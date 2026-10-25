!> Raw `bind(C)` interfaces to the C++ shim in `shim/qtf_widgets.cpp`.
module qt_c_widgets

    use iso_c_binding
    implicit none
    private

    interface

        ! QApplication

        function qtf_qapplication_new() result(app) bind(C, name='qtf_qapplication_new')
            import :: c_ptr
            type(c_ptr) :: app
        end function qtf_qapplication_new

        function qtf_qapplication_exec() result(ierr) bind(C, name='qtf_qapplication_exec')
            import :: c_int
            integer(c_int) :: ierr
        end function qtf_qapplication_exec

        subroutine qtf_qapplication_quit() bind(C, name='qtf_qapplication_quit')
        end subroutine qtf_qapplication_quit

        subroutine qtf_qapplication_processEvents() bind(C, name='qtf_qapplication_processEvents')
        end subroutine qtf_qapplication_processEvents

        ! QWidget

        function qtf_qwidget_new(parent) result(w) bind(C, name='qtf_qwidget_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: w
        end function qtf_qwidget_new

        subroutine qtf_qwidget_show(w) bind(C, name='qtf_qwidget_show')
            import :: c_ptr
            type(c_ptr), value :: w
        end subroutine qtf_qwidget_show

        subroutine qtf_qwidget_hide(w) bind(C, name='qtf_qwidget_hide')
            import :: c_ptr
            type(c_ptr), value :: w
        end subroutine qtf_qwidget_hide

        function qtf_qwidget_isVisible(w) result(b) bind(C, name='qtf_qwidget_isVisible')
            import :: c_ptr, c_int
            type(c_ptr), value :: w
            integer(c_int) :: b
        end function qtf_qwidget_isVisible

        subroutine qtf_qwidget_resize(w, width, height) bind(C, name='qtf_qwidget_resize')
            import :: c_ptr, c_int
            type(c_ptr), value :: w
            integer(c_int), value :: width, height
        end subroutine qtf_qwidget_resize

        function qtf_qwidget_width(w) result(width) bind(C, name='qtf_qwidget_width')
            import :: c_ptr, c_int
            type(c_ptr), value :: w
            integer(c_int) :: width
        end function qtf_qwidget_width

        function qtf_qwidget_height(w) result(height) bind(C, name='qtf_qwidget_height')
            import :: c_ptr, c_int
            type(c_ptr), value :: w
            integer(c_int) :: height
        end function qtf_qwidget_height

        subroutine qtf_qwidget_setWindowTitle(w, s, len) bind(C, name='qtf_qwidget_setWindowTitle')
            import :: c_ptr, c_char, c_int
            type(c_ptr), value :: w
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qwidget_setWindowTitle

        function qtf_qwidget_windowTitle(w, len) result(s) bind(C, name='qtf_qwidget_windowTitle')
            import :: c_ptr, c_int
            type(c_ptr), value :: w
            integer(c_int), intent(out) :: len
            type(c_ptr) :: s
        end function qtf_qwidget_windowTitle

        ! QLabel

        function qtf_qlabel_new(s, len, parent) result(w) bind(C, name='qtf_qlabel_new')
            import :: c_ptr, c_char, c_int
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
            type(c_ptr), value :: parent
            type(c_ptr) :: w
        end function qtf_qlabel_new

        subroutine qtf_qlabel_setText(w, s, len) bind(C, name='qtf_qlabel_setText')
            import :: c_ptr, c_char, c_int
            type(c_ptr), value :: w
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qlabel_setText

        function qtf_qlabel_text(w, len) result(s) bind(C, name='qtf_qlabel_text')
            import :: c_ptr, c_int
            type(c_ptr), value :: w
            integer(c_int), intent(out) :: len
            type(c_ptr) :: s
        end function qtf_qlabel_text

        subroutine qtf_qlabel_setAlignment(w, flags) bind(C, name='qtf_qlabel_setAlignment')
            import :: c_ptr, c_int
            type(c_ptr), value :: w
            integer(c_int), value :: flags
        end subroutine qtf_qlabel_setAlignment

    end interface

    public :: qtf_qapplication_new, qtf_qapplication_exec, qtf_qapplication_quit
    public :: qtf_qapplication_processEvents
    public :: qtf_qwidget_new, qtf_qwidget_show, qtf_qwidget_hide, qtf_qwidget_isVisible
    public :: qtf_qwidget_resize, qtf_qwidget_width, qtf_qwidget_height
    public :: qtf_qwidget_setWindowTitle, qtf_qwidget_windowTitle
    public :: qtf_qlabel_new, qtf_qlabel_setText, qtf_qlabel_text, qtf_qlabel_setAlignment

end module qt_c_widgets
