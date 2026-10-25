!> Hand-written low-level helpers shared by all modules: the signal argument
!> block and string/boolean conversion across the C boundary.
module qt_c_util

    use iso_c_binding
    use qt_c_core, only: qtf_free
    implicit none
    private

    !> Signal arguments from the shim (mirrors `struct qtf_args` in shim/qtf_common.h).
    !> `s` and `p` are borrowed: valid only during the dispatch call.
    type, bind(C), public :: qtf_args
        integer(c_int64_t) :: i(4)
        real(c_double) :: d(4)
        type(c_ptr) :: s
        type(c_ptr) :: p
        integer(c_int32_t) :: slen
    end type qtf_args

    !> An element of a string list (e.g. selected file names).
    type, public :: qt_string
        character(len=:), allocatable :: s
    end type qt_string

    public :: qtf_string, qtf_take_string, qtf_take_string_list, qtf_take_ints, qtf_logical, qtf_int

contains

    !> Copy `len` bytes of UTF-8 at `p` into a Fortran string (borrowed: not freed).
    function qtf_string(p, len) result(s)
        type(c_ptr), intent(in) :: p
        integer(c_int), intent(in) :: len
        character(len=:), allocatable :: s
        character(kind=c_char), dimension(:), pointer :: buf
        integer :: i
        allocate(character(len=len) :: s)
        if (len == 0) return
        call c_f_pointer(p, buf, [len])
        do i = 1, len
            s(i:i) = buf(i)
        end do
    end function qtf_string

    !> Copy a malloc'd UTF-8 buffer returned by the shim, then free it.
    function qtf_take_string(p, len) result(s)
        type(c_ptr), intent(in) :: p
        integer(c_int), intent(in) :: len
        character(len=:), allocatable :: s
        s = qtf_string(p, len)
        call qtf_free(p)
    end function qtf_take_string

    !> Split a malloc'd buffer of NUL-terminated UTF-8 strings (as returned by
    !> the shim for string lists) into a list, then free it.
    function qtf_take_string_list(p, nbytes) result(list)
        type(c_ptr), intent(in) :: p
        integer(c_int), intent(in) :: nbytes
        type(qt_string), allocatable :: list(:)
        character(len=:), allocatable :: all
        integer :: n, start, i
        all = qtf_take_string(p, nbytes)
        n = count([(all(i:i) == achar(0), i = 1, len(all))])
        allocate(list(n))
        start = 1
        n = 0
        do i = 1, len(all)
            if (all(i:i) == achar(0)) then
                n = n + 1
                list(n)%s = all(start:i-1)
                start = i + 1
            end if
        end do
    end function qtf_take_string_list

    !> Copy a malloc'd array of `n` C ints returned by the shim, then free it.
    function qtf_take_ints(p, n) result(v)
        type(c_ptr), intent(in) :: p
        integer(c_int), intent(in) :: n
        integer, allocatable :: v(:)
        integer(c_int), pointer :: buf(:)
        allocate(v(n))
        if (n > 0) then
            call c_f_pointer(p, buf, [n])
            v = buf
        end if
        call qtf_free(p)
    end function qtf_take_ints

    !> Shim boolean (0/1) to Fortran logical.
    pure elemental function qtf_logical(b) result(l)
        integer(c_int), intent(in) :: b
        logical :: l
        l = b /= 0
    end function qtf_logical

    !> Fortran logical to shim boolean (0/1).
    pure elemental function qtf_int(l) result(b)
        logical, intent(in) :: l
        integer(c_int) :: b
        b = merge(1_c_int, 0_c_int, l)
    end function qtf_int

end module qt_c_util
