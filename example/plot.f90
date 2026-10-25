!> A live, scrolling plot drawn with QPainter on a QtfWidget.
!>
!> Click to drop markers, wheel to zoom vertically, Space (or View > Pause) to
!> pause, C to clear markers, File > Save image... to export a PNG.
!>
!> `plot --screenshot out.png` renders a few frames, saves the window and exits.
module plot_slots

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    integer, parameter :: nsamples = 400, max_markers = 32
    real(dp), parameter :: ymax = 1.6_dp   !! data range shown at zoom 1: [-ymax, ymax]

    type :: plot_state
        type(QMainWindow) :: window
        type(QtfWidget) :: canvas
        type(QTimer) :: timer
        type(QAction) :: pause
        type(QStatusBar) :: status
        real(dp) :: y(nsamples) = 0.0_dp
        integer :: t = 0
        real(dp) :: zoom = 1.0_dp
        integer :: nmarkers = 0
        real(dp) :: marker_i(max_markers), marker_y(max_markers)   !! sample index, value
        character(len=:), allocatable :: screenshot
        integer :: frames_left = 60
    end type plot_state

contains

    ! ---- plot geometry: data <-> pixel coordinates

    subroutine plot_area(w, h, x0, x1, y0, y1)
        integer, intent(in) :: w, h
        real(dp), intent(out) :: x0, x1, y0, y1
        x0 = 50
        x1 = w - 15
        y0 = 30
        y1 = h - 25
    end subroutine plot_area

    pure real(dp) function px(i, x0, x1)
        real(dp), intent(in) :: i, x0, x1
        px = x0 + (i - 1) * (x1 - x0) / (nsamples - 1)
    end function px

    pure real(dp) function py(v, zoom, y0, y1)
        real(dp), intent(in) :: v, zoom, y0, y1
        py = (y0 + y1) / 2 - v * zoom * (y1 - y0) / (2 * ymax)
    end function py

    !> Append the next sample, scrolling the trace (and markers) left.
    subroutine advance(s)
        type(plot_state), intent(inout) :: s
        real(dp) :: noise, t
        s%t = s%t + 1
        t = s%t
        call random_number(noise)
        s%y = cshift(s%y, 1)
        s%y(nsamples) = sin(0.05_dp * t) + 0.35_dp * sin(0.31_dp * t) + 0.15_dp * (noise - 0.5_dp)
        s%marker_i(1:s%nmarkers) = s%marker_i(1:s%nmarkers) - 1
    end subroutine advance

    ! ---- slots

    subroutine on_tick(data)
        class(*), intent(inout), optional :: data
        logical :: ok
        type(QPixmap) :: pix
        select type (s => data)
        type is (plot_state)
            call advance(s)
            call s%canvas%update()
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

    subroutine on_paint(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        real(dp) :: x0, x1, y0, y1, v, xs(nsamples), ys(nsamples)
        integer :: i, w, h
        character(len=16) :: label
        select type (s => data)
        type is (plot_state)
            w = painter%deviceWidth()
            h = painter%deviceHeight()
            call plot_area(w, h, x0, x1, y0, y1)
            call painter%setRenderHint(QPainter_Antialiasing)
            call painter%fillRect(0, 0, w, h, Qt_white)

            ! grid and y-axis labels
            call painter%setFont(QFont(pointSize=9.0_dp))
            do i = -3, 3
                v = i * 0.5_dp / s%zoom
                call painter%setPen(QPen(merge(Qt_gray, Qt_lightGray, i == 0), 1.0_dp, &
                                         merge(Qt_SolidLine, Qt_DotLine, i == 0)))
                call painter%drawLine(x0, py(v, s%zoom, y0, y1), x1, py(v, s%zoom, y0, y1))
                write(label, '(F6.2)') v
                call painter%setPen(Qt_darkGray)
                call painter%drawText(0.0_dp, py(v, s%zoom, y0, y1) - 8, x0 - 6, 16.0_dp, &
                                          ior(Qt_AlignRight, Qt_AlignVCenter), trim(adjustl(label)))
            end do
            call painter%setPen(QPen(Qt_darkGray))
            call painter%setBrush(QBrush(style=Qt_NoBrush))
            call painter%drawRect(x0, y0, x1 - x0, y1 - y0)

            ! the trace
            xs = [(px(real(i, dp), x0, x1), i = 1, nsamples)]
            ys = [(py(s%y(i), s%zoom, y0, y1), i = 1, nsamples)]
            call painter%setPen(QPen(QColor(30, 100, 200), 2.0_dp))
            call painter%drawPolyline(xs, ys)

            ! markers
            call painter%setPen(QPen(Qt_darkRed, 1.5_dp))
            call painter%setBrush(QColor(220, 60, 60, 160))
            do i = 1, s%nmarkers
                if (s%marker_i(i) < 1) cycle
                call painter%drawEllipse(px(s%marker_i(i), x0, x1) - 5, py(s%marker_y(i), s%zoom, y0, y1) - 5, &
                                         10.0_dp, 10.0_dp)
            end do

            ! title
            call painter%setPen(Qt_black)
            call painter%setFont(QFont(pointSize=12.0_dp, bold=.true.))
            call painter%drawText(x0, y0 - 10, 'Live signal')
            call painter%setFont(QFont(pointSize=9.0_dp))
            write(label, '(A,F4.2)') 'zoom x', s%zoom
            call painter%drawText(x1 - painter%textWidth(trim(label)), y0 - 10, trim(label))
        end select
    end subroutine on_paint

    !> Convert a widget position to (sample index, value).
    subroutine to_data(s, x, y, i, v)
        type(plot_state), intent(in) :: s
        real(dp), intent(in) :: x, y
        real(dp), intent(out) :: i, v
        real(dp) :: x0, x1, y0, y1
        call plot_area(s%canvas%width(), s%canvas%height(), x0, x1, y0, y1)
        i = 1 + (x - x0) * (nsamples - 1) / (x1 - x0)
        v = ((y0 + y1) / 2 - y) * 2 * ymax / ((y1 - y0) * s%zoom)
    end subroutine to_data

    subroutine on_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        real(dp) :: i, v
        select type (s => data)
        type is (plot_state)
            if (event%button() /= Qt_LeftButton) return
            call to_data(s, event%x(), event%y(), i, v)
            if (s%nmarkers == max_markers) then      ! drop the oldest
                s%marker_i = cshift(s%marker_i, 1)
                s%marker_y = cshift(s%marker_y, 1)
                s%nmarkers = s%nmarkers - 1
            end if
            s%nmarkers = s%nmarkers + 1
            s%marker_i(s%nmarkers) = i
            s%marker_y(s%nmarkers) = v
            call s%canvas%update()
        end select
    end subroutine on_press

    subroutine on_move(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        real(dp) :: i, v
        character(len=48) :: msg
        select type (s => data)
        type is (plot_state)
            call to_data(s, event%x(), event%y(), i, v)
            if (i < 1 .or. i > nsamples) return
            write(msg, '(A,I0,A,F7.3)') 'sample ', s%t - nsamples + nint(i), '   value ', v
            call s%status%showMessage(trim(msg))
        end select
    end subroutine on_move

    subroutine on_wheel(event, data)
        type(QWheelEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (plot_state)
            s%zoom = min(max(s%zoom * 1.1_dp**(event%angleDeltaY() / 120.0_dp), 0.25_dp), 8.0_dp)
            call s%canvas%update()
        end select
    end subroutine on_wheel

    subroutine on_key(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (plot_state)
            select case (event%key())
            case (Qt_Key_Space)
                call s%pause%trigger()
            case (Qt_Key_C)
                s%nmarkers = 0
                call s%canvas%update()
            end select
        end select
    end subroutine on_key

    subroutine on_pause(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (plot_state)
            if (checked) then
                call s%timer%stop()
                call s%status%showMessage('Paused')
            else
                call s%timer%start()
                call s%status%showMessage('Running', 1500)
            end if
        end select
    end subroutine on_pause

    subroutine on_save(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        type(QPixmap) :: pix
        integer :: button
        select type (s => data)
        type is (plot_state)
            path = QFileDialog_getSaveFileName('Save image', 'plot.png', 'PNG images (*.png)', parent=s%window)
            if (path == '') return
            pix = s%canvas%grab()
            if (pix%save(path)) then
                call s%status%showMessage('Saved '//path, 3000)
            else
                button = QMessageBox_warning('Save image', 'Could not write '//path, parent=s%window)
            end if
            call pix%delete()
        end select
    end subroutine on_save

    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

end module plot_slots

program plot

    use qt
    use plot_slots
    implicit none

    type(QApplication) :: app
    type(plot_state), target :: s
    type(QMenuBar) :: bar
    type(QMenu) :: file_menu, view_menu
    type(QAction) :: save, quit
    character(len=1024) :: arg
    integer :: ierr, i

    app = QApplication()

    s%window = QMainWindow()
    call s%window%setWindowTitle('qt-fortran live plot')
    s%canvas = QtfWidget()
    call s%canvas%setMinimumSize(400, 250)
    call s%canvas%setMouseTracking(.true.)
    call s%window%setCentralWidget(s%canvas)
    s%status = s%window%statusBar()

    ! menus
    bar = s%window%menuBar()
    file_menu = bar%addMenu('&File')
    save = QAction('&Save image...', s%window)
    call save%setShortcut('Ctrl+S')
    call file_menu%addAction(save)
    call file_menu%addSeparator()
    quit = QAction('&Quit', s%window)
    call quit%setShortcut('Ctrl+Q')
    call file_menu%addAction(quit)
    view_menu = bar%addMenu('&View')
    s%pause = QAction('&Pause', s%window)
    call s%pause%setCheckable(.true.)
    call s%pause%setShortcut('Ctrl+P')
    call view_menu%addAction(s%pause)

    ! signals
    call save%triggered%connect(on_save, s)
    call quit%triggered%connect(on_quit)
    call s%pause%toggled%connect(on_pause, s)
    call s%canvas%paintEvent%connect(on_paint, s)
    call s%canvas%mousePressEvent%connect(on_press, s)
    call s%canvas%mouseMoveEvent%connect(on_move, s)
    call s%canvas%wheelEvent%connect(on_wheel, s)
    call s%canvas%keyPressEvent%connect(on_key, s)

    do i = 1, nsamples    ! start with a full trace
        call advance(s)
    end do
    s%timer = QTimer()
    call s%timer%timeout%connect(on_tick, s)
    call s%timer%start(30)

    ! `--screenshot file.png`: render some frames, save the window and exit
    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        s%nmarkers = 2
        s%marker_i(1:2) = [300.0_dp, 380.0_dp]
        s%marker_y(1:2) = [0.9_dp, -0.6_dp]
    end if

    call s%status%showMessage('Click to add markers, wheel to zoom, Space to pause')
    call s%window%resize(640, 400)
    call s%window%show()
    call s%canvas%setFocus()
    ierr = app%exec()

end program plot
