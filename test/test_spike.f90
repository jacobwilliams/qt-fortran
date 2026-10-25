!> Spike test: create widgets, round-trip strings, and fire a callback
!> from inside the event loop. Run headless with QT_QPA_PLATFORM=offscreen.
program test_spike

    use iso_c_binding
    use qt
    implicit none

    type(QApplication) :: app
    type(QLabel) :: label
    integer(c_int), target :: counter
    integer :: ierr
    ! 'héllo → Qt' as explicit UTF-8 bytes, so the source stays ASCII for every compiler
    character(len=*), parameter :: msg = 'h'//achar(195)//achar(169)//'llo '// &
                                         achar(226)//achar(134)//achar(146)//' Qt'

    app = QApplication()

    label = QLabel("initial")
    call check(label%text() == "initial", "QLabel constructor text")

    call label%setText(msg)
    call check(label%text() == msg, "UTF-8 round-trip")
    call check(len(label%text()) == len(msg), "byte length preserved")

    call label%show()

    counter = 0
    call QTimer_singleShot(10, on_timeout, c_loc(counter))
    ierr = app%exec()
    call check(ierr == 0, "exec returned 0")
    call check(counter == 1, "timer callback fired once")

    call label%delete()
    call check(.not. c_associated(label%ptr), "delete nulls handle")

    write(*,'(A)') 'test_spike: all checks passed'

contains

    subroutine on_timeout(data) bind(C)
        type(c_ptr), value :: data
        integer(c_int), pointer :: n
        call c_f_pointer(data, n)
        n = n + 1
        call app%quit()
    end subroutine on_timeout

    subroutine check(cond, what)
        logical, intent(in) :: cond
        character(len=*), intent(in) :: what
        if (.not. cond) then
            write(*,'(A)') 'FAILED: '//what
            error stop 1
        end if
        write(*,'(A)') 'ok: '//what
    end subroutine check

end program test_spike
