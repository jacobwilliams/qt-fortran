!> Object lifetime: handles to deleted objects are detected (isNull, and calls
!> on them stop with a clear message instead of crashing).
!> The misuse cases end the program, so the test runs itself again with
!> `--misuse <case>` for each and checks the exit status and message.
!> Run headless with QT_QPA_PLATFORM=offscreen.
module test_lifetime_cases

    use qt
    implicit none

contains

    !> Leave the event loop.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

    !> Run the event loop once (deferred deletions happen there).
    subroutine spin()
        integer :: ierr
        call QTimer_singleShot(0, on_quit)
        ierr = QApplication_exec()
    end subroutine spin

    !> A slot that does nothing.
    subroutine on_nothing(data)
        class(*), intent(inout), optional :: data
    end subroutine on_nothing

    !> Misuse a handle in the way named by `what` (this stops the program).
    subroutine misuse(what)
        character(len=*), intent(in) :: what
        type(QWidget) :: window, never
        type(QLabel) :: label
        type(QPushButton) :: button
        type(QVBoxLayout) :: layout
        type(QSignalInt) :: sig
        type(QObject) :: owner
        window = QWidget()
        label = QLabel('text', window)
        button = QPushButton('Go', window)
        select case (what)
        case ('method')            ! a child deleted together with its parent
            call window%delete()
            call label%setText('boom')
        case ('null')              ! a handle that was never created
            call never%show()
        case ('argument')          ! a deleted widget passed to a method
            layout = QVBoxLayout()
            call window%delete()
            call layout%addWidget(label)
        case ('parent')            ! a deleted parent (the label went with the window)
            call window%delete()
            button = QPushButton('again', label)
        case ('connect')           ! connecting to a deleted object's signal
            call window%delete()
            call button%clicked%connect(on_nothing)
        case ('emit')              ! emitting a signal whose owner was deleted
            owner = QObject()
            sig = QSignalInt(owner)
            call owner%delete()
            call sig%emit(1)
        end select
        write(*,'(A)') 'misuse not detected: ' // what
    end subroutine misuse

end module test_lifetime_cases

!> Tests detection of deleted objects.
program test_lifetime

    use qt
    use testing
    use test_lifetime_cases
    use iso_c_binding, only: c_associated
    implicit none

    character(len=*), parameter :: log_file = 'build/test_lifetime_misuse.txt'
    type(QApplication) :: app
    type(QWidget) :: window, central
    type(QMainWindow) :: main
    type(QLabel) :: label, label2
    type(QObject) :: a, b, c
    character(len=1024) :: arg, self_path
    integer :: i
    logical :: reused

    app = QApplication()
    call get_command_argument(1, arg)
    if (arg == '--misuse') then
        call get_command_argument(2, arg)
        call misuse(trim(arg))
        stop
    end if

    ! --- a child deleted together with its parent
    window = QWidget()
    label = QLabel('child', window)
    label2 = label                               ! a second handle to the same label
    call check(.not. label%isNull(), 'live child')
    call window%delete()
    call check(window%isNull(), 'deleted through this handle')
    call check(label%isNull() .and. label2%isNull(), 'child deleted with its parent')
    call label%delete()                          ! already gone: no double delete
    call check(label%isNull(), 'delete of a deleted object is a no-op')

    ! --- copies of a handle; deleted through another copy
    a = QObject()
    b = a
    call a%delete()
    call check(b%isNull(), 'copy sees the deletion')
    call b%delete()

    ! --- a new object at the same address is not mistaken for the old one
    reused = .false.
    a = QObject()
    b = a
    do i = 1, 200
        call a%delete()
        c = QObject()
        if (c_associated(c%ptr, b%ptr)) then
            reused = .true.
            exit
        end if
        a = c
    end do
    call check(b%isNull(), 'stale handle stays null (address reused: ' // merge('yes', 'no ', reused) // ')')
    if (reused) call check(.not. c%isNull(), 'the new object is live')
    call c%delete()

    ! --- deleteLater takes effect in the event loop
    a = QObject()
    call a%deleteLater()
    call check(.not. a%isNull(), 'deleteLater: alive until the event loop runs')
    call spin()
    call check(a%isNull(), 'deleteLater: deleted')

    ! --- an object Qt deletes on its own (a replaced central widget)
    main = QMainWindow()
    call main%setCentralWidget(QLabel('first'))
    central = main%centralWidget()
    call main%setCentralWidget(QLabel('second'))
    call spin()                                  ! (QMainWindow may delete it later)
    call check(central%isNull(), 'replaced central widget deleted by Qt')
    call main%delete()

    ! --- misuse stops with a clear message
    call get_command_argument(0, self_path)
    call expect_stop('method', 'QLabel%setText')
    call expect_stop('null', 'null handle')
    call expect_stop('argument', 'has been deleted')
    call expect_stop('parent', 'has been deleted')
    call expect_stop('connect', 'connect: the object of this signal has been deleted')
    call expect_stop('emit', 'emit: the object of this signal has been deleted')

    write(*,'(A)') 'test_lifetime: all checks passed'

contains

    !> Run this program with `--misuse what`; check it fails with `message`.
    subroutine expect_stop(what, message)
        character(len=*), intent(in) :: what, message
        integer :: status, u, ios
        character(len=500) :: line
        logical :: found
        call execute_command_line('"' // trim(self_path) // '" --misuse ' // what // ' > ' // log_file // ' 2>&1', &
                                  exitstat=status)
        found = .false.
        open(newunit=u, file=log_file, status='old', action='read', iostat=ios)
        do while (ios == 0)
            read(u, '(A)', iostat=ios) line
            if (ios == 0) found = found .or. index(line, message) > 0
        end do
        close(u)
        call check(status /= 0 .and. found, 'misuse "' // what // '" stops: ' // message)
    end subroutine expect_stop

end program test_lifetime
