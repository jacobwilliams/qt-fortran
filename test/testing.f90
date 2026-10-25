!> Minimal assertion helper shared by the tests.
module testing

    implicit none
    private
    public :: check

contains

    !> Print 'ok: what', or stop with an error if `cond` is false.
    subroutine check(cond, what)
        logical, intent(in) :: cond
        character(len=*), intent(in) :: what
        if (.not. cond) then
            write(*,'(A)') 'FAILED: '//what
            error stop 1
        end if
        write(*,'(A)') 'ok: '//what
    end subroutine check

end module testing
