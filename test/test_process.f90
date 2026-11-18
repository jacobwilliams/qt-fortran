!> QProcess and QProcessEnvironment. The test runs its own executable as the
!> child program (`test_process child <mode>`), so it needs no other
!> programs on any platform. Run headless with QT_QPA_PLATFORM=offscreen.
module test_process_slots

    use qt
    implicit none

    !> What the slots saw.
    type :: process_log
        type(QProcess) :: proc
        integer :: started = 0, finished = 0, errors = 0, reads = 0
        integer :: exit_code = -99, exit_status = -99, error = -99
        integer, allocatable :: states(:)
        character(len=:), allocatable :: output
    end type process_log

contains

    !> Count `started`.
    subroutine on_started(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (process_log)
            data%started = data%started + 1
        end select
    end subroutine on_started

    !> Record `finished(exitCode, exitStatus)`; quit a running event loop.
    subroutine on_finished(exit_code, exit_status, data)
        integer, intent(in) :: exit_code, exit_status
        class(*), intent(inout), optional :: data
        select type (data)
        type is (process_log)
            data%finished = data%finished + 1
            data%exit_code = exit_code
            data%exit_status = exit_status
        end select
        call QApplication_quit()
    end subroutine on_finished

    !> Record `errorOccurred(error)`.
    subroutine on_error(error, data)
        integer, intent(in) :: error
        class(*), intent(inout), optional :: data
        select type (data)
        type is (process_log)
            data%errors = data%errors + 1
            data%error = error
        end select
    end subroutine on_error

    !> Record `stateChanged(state)`.
    subroutine on_state(state, data)
        integer, intent(in) :: state
        class(*), intent(inout), optional :: data
        select type (data)
        type is (process_log)
            data%states = [data%states, state]
        end select
    end subroutine on_state

    !> Collect standard output as it arrives.
    subroutine on_ready_read(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (process_log)
            data%reads = data%reads + 1
            data%output = data%output//data%proc%readAllStandardOutput()
        end select
    end subroutine on_ready_read

    !> Stop a hung event loop.
    subroutine on_timeout(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_timeout

    !> The child program: what it does depends on `mode`.
    subroutine run_child(mode)
        use iso_fortran_env, only: error_unit, output_unit
        character(len=*), intent(in) :: mode
        character(len=256) :: line, value
        integer :: ios, k
        select case (mode)
        case ('echo')
            ! echo standard input, report an environment variable, exit with code 3
            read(*, '(A)', iostat=ios) line
            write(output_unit, '(A)') 'got: '//trim(line)
            call get_environment_variable('QTF_TEST_VAR', value, status=ios)
            if (ios /= 0) value = '(unset)'
            write(output_unit, '(A)') 'var: '//trim(value)
            write(error_unit, '(A)') 'err: on stderr'
            flush(output_unit)
            flush(error_unit)
            stop 3
        case ('lines')
            do k = 1, 3
                write(output_unit, '(A,I0)') 'line ', k
            end do
        case ('wait')
            ! block until standard input is closed (or the process is killed)
            do
                read(*, '(A)', iostat=ios) line
                if (ios /= 0) exit
            end do
        case default   ! 'quiet': exit with code 0
        end select
    end subroutine run_child

end module test_process_slots

!> Tests for QProcess.
program test_process

    use qt
    use testing
    use test_process_slots
    implicit none

    type(QApplication) :: app
    type(QProcess) :: p
    type(QProcessEnvironment) :: env, env2
    type(process_log), target :: log
    type(qt_string), allocatable :: list(:)
    character(len=:), allocatable :: self, out, err
    character(len=1024) :: arg
    integer :: n, code, ierr

    ! the child program
    call get_command_argument(1, arg)
    if (arg == 'child') then
        call get_command_argument(2, arg)
        call run_child(trim(arg))
        stop
    end if

    app = QApplication()
    call get_command_argument(0, arg)
    self = trim(arg)
    ! a relative path would depend on the child's working directory
    if (self(1:1) /= '/' .and. index(self, ':') == 0) self = QDir_currentPath()//'/'//self

    ! ---- QProcessEnvironment
    env = QProcessEnvironment()
    call check(env%isEmpty(), 'QProcessEnvironment() is empty')
    call env%insert('A', '1')
    call env%insert('B', 'two')
    call check(env%contains('A') .and. env%value('B') == 'two', 'QProcessEnvironment insert / value')
    call check(env%value('C', 'none') == 'none', 'QProcessEnvironment value default')
    list = env%keys()
    call check(size(list) == 2, 'QProcessEnvironment keys')
    env2 = env%copy()
    call env%remove('A')
    call check(.not. env%contains('A') .and. env2%contains('A'), 'QProcessEnvironment remove / copy')
    call env%delete()
    call env2%delete()
    env = QProcessEnvironment_systemEnvironment()
    call check(.not. env%isEmpty(), 'QProcessEnvironment_systemEnvironment')
    call env%insert('QTF_TEST_VAR', 'forty-two')

    ! ---- run, write to stdin, read stdout and stderr (waiting, no event loop)
    p = QProcess()
    log%proc = p
    call p%started%connect(on_started, log)
    call p%finished%connect(on_finished, log)
    call p%errorOccurred%connect(on_error, log)
    allocate(log%states(0))
    call p%stateChanged%connect(on_state, log)
    call p%setProgram(self)
    call p%setArguments([character(len=5) :: 'child', 'echo'])
    call check(p%program() == self, 'QProcess program')
    list = p%arguments()
    call check(size(list) == 2 .and. list(2)%s == 'echo', 'QProcess arguments')
    call p%setProcessEnvironment(env)
    call env%delete()
    env = p%processEnvironment()
    call check(env%value('QTF_TEST_VAR') == 'forty-two', 'QProcess processEnvironment')
    call env%delete()
    call check(p%state() == QProcess_NotRunning, 'QProcess not running before start')
    call p%start()
    call check(p%waitForStarted(), 'QProcess waitForStarted')
    call check(p%state() == QProcess_Running .and. p%processId() > 0, 'QProcess running, processId')
    n = p%write('hello'//new_line('a'))
    call check(n == 6, 'QProcess write')
    call p%closeWriteChannel()
    call check(p%waitForFinished(), 'QProcess waitForFinished')
    out = p%readAllStandardOutput()
    err = p%readAllStandardError()
    call check(index(out, 'got: hello') > 0, 'stdin reached the child; stdout read')
    call check(index(out, 'var: forty-two') > 0, 'the environment reached the child')
    call check(index(err, 'err: on stderr') > 0 .and. index(out, 'err:') == 0, 'stderr read separately')
    call check(p%exitCode() == 3 .and. p%exitStatus() == QProcess_NormalExit, 'exitCode / exitStatus')
    call check(log%started == 1 .and. log%finished == 1, 'started / finished signals during waits')
    call check(log%exit_code == 3 .and. log%exit_status == QProcess_NormalExit, 'finished(exitCode, exitStatus)')
    call check(size(log%states) >= 3, 'stateChanged')
    call check(log%states(size(log%states)) == QProcess_NotRunning, 'stateChanged: not running at the end')

    ! ---- merged channels, a program and arguments given to start
    call p%setProcessChannelMode(QProcess_MergedChannels)
    call p%start(self, [character(len=5) :: 'child', 'echo'])
    call p%closeWriteChannel()
    call check(p%waitForFinished(), 'merged: finished')
    out = p%readAllStandardOutput()
    call check(index(out, 'err: on stderr') > 0 .and. index(out, 'got:') > 0, 'merged channels')
    call p%setProcessChannelMode(QProcess_SeparateChannels)

    ! ---- reading line by line
    call p%start(self, [character(len=5) :: 'child', 'lines'])
    call check(p%waitForFinished(), 'lines: finished')
    n = 0
    do while (p%canReadLine())
        out = p%readLine()
        n = n + 1
        if (n == 2) call check(out == 'line 2', 'readLine strips the line break')
    end do
    call check(n == 3 .and. p%exitCode() == 0, 'readLine / canReadLine')

    ! ---- a program that does not exist
    log%errors = 0
    call p%start('qtf-no-such-program-xyz')
    call check(.not. p%waitForStarted(), 'missing program: waitForStarted is false')
    call check(p%error() == QProcess_FailedToStart .and. log%error == QProcess_FailedToStart, &
               'missing program: errorOccurred(QProcess_FailedToStart)')
    call check(len(p%errorString()) > 0, 'errorString')

    ! ---- kill a running program
    call p%start(self, [character(len=5) :: 'child', 'wait'])
    call check(p%waitForStarted(), 'wait: started')
    call check(.not. p%waitForFinished(200), 'waitForFinished times out')
    call p%kill()
    call check(p%waitForFinished(), 'killed: finished')
    call check(p%state() == QProcess_NotRunning, 'killed: not running')

    ! ---- asynchronous: output and finish arrive in slots inside the event loop
    log%reads = 0
    log%finished = 0
    log%output = ''
    call p%readyReadStandardOutput%connect(on_ready_read, log)
    call p%start(self, [character(len=5) :: 'child', 'echo'])
    n = p%write('async'//new_line('a'))
    call p%closeWriteChannel()
    call QTimer_singleShot(20000, on_timeout)
    ierr = app%exec()
    call check(log%finished == 1 .and. log%exit_code == 3, 'finished arrives in the event loop')
    call check(log%reads > 0 .and. index(log%output, 'got: async') > 0, 'readyReadStandardOutput')

    ! ---- working directory, files, static functions
    call p%setWorkingDirectory(QDir_tempPath())
    call check(p%workingDirectory() == QDir_tempPath(), 'working directory')
    code = QProcess_execute(self, [character(len=5) :: 'child', 'quiet'])
    call check(code == 0, 'QProcess_execute')
    list = QProcess_splitCommand('fpm run "my app" --verbose')
    call check(size(list) == 4 .and. list(3)%s == 'my app', 'QProcess_splitCommand')
    call check(len(QProcess_nullDevice()) > 0, 'QProcess_nullDevice')
    call p%startCommand('"'//self//'" child quiet')
    call check(p%waitForFinished() .and. p%exitCode() == 0, 'startCommand')

    call p%delete()

end program test_process
