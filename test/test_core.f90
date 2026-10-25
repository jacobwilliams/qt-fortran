!> Core tests: QObject, signals/slots with user data, slot lifetime, QTimer.
!> Run headless with QT_QPA_PLATFORM=offscreen.
module test_core_slots

    use qt
    implicit none

    type :: tick_state
        type(QTimer) :: timer
        integer :: ticks = 0
        integer :: last = 3
    end type tick_state

    type :: name_log
        character(len=:), allocatable :: last
        integer :: calls = 0
    end type name_log

    integer, parameter :: n_reentrant = 40

contains

    subroutine count_calls(data)
        class(*), intent(inout), optional :: data
        if (.not. present(data)) return
        select type (data)
        type is (integer)
            data = data + 1
        end select
    end subroutine count_calls

    subroutine record_name(value, data)
        character(len=*), intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (name_log)
            data%last = value
            data%calls = data%calls + 1
        end select
    end subroutine record_name

    subroutine on_tick(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (tick_state)
            data%ticks = data%ticks + 1
            if (data%ticks == data%last) then
                call data%timer%stop()
                call QApplication_quit()
            end if
        end select
    end subroutine on_tick

    subroutine quit_now(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine quit_now

    !> Re-entrancy: connect many slots (growing the registry) from inside a slot,
    !> fire them all, then quit.
    subroutine connect_more(data)
        class(*), intent(inout), optional :: data
        type(QObject) :: o
        integer :: i
        o = QObject()
        do i = 1, n_reentrant
            call o%destroyed%connect(count_calls, data)
        end do
        call o%delete()
        call QTimer_singleShot(0, quit_now)
    end subroutine connect_more

end module test_core_slots

program test_core

    use qt
    use testing
    use iso_c_binding, only: c_associated
    use test_core_slots
    implicit none

    type(QApplication) :: app
    type(QObject) :: o, child, p
    type(QTimer) :: t
    type(name_log), target :: log
    type(tick_state), target :: state
    integer, target :: ndestroyed, nreentrant
    integer :: base, ierr
    ! 'naïve' as explicit UTF-8 bytes, so the source stays ASCII
    character(len=*), parameter :: utf8_name = 'na'//achar(195)//achar(175)//'ve'

    app = QApplication()

    ! --- QObject basics
    o = QObject()
    call check(.not. o%isNull(), 'QObject created')
    call check(o%className() == 'QObject', 'className')
    call check(o%inherits('QObject') .and. .not. o%inherits('QTimer'), 'inherits')
    call o%setObjectName('root')
    call check(o%objectName() == 'root', 'objectName round-trip')
    p = o%parent()
    call check(p%isNull(), 'top-level object has no parent')

    child = QObject(o)
    p = child%parent()
    call check(c_associated(p%ptr, o%ptr), 'constructor sets parent')
    call child%setParent()
    p = child%parent()
    call check(p%isNull(), 'setParent() clears parent')
    call child%setParent(o)

    ! --- signal with a string argument and user data
    base = qt_slot_count()
    call o%objectNameChanged%connect(record_name, log)
    call o%setObjectName(utf8_name)
    call check(log%calls == 1, 'objectNameChanged fired once')
    call check(log%last == utf8_name, 'string signal argument (UTF-8)')

    ! --- destroyed signal; deleting the parent deletes the child; slots released
    ndestroyed = 0
    call child%destroyed%connect(count_calls, ndestroyed)
    call o%destroyed%connect(count_calls, ndestroyed)
    call check(qt_slot_count() == base + 3, 'slots registered')
    call o%delete()
    call check(o%isNull(), 'delete nulls handle')
    call check(ndestroyed == 2, 'destroyed fired for parent and child')
    call check(qt_slot_count() == base, 'slots released when sender destroyed')

    ! --- QTimer properties
    t = QTimer()
    call check(t%className() == 'QTimer' .and. t%inherits('QObject'), 'QTimer class')
    call t%setInterval(25)
    call check(t%interval() == 25, 'setInterval/interval')
    call check(.not. t%isActive(), 'timer inactive before start')
    call t%setSingleShot(.true.)
    call check(t%isSingleShot(), 'setSingleShot')
    call t%start()
    call check(t%isActive(), 'timer active after start')
    call t%stop()
    call check(.not. t%isActive(), 'timer inactive after stop')
    call t%delete()

    ! --- repeating timer driving the event loop, state passed as data
    state%timer = QTimer()
    call state%timer%timeout%connect(on_tick, state)
    call state%timer%start(5)
    ierr = app%exec()
    call check(ierr == 0, 'exec returned 0')
    call check(state%ticks == 3, 'timeout fired 3 times')
    call check(.not. state%timer%isActive(), 'timer stopped from slot')
    call state%timer%delete()

    ! --- single-shot + connecting from inside a slot
    base = qt_slot_count()
    nreentrant = 0
    call QTimer_singleShot(0, connect_more, nreentrant)
    ierr = app%exec()
    call check(nreentrant == n_reentrant, 'slots connected inside a slot all fired')
    call check(qt_slot_count() == base, 'single-shot and re-entrant slots released')

    write(*,'(A)') 'test_core: all checks passed'

end program test_core
