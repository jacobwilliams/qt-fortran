!> A playground for the geometry and 3D math value types.
!>
!> Left, 2D: drag the round handles. Two QLineF segments show their
!> intersection (bounded: a green dot; unbounded: dashed extensions), angles and
!> lengths; two QRectF rectangles show their intersection (filled) and union
!> (dashed); the blue rectangle lights up while the mouse is inside it.
!>
!> Right, 3D: a cube painted with QPainter (no OpenGL needed). Its orientation
!> is a QQuaternion slerp between two Euler-angle orientations, times a
!> rotation you add by dragging; it is projected with QMatrix4x4 and
!> QVector3D_project, faces facing away are culled with rotated normals, and the
!> vertex under the mouse is picked with QVector3D_unproject and
!> QVector3D%distanceToLine. Wheel: zoom; Space: pause the animation; R: reset.
!>
!> `geometry --screenshot out.png` renders a few frames, saves the window and exits.
module geometry_slots

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double

    ! the cube: vertex k at (+-1, +-1, +-1) from the bits of k - 1; faces as
    ! vertex indices (in order around the face) and outward normals
    integer, parameter :: faces(4, 6) = reshape([1, 3, 7, 5,  2, 4, 8, 6,  1, 2, 6, 5, &
                                                 3, 4, 8, 7,  1, 2, 4, 3,  5, 6, 8, 7], [4, 6])
    real(dp), parameter :: normals(3, 6) = reshape([-1, 0, 0,  1, 0, 0,  0, -1, 0, &
                                                    0, 1, 0,  0, 0, -1,  0, 0, 1], [3, 6]) * 1.0_dp

    !> Widgets and state of both views.
    type :: geometry_state
        type(QMainWindow) :: window
        type(QtfWidget) :: view2d, view3d
        type(QStatusBar) :: status
        type(QTimer) :: timer
        ! 2D: handles 1-2 are line A, 3-4 line B, 5 the center of rectangle B
        type(QPointF) :: handle(5)
        type(QRectF) :: rectA = QRectF(40, 250, 170, 110)
        type(QSizeF) :: sizeB = QSizeF(150, 100)
        type(QPointF) :: mouse2d = QPointF(-100, -100)
        integer :: dragging = 0       !! the handle being dragged (0: none)
        ! 3D
        type(QQuaternion) :: qa, qb   !! the two key orientations
        type(QQuaternion) :: user     !! the rotation added by dragging
        real(dp) :: t = 0, dt = 0.004_dp
        real(dp) :: distance = 7.5_dp
        logical :: animate = .true., rotating = .false.
        type(QPointF) :: mouse3d = QPointF(-100, -100), last
        character(len=:), allocatable :: screenshot
        integer :: frames_left = 40
    end type geometry_state

