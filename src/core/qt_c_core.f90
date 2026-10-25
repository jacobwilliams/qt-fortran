!> Raw `bind(C)` interfaces to the C++ shim in `shim/qtf_core.cpp`,
!> plus low-level helpers shared by all modules.
module qt_c_core

    use iso_c_binding
    implicit none
    private

    ! Signal ids: must match `enum qtf_signal` in shim/qtf_common.h.
    integer(c_int), parameter, public :: QTF_SIG_QOBJECT_DESTROYED = 1
    integer(c_int), parameter, public :: QTF_SIG_QOBJECT_OBJECTNAMECHANGED = 2
    integer(c_int), parameter, public :: QTF_SIG_QTIMER_TIMEOUT = 3

    !> Signal arguments from the shim (mirrors `struct qtf_args`).
    !> `s` is borrowed: valid only during the dispatch call.
    type, bind(C), public :: qtf_args
        integer(c_int64_t) :: i(4)
        real(c_double) :: d(4)
        type(c_ptr) :: s
        integer(c_int32_t) :: slen
    end type qtf_args

    public :: qtf_string, qtf_take_string, qtf_logical, qtf_int

    interface

        subroutine qtf_free(p) bind(C, name='qtf_free')
            import :: c_ptr
            type(c_ptr), value :: p
        end subroutine qtf_free

        subroutine qtf_set_dispatcher(dispatch, release) bind(C, name='qtf_set_dispatcher')
            import :: c_funptr
            type(c_funptr), value :: dispatch, release
        end subroutine qtf_set_dispatcher

        function qtf_connect(sender, signal, slot) result(ok) bind(C, name='qtf_connect')
            import :: c_ptr, c_int
            type(c_ptr), value :: sender
            integer(c_int), value :: signal, slot
            integer(c_int) :: ok
        end function qtf_connect

        ! QObject

        function qtf_qobject_new(parent) result(o) bind(C, name='qtf_qobject_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: o
        end function qtf_qobject_new

        subroutine qtf_qobject_delete(o) bind(C, name='qtf_qobject_delete')
            import :: c_ptr
            type(c_ptr), value :: o
        end subroutine qtf_qobject_delete

        subroutine qtf_qobject_deleteLater(o) bind(C, name='qtf_qobject_deleteLater')
            import :: c_ptr
            type(c_ptr), value :: o
        end subroutine qtf_qobject_deleteLater

        function qtf_qobject_objectName(o, len) result(s) bind(C, name='qtf_qobject_objectName')
            import :: c_ptr, c_int
            type(c_ptr), value :: o
            integer(c_int), intent(out) :: len
            type(c_ptr) :: s
        end function qtf_qobject_objectName

        subroutine qtf_qobject_setObjectName(o, s, len) bind(C, name='qtf_qobject_setObjectName')
            import :: c_ptr, c_char, c_int
            type(c_ptr), value :: o
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qobject_setObjectName

        subroutine qtf_qobject_setParent(o, parent) bind(C, name='qtf_qobject_setParent')
            import :: c_ptr
            type(c_ptr), value :: o, parent
        end subroutine qtf_qobject_setParent

        function qtf_qobject_parent(o) result(parent) bind(C, name='qtf_qobject_parent')
            import :: c_ptr
            type(c_ptr), value :: o
            type(c_ptr) :: parent
        end function qtf_qobject_parent

        function qtf_qobject_className(o, len) result(s) bind(C, name='qtf_qobject_className')
            import :: c_ptr, c_int
            type(c_ptr), value :: o
            integer(c_int), intent(out) :: len
            type(c_ptr) :: s
        end function qtf_qobject_className

        function qtf_qobject_inherits(o, s, len) result(b) bind(C, name='qtf_qobject_inherits')
            import :: c_ptr, c_char, c_int
            type(c_ptr), value :: o
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
            integer(c_int) :: b
        end function qtf_qobject_inherits

        ! QTimer

        function qtf_qtimer_new(parent) result(t) bind(C, name='qtf_qtimer_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: t
        end function qtf_qtimer_new

        subroutine qtf_qtimer_start(t, msec) bind(C, name='qtf_qtimer_start')
            import :: c_ptr, c_int
            type(c_ptr), value :: t
            integer(c_int), value :: msec
        end subroutine qtf_qtimer_start

        subroutine qtf_qtimer_stop(t) bind(C, name='qtf_qtimer_stop')
            import :: c_ptr
            type(c_ptr), value :: t
        end subroutine qtf_qtimer_stop

        subroutine qtf_qtimer_setInterval(t, msec) bind(C, name='qtf_qtimer_setInterval')
            import :: c_ptr, c_int
            type(c_ptr), value :: t
            integer(c_int), value :: msec
        end subroutine qtf_qtimer_setInterval

        function qtf_qtimer_interval(t) result(msec) bind(C, name='qtf_qtimer_interval')
            import :: c_ptr, c_int
            type(c_ptr), value :: t
            integer(c_int) :: msec
        end function qtf_qtimer_interval

        function qtf_qtimer_isActive(t) result(b) bind(C, name='qtf_qtimer_isActive')
            import :: c_ptr, c_int
            type(c_ptr), value :: t
            integer(c_int) :: b
        end function qtf_qtimer_isActive

        subroutine qtf_qtimer_setSingleShot(t, b) bind(C, name='qtf_qtimer_setSingleShot')
            import :: c_ptr, c_int
            type(c_ptr), value :: t
            integer(c_int), value :: b
        end subroutine qtf_qtimer_setSingleShot

        function qtf_qtimer_isSingleShot(t) result(b) bind(C, name='qtf_qtimer_isSingleShot')
            import :: c_ptr, c_int
            type(c_ptr), value :: t
            integer(c_int) :: b
        end function qtf_qtimer_isSingleShot

        subroutine qtf_qtimer_singleShot(msec, slot) bind(C, name='qtf_qtimer_singleShot')
            import :: c_int
            integer(c_int), value :: msec, slot
        end subroutine qtf_qtimer_singleShot

    end interface

    public :: qtf_free, qtf_set_dispatcher, qtf_connect
    public :: qtf_qobject_new, qtf_qobject_delete, qtf_qobject_deleteLater
    public :: qtf_qobject_objectName, qtf_qobject_setObjectName
    public :: qtf_qobject_setParent, qtf_qobject_parent
    public :: qtf_qobject_className, qtf_qobject_inherits
    public :: qtf_qtimer_new, qtf_qtimer_start, qtf_qtimer_stop
    public :: qtf_qtimer_setInterval, qtf_qtimer_interval, qtf_qtimer_isActive
    public :: qtf_qtimer_setSingleShot, qtf_qtimer_isSingleShot, qtf_qtimer_singleShot

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

end module qt_c_core
