!> A small data catalog: datasets in a table, plotted together in a chart.
!>
!> - Drop data files (one number per line, or CSV: the last number of each
!>   line is used) or text onto the window to add datasets; File > Open...
!>   does the same.
!> - Check a dataset to show it; click a row to select it, then a color below
!>   the table to recolor it.
!> - Edit > Copy table / Copy chart put text or an image on the clipboard;
!>   Edit > Paste numbers adds a dataset from copied text.
!> - Drag the chart out of the window to drop it as an image elsewhere.
!>
!> Shows: check boxes, color swatches, tool tips and bold text from a Fortran
!> table model; custom-painted cells (QtfItemDelegate%paintCell); a QListView
!> icon grid with a QtfListModel; QPainterPath curves with gradient fills, a
!> rotated label (QTransform) and elided text (QFontMetrics); drag and drop
!> both ways; the clipboard; cursors; and the window sized from its QScreen.
!>
!> `datasets --screenshot out.png` saves the window and exits.
module datasets_app

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    integer, parameter :: max_sets = 24, npal = 12

    !> The colors offered for datasets.
    type(QColor), parameter :: palette(npal) = [ &
        QColor(31, 119, 180), QColor(255, 127, 14), QColor(44, 160, 44), QColor(214, 39, 40), &
        QColor(148, 103, 189), QColor(140, 86, 75), QColor(227, 119, 194), QColor(127, 127, 127), &
        QColor(188, 189, 34), QColor(23, 190, 207), QColor(0, 0, 0), QColor(250, 200, 0)]
    character(len=*), parameter :: palette_names(npal) = [character(len=7) :: 'blue', 'orange', 'green', &
        'red', 'purple', 'brown', 'pink', 'gray', 'olive', 'cyan', 'black', 'yellow']

    !> One dataset: a name, where it came from, its values and how it is drawn.
    type :: dataset_t
        character(len=:), allocatable :: name, source
        real(dp), allocatable :: y(:)
        type(QColor) :: color
        logical :: shown = .true.
    end type dataset_t

    !> The application: widgets and datasets.
    type :: app_t
        type(QMainWindow) :: window
        type(QTableView) :: table
        type(QtfTableModel) :: model
        type(QtfItemDelegate) :: bars
        type(QListView) :: swatches
        type(QtfListModel) :: colors
        type(QtfWidget) :: chart
        type(QStatusBar) :: status
        type(dataset_t) :: sets(max_sets)
        integer :: nsets = 0, current = 0
        logical :: pressed = .false.
        real(dp) :: press_x = 0, press_y = 0
        character(len=:), allocatable :: screenshot
    end type app_t

