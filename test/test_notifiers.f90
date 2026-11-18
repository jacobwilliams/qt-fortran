!> QSocketNotifier and QWinEventNotifier. The test runs its own executable as
!> a child (`test_notifiers child`) whose QSocketNotifier watches its standard
!> input (descriptor 0): the parent writes a line, the child's `activated`
!> slot reads it and echoes it. That part runs where descriptors can be
!> watched (not on Windows, where QSocketNotifier takes only sockets). Run
!> headless with QT_QPA_PLATFORM=offscreen.
module test_notifiers_slots

    use qt
    implicit none

    !> What the child's slot saw.
    type :: notify_log
        integer :: calls = 0, socket = -9
    end type notify_log

contains

    !> Standard input is readable: echo a line and quit.
    subroutine on_readable(socket, data)
        use iso_fortran_env, only: output_unit
        integer, intent(in) :: socket
        class(*), intent(inout), optional :: data
        character(len=256) :: line
        integer :: ios
        select type (data)
        type is (notify_log)
            data%calls = data%calls + 1
            data%socket = socket
        end select
        read(*, '(A)', iostat=ios) line
        if (ios == 0) then
            write(output_unit, '(A,I0)') 'got: '//trim(line)//' on ', socket
            flush(output_unit)
        end if
        call QApplication_quit()
    end subroutine on_readable

    !> Stop a hung event loop.
    subroutine on_timeout(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_timeout

    !> A slot that must not run.
    subroutine on_signaled(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (notify_log)
            data%calls = data%calls + 1
        end select
    end subroutine on_signaled

end module test_notifiers_slots

!> Tests for QSocketNotifier and QWinEventNotifier.
program test_notifiers

    use qt
    use testing
    use test_notifiers_slots
    use iso_c_binding, only: c_long_long
    implicit none

    type(QApplication) :: app
    type(QSocketNotifier) :: sn
    type(QWinEventNotifier) :: wn
    type(QProcess) :: p
    type(notify_log), target :: log
    character(len=1024) :: arg
    character(len=:), allocatable :: self, out
    integer :: ierr, n

    app = QApplication()

    ! ---- the child: wait in the event loop for standard input
    call get_command_argument(1, arg)
    if (arg == 'child') then
        sn = QSocketNotifier(0, QSocketNotifier_Read)
        call sn%activated%connect(on_readable, log)
        call QTimer_singleShot(10000, on_timeout)
        ierr = app%exec()
        call sn%delete()
        stop
    end if

    ! ---- QSocketNotifier: properties
    sn = QSocketNotifier(0, QSocketNotifier_Read)
    call check(sn%socket() == 0 .and. sn%notifierType() == QSocketNotifier_Read, 'socket, notifierType')
    call check(sn%isEnabled() .and. sn%isValid(), 'enabled and valid at once')
    call sn%setEnabled(.false.)
    call check(.not. sn%isEnabled(), 'setEnabled')
    call sn%delete()

    ! ---- QSocketNotifier: a real notification, in a child process
    if (.not. QWinEventNotifier_isSupported()) then
        call get_command_argument(0, arg)
        self = trim(arg)
        if (self(1:1) /= '/') self = QDir_currentPath()//'/'//self
        p = QProcess()
        call p%start(self, ['child'])
        call check(p%waitForStarted(), 'child started')
        n = p%write('hello'//new_line('a'))
        call check(p%waitForFinished(20000), 'child finished')
        out = p%readAllStandardOutput()
        call check(index(out, 'got: hello on 0') > 0, 'activated: the slot read the line')
        call p%delete()
    end if

    ! ---- QWinEventNotifier: the API (it fires only on Windows)
    wn = QWinEventNotifier(0_c_long_long)
    call check(wn%handle() == 0_c_long_long .and. wn%isEnabled(), 'QWinEventNotifier handle, enabled')
    call wn%setHandle(1234_c_long_long)
    call check(wn%handle() == 1234_c_long_long, 'setHandle')
    call wn%setEnabled(.false.)
    call check(.not. wn%isEnabled(), 'QWinEventNotifier setEnabled')
    call wn%activated%connect(on_signaled, log)
    call QApplication_processEvents()
    call check(log%calls == 0, 'not activated')
    call wn%delete()

end program test_notifiers
