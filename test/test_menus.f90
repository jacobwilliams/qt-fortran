!> Menus, tool bars and actions. Run headless with QT_QPA_PLATFORM=offscreen.
module test_menus_slots

    implicit none

    !> Records action signals.
    type :: action_log
        integer :: triggered = 0
        integer :: toggles = 0
        logical :: state = .false.
    end type action_log

contains

    !> Count triggered emissions.
    subroutine on_triggered(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (action_log)
            data%triggered = data%triggered + 1
        end select
    end subroutine on_triggered

    !> Record the state passed by toggled.
    subroutine on_toggled(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (data)
        type is (action_log)
            data%toggles = data%toggles + 1
            data%state = checked
        end select
    end subroutine on_toggled

end module test_menus_slots

!> Tests menus, tool bars and actions.
program test_menus

    use qt
    use testing
    use test_menus_slots
    implicit none

    type(QApplication) :: app
    type(QMainWindow) :: main
    type(QMenuBar) :: bar
    type(QMenu) :: file_menu, recent, view
    type(QToolBar) :: tools
    type(QAction) :: open_action, grid_action, a
    type(QObject) :: p
    type(action_log), target :: open_log, grid_log

    app = QApplication()
    main = QMainWindow()

    bar = main%menuBar()
    call check(bar%className() == 'QMenuBar', 'menuBar')
    file_menu = bar%addMenu('&File')
    call check(file_menu%title() == '&File', 'addMenu title')
    a = file_menu%menuAction()
    call check(a%text() == '&File', 'menuAction text')

    ! --- plain action with a shortcut
    open_action = QAction('&Open...', main)
    call open_action%setShortcut('Ctrl+O')
    call check(open_action%shortcut() == 'Ctrl+O', 'setShortcut/shortcut (portable text)')
    call open_action%setStatusTip('Open a file')
    call file_menu%addAction(open_action)
    call file_menu%addSeparator()
    recent = file_menu%addMenu('Recent')
    call check(recent%title() == 'Recent', 'submenu')
    p = recent%parent()
    call check(p%inherits('QMenu'), 'submenu parented to its menu')

    call open_action%triggered%connect(on_triggered, open_log)
    call open_action%trigger()
    call check(open_log%triggered == 1, 'triggered')
    call open_action%setEnabled(.false.)
    call open_action%trigger()
    call check(open_log%triggered == 1 .and. .not. open_action%isEnabled(), 'disabled action does not trigger')

    ! --- checkable action in a menu and a tool bar
    view = bar%addMenu('&View')
    grid_action = QAction('Show &grid', main)
    call grid_action%setCheckable(.true.)
    call grid_action%setChecked(.true.)
    call view%addAction(grid_action)
    tools = main%addToolBar('Tools')
    call check(tools%className() == 'QToolBar', 'addToolBar')
    call tools%addAction(grid_action)
    call tools%addSeparator()
    call tools%addWidget(QLabel('zoom'))

    call grid_action%toggled%connect(on_toggled, grid_log)
    call grid_action%triggered%connect(on_triggered, grid_log)
    call grid_action%trigger()
    call check(.not. grid_action%isChecked(), 'trigger toggles a checkable action')
    call check(grid_log%toggles == 1 .and. .not. grid_log%state .and. grid_log%triggered == 1, &
               'toggled(.false.) and triggered')
    call grid_action%setChecked(.true.)
    call check(grid_log%toggles == 2 .and. grid_log%state .and. grid_log%triggered == 1, &
               'setChecked emits toggled but not triggered')
    call grid_action%setText('Show &Grid')
    call check(grid_action%text() == 'Show &Grid', 'action setText')

    call main%delete()
    call check(qt_slot_count() == 0, 'action slots released with the window')

    write(*,'(A)') 'test_menus: all checks passed'

end program test_menus
