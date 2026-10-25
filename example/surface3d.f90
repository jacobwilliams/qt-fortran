!> Interactive 3D surface plot with modern OpenGL.
!>
!> The surface z = f(x, y) is drawn as an indexed triangle mesh with per-vertex
!> normals and height colors, lit in a GLSL fragment shader, inside a bounding
!> box drawn with lines.
!>
!> * Drag with the left mouse button to orbit, use the wheel to zoom.
!> * Toolbar: choose the function; View > Auto-rotate (Space), Show box, Reset
!>   camera; File > Save image... exports a PNG.
!>
!> `surface3d --screenshot out.png [--function N]` renders a few frames (switching
!> to function N, 0-based, halfway), saves the plot and exits. It needs a display
!> with OpenGL 3.3 (the offscreen platform has no OpenGL).
module surface3d_app

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    real(dp), parameter :: pi = acos(-1.0_dp)
    integer, parameter :: n = 120                  !! grid points per side
    real(dp), parameter :: extent = 8.0_dp         !! the grid spans [-extent, extent]^2
    real(dp), parameter :: height = 2.5_dp         !! z is scaled to [-height/2, height/2]-ish
    integer, parameter :: floats_per_vertex = 9    !! position(3), normal(3), color(3)
    integer, parameter :: stride = floats_per_vertex * 4   !! bytes (buffers hold 32-bit floats)

    character(len=20), parameter :: function_names(4) = &
        [character(len=20) :: 'Ripple (sinc)', 'Saddle', 'Gaussian peaks', 'Egg crate']

    character(len=*), parameter :: nl = new_line('a')
    character(len=*), parameter :: vertex_shader = &
        '#version 330 core' // nl // &
        'layout(location = 0) in vec3 position;' // nl // &
        'layout(location = 1) in vec3 normal;' // nl // &
        'layout(location = 2) in vec3 color;' // nl // &
        'uniform mat4 mvp;' // nl // &
        'uniform mat3 normalMatrix;' // nl // &
        'out vec3 vNormal;' // nl // &
        'out vec3 vColor;' // nl // &
        'out vec3 vPosition;' // nl // &
        'void main() {' // nl // &
        '    gl_Position = mvp * vec4(position, 1.0);' // nl // &
        '    vNormal = normalMatrix * normal;' // nl // &
        '    vColor = color;' // nl // &
        '    vPosition = position;' // nl // &
        '}' // nl
    character(len=*), parameter :: fragment_shader = &
        '#version 330 core' // nl // &
        'in vec3 vNormal;' // nl // &
        'in vec3 vColor;' // nl // &
        'in vec3 vPosition;' // nl // &
        'uniform vec3 lightDirection;' // nl // &
        'uniform vec3 eye;' // nl // &
        'uniform int unlit;' // nl // &
        'out vec4 fragColor;' // nl // &
        'void main() {' // nl // &
        '    if (unlit != 0) { fragColor = vec4(vColor, 1.0); return; }' // nl // &
        '    vec3 n = normalize(vNormal);' // nl // &
        '    if (!gl_FrontFacing) n = -n;' // nl // &
        '    vec3 l = normalize(lightDirection);' // nl // &
        '    vec3 h = normalize(l + normalize(eye - vPosition));' // nl // &
        '    float diffuse = max(dot(n, l), 0.0);' // nl // &
        '    float specular = pow(max(dot(n, h), 0.0), 40.0);' // nl // &
        '    fragColor = vec4(vColor * (0.28 + 0.72 * diffuse) + 0.35 * specular, 1.0);' // nl // &
        '}' // nl

    !> Widgets, GL resources and camera of the surface viewer.
    type :: viewer
        type(QMainWindow) :: window
        type(QtfOpenGLWidget) :: gl
        type(QStatusBar) :: status
        type(QComboBox) :: function
        type(QAction) :: rotate, box
        type(QTimer) :: timer
        ! GL resources (created in initializeGL)
        type(QOpenGLShaderProgram) :: program
        type(QOpenGLVertexArrayObject) :: surface_vao, box_vao
        type(QOpenGLBuffer) :: surface_vbo, surface_ibo, box_vbo
        integer :: nindices = 0
        logical :: ready = .false.
        ! camera: orbit around the origin
        real(dp) :: yaw = 35.0_dp, pitch = 30.0_dp, distance = 30.0_dp
        real(dp) :: last_x = 0.0_dp, last_y = 0.0_dp
        ! --screenshot
        character(len=:), allocatable :: screenshot
        integer :: frames_left = 30
        integer :: switch_to = -1   !! --function: switch to this function mid-run
    end type viewer

