!> Field Viewer: 2D scalar fields computed in Fortran, shown as colormapped
!> images (QImage_fromArray) with axes and a colorbar.
!>
!> * Fields: wave interference (animated), Gaussian peaks (masked with NaN
!>   outside a disk), the Mandelbrot set, and heat diffusion. On the
!>   diffusion field, left-click or drag to add heat and right-click to add
!>   cold, then press Play to run the solver.
!> * Side panel: field, resolution, colormap (with a colorbar preview), smooth
!>   scaling, a fixed value range, and an overview thumbnail.
!> * Hover over the field to read x, y and the value in the status bar.
!>
!> `fieldviewer --screenshot out.png [--field N]` renders field N (0-based),
!> saves the window and exits.
module fieldviewer_app

    use qt
    use iso_c_binding, only: c_double
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_is_nan
    implicit none

    integer, parameter :: dp = c_double
    real(dp), parameter :: pi = acos(-1.0_dp)

    character(len=16), parameter :: field_names(4) = &
        [character(len=16) :: 'Interference', 'Gaussian peaks', 'Mandelbrot', 'Heat diffusion']
    character(len=10), parameter :: colormap_names(6) = &
        [character(len=10) :: 'viridis', 'magma', 'inferno', 'plasma', 'coolwarm', 'gray']
    integer, parameter :: INTERFERENCE = 0, PEAKS = 1, MANDELBROT = 2, DIFFUSION = 3

    !> Widgets, the current field and its image.
    type :: viewer_t
        type(QMainWindow) :: window
        type(QStatusBar) :: status
        type(QtfWidget) :: canvas
        type(QComboBox) :: field, colormap
        type(QSpinBox) :: resolution
        type(QCheckBox) :: smooth
        type(QGroupBox) :: fixed
        type(QDoubleSpinBox) :: vmin, vmax
        type(QLabel) :: preview, overview
        type(QAction) :: play
        type(QTimer) :: timer
        ! data
        real(dp), allocatable :: f(:, :)      !! the field: f(i, j) at (x(i), y(j))
        real(dp) :: xlim(2) = [-1.0_dp, 1.0_dp], ylim(2) = [-1.0_dp, 1.0_dp]
        real(dp) :: lo = 0, hi = 1            !! value range shown
        real(dp) :: phase = 0
        type(QImage) :: image, bar
        ! geometry of the drawn field (pixels), for mouse readout
        real(dp) :: px0 = 0, py0 = 0, psize = 1
        ! --screenshot
        character(len=:), allocatable :: screenshot
    end type viewer_t

