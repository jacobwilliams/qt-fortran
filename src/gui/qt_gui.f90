!> Qt Gui: colors, pens, brushes, fonts, painting, images, input events, actions.
!>
!> QColor, QPen, QBrush and QFont are Fortran value types (as in Qt, where they
!> are values too): build them with structure constructors, e.g.
!> `QPen(Qt_red, 2.0_c_double)`. Images, pixmaps and painters created from
!> Fortran hold C++ objects and must be released with `delete` / `end`.
module qt_gui

    use iso_c_binding
    use qt_c_util
    use qt_c_gui
    use qt_core
    implicit none
    private

    ! Qt::PenStyle
    integer(c_int), parameter, public :: Qt_NoPen          = 0
    integer(c_int), parameter, public :: Qt_SolidLine      = 1
    integer(c_int), parameter, public :: Qt_DashLine       = 2
    integer(c_int), parameter, public :: Qt_DotLine        = 3
    integer(c_int), parameter, public :: Qt_DashDotLine    = 4
    integer(c_int), parameter, public :: Qt_DashDotDotLine = 5

    ! Qt::BrushStyle (subset)
    integer(c_int), parameter, public :: Qt_NoBrush      = 0
    integer(c_int), parameter, public :: Qt_SolidPattern = 1

    ! QPainter::RenderHint
    integer(c_int), parameter, public :: QPainter_Antialiasing          = 1
    integer(c_int), parameter, public :: QPainter_TextAntialiasing      = 2
    integer(c_int), parameter, public :: QPainter_SmoothPixmapTransform = 4

    ! Qt::MouseButton
    integer(c_int), parameter, public :: Qt_NoButton     = 0
    integer(c_int), parameter, public :: Qt_LeftButton   = 1
    integer(c_int), parameter, public :: Qt_RightButton  = 2
    integer(c_int), parameter, public :: Qt_MiddleButton = 4

    ! Qt::KeyboardModifier
    integer(c_int), parameter, public :: Qt_NoModifier      = 0
    integer(c_int), parameter, public :: Qt_ShiftModifier   = int(z'02000000', c_int)
    integer(c_int), parameter, public :: Qt_ControlModifier = int(z'04000000', c_int)
    integer(c_int), parameter, public :: Qt_AltModifier     = int(z'08000000', c_int)
    integer(c_int), parameter, public :: Qt_MetaModifier    = int(z'10000000', c_int)
    integer(c_int), parameter, public :: Qt_KeypadModifier  = int(z'20000000', c_int)

    ! Qt::Key (subset)
    integer(c_int), parameter, public :: Qt_Key_Escape    = int(z'01000000', c_int)
    integer(c_int), parameter, public :: Qt_Key_Tab       = int(z'01000001', c_int)
    integer(c_int), parameter, public :: Qt_Key_Backspace = int(z'01000003', c_int)
    integer(c_int), parameter, public :: Qt_Key_Return    = int(z'01000004', c_int)
    integer(c_int), parameter, public :: Qt_Key_Enter     = int(z'01000005', c_int)
    integer(c_int), parameter, public :: Qt_Key_Delete    = int(z'01000007', c_int)
    integer(c_int), parameter, public :: Qt_Key_Home      = int(z'01000010', c_int)
    integer(c_int), parameter, public :: Qt_Key_End       = int(z'01000011', c_int)
    integer(c_int), parameter, public :: Qt_Key_Left      = int(z'01000012', c_int)
    integer(c_int), parameter, public :: Qt_Key_Up        = int(z'01000013', c_int)
    integer(c_int), parameter, public :: Qt_Key_Right     = int(z'01000014', c_int)
    integer(c_int), parameter, public :: Qt_Key_Down      = int(z'01000015', c_int)
    integer(c_int), parameter, public :: Qt_Key_PageUp    = int(z'01000016', c_int)
    integer(c_int), parameter, public :: Qt_Key_PageDown  = int(z'01000017', c_int)
    integer(c_int), parameter, public :: Qt_Key_Space     = 32
    integer(c_int), parameter, public :: Qt_Key_Plus      = 43
    integer(c_int), parameter, public :: Qt_Key_Minus     = 45
    integer(c_int), parameter, public :: Qt_Key_A = 65
    integer(c_int), parameter, public :: Qt_Key_B = 66
    integer(c_int), parameter, public :: Qt_Key_C = 67
    integer(c_int), parameter, public :: Qt_Key_D = 68
    integer(c_int), parameter, public :: Qt_Key_E = 69
    integer(c_int), parameter, public :: Qt_Key_F = 70
    integer(c_int), parameter, public :: Qt_Key_G = 71
    integer(c_int), parameter, public :: Qt_Key_H = 72
    integer(c_int), parameter, public :: Qt_Key_I = 73
    integer(c_int), parameter, public :: Qt_Key_J = 74
    integer(c_int), parameter, public :: Qt_Key_K = 75
    integer(c_int), parameter, public :: Qt_Key_L = 76
    integer(c_int), parameter, public :: Qt_Key_M = 77
    integer(c_int), parameter, public :: Qt_Key_N = 78
    integer(c_int), parameter, public :: Qt_Key_O = 79
    integer(c_int), parameter, public :: Qt_Key_P = 80
    integer(c_int), parameter, public :: Qt_Key_Q = 81
    integer(c_int), parameter, public :: Qt_Key_R = 82
    integer(c_int), parameter, public :: Qt_Key_S = 83
    integer(c_int), parameter, public :: Qt_Key_T = 84
    integer(c_int), parameter, public :: Qt_Key_U = 85
    integer(c_int), parameter, public :: Qt_Key_V = 86
    integer(c_int), parameter, public :: Qt_Key_W = 87
    integer(c_int), parameter, public :: Qt_Key_X = 88
    integer(c_int), parameter, public :: Qt_Key_Y = 89
    integer(c_int), parameter, public :: Qt_Key_Z = 90
    integer(c_int), parameter, public :: Qt_Key_0 = 48
    integer(c_int), parameter, public :: Qt_Key_1 = 49
    integer(c_int), parameter, public :: Qt_Key_2 = 50
    integer(c_int), parameter, public :: Qt_Key_3 = 51
    integer(c_int), parameter, public :: Qt_Key_4 = 52
    integer(c_int), parameter, public :: Qt_Key_5 = 53
    integer(c_int), parameter, public :: Qt_Key_6 = 54
    integer(c_int), parameter, public :: Qt_Key_7 = 55
    integer(c_int), parameter, public :: Qt_Key_8 = 56
    integer(c_int), parameter, public :: Qt_Key_9 = 57
    integer(c_int), parameter, public :: Qt_Key_F1 = int(z'01000030', c_int)
    integer(c_int), parameter, public :: Qt_Key_F2 = int(z'01000031', c_int)
    integer(c_int), parameter, public :: Qt_Key_F3 = int(z'01000032', c_int)
    integer(c_int), parameter, public :: Qt_Key_F4 = int(z'01000033', c_int)
    integer(c_int), parameter, public :: Qt_Key_F5 = int(z'01000034', c_int)
    integer(c_int), parameter, public :: Qt_Key_F6 = int(z'01000035', c_int)
    integer(c_int), parameter, public :: Qt_Key_F7 = int(z'01000036', c_int)
    integer(c_int), parameter, public :: Qt_Key_F8 = int(z'01000037', c_int)
    integer(c_int), parameter, public :: Qt_Key_F9 = int(z'01000038', c_int)
    integer(c_int), parameter, public :: Qt_Key_F10 = int(z'01000039', c_int)
    integer(c_int), parameter, public :: Qt_Key_F11 = int(z'0100003A', c_int)
    integer(c_int), parameter, public :: Qt_Key_F12 = int(z'0100003B', c_int)

    ! ------------------------------------------------------------------
    ! value types

    !> An RGBA color, components 0..255.
    type, public :: QColor
        integer :: r = 0
        integer :: g = 0
        integer :: b = 0
        integer :: a = 255
        logical :: valid = .true.
    contains
        procedure :: red => qcolor_red
        procedure :: green => qcolor_green
        procedure :: blue => qcolor_blue
        procedure :: alpha => qcolor_alpha
        procedure :: isValid => qcolor_isValid
        procedure :: name => qcolor_name
    end type QColor
    !> `QColor(r, g, b [, a])` is the structure constructor;
    !> `QColor('steelblue')` / `QColor('#4682b4')` parses a color name.
    interface QColor
        module procedure :: qcolor_fromString
    end interface QColor

    interface operator(==)
        module procedure :: qcolor_eq
    end interface operator(==)
    interface operator(/=)
        module procedure :: qcolor_ne
    end interface operator(/=)
    public :: operator(==), operator(/=)

    ! Qt::GlobalColor
    type(QColor), parameter, public :: Qt_white       = QColor(255, 255, 255)
    type(QColor), parameter, public :: Qt_black       = QColor(0, 0, 0)
    type(QColor), parameter, public :: Qt_red         = QColor(255, 0, 0)
    type(QColor), parameter, public :: Qt_darkRed     = QColor(128, 0, 0)
    type(QColor), parameter, public :: Qt_green       = QColor(0, 255, 0)
    type(QColor), parameter, public :: Qt_darkGreen   = QColor(0, 128, 0)
    type(QColor), parameter, public :: Qt_blue        = QColor(0, 0, 255)
    type(QColor), parameter, public :: Qt_darkBlue    = QColor(0, 0, 128)
    type(QColor), parameter, public :: Qt_cyan        = QColor(0, 255, 255)
    type(QColor), parameter, public :: Qt_darkCyan    = QColor(0, 128, 128)
    type(QColor), parameter, public :: Qt_magenta     = QColor(255, 0, 255)
    type(QColor), parameter, public :: Qt_darkMagenta = QColor(128, 0, 128)
    type(QColor), parameter, public :: Qt_yellow      = QColor(255, 255, 0)
    type(QColor), parameter, public :: Qt_darkYellow  = QColor(128, 128, 0)
    type(QColor), parameter, public :: Qt_gray        = QColor(160, 160, 164)
    type(QColor), parameter, public :: Qt_darkGray    = QColor(128, 128, 128)
    type(QColor), parameter, public :: Qt_lightGray   = QColor(192, 192, 192)
    type(QColor), parameter, public :: Qt_transparent = QColor(0, 0, 0, 0)

    !> Line drawing settings: `QPen(color [, width [, style]])`.
    type, public :: QPen
        type(QColor) :: color = QColor(0, 0, 0)
        real(c_double) :: width = 1.0_c_double
        integer :: style = Qt_SolidLine
    end type QPen

    !> Fill settings: `QBrush(color [, style])`.
    type, public :: QBrush
        type(QColor) :: color = QColor(0, 0, 0)
        integer :: style = Qt_SolidPattern
    end type QBrush

    !> Font settings: `QFont(family [, pointSize [, bold [, italic]]])`.
    !> An empty family or pointSize <= 0 keeps the painter's current value.
    type, public :: QFont
        character(len=:), allocatable :: family
        real(c_double) :: pointSize = -1.0_c_double
        logical :: bold = .false.
        logical :: italic = .false.
    end type QFont

    ! ------------------------------------------------------------------
    ! images

    type, public :: QImage
        type(c_ptr) :: ptr = c_null_ptr
    contains
        procedure :: delete => qimage_delete
        procedure :: isNull => qimage_isNull
        procedure :: width => qimage_width
        procedure :: height => qimage_height
        procedure :: fill => qimage_fill
        procedure :: pixelColor => qimage_pixelColor
        procedure :: setPixelColor => qimage_setPixelColor
        procedure :: save => qimage_save
    end type QImage
    !> `QImage(width, height)` (ARGB32, uninitialized) or `QImage(fileName)`.
    interface QImage
        module procedure :: qimage_new, qimage_fromFile
    end interface QImage

    type, public :: QPixmap
        type(c_ptr) :: ptr = c_null_ptr
    contains
        procedure :: delete => qpixmap_delete
        procedure :: isNull => qpixmap_isNull
        procedure :: width => qpixmap_width
        procedure :: height => qpixmap_height
        procedure :: toImage => qpixmap_toImage
        procedure :: save => qpixmap_save
    end type QPixmap

    ! ------------------------------------------------------------------
    ! QPainter

    !> Draws on an image, or on a QtfWidget inside its paintEvent slot.
    !> Coordinates may be integers or `real(c_double)`.
    type, public :: QPainter
        type(c_ptr) :: ptr = c_null_ptr
        logical :: owned = .false.   !! created from Fortran: `end` deletes it
    contains
        procedure :: end => qpainter_end
        procedure :: isActive => qpainter_isActive
        procedure :: deviceWidth => qpainter_deviceWidth
        procedure :: deviceHeight => qpainter_deviceHeight
        procedure, private :: setPen_pen, setPen_color
        generic :: setPen => setPen_pen, setPen_color
        procedure, private :: setBrush_brush, setBrush_color
        generic :: setBrush => setBrush_brush, setBrush_color
        procedure :: setFont => qpainter_setFont
        procedure :: setRenderHint => qpainter_setRenderHint
        procedure :: setOpacity => qpainter_setOpacity
        procedure :: save => qpainter_save
        procedure :: restore => qpainter_restore
        procedure, private :: translate_d, translate_i
        generic :: translate => translate_d, translate_i
        procedure :: scale => qpainter_scale
        procedure :: rotate => qpainter_rotate
        procedure :: resetTransform => qpainter_resetTransform
        procedure, private :: drawPoint_d, drawPoint_i
        generic :: drawPoint => drawPoint_d, drawPoint_i
        procedure, private :: drawLine_d, drawLine_i
        generic :: drawLine => drawLine_d, drawLine_i
        procedure, private :: drawRect_d, drawRect_i
        generic :: drawRect => drawRect_d, drawRect_i
        procedure, private :: drawRoundedRect_d, drawRoundedRect_i
        generic :: drawRoundedRect => drawRoundedRect_d, drawRoundedRect_i
        procedure, private :: drawEllipse_d, drawEllipse_i
        generic :: drawEllipse => drawEllipse_d, drawEllipse_i
        procedure, private :: fillRect_d, fillRect_i
        generic :: fillRect => fillRect_d, fillRect_i
        procedure, private :: drawPolyline_d, drawPolyline_i
        generic :: drawPolyline => drawPolyline_d, drawPolyline_i
        procedure, private :: drawPolygon_d, drawPolygon_i
        generic :: drawPolygon => drawPolygon_d, drawPolygon_i
        procedure, private :: drawText_d, drawText_i, drawTextRect_d, drawTextRect_i
        generic :: drawText => drawText_d, drawText_i, drawTextRect_d, drawTextRect_i
        procedure :: drawImage => qpainter_drawImage
        procedure :: textWidth => qpainter_textWidth
        procedure :: fontHeight => qpainter_fontHeight
    end type QPainter
    !> `QPainter(image)`: paint on an image; call `end` when done.
    interface QPainter
        module procedure :: qpainter_new_image
    end interface QPainter

    ! ------------------------------------------------------------------
    ! input events

    type, extends(QEvent), public :: QMouseEvent
    contains
        procedure :: x => qmouseevent_x
        procedure :: y => qmouseevent_y
        procedure :: button => qmouseevent_button
        procedure :: buttons => qmouseevent_buttons
        procedure :: modifiers => qmouseevent_modifiers
    end type QMouseEvent
    interface QMouseEvent
        module procedure :: qmouseevent_new
    end interface QMouseEvent

    type, extends(QEvent), public :: QKeyEvent
    contains
        procedure :: key => qkeyevent_key
        procedure :: modifiers => qkeyevent_modifiers
        procedure :: text => qkeyevent_text
        procedure :: isAutoRepeat => qkeyevent_isAutoRepeat
    end type QKeyEvent
    interface QKeyEvent
        module procedure :: qkeyevent_new
    end interface QKeyEvent

    !> Wheel event; `angleDeltaY()` is +/-120 per standard wheel notch.
    type, extends(QEvent), public :: QWheelEvent
    contains
        procedure :: x => qwheelevent_x
        procedure :: y => qwheelevent_y
        procedure :: angleDeltaX => qwheelevent_angleDeltaX
        procedure :: angleDeltaY => qwheelevent_angleDeltaY
        procedure :: buttons => qwheelevent_buttons
        procedure :: modifiers => qwheelevent_modifiers
    end type QWheelEvent
    interface QWheelEvent
        module procedure :: qwheelevent_new
    end interface QWheelEvent

    type, extends(QEvent), public :: QResizeEvent
    contains
        procedure :: width => qresizeevent_width
        procedure :: height => qresizeevent_height
        procedure :: oldWidth => qresizeevent_oldWidth
        procedure :: oldHeight => qresizeevent_oldHeight
    end type QResizeEvent
    interface QResizeEvent
        module procedure :: qresizeevent_new
    end interface QResizeEvent

    ! ------------------------------------------------------------------
    ! event / painter signals (used by QtfWidget)

    abstract interface
        subroutine qt_slot_painter(painter, data)
            import :: QPainter
            type(QPainter), intent(inout) :: painter
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_painter
        subroutine qt_slot_mouse_event(event, data)
            import :: QMouseEvent
            type(QMouseEvent), intent(in) :: event
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_mouse_event
        subroutine qt_slot_key_event(event, data)
            import :: QKeyEvent
            type(QKeyEvent), intent(in) :: event
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_key_event
        subroutine qt_slot_wheel_event(event, data)
            import :: QWheelEvent
            type(QWheelEvent), intent(in) :: event
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_wheel_event
        subroutine qt_slot_resize_event(event, data)
            import :: QResizeEvent
            type(QResizeEvent), intent(in) :: event
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_resize_event
    end interface
    public :: qt_slot_painter, qt_slot_mouse_event, qt_slot_key_event
    public :: qt_slot_wheel_event, qt_slot_resize_event

    !> Paint request: slots receive an active painter (do not `end` it).
    type, public :: QSignalPainter
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignalpainter_connect
    end type QSignalPainter

    type, public :: QSignalMouseEvent
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignalmouseevent_connect
    end type QSignalMouseEvent

    type, public :: QSignalKeyEvent
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignalkeyevent_connect
    end type QSignalKeyEvent

    type, public :: QSignalWheelEvent
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignalwheelevent_connect
    end type QSignalWheelEvent

    type, public :: QSignalResizeEvent
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignalresizeevent_connect
    end type QSignalResizeEvent

    type, extends(qt_slot_handler) :: painter_handler
        procedure(qt_slot_painter), pointer, nopass :: f => null()
    contains
        procedure :: invoke => painter_handler_invoke
    end type painter_handler

    type, extends(qt_slot_handler) :: mouse_handler
        procedure(qt_slot_mouse_event), pointer, nopass :: f => null()
    contains
        procedure :: invoke => mouse_handler_invoke
    end type mouse_handler

    type, extends(qt_slot_handler) :: key_handler
        procedure(qt_slot_key_event), pointer, nopass :: f => null()
    contains
        procedure :: invoke => key_handler_invoke
    end type key_handler

    type, extends(qt_slot_handler) :: wheel_handler
        procedure(qt_slot_wheel_event), pointer, nopass :: f => null()
    contains
        procedure :: invoke => wheel_handler_invoke
    end type wheel_handler

    type, extends(qt_slot_handler) :: resize_handler
        procedure(qt_slot_resize_event), pointer, nopass :: f => null()
    contains
        procedure :: invoke => resize_handler_invoke
    end type resize_handler

    ! ------------------------------------------------------------------
    ! QAction

    !> A menu/toolbar command. `triggered` carries no argument; use `toggled`
    !> for checkable actions.
    type, extends(QObject), public :: QAction
        type(QSignal) :: triggered
        type(QSignalBool) :: toggled
    contains
        procedure :: attach => qaction_attach
        procedure :: setText => qaction_setText
        procedure :: text => qaction_text
        procedure :: setShortcut => qaction_setShortcut
        procedure :: shortcut => qaction_shortcut
        procedure :: setCheckable => qaction_setCheckable
        procedure :: isCheckable => qaction_isCheckable
        procedure :: setChecked => qaction_setChecked
        procedure :: isChecked => qaction_isChecked
        procedure :: setEnabled => qaction_setEnabled
        procedure :: isEnabled => qaction_isEnabled
        procedure :: setStatusTip => qaction_setStatusTip
        procedure :: setToolTip => qaction_setToolTip
        procedure :: trigger => qaction_trigger
    end type QAction
    interface QAction
        module procedure :: qaction_new
    end interface QAction

