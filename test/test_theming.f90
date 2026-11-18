!> Theming (QPalette, styles), services (key sequences, shortcuts, tool tips,
!> desktop services), and widgets: QActionGroup, QTabBar, QStackedLayout,
!> QHeaderView, QScrollBar. Run headless with QT_QPA_PLATFORM=offscreen.
module test_theming_slots

    use qt
    implicit none

    !> Records signal arguments.
    type :: signal_log
        integer :: calls = 0
        integer :: a = -9, b = -9, c = -9
    end type signal_log

contains

    !> Record an integer.
    subroutine on_int(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (signal_log)
            data%calls = data%calls + 1
            data%a = value
        end select
    end subroutine on_int

    !> Record two integers.
    subroutine on_int2(a, b, data)
        integer, intent(in) :: a, b
        class(*), intent(inout), optional :: data
        select type (data)
        type is (signal_log)
            data%calls = data%calls + 1
            data%a = a
            data%b = b
        end select
    end subroutine on_int2

    !> Record three integers.
    subroutine on_int3(a, b, c, data)
        integer, intent(in) :: a, b, c
        class(*), intent(inout), optional :: data
        select type (data)
        type is (signal_log)
            data%calls = data%calls + 1
            data%a = a
            data%b = b
            data%c = c
        end select
    end subroutine on_int3

end module test_theming_slots

!> Tests for theming, services and the extra widgets.
program test_theming

    use qt
    use testing
    use test_theming_slots
    implicit none

    type(QApplication) :: app
    type(QPalette) :: pal, pal2
    type(QColor) :: c
    type(QWidget) :: w, host, page
    type(QAction) :: act, a(3)
    type(QActionGroup) :: group
    type(QShortcut) :: sc, sc2
    type(QTabBar) :: tabs
    type(QStackedLayout) :: stack
    type(QTableWidget) :: table
    type(QTreeWidget) :: tree
    type(QHeaderView) :: header
    type(QPlainTextEdit) :: edit
    type(QScrollBar) :: bar, hbar
    type(qt_string), allocatable :: keys(:)
    type(signal_log), target :: triggered, current, resized, sorted, scrolled, moved, stacked
    character(len=:), allocatable :: text
    integer :: i, k
    logical :: found

    app = QApplication()

    ! ---- palettes
    pal = QPalette()
    call pal%setColor(QPalette_Window, QColor(10, 20, 30))
    call pal%setColor(QPalette_WindowText, QColor(230, 230, 230))
    c = pal%color(QPalette_Window)
    call check(c%r == 10 .and. c%g == 20 .and. c%b == 30, 'QPalette setColor / color')
    c = pal%color(QPalette_Window, QPalette_Disabled)
    call check(c%r == 10, 'QPalette setColor sets all groups by default')
    call pal%setColor(QPalette_Text, QColor(128, 128, 128), QPalette_Disabled)
    c = pal%color(QPalette_Text, QPalette_Disabled)
    call check(c%r == 128, 'QPalette setColor in one group')
    call check(pal%isDark(), 'QPalette isDark')
    pal2 = pal%copy()
    call check(pal2%isEqual(pal), 'QPalette copy / isEqual')
    call pal2%delete()
    pal2 = QPalette(QColor(200, 100, 50))
    c = pal2%color(QPalette_Button)
    call check(c%r == 200 .and. c%g == 100 .and. c%b == 50, 'QPalette from a button color')
    call pal2%delete()

    ! application and widget palettes
    call QApplication_setPalette(pal)
    pal2 = QApplication_palette()
    c = pal2%color(QPalette_Window)
    call check(c%r == 10 .and. c%b == 30, 'QApplication_setPalette / palette')
    call pal2%delete()
    w = QWidget()
    pal2 = w%palette()
    c = pal2%color(QPalette_Window)
    call check(c%r == 10, 'widgets use the application palette')
    call pal2%setColor(QPalette_Window, QColor(1, 2, 3))
    call w%setPalette(pal2)
    call w%setAutoFillBackground(.true.)
    call pal2%delete()
    pal2 = w%palette()
    c = pal2%color(QPalette_Window)
    call check(c%r == 1 .and. c%b == 3, 'QWidget setPalette')
    call pal2%delete()
    call pal%delete()

    ! ---- styles and color scheme
    keys = QStyleFactory_keys()
    found = .false.
    do i = 1, size(keys)
        if (keys(i)%s == 'Fusion') found = .true.
    end do
    call check(found, 'QStyleFactory_keys has Fusion')
    call check(QApplication_setStyle('Fusion') .and. QApplication_styleName() == 'fusion', &
               'QApplication_setStyle / styleName')
    call check(.not. QApplication_setStyle('no-such-style'), 'QApplication_setStyle: unknown style')
    k = QGuiApplication_colorScheme()
    call check(k >= Qt_ColorScheme_Unknown .and. k <= Qt_ColorScheme_Dark, 'QGuiApplication_colorScheme')

    ! ---- key sequences and shortcuts
    call check(QKeySequence_standardKey(QKeySequence_Copy) == 'Ctrl+C', 'QKeySequence_standardKey')
    keys = QKeySequence_standardKeyBindings(QKeySequence_Copy)
    call check(size(keys) >= 1, 'QKeySequence_standardKeyBindings')
    text = QKeySequence_nativeText('Ctrl+Shift+S')
    call check(len(text) > 0 .and. QKeySequence_portableText(text) == 'Ctrl+Shift+S', &
               'QKeySequence_nativeText / portableText')
    act = QAction('Open', w)
    call act%setStandardShortcut(QKeySequence_Open)
    call check(act%shortcut() == 'Ctrl+O' .and. len(act%shortcutNativeText()) > 0, 'QAction setStandardShortcut')
    call act%setShortcutContext(Qt_ApplicationShortcut)
    sc = QShortcut('Ctrl+K', w)
    call check(sc%key() == 'Ctrl+K' .and. sc%isEnabled(), 'QShortcut key')
    call sc%setKey('Ctrl+K, Ctrl+C')
    call check(sc%key() == 'Ctrl+K, Ctrl+C', 'QShortcut setKey (a sequence)')
    call sc%setEnabled(.false.)
    call check(.not. sc%isEnabled(), 'QShortcut setEnabled')
    call sc%setContext(Qt_WidgetShortcut)
    sc2 = QShortcut(QKeySequence_Find, w)
    call check(sc2%key() == 'Ctrl+F', 'QShortcut from a standard key')

    ! ---- services
    call check(.not. QDesktopServices_openUrl(''), 'QDesktopServices_openUrl: nothing to open')
    call w%show()
    call QToolTip_showText(50, 50, 'a tip', w)
    call check(QToolTip_text() == 'a tip', 'QToolTip_showText / text')
    call QToolTip_hideText()

    ! ---- QActionGroup
    group = QActionGroup(w)
    do i = 1, 3
        a(i) = QAction('Theme', w)
        call a(i)%setCheckable(.true.)
        call group%addAction(a(i))
    end do
    call group%triggered%connect(on_int, triggered)
    call check(group%count() == 3 .and. group%isExclusive(), 'QActionGroup count / exclusive')
    call a(2)%trigger()
    call check(triggered%a == 1 .and. group%checkedIndex() == 1, 'QActionGroup triggered(index) / checkedIndex')
    call a(3)%trigger()
    call check(group%checkedIndex() == 2 .and. .not. a(2)%isChecked(), 'QActionGroup: one checked at a time')
    act = group%checkedAction()
    call check(act%isChecked(), 'QActionGroup checkedAction')
    call group%setExclusionPolicy(QActionGroup_ExclusiveOptional)
    call a(3)%trigger()
    call check(group%checkedIndex() == -1, 'QActionGroup ExclusiveOptional: uncheck')
    act = group%action(0)
    call check(.not. act%isNull(), 'QActionGroup action(index)')
    act = group%action(5)
    call check(act%isNull(), 'QActionGroup action(index) out of range')

    ! ---- QTabBar
    tabs = QTabBar()
    call tabs%currentChanged%connect(on_int, current)
    call tabs%tabMoved%connect(on_int2, moved)
    call tabs%addTab('one')
    call tabs%addTab('two')
    call tabs%addTab('three')
    call check(tabs%count() == 3 .and. tabs%tabText(1) == 'two', 'QTabBar addTab / tabText')
    do i = 0, 2
        call tabs%setTabData(i, 100 + i)
    end do
    call tabs%setCurrentIndex(2)
    call check(tabs%currentIndex() == 2 .and. current%a == 2, 'QTabBar setCurrentIndex / currentChanged')
    call tabs%moveTab(0, 2)
    call check(tabs%tabText(2) == 'one' .and. tabs%tabData(2) == 100, 'QTabBar moveTab keeps the data')
    call tabs%setTabToolTip(0, 'tip')
    call check(tabs%tabToolTip(0) == 'tip', 'QTabBar tool tip')
    call tabs%setTabsClosable(.true.)
    call tabs%setMovable(.true.)
    call check(tabs%tabsClosable() .and. tabs%isMovable(), 'QTabBar closable / movable')
    call tabs%setTabTextColor(1, Qt_red)
    c = tabs%tabTextColor(1)
    call check(c%r == 255 .and. c%g == 0, 'QTabBar tab text color')
    call tabs%removeTab(0)
    call check(tabs%count() == 2, 'QTabBar removeTab')

    ! ---- QStackedLayout
    host = QWidget()
    stack = QStackedLayout(host)
    call stack%currentChanged%connect(on_int, stacked)
    do i = 1, 3
        page = QWidget()
        call stack%addWidget(page)
    end do
    call check(stack%count() == 3 .and. stack%currentIndex() == 0, 'QStackedLayout addWidget')
    call stack%setCurrentIndex(2)
    call host%show()
    page = stack%currentWidget()
    call check(stack%currentIndex() == 2 .and. stacked%a == 2, 'QStackedLayout setCurrentIndex / currentChanged')
    call check(.not. page%isNull() .and. page%isVisible(), 'QStackedLayout currentWidget')
    page = stack%widget(5)
    call check(page%isNull(), 'QStackedLayout widget(index) out of range')
    call stack%setStackingMode(QStackedLayout_StackAll)
    call check(stack%stackingMode() == QStackedLayout_StackAll, 'QStackedLayout stacking mode')

    ! ---- QHeaderView
    table = QTableWidget(5, 3)
    call table%resize(400, 300)
    call table%show()
    header = table%horizontalHeader()
    call check(header%count() == 3 .and. header%orientation() == Qt_Horizontal, 'horizontalHeader')
    call header%sectionResized%connect(on_int3, resized)
    call header%sortIndicatorChanged%connect(on_int2, sorted)
    call header%setSectionResizeMode(QHeaderView_Interactive)
    call header%resizeSection(1, 77)
    call check(header%sectionSize(1) == 77, 'QHeaderView resizeSection / sectionSize')
    call check(resized%a == 1 .and. resized%c == 77, 'sectionResized(logicalIndex, oldSize, newSize)')
    call header%setSectionResizeMode(2, QHeaderView_Stretch)
    call check(header%sectionResizeMode(2) == QHeaderView_Stretch .and. &
               header%sectionResizeMode(0) == QHeaderView_Interactive, 'QHeaderView setSectionResizeMode of one section')
    call header%setSortIndicatorShown(.true.)
    call header%setSortIndicator(1, Qt_DescendingOrder)
    call check(header%sortIndicatorSection() == 1 .and. header%sortIndicatorOrder() == Qt_DescendingOrder, &
               'QHeaderView sort indicator')
    call check(sorted%a == 1 .and. sorted%b == Qt_DescendingOrder, 'sortIndicatorChanged')
    call header%setSectionsMovable(.true.)
    call header%moveSection(0, 2)
    call check(header%visualIndex(0) == 2 .and. header%logicalIndex(0) == 1, 'QHeaderView moveSection')
    call header%hideSection(1)
    call check(header%isSectionHidden(1), 'QHeaderView hideSection')
    call header%showSection(1)
    header = table%verticalHeader()
    call check(header%count() == 5 .and. header%orientation() == Qt_Vertical, 'verticalHeader')
    tree = QTreeWidget()
    call tree%setColumnCount(4)
    header = tree%header()
    call check(header%count() == 4, 'QTreeWidget header')

    ! ---- QScrollBar
    edit = QPlainTextEdit()
    do i = 1, 200
        call edit%appendPlainText('line')
    end do
    call edit%resize(300, 200)
    call edit%show()
    bar = edit%verticalScrollBar()
    call check(bar%maximum() > 0 .and. bar%orientation() == Qt_Vertical, 'verticalScrollBar range')
    call bar%valueChanged%connect(on_int, scrolled)
    call bar%setValue(10)
    call check(scrolled%a == 10 .and. bar%value() == 10, 'QScrollBar setValue / valueChanged')
    call check(bar%pageStep() > 0, 'QScrollBar pageStep')
    hbar = edit%horizontalScrollBar()
    call check(hbar%orientation() == Qt_Horizontal, 'horizontalScrollBar')
    call edit%setVerticalScrollBarPolicy(Qt_ScrollBarAlwaysOff)
    hbar = QScrollBar(Qt_Horizontal)
    call hbar%setRange(0, 50)
    call check(hbar%maximum() == 50 .and. hbar%orientation() == Qt_Horizontal, 'standalone QScrollBar')

    call edit%delete()
    call table%delete()
    call tree%delete()
    call tabs%delete()
    call host%delete()
    call w%delete()

end program test_theming