contains

    ! ==================================================================
    ! helpers

    !> Real as compact text with `d` decimals.
    function rtoa(x, d) result(s)
        real(dp), intent(in) :: x
        integer, intent(in) :: d
        character(len=:), allocatable :: s
        character(len=40) :: buf, fmt
        write(fmt, '(A,I0,A)') '(F40.', d, ')'
        write(buf, fmt) x
        s = trim(adjustl(buf))
    end function rtoa

    !> The selected colormap name.
    function colormap_name(s) result(name)
        type(viewer_t), intent(in) :: s
        character(len=:), allocatable :: name
        name = trim(colormap_names(s%colormap%currentIndex() + 1))
    end function colormap_name

    !> Grid coordinate k (1..n) along [a, b].
    pure real(dp) function coord(k, n, lim)
        integer, intent(in) :: k, n
        real(dp), intent(in) :: lim(2)
        coord = lim(1) + (k - 1) * (lim(2) - lim(1)) / (n - 1)
    end function coord

    ! ==================================================================
    ! fields

    !> Two point sources of circular waves.
    subroutine compute_interference(s, n)
        type(viewer_t), intent(inout) :: s
        integer, intent(in) :: n
        real(dp) :: x, y, r1, r2
        integer :: i, j
        s%xlim = [-1.0_dp, 1.0_dp]
        s%ylim = [-1.0_dp, 1.0_dp]
        do j = 1, n
            y = coord(j, n, s%ylim)
            do i = 1, n
                x = coord(i, n, s%xlim)
                r1 = hypot(x + 0.35_dp, y)
                r2 = hypot(x - 0.35_dp, y)
                s%f(i, j) = cos(40 * r1 - s%phase) / (1 + 4 * r1) + cos(40 * r2 - s%phase) / (1 + 4 * r2)
            end do
        end do
    end subroutine compute_interference

    !> A few Gaussian peaks, undefined (NaN) outside the unit disk.
    subroutine compute_peaks(s, n)
        type(viewer_t), intent(inout) :: s
        integer, intent(in) :: n
        real(dp) :: x, y
        integer :: i, j
        s%xlim = [-1.0_dp, 1.0_dp]
        s%ylim = [-1.0_dp, 1.0_dp]
        do j = 1, n
            y = coord(j, n, s%ylim)
            do i = 1, n
                x = coord(i, n, s%xlim)
                if (x * x + y * y > 1) then
                    s%f(i, j) = ieee_value(1.0_dp, ieee_quiet_nan)
                else
                    s%f(i, j) = 1.0_dp * exp(-((x - 0.3_dp)**2 + (y - 0.2_dp)**2) / 0.05_dp) &
                              + 0.7_dp * exp(-((x + 0.4_dp)**2 + (y + 0.3_dp)**2) / 0.08_dp) &
                              - 0.5_dp * exp(-((x + 0.1_dp)**2 + (y - 0.5_dp)**2) / 0.03_dp)
                end if
            end do
        end do
    end subroutine compute_peaks

    !> The Mandelbrot set: smoothed escape iteration counts.
    subroutine compute_mandelbrot(s, n)
        type(viewer_t), intent(inout) :: s
        integer, intent(in) :: n
        integer, parameter :: max_iter = 200
        complex(dp) :: c, z
        integer :: i, j, k
        s%xlim = [-2.2_dp, 0.8_dp]
        s%ylim = [-1.5_dp, 1.5_dp]
        do j = 1, n
            do i = 1, n
                c = cmplx(coord(i, n, s%xlim), coord(j, n, s%ylim), dp)
                z = 0
                do k = 1, max_iter
                    z = z * z + c
                    if (abs(z) > 4) exit
                end do
                if (k > max_iter) then
                    s%f(i, j) = 0                                   ! inside the set
                else
                    s%f(i, j) = log(k + 1 - log(log(abs(z))) / log(2.0_dp))
                end if
            end do
        end do
    end subroutine compute_mandelbrot

    !> One explicit finite-difference step of the heat equation (fixed 0 edges).
    subroutine diffuse(f)
        real(dp), intent(inout) :: f(:, :)
        integer :: n
        n = size(f, 1)
        f(2:n-1, 2:n-1) = f(2:n-1, 2:n-1) + 0.24_dp * (f(1:n-2, 2:n-1) + f(3:n, 2:n-1) &
                          + f(2:n-1, 1:n-2) + f(2:n-1, 3:n) - 4 * f(2:n-1, 2:n-1))
    end subroutine diffuse

    !> Recompute the field for the current settings (keeping diffusion state).
    subroutine compute(s, reset)
        type(viewer_t), intent(inout) :: s
        logical, intent(in) :: reset
        integer :: n
        n = s%resolution%value()
        if (allocated(s%f)) then
            if (size(s%f, 1) /= n) deallocate(s%f)
        end if
        if (.not. allocated(s%f)) then
            allocate(s%f(n, n))
            s%f = 0
        end if
        select case (s%field%currentIndex())
        case (INTERFERENCE)
            call compute_interference(s, n)
        case (PEAKS)
            call compute_peaks(s, n)
        case (MANDELBROT)
            call compute_mandelbrot(s, n)
        case (DIFFUSION)
            s%xlim = [0.0_dp, 1.0_dp]
            s%ylim = [0.0_dp, 1.0_dp]
            if (reset) then
                s%f = 0
                call deposit(s, 0.3_dp, 0.6_dp, 1.0_dp)
                call deposit(s, 0.7_dp, 0.35_dp, -1.0_dp)
            end if
        end select
        call refresh(s)
    end subroutine compute

    !> Add heat (value > 0) or cold in a small disk around (x, y).
    subroutine deposit(s, x, y, value)
        type(viewer_t), intent(inout) :: s
        real(dp), intent(in) :: x, y, value
        integer :: i, j, n, r, ci, cj
        n = size(s%f, 1)
        r = max(2, n / 25)
        ci = 1 + nint((x - s%xlim(1)) / (s%xlim(2) - s%xlim(1)) * (n - 1))
        cj = 1 + nint((y - s%ylim(1)) / (s%ylim(2) - s%ylim(1)) * (n - 1))
        do j = max(2, cj - r), min(n - 1, cj + r)
            do i = max(2, ci - r), min(n - 1, ci + r)
                if ((i - ci)**2 + (j - cj)**2 <= r * r) s%f(i, j) = value
            end do
        end do
    end subroutine deposit

    !> Rebuild the image, colorbar, preview and thumbnail; repaint.
    subroutine refresh(s)
        type(viewer_t), intent(inout) :: s
        type(QPixmap) :: pix
        if (s%fixed%isChecked()) then
            s%lo = s%vmin%value()
            s%hi = s%vmax%value()
        else if (any(.not. ieee_is_nan(s%f))) then
            s%lo = minval(s%f, mask=.not. ieee_is_nan(s%f))
            s%hi = maxval(s%f, mask=.not. ieee_is_nan(s%f))
        end if
        call s%image%delete()
        s%image = QImage_fromArray(s%f, colormap_name(s), s%lo, s%hi, flipY=.true.)
        call s%bar%delete()
        s%bar = QImage_colorbar(colormap_name(s), 1, 256)

        pix = QPixmap_fromImage(s%image)               ! overview thumbnail
        call s%overview%setPixmap(pix)
        call pix%delete()
        call s%canvas%update()
    end subroutine refresh

    !> Show the selected colormap in the side panel.
    subroutine update_preview(s)
        type(viewer_t), intent(inout) :: s
        type(QImage) :: strip
        type(QPixmap) :: pix
        strip = QImage_colorbar(colormap_name(s), 200, 14, vertical=.false.)
        pix = QPixmap_fromImage(strip)
        call s%preview%setPixmap(pix)
        call pix%delete()
        call strip%delete()
    end subroutine update_preview

    ! ==================================================================
    ! painting

    !> Draw the field (square, scaled to fit), axes and the colorbar.
    subroutine on_paint(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        real(dp) :: w, h, x0, y0, size, cbx, t
        integer :: k
        select type (s => data)
        type is (viewer_t)
            w = painter%deviceWidth()
            h = painter%deviceHeight()
            call painter%fillRect(0, 0, int(w), int(h), QColor(245, 246, 248))
            if (s%image%isNull()) return
            size = max(10.0_dp, min(w - 170, h - 60))
            x0 = 60 + (w - 170 - size) / 2
            y0 = 15 + (h - 60 - size) / 2
            s%px0 = x0
            s%py0 = y0
            s%psize = size

            ! the field: a checkerboard behind it shows the transparent (NaN) parts
            call painter%fillRect(x0, y0, size, size, QColor(225, 225, 228))
            call painter%setRenderHint(QPainter_SmoothPixmapTransform, s%smooth%isChecked())
            call painter%drawImage(x0, y0, size, size, s%image)
            call painter%setPen(Qt_darkGray)
            call painter%setBrush(QBrush(style=Qt_NoBrush))
            call painter%drawRect(x0, y0, size, size)

            ! axis ticks
            call painter%setFont(QFont(pointSize=9.0_dp))
            do k = 0, 4
                t = k / 4.0_dp
                call painter%drawLine(x0 + t * size, y0 + size, x0 + t * size, y0 + size + 4)
                call painter%drawText(x0 + t * size - 30, y0 + size + 6, 60.0_dp, 16.0_dp, Qt_AlignCenter, &
                                      rtoa(s%xlim(1) + t * (s%xlim(2) - s%xlim(1)), 2))
                call painter%drawLine(x0 - 4, y0 + size - t * size, x0, y0 + size - t * size)
                call painter%drawText(0.0_dp, y0 + size - t * size - 8, x0 - 7, 16.0_dp, &
                                      ior(Qt_AlignRight, Qt_AlignVCenter), &
                                      rtoa(s%ylim(1) + t * (s%ylim(2) - s%ylim(1)), 2))
            end do

            ! colorbar with value labels
            cbx = x0 + size + 25
            call painter%drawImage(cbx, y0, 18.0_dp, size, s%bar)
            call painter%drawRect(cbx, y0, 18.0_dp, size)
            do k = 0, 4
                t = k / 4.0_dp
                call painter%drawLine(cbx + 18, y0 + size - t * size, cbx + 22, y0 + size - t * size)
                call painter%drawText(cbx + 25, y0 + size - t * size - 8, 70.0_dp, 16.0_dp, &
                                      ior(Qt_AlignLeft, Qt_AlignVCenter), rtoa(s%lo + t * (s%hi - s%lo), 3))
            end do
        end select
    end subroutine on_paint

    !> Grid indices (i, j) under a widget position; false if outside the field.
    logical function locate(s, px, py, i, j)
        type(viewer_t), intent(in) :: s
        real(dp), intent(in) :: px, py
        integer, intent(out) :: i, j
        integer :: n
        n = size(s%f, 1)
        i = 1 + int((px - s%px0) / s%psize * n)
        j = 1 + int((s%py0 + s%psize - py) / s%psize * n)       ! y points up
        locate = i >= 1 .and. i <= n .and. j >= 1 .and. j <= n
    end function locate

    !> Show x, y and the value under the cursor; paint heat while dragging.
    subroutine on_move(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        integer :: i, j, n
        character(len=:), allocatable :: value
        select type (s => data)
        type is (viewer_t)
            if (.not. allocated(s%f)) return
            if (.not. locate(s, event%x(), event%y(), i, j)) return
            n = size(s%f, 1)
            value = 'NaN'
            if (.not. ieee_is_nan(s%f(i, j))) value = rtoa(s%f(i, j), 4)
            call s%status%showMessage('x = ' // rtoa(coord(i, n, s%xlim), 3) // '   y = ' // &
                                      rtoa(coord(j, n, s%ylim), 3) // '   value = ' // value)
            if (event%buttons() /= Qt_NoButton) call paint_heat(s, event)
        end select
    end subroutine on_move

    !> Click on the diffusion field: add heat (left) or cold (right).
    subroutine on_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer_t)
            call paint_heat(s, event)
        end select
    end subroutine on_press

    !> Deposit heat or cold under the mouse (diffusion field only).
    subroutine paint_heat(s, event)
        type(viewer_t), intent(inout) :: s
        type(QMouseEvent), intent(in) :: event
        integer :: i, j, n
        if (s%field%currentIndex() /= DIFFUSION .or. .not. allocated(s%f)) return
        if (.not. locate(s, event%x(), event%y(), i, j)) return
        n = size(s%f, 1)
        call deposit(s, coord(i, n, s%xlim), coord(j, n, s%ylim), &
                     merge(-1.0_dp, 1.0_dp, iand(event%buttons(), Qt_RightButton) /= 0 &
                                            .or. event%button() == Qt_RightButton))
        call refresh(s)
    end subroutine paint_heat

    ! ==================================================================
    ! controls and commands

    !> A new field was chosen: suitable defaults, then compute.
    subroutine on_field(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer_t)
            if (index == DIFFUSION) then                   ! symmetric range, diverging colors
                call s%vmin%setValue(-1.0_dp)
                call s%vmax%setValue(1.0_dp)
                call s%fixed%setChecked(.true.)
                call s%colormap%setCurrentIndex(4)
                call s%status%showMessage('Left-click or drag to add heat, right-click for cold; ' // &
                                          'press Play to diffuse')
            else
                call s%fixed%setChecked(.false.)
                call s%status%showMessage(trim(field_names(index + 1)), 2000)
            end if
            call compute(s, .true.)
        end select
    end subroutine on_field

    !> Resolution changed.
    subroutine on_resolution(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer_t)
            call compute(s, .true.)
        end select
    end subroutine on_resolution

    !> Colormap changed.
    subroutine on_colormap(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer_t)
            call update_preview(s)
            if (allocated(s%f)) call refresh(s)
        end select
    end subroutine on_colormap

    !> Range or display option changed.
    subroutine on_option(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer_t)
            if (allocated(s%f)) call refresh(s)
        end select
    end subroutine on_option

    !> Range limits changed.
    subroutine on_range(value, data)
        real(dp), intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer_t)
            if (allocated(s%f) .and. s%fixed%isChecked()) call refresh(s)
        end select
    end subroutine on_range

    !> Play / pause the animation (wave phase, or the heat solver).
    subroutine on_play(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        type(QIcon) :: icon
        select type (s => data)
        type is (viewer_t)
            icon = QStyle_standardIcon(merge('SP_MediaPause', 'SP_MediaPlay ', checked))
            call s%play%setIcon(icon)
            call icon%delete()
            call s%play%setText(merge('Pause', 'Play ', checked))
            if (checked) then
                call s%timer%start(30)
            else
                call s%timer%stop()
            end if
        end select
    end subroutine on_play

    !> Animation step; handles `--screenshot`.
    subroutine on_tick(data)
        class(*), intent(inout), optional :: data
        integer :: k
        select type (s => data)
        type is (viewer_t)
            select case (s%field%currentIndex())
            case (DIFFUSION)
                do k = 1, 20
                    call diffuse(s%f)
                end do
                call refresh(s)
            case (INTERFERENCE)
                s%phase = s%phase + 0.25_dp
                call compute(s, .false.)
            end select
        end select
    end subroutine on_tick

    !> Reset the field.
    subroutine on_reset(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (viewer_t)
            s%phase = 0
            call compute(s, .true.)
        end select
    end subroutine on_reset

    !> Save the view (field, axes and colorbar) as a PNG.
    subroutine on_save(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        type(QPixmap) :: pix
        integer :: button
        select type (s => data)
        type is (viewer_t)
            path = QFileDialog_getSaveFileName('Save image', 'field.png', 'PNG images (*.png)', parent=s%window)
            if (path == '') return
            pix = s%canvas%grab()
            if (pix%save(path)) then
                call s%status%showMessage('Saved ' // path, 3000)
            else
                button = QMessageBox_warning('Save image', 'Could not write ' // path, parent=s%window)
            end if
            call pix%delete()
        end select
    end subroutine on_save

    !> Save the field alone, one pixel per grid point.
    subroutine on_save_raw(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        integer :: button
        select type (s => data)
        type is (viewer_t)
            path = QFileDialog_getSaveFileName('Save field image', 'field-raw.png', 'PNG images (*.png)', &
                                               parent=s%window)
            if (path == '') return
            if (s%image%save(path)) then
                call s%status%showMessage('Saved ' // path, 3000)
            else
                button = QMessageBox_warning('Save image', 'Could not write ' // path, parent=s%window)
            end if
        end select
    end subroutine on_save_raw

    !> Quit the application.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

    !> --screenshot: save the window and quit.
    subroutine on_screenshot(data)
        class(*), intent(inout), optional :: data
        type(QPixmap) :: pix
        select type (s => data)
        type is (viewer_t)
            pix = s%window%grab()
            if (.not. pix%save(s%screenshot)) write(*,'(A)') 'could not save ' // s%screenshot
            call pix%delete()
            call QApplication_quit()
        end select
    end subroutine on_screenshot

    ! ==================================================================
    ! construction

    !> An action with a standard icon, connected to `slot` if given.
    function icon_action(s, text, icon_name, shortcut, slot) result(a)
        type(viewer_t), intent(inout), target :: s
        character(len=*), intent(in) :: text, icon_name, shortcut
        procedure(qt_slot), optional :: slot
        type(QAction) :: a
        type(QIcon) :: icon
        a = QAction(text, s%window)
        icon = QStyle_standardIcon(icon_name)
        call a%setIcon(icon)
        call icon%delete()
        if (shortcut /= '') call a%setShortcut(shortcut)
        if (present(slot)) call a%triggered%connect(slot, s)
    end function icon_action

    !> Build the side panel.
    function build_panel(s) result(panel)
        type(viewer_t), intent(inout), target :: s
        type(QWidget) :: panel
        type(QVBoxLayout) :: vbox, color_box, overview_box
        type(QFormLayout) :: field_form, range_form
        type(QGroupBox) :: field_group, color_group, overview_group

        panel = QWidget()
        call panel%setFixedWidth(260)
        vbox = QVBoxLayout(panel)

        field_group = QGroupBox('Field')
        field_form = QFormLayout(field_group)
        s%field = QComboBox()
        call s%field%addItems(field_names)
        call field_form%addRow('Field', s%field)
        s%resolution = QSpinBox()
        call s%resolution%setRange(32, 1024)
        call s%resolution%setSingleStep(32)
        call s%resolution%setValue(256)
        call s%resolution%setSuffix(' px')
        call field_form%addRow('Resolution', s%resolution)
        call vbox%addWidget(field_group)

        color_group = QGroupBox('Colors')
        color_box = QVBoxLayout(color_group)
        s%colormap = QComboBox()
        call s%colormap%addItems(colormap_names)
        s%preview = QLabel()
        call s%preview%setScaledContents(.true.)
        call s%preview%setFixedHeight(14)
        s%smooth = QCheckBox('Smooth scaling')
        call color_box%addWidget(s%colormap)
        call color_box%addWidget(s%preview)
        call color_box%addWidget(s%smooth)
        call vbox%addWidget(color_group)

        s%fixed = QGroupBox('Fixed range')
        call s%fixed%setCheckable(.true.)
        call s%fixed%setChecked(.false.)
        range_form = QFormLayout(s%fixed)
        s%vmin = QDoubleSpinBox()
        call s%vmin%setRange(-1000.0_dp, 1000.0_dp)
        call s%vmin%setDecimals(3)
        call s%vmin%setSingleStep(0.1_dp)
        call s%vmin%setValue(-1.0_dp)
        s%vmax = QDoubleSpinBox()
        call s%vmax%setRange(-1000.0_dp, 1000.0_dp)
        call s%vmax%setDecimals(3)
        call s%vmax%setSingleStep(0.1_dp)
        call s%vmax%setValue(1.0_dp)
        call range_form%addRow('Minimum', s%vmin)
        call range_form%addRow('Maximum', s%vmax)
        call vbox%addWidget(s%fixed)

        overview_group = QGroupBox('Overview')
        overview_box = QVBoxLayout(overview_group)
        s%overview = QLabel()
        call s%overview%setScaledContents(.true.)
        call s%overview%setFixedSize(220, 220)
        call overview_box%addWidget(s%overview)
        call vbox%addWidget(overview_group)
        call vbox%addStretch()

        call s%field%currentIndexChanged%connect(on_field, s)
        call s%resolution%valueChanged%connect(on_resolution, s)
        call s%colormap%currentIndexChanged%connect(on_colormap, s)
        call s%smooth%toggled%connect(on_option, s)
        call s%fixed%toggled%connect(on_option, s)
        call s%vmin%valueChanged%connect(on_range, s)
        call s%vmax%valueChanged%connect(on_range, s)
    end function build_panel

    !> Build the main window.
    subroutine build(s)
        type(viewer_t), intent(inout), target :: s
        type(QWidget) :: central
        type(QHBoxLayout) :: hbox
        type(QMenuBar) :: bar
        type(QMenu) :: file_menu, view_menu
        type(QToolBar) :: tools
        type(QAction) :: reset, save, save_raw, quit
        type(QImage) :: logo
        type(QPixmap) :: pix
        type(QIcon) :: icon

        s%window = QMainWindow()
        call s%window%setWindowTitle('Field Viewer - qt-fortran')
        s%status = s%window%statusBar()

        ! window icon: a little colorbar image
        logo = QImage_colorbar('viridis', 32, 32, vertical=.false.)
        pix = QPixmap_fromImage(logo)
        icon = QIcon(pix)
        call s%window%setWindowIcon(icon)
        call icon%delete()
        call pix%delete()
        call logo%delete()

        central = QWidget()
        hbox = QHBoxLayout(central)
        call hbox%addWidget(build_panel(s))
        s%canvas = QtfWidget()
        call s%canvas%setMinimumSize(500, 420)
        call s%canvas%setMouseTracking(.true.)
        call s%canvas%paintEvent%connect(on_paint, s)
        call s%canvas%mouseMoveEvent%connect(on_move, s)
        call s%canvas%mousePressEvent%connect(on_press, s)
        call hbox%addWidget(s%canvas, stretch=1)
        call s%window%setCentralWidget(central)

        s%play = icon_action(s, 'Play', 'SP_MediaPlay', 'Ctrl+P')     ! toggled -> on_play (main program)
        call s%play%setCheckable(.true.)
        reset = icon_action(s, 'Reset', 'SP_BrowserReload', 'Ctrl+R', on_reset)
        save = icon_action(s, 'Save view...', 'SP_DialogSaveButton', 'Ctrl+S', on_save)
        save_raw = icon_action(s, 'Save field image...', 'SP_DriveFDIcon', '', on_save_raw)
        quit = icon_action(s, 'Quit', 'SP_DialogCloseButton', 'Ctrl+Q', on_quit)

        bar = s%window%menuBar()
        file_menu = bar%addMenu('&File')
        call file_menu%addAction(save)
        call file_menu%addAction(save_raw)
        call file_menu%addSeparator()
        call file_menu%addAction(quit)
        view_menu = bar%addMenu('&View')
        call view_menu%addAction(s%play)
        call view_menu%addAction(reset)

        tools = s%window%addToolBar('Main')
        call tools%setToolButtonStyle(Qt_ToolButtonTextBesideIcon)
        call tools%addAction(s%play)
        call tools%addAction(reset)
        call tools%addSeparator()
        call tools%addAction(save)

        s%timer = QTimer()
        call s%timer%timeout%connect(on_tick, s)
    end subroutine build

end module fieldviewer_app

!> Field Viewer (see the module documentation).
program fieldviewer

    use qt
    use fieldviewer_app
    implicit none

    type(QApplication) :: app
    type(viewer_t), target :: s
    type(qt_string), allocatable :: args(:)
    integer :: field, ierr

    app = QApplication()
    call build(s)
    call s%play%toggled%connect(on_play, s)
    call update_preview(s)
    call compute(s, .true.)

    ! `--screenshot file.png [--field N]` (Qt has already removed its own options)
    args = QApplication_arguments()
    if (size(args) >= 3) then
        if (args(2)%s == '--screenshot') then
            s%screenshot = args(3)%s
            field = MANDELBROT
            if (size(args) >= 5) then
                if (args(4)%s == '--field') read(args(5)%s, *) field
            end if
            call s%field%setCurrentIndex(field)
            if (field == MANDELBROT) call s%colormap%setCurrentIndex(1)
            call QTimer_singleShot(300, on_screenshot, s)
        end if
    end if

    call s%window%resize(1060, 720)
    call s%window%show()
    ierr = app%exec()

end program fieldviewer
