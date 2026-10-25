!> Qt Gui value types: QColor, QPen, QBrush, QFont, and the styles and named
!> colors they use. These are plain Fortran types (as Qt treats them as values),
!> built with structure constructors, e.g. `QPen(Qt_red, 2.0_c_double)`.
module qt_gui_types

    use iso_c_binding
    use qt_c_util, only: qtf_logical
    use qt_c_gui, only: qtf_qcolor_fromString
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

    !> Compare two colors (all components and validity).
    interface operator(==)
        module procedure :: qcolor_eq
    end interface operator(==)
    !> True if two colors differ.
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

contains

    !> Parse a color name (SVG names, `#rgb`, `#rrggbb`); check `isValid()`.
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

    !> The red component (0..255).
    integer function qcolor_red(self)
        class(QColor), intent(in) :: self
        qcolor_red = self%r
    end function qcolor_red

    !> The green component (0..255).
    integer function qcolor_green(self)
        class(QColor), intent(in) :: self
        qcolor_green = self%g
    end function qcolor_green

    !> The blue component (0..255).
    integer function qcolor_blue(self)
        class(QColor), intent(in) :: self
        qcolor_blue = self%b
    end function qcolor_blue

    !> The alpha (opacity) component (0 transparent .. 255 opaque).
    integer function qcolor_alpha(self)
        class(QColor), intent(in) :: self
        qcolor_alpha = self%a
    end function qcolor_alpha

    !> False if the color was built from an unknown name.
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

    !> ASCII lower-case copy of `s`.
    pure function lower(s) result(t)
        character(len=*), intent(in) :: s
        character(len=len(s)) :: t
        integer :: i
        t = s
        do i = 1, len(s)
            if (s(i:i) >= 'A' .and. s(i:i) <= 'Z') t(i:i) = achar(iachar(s(i:i)) + 32)
        end do
    end function lower

    !> True if two colors are equal.
    elemental logical function qcolor_eq(c1, c2)
        type(QColor), intent(in) :: c1, c2
        qcolor_eq = c1%r == c2%r .and. c1%g == c2%g .and. c1%b == c2%b .and. c1%a == c2%a &
                    .and. (c1%valid .eqv. c2%valid)
    end function qcolor_eq

    !> True if two colors differ.
    elemental logical function qcolor_ne(c1, c2)
        type(QColor), intent(in) :: c1, c2
        qcolor_ne = .not. qcolor_eq(c1, c2)
    end function qcolor_ne

end module qt_gui_types
