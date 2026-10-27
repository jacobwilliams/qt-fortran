!> OpenGL rendering: shaders, a vertex array object and a vertex buffer draw a
!> triangle into a QtfOpenGLWidget, checked through grabFramebuffer.
!>
!> OpenGL needs a real display: the offscreen platform used by `pixi run test`
!> has none, so there (and on machines without OpenGL 3.3) the test prints SKIP
!> and passes. Run it for real with `pixi run test-gl`.
module test_opengl_scene

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double

    !> GL resources and what the slots observed.
    type :: scene
        type(QtfOpenGLWidget) :: widget
        type(QOpenGLShaderProgram) :: program
        type(QOpenGLVertexArrayObject) :: vao
        type(QOpenGLBuffer) :: vbo
        logical :: linked = .false.
        integer :: initialized = 0, painted = 0, resized = 0
        character(len=:), allocatable :: version, log
    end type scene

    character(len=*), parameter :: nl = new_line('a')
    character(len=*), parameter :: vertex_shader = &
        '#version 330 core' // nl // &
        'layout(location = 0) in vec2 position;' // nl // &
        'uniform mat4 transform;' // nl // &
        'void main() { gl_Position = transform * vec4(position, 0.0, 1.0); }' // nl
    character(len=*), parameter :: fragment_shader = &
        '#version 330 core' // nl // &
        'uniform vec4 color;' // nl // &
        'out vec4 fragColor;' // nl // &
        'void main() { fragColor = color; }' // nl

contains

    !> Compile the shaders and upload a triangle covering the center.
    subroutine on_initialize(data)
        class(*), intent(inout), optional :: data
        logical :: ok
        select type (s => data)
        type is (scene)
            s%initialized = s%initialized + 1
            s%version = glGetString(GL_VERSION)
            s%program = QOpenGLShaderProgram(s%widget)
            ok = s%program%addShaderFromSourceCode(QOpenGLShader_Vertex, vertex_shader)
            ok = ok .and. s%program%addShaderFromSourceCode(QOpenGLShader_Fragment, fragment_shader)
            s%linked = ok .and. s%program%link()
            s%log = s%program%log()
            if (.not. s%linked) return

            s%vao = QOpenGLVertexArrayObject(s%widget)
            ok = s%vao%create()
            call s%vao%bind()
            s%vbo = QOpenGLBuffer()
            ok = s%vbo%create()
            ok = s%vbo%bind()
            ! a large triangle (in clip coordinates, before `transform`)
            call s%vbo%allocate([-0.5_dp, -0.5_dp, 0.5_dp, -0.5_dp, 0.0_dp, 0.5_dp])
            ok = s%program%bind()
            call s%program%enableAttributeArray(0)
            call s%program%setAttributeBuffer(0, GL_FLOAT, 0, 2)
            call s%vao%release()
            call s%program%release()
        end select
    end subroutine on_initialize

    !> Count resizes.
    subroutine on_resize(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (scene)
            s%resized = s%resized + 1
        end select
    end subroutine on_resize

    !> Clear to blue and draw the triangle in red, scaled up by 1.6.
    subroutine on_paint(data)
        class(*), intent(inout), optional :: data
        type(QMatrix4x4) :: transform
        logical :: ok
        select type (s => data)
        type is (scene)
            s%painted = s%painted + 1
            call glClearColor(0.0_dp, 0.0_dp, 1.0_dp, 1.0_dp)
            call glClear(ior(GL_COLOR_BUFFER_BIT, GL_DEPTH_BUFFER_BIT))
            if (.not. s%linked) return
            call transform%scale(1.6_dp)
            ok = s%program%bind()
            call s%program%setUniformValue('transform', transform)
            call s%program%setUniformValue('color', Qt_red)
            call s%vao%bind()
            call glDrawArrays(GL_TRIANGLES, 0, 3)
            call s%vao%release()
            call s%program%release()
        end select
    end subroutine on_paint

end module test_opengl_scene

!> Tests the OpenGL bindings (see the module documentation).
program test_opengl

    use qt
    use testing
    use test_opengl_scene
    implicit none

    type(QApplication) :: app
    type(QSurfaceFormat) :: fmt, actual
    type(scene), target :: s
    type(QImage) :: img
    integer :: w, h

    ! one GL version everywhere, so `#version 330 core` shaders work on all platforms
    fmt = QSurfaceFormat()
    call fmt%setVersion(3, 3)
    call fmt%setProfile(QSurfaceFormat_CoreProfile)
    call QSurfaceFormat_setDefaultFormat(fmt)
    call check(fmt%majorVersion() == 3 .and. fmt%profile() == QSurfaceFormat_CoreProfile, 'QSurfaceFormat')
    call fmt%delete()
    ! the swap interval (vsync), on a format of its own (the default is left as set above)
    fmt = QSurfaceFormat()
    call fmt%setSwapInterval(0)
    call check(fmt%swapInterval() == 0, 'QSurfaceFormat swap interval 0')
    call fmt%setSwapInterval(1)
    call check(fmt%swapInterval() == 1, 'QSurfaceFormat swap interval 1')
    call fmt%delete()

    app = QApplication()

    s%widget = QtfOpenGLWidget()
    call s%widget%resize(64, 48)
    call s%widget%initializeGL%connect(on_initialize, s)
    call s%widget%resizeGL%connect(on_resize, s)
    call s%widget%paintGL%connect(on_paint, s)

    img = s%widget%grabFramebuffer()   ! initializes GL and renders once
    if (.not. s%widget%isValid() .or. img%isNull()) then
        write(*,'(A)') 'test_opengl: SKIP (no OpenGL context on this platform)'
        stop
    end if
    actual = s%widget%format()
    if (actual%majorVersion() < 3 .or. (actual%majorVersion() == 3 .and. actual%minorVersion() < 3)) then
        write(*,'(A)') 'test_opengl: SKIP (OpenGL 3.3 not available: '//s%version//')'
        stop
    end if
    write(*,'(A)') 'OpenGL '//s%version

    call check(s%initialized == 1, 'initializeGL called once')
    call check(s%linked, 'shaders compiled and linked')
    if (.not. s%linked) write(*,'(A)') s%log
    call check(s%painted >= 1, 'paintGL called')

    ! resizeGL follows real resize events (not a hidden widget's grab)
    call s%widget%show()
    call s%widget%resize(80, 60)
    call QApplication_processEvents()
    call check(s%resized >= 1, 'resizeGL called on resize')
    call img%delete()
    img = s%widget%grabFramebuffer()

    w = img%width()
    h = img%height()
    call check(w >= 80 .and. h >= 60, 'framebuffer size (device pixels)')
    call check(img%pixelColor(w / 2, h / 2) == Qt_red, 'triangle drawn in the center')
    call check(img%pixelColor(1, 1) == Qt_blue, 'clear color in the corner')
    call check(glGetError() == GL_NO_ERROR, 'no GL errors (no current context outside slots)')

    call img%delete()
    call actual%delete()
    call s%widget%delete()

    write(*,'(A)') 'test_opengl: all checks passed'

end program test_opengl
