!> A label counting down once per second, then closing the application.
module timer_slots

    use qt
    implicit none

    !> State of the countdown window.
    type :: countdown
        type(QLabel) :: label
        type(QTimer) :: timer
        integer :: remaining = 5
    end type countdown

contains

    !> Count down once per second; quit at zero.
    subroutine on_tick(data)
        class(*), intent(inout), optional :: data
        character(len=32) :: buf
        select type (data)
        type is (countdown)
            data%remaining = data%remaining - 1
            if (data%remaining > 0) then
                write(buf, '(A,I0)') 'Closing in ', data%remaining
                call data%label%setText(trim(buf))
            else
                call data%timer%stop()
                call QApplication_quit()
            end if
        end select
    end subroutine on_tick

end module timer_slots

!> A window counting down with QTimer, then closing the application.
program timer

    use qt
    use timer_slots
    implicit none

    type(QApplication) :: app
    type(countdown), target :: state
    integer :: ierr

    app = QApplication()

    state%label = QLabel('Closing in 5')
    call state%label%setWindowTitle('qt-fortran timer')
    call state%label%setAlignment(Qt_AlignCenter)
    call state%label%resize(320, 120)
    call state%label%show()

    state%timer = QTimer()
    call state%timer%timeout%connect(on_tick, state)
    call state%timer%start(1000)

    ierr = app%exec()
    write(*,'(A,I0)') 'event loop exited with code ', ierr

end program timer