contains

    ! ------------------------------------------------------------------
    ! the surface

    !> The selected function at (x, y).
    real(dp) function surface(which, x, y)
        integer, intent(in) :: which
        real(dp), intent(in) :: x, y
        real(dp) :: r
        select case (which)
        case (1)
            surface = (x * x - y * y) / 16
        case (2)
            surface = 1.6_dp * exp(-((x - 2.5_dp)**2 + (y - 1.5_dp)**2) / 3) &
                    + 1.0_dp * exp(-((x + 2.5_dp)**2 + (y + 2.0_dp)**2) / 5) &
                    - 0.8_dp * exp(-((x + 1.0_dp)**2 + (y - 3.5_dp)**2) / 2)
        case (3)
            surface = 0.5_dp * sin(x) * cos(y)
        case default
            r = sqrt(x * x + y * y)
            surface = 1.8_dp
            if (r > 1.0e-9_dp) surface = 1.8_dp * sin(1.5_dp * r) / (1.5_dp * r)
        end select
    end function surface

    !> A blue-cyan-green-yellow-red color for t in [0, 1].
    pure function colormap(t) result(rgb)
        real(dp), intent(in) :: t
        real(dp) :: rgb(3), u
        u = min(max(t, 0.0_dp), 1.0_dp) * 4
        if (u < 1) then
            rgb = [0.10_dp, 0.25_dp + 0.6_dp * u, 0.85_dp]
        else if (u < 2) then
            rgb = [0.10_dp, 0.85_dp, 0.85_dp - 0.6_dp * (u - 1)]
        else if (u < 3) then
            rgb = [0.10_dp + 0.85_dp * (u - 2), 0.85_dp, 0.25_dp]
        else
            rgb = [0.95_dp, 0.85_dp - 0.6_dp * (u - 3), 0.25_dp - 0.1_dp * (u - 3)]
        end if
    end function colormap

    !> Build the mesh of function `which`: interleaved vertices and triangle indices.
    !> The surface is drawn with y up: (x, f(x, y), y).
    subroutine build_mesh(which, vertices, indices)
        integer, intent(in) :: which
        real(dp), allocatable, intent(out) :: vertices(:)
        integer, allocatable, intent(out) :: indices(:)
        real(dp) :: x, y, z(n, n), nx, ny, nz, len, zmin, zmax, h
        integer :: i, j, k, v
        h = 2 * extent / (n - 1)
        do j = 1, n
            do i = 1, n
                z(i, j) = surface(which, -extent + (i - 1) * h, -extent + (j - 1) * h)
            end do
        end do
        zmin = minval(z)
        zmax = max(maxval(z), zmin + 1.0e-6_dp)
        z = (z - zmin) / (zmax - zmin) * height - height / 2   ! scale to a common height

        allocate(vertices(floats_per_vertex * n * n))
        k = 0
        do j = 1, n
            do i = 1, n
                x = -extent + (i - 1) * h
                y = -extent + (j - 1) * h
                ! normal from central differences of the (scaled) height
                nx = -(z(min(i + 1, n), j) - z(max(i - 1, 1), j)) / (h * (min(i + 1, n) - max(i - 1, 1)))
                nz = -(z(i, min(j + 1, n)) - z(i, max(j - 1, 1))) / (h * (min(j + 1, n) - max(j - 1, 1)))
                ny = 1.0_dp
                len = sqrt(nx * nx + ny * ny + nz * nz)
                vertices(k + 1:k + 9) = [x, z(i, j), y, nx / len, ny / len, nz / len, &
                                         colormap((z(i, j) + height / 2) / height)]
                k = k + floats_per_vertex
            end do
        end do

        allocate(indices(6 * (n - 1) * (n - 1)))
        k = 0
        do j = 1, n - 1
            do i = 1, n - 1
                v = (j - 1) * n + (i - 1)          ! 0-based index of corner (i, j)
                ! counter-clockwise seen from above (+y), so the top is the front face
                indices(k + 1:k + 6) = [v, v + n, v + 1, v + 1, v + n, v + n + 1]
                k = k + 6
            end do
        end do
    end subroutine build_mesh

    !> The 12 edges of the bounding box as unlit gray lines (same vertex layout).
    function box_lines() result(vertices)
        real(dp), allocatable :: vertices(:)
        real(dp) :: c(3, 8), e, t
        integer, parameter :: edges(2, 12) = reshape([1, 2, 2, 3, 3, 4, 4, 1, 5, 6, 6, 7, 7, 8, 8, 5, &
                                                      1, 5, 2, 6, 3, 7, 4, 8], [2, 12])
        integer :: i, k
        e = extent
        t = height / 2 + 0.3_dp
        c = reshape([-e, -t, -e,  e, -t, -e,  e, -t, e,  -e, -t, e, &
                     -e,  t, -e,  e,  t, -e,  e,  t, e,  -e,  t, e], [3, 8])
        allocate(vertices(floats_per_vertex * 24))
        k = 0
        do i = 1, 12
            vertices(k + 1:k + 9) = [c(:, edges(1, i)), 0.0_dp, 1.0_dp, 0.0_dp, 0.70_dp, 0.72_dp, 0.76_dp]
            vertices(k + 10:k + 18) = [c(:, edges(2, i)), 0.0_dp, 1.0_dp, 0.0_dp, 0.70_dp, 0.72_dp, 0.76_dp]
            k = k + 18
        end do
    end function box_lines

    !> Describe the interleaved vertex layout of the bound buffer to the program.
    subroutine set_layout(program)
        type(QOpenGLShaderProgram), intent(in) :: program
        call program%enableAttributeArray(0)
        call program%setAttributeBuffer(0, GL_FLOAT, 0, 3, stride)     ! position
        call program%enableAttributeArray(1)
        call program%setAttributeBuffer(1, GL_FLOAT, 12, 3, stride)    ! normal
        call program%enableAttributeArray(2)
        call program%setAttributeBuffer(2, GL_FLOAT, 24, 3, stride)    ! color
    end subroutine set_layout

    !> Upload the mesh of the selected function (the context must be current).
    subroutine upload_surface(s)
        type(viewer), intent(inout) :: s
        real(dp), allocatable :: vertices(:)
        integer, allocatable :: indices(:)
        logical :: ok
        call build_mesh(s%function%currentIndex(), vertices, indices)
        call s%surface_vao%bind()
        ok = s%surface_vbo%bind()
        call s%surface_vbo%allocate(vertices)
        ok = s%surface_ibo%bind()
        call s%surface_ibo%allocate(indices)
        s%nindices = size(indices)
        call s%surface_vao%release()
    end subroutine upload_surface

    ! ------------------------------------------------------------------
    ! OpenGL slots

    !> Compile the shaders and create the buffers.
    subroutine on_initialize(data)
        class(*), intent(inout), optional :: data
        logical :: ok
        integer :: button
        select type (s => data)
        type is (viewer)
            call glEnable(GL_DEPTH_TEST)
            call glEnable(GL_MULTISAMPLE)
            call glClearColor(0.0_dp, 0.0_dp, 0.0_dp, 1.0_dp)

            s%program = QOpenGLShaderProgram(s%gl)
            ok = s%program%addShaderFromSourceCode(QOpenGLShader_Vertex, vertex_shader)
            ok = ok .and. s%program%addShaderFromSourceCode(QOpenGLShader_Fragment, fragment_shader)
            ok = ok .and. s%program%link()
            if (.not. ok) then
                button = QMessageBox_critical('OpenGL', 'Could not build the shaders:' // nl // &
                                              s%program%log(), parent=s%window)
                return
            end if
            ok = s%program%bind()

            ! surface: vertex buffer + index buffer, recorded in a VAO
            s%surface_vao = QOpenGLVertexArrayObject(s%gl)
            ok = s%surface_vao%create()
            call s%surface_vao%bind()
            s%surface_vbo = QOpenGLBuffer()
            ok = s%surface_vbo%create()
            ok = s%surface_vbo%bind()
            call set_layout(s%program)
            s%surface_ibo = QOpenGLBuffer(QOpenGLBuffer_IndexBuffer)
            ok = s%surface_ibo%create()
            call s%surface_vao%release()
            call upload_surface(s)

            ! bounding box: plain lines
            s%box_vao = QOpenGLVertexArrayObject(s%gl)
            ok = s%box_vao%create()
            call s%box_vao%bind()
            s%box_vbo = QOpenGLBuffer()
            ok = s%box_vbo%create()
            ok = s%box_vbo%bind()
            call s%box_vbo%allocate(box_lines())
            call set_layout(s%program)
            call s%box_vao%release()
            call s%program%release()

            s%ready = .true.
            call s%status%showMessage('OpenGL ' // glGetString(GL_VERSION) // ' - drag to orbit, wheel to zoom')
        end select
    end subroutine on_initialize

    !> Draw the surface and the box from the current camera.
    subroutine on_paint(data)
        class(*), intent(inout), optional :: data
        type(QMatrix4x4) :: mvp, model
        real(dp) :: eye(3), yaw, pitch, aspect
        logical :: ok
        select type (s => data)
        type is (viewer)
            call glClear(ior(GL_COLOR_BUFFER_BIT, GL_DEPTH_BUFFER_BIT))
            if (.not. s%ready) return

            yaw = s%yaw * pi / 180
            pitch = s%pitch * pi / 180
            eye = s%distance * [cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)]
            aspect = real(s%gl%width(), dp) / max(1, s%gl%height())
            call mvp%perspective(40.0_dp, aspect, 0.5_dp, 200.0_dp)
            call mvp%lookAt(eye, [0.0_dp, 0.0_dp, 0.0_dp], [0.0_dp, 1.0_dp, 0.0_dp])
            mvp = mvp * model   ! (the model transform is the identity here)

            ok = s%program%bind()
            call s%program%setUniformValue('mvp', mvp)
            call s%program%setUniformValue('normalMatrix', reshape(model%normalMatrix(), [9]))
            call s%program%setUniformValue('lightDirection', 0.4_dp, 1.0_dp, 0.6_dp)
            call s%program%setUniformValue('eye', eye(1), eye(2), eye(3))

            call s%program%setUniformValue('unlit', 0)
            call s%surface_vao%bind()
            call glDrawElements(GL_TRIANGLES, s%nindices, GL_UNSIGNED_INT)
            call s%surface_vao%release()

            if (s%box%isChecked()) then
                call s%program%setUniformValue('unlit', 1)
                call s%box_vao%bind()
                call glDrawArrays(GL_LINES, 0, 24)
                call s%box_vao%release()
            end if
            call s%program%release()
        end select
    end subroutine on_paint

    ! ------------------------------------------------------------------
    ! camera input

    !> Remember where a drag starts.
    subroutine on_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer)
            s%last_x = event%x()
            s%last_y = event%y()
        end select
    end subroutine on_press

    !> Orbit while dragging with the left button.
    subroutine on_move(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer)
            if (iand(event%buttons(), Qt_LeftButton) == 0) return
            s%yaw = s%yaw - 0.4_dp * (event%x() - s%last_x)
            s%pitch = min(max(s%pitch + 0.4_dp * (event%y() - s%last_y), -85.0_dp), 85.0_dp)
            s%last_x = event%x()
            s%last_y = event%y()
            call s%gl%update()
        end select
    end subroutine on_move

    !> Zoom with the wheel.
    subroutine on_wheel(event, data)
        type(QWheelEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer)
            s%distance = min(max(s%distance * 0.9_dp**(event%angleDeltaY() / 120.0_dp), 6.0_dp), 80.0_dp)
            call s%gl%update()
        end select
    end subroutine on_wheel

    !> Space toggles auto-rotation.
    subroutine on_key(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer)
            if (event%key() == Qt_Key_Space) call s%rotate%trigger()
        end select
    end subroutine on_key

    ! ------------------------------------------------------------------
    ! commands

    !> Rebuild the mesh for the newly selected function.
    subroutine on_function(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer)
            if (.not. s%ready) return
            call s%gl%makeCurrent()      ! GL calls outside the widget's slots
            call upload_surface(s)
            call s%gl%doneCurrent()
            call s%gl%update()
        end select
    end subroutine on_function

    !> Start or stop auto-rotation.
    subroutine on_rotate(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer)
            if (checked) then
                call s%timer%start(16)
            else
                call s%timer%stop()
            end if
        end select
    end subroutine on_rotate

    !> Advance the auto-rotation; handles `--screenshot`.
    subroutine on_tick(data)
        class(*), intent(inout), optional :: data
        type(QImage) :: img
        select type (s => data)
        type is (viewer)
            s%yaw = s%yaw + 0.4_dp
            call s%gl%update()
            if (allocated(s%screenshot)) then
                s%frames_left = s%frames_left - 1
                ! switch functions on a live context (exercises the re-upload path)
                if (s%frames_left == 15 .and. s%switch_to >= 0) call s%function%setCurrentIndex(s%switch_to)
                if (s%frames_left == 0) then
                    img = s%gl%grabFramebuffer()
                    if (.not. img%save(s%screenshot)) write(*,'(A)') 'could not save '//s%screenshot
                    call img%delete()
                    call QApplication_quit()
                end if
            end if
        end select
    end subroutine on_tick

    !> Repaint (e.g. after toggling the box).
    subroutine on_redraw(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer)
            call s%gl%update()
        end select
    end subroutine on_redraw

    !> Restore the initial camera.
    subroutine on_reset(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer)
            s%yaw = 35.0_dp
            s%pitch = 30.0_dp
            s%distance = 30.0_dp
            call s%gl%update()
        end select
    end subroutine on_reset

    !> Save the rendered surface as a PNG.
    subroutine on_save(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        type(QImage) :: img
        integer :: button
        select type (s => data)
        type is (viewer)
            path = QFileDialog_getSaveFileName('Save image', 'surface.png', 'PNG images (*.png)', parent=s%window)
            if (path == '') return
            img = s%gl%grabFramebuffer()
            if (img%save(path)) then
                call s%status%showMessage('Saved ' // path, 3000)
            else
                button = QMessageBox_warning('Save image', 'Could not write ' // path, parent=s%window)
            end if
            call img%delete()
        end select
    end subroutine on_save

    !> Quit the application.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

    ! ------------------------------------------------------------------
    ! construction

    !> Build the window: toolbar, menus, the OpenGL view and the status bar.
    subroutine build(s)
        type(viewer), intent(inout), target :: s
        type(QMenuBar) :: bar
        type(QMenu) :: file_menu, view_menu
        type(QToolBar) :: tools
        type(QAction) :: save, quit, reset

        s%window = QMainWindow()
        call s%window%setWindowTitle('3D Surface - qt-fortran + OpenGL')
        s%status = s%window%statusBar()

        s%gl = QtfOpenGLWidget()
        call s%gl%setMinimumSize(640, 480)
        call s%window%setCentralWidget(s%gl)
        call s%gl%initializeGL%connect(on_initialize, s)
        call s%gl%paintGL%connect(on_paint, s)
        call s%gl%mousePressEvent%connect(on_press, s)
        call s%gl%mouseMoveEvent%connect(on_move, s)
        call s%gl%wheelEvent%connect(on_wheel, s)
        call s%gl%keyPressEvent%connect(on_key, s)

        save = QAction('&Save image...', s%window)
        call save%setShortcut('Ctrl+S')
        call save%triggered%connect(on_save, s)
        quit = QAction('&Quit', s%window)
        call quit%setShortcut('Ctrl+Q')
        call quit%triggered%connect(on_quit, s)
        s%rotate = QAction('Auto-&rotate', s%window)
        call s%rotate%setCheckable(.true.)
        call s%rotate%toggled%connect(on_rotate, s)
        s%box = QAction('Show &box', s%window)
        call s%box%setCheckable(.true.)
        call s%box%setChecked(.true.)
        call s%box%toggled%connect(on_redraw, s)
        reset = QAction('Reset &camera', s%window)
        call reset%setShortcut('Ctrl+0')
        call reset%triggered%connect(on_reset, s)

        bar = s%window%menuBar()
        file_menu = bar%addMenu('&File')
        call file_menu%addAction(save)
        call file_menu%addSeparator()
        call file_menu%addAction(quit)
        view_menu = bar%addMenu('&View')
        call view_menu%addAction(s%rotate)
        call view_menu%addAction(s%box)
        call view_menu%addAction(reset)

        s%function = QComboBox()
        call s%function%addItems(function_names)
        call s%function%currentIndexChanged%connect(on_function, s)
        tools = s%window%addToolBar('Surface')
        call tools%addWidget(QLabel(' Function: '))
        call tools%addWidget(s%function)
        call tools%addSeparator()
        call tools%addAction(s%rotate)
        call tools%addAction(s%box)
        call tools%addAction(reset)

        s%timer = QTimer()
        call s%timer%timeout%connect(on_tick, s)
    end subroutine build

end module surface3d_app

!> 3D surface viewer (see the module documentation).
program surface3d

    use qt
    use surface3d_app
    implicit none

    type(QApplication) :: app
    type(QSurfaceFormat) :: fmt
    type(viewer), target :: s
    character(len=1024) :: arg
    integer :: ierr

    ! OpenGL 3.3 core everywhere (matches the `#version 330 core` shaders), with
    ! a depth buffer and 4x multisampling; must be set before the application
    fmt = QSurfaceFormat()
    call fmt%setVersion(3, 3)
    call fmt%setProfile(QSurfaceFormat_CoreProfile)
    call fmt%setDepthBufferSize(24)
    call fmt%setSamples(4)
    call QSurfaceFormat_setDefaultFormat(fmt)
    call fmt%delete()

    app = QApplication()
    call build(s)

    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        call s%rotate%setChecked(.true.)
        call get_command_argument(3, arg)
        if (arg == '--function') then
            call get_command_argument(4, arg)
            read(arg, *) s%switch_to
        end if
    end if

    call s%window%resize(900, 680)
    call s%window%show()
    call s%gl%setFocus()
    ierr = app%exec()

end program surface3d