contains

    ! ------------------------------------------------------------------
    ! 2D view

    !> Draw the rectangles, the lines, their intersection and the handles.
    subroutine on_paint2d(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        type(QRect) :: area
        type(QRectF) :: rectB, both, overlap
        type(QLineF) :: a, b
        type(QPointF) :: ip
        integer :: kind, i
        character(len=80) :: text
        select type (s => data)
        type is (geometry_state)
            call painter%setRenderHint(QPainter_Antialiasing)
            area = s%view2d%rect()
            call painter%fillRect(QRectF(area), Qt_white)
            area = area - QMargins(6, 6, 6, 6)
            call painter%setPen(QPen(Qt_lightGray, 1.0_dp))
            call painter%setBrush(QBrush(style=Qt_NoBrush))
            call painter%drawRect(QRectF(area))

            ! rectangles: A fixed, B centered on handle 5
            rectB = QRectF(QPointF(0, 0), s%sizeB)
            call rectB%moveCenter(s%handle(5))
            both = s%rectA%united(rectB)
            call painter%setPen(QPen(Qt_gray, 1.0_dp, Qt_DashLine))
            call painter%drawRect(both)
            call painter%setPen(QPen(QColor(40, 90, 200), merge(3.0_dp, 1.0_dp, s%rectA%contains(s%mouse2d))))
            call painter%setBrush(QColor(40, 90, 200, 50))
            call painter%drawRect(s%rectA)
            call painter%setPen(QPen(QColor(220, 120, 20), 1.0_dp))
            call painter%setBrush(QColor(220, 120, 20, 50))
            call painter%drawRect(rectB)
            if (s%rectA%intersects(rectB)) then
                overlap = s%rectA%intersected(rectB)
                call painter%fillRect(overlap, QColor(130, 40, 160, 120))
                write(text, '(A,I0,A,I0)') 'overlap ', nint(overlap%width), ' x ', nint(overlap%height)
                call painter%setPen(QColor(90, 20, 120))
                call painter%drawText(QPointF(overlap%x, overlap%bottom() + 16), trim(text))
            end if

            ! lines and their intersection
            a = QLineF(s%handle(1), s%handle(2))
            b = QLineF(s%handle(3), s%handle(4))
            kind = a%intersects(b, ip)
            if (kind == QLineF_UnboundedIntersection) then
                call painter%setPen(QPen(Qt_gray, 1.0_dp, Qt_DashLine))
                call painter%drawLine(a%center(), ip)
                call painter%drawLine(b%center(), ip)
            end if
            call painter%setPen(QPen(QColor(40, 90, 200), 2.5_dp))
            call painter%drawLine(a)
            call painter%setPen(QPen(QColor(200, 40, 40), 2.5_dp))
            call painter%drawLine(b)
            if (kind /= QLineF_NoIntersection) then
                call painter%setPen(QPen(Qt_black, 1.0_dp))
                call painter%setBrush(merge(QColor(30, 170, 60), Qt_white, kind == QLineF_BoundedIntersection))
                call painter%drawEllipse(ip, 5.0_dp, 5.0_dp)
            end if

            ! handles (the one under the mouse in yellow)
            do i = 1, size(s%handle)
                call painter%setPen(QPen(Qt_black, 1.0_dp))
                call painter%setBrush(merge(Qt_yellow, Qt_lightGray, i == handle_at(s, s%mouse2d) .or. i == s%dragging))
                call painter%drawEllipse(s%handle(i), 6.0_dp, 6.0_dp)
            end do

            ! readout
            call painter%setPen(Qt_black)
            call painter%setFont(QFont(pointSize=10.0_dp))
            write(text, '(A,F6.1,A,F6.1,A)') 'blue line: length ', a%length(), ', angle ', a%angle(), ' deg'
            call painter%drawText(QPointF(14, 24), trim(text))
            write(text, '(A,F6.1,A,F6.1,A)') 'red line:  length ', b%length(), ', angle ', b%angle(), ' deg'
            call painter%drawText(QPointF(14, 42), trim(text))
            select case (kind)
            case (QLineF_BoundedIntersection)
                write(text, '(A,F0.1,A,F0.1,A,F5.1,A)') 'they cross at (', ip%x, ', ', ip%y, '), angle ', &
                    a%angleTo(b), ' deg'
            case (QLineF_UnboundedIntersection)
                write(text, '(A,F0.1,A,F0.1,A)') 'their extensions cross at (', ip%x, ', ', ip%y, ')'
            case default
                text = 'they are parallel'
            end select
            call painter%drawText(QPointF(14, 60), trim(text))
        end select
    end subroutine on_paint2d

    !> The handle within 10 pixels of `p` (0 if none).
    integer function handle_at(s, p) result(found)
        type(geometry_state), intent(in) :: s
        type(QPointF), intent(in) :: p
        type(QLineF) :: to_handle
        integer :: i
        found = 0
        do i = 1, size(s%handle)
            to_handle = QLineF(s%handle(i), p)
            if (to_handle%length() <= 10) found = i
        end do
    end function handle_at

    !> Start dragging the handle under the mouse.
    subroutine on_press2d(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (geometry_state)
            s%dragging = handle_at(s, event%position())
            call s%view2d%update()
        end select
    end subroutine on_press2d

    !> Move the dragged handle (kept inside the view), or just track the mouse.
    subroutine on_move2d(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        type(QRectF) :: inside
        type(QPointF) :: p
        select type (s => data)
        type is (geometry_state)
            s%mouse2d = event%position()
            if (s%dragging > 0) then
                inside = QRectF(s%view2d%rect())
                inside = inside%adjusted(8.0_dp, 8.0_dp, -8.0_dp, -8.0_dp)
                p = s%mouse2d
                p%x = min(max(p%x, inside%left()), inside%right())
                p%y = min(max(p%y, inside%top()), inside%bottom())
                s%handle(s%dragging) = p
            end if
            call s%view2d%update()
        end select
    end subroutine on_move2d

    !> Stop dragging.
    subroutine on_release2d(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (geometry_state)
            s%dragging = 0
            call s%view2d%update()
        end select
    end subroutine on_release2d

    ! ------------------------------------------------------------------
    ! 3D view

    !> The cube's current orientation: the dragged rotation after the animated one.
    type(QQuaternion) function orientation(s)
        type(geometry_state), intent(in) :: s
        real(dp) :: smooth
        smooth = s%t * s%t * (3 - 2 * s%t)   ! ease in and out
        orientation = s%user * QQuaternion_slerp(s%qa, s%qb, smooth)
    end function orientation

    !> The model-view and projection matrices and the viewport of the 3D view.
    subroutine camera(s, q, mv, proj, viewport)
        type(geometry_state), intent(in) :: s
        type(QQuaternion), intent(in) :: q
        type(QMatrix4x4), intent(out) :: mv, proj
        type(QRect), intent(out) :: viewport
        viewport = s%view3d%rect()
        mv = QMatrix4x4()
        call mv%lookAt(QVector3D(0.0_dp, 0.0_dp, s%distance), QVector3D(), QVector3D(0, 1, 0))
        call mv%rotate(q)
        proj = QMatrix4x4()
        call proj%perspective(40.0_dp, real(viewport%width, dp) / max(viewport%height, 1), 0.1_dp, 100.0_dp)
    end subroutine camera

    !> Vertex `k` (1..8) of the cube.
    type(QVector3D) function vertex(k)
        integer, intent(in) :: k
        vertex = QVector3D(2 * ibits(k - 1, 0, 1) - 1, 2 * ibits(k - 1, 1, 1) - 1, 2 * ibits(k - 1, 2, 1) - 1)
    end function vertex

    !> Where the object-space point `v` appears in the view (widget coordinates).
    type(QPointF) function on_screen(v, mv, proj, viewport)
        type(QVector3D), intent(in) :: v
        type(QMatrix4x4), intent(in) :: mv, proj
        type(QRect), intent(in) :: viewport
        type(QVector3D) :: win
        win = QVector3D_project(v, mv, proj, viewport)
        on_screen = QPointF(win%x, viewport%height - win%y)   ! window y is up, widget y down
    end function on_screen

    !> The cube vertex under widget position `p` (0 if none): the closest one to
    !> the picking ray through `p`.
    integer function picked_vertex(s, p) result(found)
        type(geometry_state), intent(in) :: s
        type(QPointF), intent(in) :: p
        type(QMatrix4x4) :: mv, proj
        type(QRect) :: viewport
        type(QVector3D) :: near, far, v
        real(dp) :: d, best
        integer :: k
        call camera(s, orientation(s), mv, proj, viewport)
        near = QVector3D_unproject(QVector3D(p%x, viewport%height - p%y, 0.0_dp), mv, proj, viewport)
        far = QVector3D_unproject(QVector3D(p%x, viewport%height - p%y, 1.0_dp), mv, proj, viewport)
        found = 0
        best = 0.2_dp
        do k = 1, 8
            v = vertex(k)
            d = v%distanceToLine(near, far - near)
            if (d < best) then
                best = d
                found = k
            end if
        end do
    end function picked_vertex

    !> Draw the lit cube, its axes and the readout.
    subroutine on_paint3d(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        type(QQuaternion) :: q
        type(QMatrix4x4) :: mv, proj
        type(QRect) :: viewport
        type(QVector3D) :: eye, n, center, light, angles, axis
        type(QPointF) :: corner(4), origin, tip
        type(QColor), parameter :: face_colors(6) = [QColor(220, 80, 70), QColor(220, 80, 70), &
            QColor(70, 170, 90), QColor(70, 170, 90), QColor(70, 110, 220), QColor(70, 110, 220)]
        type(QColor), parameter :: axis_colors(3) = [Qt_red, Qt_green, Qt_cyan]
        character(len=*), parameter :: axis_names = 'xyz'
        type(QColor) :: c
        real(dp) :: shade, angle
        integer :: f, i, k
        character(len=80) :: text
        select type (s => data)
        type is (geometry_state)
            call painter%setRenderHint(QPainter_Antialiasing)
            viewport = s%view3d%rect()
            call painter%fillRect(QRectF(viewport), QColor(28, 30, 38))
            q = orientation(s)
            call camera(s, q, mv, proj, viewport)

            ! faces that face the camera, shaded by a light from the upper right
            eye = QVector3D(0.0_dp, 0.0_dp, s%distance)
            light = QVector3D(1, 2, 3)
            call light%normalize()
            do f = 1, 6
                n = q%rotatedVector(QVector3D(normals(:, f)))
                center = n                               ! a face's center is its normal on a unit cube
                if (QVector3D_dotProduct(n, eye - center) <= 0) cycle
                shade = 0.35_dp + 0.65_dp * max(0.0_dp, QVector3D_dotProduct(n, light))
                c = face_colors(f)
                c = QColor(nint(c%r * shade), nint(c%g * shade), nint(c%b * shade))
                do i = 1, 4
                    corner(i) = on_screen(vertex(faces(i, f)), mv, proj, viewport)
                end do
                call painter%setPen(QPen(QColor(15, 15, 20), 1.5_dp))
                call painter%setBrush(c)
                call painter%drawPolygon(corner%x, corner%y)
            end do

            ! axes from the center (they show through the cube)
            origin = on_screen(QVector3D(), mv, proj, viewport)
            do i = 1, 3
                n = QVector3D()
                if (i == 1) n%x = 1.7_dp
                if (i == 2) n%y = 1.7_dp
                if (i == 3) n%z = 1.7_dp
                tip = on_screen(n, mv, proj, viewport)
                call painter%setPen(QPen(axis_colors(i), 2.0_dp))
                call painter%drawLine(origin, tip)
                call painter%drawText(tip + QPointF(4, -4), axis_names(i:i))
            end do

            ! the vertex under the mouse
            k = picked_vertex(s, s%mouse3d)
            if (k > 0) then
                tip = on_screen(vertex(k), mv, proj, viewport)
                call painter%setPen(QPen(Qt_yellow, 2.0_dp))
                call painter%setBrush(QBrush(style=Qt_NoBrush))
                call painter%drawEllipse(tip, 8.0_dp, 8.0_dp)
                n = vertex(k)
                write(text, '(A,3(I2,A))') 'vertex (', nint(n%x), ',', nint(n%y), ',', nint(n%z), ')'
                call painter%drawText(tip + QPointF(10, -10), trim(text))
            end if

            ! readout: the orientation as Euler angles and as axis and angle
            call painter%setPen(QColor(230, 230, 230))
            call painter%setFont(QFont(pointSize=10.0_dp))
            angles = q%toEulerAngles()
            write(text, '(A,F5.2,A)') 'slerp t = ', s%t, merge('          ', ' (paused) ', s%animate)
            call painter%drawText(QPointF(14, 24), trim(text))
            write(text, '(A,3F8.1)') 'pitch, yaw, roll:', angles%x, angles%y, angles%z
            call painter%drawText(QPointF(14, 42), trim(text))
            call q%getAxisAndAngle(axis, angle)
            write(text, '(A,F6.1,A,3F6.2,A)') 'rotation ', angle, ' deg about (', axis%x, axis%y, axis%z, ')'
            call painter%drawText(QPointF(14, 60), trim(text))
        end select
    end subroutine on_paint3d

    !> Start rotating the cube with the mouse.
    subroutine on_press3d(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (geometry_state)
            s%rotating = event%button() == Qt_LeftButton
            s%last = event%position()
        end select
    end subroutine on_press3d

    !> Rotate the cube by the mouse movement (about the axis perpendicular to
    !> it, in view space), or just track the mouse for picking.
    subroutine on_move3d(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        type(QPointF) :: delta
        type(QLineF) :: moved
        select type (s => data)
        type is (geometry_state)
            s%mouse3d = event%position()
            if (s%rotating) then
                delta = s%mouse3d - s%last
                moved = QLineF(s%last, s%mouse3d)
                if (.not. delta%isNull()) then
                    s%user = QQuaternion_fromAxisAndAngle(QVector3D(delta%y, delta%x, 0.0_dp), 0.5_dp * moved%length()) &
                             * s%user
                end if
                s%last = s%mouse3d
            end if
            call s%view3d%update()
        end select
    end subroutine on_move3d

    !> Stop rotating.
    subroutine on_release3d(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (geometry_state)
            s%rotating = .false.
        end select
    end subroutine on_release3d

    !> Zoom: move the camera closer or farther.
    subroutine on_wheel3d(event, data)
        type(QWheelEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        type(QPoint) :: delta
        select type (s => data)
        type is (geometry_state)
            delta = event%angleDelta()
            s%distance = min(max(s%distance * 0.9_dp**(delta%y / 120.0_dp), 3.0_dp), 20.0_dp)
            call s%view3d%update()
        end select
    end subroutine on_wheel3d

    !> Space: pause or resume the animation; R: reset the dragged rotation.
    subroutine on_key3d(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (geometry_state)
            select case (event%key())
            case (Qt_Key_Space)
                s%animate = .not. s%animate
            case (Qt_Key_R)
                s%user = QQuaternion()
            end select
            call s%view3d%update()
        end select
    end subroutine on_key3d

    !> Show the view's new size.
    subroutine on_resize3d(event, data)
        type(QResizeEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        type(QSize) :: size
        character(len=60) :: text
        select type (s => data)
        type is (geometry_state)
            size = event%size()
            write(text, '(A,I0,A,I0)') '3D view: ', size%width, ' x ', size%height
            call s%status%showMessage(trim(text), 2000)
        end select
    end subroutine on_resize3d

    !> Advance the slerp back and forth; handles `--screenshot`.
    subroutine on_tick(data)
        class(*), intent(inout), optional :: data
        type(QPixmap) :: pix
        logical :: ok
        select type (s => data)
        type is (geometry_state)
            if (s%animate) then
                s%t = s%t + s%dt
                if (s%t > 1 .or. s%t < 0) then
                    s%dt = -s%dt
                    s%t = min(max(s%t, 0.0_dp), 1.0_dp)
                end if
                call s%view3d%update()
            end if
            if (allocated(s%screenshot)) then
                s%frames_left = s%frames_left - 1
                if (s%frames_left == 0) then
                    pix = s%window%grab()
                    ok = pix%save(s%screenshot)
                    call pix%delete()
                    call QApplication_quit()
                end if
            end if
        end select
    end subroutine on_tick

end module geometry_slots

!> Geometry and 3D math playground (see the module documentation).
program geometry

    use qt
    use geometry_slots
    implicit none

    type(QApplication) :: app
    type(geometry_state), target :: s
    type(QWidget) :: central
    type(QHBoxLayout) :: layout
    type(QScreen) :: screen
    type(QRect) :: frame, available
    character(len=1024) :: arg
    integer :: ierr

    app = QApplication()

    s%window = QMainWindow()
    call s%window%setWindowTitle('qt-fortran geometry')
    central = QWidget()
    layout = QHBoxLayout(central)
    call layout%setContentsMargins(QMargins(0, 0, 0, 0))
    s%view2d = QtfWidget()
    s%view3d = QtfWidget()
    call s%view2d%setMinimumSize(QSize(420, 400))
    call s%view3d%setMinimumSize(QSize(420, 400))
    call s%view2d%setMouseTracking(.true.)
    call s%view3d%setMouseTracking(.true.)
    call s%view3d%setFocusPolicy(Qt_StrongFocus)
    call layout%addWidget(s%view2d)
    call layout%addWidget(s%view3d)
    call s%window%setCentralWidget(central)
    s%status = s%window%statusBar()

    ! 2D: two crossing lines and the center of the orange rectangle
    s%handle = [QPointF(60, 110), QPointF(360, 210), QPointF(90, 230), QPointF(330, 90), QPointF(250, 300)]

    ! 3D: animate between two orientations given as Euler angles (pitch, yaw, roll)
    s%qa = QQuaternion_fromEulerAngles(25.0_dp, -35.0_dp, 0.0_dp)
    s%qb = QQuaternion_fromEulerAngles(QVector3D(-30, 200, 40))

    call s%view2d%paintEvent%connect(on_paint2d, s)
    call s%view2d%mousePressEvent%connect(on_press2d, s)
    call s%view2d%mouseMoveEvent%connect(on_move2d, s)
    call s%view2d%mouseReleaseEvent%connect(on_release2d, s)
    call s%view3d%paintEvent%connect(on_paint3d, s)
    call s%view3d%mousePressEvent%connect(on_press3d, s)
    call s%view3d%mouseMoveEvent%connect(on_move3d, s)
    call s%view3d%mouseReleaseEvent%connect(on_release3d, s)
    call s%view3d%wheelEvent%connect(on_wheel3d, s)
    call s%view3d%keyPressEvent%connect(on_key3d, s)
    call s%view3d%resizeEvent%connect(on_resize3d, s)

    s%timer = QTimer()
    call s%timer%timeout%connect(on_tick, s)
    call s%timer%start(16)

    ! `--screenshot file.png`: render some frames, save the window and exit
    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        s%mouse2d = QPointF(100, 300)   ! inside the blue rectangle
    end if

    ! center the window in the screen's available area
    frame = QRect(0, 0, 900, 460)
    screen = QGuiApplication_primaryScreen()
    available = screen%availableGeometry()
    call frame%moveCenter(available%center())
    call s%window%setGeometry(frame)

    call s%status%showMessage('2D: drag the handles.  3D: drag to rotate, wheel to zoom, Space to pause, R to reset.')
    call s%window%show()
    call s%view3d%setFocus()
    ierr = app%exec()

end program geometry
