!> Signals defined in Fortran (create, connect, emit) and disconnecting slots
!> from Fortran-defined, Qt and event signals.
!> Run headless with QT_QPA_PLATFORM=offscreen.
module test_signals_slots

    use qt
    use iso_c_binding, only: c_double
    implicit none

    !> A Fortran "model" that announces its progress through its own signals.
    type :: solver_t
        type(QSignalInt) :: progress
        type(QSignalString) :: message
        type(QSignal) :: finished
    end type solver_t

    !> What the slots received.
    type :: recorder
        integer :: calls = 0, a = 0, b = 0, c = 0, d = 0, total = 0
        logical :: flag = .false.
        real(c_double) :: x = 0
        character(len=:), allocatable :: text
        character(len=:), allocatable :: order
        type(QMetaObject_Connection) :: self_connection
    end type recorder

contains

    !> Count a call.
    subroutine on_void(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
        end select
    end subroutine on_void

    !> Record an integer.
    subroutine on_int(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            data%a = value
            data%total = data%total + value
        end select
    end subroutine on_int

    !> Record the call order (first slot).
    subroutine on_first(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%order = data%order // '1'
        end select
    end subroutine on_first

    !> Record the call order (second slot).
    subroutine on_second(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%order = data%order // '2'
        end select
    end subroutine on_second

    !> Record a logical.
    subroutine on_bool(value, data)
        logical, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            data%flag = value
        end select
    end subroutine on_bool

    !> Record a real.
    subroutine on_double(value, data)
        real(c_double), intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            data%x = value
        end select
    end subroutine on_double

    !> Record a string.
    subroutine on_string(value, data)
        character(len=*), intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            data%text = value
        end select
    end subroutine on_string

    !> Record two integers.
    subroutine on_int2(a, b, data)
        integer, intent(in) :: a, b
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%a = a
            data%b = b
        end select
    end subroutine on_int2

    !> Record three integers.
    subroutine on_int3(a, b, c, data)
        integer, intent(in) :: a, b, c
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%a = a
            data%b = b
            data%c = c
        end select
    end subroutine on_int3

    !> Record four integers.
    subroutine on_int4(a, b, c, d, data)
        integer, intent(in) :: a, b, c, d
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%a = a
            data%b = b
            data%c = c
            data%d = d
        end select
    end subroutine on_int4

    !> A slot that runs once: it disconnects itself.
    subroutine on_once(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            if (.not. QObject_disconnect(data%self_connection)) error stop 'self-disconnect failed'
        end select
    end subroutine on_once

    !> Count mouse presses.
    subroutine on_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
        end select
    end subroutine on_press

    !> Keep the window open.
    subroutine on_close_veto(event, data)
        type(QCloseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        call event%ignore()
    end subroutine on_close_veto

end module test_signals_slots

!> Tests Fortran-defined signals and disconnecting.
program test_signals

    use qt
    use testing
    use test_signals_slots
    use iso_c_binding, only: c_double
    implicit none

    type(QApplication) :: app
    type(QObject) :: owner
    type(solver_t) :: solver
    type(QSignal) :: sig0, sigv
    type(QSignalBool) :: sigb
    type(QSignalInt) :: sigi
    type(QSignalDouble) :: sigd
    type(QSignalInt2) :: sig2
    type(QSignalInt3) :: sig3
    type(QSignalInt4) :: sig4
    type(QPushButton) :: button
    type(QtfWidget) :: canvas
    type(QWidget) :: window
    type(QMouseEvent) :: me
    type(QMetaObject_Connection) :: c1, c2, never
    type(recorder), target :: r, r2
    logical :: handled
    integer :: n0, n1, i

    app = QApplication()
    n0 = qt_slot_count()
    owner = QObject()

    ! --- Fortran-defined signals as components of a Fortran type
    solver%progress = QSignalInt(owner)
    solver%message = QSignalString(owner)
    solver%finished = QSignal(owner)
    call solver%progress%connect(on_int, r)
    call solver%message%connect(on_string, r)
    call solver%finished%connect(on_void, r2)
    do i = 1, 4
        call solver%progress%emit(25 * i)
    end do
    call check(r%calls == 4 .and. r%a == 100 .and. r%total == 250, 'QSignalInt emit')
    call solver%message%emit('converged after 4 steps')
    call check(r%text == 'converged after 4 steps', 'QSignalString emit')
    call solver%message%emit('')
    call check(r%text == '', 'empty string emit')
    call solver%finished%emit()
    call check(r2%calls == 1, 'QSignal emit')

    ! --- the other kinds
    r = recorder()
    sigb = QSignalBool(owner)
    sigd = QSignalDouble(owner)
    sig2 = QSignalInt2(owner)
    sig3 = QSignalInt3(owner)
    sig4 = QSignalInt4(owner)
    call sigb%connect(on_bool, r)
    call sigd%connect(on_double, r)
    call sigb%emit(.true.)
    call check(r%flag, 'QSignalBool emit')
    call sigd%emit(2.5_c_double)
    call check(r%x == 2.5_c_double, 'QSignalDouble emit')
    call sig2%connect(on_int2, r)
    call sig2%emit(3, 4)
    call check(r%a == 3 .and. r%b == 4, 'QSignalInt2 emit')
    call sig3%connect(on_int3, r)
    call sig3%emit(2026, 10, 25)
    call check(r%a == 2026 .and. r%b == 10 .and. r%c == 25, 'QSignalInt3 emit')
    call sig4%connect(on_int4, r)
    call sig4%emit(1, -2, 3, -4)
    call check(r%a == 1 .and. r%b == -2 .and. r%c == 3 .and. r%d == -4, 'QSignalInt4 emit')
    sig0 = QSignal()     ! no parent: lives until the program ends
    call sig0%emit()     ! no slots: nothing happens
    call check(.true., 'emit without slots')

    ! --- slots run in connection order
    r = recorder()
    r%order = ''
    sigi = QSignalInt(owner)
    call sigi%connect(on_first, r)
    call sigi%connect(on_second, r, connection=c2)
    call sigi%emit(0)
    call check(r%order == '12', 'connection order')

    ! --- disconnect one connection
    n1 = qt_slot_count()
    call check(QObject_disconnect(c2), 'QObject_disconnect')
    call check(qt_slot_count() == n1 - 1, 'disconnected slot released')
    call sigi%emit(0)
    call check(r%order == '121', 'disconnected slot not called')
    call check(.not. QObject_disconnect(c2), 'second disconnect is a no-op')
    call check(.not. QObject_disconnect(never), 'never-connected handle')

    ! --- a slot that disconnects itself while running
    r = recorder()
    sigv = QSignal(owner)
    call sigv%connect(on_once, r, connection=r%self_connection)
    call sigv%emit()
    call sigv%emit()
    call check(r%calls == 1, 'slot disconnects itself')

    ! --- disconnect all slots of a signal (others are untouched)
    call solver%progress%connect(on_int, r)
    call solver%progress%disconnect()
    r = recorder()
    call solver%progress%emit(5)
    call check(r%calls == 0, 'sig%disconnect() removes all slots')
    call solver%progress%connect(on_int, r)
    call solver%progress%emit(5)
    call check(r%calls == 1, 'connect again after disconnect')

    ! --- Qt signals
    button = QPushButton('Go')
    r = recorder()
    r2 = recorder()
    call button%clicked%connect(on_void, r, connection=c1)
    call button%clicked%connect(on_void, r2)
    call button%click()
    call check(r%calls == 1 .and. r2%calls == 1, 'Qt signal, two slots')
    call check(QObject_disconnect(c1), 'disconnect a Qt signal connection')
    call button%click()
    call check(r%calls == 1 .and. r2%calls == 2, 'only the other slot called')
    call button%clicked%disconnect()
    call button%click()
    call check(r2%calls == 2, 'Qt signal disconnect()')
    call button%delete()

    ! --- event slots: a disconnected handler restores Qt's default handling
    canvas = QtfWidget()
    r = recorder()
    call canvas%mousePressEvent%connect(on_press, r, connection=c1)
    me = QMouseEvent(QEvent_MouseButtonPress, 1.0_c_double, 1.0_c_double, Qt_LeftButton)
    handled = QCoreApplication_sendEvent(canvas, me)
    call check(r%calls == 1 .and. me%isAccepted(), 'event slot')
    call check(QObject_disconnect(c1), 'disconnect an event slot')
    call me%accept()
    handled = QCoreApplication_sendEvent(canvas, me)
    call check(r%calls == 1 .and. .not. me%isAccepted(), 'default handling after disconnect')
    call me%delete()
    call canvas%delete()

    window = QWidget()
    call window%show()
    call window%closeEvent%connect(on_close_veto, connection=c1)
    call window%close()
    call check(window%isVisible(), 'close vetoed')
    call window%closeEvent%disconnect()
    call window%close()
    call check(.not. window%isVisible(), 'close after disconnecting the veto')
    call window%delete()

    ! --- deleting the owner releases the slots of its signals
    call check(qt_slot_count() > n0, 'slots connected')
    call owner%delete()
    call check(qt_slot_count() == n0, 'slots released with the owner')

    write(*,'(A)') 'test_signals: all checks passed'

end program test_signals
