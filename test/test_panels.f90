!> What application panels need: dock layout (QMainWindow, QDockWidget), data
!> stored with items (QTreeWidgetItem, QTableWidgetItem, QListWidget), file
!> watching and icons (QFileSystemWatcher, QFileIconProvider), SVG
!> (QSvgRenderer, QSvgGenerator), size hints from Fortran (QtfWidget) and a
!> Fortran row filter (QtfSortFilterProxyModel). Run headless with
!> QT_QPA_PLATFORM=offscreen.
module test_panels_slots

    use qt
    implicit none

    !> What the slots saw, and the filter's settings.
    type :: panel_log
        integer :: calls = 0, value = -9
        character(len=:), allocatable :: path
        character(len=:), allocatable :: file   !! the file the timer modifies
        integer :: filter_mode = 0              !! 0: accept all, 1: even rows only, 2: reject node 4
        integer :: filter_calls = 0
        integer :: parent_of_3 = -9
        logical :: saw_standard_reject = .false.
    end type panel_log

    character(len=*), parameter :: names(5) = [character(len=7) :: 'alpha', 'beta', 'gamma', 'delta', 'epsilon']

contains

    !> Record an integer.
    subroutine on_int(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (panel_log)
            data%calls = data%calls + 1
            data%value = value
        end select
    end subroutine on_int

    !> Record a changed path and stop the event loop.
    subroutine on_path(path, data)
        character(len=*), intent(in) :: path
        class(*), intent(inout), optional :: data
        select type (data)
        type is (panel_log)
            data%calls = data%calls + 1
            data%path = path
        end select
        call QApplication_quit()
    end subroutine on_path

    !> Append a line to the watched file.
    subroutine modify_file(data)
        class(*), intent(inout), optional :: data
        integer :: u
        select type (data)
        type is (panel_log)
            open(newunit=u, file=data%file, position='append', action='write')
            write(u, '(A)') 'changed'
            close(u)
        end select
    end subroutine modify_file

    !> Stop a hung event loop.
    subroutine on_timeout(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_timeout

    !> Table cells: a name and a row number.
    subroutine on_cell(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        if (column == 0) then
            call request%setText(trim(names(row + 1)))
        else
            call request%setInt(row)
        end if
    end subroutine on_cell

    !> Tree cells: node names.
    subroutine on_node(node, column, request, data)
        integer, intent(in) :: node, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        call request%setText(trim(names(node)))
    end subroutine on_node

    !> The Fortran filter.
    subroutine on_filter(row, data)
        type(QtfFilterRow), intent(in) :: row
        class(*), intent(inout), optional :: data
        select type (data)
        type is (panel_log)
            data%filter_calls = data%filter_calls + 1
            if (.not. row%isAccepted()) data%saw_standard_reject = .true.
            select case (data%filter_mode)
            case (1)
                if (mod(row%row(), 2) /= 0) call row%setAccepted(.false.)
            case (2)
                if (row%node() == 3) data%parent_of_3 = row%parentNode()
                if (row%node() == 4) call row%setAccepted(.false.)
            end select
        end select
    end subroutine on_filter

end module test_panels_slots

!> Tests for docks, item data, file watching, icons, SVG, size hints and filtering.
program test_panels

    use qt
    use testing
    use test_panels_slots
    use iso_c_binding, only: c_double, c_associated
    implicit none

    type(QApplication) :: app
    type(panel_log), target :: log
    type(qt_string), allocatable :: list(:)
    integer :: ierr, u

    app = QApplication()

    call test_docks()
    call test_item_data()
    call test_files()
    call test_svg()
    call test_size_hints()
    call test_filter()

contains

    !> Dock layout: split, tabify, resize, corners, tab position, options, signals, title bar.
    subroutine test_docks()
        type(QMainWindow) :: win
        type(QDockWidget) :: d1, d2, d3, d4
        type(QDockWidget), allocatable :: tabbed(:)
        type(QLabel) :: title
        type(QWidget) :: bar
        integer :: h
        win = QMainWindow()
        call win%setCentralWidget(QLabel('central'))
        d1 = QDockWidget('Project')
        d2 = QDockWidget('Outline')
        d3 = QDockWidget('Problems')
        d4 = QDockWidget('Output')
        call d1%setObjectName('d1')
        call d2%setObjectName('d2')
        call d3%setObjectName('d3')
        call d4%setObjectName('d4')
        call d1%setWidget(QLabel('files'))
        call d2%setWidget(QLabel('symbols'))
        call d3%setWidget(QLabel('problems'))
        call d4%setWidget(QLabel('output'))
        call win%addDockWidget(Qt_LeftDockWidgetArea, d1)
        call win%splitDockWidget(d1, d2, Qt_Vertical)
        call win%addDockWidget(Qt_BottomDockWidgetArea, d3)
        call win%tabifyDockWidget(d3, d4)
        call check(win%dockWidgetArea(d2) == Qt_LeftDockWidgetArea, 'splitDockWidget: same area')
        tabbed = win%tabifiedDockWidgets(d3)
        call check(size(tabbed) == 1, 'tabifiedDockWidgets: one other dock')
        if (size(tabbed) == 1) call check(tabbed(1)%objectName() == 'd4', 'tabifiedDockWidgets: the right dock')
        tabbed = win%tabifiedDockWidgets(d1)
        call check(size(tabbed) == 0, 'tabifiedDockWidgets: none')
        call check(win%dockWidgetArea(d4) == Qt_BottomDockWidgetArea, 'dockWidgetArea')

        call win%setCorner(Qt_BottomLeftCorner, Qt_LeftDockWidgetArea)
        call check(win%corner(Qt_BottomLeftCorner) == Qt_LeftDockWidgetArea, 'setCorner / corner')
        call win%setTabPosition(Qt_BottomDockWidgetArea, QTabWidget_North)
        call check(win%tabPosition(Qt_BottomDockWidgetArea) == QTabWidget_North, 'setTabPosition / tabPosition')
        call win%setTabShape(QTabWidget_Triangular)
        call win%setDockOptions(ior(QMainWindow_AllowTabbedDocks, QMainWindow_AllowNestedDocks))
        call check(win%dockOptions() == ior(QMainWindow_AllowTabbedDocks, QMainWindow_AllowNestedDocks), &
                   'setDockOptions / dockOptions')
        call check(win%isDockNestingEnabled(), 'AllowNestedDocks: nesting enabled')
        call win%setDockNestingEnabled(.false.)
        call check(.not. win%isDockNestingEnabled(), 'setDockNestingEnabled')

        ! sizes need a laid-out window
        call win%resize(900, 700)
        call win%show()
        call QApplication_processEvents()
        call win%resizeDocks([d1], [300], Qt_Horizontal)
        call QApplication_processEvents()
        call check(abs(d1%width() - 300) <= 10, 'resizeDocks: width')
        ! (the bottom area also holds the tab bar of d3 and d4)
        call win%resizeDocks([d4], [200], Qt_Vertical)
        call QApplication_processEvents()
        h = d4%height()
        call win%resizeDocks([d4], [300], Qt_Vertical)
        call QApplication_processEvents()
        call check(abs(d4%height() - h - 100) <= 10, 'resizeDocks: height')

        ! signals and title bar
        log = panel_log()
        call d2%dockLocationChanged%connect(on_int, log)
        call win%addDockWidget(Qt_RightDockWidgetArea, d2)
        call check(log%calls >= 1 .and. log%value == Qt_RightDockWidgetArea, 'dockLocationChanged')
        log = panel_log()
        call d1%featuresChanged%connect(on_int, log)
        call d1%setFeatures(QDockWidget_DockWidgetMovable)
        call check(log%calls == 1 .and. log%value == QDockWidget_DockWidgetMovable, 'featuresChanged')
        call check(d1%features() == QDockWidget_DockWidgetMovable, 'features')
        call d1%setAllowedAreas(ior(Qt_LeftDockWidgetArea, Qt_RightDockWidgetArea))
        call check(d1%isAreaAllowed(Qt_RightDockWidgetArea) .and. .not. d1%isAreaAllowed(Qt_TopDockWidgetArea), &
                   'isAreaAllowed')
        call check(d1%allowedAreas() == ior(Qt_LeftDockWidgetArea, Qt_RightDockWidgetArea), 'allowedAreas')
        bar = d3%titleBarWidget()
        call check(.not. c_associated(bar%ptr), 'titleBarWidget: none by default')
        title = QLabel('custom title')
        call d3%setTitleBarWidget(title)
        bar = d3%titleBarWidget()
        call check(c_associated(bar%ptr, title%ptr), 'setTitleBarWidget')
        call d3%setTitleBarWidget()
        bar = d3%titleBarWidget()
        call check(.not. c_associated(bar%ptr), 'setTitleBarWidget(): the standard title bar again')
        call win%close()
        call win%delete()
    end subroutine test_docks

    !> Integers and strings stored with tree, table and list items.
    subroutine test_item_data()
        type(QTreeWidget) :: tree
        type(QTreeWidgetItem) :: a, b, c, found
        type(QTableWidget) :: table
        type(QTableWidgetItem) :: cell, hit
        type(QListWidget) :: lst
        integer :: r
        tree = QTreeWidget()
        call tree%setColumnCount(2)
        a = QTreeWidgetItem(tree, ['src  ', 'dir  '])
        b = QTreeWidgetItem(a, ['main.f90', 'file    '])
        c = QTreeWidgetItem(a, ['util.f90', 'file    '])
        call check(a%data() == -1 .and. a%stringData() == '', 'item data: none by default')
        call a%setData(0, 10)
        call b%setData(0, 11)
        call c%setData(0, 12)
        call c%setData(1, 'src/util.f90')
        call check(b%data() == 11 .and. c%data(0) == 12, 'QTreeWidgetItem setData / data')
        call check(c%stringData(1) == 'src/util.f90' .and. c%data(1) == -1, 'QTreeWidgetItem string data per column')
        found = tree%findData(12)
        call check(.not. found%isNull(), 'QTreeWidget findData')
        if (.not. found%isNull()) call check(found%text(0) == 'util.f90', 'findData: the right item')
        found = tree%findData(99)
        call check(found%isNull(), 'findData: not found')
        call check(a%indexOfChild(c) == 1, 'indexOfChild')
        call tree%scrollToItem(c)
        call c%setSelected(.true.)
        call check(c%isSelected(), 'setSelected')
        call b%setHidden(.true.)
        call check(b%isHidden(), 'setHidden')
        call a%takeChild(0)
        call check(a%childCount() == 1 .and. tree%indexOfTopLevelItem(a) == 0, 'takeChild, indexOfTopLevelItem')
        call tree%takeTopLevelItem(0)
        call check(tree%topLevelItemCount() == 0, 'takeTopLevelItem')
        call tree%delete()

        ! a table: data follows its item when sorting
        table = QTableWidget(3, 1)
        do r = 0, 2
            cell = QTableWidgetItem(trim(names(3 - r)))    ! gamma, beta, alpha
            call cell%setData(100 + r)
            call table%setItem(r, 0, cell)
        end do
        cell = table%item(0, 0)
        call cell%setData('first')
        call check(cell%stringData() == 'first', 'QTableWidgetItem string data')
        call cell%setData(100)
        call table%sortItems(0)
        cell = table%item(0, 0)
        call check(cell%text() == 'alpha' .and. cell%data() == 102, 'QTableWidgetItem data moves with sorting')
        hit = table%findData(100)
        call check(.not. hit%isNull(), 'QTableWidget findData')
        if (.not. hit%isNull()) call check(hit%row() == 2 .and. hit%text() == 'gamma', 'QTableWidget findData: row')
        call table%delete()

        ! a list
        lst = QListWidget()
        call lst%addItems(['delta', 'alpha', 'gamma'])
        do r = 0, 2
            call lst%setItemData(r, 7 * r)
        end do
        call lst%setItemData(1, 'a string')
        call check(lst%itemStringData(1) == 'a string' .and. lst%itemData(1) == -1, 'QListWidget string data')
        call lst%setItemData(1, 7)
        call lst%sortItems()
        call check(lst%itemText(0) == 'alpha' .and. lst%itemData(0) == 7, 'QListWidget data moves with sorting')
        call check(lst%findData(14) == 2 .and. lst%findData(5) == -1, 'QListWidget findData')
        call check(lst%itemData(10) == -1, 'itemData: no such row')
        call lst%delete()
    end subroutine test_item_data

    !> QFileSystemWatcher (with a change made from a timer) and QFileIconProvider.
    subroutine test_files()
        type(QFileSystemWatcher) :: watcher
        type(QFileIconProvider) :: icons
        type(QIcon) :: icon
        character(len=:), allocatable :: dir, file
        dir = QDir_tempPath()//'/qtf_test_panels'
        call check(QDir_mkpath(dir), 'temporary directory')
        file = dir//'/watched.txt'
        open(newunit=u, file=file, status='replace', action='write')
        write(u, '(A)') 'original'
        close(u)

        watcher = QFileSystemWatcher()
        call check(watcher%addPath(file), 'addPath (file)')
        call check(watcher%addPath(dir), 'addPath (directory)')
        call check(.not. watcher%addPath(dir//'/no-such-file'), 'addPath: missing file')
        list = watcher%addPaths([character(len=len(dir) + 12) :: dir//'/missing.txt', file])
        call check(size(list) == 2, 'addPaths: returns those not added (missing, already watched)')
        list = watcher%files()
        call check(size(list) == 1, 'files')
        if (size(list) == 1) call check(list(1)%s == file, 'files: the path')
        list = watcher%directories()
        call check(size(list) == 1, 'directories')

        log = panel_log()
        log%file = file
        call watcher%fileChanged%connect(on_path, log)
        call QTimer_singleShot(200, modify_file, log)
        call QTimer_singleShot(10000, on_timeout)
        ierr = app%exec()
        call check(log%calls >= 1, 'fileChanged')
        if (allocated(log%path)) call check(log%path == file, 'fileChanged: the path')
        call check(watcher%removePath(file) .and. .not. watcher%removePath(file), 'removePath')
        list = watcher%removePaths([character(len=len(dir)) :: dir])
        call check(size(list) == 0 .and. size(watcher%directories()) == 0, 'removePaths')
        call watcher%delete()

        icons = QFileIconProvider()
        icon = icons%icon(dir)
        call check(.not. icon%isNull(), 'QFileIconProvider icon (directory)')
        call icon%delete()
        icon = icons%icon(file)
        call check(.not. icon%isNull(), 'QFileIconProvider icon (file)')
        call icon%delete()
        icon = icons%icon(dir//'/no-such-file')
        call check(icon%isNull(), 'QFileIconProvider icon: missing file')
        call icon%delete()
        icon = icons%iconForType(QFileIconProvider_Folder)
        call check(.not. icon%isNull(), 'iconForType')
        call icon%delete()
        call icons%setOptions(QFileIconProvider_DontUseCustomDirectoryIcons)
        call check(len(icons%typeName(file)) > 0, 'typeName')
        call icons%delete()
        call check(QDir_removeRecursively(dir), 'clean up')
    end subroutine test_files

    !> QSvgRenderer (from text and files) and QSvgGenerator (to memory and files).
    subroutine test_svg()
        character(len=*), parameter :: svg = &
            '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10" viewBox="0 0 20 10">' // &
            '<rect id="left" x="0" y="0" width="10" height="10" fill="#ff0000"/>' // &
            '<rect id="right" x="10" y="0" width="10" height="10" fill="#0000ff"/></svg>'
        type(QSvgRenderer) :: r
        type(QSvgGenerator) :: gen
        type(QPainter) :: p
        type(QImage) :: img
        type(QIcon) :: icon
        type(QSize) :: sz
        type(QRectF) :: box
        type(QColor) :: corner
        character(len=:), allocatable :: text, path

        r = QSvgRenderer(svg)
        call check(r%isValid(), 'QSvgRenderer from SVG text')
        sz = r%defaultSize()
        call check(sz%width == 20 .and. sz%height == 10, 'defaultSize')
        box = r%viewBoxF()
        call check(abs(box%width - 20) < 1e-9 .and. abs(box%height - 10) < 1e-9, 'viewBoxF')
        call check(r%elementExists('right') .and. .not. r%elementExists('middle'), 'elementExists')
        box = r%boundsOnElement('right')
        call check(abs(box%x - 10) < 1e-9 .and. abs(box%width - 10) < 1e-9, 'boundsOnElement')
        call check(.not. r%isAnimated(), 'isAnimated')
        img = r%toImage(40, 20)
        call check(img%width() == 40 .and. img%pixelColor(5, 10) == Qt_red .and. img%pixelColor(35, 10) == Qt_blue, &
                   'toImage')
        call img%delete()
        icon = r%toIcon(32, 32)
        call check(.not. icon%isNull(), 'toIcon')
        call icon%delete()

        ! render with a painter: scaled, one element, kept aspect ratio
        img = QImage(40, 40)
        call img%fill(Qt_white)
        p = QPainter(img)
        call r%render(p, 0.0_c_double, 0.0_c_double, 40.0_c_double, 20.0_c_double)
        call r%renderElement(p, 'left', 0.0_c_double, 20.0_c_double, 10.0_c_double, 10.0_c_double)
        call p%end()
        call check(img%pixelColor(30, 10) == Qt_blue .and. img%pixelColor(5, 25) == Qt_red .and. &
                   img%pixelColor(30, 30) == Qt_white, 'render, renderElement')
        call img%delete()
        call check(.not. r%load('<svg broken'), 'load: invalid SVG')
        call r%delete()

        ! write an SVG in memory and to a file
        gen = QSvgGenerator('', 100, 50)
        call gen%setTitle('qt-fortran test')
        call gen%setDescription('two rectangles')
        p = QPainter(gen)
        call p%fillRect(0, 0, 50, 50, Qt_red)
        call p%fillRect(50, 0, 50, 50, Qt_blue)
        call p%end()
        text = gen%contents()
        call check(index(text, '<svg') > 0 .and. index(text, 'qt-fortran test') > 0, 'QSvgGenerator in memory')
        call check(gen%fileName() == '', 'fileName: none')
        call gen%delete()
        r = QSvgRenderer(text)
        call check(r%isValid(), 'the generated SVG loads')
        call r%delete()

        path = QDir_tempPath()//'/qtf_test_panels.svg'
        gen = QSvgGenerator(path, 100, 50)
        p = QPainter(gen)
        call p%fillRect(0, 0, 100, 50, Qt_green)
        call p%end()
        call gen%delete()
        r = QSvgRenderer(path)
        box = r%viewBoxF()
        call check(r%isValid() .and. abs(box%width - 100) < 1e-9 .and. abs(box%height - 50) < 1e-9, &
                   'QSvgGenerator to a file; QSvgRenderer from a file')
        call r%setAspectRatioMode(Qt_KeepAspectRatio)
        img = r%toImage(100, 100)
        corner = img%pixelColor(50, 5)
        call check(img%pixelColor(50, 50) == Qt_green .and. corner%a == 0, 'setAspectRatioMode')
        call img%delete()
        call r%delete()
        open(newunit=u, file=path, status='old')
        close(u, status='delete')
        r = QSvgRenderer(QDir_tempPath()//'/qtf-no-such.svg')
        call check(.not. r%isValid(), 'missing file: not valid')
        call r%delete()
    end subroutine test_svg

    !> Size hints set from Fortran on a QtfWidget, and a layout using them.
    subroutine test_size_hints()
        type(QtfWidget) :: w
        type(QWidget) :: box
        type(QVBoxLayout) :: lay
        type(QSize) :: sz
        w = QtfWidget()
        sz = w%sizeHint()
        call check(sz%width == -1 .and. sz%height == -1, 'QtfWidget: no size hint by default')
        call w%setSizeHint(123, 45)
        sz = w%sizeHint()
        call check(sz%width == 123 .and. sz%height == 45, 'setSizeHint')
        call w%setSizeHint(height=60)
        sz = w%sizeHint()
        call check(sz%width == -1 .and. sz%height == 60, 'setSizeHint: one dimension')
        call w%setMinimumSizeHint(30, 20)
        sz = w%minimumSizeHint()
        call check(sz%width == 30 .and. sz%height == 20, 'setMinimumSizeHint')

        ! a layout uses them
        box = QWidget()
        lay = QVBoxLayout(box)
        call lay%setContentsMargins(0, 0, 0, 0)
        call lay%addWidget(w)
        call w%setSizeHint(200, 150)
        sz = box%sizeHint()
        call check(sz%width == 200 .and. sz%height == 150, 'the layout follows the size hint')
        call box%adjustSize()
        call check(box%width() == 200 .and. box%height() == 150, 'adjustSize')
        call w%setSizeHint(250, 150)
        call box%adjustSize()
        call check(box%width() == 250, 'a new size hint updates the layout')
        call box%delete()
    end subroutine test_size_hints

    !> QtfSortFilterProxyModel with a Fortran filterAcceptsRow slot, on a table and a tree.
    subroutine test_filter()
        type(QtfTableModel) :: table
        type(QtfTreeModel) :: tree
        type(QtfSortFilterProxyModel) :: proxy
        type(QTreeView) :: view
        type(QObject) :: owner
        owner = QObject()
        table = QtfTableModel(5, 2, owner)
        call table%dataRequested%connect(on_cell)
        proxy = QtfSortFilterProxyModel(owner)
        call proxy%setSourceModel(table)
        call check(proxy%rowCount() == 5, 'QtfSortFilterProxyModel: no slot, all rows')

        log = panel_log()
        log%filter_mode = 1
        call proxy%filterAcceptsRow%connect(on_filter, log)
        call check(log%filter_calls >= 5, 'filterAcceptsRow called for each row')
        call check(proxy%rowCount() == 3, 'filterAcceptsRow: even rows only')
        call check(proxy%mapToSourceRow(1) == 2, 'filtered rows map to the source')
        log%filter_mode = 0
        call proxy%invalidateFilter()
        call check(proxy%rowCount() == 5, 'invalidateFilter: filtered again')

        ! combined with the standard filter: rows arrive already judged
        call proxy%setFilterKeyColumn(0)
        call proxy%setFilterFixedString('a')       ! alpha, beta, gamma, delta (not epsilon)
        call check(proxy%rowCount() == 4 .and. log%saw_standard_reject, 'isAccepted: the standard filter''s result')
        log%filter_mode = 1
        call proxy%invalidateFilter()
        call check(proxy%rowCount() == 2, 'both filters')     ! alpha (0), gamma (2)
        call proxy%setFilterFixedString('')

        ! a tree: nodes, parent nodes
        tree = QtfTreeModel(1, owner)
        call tree%dataRequested%connect(on_node)
        call tree%setParents([0, 0, 1, 1, 2])
        log%filter_mode = 2
        call proxy%setSourceModel(tree)
        call check(proxy%rowCount() == 2, 'tree: top-level nodes')
        ! children are filtered when a view asks for them
        view = QTreeView()
        call view%setModel(proxy)
        call view%expandAll()
        call check(log%parent_of_3 == 1, 'tree: node and parentNode')
        call view%setCurrentNode(5)
        call check(view%currentNode() == 5, 'tree: node 5 shown')
        call view%setCurrentNode(4)
        call check(view%currentNode() /= 4, 'tree: node 4 filtered out')
        call view%delete()
        call owner%delete()
    end subroutine test_filter

end program test_panels
