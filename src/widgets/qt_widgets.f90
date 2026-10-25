!> Qt Widgets: QApplication, QWidget, QLabel.
module qt_widgets

    use iso_c_binding
    use qt_c_core, only: qtf_take_string, qtf_logical
    use qt_c_widgets
    use qt_core
    implicit none
    private

    !> The application object. Create exactly one, before any widget.
    type, extends(QObject), public :: QApplication
    contains
        procedure, nopass :: exec => QApplication_exec
        procedure, nopass :: quit => QApplication_quit
        procedure, nopass :: processEvents => QApplication_processEvents
    end type QApplication
    interface QApplication
        module procedure :: qapplication_new
    end interface QApplication

    type, extends(QObject), public :: QWidget
    contains
        procedure :: show => qwidget_show
        procedure :: hide => qwidget_hide
        procedure :: isVisible => qwidget_isVisible
        procedure :: resize => qwidget_resize
        procedure :: width => qwidget_width
        procedure :: height => qwidget_height
        procedure :: setWindowTitle => qwidget_setWindowTitle
        procedure :: windowTitle => qwidget_windowTitle
    end type QWidget
    interface QWidget
        module procedure :: qwidget_new
    end interface QWidget

    type, extends(QWidget), public :: QLabel
    contains
        procedure :: setText => qlabel_setText
        procedure :: text => qlabel_text
        procedure :: setAlignment => qlabel_setAlignment
    end type QLabel
    interface QLabel
        module procedure :: qlabel_new
    end interface QLabel

    public :: QApplication_exec, QApplication_quit, QApplication_processEvents

contains

    ! ------------------------------------------------------------------
    ! QApplication

    function qapplication_new() result(app)
        type(QApplication) :: app
        call app%attach(qtf_qapplication_new())
    end function qapplication_new

    !> Run the event loop until quit; returns the exit code.
    integer function QApplication_exec()
        QApplication_exec = qtf_qapplication_exec()
    end function QApplication_exec

    subroutine QApplication_quit()
        call qtf_qapplication_quit()
    end subroutine QApplication_quit

    subroutine QApplication_processEvents()
        call qtf_qapplication_processEvents()
    end subroutine QApplication_processEvents

    ! ------------------------------------------------------------------
    ! QWidget

    function qwidget_new(parent) result(w)
        class(QWidget), intent(in), optional :: parent
        type(QWidget) :: w
        call w%attach(qtf_qwidget_new(qtf_ptr(parent)))
    end function qwidget_new

    subroutine qwidget_show(self)
        class(QWidget), intent(in) :: self
        call qtf_qwidget_show(self%ptr)
    end subroutine qwidget_show

    subroutine qwidget_hide(self)
        class(QWidget), intent(in) :: self
        call qtf_qwidget_hide(self%ptr)
    end subroutine qwidget_hide

    logical function qwidget_isVisible(self)
        class(QWidget), intent(in) :: self
        qwidget_isVisible = qtf_logical(qtf_qwidget_isVisible(self%ptr))
    end function qwidget_isVisible

    subroutine qwidget_resize(self, width, height)
        class(QWidget), intent(in) :: self
        integer, intent(in) :: width, height
        call qtf_qwidget_resize(self%ptr, int(width, c_int), int(height, c_int))
    end subroutine qwidget_resize

    integer function qwidget_width(self)
        class(QWidget), intent(in) :: self
        qwidget_width = qtf_qwidget_width(self%ptr)
    end function qwidget_width

    integer function qwidget_height(self)
        class(QWidget), intent(in) :: self
        qwidget_height = qtf_qwidget_height(self%ptr)
    end function qwidget_height

    subroutine qwidget_setWindowTitle(self, title)
        class(QWidget), intent(in) :: self
        character(len=*), intent(in) :: title
        call qtf_qwidget_setWindowTitle(self%ptr, title, len(title, c_int))
    end subroutine qwidget_setWindowTitle

    function qwidget_windowTitle(self) result(title)
        class(QWidget), intent(in) :: self
        character(len=:), allocatable :: title
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qwidget_windowTitle(self%ptr, n)
        title = qtf_take_string(p, n)
    end function qwidget_windowTitle

    ! ------------------------------------------------------------------
    ! QLabel

    function qlabel_new(text, parent) result(w)
        character(len=*), intent(in) :: text
        class(QWidget), intent(in), optional :: parent
        type(QLabel) :: w
        call w%attach(qtf_qlabel_new(text, len(text, c_int), qtf_ptr(parent)))
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
        text = qtf_take_string(p, n)
    end function qlabel_text

    subroutine qlabel_setAlignment(self, flags)
        class(QLabel), intent(in) :: self
        integer(c_int), intent(in) :: flags
        call qtf_qlabel_setAlignment(self%ptr, flags)
    end subroutine qlabel_setAlignment

end module qt_widgets
