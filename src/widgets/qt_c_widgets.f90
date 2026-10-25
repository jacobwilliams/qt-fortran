!> Raw `bind(C)` interfaces to the C++ shim in `shim/qtf_widgets.cpp`.
module qt_c_widgets

    use iso_c_binding
    implicit none
    private

    ! Signal ids: must match `enum qtf_signal` in shim/qtf_common.h.
    integer(c_int), parameter, public :: QTF_SIG_QABSTRACTBUTTON_CLICKED = 1000
    integer(c_int), parameter, public :: QTF_SIG_QABSTRACTBUTTON_TOGGLED = 1001
    integer(c_int), parameter, public :: QTF_SIG_QABSTRACTBUTTON_PRESSED = 1002
    integer(c_int), parameter, public :: QTF_SIG_QABSTRACTBUTTON_RELEASED = 1003
    integer(c_int), parameter, public :: QTF_SIG_QLINEEDIT_TEXTCHANGED = 1010
    integer(c_int), parameter, public :: QTF_SIG_QLINEEDIT_TEXTEDITED = 1011
    integer(c_int), parameter, public :: QTF_SIG_QLINEEDIT_RETURNPRESSED = 1012
    integer(c_int), parameter, public :: QTF_SIG_QLINEEDIT_EDITINGFINISHED = 1013
    integer(c_int), parameter, public :: QTF_SIG_QSPINBOX_VALUECHANGED = 1020
    integer(c_int), parameter, public :: QTF_SIG_QDOUBLESPINBOX_VALUECHANGED = 1021
    integer(c_int), parameter, public :: QTF_SIG_QABSTRACTSLIDER_VALUECHANGED = 1030
    integer(c_int), parameter, public :: QTF_SIG_QABSTRACTSLIDER_SLIDERMOVED = 1031
    integer(c_int), parameter, public :: QTF_SIG_QABSTRACTSLIDER_SLIDERPRESSED = 1032
    integer(c_int), parameter, public :: QTF_SIG_QABSTRACTSLIDER_SLIDERRELEASED = 1033
    integer(c_int), parameter, public :: QTF_SIG_QCOMBOBOX_CURRENTINDEXCHANGED = 1040
    integer(c_int), parameter, public :: QTF_SIG_QCOMBOBOX_CURRENTTEXTCHANGED = 1041
    integer(c_int), parameter, public :: QTF_SIG_QCOMBOBOX_ACTIVATED = 1042
    integer(c_int), parameter, public :: QTF_SIG_QDIALOG_ACCEPTED = 1050
    integer(c_int), parameter, public :: QTF_SIG_QDIALOG_REJECTED = 1051
    integer(c_int), parameter, public :: QTF_SIG_QDIALOG_FINISHED = 1052

    interface

        function qtf_qapplication_new() result(res) bind(C, name='qtf_qapplication_new')
            import :: c_ptr
            type(c_ptr) :: res
        end function qtf_qapplication_new

        function qtf_qapplication_exec() result(res) bind(C, name='qtf_qapplication_exec')
            import :: c_int
            integer(c_int) :: res
        end function qtf_qapplication_exec

        subroutine qtf_qapplication_quit() bind(C, name='qtf_qapplication_quit')
        end subroutine qtf_qapplication_quit

        subroutine qtf_qapplication_processEvents() bind(C, name='qtf_qapplication_processEvents')
        end subroutine qtf_qapplication_processEvents

        function qtf_qapplication_activeModalWidget() result(res) &
                bind(C, name='qtf_qapplication_activeModalWidget')
            import :: c_ptr
            type(c_ptr) :: res
        end function qtf_qapplication_activeModalWidget

        function qtf_qwidget_new(parent) result(res) bind(C, name='qtf_qwidget_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qwidget_new

        subroutine qtf_qwidget_show(w) bind(C, name='qtf_qwidget_show')
            import :: c_ptr
            type(c_ptr), value :: w
        end subroutine qtf_qwidget_show

        subroutine qtf_qwidget_hide(w) bind(C, name='qtf_qwidget_hide')
            import :: c_ptr
            type(c_ptr), value :: w
        end subroutine qtf_qwidget_hide

        subroutine qtf_qwidget_close(w) bind(C, name='qtf_qwidget_close')
            import :: c_ptr
            type(c_ptr), value :: w
        end subroutine qtf_qwidget_close

        subroutine qtf_qwidget_setVisible(w, b) bind(C, name='qtf_qwidget_setVisible')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), value :: b
        end subroutine qtf_qwidget_setVisible

        function qtf_qwidget_isVisible(w) result(res) bind(C, name='qtf_qwidget_isVisible')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int) :: res
        end function qtf_qwidget_isVisible

        subroutine qtf_qwidget_setEnabled(w, b) bind(C, name='qtf_qwidget_setEnabled')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), value :: b
        end subroutine qtf_qwidget_setEnabled

        function qtf_qwidget_isEnabled(w) result(res) bind(C, name='qtf_qwidget_isEnabled')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int) :: res
        end function qtf_qwidget_isEnabled

        subroutine qtf_qwidget_resize(w, width, height) bind(C, name='qtf_qwidget_resize')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), value :: width
            integer(c_int), value :: height
        end subroutine qtf_qwidget_resize

        function qtf_qwidget_width(w) result(res) bind(C, name='qtf_qwidget_width')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int) :: res
        end function qtf_qwidget_width

        function qtf_qwidget_height(w) result(res) bind(C, name='qtf_qwidget_height')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int) :: res
        end function qtf_qwidget_height

        subroutine qtf_qwidget_setMinimumSize(w, width, height) bind(C, name='qtf_qwidget_setMinimumSize')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), value :: width
            integer(c_int), value :: height
        end subroutine qtf_qwidget_setMinimumSize

        subroutine qtf_qwidget_setFixedSize(w, width, height) bind(C, name='qtf_qwidget_setFixedSize')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), value :: width
            integer(c_int), value :: height
        end subroutine qtf_qwidget_setFixedSize

        subroutine qtf_qwidget_setWindowTitle(w, s, len) bind(C, name='qtf_qwidget_setWindowTitle')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: w
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qwidget_setWindowTitle

        function qtf_qwidget_windowTitle(w, len) result(res) bind(C, name='qtf_qwidget_windowTitle')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qwidget_windowTitle

        subroutine qtf_qwidget_setToolTip(w, s, len) bind(C, name='qtf_qwidget_setToolTip')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: w
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qwidget_setToolTip

        function qtf_qwidget_toolTip(w, len) result(res) bind(C, name='qtf_qwidget_toolTip')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qwidget_toolTip

        subroutine qtf_qwidget_setStyleSheet(w, s, len) bind(C, name='qtf_qwidget_setStyleSheet')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: w
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qwidget_setStyleSheet

        subroutine qtf_qwidget_setFocus(w) bind(C, name='qtf_qwidget_setFocus')
            import :: c_ptr
            type(c_ptr), value :: w
        end subroutine qtf_qwidget_setFocus

        subroutine qtf_qwidget_setLayout(w, layout) bind(C, name='qtf_qwidget_setLayout')
            import :: c_ptr
            type(c_ptr), value :: w
            type(c_ptr), value :: layout
        end subroutine qtf_qwidget_setLayout

        function qtf_qwidget_layout(w) result(res) bind(C, name='qtf_qwidget_layout')
            import :: c_ptr
            type(c_ptr), value :: w
            type(c_ptr) :: res
        end function qtf_qwidget_layout

        function qtf_qlabel_new(s, len, parent) result(res) bind(C, name='qtf_qlabel_new')
            import :: c_char, c_int, c_ptr
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qlabel_new

        subroutine qtf_qlabel_setText(w, s, len) bind(C, name='qtf_qlabel_setText')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: w
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qlabel_setText

        function qtf_qlabel_text(w, len) result(res) bind(C, name='qtf_qlabel_text')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qlabel_text

        subroutine qtf_qlabel_setAlignment(w, flags) bind(C, name='qtf_qlabel_setAlignment')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), value :: flags
        end subroutine qtf_qlabel_setAlignment

        subroutine qtf_qlabel_setWordWrap(w, b) bind(C, name='qtf_qlabel_setWordWrap')
            import :: c_int, c_ptr
            type(c_ptr), value :: w
            integer(c_int), value :: b
        end subroutine qtf_qlabel_setWordWrap

        function qtf_qpushbutton_new(s, len, parent) result(res) bind(C, name='qtf_qpushbutton_new')
            import :: c_char, c_int, c_ptr
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qpushbutton_new

        function qtf_qcheckbox_new(s, len, parent) result(res) bind(C, name='qtf_qcheckbox_new')
            import :: c_char, c_int, c_ptr
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qcheckbox_new

        function qtf_qradiobutton_new(s, len, parent) result(res) bind(C, name='qtf_qradiobutton_new')
            import :: c_char, c_int, c_ptr
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qradiobutton_new

        subroutine qtf_qabstractbutton_setText(b, s, len) bind(C, name='qtf_qabstractbutton_setText')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: b
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qabstractbutton_setText

        function qtf_qabstractbutton_text(b, len) result(res) bind(C, name='qtf_qabstractbutton_text')
            import :: c_int, c_ptr
            type(c_ptr), value :: b
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qabstractbutton_text

        subroutine qtf_qabstractbutton_setCheckable(b, v) bind(C, name='qtf_qabstractbutton_setCheckable')
            import :: c_int, c_ptr
            type(c_ptr), value :: b
            integer(c_int), value :: v
        end subroutine qtf_qabstractbutton_setCheckable

        function qtf_qabstractbutton_isCheckable(b) result(res) &
                bind(C, name='qtf_qabstractbutton_isCheckable')
            import :: c_int, c_ptr
            type(c_ptr), value :: b
            integer(c_int) :: res
        end function qtf_qabstractbutton_isCheckable

        subroutine qtf_qabstractbutton_setChecked(b, v) bind(C, name='qtf_qabstractbutton_setChecked')
            import :: c_int, c_ptr
            type(c_ptr), value :: b
            integer(c_int), value :: v
        end subroutine qtf_qabstractbutton_setChecked

        function qtf_qabstractbutton_isChecked(b) result(res) bind(C, name='qtf_qabstractbutton_isChecked')
            import :: c_int, c_ptr
            type(c_ptr), value :: b
            integer(c_int) :: res
        end function qtf_qabstractbutton_isChecked

        subroutine qtf_qabstractbutton_click(b) bind(C, name='qtf_qabstractbutton_click')
            import :: c_ptr
            type(c_ptr), value :: b
        end subroutine qtf_qabstractbutton_click

        subroutine qtf_qabstractbutton_toggle(b) bind(C, name='qtf_qabstractbutton_toggle')
            import :: c_ptr
            type(c_ptr), value :: b
        end subroutine qtf_qabstractbutton_toggle

        subroutine qtf_qpushbutton_setDefault(b, v) bind(C, name='qtf_qpushbutton_setDefault')
            import :: c_int, c_ptr
            type(c_ptr), value :: b
            integer(c_int), value :: v
        end subroutine qtf_qpushbutton_setDefault

        function qtf_qlineedit_new(s, len, parent) result(res) bind(C, name='qtf_qlineedit_new')
            import :: c_char, c_int, c_ptr
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qlineedit_new

        subroutine qtf_qlineedit_setText(e, s, len) bind(C, name='qtf_qlineedit_setText')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: e
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qlineedit_setText

        function qtf_qlineedit_text(e, len) result(res) bind(C, name='qtf_qlineedit_text')
            import :: c_int, c_ptr
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qlineedit_text

        subroutine qtf_qlineedit_setPlaceholderText(e, s, len) &
                bind(C, name='qtf_qlineedit_setPlaceholderText')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: e
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qlineedit_setPlaceholderText

        function qtf_qlineedit_placeholderText(e, len) result(res) &
                bind(C, name='qtf_qlineedit_placeholderText')
            import :: c_int, c_ptr
            type(c_ptr), value :: e
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qlineedit_placeholderText

        subroutine qtf_qlineedit_setReadOnly(e, b) bind(C, name='qtf_qlineedit_setReadOnly')
            import :: c_int, c_ptr
            type(c_ptr), value :: e
            integer(c_int), value :: b
        end subroutine qtf_qlineedit_setReadOnly

        function qtf_qlineedit_isReadOnly(e) result(res) bind(C, name='qtf_qlineedit_isReadOnly')
            import :: c_int, c_ptr
            type(c_ptr), value :: e
            integer(c_int) :: res
        end function qtf_qlineedit_isReadOnly

        subroutine qtf_qlineedit_setMaxLength(e, n) bind(C, name='qtf_qlineedit_setMaxLength')
            import :: c_int, c_ptr
            type(c_ptr), value :: e
            integer(c_int), value :: n
        end subroutine qtf_qlineedit_setMaxLength

        function qtf_qlineedit_maxLength(e) result(res) bind(C, name='qtf_qlineedit_maxLength')
            import :: c_int, c_ptr
            type(c_ptr), value :: e
            integer(c_int) :: res
        end function qtf_qlineedit_maxLength

        subroutine qtf_qlineedit_clear(e) bind(C, name='qtf_qlineedit_clear')
            import :: c_ptr
            type(c_ptr), value :: e
        end subroutine qtf_qlineedit_clear

        function qtf_qspinbox_new(parent) result(res) bind(C, name='qtf_qspinbox_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qspinbox_new

        subroutine qtf_qspinbox_setRange(s, lo, hi) bind(C, name='qtf_qspinbox_setRange')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int), value :: lo
            integer(c_int), value :: hi
        end subroutine qtf_qspinbox_setRange

        function qtf_qspinbox_minimum(s) result(res) bind(C, name='qtf_qspinbox_minimum')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int) :: res
        end function qtf_qspinbox_minimum

        function qtf_qspinbox_maximum(s) result(res) bind(C, name='qtf_qspinbox_maximum')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int) :: res
        end function qtf_qspinbox_maximum

        subroutine qtf_qspinbox_setValue(s, v) bind(C, name='qtf_qspinbox_setValue')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int), value :: v
        end subroutine qtf_qspinbox_setValue

        function qtf_qspinbox_value(s) result(res) bind(C, name='qtf_qspinbox_value')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int) :: res
        end function qtf_qspinbox_value

        subroutine qtf_qspinbox_setSingleStep(s, v) bind(C, name='qtf_qspinbox_setSingleStep')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int), value :: v
        end subroutine qtf_qspinbox_setSingleStep

        function qtf_qspinbox_singleStep(s) result(res) bind(C, name='qtf_qspinbox_singleStep')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int) :: res
        end function qtf_qspinbox_singleStep

        subroutine qtf_qspinbox_setPrefix(s, p, len) bind(C, name='qtf_qspinbox_setPrefix')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: s
            character(kind=c_char), dimension(*), intent(in) :: p
            integer(c_int), value :: len
        end subroutine qtf_qspinbox_setPrefix

        subroutine qtf_qspinbox_setSuffix(s, p, len) bind(C, name='qtf_qspinbox_setSuffix')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: s
            character(kind=c_char), dimension(*), intent(in) :: p
            integer(c_int), value :: len
        end subroutine qtf_qspinbox_setSuffix

        function qtf_qdoublespinbox_new(parent) result(res) bind(C, name='qtf_qdoublespinbox_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qdoublespinbox_new

        subroutine qtf_qdoublespinbox_setRange(s, lo, hi) bind(C, name='qtf_qdoublespinbox_setRange')
            import :: c_double, c_ptr
            type(c_ptr), value :: s
            real(c_double), value :: lo
            real(c_double), value :: hi
        end subroutine qtf_qdoublespinbox_setRange

        function qtf_qdoublespinbox_minimum(s) result(res) bind(C, name='qtf_qdoublespinbox_minimum')
            import :: c_double, c_ptr
            type(c_ptr), value :: s
            real(c_double) :: res
        end function qtf_qdoublespinbox_minimum

        function qtf_qdoublespinbox_maximum(s) result(res) bind(C, name='qtf_qdoublespinbox_maximum')
            import :: c_double, c_ptr
            type(c_ptr), value :: s
            real(c_double) :: res
        end function qtf_qdoublespinbox_maximum

        subroutine qtf_qdoublespinbox_setValue(s, v) bind(C, name='qtf_qdoublespinbox_setValue')
            import :: c_double, c_ptr
            type(c_ptr), value :: s
            real(c_double), value :: v
        end subroutine qtf_qdoublespinbox_setValue

        function qtf_qdoublespinbox_value(s) result(res) bind(C, name='qtf_qdoublespinbox_value')
            import :: c_double, c_ptr
            type(c_ptr), value :: s
            real(c_double) :: res
        end function qtf_qdoublespinbox_value

        subroutine qtf_qdoublespinbox_setSingleStep(s, v) bind(C, name='qtf_qdoublespinbox_setSingleStep')
            import :: c_double, c_ptr
            type(c_ptr), value :: s
            real(c_double), value :: v
        end subroutine qtf_qdoublespinbox_setSingleStep

        function qtf_qdoublespinbox_singleStep(s) result(res) bind(C, name='qtf_qdoublespinbox_singleStep')
            import :: c_double, c_ptr
            type(c_ptr), value :: s
            real(c_double) :: res
        end function qtf_qdoublespinbox_singleStep

        subroutine qtf_qdoublespinbox_setDecimals(s, n) bind(C, name='qtf_qdoublespinbox_setDecimals')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int), value :: n
        end subroutine qtf_qdoublespinbox_setDecimals

        function qtf_qdoublespinbox_decimals(s) result(res) bind(C, name='qtf_qdoublespinbox_decimals')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int) :: res
        end function qtf_qdoublespinbox_decimals

        subroutine qtf_qdoublespinbox_setPrefix(s, p, len) bind(C, name='qtf_qdoublespinbox_setPrefix')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: s
            character(kind=c_char), dimension(*), intent(in) :: p
            integer(c_int), value :: len
        end subroutine qtf_qdoublespinbox_setPrefix

        subroutine qtf_qdoublespinbox_setSuffix(s, p, len) bind(C, name='qtf_qdoublespinbox_setSuffix')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: s
            character(kind=c_char), dimension(*), intent(in) :: p
            integer(c_int), value :: len
        end subroutine qtf_qdoublespinbox_setSuffix

        function qtf_qslider_new(orientation, parent) result(res) bind(C, name='qtf_qslider_new')
            import :: c_int, c_ptr
            integer(c_int), value :: orientation
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qslider_new

        subroutine qtf_qabstractslider_setRange(s, lo, hi) bind(C, name='qtf_qabstractslider_setRange')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int), value :: lo
            integer(c_int), value :: hi
        end subroutine qtf_qabstractslider_setRange

        function qtf_qabstractslider_minimum(s) result(res) bind(C, name='qtf_qabstractslider_minimum')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int) :: res
        end function qtf_qabstractslider_minimum

        function qtf_qabstractslider_maximum(s) result(res) bind(C, name='qtf_qabstractslider_maximum')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int) :: res
        end function qtf_qabstractslider_maximum

        subroutine qtf_qabstractslider_setValue(s, v) bind(C, name='qtf_qabstractslider_setValue')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int), value :: v
        end subroutine qtf_qabstractslider_setValue

        function qtf_qabstractslider_value(s) result(res) bind(C, name='qtf_qabstractslider_value')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int) :: res
        end function qtf_qabstractslider_value

        subroutine qtf_qabstractslider_setSingleStep(s, v) bind(C, name='qtf_qabstractslider_setSingleStep')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int), value :: v
        end subroutine qtf_qabstractslider_setSingleStep

        subroutine qtf_qabstractslider_setPageStep(s, v) bind(C, name='qtf_qabstractslider_setPageStep')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int), value :: v
        end subroutine qtf_qabstractslider_setPageStep

        subroutine qtf_qabstractslider_setOrientation(s, o) bind(C, name='qtf_qabstractslider_setOrientation')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int), value :: o
        end subroutine qtf_qabstractslider_setOrientation

        function qtf_qabstractslider_orientation(s) result(res) &
                bind(C, name='qtf_qabstractslider_orientation')
            import :: c_int, c_ptr
            type(c_ptr), value :: s
            integer(c_int) :: res
        end function qtf_qabstractslider_orientation

        function qtf_qcombobox_new(parent) result(res) bind(C, name='qtf_qcombobox_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qcombobox_new

        subroutine qtf_qcombobox_addItem(c, s, len) bind(C, name='qtf_qcombobox_addItem')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: c
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qcombobox_addItem

        subroutine qtf_qcombobox_insertItem(c, index, s, len) bind(C, name='qtf_qcombobox_insertItem')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: c
            integer(c_int), value :: index
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qcombobox_insertItem

        subroutine qtf_qcombobox_removeItem(c, index) bind(C, name='qtf_qcombobox_removeItem')
            import :: c_int, c_ptr
            type(c_ptr), value :: c
            integer(c_int), value :: index
        end subroutine qtf_qcombobox_removeItem

        subroutine qtf_qcombobox_clear(c) bind(C, name='qtf_qcombobox_clear')
            import :: c_ptr
            type(c_ptr), value :: c
        end subroutine qtf_qcombobox_clear

        function qtf_qcombobox_count(c) result(res) bind(C, name='qtf_qcombobox_count')
            import :: c_int, c_ptr
            type(c_ptr), value :: c
            integer(c_int) :: res
        end function qtf_qcombobox_count

        function qtf_qcombobox_currentIndex(c) result(res) bind(C, name='qtf_qcombobox_currentIndex')
            import :: c_int, c_ptr
            type(c_ptr), value :: c
            integer(c_int) :: res
        end function qtf_qcombobox_currentIndex

        subroutine qtf_qcombobox_setCurrentIndex(c, index) bind(C, name='qtf_qcombobox_setCurrentIndex')
            import :: c_int, c_ptr
            type(c_ptr), value :: c
            integer(c_int), value :: index
        end subroutine qtf_qcombobox_setCurrentIndex

        function qtf_qcombobox_currentText(c, len) result(res) bind(C, name='qtf_qcombobox_currentText')
            import :: c_int, c_ptr
            type(c_ptr), value :: c
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qcombobox_currentText

        subroutine qtf_qcombobox_setCurrentText(c, s, len) bind(C, name='qtf_qcombobox_setCurrentText')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: c
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qcombobox_setCurrentText

        function qtf_qcombobox_itemText(c, index, len) result(res) bind(C, name='qtf_qcombobox_itemText')
            import :: c_int, c_ptr
            type(c_ptr), value :: c
            integer(c_int), value :: index
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qcombobox_itemText

        function qtf_qcombobox_findText(c, s, len) result(res) bind(C, name='qtf_qcombobox_findText')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: c
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
            integer(c_int) :: res
        end function qtf_qcombobox_findText

        subroutine qtf_qcombobox_setEditable(c, b) bind(C, name='qtf_qcombobox_setEditable')
            import :: c_int, c_ptr
            type(c_ptr), value :: c
            integer(c_int), value :: b
        end subroutine qtf_qcombobox_setEditable

        subroutine qtf_qlayout_setContentsMargins(l, left, top, right, bottom) &
                bind(C, name='qtf_qlayout_setContentsMargins')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int), value :: left
            integer(c_int), value :: top
            integer(c_int), value :: right
            integer(c_int), value :: bottom
        end subroutine qtf_qlayout_setContentsMargins

        subroutine qtf_qlayout_setSpacing(l, s) bind(C, name='qtf_qlayout_setSpacing')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int), value :: s
        end subroutine qtf_qlayout_setSpacing

        function qtf_qlayout_spacing(l) result(res) bind(C, name='qtf_qlayout_spacing')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int) :: res
        end function qtf_qlayout_spacing

        function qtf_qlayout_count(l) result(res) bind(C, name='qtf_qlayout_count')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int) :: res
        end function qtf_qlayout_count

        function qtf_qvboxlayout_new(parent) result(res) bind(C, name='qtf_qvboxlayout_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qvboxlayout_new

        function qtf_qhboxlayout_new(parent) result(res) bind(C, name='qtf_qhboxlayout_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qhboxlayout_new

        subroutine qtf_qboxlayout_addWidget(l, w, stretch, alignment) bind(C, name='qtf_qboxlayout_addWidget')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            type(c_ptr), value :: w
            integer(c_int), value :: stretch
            integer(c_int), value :: alignment
        end subroutine qtf_qboxlayout_addWidget

        subroutine qtf_qboxlayout_addLayout(l, child, stretch) bind(C, name='qtf_qboxlayout_addLayout')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            type(c_ptr), value :: child
            integer(c_int), value :: stretch
        end subroutine qtf_qboxlayout_addLayout

        subroutine qtf_qboxlayout_addStretch(l, stretch) bind(C, name='qtf_qboxlayout_addStretch')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int), value :: stretch
        end subroutine qtf_qboxlayout_addStretch

        subroutine qtf_qboxlayout_addSpacing(l, size) bind(C, name='qtf_qboxlayout_addSpacing')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int), value :: size
        end subroutine qtf_qboxlayout_addSpacing

        function qtf_qgridlayout_new(parent) result(res) bind(C, name='qtf_qgridlayout_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qgridlayout_new

        subroutine qtf_qgridlayout_addWidget(l, w, row, col, rowSpan, colSpan, alignment) &
                bind(C, name='qtf_qgridlayout_addWidget')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            type(c_ptr), value :: w
            integer(c_int), value :: row
            integer(c_int), value :: col
            integer(c_int), value :: rowSpan
            integer(c_int), value :: colSpan
            integer(c_int), value :: alignment
        end subroutine qtf_qgridlayout_addWidget

        subroutine qtf_qgridlayout_addLayout(l, child, row, col, rowSpan, colSpan, alignment) &
                bind(C, name='qtf_qgridlayout_addLayout')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            type(c_ptr), value :: child
            integer(c_int), value :: row
            integer(c_int), value :: col
            integer(c_int), value :: rowSpan
            integer(c_int), value :: colSpan
            integer(c_int), value :: alignment
        end subroutine qtf_qgridlayout_addLayout

        subroutine qtf_qgridlayout_setRowStretch(l, row, stretch) &
                bind(C, name='qtf_qgridlayout_setRowStretch')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int), value :: row
            integer(c_int), value :: stretch
        end subroutine qtf_qgridlayout_setRowStretch

        subroutine qtf_qgridlayout_setColumnStretch(l, col, stretch) &
                bind(C, name='qtf_qgridlayout_setColumnStretch')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int), value :: col
            integer(c_int), value :: stretch
        end subroutine qtf_qgridlayout_setColumnStretch

        function qtf_qgridlayout_rowCount(l) result(res) bind(C, name='qtf_qgridlayout_rowCount')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int) :: res
        end function qtf_qgridlayout_rowCount

        function qtf_qgridlayout_columnCount(l) result(res) bind(C, name='qtf_qgridlayout_columnCount')
            import :: c_int, c_ptr
            type(c_ptr), value :: l
            integer(c_int) :: res
        end function qtf_qgridlayout_columnCount

        function qtf_qmainwindow_new(parent) result(res) bind(C, name='qtf_qmainwindow_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qmainwindow_new

        subroutine qtf_qmainwindow_setCentralWidget(m, w) bind(C, name='qtf_qmainwindow_setCentralWidget')
            import :: c_ptr
            type(c_ptr), value :: m
            type(c_ptr), value :: w
        end subroutine qtf_qmainwindow_setCentralWidget

        function qtf_qmainwindow_centralWidget(m) result(res) bind(C, name='qtf_qmainwindow_centralWidget')
            import :: c_ptr
            type(c_ptr), value :: m
            type(c_ptr) :: res
        end function qtf_qmainwindow_centralWidget

        function qtf_qmainwindow_statusBar(m) result(res) bind(C, name='qtf_qmainwindow_statusBar')
            import :: c_ptr
            type(c_ptr), value :: m
            type(c_ptr) :: res
        end function qtf_qmainwindow_statusBar

        subroutine qtf_qstatusbar_showMessage(b, s, len, timeout) bind(C, name='qtf_qstatusbar_showMessage')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: b
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
            integer(c_int), value :: timeout
        end subroutine qtf_qstatusbar_showMessage

        subroutine qtf_qstatusbar_clearMessage(b) bind(C, name='qtf_qstatusbar_clearMessage')
            import :: c_ptr
            type(c_ptr), value :: b
        end subroutine qtf_qstatusbar_clearMessage

        function qtf_qstatusbar_currentMessage(b, len) result(res) &
                bind(C, name='qtf_qstatusbar_currentMessage')
            import :: c_int, c_ptr
            type(c_ptr), value :: b
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qstatusbar_currentMessage

        function qtf_qdialog_new(parent) result(res) bind(C, name='qtf_qdialog_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qdialog_new

        function qtf_qdialog_exec(d) result(res) bind(C, name='qtf_qdialog_exec')
            import :: c_int, c_ptr
            type(c_ptr), value :: d
            integer(c_int) :: res
        end function qtf_qdialog_exec

        subroutine qtf_qdialog_open(d) bind(C, name='qtf_qdialog_open')
            import :: c_ptr
            type(c_ptr), value :: d
        end subroutine qtf_qdialog_open

        subroutine qtf_qdialog_accept(d) bind(C, name='qtf_qdialog_accept')
            import :: c_ptr
            type(c_ptr), value :: d
        end subroutine qtf_qdialog_accept

        subroutine qtf_qdialog_reject(d) bind(C, name='qtf_qdialog_reject')
            import :: c_ptr
            type(c_ptr), value :: d
        end subroutine qtf_qdialog_reject

        subroutine qtf_qdialog_done(d, r) bind(C, name='qtf_qdialog_done')
            import :: c_int, c_ptr
            type(c_ptr), value :: d
            integer(c_int), value :: r
        end subroutine qtf_qdialog_done

        function qtf_qdialog_result(d) result(res) bind(C, name='qtf_qdialog_result')
            import :: c_int, c_ptr
            type(c_ptr), value :: d
            integer(c_int) :: res
        end function qtf_qdialog_result

        subroutine qtf_qdialog_setModal(d, b) bind(C, name='qtf_qdialog_setModal')
            import :: c_int, c_ptr
            type(c_ptr), value :: d
            integer(c_int), value :: b
        end subroutine qtf_qdialog_setModal

        function qtf_qmessagebox_new(parent) result(res) bind(C, name='qtf_qmessagebox_new')
            import :: c_ptr
            type(c_ptr), value :: parent
            type(c_ptr) :: res
        end function qtf_qmessagebox_new

        subroutine qtf_qmessagebox_setText(m, s, len) bind(C, name='qtf_qmessagebox_setText')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: m
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qmessagebox_setText

        function qtf_qmessagebox_text(m, len) result(res) bind(C, name='qtf_qmessagebox_text')
            import :: c_int, c_ptr
            type(c_ptr), value :: m
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qmessagebox_text

        subroutine qtf_qmessagebox_setInformativeText(m, s, len) &
                bind(C, name='qtf_qmessagebox_setInformativeText')
            import :: c_char, c_int, c_ptr
            type(c_ptr), value :: m
            character(kind=c_char), dimension(*), intent(in) :: s
            integer(c_int), value :: len
        end subroutine qtf_qmessagebox_setInformativeText

        function qtf_qmessagebox_informativeText(m, len) result(res) &
                bind(C, name='qtf_qmessagebox_informativeText')
            import :: c_int, c_ptr
            type(c_ptr), value :: m
            integer(c_int), intent(out) :: len
            type(c_ptr) :: res
        end function qtf_qmessagebox_informativeText

        subroutine qtf_qmessagebox_setIcon(m, icon) bind(C, name='qtf_qmessagebox_setIcon')
            import :: c_int, c_ptr
            type(c_ptr), value :: m
            integer(c_int), value :: icon
        end subroutine qtf_qmessagebox_setIcon

        subroutine qtf_qmessagebox_setStandardButtons(m, buttons) &
                bind(C, name='qtf_qmessagebox_setStandardButtons')
            import :: c_int, c_ptr
            type(c_ptr), value :: m
            integer(c_int), value :: buttons
        end subroutine qtf_qmessagebox_setStandardButtons

        subroutine qtf_qmessagebox_setDefaultButton(m, which) bind(C, name='qtf_qmessagebox_setDefaultButton')
            import :: c_int, c_ptr
            type(c_ptr), value :: m
            integer(c_int), value :: which
        end subroutine qtf_qmessagebox_setDefaultButton

        function qtf_qmessagebox_button(m, which) result(res) bind(C, name='qtf_qmessagebox_button')
            import :: c_int, c_ptr
            type(c_ptr), value :: m
            integer(c_int), value :: which
            type(c_ptr) :: res
        end function qtf_qmessagebox_button

        function qtf_qmessagebox_static(which, parent, title, tlen, text, len, buttons, defaultButton) result(res) &
                bind(C, name='qtf_qmessagebox_static')
            import :: c_char, c_int, c_ptr
            integer(c_int), value :: which
            type(c_ptr), value :: parent
            character(kind=c_char), dimension(*), intent(in) :: title
            integer(c_int), value :: tlen
            character(kind=c_char), dimension(*), intent(in) :: text
            integer(c_int), value :: len
            integer(c_int), value :: buttons
            integer(c_int), value :: defaultButton
            integer(c_int) :: res
        end function qtf_qmessagebox_static

    end interface

    public :: qtf_qapplication_new, qtf_qapplication_exec, qtf_qapplication_quit
    public :: qtf_qapplication_processEvents, qtf_qapplication_activeModalWidget, qtf_qwidget_new
    public :: qtf_qwidget_show, qtf_qwidget_hide, qtf_qwidget_close, qtf_qwidget_setVisible
    public :: qtf_qwidget_isVisible, qtf_qwidget_setEnabled, qtf_qwidget_isEnabled, qtf_qwidget_resize
    public :: qtf_qwidget_width, qtf_qwidget_height, qtf_qwidget_setMinimumSize, qtf_qwidget_setFixedSize
    public :: qtf_qwidget_setWindowTitle, qtf_qwidget_windowTitle, qtf_qwidget_setToolTip
    public :: qtf_qwidget_toolTip, qtf_qwidget_setStyleSheet, qtf_qwidget_setFocus, qtf_qwidget_setLayout
    public :: qtf_qwidget_layout, qtf_qlabel_new, qtf_qlabel_setText, qtf_qlabel_text
    public :: qtf_qlabel_setAlignment, qtf_qlabel_setWordWrap, qtf_qpushbutton_new, qtf_qcheckbox_new
    public :: qtf_qradiobutton_new, qtf_qabstractbutton_setText, qtf_qabstractbutton_text
    public :: qtf_qabstractbutton_setCheckable, qtf_qabstractbutton_isCheckable
    public :: qtf_qabstractbutton_setChecked, qtf_qabstractbutton_isChecked, qtf_qabstractbutton_click
    public :: qtf_qabstractbutton_toggle, qtf_qpushbutton_setDefault, qtf_qlineedit_new
    public :: qtf_qlineedit_setText, qtf_qlineedit_text, qtf_qlineedit_setPlaceholderText
    public :: qtf_qlineedit_placeholderText, qtf_qlineedit_setReadOnly, qtf_qlineedit_isReadOnly
    public :: qtf_qlineedit_setMaxLength, qtf_qlineedit_maxLength, qtf_qlineedit_clear, qtf_qspinbox_new
    public :: qtf_qspinbox_setRange, qtf_qspinbox_minimum, qtf_qspinbox_maximum, qtf_qspinbox_setValue
    public :: qtf_qspinbox_value, qtf_qspinbox_setSingleStep, qtf_qspinbox_singleStep, qtf_qspinbox_setPrefix
    public :: qtf_qspinbox_setSuffix, qtf_qdoublespinbox_new, qtf_qdoublespinbox_setRange
    public :: qtf_qdoublespinbox_minimum, qtf_qdoublespinbox_maximum, qtf_qdoublespinbox_setValue
    public :: qtf_qdoublespinbox_value, qtf_qdoublespinbox_setSingleStep, qtf_qdoublespinbox_singleStep
    public :: qtf_qdoublespinbox_setDecimals, qtf_qdoublespinbox_decimals, qtf_qdoublespinbox_setPrefix
    public :: qtf_qdoublespinbox_setSuffix, qtf_qslider_new, qtf_qabstractslider_setRange
    public :: qtf_qabstractslider_minimum, qtf_qabstractslider_maximum, qtf_qabstractslider_setValue
    public :: qtf_qabstractslider_value, qtf_qabstractslider_setSingleStep, qtf_qabstractslider_setPageStep
    public :: qtf_qabstractslider_setOrientation, qtf_qabstractslider_orientation, qtf_qcombobox_new
    public :: qtf_qcombobox_addItem, qtf_qcombobox_insertItem, qtf_qcombobox_removeItem, qtf_qcombobox_clear
    public :: qtf_qcombobox_count, qtf_qcombobox_currentIndex, qtf_qcombobox_setCurrentIndex
    public :: qtf_qcombobox_currentText, qtf_qcombobox_setCurrentText, qtf_qcombobox_itemText
    public :: qtf_qcombobox_findText, qtf_qcombobox_setEditable, qtf_qlayout_setContentsMargins
    public :: qtf_qlayout_setSpacing, qtf_qlayout_spacing, qtf_qlayout_count, qtf_qvboxlayout_new
    public :: qtf_qhboxlayout_new, qtf_qboxlayout_addWidget, qtf_qboxlayout_addLayout
    public :: qtf_qboxlayout_addStretch, qtf_qboxlayout_addSpacing, qtf_qgridlayout_new
    public :: qtf_qgridlayout_addWidget, qtf_qgridlayout_addLayout, qtf_qgridlayout_setRowStretch
    public :: qtf_qgridlayout_setColumnStretch, qtf_qgridlayout_rowCount, qtf_qgridlayout_columnCount
    public :: qtf_qmainwindow_new, qtf_qmainwindow_setCentralWidget, qtf_qmainwindow_centralWidget
    public :: qtf_qmainwindow_statusBar, qtf_qstatusbar_showMessage, qtf_qstatusbar_clearMessage
    public :: qtf_qstatusbar_currentMessage, qtf_qdialog_new, qtf_qdialog_exec, qtf_qdialog_open
    public :: qtf_qdialog_accept, qtf_qdialog_reject, qtf_qdialog_done, qtf_qdialog_result
    public :: qtf_qdialog_setModal, qtf_qmessagebox_new, qtf_qmessagebox_setText, qtf_qmessagebox_text
    public :: qtf_qmessagebox_setInformativeText, qtf_qmessagebox_informativeText, qtf_qmessagebox_setIcon
    public :: qtf_qmessagebox_setStandardButtons, qtf_qmessagebox_setDefaultButton, qtf_qmessagebox_button
    public :: qtf_qmessagebox_static

end module qt_c_widgets
