!> Widget options: window flags, accessibility, label text formats, combo box
!> placeholders, slider state, table grids, QListWidget as a QListView,
!> QTreeWidget item geometry and QAction icon text. Run headless with
!> QT_QPA_PLATFORM=offscreen.
program test_widget_options

    use qt
    use testing
    implicit none

    type(QApplication) :: app
    type(QWidget) :: w
    type(QLabel) :: label
    type(QComboBox) :: combo
    type(QSlider) :: slider
    type(QTableWidget) :: table
    type(QListWidget) :: list
    type(QTreeWidget) :: tree
    type(QTreeWidgetItem) :: a, b, hit
    type(QAction) :: act
    type(QRect) :: r

    app = QApplication()

    ! window flags
    w = QWidget()
    call w%setWindowFlag(Qt_FramelessWindowHint)
    call check(w%testWindowFlag(Qt_FramelessWindowHint), 'setWindowFlag(Qt_FramelessWindowHint)')
    call check(iand(w%windowFlags(), Qt_FramelessWindowHint) /= 0, 'windowFlags')
    call w%setWindowFlag(Qt_FramelessWindowHint, .false.)
    call check(.not. w%testWindowFlag(Qt_FramelessWindowHint), 'setWindowFlag(..., .false.)')
    call w%setWindowFlags(ior(Qt_Tool, Qt_WindowStaysOnTopHint))
    call check(iand(w%windowFlags(), Qt_WindowType_Mask) == Qt_Tool .and. &
               w%testWindowFlag(Qt_WindowStaysOnTopHint), 'setWindowFlags: kind and hint')

    ! accessibility
    call w%setAccessibleName('Run button')
    call w%setAccessibleDescription('Starts the simulation')
    call check(w%accessibleName() == 'Run button' .and. w%accessibleDescription() == 'Starts the simulation', &
               'accessible name and description')
    call w%delete()

    ! label text format
    label = QLabel('<b>bold</b>')
    call check(label%textFormat() == Qt_AutoText, 'textFormat: auto by default')
    call label%setTextFormat(Qt_PlainText)
    call check(label%textFormat() == Qt_PlainText, 'setTextFormat')
    call label%setTextFormat(Qt_MarkdownText)
    call check(label%textFormat() == Qt_MarkdownText, 'Qt_MarkdownText')
    call label%delete()

    ! combo box placeholder
    combo = QComboBox()
    call combo%addItems(['one', 'two'])
    call combo%setPlaceholderText('Choose...')
    call combo%setCurrentIndex(-1)
    call check(combo%placeholderText() == 'Choose...' .and. combo%currentIndex() == -1, 'QComboBox placeholder')
    call combo%delete()

    ! slider state
    slider = QSlider(Qt_Horizontal)
    call check(.not. slider%isSliderDown(), 'isSliderDown')
    call slider%delete()

    ! table grid, also through QTableWidget
    table = QTableWidget(2, 2)
    call check(table%showGrid(), 'showGrid by default')
    call table%setShowGrid(.false.)
    call check(.not. table%showGrid(), 'QTableWidget setShowGrid')
    call table%setGridStyle(Qt_DotLine)
    call table%delete()

    ! QListWidget is a QListView
    list = QListWidget()
    call list%addItems(['alpha', 'beta '])
    call list%setSpacing(6)
    call list%setWordWrap(.true.)
    call list%setViewMode(QListView_IconMode)
    call list%setCurrentRow(1)
    call check(list%currentRow() == 1 .and. list%count() == 2, 'QListWidget with QListView methods')
    call list%delete()

    ! tree item geometry
    tree = QTreeWidget()
    call tree%resize(300, 200)
    a = QTreeWidgetItem(tree, ['first '])
    b = QTreeWidgetItem(tree, ['second'])
    call tree%show()
    call QApplication_processEvents()
    r = tree%visualItemRect(b)
    call check(r%height > 0 .and. r%y > 0, 'visualItemRect')
    hit = tree%itemAt(r%x + 5, r%y + r%height / 2)
    call check(.not. hit%isNull(), 'itemAt(x, y)')
    if (.not. hit%isNull()) call check(hit%text(0) == 'second', 'itemAt: the right item')
    hit = tree%itemAt(QPoint(5, 1))
    call check(.not. hit%isNull(), 'itemAt(QPoint)')
    if (.not. hit%isNull()) call check(hit%text(0) == 'first', 'itemAt(QPoint): the right item')
    hit = tree%itemAt(5, 190)
    call check(hit%isNull(), 'itemAt: empty space')
    call tree%delete()

    ! action icon text
    act = QAction('&Save As...')
    call check(act%iconText() == 'Save As', 'iconText: derived from the text')
    call act%setIconText('Save')
    call check(act%iconText() == 'Save', 'setIconText')
    call act%delete()

end program test_widget_options
