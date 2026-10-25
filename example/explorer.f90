!> Function explorer: an interactive plot of a periodic function, combining most
!> of the qt-fortran API in one application.
!>
!> * Left panel: function, amplitude, frequency, phase, line width, color,
!>   line style, grid/fill options and a title, all updating the plot live.
!> * Plot: left click adds a marker on the curve, right click removes the
!>   nearest marker, the wheel zooms, arrow keys pan, Escape resets the view.
!> * Menus and toolbar: export PNG, clear markers, animate the phase, zoom,
!>   about box.
!>
!> `explorer --screenshot out.png` renders a few animated frames, saves the
!> window and exits (useful headless, with QT_QPA_PLATFORM=offscreen).
module explorer_app

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    real(dp), parameter :: pi = acos(-1.0_dp)
    real(dp), parameter :: ymax = 2.4_dp            !! visible y range: [-ymax, ymax]
    real(dp), parameter :: default_span = 10.0_dp  !! half width of the visible x range
    integer, parameter :: npoints = 600            !! samples along the curve
    integer, parameter :: max_markers = 20
    integer, parameter :: nfunctions = 5

    character(len=12), parameter :: function_names(nfunctions) = &
        [character(len=12) :: 'Sine', 'Square', 'Sawtooth', 'Damped sine', 'Sinc']
    character(len=8), parameter :: color_names(5) = &
        [character(len=8) :: 'Blue', 'Red', 'Green', 'Purple', 'Orange']

    !> All widgets and view state of the explorer.
    type :: explorer_state
        ! main window
        type(QMainWindow) :: window
        type(QStatusBar) :: status
        type(QtfWidget) :: canvas
        type(QAction) :: animate
        type(QTimer) :: timer
        ! controls
        type(QComboBox) :: func
        type(QDoubleSpinBox) :: amplitude, phase
        type(QSlider) :: frequency
        type(QLabel) :: frequency_label
        type(QSpinBox) :: line_width
        type(QComboBox) :: color
        type(QRadioButton) :: solid, dashed, dotted
        type(QCheckBox) :: grid, fill
        type(QLineEdit) :: title
        ! view
        real(dp) :: x0 = 0.0_dp                 !! center of the visible x range
        real(dp) :: span = default_span         !! half width of the visible x range
        integer :: nmarkers = 0
        real(dp) :: marker_x(max_markers) = 0.0_dp
        ! --screenshot
        character(len=:), allocatable :: screenshot
        integer :: frames_left = 25
    end type explorer_state

