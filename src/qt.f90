!> Modern Fortran interface to Qt.
module qt

    use iso_c_binding
    use qt_c_widgets
    implicit none
    private

    integer(c_int), parameter, public :: Qt_AlignLeft    = int(z'0001', c_int)
    integer(c_int), parameter, public :: Qt_AlignRight   = int(z'0002', c_int)
    integer(c_int), parameter, public :: Qt_AlignHCenter = int(z'0004', c_int)
    integer(c_int), parameter, public :: Qt_AlignVCenter = int(z'0080', c_int)
    integer(c_int), parameter, public :: Qt_AlignCenter  = ior(Qt_AlignHCenter, Qt_AlignVCenter)

    type, public :: QApplication
        type(c_ptr) :: ptr = c_null_ptr
    contains
        procedure, nopass :: exec => qapplication_exec
        procedure, nopass :: quit => qapplication_quit
    end type QApplication
    interface QApplication
        module procedure :: qapplication_new
    end interface QApplication

    type, public :: QWidget
        type(c_ptr) :: ptr = c_null_ptr
    contains
        procedure :: show => qwidget_show
        procedure :: resize => qwidget_resize
        procedure :: setWindowTitle => qwidget_setWindowTitle
        procedure :: delete => qwidget_delete
    end type QWidget

    type, extends(QWidget), public :: QLabel
    contains
        procedure :: setText => qlabel_setText
        procedure :: text => qlabel_text
        procedure :: setAlignment => qlabel_setAlignment
    end type QLabel
    interface QLabel
        module procedure :: qlabel_new
    end interface QLabel

    abstract interface
        !> Callback signature for the spike timer (replaced by a dispatcher in phase 1).
        subroutine qt_callback(data) bind(C)
            import :: c_ptr
            type(c_ptr), value :: data
        end subroutine qt_callback
    end interface
    public :: qt_callback

    public :: QTimer_singleShot

contains

    !> Copy a malloc'd UTF-8 buffer from the shim into a Fortran string and free it.
    function from_c(p, len) result(s)
        type(c_ptr), intent(in) :: p
        integer(c_int), intent(in) :: len
        character(len=:), allocatable :: s
        character(kind=c_char), dimension(:), pointer :: buf
        integer :: i
        allocate(character(len=len) :: s)
        call c_f_pointer(p, buf, [len])
        do i = 1, len
            s(i:i) = buf(i)
        end do
        call qtf_free(p)
    end function from_c

    function qapplication_new() result(app)
        type(QApplication) :: app
        app%ptr = qtf_qapplication_new()
    end function qapplication_new

    function qapplication_exec() result(ierr)
        integer :: ierr
        ierr = qtf_qapplication_exec()
    end function qapplication_exec

    subroutine qapplication_quit()
        call qtf_qapplication_quit()
    end subroutine qapplication_quit

    subroutine qwidget_show(self)
        class(QWidget), intent(in) :: self
        call qtf_qwidget_show(self%ptr)
    end subroutine qwidget_show

    subroutine qwidget_resize(self, width, height)
        class(QWidget), intent(in) :: self
        integer, intent(in) :: width, height
        call qtf_qwidget_resize(self%ptr, int(width, c_int), int(height, c_int))
    end subroutine qwidget_resize

    subroutine qwidget_setWindowTitle(self, title)
        class(QWidget), intent(in) :: self
        character(len=*), intent(in) :: title
        call qtf_qwidget_setWindowTitle(self%ptr, title, len(title, c_int))
    end subroutine qwidget_setWindowTitle

    !> Delete a top-level widget (children are deleted by Qt).
    subroutine qwidget_delete(self)
        class(QWidget), intent(inout) :: self
        if (c_associated(self%ptr)) call qtf_qwidget_delete(self%ptr)
        self%ptr = c_null_ptr
    end subroutine qwidget_delete

    function qlabel_new(text, parent) result(w)
        character(len=*), intent(in) :: text
        class(QWidget), intent(in), optional :: parent
        type(QLabel) :: w
        type(c_ptr) :: p
        p = c_null_ptr
        if (present(parent)) p = parent%ptr
        w%ptr = qtf_qlabel_new(text, len(text, c_int), p)
    end function qlabel_new

    subroutine qlabel_setText(self, text)
        class(QLabel), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qlabel_setText(self%ptr, text, len(text, c_int))
    end subroutine qlabel_setText

    function qlabel_text(self) result(text)
        class(QLabel), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qlabel_text(self%ptr, n)
        text = from_c(p, n)
    end function qlabel_text

    subroutine qlabel_setAlignment(self, flags)
        class(QLabel), intent(in) :: self
        integer(c_int), intent(in) :: flags
        call qtf_qlabel_setAlignment(self%ptr, flags)
    end subroutine qlabel_setAlignment

    subroutine QTimer_singleShot(msec, callback, data)
        integer, intent(in) :: msec
        procedure(qt_callback) :: callback
        type(c_ptr), intent(in), optional :: data
        type(c_ptr) :: d
        d = c_null_ptr
        if (present(data)) d = data
        call qtf_qtimer_singleShot(int(msec, c_int), c_funloc(callback), d)
    end subroutine QTimer_singleShot

end module qt
