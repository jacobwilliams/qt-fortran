!> Function explorer: an interactive plot of a periodic function, combining most
!> of the qt-fortran API in one application.
!>
!> * Left panel: function, amplitude, frequency, phase, line width, color,
!>   line style, grid/fill options and a title, all updating the plot live.
!> * Plot: left click adds a marker on the curve, right click removes the
!>   nearest marker, the wheel zooms, arrow keys pan, Escape resets the view.
!> * Menus and toolbar: export PNG, clear markers, animate the phase, zoom,
!>   about box.
!> * Undo/redo (QUndoStack) of every marker change: Edit menu, toolbar, and a
!>   History tab (QUndoView).
!> * Markers dock: a table of the markers (QtfTableModel). The x column is
!>   edited with a spin box (QtfItemDelegate), and a click on a column title
!>   sorts the markers (sortRequested).
!> * Function library dock: a tree (QtfTreeModel) kept in sync with the
!>   function box, filtered by a search field (QSortFilterProxyModel, with a
!>   QCompleter).
!> * File > New plot: a wizard (QWizard) with a validated amplitude
!>   (QDoubleValidator) and a mandatory title. View > Set range: a dialog with
!>   validated fields and OK / Cancel / Restore Defaults (QDialogButtonBox).
!>   Help > Contents: linked help (QTextBrowser). View > Full screen.
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

    ! the function library tree: node i's name, formula, parent and function (0-based; -1: a group)
    integer, parameter :: nnodes = 7
    character(len=12), parameter :: node_names(nnodes) = [character(len=12) :: &
        'Periodic', 'Sine', 'Square', 'Sawtooth', 'Decaying', 'Damped sine', 'Sinc']
    character(len=24), parameter :: node_formulas(nnodes) = [character(len=24) :: &
        '', 'A sin(t)', 'A sgn(sin(t))', 'A saw(t)', '', 'A exp(-0.15|x|) sin(t)', 'A sin(t)/t']
    integer, parameter :: node_parents(nnodes) = [0, 1, 1, 1, 0, 5, 5]
    integer, parameter :: node_function(nnodes) = [-1, 0, 1, 2, -1, 3, 4]

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
        ! docks: function library (tree + search) and markers (table + undo history)
        type(QtfTreeModel) :: library
        type(QSortFilterProxyModel) :: library_filter
        type(QTreeView) :: library_view
        type(QLineEdit) :: library_search
        type(QtfTableModel) :: marker_model
        type(QTableView) :: marker_table
        type(QtfItemDelegate) :: x_delegate
        type(QAction) :: fullscreen
        ! undo: the marker sets before and after each command (command id = column)
        type(QUndoStack) :: undo
        integer :: ncommands = 0
        integer, allocatable :: nbefore(:), nafter(:)
        real(dp), allocatable :: before(:, :), after(:, :)
        ! the dialogs (alive while shown)
        type(QDialog) :: range_dialog
        type(QLineEdit) :: range_center, range_span
        type(QDialogButtonBox) :: range_buttons
        type(QWizardPage) :: wizard_parameters
        type(QLineEdit) :: wizard_amplitude
        type(QDialog) :: help
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
            if (.not. s%marker_model%isNull()) call s%marker_model%refresh()   ! the f(x) column
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
        real(dp) :: x, xs(max_markers)
        integer :: i, n
        select type (s => data)
        type is (explorer_state)
            x = data_x(s, event%x())
            n = s%nmarkers
            xs = s%marker_x
            if (event%button() == Qt_LeftButton) then
                if (n == max_markers) then
                    call s%status%showMessage('Marker limit reached', 2000)
                    return
                end if
                n = n + 1
                xs(n) = x
                call change_markers(s, 'Add marker at x = ' // fixed(x), n, xs)
            else if (event%button() == Qt_RightButton .and. n > 0) then
                i = minloc(abs(xs(1:n) - x), dim=1)
                x = xs(i)
                xs(i:n - 1) = xs(i + 1:n)
                n = n - 1
                call change_markers(s, 'Remove marker at x = ' // fixed(x), n, xs)
            end if
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
            if (QMessageBox_question('Clear markers', trim(question) // ' (Edit > Undo restores them.)', &
                                     parent=s%window) == QMessageBox_Yes) then
                call change_markers(s, 'Clear markers', 0, s%marker_x)
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
    ! markers: every change is an undoable command (QUndoStack)

    !> Record a change of the marker set (to `n` markers at `xs`) as a command
    !> named `text`, and perform it.
    subroutine change_markers(s, text, n, xs)
        type(explorer_state), intent(inout) :: s
        character(len=*), intent(in) :: text
        integer, intent(in) :: n
        real(dp), intent(in) :: xs(:)
        integer :: id
        integer, allocatable :: ntmp(:)
        real(dp), allocatable :: xtmp(:, :)
        if (.not. allocated(s%nbefore)) then
            allocate(s%nbefore(16), s%nafter(16), s%before(max_markers, 16), s%after(max_markers, 16))
        else if (s%ncommands == size(s%nbefore)) then      ! grow the history
            allocate(ntmp(2 * s%ncommands)); ntmp(1:s%ncommands) = s%nbefore; call move_alloc(ntmp, s%nbefore)
            allocate(ntmp(2 * s%ncommands)); ntmp(1:s%ncommands) = s%nafter; call move_alloc(ntmp, s%nafter)
            allocate(xtmp(max_markers, 2 * s%ncommands)); xtmp(:, 1:s%ncommands) = s%before
            call move_alloc(xtmp, s%before)
            allocate(xtmp(max_markers, 2 * s%ncommands)); xtmp(:, 1:s%ncommands) = s%after
            call move_alloc(xtmp, s%after)
        end if
        s%ncommands = s%ncommands + 1
        id = s%ncommands
        s%nbefore(id) = s%nmarkers
        s%before(:, id) = s%marker_x
        s%nafter(id) = n
        s%after(:, id) = 0
        s%after(1:n, id) = xs(1:n)
        call s%undo%push(text, id)        ! calls on_redo(id): performs the change
    end subroutine change_markers

    !> Show a marker set: the plot and the marker table.
    subroutine apply_markers(s, n, xs)
        type(explorer_state), intent(inout) :: s
        integer, intent(in) :: n
        real(dp), intent(in) :: xs(:)
        s%nmarkers = n
        s%marker_x = xs
        if (s%marker_model%rowCount() /= n) then
            call s%marker_model%setRowCount(n)
        else
            call s%marker_model%refresh()
        end if
        call s%canvas%update()
    end subroutine apply_markers

    !> Perform (or redo) command `id`.
    subroutine on_redo(id, data)
        integer, intent(in) :: id
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call apply_markers(s, s%nafter(id), s%after(:, id))
        end select
    end subroutine on_redo

    !> Undo command `id`.
    subroutine on_undo(id, data)
        integer, intent(in) :: id
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call apply_markers(s, s%nbefore(id), s%before(:, id))
        end select
    end subroutine on_undo

    !> A cell of the marker table: number, x (editable), f(x).
    subroutine on_marker_cell(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            if (row >= s%nmarkers) return
            select case (column)
            case (0)
                call request%setInt(row + 1)
            case (1)
                call request%setText(fixed(s%marker_x(row + 1)))
            case default
                call request%setText(fixed(f(s, s%marker_x(row + 1))))
            end select
        end select
    end subroutine on_marker_cell

    !> The x of a marker was edited in the table: move it (undoable).
    subroutine on_marker_edited(row, column, text, data)
        integer, intent(in) :: row, column
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        real(dp) :: x, xs(max_markers)
        integer :: ios
        character(len=8) :: number
        select type (s => data)
        type is (explorer_state)
            if (column /= 1 .or. row >= s%nmarkers) return
            read(text, *, iostat=ios) x
            if (ios /= 0) return
            xs = s%marker_x
            xs(row + 1) = x
            write(number, '(I0)') row + 1
            call change_markers(s, 'Move marker ' // trim(number) // ' to x = ' // fixed(x), s%nmarkers, xs)
        end select
    end subroutine on_marker_edited

    !> A column title of the marker table was clicked: sort the markers by x
    !> (columns # and x) or by f(x) (undoable).
    subroutine on_marker_sort(column, order, data)
        integer, intent(in) :: column, order
        class(*), intent(inout), optional :: data
        real(dp) :: key(max_markers), xs(max_markers), k, x
        integer :: i, j, n
        select type (s => data)
        type is (explorer_state)
            n = s%nmarkers
            if (n < 2) return
            xs = s%marker_x
            do i = 1, n
                key(i) = merge(f(s, xs(i)), xs(i), column == 2)
            end do
            if (order == Qt_DescendingOrder) key(1:n) = -key(1:n)
            do i = 2, n                       ! insertion sort (at most max_markers)
                k = key(i)
                x = xs(i)
                j = i - 1
                do while (j >= 1)
                    if (key(j) <= k) exit
                    key(j + 1) = key(j)
                    xs(j + 1) = xs(j)
                    j = j - 1
                end do
                key(j + 1) = k
                xs(j + 1) = x
            end do
            if (all(xs(1:n) == s%marker_x(1:n))) return
            call change_markers(s, 'Sort markers by ' // trim(merge('f(x)', 'x   ', column == 2)), n, xs)
        end select
    end subroutine on_marker_sort

    ! ------------------------------------------------------------------
    ! function library (a tree model, filtered by a proxy model)

    !> A cell of the library tree: name, formula.
    subroutine on_library_cell(node, column, request, data)
        integer, intent(in) :: node, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        if (column == 0) then
            call request%setText(trim(node_names(node)))
        else
            call request%setText(trim(node_formulas(node)))
        end if
    end subroutine on_library_cell

    !> A function was chosen in the library: select it in the panel.
    subroutine on_library_node(node, data)
        integer, intent(in) :: node
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            if (node < 1) return
            if (node_function(node) >= 0) call s%func%setCurrentIndex(node_function(node))
        end select
    end subroutine on_library_node

    !> The function box changed: show the function in the library.
    subroutine on_function_changed(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        integer :: node
        select type (s => data)
        type is (explorer_state)
            node = findloc(node_function, index, dim=1)
            if (node > 0 .and. s%library_view%currentNode() /= node) call s%library_view%setCurrentNode(node)
        end select
    end subroutine on_function_changed

    !> Filter the library by the search text (groups with a match stay).
    subroutine on_library_search(text, data)
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call s%library_filter%setFilterFixedString(text)
            call s%library_view%expandAll()
        end select
    end subroutine on_library_search

    ! ------------------------------------------------------------------
    ! View > Set range: a dialog with validated fields and a button box

    !> Show the range dialog; apply the values if accepted.
    subroutine on_set_range(data)
        class(*), intent(inout), optional :: data
        type(QFormLayout) :: form
        type(QVBoxLayout) :: vbox
        real(dp) :: center, span
        integer :: ios1, ios2
        character(len=:), allocatable :: text
        select type (s => data)
        type is (explorer_state)
            s%range_dialog = QDialog(s%window)
            call s%range_dialog%setWindowTitle('Plot range')
            vbox = QVBoxLayout(s%range_dialog)
            form = QFormLayout()
            s%range_center = QLineEdit(fixed(s%x0))
            call s%range_center%setValidator(QDoubleValidator(-1.0e6_dp, 1.0e6_dp, 3, s%range_dialog))
            s%range_span = QLineEdit(fixed(s%span))
            call s%range_span%setValidator(QDoubleValidator(0.1_dp, 1.0e6_dp, 3, s%range_dialog))
            call s%range_span%setToolTip('Half the width of the visible x range (at least 0.1)')
            call form%addRow('Center x', s%range_center)
            call form%addRow('Half width', s%range_span)
            call vbox%addLayout(form)
            s%range_buttons = QDialogButtonBox(ior(ior(QDialogButtonBox_Ok, QDialogButtonBox_Cancel), &
                                                   QDialogButtonBox_RestoreDefaults))
            call vbox%addWidget(s%range_buttons)
            call s%range_center%textChanged%connect(on_range_text, s)
            call s%range_span%textChanged%connect(on_range_text, s)
            call s%range_buttons%clicked%connect(on_range_button, s)
            if (s%range_dialog%exec() == QDialog_Accepted) then
                text = s%range_center%text()
                read(text, *, iostat=ios1) center
                text = s%range_span%text()
                read(text, *, iostat=ios2) span
                if (ios1 == 0 .and. ios2 == 0) then
                    s%x0 = center
                    s%span = span
                    call s%canvas%update()
                end if
            end if
            call s%range_dialog%delete()
        end select
    end subroutine on_set_range

    !> Enable OK only while both fields hold acceptable numbers.
    subroutine on_range_text(text, data)
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        type(QPushButton) :: ok
        select type (s => data)
        type is (explorer_state)
            ok = s%range_buttons%button(QDialogButtonBox_Ok)
            call ok%setEnabled(s%range_center%hasAcceptableInput() .and. s%range_span%hasAcceptableInput())
        end select
    end subroutine on_range_text

    !> A button of the range dialog: OK, Cancel or Restore Defaults.
    subroutine on_range_button(button, data)
        integer, intent(in) :: button
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            select case (button)
            case (QDialogButtonBox_Ok)
                call s%range_dialog%accept()
            case (QDialogButtonBox_Cancel)
                call s%range_dialog%reject()
            case (QDialogButtonBox_RestoreDefaults)
                call s%range_center%setText(fixed(0.0_dp))
                call s%range_span%setText(fixed(default_span))
            end select
        end select
    end subroutine on_range_button

    ! ------------------------------------------------------------------
    ! File > New plot: a wizard

    !> Lead through function, parameters and title; apply them on Finish.
    subroutine on_new_plot(data)
        class(*), intent(inout), optional :: data
        type(QWizard) :: wizard
        type(QWizardPage) :: page1, page3
        type(QVBoxLayout) :: box1, box3
        type(QFormLayout) :: form
        type(QComboBox) :: choice
        type(QDoubleSpinBox) :: frequency
        type(QLineEdit) :: title
        type(QCheckBox) :: clear
        real(dp) :: amplitude
        integer :: ios
        character(len=:), allocatable :: text
        select type (s => data)
        type is (explorer_state)
            wizard = QWizard(s%window)
            call wizard%setWindowTitle('New plot')

            page1 = QWizardPage()
            call page1%setTitle('Function')
            call page1%setSubTitle('Which function do you want to plot?')
            box1 = QVBoxLayout(page1)
            choice = QComboBox()
            call choice%addItems(function_names)
            call choice%setCurrentIndex(s%func%currentIndex())
            call box1%addWidget(choice)
            call page1%registerField('function', choice)

            s%wizard_parameters = QWizardPage()
            call s%wizard_parameters%setTitle('Parameters')
            call s%wizard_parameters%setSubTitle('The amplitude must be between 0.1 and 2.')
            form = QFormLayout(s%wizard_parameters)
            s%wizard_amplitude = QLineEdit(fixed(s%amplitude%value()))
            call s%wizard_amplitude%setValidator(QDoubleValidator(0.1_dp, 2.0_dp, 2, s%wizard_parameters))
            call s%wizard_amplitude%textChanged%connect(on_wizard_amplitude, s)
            frequency = QDoubleSpinBox()
            call frequency%setRange(0.1_dp, 5.0_dp)
            call frequency%setSingleStep(0.1_dp)
            call frequency%setValue(s%frequency%value() / 10.0_dp)
            call form%addRow('Amplitude', s%wizard_amplitude)
            call form%addRow('Frequency', frequency)
            call s%wizard_parameters%registerField('amplitude', s%wizard_amplitude)
            call s%wizard_parameters%registerField('frequency', frequency)

            page3 = QWizardPage()
            call page3%setTitle('Title')
            call page3%setSubTitle('A title is required.')
            call page3%setFinalPage(.true.)
            box3 = QVBoxLayout(page3)
            title = QLineEdit(s%title%text())
            call title%setPlaceholderText('Plot title')
            clear = QCheckBox('Clear the markers')
            call box3%addWidget(title)
            call box3%addWidget(clear)
            call page3%registerField('title*', title)      ! '*': mandatory
            call page3%registerField('clear', clear)

            call wizard%addPage(page1)
            call wizard%addPage(s%wizard_parameters)
            call wizard%addPage(page3)
            if (wizard%exec() == QDialog_Accepted) then
                call s%func%setCurrentIndex(wizard%intField('function'))
                text = wizard%stringField('amplitude')
                read(text, *, iostat=ios) amplitude
                if (ios == 0) call s%amplitude%setValue(amplitude)
                call s%frequency%setValue(nint(10 * wizard%doubleField('frequency')))
                call s%title%setText(wizard%stringField('title'))
                if (wizard%boolField('clear') .and. s%nmarkers > 0) &
                    call change_markers(s, 'Clear markers', 0, s%marker_x)
                call s%status%showMessage('New plot: ' // wizard%stringField('title'), 3000)
            end if
            call wizard%delete()
        end select
    end subroutine on_new_plot

    !> The wizard's Next waits for an acceptable amplitude.
    subroutine on_wizard_amplitude(text, data)
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call s%wizard_parameters%setComplete(s%wizard_amplitude%hasAcceptableInput())
        end select
    end subroutine on_wizard_amplitude

    ! ------------------------------------------------------------------
    ! Help > Contents, View > Full screen

    !> Show the help in a text browser (links jump within the page); the
    !> window is created once and then shown again.
    subroutine on_help(data)
        class(*), intent(inout), optional :: data
        type(QVBoxLayout) :: vbox
        type(QTextBrowser) :: browser
        type(QDialogButtonBox) :: buttons
        select type (s => data)
        type is (explorer_state)
            if (.not. s%help%isNull()) then
                call s%help%show()
                call s%help%raise()
                return
            end if
            s%help = QDialog(s%window)
            call s%help%setWindowTitle('Function Explorer help')
            call s%help%resize(520, 420)
            vbox = QVBoxLayout(s%help)
            browser = QTextBrowser()
            call browser%setHtml( &
                '<h2>Function Explorer</h2>' // &
                '<p>Contents: <a href="#plot">the plot</a> | <a href="#markers">markers</a> | ' // &
                '<a href="#library">function library</a></p>' // &
                '<h3><a name="plot"></a>The plot</h3>' // &
                '<p>Change the function and its style in the left panel. The wheel zooms, the arrow keys ' // &
                'pan and Escape resets the view; View &gt; Set range sets it exactly.</p>' // &
                '<h3><a name="markers"></a>Markers</h3>' // &
                '<p>Left click adds a marker, right click removes the nearest one. The Markers dock lists ' // &
                'them: double-click an x value to edit it, click a column title to sort. ' // &
                'Every change can be undone (Edit &gt; Undo, or the History tab).</p>' // &
                '<h3><a name="library"></a>Function library</h3>' // &
                '<p>Pick a function from the tree; type in the search field to filter it.</p>')
            call vbox%addWidget(browser)
            buttons = QDialogButtonBox(QDialogButtonBox_Close)
            call vbox%addWidget(buttons)
            call buttons%rejected%connect(on_close_help, s)
            call s%help%show()
        end select
    end subroutine on_help

    !> Hide the help window (Close button).
    subroutine on_close_help(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            call s%help%hide()
        end select
    end subroutine on_close_help

    !> Switch full screen on or off.
    subroutine on_fullscreen(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (explorer_state)
            if (checked) then
                call s%window%showFullScreen()
            else
                call s%window%showNormal()
            end if
        end select
    end subroutine on_fullscreen

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
        type(QAction) :: new_plot, undo, redo, set_range, help
        type(QMenu) :: edit_menu
        type(QDockWidget) :: library_dock, marker_dock
        type(QWidget) :: library_panel
        type(QVBoxLayout) :: library_box
        type(QTabWidget) :: marker_tabs
        type(QCompleter) :: completer

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

        ! undo stack: commands are performed / reversed by on_redo / on_undo
        s%undo = QUndoStack(s%window)
        call s%undo%redoRequested%connect(on_redo, s)
        call s%undo%undoRequested%connect(on_undo, s)
        undo = s%undo%createUndoAction(s%window)
        call undo%setShortcut('Ctrl+Z')
        redo = s%undo%createRedoAction(s%window)
        call redo%setShortcut('Ctrl+Shift+Z')

        ! function library dock: a tree model behind a filter proxy
        s%library = QtfTreeModel(2, s%window)
        call s%library%setHeaderLabels(['Function', 'Formula '])
        call s%library%dataRequested%connect(on_library_cell, s)
        call s%library%setParents(node_parents)
        s%library_filter = QSortFilterProxyModel(s%window)
        call s%library_filter%setSourceModel(s%library)
        call s%library_filter%setRecursiveFilteringEnabled(.true.)
        call s%library_filter%setFilterCaseSensitivity(Qt_CaseInsensitive)
        s%library_view = QTreeView()
        call s%library_view%setModel(s%library_filter)
        call s%library_view%expandAll()
        call s%library_view%resizeColumnToContents(0)
        call s%library_view%currentNodeChanged%connect(on_library_node, s)
        call s%func%currentIndexChanged%connect(on_function_changed, s)
        s%library_search = QLineEdit()
        call s%library_search%setPlaceholderText('Search functions')
        call s%library_search%setClearButtonEnabled(.true.)
        completer = QCompleter(function_names, s%window)
        call completer%setCaseSensitivity(Qt_CaseInsensitive)
        call completer%setFilterMode(Qt_MatchContains)
        call s%library_search%setCompleter(completer)
        call s%library_search%textChanged%connect(on_library_search, s)
        library_panel = QWidget()
        library_box = QVBoxLayout(library_panel)
        call library_box%setContentsMargins(0, 0, 0, 0)
        call library_box%addWidget(s%library_search)
        call library_box%addWidget(s%library_view)
        library_dock = QDockWidget('Function library', s%window)
        call library_dock%setObjectName('library')
        call library_dock%setWidget(library_panel)
        call s%window%addDockWidget(Qt_LeftDockWidgetArea, library_dock)

        ! markers dock: the marker table and the undo history
        s%marker_model = QtfTableModel(0, 3, s%window)
        call s%marker_model%setHorizontalHeaderLabels(['#   ', 'x   ', 'f(x)'])
        call s%marker_model%setEditable(.true.)
        call s%marker_model%dataRequested%connect(on_marker_cell, s)
        call s%marker_model%dataEdited%connect(on_marker_edited, s)
        call s%marker_model%sortRequested%connect(on_marker_sort, s)
        s%marker_table = QTableView()
        call s%marker_table%setModel(s%marker_model)
        call s%marker_table%setVerticalHeaderVisible(.false.)
        call s%marker_table%setStretchLastSection(.true.)
        call s%marker_table%setSortingEnabled(.true.)
        call s%marker_table%sortByColumn(1, Qt_AscendingOrder)    ! (the indicator; nothing to sort yet)
        call s%marker_table%setColumnWidth(0, 36)
        call s%marker_table%setColumnWidth(1, 80)
        call s%marker_table%setEditTriggers(ior(QAbstractItemView_DoubleClicked, QAbstractItemView_EditKeyPressed))
        s%x_delegate = QtfItemDelegate(s%marker_table)
        call s%x_delegate%setRange(-1000.0_dp, 1000.0_dp, 2)
        call s%marker_table%setItemDelegateForColumn(1, s%x_delegate)
        marker_tabs = QTabWidget()
        call marker_tabs%addTab(s%marker_table, 'Markers')
        call marker_tabs%addTab(QUndoView(s%undo), 'History')
        marker_dock = QDockWidget('Markers', s%window)
        call marker_dock%setObjectName('markers')
        call marker_dock%setWidget(marker_tabs)
        call marker_dock%setMinimumWidth(230)
        call s%window%addDockWidget(Qt_RightDockWidgetArea, marker_dock)

        ! more actions and menus
        new_plot = new_action(s, '&New plot...', 'Ctrl+N', 'Set up a plot step by step', on_new_plot)
        set_range = new_action(s, 'Set &range...', 'Ctrl+R', 'Set the visible x range', on_set_range)
        help = new_action(s, '&Contents', 'F1', 'Show the help', on_help)
        s%fullscreen = QAction('&Full screen', s%window)
        call s%fullscreen%setCheckable(.true.)
        call s%fullscreen%setShortcut('F11')
        call s%fullscreen%toggled%connect(on_fullscreen, s)
        call file_menu%insertAction(export, new_plot)
        edit_menu = QMenu('&Edit', s%window)
        call bar%insertMenu(view_menu%menuAction(), edit_menu)
        call edit_menu%addAction(undo)
        call edit_menu%addAction(redo)
        call view_menu%addAction(set_range)
        call view_menu%addAction(s%fullscreen)
        call view_menu%addSeparator()
        call view_menu%addAction(library_dock%toggleViewAction())
        call view_menu%addAction(marker_dock%toggleViewAction())
        call help_menu%insertAction(about, help)
        call tools%insertAction(export, new_plot)
        call tools%addSeparator()
        call tools%addAction(undo)
        call tools%addAction(redo)
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
        call change_markers(s, 'Add markers', 3, [-4.5_dp, 2.0_dp, 6.3_dp])
        call s%animate%setChecked(.true.)
    end if

    call s%status%showMessage('Ready - click the plot to add markers')
    call s%window%resize(1360, 640)
    call s%window%show()
    call s%canvas%setFocus()
    ierr = app%exec()

end program explorer