contains

    ! ------------------------------------------------------------------
    ! datasets

    !> Add a dataset (and select it).
    subroutine add_dataset(s, name, source, y)
        type(app_t), intent(inout) :: s
        character(len=*), intent(in) :: name, source
        real(dp), intent(in) :: y(:)
        if (s%nsets == max_sets) then
            call s%status%showMessage('Too many datasets: remove one first (Edit > Remove dataset)', 4000)
            return
        end if
        s%nsets = s%nsets + 1
        s%sets(s%nsets)%name = name
        s%sets(s%nsets)%source = source
        s%sets(s%nsets)%y = y
        s%sets(s%nsets)%color = palette(mod(s%nsets - 1, npal) + 1)
        s%sets(s%nsets)%shown = .true.
        s%current = s%nsets
        call s%model%setRowCount(s%nsets)
        call changed(s)
    end subroutine add_dataset

    !> Redisplay the table and chart after the datasets changed.
    subroutine changed(s)
        type(app_t), intent(inout) :: s
        call s%model%refresh()
        if (s%current > 0) call s%table%selectRow(s%current - 1)
        call s%chart%update()
    end subroutine changed

    !> Parse one line of text: its last number, if any (so CSV files give
    !> their last column, and header lines are skipped).
    subroutine parse_line(line, v, found)
        character(len=*), intent(in) :: line
        real(dp), intent(out) :: v
        logical, intent(out) :: found
        character(len=len(line)) :: l
        real(dp) :: x
        integer :: i, j, ios
        l = line
        do i = 1, len(l)
            if (index(',;' // achar(9) // achar(13), l(i:i)) > 0) l(i:i) = ' '
        end do
        found = .false.
        v = 0
        i = 1
        do
            do while (i <= len(l))           ! skip blanks
                if (l(i:i) /= ' ') exit
                i = i + 1
            end do
            if (i > len(l)) exit
            j = i
            do while (j < len(l))            ! the end of the token
                if (l(j+1:j+1) == ' ') exit
                j = j + 1
            end do
            if (verify(l(i:j), '0123456789+-.eEdD') == 0) then
                read(l(i:j), *, iostat=ios) x
                if (ios == 0) then
                    v = x
                    found = .true.
                end if
            end if
            i = j + 1
        end do
    end subroutine parse_line

    !> Append `v` to `y(1:n)`, growing it as needed.
    subroutine push(y, n, v)
        real(dp), allocatable, intent(inout) :: y(:)
        integer, intent(inout) :: n
        real(dp), intent(in) :: v
        real(dp), allocatable :: tmp(:)
        if (.not. allocated(y)) allocate(y(256))
        if (n == size(y)) then
            allocate(tmp(2 * n))
            tmp(1:n) = y
            call move_alloc(tmp, y)
        end if
        n = n + 1
        y(n) = v
    end subroutine push

    !> The numbers in `text` (one per line).
    subroutine parse_text(text, y, n)
        character(len=*), intent(in) :: text
        real(dp), allocatable, intent(out) :: y(:)
        integer, intent(out) :: n
        integer :: i, j
        real(dp) :: v
        logical :: found
        n = 0
        i = 1
        do while (i <= len(text))
            j = index(text(i:), achar(10))
            j = merge(len(text), i + j - 2, j == 0)
            call parse_line(text(i:j), v, found)
            if (found) call push(y, n, v)
            i = j + 2
        end do
    end subroutine parse_text

    !> Read the numbers of a file (one per line, or the last of each line).
    subroutine read_file(path, y, n)
        character(len=*), intent(in) :: path
        real(dp), allocatable, intent(out) :: y(:)
        integer, intent(out) :: n
        character(len=4096) :: line
        real(dp) :: v
        logical :: found
        integer :: u, ios
        n = 0
        open(newunit=u, file=path, status='old', action='read', iostat=ios)
        if (ios /= 0) return
        do
            read(u, '(a)', iostat=ios) line
            if (ios /= 0) exit
            call parse_line(line, v, found)
            if (found) call push(y, n, v)
        end do
        close(u)
    end subroutine read_file

    !> Add a dataset per file (with a busy cursor while reading).
    subroutine load_files(s, paths)
        type(app_t), intent(inout) :: s
        type(qt_string), intent(in) :: paths(:)
        real(dp), allocatable :: y(:)
        integer :: i, n, loaded, slash
        character(len=80) :: msg
        loaded = 0
        call QGuiApplication_setOverrideCursor(Qt_WaitCursor)
        do i = 1, size(paths)
            if (index(paths(i)%s, '://') > 0) cycle      ! not a local file
            call read_file(paths(i)%s, y, n)
            if (n < 2) cycle
            slash = max(index(paths(i)%s, '/', back=.true.), index(paths(i)%s, '\', back=.true.))
            call add_dataset(s, paths(i)%s(slash + 1:), paths(i)%s, y(1:n))
            loaded = loaded + 1
        end do
        call QGuiApplication_restoreOverrideCursor()
        write(msg, '(i0, a, i0, a)') loaded, ' of ', size(paths), ' file(s) loaded'
        call s%status%showMessage(trim(msg), 4000)
    end subroutine load_files

    !> Add a dataset from text (pasted or dropped).
    subroutine add_from_text(s, text, name)
        type(app_t), intent(inout) :: s
        character(len=*), intent(in) :: text, name
        real(dp), allocatable :: y(:)
        integer :: n
        call parse_text(text, y, n)
        if (n < 2) then
            call s%status%showMessage('No numbers found in the text', 4000)
            return
        end if
        call add_dataset(s, name, 'text', y(1:n))
    end subroutine add_from_text

    !> A number as short text.
    function fmt(v) result(text)
        real(dp), intent(in) :: v
        character(len=:), allocatable :: text
        character(len=24) :: buf
        if (v /= 0 .and. (abs(v) >= 1e5_dp .or. abs(v) < 1e-3_dp)) then
            write(buf, '(es10.2)') v
        else
            write(buf, '(f12.3)') v
        end if
        text = trim(adjustl(buf))
    end function fmt

    ! ------------------------------------------------------------------
    ! the table: datasets, with check boxes, swatches and painted bars

    !> One cell: column 0 the name (check box, color swatch, tool tip),
    !> column 1 the number of points (painted as a bar), column 2 the mean.
    subroutine on_cell(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            associate (d => s%sets(row + 1))
                select case (column)
                case (0)
                    call request%setText(d%name)
                    call request%setChecked(d%shown)
                    call request%setIconColor(d%color)
                    call request%setToolTip(d%source)
                case (1)
                    call request%setInt(size(d%y))
                    call request%setAlignment(ior(Qt_AlignRight, Qt_AlignVCenter))
                case (2)
                    call request%setText(fmt(sum(d%y) / size(d%y)))
                    call request%setAlignment(ior(Qt_AlignRight, Qt_AlignVCenter))
                    call request%setToolTip('range ' // fmt(minval(d%y)) // ' .. ' // fmt(maxval(d%y)))
                end select
                if (row + 1 == s%current) call request%setBold()
            end associate
        end select
    end subroutine on_cell

    !> A check box was clicked: show or hide the dataset.
    subroutine on_check(row, column, checked, data)
        integer, intent(in) :: row, column, checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            s%sets(row + 1)%shown = checked == 1
            call s%chart%update()
        end select
    end subroutine on_check

    !> A row was clicked: select that dataset.
    subroutine on_row_clicked(row, column, data)
        integer, intent(in) :: row, column
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            s%current = row + 1
            call changed(s)
        end select
    end subroutine on_row_clicked

    !> The "Points" column: a bar as long as the dataset (relative to the
    !> longest), in the dataset's color, with the count on top.
    subroutine on_paint_points(cell, data)
        type(QtfPaintCell), intent(in) :: cell
        class(*), intent(inout), optional :: data
        type(QPainter) :: p
        type(QColor) :: c
        integer :: longest, w
        select type (s => data)
        type is (app_t)
            call cell%drawBackground()
            longest = maxval([(size(s%sets(w)%y), w = 1, s%nsets)])
            c = s%sets(cell%row() + 1)%color
            c%a = 90
            w = nint(real(size(s%sets(cell%row() + 1)%y), dp) / longest * (cell%width() - 6))
            p = cell%painter()
            call p%fillRect(cell%x() + 3, cell%y() + 4, w, cell%height() - 8, c)
            call p%setPen(cell%textColor())
            call p%drawText(cell%x() + 4, cell%y(), cell%width() - 8, cell%height(), &
                            ior(Qt_AlignRight, Qt_AlignVCenter), cell%text())
        end select
    end subroutine on_paint_points

    ! ------------------------------------------------------------------
    ! the color grid (a QListView in icon mode)

    !> One color: a swatch, with its name as the tool tip.
    subroutine on_color(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        call request%setText('')
        call request%setIconColor(palette(row + 1))
        call request%setToolTip(trim(palette_names(row + 1)))
    end subroutine on_color

    !> A color was clicked: recolor the selected dataset.
    subroutine on_color_clicked(row, column, data)
        integer, intent(in) :: row, column
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            if (s%current < 1) return
            s%sets(s%current)%color = palette(row + 1)
            call changed(s)
        end select
    end subroutine on_color_clicked

    ! ------------------------------------------------------------------
    ! the chart

    !> Plot the shown datasets: curves as painter paths, the selected one
    !> filled with a gradient; a legend, axis labels and an elided title.
    subroutine on_paint_chart(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        integer, parameter :: right = 20, top = 44, bottom = 40
        integer :: left
        type(QLinearGradient) :: bg, fill
        type(QPainterPath) :: curve, area
        type(QTransform) :: t
        type(QFontMetrics) :: fm
        type(QColor) :: c
        character(len=:), allocatable :: title, label
        character(len=16) :: count
        real(dp) :: ymin, ymax, x, y, pw, ph
        integer :: w, h, k, i, n, nmax, lw, ly
        logical :: any_shown
        select type (s => data)
        type is (app_t)
            w = painter%deviceWidth()
            h = painter%deviceHeight()
            call painter%setRenderHint(QPainter_Antialiasing)
            call painter%fillRect(0, 0, w, h, Qt_white)
            fm = painter%fontMetrics()

            ! the data range of the shown datasets
            any_shown = .false.
            nmax = 2
            ymin = huge(1.0_dp)
            ymax = -huge(1.0_dp)
            do k = 1, s%nsets
                if (.not. s%sets(k)%shown) cycle
                any_shown = .true.
                nmax = max(nmax, size(s%sets(k)%y))
                ymin = min(ymin, minval(s%sets(k)%y))
                ymax = max(ymax, maxval(s%sets(k)%y))
            end do
            if (.not. any_shown) then
                call painter%setPen(Qt_gray)
                call painter%drawText(0, 0, w, h, Qt_AlignCenter, 'Check a dataset, or drop a data file here')
                call fm%delete()
                return
            end if
            if (ymax - ymin < 1e-12_dp) then
                ymin = ymin - 1
                ymax = ymax + 1
            end if

            ! the plot area: room on the left for the widest value label and the axis title
            left = 0
            do i = 0, 4
                left = max(left, fm%horizontalAdvance(fmt(ymax - (ymax - ymin) * i / 4.0_dp)))
            end do
            left = left + fm%height() + 18
            pw = w - left - right
            ph = h - top - bottom
            bg = QLinearGradient(0.0_dp, real(top, dp), 0.0_dp, real(h - bottom, dp))
            call bg%setColorAt(0.0_dp, QColor(236, 242, 252))
            call bg%setColorAt(1.0_dp, Qt_white)
            call painter%fillRect(left, top, w - left - right, h - top - bottom, bg)
            call bg%delete()

            ! grid and value labels
            do i = 0, 4
                y = top + ph * i / 4.0_dp
                call painter%setPen(QColor(210, 215, 225))
                call painter%drawLine(real(left, dp), y, left + pw, y)
                label = fmt(ymax - (ymax - ymin) * i / 4.0_dp)
                call painter%setPen(Qt_darkGray)
                call painter%drawText(left - 6 - fm%horizontalAdvance(label), nint(y) + fm%ascent() / 2, label)
            end do
            call painter%drawText(left, h - bottom + fm%height() + 2, '1')
            write(count, '(i0)') nmax
            call painter%drawText(left + nint(pw) - fm%horizontalAdvance(trim(count)), h - bottom + fm%height() + 2, &
                                  trim(count))
            label = 'sample'
            call painter%drawText(left + nint(pw / 2) - fm%horizontalAdvance(label) / 2, h - 10, label)
            label = 'value'      ! rotated, along the y axis
            t = QTransform()
            call t%translate(6.0_dp + fm%ascent(), top + ph / 2)
            call t%rotate(-90.0_dp)
            call painter%setTransform(t)
            call painter%drawText(-fm%horizontalAdvance(label) / 2, fm%ascent() / 2, label)
            call painter%resetTransform()
            call t%delete()

            ! the curves, clipped to the plot area; the selected one last, filled
            call painter%setClipRect(left, top, w - left - right, h - top - bottom)
            do k = 1, s%nsets + 1
                i = merge(s%current, k, k == s%nsets + 1)
                if (i < 1) cycle
                if (k == s%current .or. .not. s%sets(i)%shown) cycle
                n = size(s%sets(i)%y)
                curve = QPainterPath()
                do lw = 1, n
                    x = left + pw * (lw - 1) / (nmax - 1)
                    y = top + ph * (ymax - s%sets(i)%y(lw)) / (ymax - ymin)
                    if (lw == 1) then
                        call curve%moveTo(x, y)
                    else
                        call curve%lineTo(x, y)
                    end if
                end do
                c = s%sets(i)%color
                if (i == s%current) then
                    area = curve%copy()
                    call area%lineTo(x, real(top, dp) + ph)
                    call area%lineTo(real(left, dp), real(top, dp) + ph)
                    call area%closeSubpath()
                    fill = QLinearGradient(0.0_dp, real(top, dp), 0.0_dp, top + ph)
                    c%a = 110
                    call fill%setColorAt(0.0_dp, c)
                    c%a = 0
                    call fill%setColorAt(1.0_dp, c)
                    call painter%fillPath(area, fill)
                    call fill%delete()
                    call area%delete()
                    c%a = 255
                end if
                call painter%strokePath(curve, QPen(c, merge(2.5_dp, 1.3_dp, i == s%current)))
                call curve%delete()
            end do
            call painter%setClipping(.false.)

            ! the legend: swatches and names, sized with the font metrics
            lw = 0
            n = 0
            do k = 1, s%nsets
                if (.not. s%sets(k)%shown) cycle
                lw = max(lw, fm%horizontalAdvance(s%sets(k)%name))
                n = n + 1
            end do
            lw = lw + 44                       ! swatch, gaps and margins
            ly = top + 8
            call painter%setPen(QColor(200, 200, 200))
            call painter%setBrush(QColor(255, 255, 255, 220))
            call painter%drawRoundedRect(w - right - lw - 6, ly, lw, n * fm%lineSpacing() + 10, 6, 6)
            do k = 1, s%nsets
                if (.not. s%sets(k)%shown) cycle
                ly = ly + fm%lineSpacing()
                call painter%fillRect(w - right - lw + 4, ly - fm%ascent() + 2, 16, fm%ascent() - 4, &
                                      s%sets(k)%color)
                call painter%setPen(Qt_black)
                call painter%drawText(w - right - lw + 26, ly, s%sets(k)%name)
            end do

            ! the title, elided to the plot width
            title = ''
            do k = 1, s%nsets
                if (s%sets(k)%shown) title = title // merge(', ', '  ', len(title) > 0) // s%sets(k)%name
            end do
            call painter%setFont(QFont(pointSize=13.0_dp, bold=.true.))
            call fm%delete()
            fm = painter%fontMetrics()
            call painter%setPen(Qt_black)
            call painter%drawText(left, 28, fm%elidedText(adjustl(title), Qt_ElideRight, nint(pw)))
            call fm%delete()
        end select
    end subroutine on_paint_chart

    !> Remember where a drag of the chart may start.
    subroutine on_chart_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            s%pressed = event%button() == Qt_LeftButton
            s%press_x = event%x()
            s%press_y = event%y()
        end select
    end subroutine on_chart_press

    !> Dragging the chart: export it as an image (and its titles as text).
    subroutine on_chart_move(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        type(QMimeData) :: mime
        type(QDrag) :: drag
        type(QPixmap) :: pix
        type(QImage) :: img
        integer :: action
        select type (s => data)
        type is (app_t)
            if (.not. s%pressed .or. iand(event%buttons(), Qt_LeftButton) == 0) return
            if (hypot(event%x() - s%press_x, event%y() - s%press_y) < 12) return
            s%pressed = .false.
            pix = s%chart%grab()
            img = pix%toImage()
            mime = QMimeData()
            call mime%setImage(img)
            call mime%setText(table_text(s))
            drag = QDrag(s%chart)
            call drag%setMimeData(mime)           ! the drag owns it
            action = drag%exec(Qt_CopyAction)
            call drag%deleteLater()
            call img%delete()
            call pix%delete()
            if (action /= Qt_IgnoreAction) call s%status%showMessage('Chart dropped as an image', 3000)
        end select
    end subroutine on_chart_move

    ! ------------------------------------------------------------------
    ! drag and drop onto the window

    !> Accept files and text.
    subroutine on_drag_enter(event, data)
        type(QDropEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        if (event%hasUrls() .or. event%hasText()) call event%acceptProposedAction()
    end subroutine on_drag_enter

    !> Add the dropped files, or the dropped text, as datasets.
    subroutine on_drop(event, data)
        type(QDropEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            if (event%hasUrls()) then
                call load_files(s, event%urls())
            else if (event%hasText()) then
                call add_from_text(s, event%text(), 'Dropped text')
            end if
            call event%acceptProposedAction()
        end select
    end subroutine on_drop

    ! ------------------------------------------------------------------
    ! menus

    !> The table as tab-separated text.
    function table_text(s) result(text)
        type(app_t), intent(in) :: s
        character(len=:), allocatable :: text
        character(len=16) :: count
        integer :: k
        text = 'dataset' // achar(9) // 'points' // achar(9) // 'mean' // achar(10)
        do k = 1, s%nsets
            write(count, '(i0)') size(s%sets(k)%y)
            text = text // s%sets(k)%name // achar(9) // trim(count) // achar(9) // &
                   fmt(sum(s%sets(k)%y) / size(s%sets(k)%y)) // achar(10)
        end do
    end function table_text

    !> File > Open...: add data files.
    subroutine on_open(data)
        class(*), intent(inout), optional :: data
        type(qt_string), allocatable :: paths(:)
        select type (s => data)
        type is (app_t)
            paths = QFileDialog_getOpenFileNames('Open data files', '', &
                                                 'Data files (*.txt *.csv *.dat);;All files (*)', s%window)
            if (size(paths) > 0) call load_files(s, paths)
        end select
    end subroutine on_open

    !> File > Save chart...: save the chart as an image.
    subroutine on_save(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        type(QPixmap) :: pix
        select type (s => data)
        type is (app_t)
            path = QFileDialog_getSaveFileName('Save chart', 'chart.png', 'Images (*.png *.jpg)', s%window)
            if (len(path) == 0) return
            pix = s%chart%grab()
            if (pix%save(path)) call s%status%showMessage('Saved ' // path, 4000)
            call pix%delete()
        end select
    end subroutine on_save

    !> Edit > Copy table: tab-separated text (pastes into a spreadsheet).
    subroutine on_copy_table(data)
        class(*), intent(inout), optional :: data
        type(QClipboard) :: cb
        select type (s => data)
        type is (app_t)
            cb = QGuiApplication_clipboard()
            call cb%setText(table_text(s))
            call s%status%showMessage('Table copied', 3000)
        end select
    end subroutine on_copy_table

    !> Edit > Copy chart: the chart as an image.
    subroutine on_copy_chart(data)
        class(*), intent(inout), optional :: data
        type(QClipboard) :: cb
        type(QPixmap) :: pix
        type(QImage) :: img
        select type (s => data)
        type is (app_t)
            pix = s%chart%grab()
            img = pix%toImage()
            cb = QGuiApplication_clipboard()
            call cb%setImage(img)
            call img%delete()
            call pix%delete()
            call s%status%showMessage('Chart copied', 3000)
        end select
    end subroutine on_copy_chart

    !> Edit > Paste numbers: a dataset from the clipboard's text.
    subroutine on_paste(data)
        class(*), intent(inout), optional :: data
        type(QClipboard) :: cb
        select type (s => data)
        type is (app_t)
            cb = QGuiApplication_clipboard()
            if (.not. cb%hasText()) then
                call s%status%showMessage('The clipboard holds no text', 3000)
                return
            end if
            call add_from_text(s, cb%text(), 'Pasted numbers')
        end select
    end subroutine on_paste

    !> Edit > Remove dataset: remove the selected one.
    subroutine on_remove(data)
        class(*), intent(inout), optional :: data
        integer :: k
        select type (s => data)
        type is (app_t)
            if (s%current < 1) return
            do k = s%current, s%nsets - 1
                s%sets(k) = s%sets(k + 1)
            end do
            s%nsets = s%nsets - 1
            s%current = min(s%current, s%nsets)
            call s%model%setRowCount(s%nsets)
            call changed(s)
        end select
    end subroutine on_remove

    !> File > Quit.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

    !> `--screenshot`: save the window and quit.
    subroutine on_screenshot(data)
        class(*), intent(inout), optional :: data
        type(QPixmap) :: pix
        logical :: ok
        select type (s => data)
        type is (app_t)
            pix = s%window%grab()
            ok = pix%save(s%screenshot)
            call pix%delete()
            call QApplication_quit()
        end select
    end subroutine on_screenshot

end module datasets_app

!> The data catalog.
program datasets

    use qt
    use datasets_app
    implicit none

    type(QApplication) :: app
    type(app_t), target :: s
    type(QSplitter) :: split
    type(QWidget) :: side
    type(QVBoxLayout) :: box
    type(QLabel) :: hint, colors_label
    type(QMenuBar) :: bar
    type(QMenu) :: menu
    type(QAction) :: act
    type(QScreen) :: screen
    character(len=256) :: arg, msg
    real(dp), allocatable :: y(:)
    integer :: i, ierr, w, h
    real(dp) :: walk, r

    app = QApplication()
    s%window = QMainWindow()
    call s%window%setWindowTitle('Datasets')
    s%status = s%window%statusBar()

    ! --- left: the table of datasets, and the colors
    side = QWidget()
    call side%setMinimumWidth(340)
    box = QVBoxLayout(side)
    hint = QLabel('Drop data files or text on the window. Check a dataset to show it; ' // &
                  'click one, then a color, to recolor it.')
    call hint%setWordWrap(.true.)
    call box%addWidget(hint)

    s%model = QtfTableModel(0, 3, s%window)
    call s%model%setHorizontalHeaderLabels([character(len=7) :: 'Dataset', 'Points', 'Mean'])
    call s%model%dataRequested%connect(on_cell, s)
    call s%model%checkChanged%connect(on_check, s)
    s%table = QTableView()
    call s%table%setModel(s%model)
    call s%table%setSelectionBehavior(QAbstractItemView_SelectRows)
    call s%table%setSelectionMode(QAbstractItemView_SingleSelection)
    call s%table%setEditTriggers(QAbstractItemView_NoEditTriggers)
    call s%table%setVerticalHeaderVisible(.false.)
    call s%table%setStretchLastSection(.true.)
    call s%table%setColumnWidth(0, 175)
    call s%table%setColumnWidth(1, 75)
    call s%table%clicked%connect(on_row_clicked, s)
    s%bars = QtfItemDelegate(s%table)
    call s%bars%paintCell%connect(on_paint_points, s)
    call s%table%setItemDelegateForColumn(1, s%bars)
    call box%addWidget(s%table, 1)

    colors_label = QLabel('Color of the selected dataset:')
    call box%addWidget(colors_label)
    s%colors = QtfListModel(npal, s%window)
    call s%colors%dataRequested%connect(on_color)
    s%swatches = QListView()
    call s%swatches%setModel(s%colors)
    call s%swatches%setViewMode(QListView_IconMode)
    call s%swatches%setFlow(QListView_LeftToRight)
    call s%swatches%setWrapping(.true.)
    call s%swatches%setResizeMode(QListView_Adjust)
    call s%swatches%setMovement(QListView_Static)
    call s%swatches%setIconSize(26, 26)
    call s%swatches%setGridSize(36, 36)
    call s%swatches%setFixedHeight(84)
    call s%swatches%setCursor(Qt_PointingHandCursor)
    call s%swatches%clicked%connect(on_color_clicked, s)
    call box%addWidget(s%swatches)

    ! --- right: the chart
    s%chart = QtfWidget()
    call s%chart%setMinimumSize(360, 260)
    call s%chart%setCursor(Qt_CrossCursor)
    call s%chart%setToolTip('Drag the chart out to drop it as an image')
    call s%chart%paintEvent%connect(on_paint_chart, s)
    call s%chart%mousePressEvent%connect(on_chart_press, s)
    call s%chart%mouseMoveEvent%connect(on_chart_move, s)

    split = QSplitter(Qt_Horizontal)
    call split%addWidget(side)
    call split%addWidget(s%chart)
    call split%setStretchFactor(1, 1)
    call s%window%setCentralWidget(split)

    ! --- drops anywhere on the window
    call s%window%setAcceptDrops(.true.)
    call s%window%dragEnterEvent%connect(on_drag_enter, s)
    call s%window%dropEvent%connect(on_drop, s)

    ! --- menus
    bar = s%window%menuBar()
    menu = bar%addMenu('&File')
    act = QAction('&Open...', s%window)
    call act%setShortcut('Ctrl+O')
    call act%triggered%connect(on_open, s)
    call menu%addAction(act)
    act = QAction('&Save chart...', s%window)
    call act%setShortcut('Ctrl+S')
    call act%triggered%connect(on_save, s)
    call menu%addAction(act)
    call menu%addSeparator()
    act = QAction('&Quit', s%window)
    call act%setShortcut('Ctrl+Q')
    call act%triggered%connect(on_quit)
    call menu%addAction(act)
    menu = bar%addMenu('&Edit')
    act = QAction('Copy &table', s%window)
    call act%setShortcut('Ctrl+C')
    call act%triggered%connect(on_copy_table, s)
    call menu%addAction(act)
    act = QAction('Copy &chart', s%window)
    call act%setShortcut('Ctrl+Shift+C')
    call act%triggered%connect(on_copy_chart, s)
    call menu%addAction(act)
    act = QAction('&Paste numbers', s%window)
    call act%setShortcut('Ctrl+V')
    call act%triggered%connect(on_paste, s)
    call menu%addAction(act)
    call menu%addSeparator()
    act = QAction('&Remove dataset', s%window)
    call act%setShortcut('Del')
    call act%triggered%connect(on_remove, s)
    call menu%addAction(act)

    ! --- some data to start with
    y = [(exp(-i / 160.0_dp) * sin(i / 9.0_dp), i = 1, 400)]
    call add_dataset(s, 'Damped oscillation', 'computed: exp(-t/160) sin(t/9)', y)
    y = [(1.6_dp / (1 + exp(-(i - 150) / 25.0_dp)) - 0.8_dp, i = 1, 300)]
    call add_dataset(s, 'Logistic growth', 'computed: a logistic curve', y)
    deallocate(y)
    allocate(y(400))
    walk = 0
    r = 0.5_dp
    do i = 1, 400                         ! a reproducible random walk
        r = mod(r * 9301 + 0.49297_dp, 1.0_dp)
        walk = walk + (r - 0.5_dp) * 0.12_dp
        y(i) = walk
    end do
    call add_dataset(s, 'Random walk', 'computed: steps uniform in [-0.06, 0.06]', y)
    y = [(0.7_dp * sin(2 * acos(-1.0_dp) * i / 365) + 0.15_dp * sin(i / 4.0_dp), i = 1, 365)]
    call add_dataset(s, 'Seasonal cycle', 'computed: a year with a weekly ripple', y)
    s%sets(3)%shown = .false.
    s%current = 1
    call changed(s)

    ! --- size the window from the screen it opens on
    screen = s%window%screen()
    w = min(1100, int(0.8 * screen%availableWidth()))
    h = min(680, int(0.8 * screen%availableHeight()))
    call s%window%resize(w, h)
    call split%setSizes([max(340, nint(0.36 * w)), w - max(340, nint(0.36 * w))])
    write(msg, '(a, i0, a, i0, a, f3.1, a, i0, a)') 'Screen ', screen%width(), ' x ', screen%height(), &
        ' (pixel ratio ', screen%devicePixelRatio(), ', ', nint(screen%logicalDotsPerInch()), ' dpi)'
    call s%status%showMessage(trim(msg))

    ! `--screenshot file.png`: save the window and exit
    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        call QTimer_singleShot(300, on_screenshot, s)
    end if

    call s%window%show()
    ierr = app%exec()

end program datasets
