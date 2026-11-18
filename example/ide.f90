!> A small IDE-like window: the building blocks of an application with docks.
!>
!> * Docks around a file viewer (QMainWindow, QDockWidget):
!>   - Project (left): the folder's files in a QTreeWidget, with platform
!>     icons (QFileIconProvider). Each file item carries its index into the
!>     Fortran file list (`item%setData`); clicking it opens the file.
!>   - Preview (right, with a compact custom title bar): an SVG logo drawn by
!>     QSvgRenderer in a QtfWidget whose size hint comes from Fortran, and
!>     the open file's type.
!>   - Quick open and Log (bottom, tabified): type letters to find a file
!>     (a fuzzy match decided in Fortran by a QtfSortFilterProxyModel: e.g.
!>     'shimcpp' finds src/shim/*.cpp), and a
!>     log of file and dock events.
!> * View > Layout (an action group): side panels, or stacked (splitDockWidget,
!>   tabifyDockWidget, resizeDocks, setCorner); tabs on top (setTabPosition).
!> * The open file and the folders are watched (QFileSystemWatcher): edit the
!>   file in another program and the view reloads; add or remove a file and
!>   the tree is rebuilt, keeping the open file selected (`tree%findData`).
!> * File > Export layout as SVG writes a map of the docks (QSvgGenerator).
!>   The toolbar icons are SVG text drawn with QSvgRenderer%toIcon.
!>
!> `ide [folder]` shows `folder` (default: the current directory).
!> `ide --screenshot out.png [folder]` saves the window and exits.
module ide_app

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: max_depth = 3        !! folder levels shown
    integer, parameter :: max_bytes = 500000   !! larger files are not shown

    !> A file of the project.
    type :: file_entry
        character(len=:), allocatable :: path, name, folder
        integer :: bytes = 0
    end type file_entry

    !> The application's state.
    type :: app_state
        type(QMainWindow) :: window
        type(QStatusBar) :: status
        type(QDockWidget) :: project_dock, preview_dock, quick_dock, log_dock
        type(QTreeWidget) :: tree
        type(QPlainTextEdit) :: viewer, log
        type(QtfTableModel) :: files_model
        type(QtfSortFilterProxyModel) :: proxy
        type(QTableView) :: files_view
        type(QLineEdit) :: query
        type(QLabel) :: file_type
        type(QFileSystemWatcher) :: watcher
        type(QFileIconProvider) :: icons
        type(QSvgRenderer) :: logo
        type(QtfWidget) :: logo_view
        type(file_entry), allocatable :: files(:)
        integer :: nfiles = 0
        integer :: current = 0                 !! the open file (0: none)
        character(len=:), allocatable :: root, pattern, screenshot
    end type app_state

    character(len=*), parameter :: logo_svg = &
        '<svg xmlns="http://www.w3.org/2000/svg" width="220" height="160" viewBox="0 0 220 160">' // &
        '<rect x="10" y="10" width="200" height="140" rx="18" fill="#2b5b84"/>' // &
        '<rect x="28" y="30" width="70" height="100" rx="6" fill="#ffffff" opacity="0.92"/>' // &
        '<rect x="108" y="30" width="84" height="45" rx="6" fill="#ffd43b"/>' // &
        '<rect x="108" y="85" width="84" height="45" rx="6" fill="#41cd52"/>' // &
        '<path d="M40 50 h46 M40 66 h36 M40 82 h42 M40 98 h28" stroke="#2b5b84" stroke-width="6"/></svg>'
    character(len=*), parameter :: reload_svg = &
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M20 12a8 8 0 1 1-2.3-5.6" ' // &
        'fill="none" stroke="#2b7bd6" stroke-width="2.5"/><path d="M20 3v6h-6z" fill="#2b7bd6"/></svg>'
    character(len=*), parameter :: export_svg = &
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" ' // &
        'rx="2" fill="none" stroke="#3a9a4a" stroke-width="2"/><rect x="3" y="3" width="6" height="18" ' // &
        'fill="#3a9a4a"/><rect x="9" y="15" width="12" height="6" fill="#9ad3a3"/></svg>'

contains

    ! ------------------------------------------------------------------
    ! the project's files

    !> Read the folder into the tree and the file list, and watch its folders.
    subroutine load_project(s)
        type(app_state), intent(inout) :: s
        type(QTreeWidgetItem) :: none
        type(qt_string), allocatable :: watched(:)
        integer :: i
        call s%tree%clear()
        s%nfiles = 0
        if (.not. allocated(s%files)) allocate(s%files(64))
        watched = s%watcher%directories()
        do i = 1, size(watched)
            if (s%watcher%removePath(watched(i)%s)) continue
        end do
        call add_folder(s, s%root, none, 1)
        call s%files_model%setRowCount(s%nfiles)
        call s%files_model%refresh()
        call s%tree%resizeColumnToContents(0)
    end subroutine load_project

    !> Add the entries of `dir` under `parent` (a null item: top level).
    recursive subroutine add_folder(s, dir, parent, depth)
        type(app_state), intent(inout) :: s
        character(len=*), intent(in) :: dir
        type(QTreeWidgetItem), intent(in) :: parent
        integer, intent(in) :: depth
        type(qt_string), allocatable :: names(:)
        type(QTreeWidgetItem) :: item
        type(QIcon) :: icon
        character(len=:), allocatable :: path
        integer :: i
        if (s%watcher%addPath(dir)) continue
        names = QDir_entryList(dir)
        do i = 1, size(names)
            if (skipped(names(i)%s)) cycle
            path = dir//'/'//names(i)%s
            if (parent%isNull()) then
                item = QTreeWidgetItem(s%tree, [character(len=len(names(i)%s)) :: names(i)%s])
            else
                item = QTreeWidgetItem(parent, [character(len=len(names(i)%s)) :: names(i)%s])
            end if
            icon = s%icons%icon(path)
            call item%setIcon(0, icon)
            call icon%delete()
            if (QDir_isDir(path)) then
                call item%setToolTip(0, path)
                if (depth < max_depth) call add_folder(s, path, item, depth + 1)
            else
                call add_file(s, path, names(i)%s, dir)
                call item%setData(0, s%nfiles)     ! the file's index in s%files
                call item%setToolTip(0, path)
            end if
        end do
    end subroutine add_folder

    !> Names not shown: hidden files and build output.
    logical function skipped(name)
        character(len=*), intent(in) :: name
        skipped = name(1:1) == '.' .or. name == 'build' .or. name == 'node_modules' .or. name == '__pycache__'
    end function skipped

    !> Append a file to the list.
    subroutine add_file(s, path, name, folder)
        type(app_state), intent(inout) :: s
        character(len=*), intent(in) :: path, name, folder
        type(file_entry), allocatable :: grown(:)
        integer :: bytes
        if (s%nfiles == size(s%files)) then
            allocate(grown(2 * size(s%files)))
            grown(1:s%nfiles) = s%files(1:s%nfiles)
            call move_alloc(grown, s%files)
        end if
        s%nfiles = s%nfiles + 1
        inquire(file=path, size=bytes)
        ! (component by component: a structure constructor here crashes gfortran 15)
        s%files(s%nfiles)%path = path
        s%files(s%nfiles)%name = name
        s%files(s%nfiles)%folder = relative(s, folder)
        s%files(s%nfiles)%bytes = bytes
    end subroutine add_file

    !> `path` relative to the project folder.
    function relative(s, path) result(rel)
        type(app_state), intent(in) :: s
        character(len=*), intent(in) :: path
        character(len=:), allocatable :: rel
        rel = '.'
        if (len(path) > len(s%root)) rel = path(len(s%root) + 2:)
    end function relative

    !> The text of a file ('' and `ok` false if it is unreadable, too large or binary).
    function read_file(path, ok) result(text)
        character(len=*), intent(in) :: path
        logical, intent(out) :: ok
        character(len=:), allocatable :: text
        integer :: u, ios, n
        text = ''
        ok = .false.
        open(newunit=u, file=path, access='stream', form='unformatted', action='read', status='old', iostat=ios)
        if (ios /= 0) return
        inquire(unit=u, size=n)
        if (n >= 0 .and. n <= max_bytes) then
            deallocate(text)
            allocate(character(len=n) :: text)
            read(u, iostat=ios) text
            ok = ios == 0 .and. index(text, achar(0)) == 0
            if (.not. ok) text = ''
        end if
        close(u)
    end function read_file

    !> Show file `k`, and watch it.
    subroutine open_file(s, k)
        type(app_state), intent(inout) :: s
        integer, intent(in) :: k
        character(len=:), allocatable :: text
        logical :: ok
        if (k < 1 .or. k > s%nfiles) return
        if (s%current > 0) then
            if (s%watcher%removePath(s%files(s%current)%path)) continue
        end if
        s%current = k
        text = read_file(s%files(k)%path, ok)
        if (ok) then
            call s%viewer%setPlainText(text)
        else
            call s%viewer%setPlainText('(binary, unreadable or larger than 500 kB)')
        end if
        if (s%watcher%addPath(s%files(k)%path)) continue
        call s%window%setWindowTitle(s%files(k)%name//' - qt-fortran IDE')
        call s%file_type%setText(s%icons%typeName(s%files(k)%path)//', '//itoa(s%files(k)%bytes)//' bytes')
        call s%status%showMessage(s%files(k)%path, 4000)
    end subroutine open_file

    !> Select file `k` in the tree (found by its data).
    subroutine select_in_tree(s, k)
        type(app_state), intent(inout) :: s
        integer, intent(in) :: k
        type(QTreeWidgetItem) :: item
        item = s%tree%findData(k)
        if (item%isNull()) return
        call s%tree%setCurrentItem(item)
        call s%tree%scrollToItem(item)
    end subroutine select_in_tree

    !> Append a line to the log dock.
    subroutine log_line(s, text)
        type(app_state), intent(inout) :: s
        character(len=*), intent(in) :: text
        call s%log%appendPlainText(text)
    end subroutine log_line

    !> An integer as text.
    function itoa(i) result(str)
        integer, intent(in) :: i
        character(len=:), allocatable :: str
        character(len=16) :: buf
        write(buf, '(I0)') i
        str = trim(buf)
    end function itoa

    ! ------------------------------------------------------------------
    ! slots

    !> A tree item was clicked: open its file (folders have no data).
    subroutine on_item_clicked(item, column, data)
        type(QTreeWidgetItem), intent(in) :: item
        integer, intent(in) :: column
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            if (item%data() > 0) call open_file(s, item%data())
        end select
    end subroutine on_item_clicked

    !> The open file or a folder changed on disk.
    subroutine on_file_changed(path, data)
        character(len=*), intent(in) :: path
        class(*), intent(inout), optional :: data
        integer :: k
        select type (s => data)
        type is (app_state)
            if (s%current < 1) return
            k = s%current
            if (path /= s%files(k)%path) return
            if (QDir_isDir(path)) return
            call log_line(s, 'changed on disk: '//path)
            s%current = 0
            call open_file(s, k)      ! reload; and watch it again (editors often replace the file)
        end select
    end subroutine on_file_changed

    !> A folder's entries changed: rebuild, keeping the open file.
    subroutine on_directory_changed(path, data)
        character(len=*), intent(in) :: path
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: open_path
        integer :: k
        select type (s => data)
        type is (app_state)
            call log_line(s, 'folder changed: '//path)
            open_path = ''
            if (s%current > 0) open_path = s%files(s%current)%path
            call load_project(s)
            s%current = 0
            do k = 1, s%nfiles
                if (s%files(k)%path == open_path) then
                    s%current = k
                    call select_in_tree(s, k)
                end if
            end do
        end select
    end subroutine on_directory_changed

    !> Cells of the quick-open table.
    subroutine on_file_cell(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            if (row + 1 > s%nfiles) return
            select case (column)
            case (0)
                call request%setText(s%files(row + 1)%name)
            case (1)
                call request%setText(s%files(row + 1)%folder)
            case (2)
                call request%setNumber(real(s%files(row + 1)%bytes, c_double))
                call request%setAlignment(ior(Qt_AlignRight, Qt_AlignVCenter))
            end select
        end select
    end subroutine on_file_cell

    !> The quick-open filter: the typed letters appear in order in the file's
    !> folder and name (case-insensitive), e.g. 'wdgf' matches widgets/qt_widgets.f90.
    subroutine on_filter(row, data)
        type(QtfFilterRow), intent(in) :: row
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            if (len(s%pattern) == 0) return
            if (.not. fuzzy_match(s%pattern, s%files(row%row() + 1)%folder//'/'//s%files(row%row() + 1)%name)) &
                call row%setAccepted(.false.)
        end select
    end subroutine on_filter

    !> True if the characters of `pattern` occur in `text` in order (ignoring case).
    logical function fuzzy_match(pattern, text)
        character(len=*), intent(in) :: pattern, text
        integer :: i, j
        j = 1
        do i = 1, len(text)
            if (j > len(pattern)) exit
            if (lower(text(i:i)) == lower(pattern(j:j))) j = j + 1
        end do
        fuzzy_match = j > len(pattern)
    end function fuzzy_match

    !> A letter in lower case.
    pure character function lower(c)
        character, intent(in) :: c
        lower = c
        if (c >= 'A' .and. c <= 'Z') lower = achar(iachar(c) + 32)
    end function lower

    !> The query changed: filter again.
    subroutine on_query(text, data)
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            s%pattern = trim(text)
            call s%proxy%invalidateFilter()
            call s%status%showMessage(itoa(s%proxy%rowCount())//' of '//itoa(s%nfiles)//' files', 2000)
        end select
    end subroutine on_query

    !> Enter or a double click in the quick-open list: open the file.
    subroutine on_quick_open(row, column, data)
        integer, intent(in) :: row, column
        class(*), intent(inout), optional :: data
        integer :: k
        select type (s => data)
        type is (app_state)
            k = s%proxy%mapToSourceRow(row) + 1
            call open_file(s, k)
            call select_in_tree(s, k)
        end select
    end subroutine on_quick_open

    !> Enter in the query box: open the first match.
    subroutine on_query_enter(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            if (s%proxy%rowCount() > 0) call on_quick_open(0, 0, s)
        end select
    end subroutine on_query_enter

    !> Draw the logo, centered, keeping its aspect ratio.
    subroutine on_paint_logo(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            call s%logo%render(painter, 8.0_c_double, 8.0_c_double, real(painter%deviceWidth() - 16, c_double), &
                               real(painter%deviceHeight() - 16, c_double))
        end select
    end subroutine on_paint_logo

    !> A dock moved.
    subroutine on_dock_moved(area, data)
        integer, intent(in) :: area
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: name
        select type (s => data)
        type is (app_state)
            select case (area)
            case (Qt_LeftDockWidgetArea)
                name = 'left'
            case (Qt_RightDockWidgetArea)
                name = 'right'
            case (Qt_TopDockWidgetArea)
                name = 'top'
            case (Qt_BottomDockWidgetArea)
                name = 'bottom'
            case default
                name = 'no'
            end select
            call log_line(s, 'a dock moved to the '//name//' area')
        end select
    end subroutine on_dock_moved

    !> View > Layout: 0 side panels, 1 stacked.
    subroutine on_layout(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            call apply_layout(s, index)
        end select
    end subroutine on_layout

    !> Arrange the docks.
    subroutine apply_layout(s, layout)
        type(app_state), intent(inout) :: s
        integer, intent(in) :: layout
        call s%window%setCorner(Qt_BottomLeftCorner, Qt_LeftDockWidgetArea)   ! the left docks run to the bottom
        call s%window%addDockWidget(Qt_LeftDockWidgetArea, s%project_dock)
        call s%window%addDockWidget(Qt_BottomDockWidgetArea, s%quick_dock)
        select case (layout)
        case (0)    ! project left, preview right, quick open and log as tabs below
            call s%window%addDockWidget(Qt_RightDockWidgetArea, s%preview_dock)
            call s%window%tabifyDockWidget(s%quick_dock, s%log_dock)
            call s%quick_dock%raise()
            call s%window%resizeDocks([s%project_dock, s%preview_dock], [260, 240], Qt_Horizontal)
        case (1)    ! preview below the project; quick open and log side by side
            call s%window%addDockWidget(Qt_LeftDockWidgetArea, s%preview_dock)
            call s%window%splitDockWidget(s%project_dock, s%preview_dock, Qt_Vertical)
            call s%window%addDockWidget(Qt_BottomDockWidgetArea, s%log_dock)
            call s%window%splitDockWidget(s%quick_dock, s%log_dock, Qt_Horizontal)
            call s%window%resizeDocks([s%project_dock], [260], Qt_Horizontal)
            call s%window%resizeDocks([s%project_dock, s%preview_dock], [420, 200], Qt_Vertical)
            call s%window%resizeDocks([s%quick_dock, s%log_dock], [520, 300], Qt_Horizontal)
        end select
        call s%window%resizeDocks([s%quick_dock], [190], Qt_Vertical)
    end subroutine apply_layout

    !> View > Tabs on top.
    subroutine on_tabs_on_top(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            if (checked) then
                call s%window%setTabPosition(Qt_AllDockWidgetAreas, QTabWidget_North)
            else
                call s%window%setTabPosition(Qt_AllDockWidgetAreas, QTabWidget_South)
            end if
        end select
    end subroutine on_tabs_on_top

    !> Rebuild the tree.
    subroutine on_reload(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            call on_directory_changed(s%root, s)
        end select
    end subroutine on_reload

    !> File > Export layout as SVG.
    subroutine on_export(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        select type (s => data)
        type is (app_state)
            path = QFileDialog_getSaveFileName('Export layout', 'layout.svg', 'SVG files (*.svg)', s%window)
            if (len(path) == 0) return
            call export_layout(s, path)
            call s%status%showMessage('Wrote '//path, 4000)
        end select
    end subroutine on_export

    !> Draw the window's docks and central widget into an SVG file.
    subroutine export_layout(s, path)
        type(app_state), intent(inout) :: s
        character(len=*), intent(in) :: path
        type(QSvgGenerator) :: svg
        type(QPainter) :: p
        type(QWidget) :: central
        svg = QSvgGenerator(path, s%window%width(), s%window%height())
        call svg%setTitle('Dock layout')
        p = QPainter(svg)
        call p%fillRect(0, 0, s%window%width(), s%window%height(), QColor(245, 245, 245))
        central = s%window%centralWidget()
        call box(central%geometry(), 'Viewer', QColor(220, 220, 220), QColor(40, 40, 40))
        call dock_box(s%project_dock, QColor(43, 91, 132))
        call dock_box(s%preview_dock, QColor(230, 180, 40))
        call dock_box(s%quick_dock, QColor(65, 160, 82))
        call dock_box(s%log_dock, QColor(150, 90, 160))
        call p%end()
        call svg%delete()
    contains
        !> A visible, docked dock's rectangle.
        subroutine dock_box(dock, color)
            type(QDockWidget), intent(in) :: dock
            type(QColor), intent(in) :: color
            if (dock%isVisible() .and. .not. dock%isFloating()) &
                call box(dock%geometry(), dock%windowTitle(), color, QColor(255, 255, 255))
        end subroutine dock_box
        !> A filled rectangle with a title.
        subroutine box(r, title, color, ink)
            type(QRect), intent(in) :: r
            character(len=*), intent(in) :: title
            type(QColor), intent(in) :: color, ink
            call p%fillRect(r%x + 2, r%y + 2, r%width - 4, r%height - 4, color)
            call p%setPen(ink)
            call p%drawText(r%x + 10, r%y + 22, title)
        end subroutine box
    end subroutine export_layout

    !> File > Quit.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

    !> Save the window for `--screenshot` and quit.
    subroutine on_screenshot(data)
        class(*), intent(inout), optional :: data
        type(QPixmap) :: pix
        select type (s => data)
        type is (app_state)
            pix = s%window%grab()
            if (.not. pix%save(s%screenshot)) write(*, '(A)') 'could not save '//s%screenshot
            call pix%delete()
            call QApplication_quit()
        end select
    end subroutine on_screenshot

end module ide_app

!> The IDE window: docks, menus, tool bar; open the README.
program ide

    use ide_app
    implicit none

    type(QApplication) :: app
    type(app_state), target :: s
    type(QWidget) :: quick, bar_widget
    type(QVBoxLayout) :: quick_layout
    type(QLabel) :: title
    type(QVBoxLayout) :: preview_layout
    type(QWidget) :: preview
    type(QMenuBar) :: bar
    type(QMenu) :: file, view, layout_menu
    type(QToolBar) :: tools
    type(QAction) :: act, reload, export
    type(QActionGroup) :: layouts
    type(QHeaderView) :: header
    type(QIcon) :: icon
    type(QSvgRenderer) :: icon_svg
    character(len=1024) :: arg
    integer :: ierr, k, iarg

    app = QApplication()
    s%root = QDir_currentPath()
    s%pattern = ''
    iarg = 1
    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        iarg = 3
    end if
    call get_command_argument(iarg, arg)
    if (len_trim(arg) > 0) s%root = trim(arg)

    s%window = QMainWindow()
    call s%window%setWindowTitle('qt-fortran IDE')
    call s%window%setObjectName('ide')
    s%status = s%window%statusBar()
    s%icons = QFileIconProvider()
    s%watcher = QFileSystemWatcher(s%window)
    call s%watcher%fileChanged%connect(on_file_changed, s)
    call s%watcher%directoryChanged%connect(on_directory_changed, s)

    ! the viewer
    s%viewer = QPlainTextEdit()
    call s%viewer%setReadOnly(.true.)
    call s%viewer%setLineWrapMode(QPlainTextEdit_NoWrap)
    call s%viewer%setFont(QFont(QFontDatabase_fixedFamily(), 12))
    call s%viewer%setPlaceholderText('Open a file from the Project dock or with Quick open')
    call s%window%setCentralWidget(s%viewer)

    ! Project dock: the file tree (items carry file indices)
    s%tree = QTreeWidget()
    call s%tree%setHeaderHidden(.true.)
    call s%tree%itemClicked%connect(on_item_clicked, s)
    s%project_dock = QDockWidget('Project', s%window)
    call s%project_dock%setObjectName('project')
    call s%project_dock%setWidget(s%tree)

    ! Preview dock: an SVG logo with a size hint from Fortran, a compact title bar
    preview = QWidget()
    preview_layout = QVBoxLayout(preview)
    s%logo = QSvgRenderer(logo_svg, s%window)
    call s%logo%setAspectRatioMode(Qt_KeepAspectRatio)
    s%logo_view = QtfWidget()
    call s%logo_view%setSizeHint(220, 160)
    call s%logo_view%setMinimumSizeHint(110, 80)
    call s%logo_view%paintEvent%connect(on_paint_logo, s)
    call preview_layout%addWidget(s%logo_view)
    s%file_type = QLabel('No file open')
    call s%file_type%setWordWrap(.true.)
    call preview_layout%addWidget(s%file_type)
    s%preview_dock = QDockWidget('Preview', s%window)
    call s%preview_dock%setObjectName('preview')
    call s%preview_dock%setWidget(preview)
    title = QLabel('  PREVIEW')
    call title%setStyleSheet('font-size: 10px; font-weight: bold; padding: 4px; color: palette(mid);')
    call s%preview_dock%setTitleBarWidget(title)

    ! Quick open dock: a query and the files through the Fortran filter
    quick = QWidget()
    quick_layout = QVBoxLayout(quick)
    call quick_layout%setContentsMargins(4, 4, 4, 4)
    s%query = QLineEdit()
    call s%query%setPlaceholderText('Type letters of a file''s folder and name, e.g. shimcpp for src/shim/*.cpp')
    call s%query%setClearButtonEnabled(.true.)
    call s%query%textChanged%connect(on_query, s)
    call s%query%returnPressed%connect(on_query_enter, s)
    call quick_layout%addWidget(s%query)
    s%files_model = QtfTableModel(0, 3, s%window)
    call s%files_model%setHorizontalHeaderLabels([character(len=6) :: 'Name', 'Folder', 'Bytes'])
    call s%files_model%dataRequested%connect(on_file_cell, s)
    s%proxy = QtfSortFilterProxyModel(s%window)
    call s%proxy%setSourceModel(s%files_model)
    call s%proxy%filterAcceptsRow%connect(on_filter, s)
    s%files_view = QTableView()
    call s%files_view%setModel(s%proxy)
    call s%files_view%setSortingEnabled(.true.)
    call s%files_view%setSelectionBehavior(QAbstractItemView_SelectRows)
    call s%files_view%setEditTriggers(QAbstractItemView_NoEditTriggers)
    call s%files_view%setVerticalHeaderVisible(.false.)
    call s%files_view%activated%connect(on_quick_open, s)
    header = s%files_view%horizontalHeader()
    call header%setSectionResizeMode(0, QHeaderView_ResizeToContents)
    call header%setSectionResizeMode(1, QHeaderView_Stretch)
    call header%setSectionResizeMode(2, QHeaderView_ResizeToContents)
    call s%files_view%sortByColumn(0, Qt_AscendingOrder)
    call quick_layout%addWidget(s%files_view)
    s%quick_dock = QDockWidget('Quick open', s%window)
    call s%quick_dock%setObjectName('quick')
    call s%quick_dock%setWidget(quick)

    ! Log dock
    s%log = QPlainTextEdit()
    call s%log%setReadOnly(.true.)
    s%log_dock = QDockWidget('Log', s%window)
    call s%log_dock%setObjectName('log')
    call s%log_dock%setWidget(s%log)


    ! menus and tool bar (icons drawn from SVG text)
    bar = s%window%menuBar()
    file = bar%addMenu('&File')
    tools = s%window%addToolBar('Main')
    call tools%setObjectName('main-toolbar')
    call tools%setIconSize(20, 20)
    icon_svg = QSvgRenderer(reload_svg)
    icon = icon_svg%toIcon(40, 40)
    reload = QAction('&Reload project', s%window)
    call reload%setIcon(icon)
    call icon%delete()
    call reload%setStandardShortcut(QKeySequence_Refresh)
    call reload%triggered%connect(on_reload, s)
    if (.not. icon_svg%load(export_svg)) stop 'bad icon'
    icon = icon_svg%toIcon(40, 40)
    export = QAction('&Export layout as SVG...', s%window)
    call export%setIcon(icon)
    call icon%delete()
    call icon_svg%delete()
    call export%triggered%connect(on_export, s)
    call file%addAction(reload)
    call file%addAction(export)
    call file%addSeparator()
    act = QAction('&Quit', s%window)
    call act%setStandardShortcut(QKeySequence_Quit)
    call act%triggered%connect(on_quit)
    call file%addAction(act)
    call tools%addAction(reload)
    call tools%addAction(export)

    view = bar%addMenu('&View')
    call view%addAction(s%project_dock%toggleViewAction())
    call view%addAction(s%preview_dock%toggleViewAction())
    call view%addAction(s%quick_dock%toggleViewAction())
    call view%addAction(s%log_dock%toggleViewAction())
    call view%addSeparator()
    layout_menu = view%addMenu('&Layout')
    layouts = QActionGroup(s%window)
    act = QAction('&Side panels', s%window)
    call act%setCheckable(.true.)
    call act%setChecked(.true.)
    call layouts%addAction(act)
    call layout_menu%addAction(act)
    act = QAction('S&tacked', s%window)
    call act%setCheckable(.true.)
    call layouts%addAction(act)
    call layout_menu%addAction(act)
    call layouts%triggered%connect(on_layout, s)
    act = QAction('&Tabs on top', s%window)
    call act%setCheckable(.true.)
    call act%toggled%connect(on_tabs_on_top, s)
    call view%addAction(act)

    call s%window%setDockOptions(ior(ior(QMainWindow_AnimatedDocks, QMainWindow_AllowTabbedDocks), &
                                     QMainWindow_AllowNestedDocks))
    call s%window%resize(1100, 720)
    call apply_layout(s, 0)
    call s%project_dock%dockLocationChanged%connect(on_dock_moved, s)
    call s%preview_dock%dockLocationChanged%connect(on_dock_moved, s)
    call s%quick_dock%dockLocationChanged%connect(on_dock_moved, s)
    call s%log_dock%dockLocationChanged%connect(on_dock_moved, s)
    call load_project(s)
    call log_line(s, 'project: '//s%root//' ('//itoa(s%nfiles)//' files)')

    ! open the README if there is one
    do k = 1, s%nfiles
        if (s%files(k)%name == 'README.md' .and. s%files(k)%folder == '.') then
            call open_file(s, k)
            call select_in_tree(s, k)
        end if
    end do

    if (allocated(s%screenshot)) then
        call s%query%setText('shimcpp')
        call QTimer_singleShot(500, on_screenshot, s)
    end if
    call s%window%show()
    ierr = app%exec()
    call s%icons%delete()

end program ide
