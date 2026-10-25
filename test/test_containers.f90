!> Containers, text editors, and the remaining controls. Run headless with
!> QT_QPA_PLATFORM=offscreen.
module test_containers_slots

    implicit none

    !> Records signal arguments.
    type :: signal_log
        integer :: calls = 0
        integer :: a = -9, b = -9, c = -9
        logical :: flag = .false.
    end type signal_log

contains

    !> Count a signal without arguments.
    subroutine on_void(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (signal_log)
            data%calls = data%calls + 1
        end select
    end subroutine on_void

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

    !> Record a logical.
    subroutine on_bool(value, data)
        logical, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (signal_log)
            data%calls = data%calls + 1
            data%flag = value
        end select
    end subroutine on_bool

    !> Record three integers (a date or time).
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

end module test_containers_slots

!> Tests the container, text and remaining control widgets.
program test_containers

    use qt
    use testing
    use test_containers_slots
    use iso_c_binding, only: c_double, c_associated
    implicit none

    type(QApplication) :: app
    type(QMainWindow) :: main
    type(QWidget) :: w, page1, page2
    type(QTabWidget) :: tabs
    type(QStackedWidget) :: stack
    type(QSplitter) :: splitter
    type(QScrollArea) :: scroll
    type(QGroupBox) :: group
    type(QDockWidget) :: dock
    type(QAction) :: a
    type(QFrame) :: line
    type(QFormLayout) :: form
    type(QTextEdit) :: rich
    type(QPlainTextEdit) :: log
    type(QProgressBar) :: progress
    type(QToolButton) :: tool
    type(QButtonGroup) :: buttons
    type(QCheckBox) :: b1, b2
    type(QAbstractButton) :: b
    type(QDial) :: dial
    type(QLCDNumber) :: lcd
    type(QDateEdit) :: date_edit
    type(QTimeEdit) :: time_edit
    type(QCalendarWidget) :: calendar
    type(QDate) :: d
    type(QTime) :: t
    type(signal_log), target :: tab_log, group_log, text_log, id_log, date_log, time_log, cal_log
    integer, allocatable :: sizes(:)
    integer :: i

    app = QApplication()

    ! --- tabs and stack
    tabs = QTabWidget()
    call tabs%currentChanged%connect(on_int, tab_log)
    call tabs%addTab(QLabel('first'), 'One')
    call tabs%addTab(QLabel('second'), 'Two')
    call check(tabs%count() == 2 .and. tabs%tabText(1) == 'Two', 'QTabWidget addTab')
    call tabs%setCurrentIndex(1)
    call check(tabs%currentIndex() == 1 .and. tab_log%a == 1, 'currentChanged')
    call tabs%setTabText(0, 'First')
    call check(tabs%tabText(0) == 'First', 'setTabText')
    w = tabs%widget(0)
    call check(w%inherits('QLabel'), 'tab widget(index)')

    stack = QStackedWidget()
    page1 = QWidget()
    page2 = QWidget()
    call stack%addWidget(page1)
    call stack%addWidget(page2)
    call stack%setCurrentWidget(page2)
    w = stack%currentWidget()
    call check(stack%count() == 2 .and. stack%currentIndex() == 1 .and. c_associated(w%ptr, page2%ptr), &
               'QStackedWidget')

    ! --- splitter: integer array argument and result
    splitter = QSplitter(Qt_Horizontal)
    call splitter%addWidget(QLabel('left'))
    call splitter%addWidget(QLabel('right'))
    call splitter%resize(400, 100)
    call splitter%show()
    call splitter%setSizes([100, 300])
    sizes = splitter%sizes()
    call check(size(sizes) == 2, 'QSplitter sizes() count')
    call check(sizes(1) > 0 .and. sizes(1) < sizes(2), 'QSplitter setSizes / sizes')
    call check(splitter%orientation() == Qt_Horizontal, 'QSplitter orientation')

    ! --- scroll area, group box, frame
    scroll = QScrollArea()
    call scroll%setWidget(QLabel('big contents'))
    call scroll%setWidgetResizable(.true.)
    w = scroll%widget()
    call check(w%inherits('QLabel') .and. scroll%widgetResizable(), 'QScrollArea')

    group = QGroupBox('Options')
    call group%setCheckable(.true.)
    call group%toggled%connect(on_bool, group_log)
    call group%setChecked(.false.)
    call check(group%title() == 'Options' .and. .not. group%isChecked(), 'QGroupBox checkable')
    call check(group_log%calls == 1 .and. .not. group_log%flag, 'QGroupBox toggled')

    line = QFrame()
    call line%setFrameShape(QFrame_HLine)
    call check(line%frameShape() == QFrame_HLine, 'QFrame shape')

    ! --- form layout and size constraints
    w = QWidget()
    form = QFormLayout(w)
    call form%addRow('Name', QLineEdit())
    call form%addRow('Count', QSpinBox())
    call form%addRow(QLabel('spanning'))
    call check(form%rowCount() == 3, 'QFormLayout rows')
    call w%setMaximumSize(300, 200)
    call w%resize(500, 500)
    call check(w%width() <= 300 .and. w%height() <= 200, 'setMaximumSize')
    call w%setFixedWidth(120)
    call check(w%width() == 120, 'setFixedWidth')
    call w%setSizePolicy(QSizePolicy_Expanding, QSizePolicy_Fixed)

    ! --- docks
    main = QMainWindow()
    dock = QDockWidget('Tools', main)
    call dock%setWidget(QLabel('dock contents'))
    call main%addDockWidget(Qt_LeftDockWidgetArea, dock)
    a = dock%toggleViewAction()
    call check(a%isCheckable(), 'dock toggleViewAction')
    call dock%setFloating(.true.)
    call check(dock%isFloating(), 'dock floating')

    ! --- text editors
    rich = QTextEdit()
    call rich%textChanged%connect(on_void, text_log)
    call rich%setHtml('<b>bold</b> text')
    call check(rich%toPlainText() == 'bold text', 'QTextEdit setHtml / toPlainText')
    call rich%append('more')
    call check(index(rich%toPlainText(), 'more') > 0 .and. text_log%calls >= 2, 'append / textChanged')

    log = QPlainTextEdit()
    call log%setReadOnly(.true.)
    call log%setMaximumBlockCount(5)
    do i = 1, 10
        call log%appendPlainText('line')
    end do
    call check(log%blockCount() == 5, 'QPlainTextEdit maximumBlockCount drops old lines')
    call check(log%isReadOnly(), 'QPlainTextEdit read-only')

    ! --- controls
    progress = QProgressBar()
    call progress%setRange(0, 50)
    call progress%setValue(25)
    call check(progress%value() == 25 .and. progress%maximum() == 50, 'QProgressBar')

    a = QAction('Run', main)
    tool = QToolButton()
    call tool%setDefaultAction(a)
    call tool%setToolButtonStyle(Qt_ToolButtonTextOnly)
    call check(tool%text() == 'Run', 'QToolButton default action text')

    buttons = QButtonGroup()
    b1 = QCheckBox('one')
    b2 = QCheckBox('two')
    call buttons%addButton(b1, 1)
    call buttons%addButton(b2, 2)
    call buttons%idClicked%connect(on_int, id_log)
    call b2%click()
    call check(id_log%a == 2 .and. buttons%checkedId() == 2, 'QButtonGroup idClicked / checkedId')
    b = buttons%button(1)
    call check(c_associated(b%ptr, b1%ptr) .and. buttons%id(b2) == 2, 'QButtonGroup button(id) / id(button)')

    dial = QDial()
    call dial%setRange(0, 360)
    call dial%setWrapping(.true.)
    call dial%setValue(90)
    call check(dial%value() == 90 .and. dial%wrapping(), 'QDial')

    lcd = QLCDNumber(6)
    call lcd%display(42)
    call check(lcd%intValue() == 42, 'QLCDNumber display(integer)')
    call lcd%display(3.25_c_double)
    call check(lcd%value() == 3.25_c_double, 'QLCDNumber display(real)')
    call lcd%display('12:30')
    call check(lcd%digitCount() == 6, 'QLCDNumber display(text), digitCount')

    ! --- dates and times: value types in and out, (y, m, d) signals
    date_edit = QDateEdit()
    call date_edit%dateChanged%connect(on_int3, date_log)
    call date_edit%setDate(QDate(2026, 10, 25))
    d = date_edit%date()
    call check(d%year == 2026 .and. d%month == 10 .and. d%day == 25, 'QDateEdit setDate / date')
    call check(date_log%a == 2026 .and. date_log%b == 10 .and. date_log%c == 25, 'dateChanged(year, month, day)')
    call date_edit%setDisplayFormat('yyyy-MM-dd')
    call check(date_edit%displayFormat() == 'yyyy-MM-dd', 'displayFormat')

    time_edit = QTimeEdit()
    call time_edit%timeChanged%connect(on_int3, time_log)
    call time_edit%setTime(QTime(13, 45, 10))
    t = time_edit%time()
    call check(t%hour == 13 .and. t%minute == 45, 'QTimeEdit setTime / time')
    call check(time_log%a == 13 .and. time_log%b == 45, 'timeChanged(hour, minute, second)')

    calendar = QCalendarWidget()
    call calendar%selectionChanged%connect(on_void, cal_log)
    call calendar%setSelectedDate(QDate(2024, 2, 29))
    d = calendar%selectedDate()
    call check(d%year == 2024 .and. d%month == 2 .and. d%day == 29 .and. cal_log%calls == 1, &
               'QCalendarWidget selected date (leap day)')

    call main%delete()
    write(*,'(A)') 'test_containers: all checks passed'

end program test_containers
