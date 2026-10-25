!> QSettings, saved window geometry and state, close events (with veto) and
!> context-menu events. Run headless with QT_QPA_PLATFORM=offscreen.
module test_settings_slots

    use qt
    implicit none

    !> What the close and context-menu slots saw.
    type :: window_log
        logical :: veto = .true.
        integer :: closes = 0, menus = 0
        integer :: x = -1, y = -1, globalX = -1, globalY = -1, reason = -1
    end type window_log

contains

    !> Count close requests; keep the window open while `veto` is set.
    subroutine on_close(event, data)
        type(QCloseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (window_log)
            data%closes = data%closes + 1
            if (data%veto) call event%ignore()
        end select
    end subroutine on_close

    !> Record a context-menu request.
    subroutine on_context_menu(event, data)
        type(QContextMenuEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (window_log)
            data%menus = data%menus + 1
            data%x = event%x()
            data%y = event%y()
            data%globalX = event%globalX()
            data%globalY = event%globalY()
            data%reason = event%reason()
        end select
    end subroutine on_context_menu

end module test_settings_slots

!> Tests QSettings, saved geometry, close vetoes and context menus.
program test_settings

    use qt
    use testing
    use test_settings_slots
    use iso_c_binding, only: c_double
    implicit none

    character(len=*), parameter :: ini = 'build/test_settings.ini'
    type(QApplication) :: app
    type(QSettings) :: s, s2
    type(QWidget) :: w
    type(QMainWindow) :: mw, mw2
    type(QToolBar) :: tb
    type(QMenu) :: menu
    type(QAction) :: act
    type(QCloseEvent) :: ce
    type(QContextMenuEvent) :: cme
    type(qt_string), allocatable :: keys(:)
    type(window_log), target :: log
    character(len=:), allocatable :: geometry, state
    logical :: handled
    integer :: nslots

    app = QApplication()
    call QApplication_setOrganizationName('qt-fortran')
    call QApplication_setApplicationName('test_settings')
    call check(QApplication_organizationName() == 'qt-fortran', 'organizationName')
    call check(QApplication_applicationName() == 'test_settings', 'applicationName')

    ! --- the native store (only inspected: tests should not write the user's settings)
    s = QSettings()
    call check(len(s%fileName()) > 0, 'native settings location: '//s%fileName())
    call s%delete()

    ! --- an INI file: write
    s = QSettings(ini)
    call s%clear()
    call s%setValue('name', 'Fortran')
    call s%setValue('count', 42)
    call s%setValue('ratio', 0.25_c_double)
    call s%setValue('flag', .true.)
    call s%beginGroup('window')
    call check(s%group() == 'window', 'beginGroup')
    call s%setValue('width', 640)
    call s%endGroup()
    call s%setValue('window/height', 480)
    call s%sync()
    call check(s%status() == QSettings_NoError .and. s%isWritable(), 'sync, writable')
    call check(index(s%fileName(), 'test_settings.ini') > 0, 'fileName')

    ! --- read back through a second QSettings on the same file
    s2 = QSettings(ini)
    call check(s2%stringValue('name') == 'Fortran', 'stringValue')
    call check(s2%intValue('count') == 42, 'intValue')
    call check(s2%doubleValue('ratio') == 0.25_c_double, 'doubleValue')
    call check(s2%boolValue('flag'), 'boolValue')
    call check(s2%intValue('window/width') == 640 .and. s2%intValue('window/height') == 480, 'grouped keys')
    call check(s2%stringValue('missing', 'none') == 'none' .and. s2%intValue('missing', -7) == -7 &
               .and. s2%doubleValue('missing', 1.5_c_double) == 1.5_c_double &
               .and. .not. s2%boolValue('missing') .and. s2%boolValue('missing', .true.), 'defaults')
    call check(s2%contains('count') .and. .not. s2%contains('missing'), 'contains')
    keys = s2%allKeys()
    call check(size(keys) == 6, 'allKeys')
    keys = s2%childKeys()
    call check(size(keys) == 4, 'childKeys')
    keys = s2%childGroups()
    call check(size(keys) == 1, 'childGroups')
    if (size(keys) == 1) call check(keys(1)%s == 'window', 'childGroups name')
    call s2%remove('window')
    call check(.not. s2%contains('window/width') .and. size(s2%allKeys()) == 4, 'remove group')
    call s2%delete()
    call s%delete()

    ! --- window geometry and main window state
    mw = QMainWindow()
    tb = mw%addToolBar('Tools')
    call tb%setObjectName('tools')
    call mw%resize(320, 200)
    call mw%show()
    geometry = mw%saveGeometry()
    state = mw%saveState()
    call check(len(geometry) > 0 .and. len(state) > 0, 'saveGeometry, saveState')
    call check(mw%isWindow(), 'isWindow')

    mw2 = QMainWindow()
    tb = mw2%addToolBar('Tools')
    call tb%setObjectName('tools')
    call check(mw2%restoreGeometry(geometry), 'restoreGeometry')
    call check(mw2%width() == 320 .and. mw2%height() == 200, 'restored size')
    call check(mw2%restoreState(state), 'restoreState')
    call check(.not. mw2%restoreGeometry('not a geometry'), 'invalid geometry rejected')
    call mw%delete()
    call mw2%delete()

    ! --- close events: a slot can veto
    nslots = qt_slot_count()
    w = QWidget()
    call w%show()
    call w%closeEvent%connect(on_close, log)
    call w%close()
    call check(log%closes == 1 .and. w%isVisible(), 'close vetoed')
    ce = QCloseEvent()
    handled = QCoreApplication_sendEvent(w, ce)
    call check(log%closes == 2 .and. .not. ce%isAccepted(), 'synthetic close event ignored')
    call ce%delete()
    log%veto = .false.
    call w%close()
    call check(log%closes == 3 .and. .not. w%isVisible(), 'close accepted')

    ! --- context-menu events
    call w%contextMenuEvent%connect(on_context_menu, log)
    cme = QContextMenuEvent(QContextMenuEvent_Mouse, 5, 6, 105, 106)
    handled = QCoreApplication_sendEvent(w, cme)
    call check(log%menus == 1 .and. cme%isAccepted(), 'contextMenuEvent')
    call check(log%x == 5 .and. log%y == 6 .and. log%globalX == 105 .and. log%globalY == 106, 'context position')
    call check(log%reason == QContextMenuEvent_Mouse, 'context reason')
    call cme%delete()
    call check(log%closes == 3, 'close slot unaffected')

    menu = QMenu('Context')
    call check(menu%isEmpty(), 'menu isEmpty')
    act = QAction('Copy', menu)
    call menu%addAction(act)
    call check(.not. menu%isEmpty(), 'menu has an action')
    call menu%popup(100, 100)
    call check(menu%isVisible(), 'popup')
    call menu%hide()
    call menu%clear()
    call check(menu%isEmpty(), 'menu clear')
    call menu%delete()

    ! the filter and its slots go with the widget
    call w%delete()
    call check(qt_slot_count() == nslots, 'slots released with the widget')

    write(*,'(A)') 'test_settings: all checks passed'

end program test_settings