contains

    ! ------------------------------------------------------------------
    ! QColor

    function qcolor_fromString(name) result(c)
        character(len=*), intent(in) :: name
        type(QColor) :: c
        integer(c_int) :: r, g, b, a
        c%valid = qtf_logical(qtf_qcolor_fromString(name, len(name, c_int), r, g, b, a))
        c%r = r
        c%g = g
        c%b = b
        c%a = a
    end function qcolor_fromString

    integer function qcolor_red(self)
        class(QColor), intent(in) :: self
        qcolor_red = self%r
    end function qcolor_red

    integer function qcolor_green(self)
        class(QColor), intent(in) :: self
        qcolor_green = self%g
    end function qcolor_green

    integer function qcolor_blue(self)
        class(QColor), intent(in) :: self
        qcolor_blue = self%b
    end function qcolor_blue

    integer function qcolor_alpha(self)
        class(QColor), intent(in) :: self
        qcolor_alpha = self%a
    end function qcolor_alpha

    logical function qcolor_isValid(self)
        class(QColor), intent(in) :: self
        qcolor_isValid = self%valid
    end function qcolor_isValid

    !> "#rrggbb" (lower case, alpha ignored), as QColor::name().
    function qcolor_name(self) result(name)
        class(QColor), intent(in) :: self
        character(len=7) :: name
        write(name, '(A,3Z2.2)') '#', self%r, self%g, self%b
        name = lower(name)
    end function qcolor_name

    pure function lower(s) result(t)
        character(len=*), intent(in) :: s
        character(len=len(s)) :: t
        integer :: i
        t = s
        do i = 1, len(s)
            if (s(i:i) >= 'A' .and. s(i:i) <= 'Z') t(i:i) = achar(iachar(s(i:i)) + 32)
        end do
    end function lower

    elemental logical function qcolor_eq(c1, c2)
        type(QColor), intent(in) :: c1, c2
        qcolor_eq = c1%r == c2%r .and. c1%g == c2%g .and. c1%b == c2%b .and. c1%a == c2%a &
                    .and. (c1%valid .eqv. c2%valid)
    end function qcolor_eq

    elemental logical function qcolor_ne(c1, c2)
        type(QColor), intent(in) :: c1, c2
        qcolor_ne = .not. qcolor_eq(c1, c2)
    end function qcolor_ne

    ! ------------------------------------------------------------------
    ! QImage, QPixmap

    function qimage_new(width, height) result(img)
        integer, intent(in) :: width, height
        type(QImage) :: img
        img%ptr = qtf_qimage_new(int(width, c_int), int(height, c_int))
    end function qimage_new

    !> Load an image file; check `isNull()` for failure.
    function qimage_fromFile(fileName) result(img)
        character(len=*), intent(in) :: fileName
        type(QImage) :: img
        img%ptr = qtf_qimage_fromFile(fileName, len(fileName, c_int))
    end function qimage_fromFile

    subroutine qimage_delete(self)
        class(QImage), intent(inout) :: self
        if (c_associated(self%ptr)) call qtf_qimage_delete(self%ptr)
        self%ptr = c_null_ptr
    end subroutine qimage_delete

    logical function qimage_isNull(self)
        class(QImage), intent(in) :: self
        qimage_isNull = .true.
        if (c_associated(self%ptr)) qimage_isNull = qtf_logical(qtf_qimage_isNull(self%ptr))
    end function qimage_isNull

    integer function qimage_width(self)
        class(QImage), intent(in) :: self
        qimage_width = qtf_qimage_width(self%ptr)
    end function qimage_width

    integer function qimage_height(self)
        class(QImage), intent(in) :: self
        qimage_height = qtf_qimage_height(self%ptr)
    end function qimage_height

    subroutine qimage_fill(self, color)
        class(QImage), intent(in) :: self
        type(QColor), intent(in) :: color
        call qtf_qimage_fill(self%ptr, int(color%r, c_int), int(color%g, c_int), &
                             int(color%b, c_int), int(color%a, c_int))
    end subroutine qimage_fill

    function qimage_pixelColor(self, x, y) result(c)
        class(QImage), intent(in) :: self
        integer, intent(in) :: x, y
        type(QColor) :: c
        integer(c_int) :: r, g, b, a
        call qtf_qimage_pixelColor(self%ptr, int(x, c_int), int(y, c_int), r, g, b, a)
        c = QColor(r, g, b, a)
    end function qimage_pixelColor

    subroutine qimage_setPixelColor(self, x, y, color)
        class(QImage), intent(in) :: self
        integer, intent(in) :: x, y
        type(QColor), intent(in) :: color
        call qtf_qimage_setPixelColor(self%ptr, int(x, c_int), int(y, c_int), int(color%r, c_int), &
                                      int(color%g, c_int), int(color%b, c_int), int(color%a, c_int))
    end subroutine qimage_setPixelColor

    !> Save to a file; the format follows the extension (.png, .jpg, ...).
    logical function qimage_save(self, fileName)
        class(QImage), intent(in) :: self
        character(len=*), intent(in) :: fileName
        qimage_save = qtf_logical(qtf_qimage_save(self%ptr, fileName, len(fileName, c_int)))
    end function qimage_save

    subroutine qpixmap_delete(self)
        class(QPixmap), intent(inout) :: self
        if (c_associated(self%ptr)) call qtf_qpixmap_delete(self%ptr)
        self%ptr = c_null_ptr
    end subroutine qpixmap_delete

    logical function qpixmap_isNull(self)
        class(QPixmap), intent(in) :: self
        qpixmap_isNull = .true.
        if (c_associated(self%ptr)) qpixmap_isNull = qtf_logical(qtf_qpixmap_isNull(self%ptr))
    end function qpixmap_isNull

    integer function qpixmap_width(self)
        class(QPixmap), intent(in) :: self
        qpixmap_width = qtf_qpixmap_width(self%ptr)
    end function qpixmap_width

    integer function qpixmap_height(self)
        class(QPixmap), intent(in) :: self
        qpixmap_height = qtf_qpixmap_height(self%ptr)
    end function qpixmap_height

    !> A new image with the pixmap's contents (delete it when done).
    function qpixmap_toImage(self) result(img)
        class(QPixmap), intent(in) :: self
        type(QImage) :: img
        img%ptr = qtf_qpixmap_toImage(self%ptr)
    end function qpixmap_toImage

    logical function qpixmap_save(self, fileName)
        class(QPixmap), intent(in) :: self
        character(len=*), intent(in) :: fileName
        qpixmap_save = qtf_logical(qtf_qpixmap_save(self%ptr, fileName, len(fileName, c_int)))
    end function qpixmap_save

    ! ------------------------------------------------------------------
    ! QPainter

    function qpainter_new_image(image) result(p)
        class(QImage), intent(in) :: image
        type(QPainter) :: p
        p%ptr = qtf_qpainter_new_image(image%ptr)
        p%owned = .true.
    end function qpainter_new_image

    !> Finish painting. Only painters created from Fortran are ended; a painter
    !> received in a paint slot is ended by Qt after the slot returns.
    subroutine qpainter_end(self)
        class(QPainter), intent(inout) :: self
        if (self%owned .and. c_associated(self%ptr)) call qtf_qpainter_delete(self%ptr)
        self%ptr = c_null_ptr
        self%owned = .false.
    end subroutine qpainter_end

    logical function qpainter_isActive(self)
        class(QPainter), intent(in) :: self
        qpainter_isActive = .false.
        if (c_associated(self%ptr)) qpainter_isActive = qtf_logical(qtf_qpainter_isActive(self%ptr))
    end function qpainter_isActive

    !> Width of the device being painted (widget or image).
    integer function qpainter_deviceWidth(self)
        class(QPainter), intent(in) :: self
        qpainter_deviceWidth = qtf_qpainter_deviceWidth(self%ptr)
    end function qpainter_deviceWidth

    integer function qpainter_deviceHeight(self)
        class(QPainter), intent(in) :: self
        qpainter_deviceHeight = qtf_qpainter_deviceHeight(self%ptr)
    end function qpainter_deviceHeight

    subroutine setPen_pen(self, pen)
        class(QPainter), intent(in) :: self
        type(QPen), intent(in) :: pen
        call qtf_qpainter_setPen(self%ptr, int(pen%color%r, c_int), int(pen%color%g, c_int), &
                                 int(pen%color%b, c_int), int(pen%color%a, c_int), pen%width, &
                                 int(pen%style, c_int))
    end subroutine setPen_pen

    subroutine setPen_color(self, color)
        class(QPainter), intent(in) :: self
        type(QColor), intent(in) :: color
        call self%setPen(QPen(color))
    end subroutine setPen_color

    subroutine setBrush_brush(self, brush)
        class(QPainter), intent(in) :: self
        type(QBrush), intent(in) :: brush
        call qtf_qpainter_setBrush(self%ptr, int(brush%color%r, c_int), int(brush%color%g, c_int), &
                                   int(brush%color%b, c_int), int(brush%color%a, c_int), int(brush%style, c_int))
    end subroutine setBrush_brush

    subroutine setBrush_color(self, color)
        class(QPainter), intent(in) :: self
        type(QColor), intent(in) :: color
        call self%setBrush(QBrush(color))
    end subroutine setBrush_color

    subroutine qpainter_setFont(self, font)
        class(QPainter), intent(in) :: self
        type(QFont), intent(in) :: font
        if (allocated(font%family)) then
            call qtf_qpainter_setFont(self%ptr, font%family, len(font%family, c_int), font%pointSize, &
                                      qtf_int(font%bold), qtf_int(font%italic))
        else
            call qtf_qpainter_setFont(self%ptr, '', 0_c_int, font%pointSize, qtf_int(font%bold), &
                                      qtf_int(font%italic))
        end if
    end subroutine qpainter_setFont

    subroutine qpainter_setRenderHint(self, hint, on)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: hint
        logical, intent(in), optional :: on
        logical :: o
        o = .true.
        if (present(on)) o = on
        call qtf_qpainter_setRenderHint(self%ptr, int(hint, c_int), qtf_int(o))
    end subroutine qpainter_setRenderHint

    subroutine qpainter_setOpacity(self, opacity)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: opacity
        call qtf_qpainter_setOpacity(self%ptr, opacity)
    end subroutine qpainter_setOpacity

    subroutine qpainter_save(self)
        class(QPainter), intent(in) :: self
        call qtf_qpainter_save(self%ptr)
    end subroutine qpainter_save

    subroutine qpainter_restore(self)
        class(QPainter), intent(in) :: self
        call qtf_qpainter_restore(self%ptr)
    end subroutine qpainter_restore

    subroutine translate_d(self, dx, dy)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: dx, dy
        call qtf_qpainter_translate(self%ptr, dx, dy)
    end subroutine translate_d

    subroutine translate_i(self, dx, dy)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: dx, dy
        call qtf_qpainter_translate(self%ptr, real(dx, c_double), real(dy, c_double))
    end subroutine translate_i

    subroutine qpainter_scale(self, sx, sy)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: sx, sy
        call qtf_qpainter_scale(self%ptr, sx, sy)
    end subroutine qpainter_scale

    subroutine qpainter_rotate(self, degrees)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: degrees
        call qtf_qpainter_rotate(self%ptr, degrees)
    end subroutine qpainter_rotate

    subroutine qpainter_resetTransform(self)
        class(QPainter), intent(in) :: self
        call qtf_qpainter_resetTransform(self%ptr)
    end subroutine qpainter_resetTransform

    subroutine drawPoint_d(self, x, y)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x, y
        call qtf_qpainter_drawPoint(self%ptr, x, y)
    end subroutine drawPoint_d

    subroutine drawPoint_i(self, x, y)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x, y
        call qtf_qpainter_drawPoint(self%ptr, real(x, c_double), real(y, c_double))
    end subroutine drawPoint_i

    subroutine drawLine_d(self, x1, y1, x2, y2)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x1, y1, x2, y2
        call qtf_qpainter_drawLine(self%ptr, x1, y1, x2, y2)
    end subroutine drawLine_d

    subroutine drawLine_i(self, x1, y1, x2, y2)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x1, y1, x2, y2
        call qtf_qpainter_drawLine(self%ptr, real(x1, c_double), real(y1, c_double), &
                                   real(x2, c_double), real(y2, c_double))
    end subroutine drawLine_i

    subroutine drawRect_d(self, x, y, w, h)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x, y, w, h
        call qtf_qpainter_drawRect(self%ptr, x, y, w, h)
    end subroutine drawRect_d

    subroutine drawRect_i(self, x, y, w, h)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x, y, w, h
        call qtf_qpainter_drawRect(self%ptr, real(x, c_double), real(y, c_double), &
                                   real(w, c_double), real(h, c_double))
    end subroutine drawRect_i

    subroutine drawRoundedRect_d(self, x, y, w, h, rx, ry)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x, y, w, h, rx, ry
        call qtf_qpainter_drawRoundedRect(self%ptr, x, y, w, h, rx, ry)
    end subroutine drawRoundedRect_d

    subroutine drawRoundedRect_i(self, x, y, w, h, rx, ry)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x, y, w, h, rx, ry
        call qtf_qpainter_drawRoundedRect(self%ptr, real(x, c_double), real(y, c_double), &
                                          real(w, c_double), real(h, c_double), &
                                          real(rx, c_double), real(ry, c_double))
    end subroutine drawRoundedRect_i

    subroutine drawEllipse_d(self, x, y, w, h)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x, y, w, h
        call qtf_qpainter_drawEllipse(self%ptr, x, y, w, h)
    end subroutine drawEllipse_d

    subroutine drawEllipse_i(self, x, y, w, h)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x, y, w, h
        call qtf_qpainter_drawEllipse(self%ptr, real(x, c_double), real(y, c_double), &
                                      real(w, c_double), real(h, c_double))
    end subroutine drawEllipse_i

    subroutine fillRect_d(self, x, y, w, h, color)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x, y, w, h
        type(QColor), intent(in) :: color
        call qtf_qpainter_fillRect(self%ptr, x, y, w, h, int(color%r, c_int), int(color%g, c_int), &
                                   int(color%b, c_int), int(color%a, c_int))
    end subroutine fillRect_d

    subroutine fillRect_i(self, x, y, w, h, color)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x, y, w, h
        type(QColor), intent(in) :: color
        call self%fillRect(real(x, c_double), real(y, c_double), real(w, c_double), real(h, c_double), color)
    end subroutine fillRect_i

    subroutine drawPolyline_d(self, x, y)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x(:), y(:)
        call qtf_qpainter_drawPolyline(self%ptr, x, y, int(min(size(x), size(y)), c_int))
    end subroutine drawPolyline_d

    subroutine drawPolyline_i(self, x, y)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x(:), y(:)
        call self%drawPolyline(real(x, c_double), real(y, c_double))
    end subroutine drawPolyline_i

    subroutine drawPolygon_d(self, x, y)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x(:), y(:)
        call qtf_qpainter_drawPolygon(self%ptr, x, y, int(min(size(x), size(y)), c_int))
    end subroutine drawPolygon_d

    subroutine drawPolygon_i(self, x, y)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x(:), y(:)
        call self%drawPolygon(real(x, c_double), real(y, c_double))
    end subroutine drawPolygon_i

    !> Draw text with its baseline starting at (x, y).
    subroutine drawText_d(self, x, y, text)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x, y
        character(len=*), intent(in) :: text
        call qtf_qpainter_drawText(self%ptr, x, y, text, len(text, c_int))
    end subroutine drawText_d

    subroutine drawText_i(self, x, y, text)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x, y
        character(len=*), intent(in) :: text
        call qtf_qpainter_drawText(self%ptr, real(x, c_double), real(y, c_double), text, len(text, c_int))
    end subroutine drawText_i

    !> Draw text inside a rectangle, aligned by `flags` (e.g. Qt_AlignCenter).
    subroutine drawTextRect_d(self, x, y, w, h, flags, text)
        class(QPainter), intent(in) :: self
        real(c_double), intent(in) :: x, y, w, h
        integer, intent(in) :: flags
        character(len=*), intent(in) :: text
        call qtf_qpainter_drawTextRect(self%ptr, x, y, w, h, int(flags, c_int), text, len(text, c_int))
    end subroutine drawTextRect_d

    subroutine drawTextRect_i(self, x, y, w, h, flags, text)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x, y, w, h, flags
        character(len=*), intent(in) :: text
        call qtf_qpainter_drawTextRect(self%ptr, real(x, c_double), real(y, c_double), real(w, c_double), &
                                       real(h, c_double), int(flags, c_int), text, len(text, c_int))
    end subroutine drawTextRect_i

    subroutine qpainter_drawImage(self, x, y, image)
        class(QPainter), intent(in) :: self
        integer, intent(in) :: x, y
        type(QImage), intent(in) :: image
        call qtf_qpainter_drawImage(self%ptr, real(x, c_double), real(y, c_double), image%ptr)
    end subroutine qpainter_drawImage

    !> Width in pixels of `text` in the current font.
    integer function qpainter_textWidth(self, text)
        class(QPainter), intent(in) :: self
        character(len=*), intent(in) :: text
        qpainter_textWidth = qtf_qpainter_textWidth(self%ptr, text, len(text, c_int))
    end function qpainter_textWidth

    !> Line height in pixels of the current font.
    integer function qpainter_fontHeight(self)
        class(QPainter), intent(in) :: self
        qpainter_fontHeight = qtf_qpainter_fontHeight(self%ptr)
    end function qpainter_fontHeight

    ! ------------------------------------------------------------------
    ! input events

    !> A synthetic mouse event (e.g. for QCoreApplication_sendEvent); delete it after use.
    function qmouseevent_new(type, x, y, button, buttons, modifiers) result(e)
        integer, intent(in) :: type
        real(c_double), intent(in) :: x, y
        integer, intent(in) :: button
        integer, intent(in), optional :: buttons, modifiers
        type(QMouseEvent) :: e
        integer(c_int) :: bs, m
        bs = int(button, c_int)
        m = Qt_NoModifier
        if (present(buttons)) bs = int(buttons, c_int)
        if (present(modifiers)) m = int(modifiers, c_int)
        e%ptr = qtf_qmouseevent_new(int(type, c_int), x, y, int(button, c_int), bs, m)
    end function qmouseevent_new

    real(c_double) function qmouseevent_x(self)
        class(QMouseEvent), intent(in) :: self
        qmouseevent_x = qtf_qmouseevent_x(self%ptr)
    end function qmouseevent_x

    real(c_double) function qmouseevent_y(self)
        class(QMouseEvent), intent(in) :: self
        qmouseevent_y = qtf_qmouseevent_y(self%ptr)
    end function qmouseevent_y

    !> The button that caused the event (Qt_NoButton for moves).
    integer function qmouseevent_button(self)
        class(QMouseEvent), intent(in) :: self
        qmouseevent_button = qtf_qmouseevent_button(self%ptr)
    end function qmouseevent_button

    !> All buttons held during the event (a combination of Qt_*Button).
    integer function qmouseevent_buttons(self)
        class(QMouseEvent), intent(in) :: self
        qmouseevent_buttons = qtf_qmouseevent_buttons(self%ptr)
    end function qmouseevent_buttons

    integer function qmouseevent_modifiers(self)
        class(QMouseEvent), intent(in) :: self
        qmouseevent_modifiers = qtf_qmouseevent_modifiers(self%ptr)
    end function qmouseevent_modifiers

    !> A synthetic key event; delete it after use.
    function qkeyevent_new(type, key, modifiers, text) result(e)
        integer, intent(in) :: type, key
        integer, intent(in), optional :: modifiers
        character(len=*), intent(in), optional :: text
        type(QKeyEvent) :: e
        integer(c_int) :: m
        m = Qt_NoModifier
        if (present(modifiers)) m = int(modifiers, c_int)
        if (present(text)) then
            e%ptr = qtf_qkeyevent_new(int(type, c_int), int(key, c_int), m, text, len(text, c_int))
        else
            e%ptr = qtf_qkeyevent_new(int(type, c_int), int(key, c_int), m, '', 0_c_int)
        end if
    end function qkeyevent_new

    integer function qkeyevent_key(self)
        class(QKeyEvent), intent(in) :: self
        qkeyevent_key = qtf_qkeyevent_key(self%ptr)
    end function qkeyevent_key

    integer function qkeyevent_modifiers(self)
        class(QKeyEvent), intent(in) :: self
        qkeyevent_modifiers = qtf_qkeyevent_modifiers(self%ptr)
    end function qkeyevent_modifiers

    !> The text the key produced (may be empty, e.g. for arrow keys).
    function qkeyevent_text(self) result(text)
        class(QKeyEvent), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qkeyevent_text(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qkeyevent_text

    logical function qkeyevent_isAutoRepeat(self)
        class(QKeyEvent), intent(in) :: self
        qkeyevent_isAutoRepeat = qtf_logical(qtf_qkeyevent_isAutoRepeat(self%ptr))
    end function qkeyevent_isAutoRepeat

    !> A synthetic wheel event; delete it after use.
    function qwheelevent_new(x, y, angleDeltaX, angleDeltaY, buttons, modifiers) result(e)
        real(c_double), intent(in) :: x, y
        integer, intent(in) :: angleDeltaX, angleDeltaY
        integer, intent(in), optional :: buttons, modifiers
        type(QWheelEvent) :: e
        integer(c_int) :: bs, m
        bs = Qt_NoButton
        m = Qt_NoModifier
        if (present(buttons)) bs = int(buttons, c_int)
        if (present(modifiers)) m = int(modifiers, c_int)
        e%ptr = qtf_qwheelevent_new(x, y, int(angleDeltaX, c_int), int(angleDeltaY, c_int), bs, m)
    end function qwheelevent_new

    real(c_double) function qwheelevent_x(self)
        class(QWheelEvent), intent(in) :: self
        qwheelevent_x = qtf_qwheelevent_x(self%ptr)
    end function qwheelevent_x

    real(c_double) function qwheelevent_y(self)
        class(QWheelEvent), intent(in) :: self
        qwheelevent_y = qtf_qwheelevent_y(self%ptr)
    end function qwheelevent_y

    integer function qwheelevent_angleDeltaX(self)
        class(QWheelEvent), intent(in) :: self
        qwheelevent_angleDeltaX = qtf_qwheelevent_angleDeltaX(self%ptr)
    end function qwheelevent_angleDeltaX

    integer function qwheelevent_angleDeltaY(self)
        class(QWheelEvent), intent(in) :: self
        qwheelevent_angleDeltaY = qtf_qwheelevent_angleDeltaY(self%ptr)
    end function qwheelevent_angleDeltaY

    integer function qwheelevent_buttons(self)
        class(QWheelEvent), intent(in) :: self
        qwheelevent_buttons = qtf_qwheelevent_buttons(self%ptr)
    end function qwheelevent_buttons

    integer function qwheelevent_modifiers(self)
        class(QWheelEvent), intent(in) :: self
        qwheelevent_modifiers = qtf_qwheelevent_modifiers(self%ptr)
    end function qwheelevent_modifiers

    !> A synthetic resize event; delete it after use.
    function qresizeevent_new(width, height, oldWidth, oldHeight) result(e)
        integer, intent(in) :: width, height, oldWidth, oldHeight
        type(QResizeEvent) :: e
        e%ptr = qtf_qresizeevent_new(int(width, c_int), int(height, c_int), &
                                     int(oldWidth, c_int), int(oldHeight, c_int))
    end function qresizeevent_new

    integer function qresizeevent_width(self)
        class(QResizeEvent), intent(in) :: self
        qresizeevent_width = qtf_qresizeevent_width(self%ptr)
    end function qresizeevent_width

    integer function qresizeevent_height(self)
        class(QResizeEvent), intent(in) :: self
        qresizeevent_height = qtf_qresizeevent_height(self%ptr)
    end function qresizeevent_height

    integer function qresizeevent_oldWidth(self)
        class(QResizeEvent), intent(in) :: self
        qresizeevent_oldWidth = qtf_qresizeevent_oldWidth(self%ptr)
    end function qresizeevent_oldWidth

    integer function qresizeevent_oldHeight(self)
        class(QResizeEvent), intent(in) :: self
        qresizeevent_oldHeight = qtf_qresizeevent_oldHeight(self%ptr)
    end function qresizeevent_oldHeight

    ! ------------------------------------------------------------------
    ! event / painter signals

    subroutine qsignalpainter_connect(self, slot, data)
        class(QSignalPainter), intent(in) :: self
        procedure(qt_slot_painter) :: slot
        class(*), intent(inout), target, optional :: data
        type(painter_handler) :: h
        h%f => slot
        call qt_connect_handler(self%sender, self%id, h, data)
    end subroutine qsignalpainter_connect

    subroutine painter_handler_invoke(self, args, data)
        class(painter_handler), intent(in) :: self
        type(qtf_args), intent(in) :: args
        class(*), pointer, intent(in) :: data
        type(QPainter) :: p
        p%ptr = args%p    ! borrowed: not owned, so `end` will not delete it
        if (associated(data)) then
            call self%f(p, data)
        else
            call self%f(p)
        end if
    end subroutine painter_handler_invoke

    subroutine qsignalmouseevent_connect(self, slot, data)
        class(QSignalMouseEvent), intent(in) :: self
        procedure(qt_slot_mouse_event) :: slot
        class(*), intent(inout), target, optional :: data
        type(mouse_handler) :: h
        h%f => slot
        call qt_connect_handler(self%sender, self%id, h, data)
    end subroutine qsignalmouseevent_connect

    subroutine mouse_handler_invoke(self, args, data)
        class(mouse_handler), intent(in) :: self
        type(qtf_args), intent(in) :: args
        class(*), pointer, intent(in) :: data
        type(QMouseEvent) :: e
        e%ptr = args%p
        if (associated(data)) then
            call self%f(e, data)
        else
            call self%f(e)
        end if
    end subroutine mouse_handler_invoke

    subroutine qsignalkeyevent_connect(self, slot, data)
        class(QSignalKeyEvent), intent(in) :: self
        procedure(qt_slot_key_event) :: slot
        class(*), intent(inout), target, optional :: data
        type(key_handler) :: h
        h%f => slot
        call qt_connect_handler(self%sender, self%id, h, data)
    end subroutine qsignalkeyevent_connect

    subroutine key_handler_invoke(self, args, data)
        class(key_handler), intent(in) :: self
        type(qtf_args), intent(in) :: args
        class(*), pointer, intent(in) :: data
        type(QKeyEvent) :: e
        e%ptr = args%p
        if (associated(data)) then
            call self%f(e, data)
        else
            call self%f(e)
        end if
    end subroutine key_handler_invoke

    subroutine qsignalwheelevent_connect(self, slot, data)
        class(QSignalWheelEvent), intent(in) :: self
        procedure(qt_slot_wheel_event) :: slot
        class(*), intent(inout), target, optional :: data
        type(wheel_handler) :: h
        h%f => slot
        call qt_connect_handler(self%sender, self%id, h, data)
    end subroutine qsignalwheelevent_connect

    subroutine wheel_handler_invoke(self, args, data)
        class(wheel_handler), intent(in) :: self
        type(qtf_args), intent(in) :: args
        class(*), pointer, intent(in) :: data
        type(QWheelEvent) :: e
        e%ptr = args%p
        if (associated(data)) then
            call self%f(e, data)
        else
            call self%f(e)
        end if
    end subroutine wheel_handler_invoke

    subroutine qsignalresizeevent_connect(self, slot, data)
        class(QSignalResizeEvent), intent(in) :: self
        procedure(qt_slot_resize_event) :: slot
        class(*), intent(inout), target, optional :: data
        type(resize_handler) :: h
        h%f => slot
        call qt_connect_handler(self%sender, self%id, h, data)
    end subroutine qsignalresizeevent_connect

    subroutine resize_handler_invoke(self, args, data)
        class(resize_handler), intent(in) :: self
        type(qtf_args), intent(in) :: args
        class(*), pointer, intent(in) :: data
        type(QResizeEvent) :: e
        e%ptr = args%p
        if (associated(data)) then
            call self%f(e, data)
        else
            call self%f(e)
        end if
    end subroutine resize_handler_invoke

    ! ------------------------------------------------------------------
    ! QAction

    function qaction_new(text, parent) result(a)
        character(len=*), intent(in) :: text
        class(QObject), intent(in), optional :: parent
        type(QAction) :: a
        call a%attach(qtf_qaction_new(text, len(text, c_int), qtf_ptr(parent)))
    end function qaction_new

    subroutine qaction_attach(self, ptr)
        class(QAction), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QObject%attach(ptr)
        self%triggered = QSignal(ptr, QTF_SIG_QACTION_TRIGGERED)
        self%toggled = QSignalBool(ptr, QTF_SIG_QACTION_TOGGLED)
    end subroutine qaction_attach

    subroutine qaction_setText(self, text)
        class(QAction), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qaction_setText(self%ptr, text, len(text, c_int))
    end subroutine qaction_setText

    function qaction_text(self) result(text)
        class(QAction), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qaction_text(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qaction_text

    !> Set the keyboard shortcut, e.g. 'Ctrl+O' (Ctrl is Cmd on macOS).
    subroutine qaction_setShortcut(self, shortcut)
        class(QAction), intent(in) :: self
        character(len=*), intent(in) :: shortcut
        call qtf_qaction_setShortcut(self%ptr, shortcut, len(shortcut, c_int))
    end subroutine qaction_setShortcut

    !> The shortcut in portable text form, e.g. 'Ctrl+O'.
    function qaction_shortcut(self) result(shortcut)
        class(QAction), intent(in) :: self
        character(len=:), allocatable :: shortcut
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qaction_shortcut(self%ptr, n)
        shortcut = qtf_take_string(p, n)
    end function qaction_shortcut

    subroutine qaction_setCheckable(self, checkable)
        class(QAction), intent(in) :: self
        logical, intent(in) :: checkable
        call qtf_qaction_setCheckable(self%ptr, qtf_int(checkable))
    end subroutine qaction_setCheckable

    logical function qaction_isCheckable(self)
        class(QAction), intent(in) :: self
        qaction_isCheckable = qtf_logical(qtf_qaction_isCheckable(self%ptr))
    end function qaction_isCheckable

    subroutine qaction_setChecked(self, checked)
        class(QAction), intent(in) :: self
        logical, intent(in) :: checked
        call qtf_qaction_setChecked(self%ptr, qtf_int(checked))
    end subroutine qaction_setChecked

    logical function qaction_isChecked(self)
        class(QAction), intent(in) :: self
        qaction_isChecked = qtf_logical(qtf_qaction_isChecked(self%ptr))
    end function qaction_isChecked

    subroutine qaction_setEnabled(self, enabled)
        class(QAction), intent(in) :: self
        logical, intent(in) :: enabled
        call qtf_qaction_setEnabled(self%ptr, qtf_int(enabled))
    end subroutine qaction_setEnabled

    logical function qaction_isEnabled(self)
        class(QAction), intent(in) :: self
        qaction_isEnabled = qtf_logical(qtf_qaction_isEnabled(self%ptr))
    end function qaction_isEnabled

    subroutine qaction_setStatusTip(self, tip)
        class(QAction), intent(in) :: self
        character(len=*), intent(in) :: tip
        call qtf_qaction_setStatusTip(self%ptr, tip, len(tip, c_int))
    end subroutine qaction_setStatusTip

    subroutine qaction_setToolTip(self, tip)
        class(QAction), intent(in) :: self
        character(len=*), intent(in) :: tip
        call qtf_qaction_setToolTip(self%ptr, tip, len(tip, c_int))
    end subroutine qaction_setToolTip

    !> Activate the action (emits triggered, and toggled if checkable).
    subroutine qaction_trigger(self)
        class(QAction), intent(in) :: self
        call qtf_qaction_trigger(self%ptr)
    end subroutine qaction_trigger

end module qt_gui