contains

    ! ------------------------------------------------------------------
    ! model

    !> The selected function at `x` for the current control values.
    real(dp) function f(s, x)
        type(explorer_state), intent(in) :: s
        real(dp), intent(in) :: x
        real(dp) :: a, t
        a = s%amplitude%value()
        t = s%frequency%value() / 10.0_dp * x + s%phase%value()
        select case (s%func%currentIndex())
        case (0)
            f = a * sin(t)
        case (1)
            f = a * sign(1.0_dp, sin(t))
        case (2)
            f = a * 2 * (t / (2 * pi) - floor(t / (2 * pi) + 0.5_dp))
        case (3)
            f = a * exp(-0.15_dp * abs(x)) * sin(t)
        case default
            f = a
            if (abs(t) > 1.0e-9_dp) f = a * sin(t) / t
        end select
    end function f

    !> The color chosen in the color combo box.
    type(QColor) function curve_color(s)
        type(explorer_state), intent(in) :: s
        select case (s%color%currentIndex())
        case (1)
            curve_color = QColor(200, 40, 40)
        case (2)
            curve_color = QColor(30, 150, 70)
        case (3)
            curve_color = QColor(130, 60, 180)
        case (4)
            curve_color = QColor(230, 120, 20)
        case default
            curve_color = QColor(30, 100, 200)
        end select
    end function curve_color

    !> `v` with two decimals and a leading zero (e.g. -0.13).
    function fixed(v) result(text)
        real(dp), intent(in) :: v
        character(len=:), allocatable :: text
        character(len=16) :: buf
        write(buf, '(F16.2)') v
        text = trim(adjustl(buf))
    end function fixed

    !> A "nice" tick spacing (1, 2 or 5 times a power of ten) for a range of `width`.
    real(dp) function nice_step(width)
        real(dp), intent(in) :: width
        real(dp) :: raw, mag
        raw = width / 6
        mag = 10.0_dp**floor(log10(raw))
        if (raw / mag < 1.5_dp) then
            nice_step = mag
        else if (raw / mag < 3.5_dp) then
            nice_step = 2 * mag
        else
            nice_step = 5 * mag
        end if
    end function nice_step

    ! ------------------------------------------------------------------
    ! coordinates: plot rectangle (pixels) <-> data

    !> The plot rectangle inside a canvas of `w` x `h` pixels.
    subroutine plot_rect(w, h, left, right, top, bottom)
        integer, intent(in) :: w, h
        real(dp), intent(out) :: left, right, top, bottom
        left = 62
        right = w - 18
        top = 42
        bottom = h - 46
    end subroutine plot_rect

    !> Pixel x of data x.
    real(dp) function px(s, x, left, right)
        type(explorer_state), intent(in) :: s
        real(dp), intent(in) :: x, left, right
        px = left + (x - (s%x0 - s%span)) / (2 * s%span) * (right - left)
    end function px

    !> Pixel y of data y.
    real(dp) function py(y, top, bottom)
        real(dp), intent(in) :: y, top, bottom
        py = (top + bottom) / 2 - y / ymax * (bottom - top) / 2
    end function py

    !> Data x of pixel x.
    real(dp) function data_x(s, pixel)
        type(explorer_state), intent(in) :: s
        real(dp), intent(in) :: pixel
        real(dp) :: left, right, top, bottom
        call plot_rect(s%canvas%width(), s%canvas%height(), left, right, top, bottom)
        data_x = s%x0 - s%span + (pixel - left) / (right - left) * 2 * s%span
    end function data_x

    ! ------------------------------------------------------------------
    ! painting

    !> Draw the whole plot: background, grid, axes, curve, markers, title.
    subroutine on_paint(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        real(dp) :: left, right, top, bottom, step, x, y, xs(npoints), ys(npoints)
        integer :: i, style, decimals
        character(len=32) :: label, fmt
        character(len=:), allocatable :: title
        type(QColor) :: c

        select type (s => data)
        type is (explorer_state)
            call plot_rect(painter%deviceWidth(), painter%deviceHeight(), left, right, top, bottom)
            call painter%setRenderHint(QPainter_Antialiasing)
            call painter%fillRect(0, 0, painter%deviceWidth(), painter%deviceHeight(), QColor(250, 250, 252))
            call painter%fillRect(left, top, right - left, bottom - top, Qt_white)
            call painter%setFont(QFont(pointSize=9.0_dp))

            ! grid and tick labels
            step = nice_step(2 * s%span)
            decimals = max(0, -floor(log10(step)))
            write(fmt, '(A,I0,A)') '(F12.', decimals, ')'
            x = step * ceiling((s%x0 - s%span) / step)
            do while (x <= s%x0 + s%span)
                if (s%grid%isChecked()) then
                    call painter%setPen(QPen(Qt_lightGray, 1.0_dp, Qt_DotLine))
                    call painter%drawLine(px(s, x, left, right), top, px(s, x, left, right), bottom)
                end if
                if (decimals == 0) then
                    write(label, '(I0)') nint(x)
                else
                    write(label, fmt) x
                end if
                call painter%setPen(Qt_darkGray)
                call painter%drawText(px(s, x, left, right) - 30, bottom + 4, 60.0_dp, 16.0_dp, &
                                      Qt_AlignCenter, trim(adjustl(label)))
                x = x + step
            end do
            do i = -4, 4
                y = i * 0.5_dp
                if (s%grid%isChecked() .and. i /= 0) then
                    call painter%setPen(QPen(Qt_lightGray, 1.0_dp, Qt_DotLine))
                    call painter%drawLine(left, py(y, top, bottom), right, py(y, top, bottom))
                end if
                write(label, '(F5.1)') y
                call painter%setPen(Qt_darkGray)
                call painter%drawText(0.0_dp, py(y, top, bottom) - 8, left - 6, 16.0_dp, &
                                      ior(Qt_AlignRight, Qt_AlignVCenter), trim(adjustl(label)))
            end do

            ! axes (y = 0 and, if visible, x = 0) and frame
            call painter%setPen(QPen(Qt_gray, 1.0_dp))
            call painter%drawLine(left, py(0.0_dp, top, bottom), right, py(0.0_dp, top, bottom))
            if (abs(s%x0) < s%span) &
                call painter%drawLine(px(s, 0.0_dp, left, right), top, px(s, 0.0_dp, left, right), bottom)
            call painter%setBrush(QBrush(style=Qt_NoBrush))
            call painter%setPen(Qt_darkGray)
            call painter%drawRect(left, top, right - left, bottom - top)

            ! axis titles (the y title is rotated)
            call painter%drawText(left, bottom + 22, right - left, 16.0_dp, Qt_AlignCenter, 'x')
            call painter%save()
            call painter%translate(16.0_dp, (top + bottom) / 2)
            call painter%rotate(-90.0_dp)
            call painter%drawText(-40, -8, 80, 16, Qt_AlignCenter, 'f(x)')
            call painter%restore()

            ! the curve, optionally filled down to y = 0
            do i = 1, npoints
                x = s%x0 - s%span + (i - 1) * 2 * s%span / (npoints - 1)
                xs(i) = px(s, x, left, right)
                ys(i) = max(top, min(bottom, py(f(s, x), top, bottom)))
            end do
            c = curve_color(s)
            if (s%fill%isChecked()) then
                call painter%setPen(QPen(style=Qt_NoPen))
                call painter%setBrush(QColor(c%r, c%g, c%b, 50))
                call painter%drawPolygon([xs, xs(npoints), xs(1)], &
                                         [ys, py(0.0_dp, top, bottom), py(0.0_dp, top, bottom)])
            end if
            style = Qt_SolidLine
            if (s%dashed%isChecked()) style = Qt_DashLine
            if (s%dotted%isChecked()) style = Qt_DotLine
            call painter%setPen(QPen(c, real(s%line_width%value(), dp), style))
            call painter%drawPolyline(xs, ys)

            ! markers on the curve, with their values
            do i = 1, s%nmarkers
                x = s%marker_x(i)
                if (abs(x - s%x0) > s%span) cycle
                y = py(f(s, x), top, bottom)
                call painter%setPen(QPen(Qt_darkRed, 1.5_dp))
                call painter%setBrush(QColor(255, 220, 80, 220))
                call painter%drawEllipse(px(s, x, left, right) - 5, y - 5, 10.0_dp, 10.0_dp)
                call painter%setPen(Qt_black)
                call painter%drawText(px(s, x, left, right) + 8, y - 8, &
                                      '(' // fixed(x) // ', ' // fixed(f(s, x)) // ')')
            end do

            ! title
            title = s%title%text()
            if (title == '') title = trim(function_names(s%func%currentIndex() + 1))
            call painter%setPen(Qt_black)
            call painter%setFont(QFont(pointSize=13.0_dp, bold=.true.))
            call painter%drawText(left, 8.0_dp, right - left, 26.0_dp, Qt_AlignCenter, title)
        end select
    end subroutine on_paint

    ! ------------------------------------------------------------------
    ! control slots: one per signal argument kind, all just repaint

    !> Repaint after a signal without arguments.
    subroutine repaint(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call s%canvas%update()
        end select
    end subroutine repaint

    !> Repaint after a logical signal (check boxes, radio buttons).
    subroutine repaint_bool(value, data)
        logical, intent(in) :: value
        class(*), intent(inout), optional :: data
        call repaint(data)
    end subroutine repaint_bool

    !> Repaint after an integer signal (combo boxes, spin boxes).
    subroutine repaint_int(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        call repaint(data)
    end subroutine repaint_int

    !> Repaint after a real signal (double spin boxes).
    subroutine repaint_double(value, data)
        real(dp), intent(in) :: value
        class(*), intent(inout), optional :: data
        call repaint(data)
    end subroutine repaint_double

    !> Repaint after a string signal (the title line edit).
    subroutine repaint_string(value, data)
        character(len=*), intent(in) :: value
        class(*), intent(inout), optional :: data
        call repaint(data)
    end subroutine repaint_string

    !> Show the frequency next to its slider, then repaint.
    subroutine on_frequency(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        character(len=16) :: text
        select type (s => data)
        type is (explorer_state)
            write(text, '(F4.1)') value / 10.0_dp
            call s%frequency_label%setText(trim(adjustl(text)))
            call s%canvas%update()
        end select
    end subroutine on_frequency

    !> Restore all controls and the view to their defaults.
    subroutine on_reset(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call s%func%setCurrentIndex(0)
            call s%amplitude%setValue(1.0_dp)
            call s%frequency%setValue(10)
            call s%phase%setValue(0.0_dp)
            call s%line_width%setValue(2)
            call s%color%setCurrentIndex(0)
            call s%solid%setChecked(.true.)
            call s%grid%setChecked(.true.)
            call s%fill%setChecked(.false.)
            call s%title%clear()
            call reset_view(s)
            call s%status%showMessage('Reset', 2000)
        end select
    end subroutine on_reset

    !> Center the view on x = 0 at the default zoom.
    subroutine reset_view(s)
        type(explorer_state), intent(inout) :: s
        s%x0 = 0.0_dp
        s%span = default_span
        call s%canvas%update()
    end subroutine reset_view

    ! ------------------------------------------------------------------
    ! canvas input slots

    !> Left click: add a marker on the curve. Right click: remove the nearest marker.
    subroutine on_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        real(dp) :: x
        integer :: i
        select type (s => data)
        type is (explorer_state)
            x = data_x(s, event%x())
            if (event%button() == Qt_LeftButton) then
                if (s%nmarkers == max_markers) then
                    call s%status%showMessage('Marker limit reached', 2000)
                    return
                end if
                s%nmarkers = s%nmarkers + 1
                s%marker_x(s%nmarkers) = x
            else if (event%button() == Qt_RightButton .and. s%nmarkers > 0) then
                i = minloc(abs(s%marker_x(1:s%nmarkers) - x), dim=1)
                s%marker_x(i:s%nmarkers - 1) = s%marker_x(i + 1:s%nmarkers)
                s%nmarkers = s%nmarkers - 1
            end if
            call s%canvas%update()
        end select
    end subroutine on_press

    !> Show the data coordinates under the cursor in the status bar.
    subroutine on_move(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        character(len=64) :: msg
        real(dp) :: x
        select type (s => data)
        type is (explorer_state)
            x = data_x(s, event%x())
            write(msg, '(A,F8.3,A,F8.3)') 'x =', x, '    f(x) =', f(s, x)
            call s%status%showMessage(trim(msg))
        end select
    end subroutine on_move

    !> Zoom the x range around the center (wheel away from you zooms in).
    subroutine on_wheel(event, data)
        type(QWheelEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call zoom(s, 0.9_dp**(event%angleDeltaY() / 120.0_dp))
        end select
    end subroutine on_wheel

    !> Scale the visible x range by `factor`.
    subroutine zoom(s, factor)
        type(explorer_state), intent(inout) :: s
        real(dp), intent(in) :: factor
        s%span = min(max(s%span * factor, 0.5_dp), 200.0_dp)
        call s%canvas%update()
    end subroutine zoom

    !> Arrow keys pan, +/- zoom, Escape resets the view, Space toggles animation.
    subroutine on_key(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            select case (event%key())
            case (Qt_Key_Left)
                s%x0 = s%x0 - 0.1_dp * s%span
            case (Qt_Key_Right)
                s%x0 = s%x0 + 0.1_dp * s%span
            case (Qt_Key_Plus)
                call zoom(s, 0.8_dp)
            case (Qt_Key_Minus)
                call zoom(s, 1.25_dp)
            case (Qt_Key_Escape)
                call reset_view(s)
            case (Qt_Key_Space)
                call s%animate%trigger()
            end select
            call s%canvas%update()
        end select
    end subroutine on_key

    !> Report the plot size while the window is resized.
    subroutine on_resize(event, data)
        type(QResizeEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        character(len=32) :: msg
        select type (s => data)
        type is (explorer_state)
            write(msg, '(A,I0,A,I0)') 'Plot size ', event%width(), ' x ', event%height()
            call s%status%showMessage(trim(msg), 1500)
        end select
    end subroutine on_resize

    ! ------------------------------------------------------------------
    ! animation

    !> Start or stop animating the phase.
    subroutine on_animate(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            if (checked) then
                call s%timer%start(30)
                call s%status%showMessage('Animating (Space to stop)')
            else
                call s%timer%stop()
                call s%status%showMessage('Stopped', 1500)
            end if
        end select
    end subroutine on_animate

    !> Advance the phase; its spin box emits valueChanged, which repaints.
    subroutine on_tick(data)
        class(*), intent(inout), optional :: data
        real(dp) :: phase
        type(QPixmap) :: pix
        select type (s => data)
        type is (explorer_state)
            phase = s%phase%value() + 0.06_dp
            if (phase > 2 * pi) phase = phase - 2 * pi
            call s%phase%setValue(phase)
            if (allocated(s%screenshot)) then
                s%frames_left = s%frames_left - 1
                if (s%frames_left == 0) then
                    pix = s%window%grab()
                    if (.not. pix%save(s%screenshot)) write(*,'(A)') 'could not save '//s%screenshot
                    call pix%delete()
                    call QApplication_quit()
                end if
            end if
        end select
    end subroutine on_tick

    ! ------------------------------------------------------------------
    ! menu / toolbar commands

    !> Export the plot as a PNG chosen in a file dialog.
    subroutine on_export(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        type(QPixmap) :: pix
        integer :: button
        select type (s => data)
        type is (explorer_state)
            path = QFileDialog_getSaveFileName('Export plot', 'explorer.png', 'PNG images (*.png)', &
                                               parent=s%window)
            if (path == '') return
            pix = s%canvas%grab()
            if (pix%save(path)) then
                call s%status%showMessage('Exported '//path, 3000)
            else
                button = QMessageBox_warning('Export plot', 'Could not write '//path, parent=s%window)
            end if
            call pix%delete()
        end select
    end subroutine on_export

    !> Ask, then remove all markers.
    subroutine on_clear_markers(data)
        class(*), intent(inout), optional :: data
        character(len=64) :: question
        select type (s => data)
        type is (explorer_state)
            if (s%nmarkers == 0) then
                call s%status%showMessage('No markers to clear', 2000)
                return
            end if
            write(question, '(A,I0,A)') 'Remove all ', s%nmarkers, ' markers?'
            if (QMessageBox_question('Clear markers', trim(question), parent=s%window) == QMessageBox_Yes) then
                s%nmarkers = 0
                call s%canvas%update()
            end if
        end select
    end subroutine on_clear_markers

    !> Zoom in on the plot.
    subroutine on_zoom_in(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call zoom(s, 0.8_dp)
        end select
    end subroutine on_zoom_in

    !> Zoom out of the plot.
    subroutine on_zoom_out(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call zoom(s, 1.25_dp)
        end select
    end subroutine on_zoom_out

    !> Reset the zoom and pan.
    subroutine on_zoom_reset(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call reset_view(s)
        end select
    end subroutine on_zoom_reset

    !> Show the about box.
    subroutine on_about(data)
        class(*), intent(inout), optional :: data
        integer :: button
        select type (s => data)
        type is (explorer_state)
            button = QMessageBox_information('About Function Explorer', &
                'Function Explorer' // new_line('a') // new_line('a') // &
                'Written in Modern Fortran with qt-fortran.' // new_line('a') // &
                'Left click: add marker' // new_line('a') // &
                'Right click: remove nearest marker' // new_line('a') // &
                'Wheel or +/-: zoom    Arrows: pan    Esc: reset view', parent=s%window)
        end select
    end subroutine on_about

    !> Quit the application.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

    ! ------------------------------------------------------------------
    ! construction

    !> Create a menu/toolbar action, connected to `slot`.
    function new_action(s, text, shortcut, tip, slot) result(a)
        type(explorer_state), intent(inout), target :: s
        character(len=*), intent(in) :: text, shortcut, tip
        procedure(qt_slot) :: slot
        type(QAction) :: a
        a = QAction(text, s%window)
        if (shortcut /= '') call a%setShortcut(shortcut)
        call a%setStatusTip(tip)
        call a%triggered%connect(slot, s)
    end function new_action

    !> Build the controls panel (left side of the window).
    function build_panel(s) result(panel)
        type(explorer_state), intent(inout), target :: s
        type(QWidget) :: panel
        type(QGridLayout) :: grid
        type(QVBoxLayout) :: styles
        type(QPushButton) :: reset
        integer :: row

        panel = QWidget()
        grid = QGridLayout(panel)
        call grid%setSpacing(8)

        s%func = QComboBox()
        call s%func%addItems(function_names)
        s%amplitude = QDoubleSpinBox()
        call s%amplitude%setRange(0.1_dp, 2.0_dp)
        call s%amplitude%setSingleStep(0.1_dp)
        call s%amplitude%setValue(1.0_dp)
        s%frequency = QSlider(Qt_Horizontal)
        call s%frequency%setRange(1, 50)
        call s%frequency%setValue(10)
        s%frequency_label = QLabel('1.0')
        s%phase = QDoubleSpinBox()
        call s%phase%setRange(0.0_dp, 2 * pi)
        call s%phase%setSingleStep(0.1_dp)
        call s%phase%setSuffix(' rad')
        s%line_width = QSpinBox()
        call s%line_width%setRange(1, 8)
        call s%line_width%setValue(2)
        call s%line_width%setSuffix(' px')
        s%color = QComboBox()
        call s%color%addItems(color_names)
        s%title = QLineEdit()
        call s%title%setPlaceholderText('(function name)')
        call s%title%setToolTip('Plot title')

        row = 0
        call grid%addWidget(QLabel('Function'), row, 0)
        call grid%addWidget(s%func, row, 1, columnSpan=2)
        row = row + 1
        call grid%addWidget(QLabel('Amplitude'), row, 0)
        call grid%addWidget(s%amplitude, row, 1, columnSpan=2)
        row = row + 1
        call grid%addWidget(QLabel('Frequency'), row, 0)
        call grid%addWidget(s%frequency, row, 1)
        call grid%addWidget(s%frequency_label, row, 2)
        row = row + 1
        call grid%addWidget(QLabel('Phase'), row, 0)
        call grid%addWidget(s%phase, row, 1, columnSpan=2)
        row = row + 1
        call grid%addWidget(QLabel('Line width'), row, 0)
        call grid%addWidget(s%line_width, row, 1, columnSpan=2)
        row = row + 1
        call grid%addWidget(QLabel('Color'), row, 0)
        call grid%addWidget(s%color, row, 1, columnSpan=2)
        row = row + 1
        call grid%addWidget(QLabel('Title'), row, 0)
        call grid%addWidget(s%title, row, 1, columnSpan=2)

        ! line style: radio buttons with the same parent are mutually exclusive
        row = row + 1
        call grid%addWidget(QLabel('Line style'), row, 0, alignment=Qt_AlignTop)
        styles = QVBoxLayout()
        s%solid = QRadioButton('Solid')
        s%dashed = QRadioButton('Dashed')
        s%dotted = QRadioButton('Dotted')
        call s%solid%setChecked(.true.)
        call styles%addWidget(s%solid)
        call styles%addWidget(s%dashed)
        call styles%addWidget(s%dotted)
        call grid%addLayout(styles, row, 1, columnSpan=2)

        row = row + 1
        s%grid = QCheckBox('Show grid')
        call s%grid%setChecked(.true.)
        call grid%addWidget(s%grid, row, 0, columnSpan=3)
        row = row + 1
        s%fill = QCheckBox('Fill under curve')
        call grid%addWidget(s%fill, row, 0, columnSpan=3)

        row = row + 1
        reset = QPushButton('Reset')
        call reset%setToolTip('Restore the default settings')
        call grid%addWidget(reset, row, 0, columnSpan=3)
        call grid%setRowStretch(row + 1, 1)
        call grid%setColumnStretch(1, 1)

        ! every control repaints the plot
        call s%func%currentIndexChanged%connect(repaint_int, s)
        call s%amplitude%valueChanged%connect(repaint_double, s)
        call s%frequency%valueChanged%connect(on_frequency, s)
        call s%phase%valueChanged%connect(repaint_double, s)
        call s%line_width%valueChanged%connect(repaint_int, s)
        call s%color%currentIndexChanged%connect(repaint_int, s)
        call s%title%textChanged%connect(repaint_string, s)
        call s%solid%toggled%connect(repaint_bool, s)
        call s%dashed%toggled%connect(repaint_bool, s)
        call s%dotted%toggled%connect(repaint_bool, s)
        call s%grid%toggled%connect(repaint_bool, s)
        call s%fill%toggled%connect(repaint_bool, s)
        call reset%clicked%connect(on_reset, s)
    end function build_panel

    !> Build the main window: menus, toolbar, panel, canvas, status bar.
    subroutine build_window(s)
        type(explorer_state), intent(inout), target :: s
        type(QWidget) :: central
        type(QHBoxLayout) :: hbox
        type(QMenuBar) :: bar
        type(QMenu) :: file_menu, view_menu, zoom_menu, help_menu
        type(QToolBar) :: tools
        type(QAction) :: export, clear, quit, zoom_in, zoom_out, zoom_reset, about

        s%window = QMainWindow()
        call s%window%setWindowTitle('Function Explorer - qt-fortran')
        s%status = s%window%statusBar()

        ! central area: controls | canvas
        central = QWidget()
        hbox = QHBoxLayout(central)
        call hbox%addWidget(build_panel(s))
        s%canvas = QtfWidget()
        call s%canvas%setMinimumSize(480, 320)
        call s%canvas%setMouseTracking(.true.)
        call hbox%addWidget(s%canvas, stretch=1)
        call s%window%setCentralWidget(central)

        call s%canvas%paintEvent%connect(on_paint, s)
        call s%canvas%mousePressEvent%connect(on_press, s)
        call s%canvas%mouseMoveEvent%connect(on_move, s)
        call s%canvas%wheelEvent%connect(on_wheel, s)
        call s%canvas%keyPressEvent%connect(on_key, s)
        call s%canvas%resizeEvent%connect(on_resize, s)

        ! actions
        export = new_action(s, '&Export image...', 'Ctrl+E', 'Save the plot as a PNG file', on_export)
        clear = new_action(s, '&Clear markers', 'Ctrl+K', 'Remove all markers', on_clear_markers)
        quit = new_action(s, '&Quit', 'Ctrl+Q', 'Quit the application', on_quit)
        zoom_in = new_action(s, 'Zoom &in', 'Ctrl+=', 'Zoom in', on_zoom_in)
        zoom_out = new_action(s, 'Zoom &out', 'Ctrl+-', 'Zoom out', on_zoom_out)
        zoom_reset = new_action(s, '&Reset view', 'Ctrl+0', 'Reset zoom and pan', on_zoom_reset)
        about = new_action(s, '&About', '', 'About this program', on_about)
        s%animate = QAction('&Animate phase', s%window)
        call s%animate%setCheckable(.true.)
        call s%animate%setShortcut('Ctrl+A')
        call s%animate%setStatusTip('Advance the phase continuously')
        call s%animate%toggled%connect(on_animate, s)

        ! menus (with a submenu)
        bar = s%window%menuBar()
        file_menu = bar%addMenu('&File')
        call file_menu%addAction(export)
        call file_menu%addSeparator()
        call file_menu%addAction(quit)
        view_menu = bar%addMenu('&View')
        call view_menu%addAction(s%animate)
        call view_menu%addAction(clear)
        zoom_menu = view_menu%addMenu('&Zoom')
        call zoom_menu%addAction(zoom_in)
        call zoom_menu%addAction(zoom_out)
        call zoom_menu%addAction(zoom_reset)
        help_menu = bar%addMenu('&Help')
        call help_menu%addAction(about)

        ! toolbar (with an embedded widget)
        tools = s%window%addToolBar('Main')
        call tools%addAction(export)
        call tools%addSeparator()
        call tools%addAction(s%animate)
        call tools%addAction(clear)
        call tools%addSeparator()
        call tools%addAction(zoom_in)
        call tools%addAction(zoom_out)
        call tools%addAction(zoom_reset)
        call tools%addSeparator()
        call tools%addWidget(QLabel(' Click the plot to add markers '))

        s%timer = QTimer()
        call s%timer%timeout%connect(on_tick, s)
    end subroutine build_window

end module explorer_app

!> Function explorer (see the module documentation).
program explorer

    use qt
    use explorer_app
    implicit none

    type(QApplication) :: app
    type(explorer_state), target :: s
    character(len=1024) :: arg
    integer :: ierr

    app = QApplication()
    call build_window(s)

    ! `--screenshot file.png`: show some features, animate a few frames, save, exit
    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        call s%func%setCurrentIndex(3)
        call s%amplitude%setValue(1.8_dp)
        call s%fill%setChecked(.true.)
        call s%color%setCurrentIndex(3)
        call s%title%setText('Damped oscillation')
        s%nmarkers = 2
        s%marker_x(1:2) = [-4.5_dp, 2.0_dp]
        call s%animate%setChecked(.true.)
    end if

    call s%status%showMessage('Ready - click the plot to add markers')
    call s%window%resize(980, 600)
    call s%window%show()
    call s%canvas%setFocus()
    ierr = app%exec()

end program explorer
