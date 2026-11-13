!> Qt's 2D geometry value types, in pure Fortran: QPoint, QPointF, QSize, QSizeF,
!> QRect, QRectF, QLineF and QMargins.
!>
!> These are plain Fortran types with public components (Qt treats them as
!> values): `QPoint(10, 20)`, `p%x`, `r%width`. The integer types use default
!> integers, the floating-point ones `real(c_double)`; structure constructors
!> convert numbers, so `QPointF(1, 2)` works. Methods and operators follow Qt:
!>
!>     type(QRectF) :: r
!>     r = QRectF(0, 0, 100, 50)
!>     if (r%contains(QPointF(10, 10))) ...
!>     c = r%center() + QPointF(5, 0) * 2.0_c_double
!>
!> As in Qt, `QRect%right()` is `x + width - 1` (the last pixel inside), while
!> `QRectF%right()` is `x + width`. Floating-point types compare (`==`) to
!> within a relative 1e-12, as Qt compares them fuzzily.
module qt_geometry

    use iso_c_binding, only: c_double
    implicit none
    private

    integer, parameter :: dp = c_double

    ! QLineF::IntersectionType
    integer, parameter, public :: QLineF_NoIntersection = 0        !! the lines are parallel
    integer, parameter, public :: QLineF_BoundedIntersection = 1   !! they cross within both segments
    integer, parameter, public :: QLineF_UnboundedIntersection = 2 !! they cross outside a segment

    ! Qt::AspectRatioMode (for QSize%scaled)
    integer, parameter, public :: Qt_IgnoreAspectRatio = 0          !! scale to the given size exactly
    integer, parameter, public :: Qt_KeepAspectRatio = 1            !! the largest size inside, same aspect
    integer, parameter, public :: Qt_KeepAspectRatioByExpanding = 2 !! the smallest size around, same aspect

    ! ------------------------------------------------------------------
    ! types

    !> A point with integer coordinates: `QPoint(x, y)`.
    type, public :: QPoint
        integer :: x = 0   !! horizontal coordinate
        integer :: y = 0   !! vertical coordinate
    contains
        procedure :: isNull => qpoint_isNull
        procedure :: manhattanLength => qpoint_manhattanLength
        procedure :: transposed => qpoint_transposed
        procedure :: toPointF => qpoint_toPointF
    end type QPoint

    !> A point with floating-point coordinates: `QPointF(x, y)` or `QPointF(point)`.
    type, public :: QPointF
        real(dp) :: x = 0.0_dp   !! horizontal coordinate
        real(dp) :: y = 0.0_dp   !! vertical coordinate
    contains
        procedure :: isNull => qpointf_isNull
        procedure :: manhattanLength => qpointf_manhattanLength
        procedure :: transposed => qpointf_transposed
        procedure :: toPoint => qpointf_toPoint
    end type QPointF
    !> `QPointF(x, y)` is the structure constructor; `QPointF(point)` converts a QPoint.
    interface QPointF
        module procedure :: qpointf_fromPoint
    end interface QPointF

    !> A two-dimensional integer size: `QSize(width, height)`.
    !> A size with a negative dimension is invalid (the default is 0 x 0).
    type, public :: QSize
        integer :: width = 0    !! the width
        integer :: height = 0   !! the height
    contains
        procedure :: isNull => qsize_isNull
        procedure :: isEmpty => qsize_isEmpty
        procedure :: isValid => qsize_isValid
        procedure :: transposed => qsize_transposed
        procedure :: expandedTo => qsize_expandedTo
        procedure :: boundedTo => qsize_boundedTo
        procedure :: scaled => qsize_scaled
        procedure :: grownBy => qsize_grownBy
        procedure :: shrunkBy => qsize_shrunkBy
        procedure :: toSizeF => qsize_toSizeF
    end type QSize

    !> A two-dimensional floating-point size: `QSizeF(width, height)` or `QSizeF(size)`.
    type, public :: QSizeF
        real(dp) :: width = 0.0_dp    !! the width
        real(dp) :: height = 0.0_dp   !! the height
    contains
        procedure :: isNull => qsizef_isNull
        procedure :: isEmpty => qsizef_isEmpty
        procedure :: isValid => qsizef_isValid
        procedure :: transposed => qsizef_transposed
        procedure :: expandedTo => qsizef_expandedTo
        procedure :: boundedTo => qsizef_boundedTo
        procedure :: scaled => qsizef_scaled
        procedure :: toSize => qsizef_toSize
    end type QSizeF
    !> `QSizeF(width, height)` is the structure constructor; `QSizeF(size)` converts a QSize.
    interface QSizeF
        module procedure :: qsizef_fromSize
    end interface QSizeF

    !> Margins around a rectangle: `QMargins(left, top, right, bottom)`.
    type, public :: QMargins
        integer :: left = 0     !! the left margin
        integer :: top = 0      !! the top margin
        integer :: right = 0    !! the right margin
        integer :: bottom = 0   !! the bottom margin
    contains
        procedure :: isNull => qmargins_isNull
    end type QMargins

    !> An integer rectangle: `QRect(x, y, width, height)`, `QRect(topLeft, size)`
    !> or `QRect(topLeft, bottomRight)`.
    !> As in Qt, `right()` and `bottom()` are the last column and row inside:
    !> `x + width - 1` and `y + height - 1`.
    type, public :: QRect
        integer :: x = 0        !! the left edge
        integer :: y = 0        !! the top edge
        integer :: width = 0    !! the width
        integer :: height = 0   !! the height
    contains
        procedure :: left => qrect_left
        procedure :: top => qrect_top
        procedure :: right => qrect_right
        procedure :: bottom => qrect_bottom
        procedure :: topLeft => qrect_topLeft
        procedure :: topRight => qrect_topRight
        procedure :: bottomLeft => qrect_bottomLeft
        procedure :: bottomRight => qrect_bottomRight
        procedure :: center => qrect_center
        procedure :: size => qrect_size
        procedure :: isNull => qrect_isNull
        procedure :: isEmpty => qrect_isEmpty
        procedure :: isValid => qrect_isValid
        procedure :: normalized => qrect_normalized
        procedure, private :: qrect_containsPoint, qrect_containsRect
        generic :: contains => qrect_containsPoint, qrect_containsRect
        procedure :: intersects => qrect_intersects
        procedure :: intersected => qrect_intersected
        procedure :: united => qrect_united
        procedure, private :: qrect_translated, qrect_translatedPoint
        generic :: translated => qrect_translated, qrect_translatedPoint
        procedure :: adjusted => qrect_adjusted
        procedure :: marginsAdded => qrect_marginsAdded
        procedure :: marginsRemoved => qrect_marginsRemoved
        procedure :: moveTo => qrect_moveTo
        procedure :: moveCenter => qrect_moveCenter
        procedure :: toRectF => qrect_toRectF
    end type QRect
    !> `QRect(x, y, width, height)` is the structure constructor; also
    !> `QRect(topLeft, size)` and `QRect(topLeft, bottomRight)` (corners inclusive).
    interface QRect
        module procedure :: qrect_fromPointSize, qrect_fromPoints
    end interface QRect

    !> A floating-point rectangle: `QRectF(x, y, width, height)`,
    !> `QRectF(topLeft, size)`, `QRectF(topLeft, bottomRight)` or `QRectF(rect)`.
    type, public :: QRectF
        real(dp) :: x = 0.0_dp        !! the left edge
        real(dp) :: y = 0.0_dp        !! the top edge
        real(dp) :: width = 0.0_dp    !! the width
        real(dp) :: height = 0.0_dp   !! the height
    contains
        procedure :: left => qrectf_left
        procedure :: top => qrectf_top
        procedure :: right => qrectf_right
        procedure :: bottom => qrectf_bottom
        procedure :: topLeft => qrectf_topLeft
        procedure :: topRight => qrectf_topRight
        procedure :: bottomLeft => qrectf_bottomLeft
        procedure :: bottomRight => qrectf_bottomRight
        procedure :: center => qrectf_center
        procedure :: size => qrectf_size
        procedure :: isNull => qrectf_isNull
        procedure :: isEmpty => qrectf_isEmpty
        procedure :: isValid => qrectf_isValid
        procedure :: normalized => qrectf_normalized
        procedure, private :: qrectf_containsPoint, qrectf_containsRect
        generic :: contains => qrectf_containsPoint, qrectf_containsRect
        procedure :: intersects => qrectf_intersects
        procedure :: intersected => qrectf_intersected
        procedure :: united => qrectf_united
        procedure, private :: qrectf_translated, qrectf_translatedPoint
        generic :: translated => qrectf_translated, qrectf_translatedPoint
        procedure :: adjusted => qrectf_adjusted
        procedure :: moveTo => qrectf_moveTo
        procedure :: moveCenter => qrectf_moveCenter
        procedure :: toRect => qrectf_toRect
        procedure :: toAlignedRect => qrectf_toAlignedRect
    end type QRectF
    !> `QRectF(x, y, width, height)` is the structure constructor; also
    !> `QRectF(topLeft, size)`, `QRectF(topLeft, bottomRight)` and `QRectF(rect)`.
    interface QRectF
        module procedure :: qrectf_fromPointSize, qrectf_fromPoints, qrectf_fromRect
    end interface QRectF

    !> A line segment from (x1, y1) to (x2, y2): `QLineF(x1, y1, x2, y2)` or
    !> `QLineF(p1, p2)`. Angles are in degrees, counterclockwise from 3 o'clock
    !> (with y pointing up, as in Qt).
    type, public :: QLineF
        real(dp) :: x1 = 0.0_dp   !! x of the start point
        real(dp) :: y1 = 0.0_dp   !! y of the start point
        real(dp) :: x2 = 0.0_dp   !! x of the end point
        real(dp) :: y2 = 0.0_dp   !! y of the end point
    contains
        procedure :: p1 => qlinef_p1
        procedure :: p2 => qlinef_p2
        procedure :: dx => qlinef_dx
        procedure :: dy => qlinef_dy
        procedure :: isNull => qlinef_isNull
        procedure :: length => qlinef_length
        procedure :: setLength => qlinef_setLength
        procedure :: angle => qlinef_angle
        procedure :: setAngle => qlinef_setAngle
        procedure :: angleTo => qlinef_angleTo
        procedure :: center => qlinef_center
        procedure :: pointAt => qlinef_pointAt
        procedure :: unitVector => qlinef_unitVector
        procedure :: normalVector => qlinef_normalVector
        procedure :: intersects => qlinef_intersects
        procedure, private :: qlinef_translated, qlinef_translatedPoint
        generic :: translated => qlinef_translated, qlinef_translatedPoint
    end type QLineF
    !> `QLineF(x1, y1, x2, y2)` is the structure constructor; `QLineF(p1, p2)` joins two points.
    interface QLineF
        module procedure :: qlinef_fromPoints
    end interface QLineF

    public :: QPointF_dotProduct, QLineF_fromPolar

    ! ------------------------------------------------------------------
    ! operators

    !> Sum of points, sizes or margins.
    interface operator(+)
        module procedure :: qpoint_add, qpointf_add, qsize_add, qsizef_add, qmargins_add
        module procedure :: qrect_plus_margins, qrectf_plus_margins
    end interface operator(+)

    !> Difference (or negation) of points, sizes or margins.
    interface operator(-)
        module procedure :: qpoint_sub, qpointf_sub, qsize_sub, qsizef_sub, qmargins_sub
        module procedure :: qpoint_neg, qpointf_neg, qmargins_neg, qrect_minus_margins
    end interface operator(-)

    !> Scale a point or size by a number (integer types round, as in Qt).
    interface operator(*)
        module procedure :: qpoint_mul_i, qpoint_mul_d, qpoint_i_mul, qpoint_d_mul
        module procedure :: qpointf_mul_d, qpointf_d_mul
        module procedure :: qsize_mul_d, qsize_d_mul, qsizef_mul_d, qsizef_d_mul
    end interface operator(*)

    !> Divide a point or size by a number (integer types round, as in Qt).
    interface operator(/)
        module procedure :: qpoint_div_d, qpointf_div_d, qsize_div_d, qsizef_div_d
    end interface operator(/)

    !> Equality (floating-point types to within a relative 1e-12).
    interface operator(==)
        module procedure :: qpoint_eq, qpointf_eq, qsize_eq, qsizef_eq, qrect_eq, qrectf_eq
        module procedure :: qlinef_eq, qmargins_eq
    end interface operator(==)

    !> Inequality: `.not. (a == b)`.
    interface operator(/=)
        module procedure :: qpoint_ne, qpointf_ne, qsize_ne, qsizef_ne, qrect_ne, qrectf_ne
        module procedure :: qlinef_ne, qmargins_ne
    end interface operator(/=)

    public :: operator(+), operator(-), operator(*), operator(/), operator(==), operator(/=)

contains

    ! ------------------------------------------------------------------
    ! helpers

    !> True if `a` and `b` are equal to within a relative 1e-12.
    elemental logical function fuzzy_eq(a, b)
        real(dp), intent(in) :: a, b
        fuzzy_eq = abs(a - b) <= 1.0e-12_dp * max(1.0_dp, abs(a), abs(b))
    end function fuzzy_eq

    !> Round to the nearest integer, halfway cases away from zero (as qRound).
    elemental integer function round(a)
        real(dp), intent(in) :: a
        round = nint(a)
    end function round

    ! ------------------------------------------------------------------
    ! QPoint

    !> True if both coordinates are 0.
    pure logical function qpoint_isNull(self)
        class(QPoint), intent(in) :: self
        qpoint_isNull = self%x == 0 .and. self%y == 0
    end function qpoint_isNull

    !> `abs(x) + abs(y)`: a quick approximation of the length.
    pure integer function qpoint_manhattanLength(self)
        class(QPoint), intent(in) :: self
        qpoint_manhattanLength = abs(self%x) + abs(self%y)
    end function qpoint_manhattanLength

    !> The point with x and y swapped.
    pure type(QPoint) function qpoint_transposed(self)
        class(QPoint), intent(in) :: self
        qpoint_transposed = QPoint(self%y, self%x)
    end function qpoint_transposed

    !> The point as a QPointF.
    pure type(QPointF) function qpoint_toPointF(self)
        class(QPoint), intent(in) :: self
        qpoint_toPointF = QPointF(real(self%x, dp), real(self%y, dp))
    end function qpoint_toPointF

    !> Sum of two points.
    elemental type(QPoint) function qpoint_add(a, b)
        type(QPoint), intent(in) :: a, b
        qpoint_add = QPoint(a%x + b%x, a%y + b%y)
    end function qpoint_add

    !> Difference of two points.
    elemental type(QPoint) function qpoint_sub(a, b)
        type(QPoint), intent(in) :: a, b
        qpoint_sub = QPoint(a%x - b%x, a%y - b%y)
    end function qpoint_sub

    !> Negated point.
    elemental type(QPoint) function qpoint_neg(a)
        type(QPoint), intent(in) :: a
        qpoint_neg = QPoint(-a%x, -a%y)
    end function qpoint_neg

    !> Point times an integer.
    elemental type(QPoint) function qpoint_mul_i(a, f)
        type(QPoint), intent(in) :: a
        integer, intent(in) :: f
        qpoint_mul_i = QPoint(a%x * f, a%y * f)
    end function qpoint_mul_i

    !> Integer times a point.
    elemental type(QPoint) function qpoint_i_mul(f, a)
        integer, intent(in) :: f
        type(QPoint), intent(in) :: a
        qpoint_i_mul = QPoint(a%x * f, a%y * f)
    end function qpoint_i_mul

    !> Point times a real number (rounded).
    elemental type(QPoint) function qpoint_mul_d(a, f)
        type(QPoint), intent(in) :: a
        real(dp), intent(in) :: f
        qpoint_mul_d = QPoint(round(a%x * f), round(a%y * f))
    end function qpoint_mul_d

    !> Real number times a point (rounded).
    elemental type(QPoint) function qpoint_d_mul(f, a)
        real(dp), intent(in) :: f
        type(QPoint), intent(in) :: a
        qpoint_d_mul = QPoint(round(a%x * f), round(a%y * f))
    end function qpoint_d_mul

    !> Point divided by a real number (rounded).
    elemental type(QPoint) function qpoint_div_d(a, f)
        type(QPoint), intent(in) :: a
        real(dp), intent(in) :: f
        qpoint_div_d = QPoint(round(a%x / f), round(a%y / f))
    end function qpoint_div_d

    !> True if two points are equal.
    elemental logical function qpoint_eq(a, b)
        type(QPoint), intent(in) :: a, b
        qpoint_eq = a%x == b%x .and. a%y == b%y
    end function qpoint_eq

    !> True if two points differ.
    elemental logical function qpoint_ne(a, b)
        type(QPoint), intent(in) :: a, b
        qpoint_ne = .not. qpoint_eq(a, b)
    end function qpoint_ne

    ! ------------------------------------------------------------------
    ! QPointF

    !> A QPointF from a QPoint.
    pure type(QPointF) function qpointf_fromPoint(p)
        type(QPoint), intent(in) :: p
        qpointf_fromPoint = QPointF(real(p%x, dp), real(p%y, dp))
    end function qpointf_fromPoint

    !> True if both coordinates are 0.
    pure logical function qpointf_isNull(self)
        class(QPointF), intent(in) :: self
        qpointf_isNull = self%x == 0.0_dp .and. self%y == 0.0_dp
    end function qpointf_isNull

    !> `abs(x) + abs(y)`.
    pure real(dp) function qpointf_manhattanLength(self)
        class(QPointF), intent(in) :: self
        qpointf_manhattanLength = abs(self%x) + abs(self%y)
    end function qpointf_manhattanLength

    !> The point with x and y swapped.
    pure type(QPointF) function qpointf_transposed(self)
        class(QPointF), intent(in) :: self
        qpointf_transposed = QPointF(self%y, self%x)
    end function qpointf_transposed

    !> The point with rounded coordinates.
    pure type(QPoint) function qpointf_toPoint(self)
        class(QPointF), intent(in) :: self
        qpointf_toPoint = QPoint(round(self%x), round(self%y))
    end function qpointf_toPoint

    !> Dot product `a%x * b%x + a%y * b%y`.
    pure real(dp) function QPointF_dotProduct(a, b)
        type(QPointF), intent(in) :: a, b
        QPointF_dotProduct = a%x * b%x + a%y * b%y
    end function QPointF_dotProduct

    !> Sum of two points.
    elemental type(QPointF) function qpointf_add(a, b)
        type(QPointF), intent(in) :: a, b
        qpointf_add = QPointF(a%x + b%x, a%y + b%y)
    end function qpointf_add

    !> Difference of two points.
    elemental type(QPointF) function qpointf_sub(a, b)
        type(QPointF), intent(in) :: a, b
        qpointf_sub = QPointF(a%x - b%x, a%y - b%y)
    end function qpointf_sub

    !> Negated point.
    elemental type(QPointF) function qpointf_neg(a)
        type(QPointF), intent(in) :: a
        qpointf_neg = QPointF(-a%x, -a%y)
    end function qpointf_neg

    !> Point times a number.
    elemental type(QPointF) function qpointf_mul_d(a, f)
        type(QPointF), intent(in) :: a
        real(dp), intent(in) :: f
        qpointf_mul_d = QPointF(a%x * f, a%y * f)
    end function qpointf_mul_d

    !> Number times a point.
    elemental type(QPointF) function qpointf_d_mul(f, a)
        real(dp), intent(in) :: f
        type(QPointF), intent(in) :: a
        qpointf_d_mul = QPointF(a%x * f, a%y * f)
    end function qpointf_d_mul

    !> Point divided by a number.
    elemental type(QPointF) function qpointf_div_d(a, f)
        type(QPointF), intent(in) :: a
        real(dp), intent(in) :: f
        qpointf_div_d = QPointF(a%x / f, a%y / f)
    end function qpointf_div_d

    !> True if two points are (fuzzily) equal.
    elemental logical function qpointf_eq(a, b)
        type(QPointF), intent(in) :: a, b
        qpointf_eq = fuzzy_eq(a%x, b%x) .and. fuzzy_eq(a%y, b%y)
    end function qpointf_eq

    !> True if two points differ.
    elemental logical function qpointf_ne(a, b)
        type(QPointF), intent(in) :: a, b
        qpointf_ne = .not. qpointf_eq(a, b)
    end function qpointf_ne

    ! ------------------------------------------------------------------
    ! QSize

    !> True if width and height are both 0.
    pure logical function qsize_isNull(self)
        class(QSize), intent(in) :: self
        qsize_isNull = self%width == 0 .and. self%height == 0
    end function qsize_isNull

    !> True if width or height is less than 1.
    pure logical function qsize_isEmpty(self)
        class(QSize), intent(in) :: self
        qsize_isEmpty = self%width < 1 .or. self%height < 1
    end function qsize_isEmpty

    !> True if width and height are both at least 0.
    pure logical function qsize_isValid(self)
        class(QSize), intent(in) :: self
        qsize_isValid = self%width >= 0 .and. self%height >= 0
    end function qsize_isValid

    !> The size with width and height swapped.
    pure type(QSize) function qsize_transposed(self)
        class(QSize), intent(in) :: self
        qsize_transposed = QSize(self%height, self%width)
    end function qsize_transposed

    !> The larger width and the larger height of this size and `other`.
    pure type(QSize) function qsize_expandedTo(self, other)
        class(QSize), intent(in) :: self
        type(QSize), intent(in) :: other
        qsize_expandedTo = QSize(max(self%width, other%width), max(self%height, other%height))
    end function qsize_expandedTo

    !> The smaller width and the smaller height of this size and `other`.
    pure type(QSize) function qsize_boundedTo(self, other)
        class(QSize), intent(in) :: self
        type(QSize), intent(in) :: other
        qsize_boundedTo = QSize(min(self%width, other%width), min(self%height, other%height))
    end function qsize_boundedTo

    !> This size scaled to `size`: Qt_IgnoreAspectRatio (default) gives `size`;
    !> Qt_KeepAspectRatio the largest size inside it with this aspect ratio;
    !> Qt_KeepAspectRatioByExpanding the smallest size around it.
    pure type(QSize) function qsize_scaled(self, size, mode) result(s)
        class(QSize), intent(in) :: self
        type(QSize), intent(in) :: size
        integer, intent(in), optional :: mode
        integer(8) :: rw
        logical :: useHeight
        s = size
        if (.not. present(mode)) return
        if (mode == Qt_IgnoreAspectRatio .or. self%width == 0 .or. self%height == 0) return
        rw = int(size%height, 8) * self%width / self%height
        if (mode == Qt_KeepAspectRatio) then
            useHeight = rw <= size%width
        else
            useHeight = rw >= size%width
        end if
        if (useHeight) then
            s = QSize(int(rw), size%height)
        else
            s = QSize(size%width, int(int(size%width, 8) * self%height / self%width))
        end if
    end function qsize_scaled

    !> The size grown by `margins` (width by left + right, height by top + bottom).
    pure type(QSize) function qsize_grownBy(self, margins)
        class(QSize), intent(in) :: self
        type(QMargins), intent(in) :: margins
        qsize_grownBy = QSize(self%width + margins%left + margins%right, &
                              self%height + margins%top + margins%bottom)
    end function qsize_grownBy

    !> The size shrunk by `margins`.
    pure type(QSize) function qsize_shrunkBy(self, margins)
        class(QSize), intent(in) :: self
        type(QMargins), intent(in) :: margins
        qsize_shrunkBy = QSize(self%width - margins%left - margins%right, &
                               self%height - margins%top - margins%bottom)
    end function qsize_shrunkBy

    !> The size as a QSizeF.
    pure type(QSizeF) function qsize_toSizeF(self)
        class(QSize), intent(in) :: self
        qsize_toSizeF = QSizeF(real(self%width, dp), real(self%height, dp))
    end function qsize_toSizeF

    !> Sum of two sizes.
    elemental type(QSize) function qsize_add(a, b)
        type(QSize), intent(in) :: a, b
        qsize_add = QSize(a%width + b%width, a%height + b%height)
    end function qsize_add

    !> Difference of two sizes.
    elemental type(QSize) function qsize_sub(a, b)
        type(QSize), intent(in) :: a, b
        qsize_sub = QSize(a%width - b%width, a%height - b%height)
    end function qsize_sub

    !> Size times a number (rounded).
    elemental type(QSize) function qsize_mul_d(a, f)
        type(QSize), intent(in) :: a
        real(dp), intent(in) :: f
        qsize_mul_d = QSize(round(a%width * f), round(a%height * f))
    end function qsize_mul_d

    !> Number times a size (rounded).
    elemental type(QSize) function qsize_d_mul(f, a)
        real(dp), intent(in) :: f
        type(QSize), intent(in) :: a
        qsize_d_mul = QSize(round(a%width * f), round(a%height * f))
    end function qsize_d_mul

    !> Size divided by a number (rounded).
    elemental type(QSize) function qsize_div_d(a, f)
        type(QSize), intent(in) :: a
        real(dp), intent(in) :: f
        qsize_div_d = QSize(round(a%width / f), round(a%height / f))
    end function qsize_div_d

    !> True if two sizes are equal.
    elemental logical function qsize_eq(a, b)
        type(QSize), intent(in) :: a, b
        qsize_eq = a%width == b%width .and. a%height == b%height
    end function qsize_eq

    !> True if two sizes differ.
    elemental logical function qsize_ne(a, b)
        type(QSize), intent(in) :: a, b
        qsize_ne = .not. qsize_eq(a, b)
    end function qsize_ne

    ! ------------------------------------------------------------------
    ! QSizeF

    !> A QSizeF from a QSize.
    pure type(QSizeF) function qsizef_fromSize(s)
        type(QSize), intent(in) :: s
        qsizef_fromSize = QSizeF(real(s%width, dp), real(s%height, dp))
    end function qsizef_fromSize

    !> True if width and height are both 0.
    pure logical function qsizef_isNull(self)
        class(QSizeF), intent(in) :: self
        qsizef_isNull = self%width == 0.0_dp .and. self%height == 0.0_dp
    end function qsizef_isNull

    !> True if width or height is not positive.
    pure logical function qsizef_isEmpty(self)
        class(QSizeF), intent(in) :: self
        qsizef_isEmpty = self%width <= 0.0_dp .or. self%height <= 0.0_dp
    end function qsizef_isEmpty

    !> True if width and height are both at least 0.
    pure logical function qsizef_isValid(self)
        class(QSizeF), intent(in) :: self
        qsizef_isValid = self%width >= 0.0_dp .and. self%height >= 0.0_dp
    end function qsizef_isValid

    !> The size with width and height swapped.
    pure type(QSizeF) function qsizef_transposed(self)
        class(QSizeF), intent(in) :: self
        qsizef_transposed = QSizeF(self%height, self%width)
    end function qsizef_transposed

    !> The larger width and the larger height of this size and `other`.
    pure type(QSizeF) function qsizef_expandedTo(self, other)
        class(QSizeF), intent(in) :: self
        type(QSizeF), intent(in) :: other
        qsizef_expandedTo = QSizeF(max(self%width, other%width), max(self%height, other%height))
    end function qsizef_expandedTo

    !> The smaller width and the smaller height of this size and `other`.
    pure type(QSizeF) function qsizef_boundedTo(self, other)
        class(QSizeF), intent(in) :: self
        type(QSizeF), intent(in) :: other
        qsizef_boundedTo = QSizeF(min(self%width, other%width), min(self%height, other%height))
    end function qsizef_boundedTo

    !> This size scaled to `size` (`mode` as for QSize%scaled).
    pure type(QSizeF) function qsizef_scaled(self, size, mode) result(s)
        class(QSizeF), intent(in) :: self
        type(QSizeF), intent(in) :: size
        integer, intent(in), optional :: mode
        real(dp) :: rw
        logical :: useHeight
        s = size
        if (.not. present(mode)) return
        if (mode == Qt_IgnoreAspectRatio .or. self%width == 0.0_dp .or. self%height == 0.0_dp) return
        rw = size%height * self%width / self%height
        if (mode == Qt_KeepAspectRatio) then
            useHeight = rw <= size%width
        else
            useHeight = rw >= size%width
        end if
        if (useHeight) then
            s = QSizeF(rw, size%height)
        else
            s = QSizeF(size%width, size%width * self%height / self%width)
        end if
    end function qsizef_scaled

    !> The size with rounded width and height.
    pure type(QSize) function qsizef_toSize(self)
        class(QSizeF), intent(in) :: self
        qsizef_toSize = QSize(round(self%width), round(self%height))
    end function qsizef_toSize

    !> Sum of two sizes.
    elemental type(QSizeF) function qsizef_add(a, b)
        type(QSizeF), intent(in) :: a, b
        qsizef_add = QSizeF(a%width + b%width, a%height + b%height)
    end function qsizef_add

    !> Difference of two sizes.
    elemental type(QSizeF) function qsizef_sub(a, b)
        type(QSizeF), intent(in) :: a, b
        qsizef_sub = QSizeF(a%width - b%width, a%height - b%height)
    end function qsizef_sub

    !> Size times a number.
    elemental type(QSizeF) function qsizef_mul_d(a, f)
        type(QSizeF), intent(in) :: a
        real(dp), intent(in) :: f
        qsizef_mul_d = QSizeF(a%width * f, a%height * f)
    end function qsizef_mul_d

    !> Number times a size.
    elemental type(QSizeF) function qsizef_d_mul(f, a)
        real(dp), intent(in) :: f
        type(QSizeF), intent(in) :: a
        qsizef_d_mul = QSizeF(a%width * f, a%height * f)
    end function qsizef_d_mul

    !> Size divided by a number.
    elemental type(QSizeF) function qsizef_div_d(a, f)
        type(QSizeF), intent(in) :: a
        real(dp), intent(in) :: f
        qsizef_div_d = QSizeF(a%width / f, a%height / f)
    end function qsizef_div_d

    !> True if two sizes are (fuzzily) equal.
    elemental logical function qsizef_eq(a, b)
        type(QSizeF), intent(in) :: a, b
        qsizef_eq = fuzzy_eq(a%width, b%width) .and. fuzzy_eq(a%height, b%height)
    end function qsizef_eq

    !> True if two sizes differ.
    elemental logical function qsizef_ne(a, b)
        type(QSizeF), intent(in) :: a, b
        qsizef_ne = .not. qsizef_eq(a, b)
    end function qsizef_ne

    ! ------------------------------------------------------------------
    ! QMargins

    !> True if all margins are 0.
    pure logical function qmargins_isNull(self)
        class(QMargins), intent(in) :: self
        qmargins_isNull = self%left == 0 .and. self%top == 0 .and. self%right == 0 .and. self%bottom == 0
    end function qmargins_isNull

    !> Sum of two margins.
    elemental type(QMargins) function qmargins_add(a, b)
        type(QMargins), intent(in) :: a, b
        qmargins_add = QMargins(a%left + b%left, a%top + b%top, a%right + b%right, a%bottom + b%bottom)
    end function qmargins_add

    !> Difference of two margins.
    elemental type(QMargins) function qmargins_sub(a, b)
        type(QMargins), intent(in) :: a, b
        qmargins_sub = QMargins(a%left - b%left, a%top - b%top, a%right - b%right, a%bottom - b%bottom)
    end function qmargins_sub

    !> Negated margins.
    elemental type(QMargins) function qmargins_neg(a)
        type(QMargins), intent(in) :: a
        qmargins_neg = QMargins(-a%left, -a%top, -a%right, -a%bottom)
    end function qmargins_neg

    !> True if two margins are equal.
    elemental logical function qmargins_eq(a, b)
        type(QMargins), intent(in) :: a, b
        qmargins_eq = a%left == b%left .and. a%top == b%top .and. a%right == b%right .and. a%bottom == b%bottom
    end function qmargins_eq

    !> True if two margins differ.
    elemental logical function qmargins_ne(a, b)
        type(QMargins), intent(in) :: a, b
        qmargins_ne = .not. qmargins_eq(a, b)
    end function qmargins_ne

    ! ------------------------------------------------------------------
    ! QRect

    !> A rectangle from its top-left corner and size.
    pure type(QRect) function qrect_fromPointSize(topLeft, size)
        type(QPoint), intent(in) :: topLeft
        type(QSize), intent(in) :: size
        qrect_fromPointSize = QRect(topLeft%x, topLeft%y, size%width, size%height)
    end function qrect_fromPointSize

    !> A rectangle from its top-left and bottom-right corners (both inside).
    pure type(QRect) function qrect_fromPoints(topLeft, bottomRight)
        type(QPoint), intent(in) :: topLeft, bottomRight
        qrect_fromPoints = QRect(topLeft%x, topLeft%y, bottomRight%x - topLeft%x + 1, bottomRight%y - topLeft%y + 1)
    end function qrect_fromPoints

    !> The left edge (x).
    pure integer function qrect_left(self)
        class(QRect), intent(in) :: self
        qrect_left = self%x
    end function qrect_left

    !> The top edge (y).
    pure integer function qrect_top(self)
        class(QRect), intent(in) :: self
        qrect_top = self%y
    end function qrect_top

    !> The last column inside: `x + width - 1`.
    pure integer function qrect_right(self)
        class(QRect), intent(in) :: self
        qrect_right = self%x + self%width - 1
    end function qrect_right

    !> The last row inside: `y + height - 1`.
    pure integer function qrect_bottom(self)
        class(QRect), intent(in) :: self
        qrect_bottom = self%y + self%height - 1
    end function qrect_bottom

    !> The top-left corner.
    pure type(QPoint) function qrect_topLeft(self)
        class(QRect), intent(in) :: self
        qrect_topLeft = QPoint(self%x, self%y)
    end function qrect_topLeft

    !> The top-right corner `(right(), top())`.
    pure type(QPoint) function qrect_topRight(self)
        class(QRect), intent(in) :: self
        qrect_topRight = QPoint(self%right(), self%y)
    end function qrect_topRight

    !> The bottom-left corner `(left(), bottom())`.
    pure type(QPoint) function qrect_bottomLeft(self)
        class(QRect), intent(in) :: self
        qrect_bottomLeft = QPoint(self%x, self%bottom())
    end function qrect_bottomLeft

    !> The bottom-right corner `(right(), bottom())`.
    pure type(QPoint) function qrect_bottomRight(self)
        class(QRect), intent(in) :: self
        qrect_bottomRight = QPoint(self%right(), self%bottom())
    end function qrect_bottomRight

    !> The center pixel (rounded towards the top left, as in Qt).
    pure type(QPoint) function qrect_center(self)
        class(QRect), intent(in) :: self
        qrect_center = QPoint(int((int(self%x, 8) + self%right()) / 2), int((int(self%y, 8) + self%bottom()) / 2))
    end function qrect_center

    !> The size.
    pure type(QSize) function qrect_size(self)
        class(QRect), intent(in) :: self
        qrect_size = QSize(self%width, self%height)
    end function qrect_size

    !> True if width and height are both 0.
    pure logical function qrect_isNull(self)
        class(QRect), intent(in) :: self
        qrect_isNull = self%width == 0 .and. self%height == 0
    end function qrect_isNull

    !> True if the rectangle contains no pixels (width or height < 1).
    pure logical function qrect_isEmpty(self)
        class(QRect), intent(in) :: self
        qrect_isEmpty = self%width < 1 .or. self%height < 1
    end function qrect_isEmpty

    !> True if width and height are both positive.
    pure logical function qrect_isValid(self)
        class(QRect), intent(in) :: self
        qrect_isValid = self%width > 0 .and. self%height > 0
    end function qrect_isValid

    !> The rectangle with a non-negative width and height (flipped if needed).
    pure type(QRect) function qrect_normalized(self) result(r)
        class(QRect), intent(in) :: self
        r = self
        if (r%width < 0) then
            r%x = r%x + r%width
            r%width = -r%width
        end if
        if (r%height < 0) then
            r%y = r%y + r%height
            r%height = -r%height
        end if
    end function qrect_normalized

    !> True if `point` is inside (or, unless `proper`, on the edge of) the rectangle.
    pure logical function qrect_containsPoint(self, point, proper) result(inside)
        class(QRect), intent(in) :: self
        type(QPoint), intent(in) :: point
        logical, intent(in), optional :: proper
        type(QRect) :: n
        logical :: strict
        strict = .false.
        if (present(proper)) strict = proper
        n = self%normalized()
        inside = .false.
        if (n%isEmpty()) return
        if (strict) then
            inside = point%x > n%x .and. point%x < n%right() .and. point%y > n%y .and. point%y < n%bottom()
        else
            inside = point%x >= n%x .and. point%x <= n%right() .and. point%y >= n%y .and. point%y <= n%bottom()
        end if
    end function qrect_containsPoint

    !> True if `rect` is inside (or, unless `proper`, on the edge of) the rectangle.
    pure logical function qrect_containsRect(self, rect, proper) result(inside)
        class(QRect), intent(in) :: self
        type(QRect), intent(in) :: rect
        logical, intent(in), optional :: proper
        type(QRect) :: a, b
        logical :: strict
        strict = .false.
        if (present(proper)) strict = proper
        a = self%normalized()
        b = rect%normalized()
        inside = .false.
        if (a%isEmpty() .or. b%isEmpty()) return
        if (strict) then
            inside = b%x > a%x .and. b%right() < a%right() .and. b%y > a%y .and. b%bottom() < a%bottom()
        else
            inside = b%x >= a%x .and. b%right() <= a%right() .and. b%y >= a%y .and. b%bottom() <= a%bottom()
        end if
    end function qrect_containsRect

    !> True if the rectangles share at least one pixel.
    pure logical function qrect_intersects(self, rect)
        class(QRect), intent(in) :: self
        type(QRect), intent(in) :: rect
        type(QRect) :: r
        r = self%intersected(rect)
        qrect_intersects = .not. r%isEmpty()
    end function qrect_intersects

    !> The overlap of the rectangles (an empty QRect() if none).
    pure type(QRect) function qrect_intersected(self, rect) result(r)
        class(QRect), intent(in) :: self
        type(QRect), intent(in) :: rect
        type(QRect) :: a, b
        integer :: l, t, rr, bb
        r = QRect()
        a = self%normalized()
        b = rect%normalized()
        if (a%isEmpty() .or. b%isEmpty()) return
        l = max(a%x, b%x)
        t = max(a%y, b%y)
        rr = min(a%right(), b%right())
        bb = min(a%bottom(), b%bottom())
        if (l > rr .or. t > bb) return
        r = QRect(l, t, rr - l + 1, bb - t + 1)
    end function qrect_intersected

    !> The bounding rectangle of both rectangles (a null rectangle is ignored).
    pure type(QRect) function qrect_united(self, rect) result(r)
        class(QRect), intent(in) :: self
        type(QRect), intent(in) :: rect
        type(QRect) :: a, b
        integer :: l, t, rr, bb
        if (self%isNull()) then
            r = rect
            return
        end if
        if (rect%isNull()) then
            r = self
            return
        end if
        a = self%normalized()
        b = rect%normalized()
        l = min(a%x, b%x)
        t = min(a%y, b%y)
        rr = max(a%right(), b%right())
        bb = max(a%bottom(), b%bottom())
        r = QRect(l, t, rr - l + 1, bb - t + 1)
    end function qrect_united

    !> The rectangle moved by (dx, dy).
    pure type(QRect) function qrect_translated(self, dx, dy)
        class(QRect), intent(in) :: self
        integer, intent(in) :: dx, dy
        qrect_translated = QRect(self%x + dx, self%y + dy, self%width, self%height)
    end function qrect_translated

    !> The rectangle moved by `offset`.
    pure type(QRect) function qrect_translatedPoint(self, offset)
        class(QRect), intent(in) :: self
        type(QPoint), intent(in) :: offset
        qrect_translatedPoint = QRect(self%x + offset%x, self%y + offset%y, self%width, self%height)
    end function qrect_translatedPoint

    !> The rectangle with dx1, dy1 added to its top-left and dx2, dy2 to its
    !> bottom-right corner.
    pure type(QRect) function qrect_adjusted(self, dx1, dy1, dx2, dy2)
        class(QRect), intent(in) :: self
        integer, intent(in) :: dx1, dy1, dx2, dy2
        qrect_adjusted = QRect(self%x + dx1, self%y + dy1, self%width + dx2 - dx1, self%height + dy2 - dy1)
    end function qrect_adjusted

    !> The rectangle grown by `margins`.
    pure type(QRect) function qrect_marginsAdded(self, margins)
        class(QRect), intent(in) :: self
        type(QMargins), intent(in) :: margins
        qrect_marginsAdded = self%adjusted(-margins%left, -margins%top, margins%right, margins%bottom)
    end function qrect_marginsAdded

    !> The rectangle shrunk by `margins`.
    pure type(QRect) function qrect_marginsRemoved(self, margins)
        class(QRect), intent(in) :: self
        type(QMargins), intent(in) :: margins
        qrect_marginsRemoved = self%adjusted(margins%left, margins%top, -margins%right, -margins%bottom)
    end function qrect_marginsRemoved

    !> Move the rectangle so that its top-left corner is at `topLeft` (the size is kept).
    pure subroutine qrect_moveTo(self, topLeft)
        class(QRect), intent(inout) :: self
        type(QPoint), intent(in) :: topLeft
        self%x = topLeft%x
        self%y = topLeft%y
    end subroutine qrect_moveTo

    !> Move the rectangle so that its center is at `center` (the size is kept).
    pure subroutine qrect_moveCenter(self, center)
        class(QRect), intent(inout) :: self
        type(QPoint), intent(in) :: center
        type(QPoint) :: c
        c = self%center()
        self%x = self%x + center%x - c%x
        self%y = self%y + center%y - c%y
    end subroutine qrect_moveCenter

    !> The rectangle as a QRectF.
    pure type(QRectF) function qrect_toRectF(self)
        class(QRect), intent(in) :: self
        qrect_toRectF = QRectF(real(self%x, dp), real(self%y, dp), real(self%width, dp), real(self%height, dp))
    end function qrect_toRectF

    !> `rect + margins`: the rectangle grown by the margins.
    elemental type(QRect) function qrect_plus_margins(rect, margins)
        type(QRect), intent(in) :: rect
        type(QMargins), intent(in) :: margins
        qrect_plus_margins = rect%marginsAdded(margins)
    end function qrect_plus_margins

    !> `rect - margins`: the rectangle shrunk by the margins.
    elemental type(QRect) function qrect_minus_margins(rect, margins)
        type(QRect), intent(in) :: rect
        type(QMargins), intent(in) :: margins
        qrect_minus_margins = rect%marginsRemoved(margins)
    end function qrect_minus_margins

    !> True if two rectangles are equal.
    elemental logical function qrect_eq(a, b)
        type(QRect), intent(in) :: a, b
        qrect_eq = a%x == b%x .and. a%y == b%y .and. a%width == b%width .and. a%height == b%height
    end function qrect_eq

    !> True if two rectangles differ.
    elemental logical function qrect_ne(a, b)
        type(QRect), intent(in) :: a, b
        qrect_ne = .not. qrect_eq(a, b)
    end function qrect_ne

    ! ------------------------------------------------------------------
    ! QRectF

    !> A rectangle from its top-left corner and size.
    pure type(QRectF) function qrectf_fromPointSize(topLeft, size)
        type(QPointF), intent(in) :: topLeft
        type(QSizeF), intent(in) :: size
        qrectf_fromPointSize = QRectF(topLeft%x, topLeft%y, size%width, size%height)
    end function qrectf_fromPointSize

    !> A rectangle from its top-left and bottom-right corners.
    pure type(QRectF) function qrectf_fromPoints(topLeft, bottomRight)
        type(QPointF), intent(in) :: topLeft, bottomRight
        qrectf_fromPoints = QRectF(topLeft%x, topLeft%y, bottomRight%x - topLeft%x, bottomRight%y - topLeft%y)
    end function qrectf_fromPoints

    !> A QRectF from a QRect.
    pure type(QRectF) function qrectf_fromRect(r)
        type(QRect), intent(in) :: r
        qrectf_fromRect = r%toRectF()
    end function qrectf_fromRect

    !> The left edge (x).
    pure real(dp) function qrectf_left(self)
        class(QRectF), intent(in) :: self
        qrectf_left = self%x
    end function qrectf_left

    !> The top edge (y).
    pure real(dp) function qrectf_top(self)
        class(QRectF), intent(in) :: self
        qrectf_top = self%y
    end function qrectf_top

    !> The right edge: `x + width`.
    pure real(dp) function qrectf_right(self)
        class(QRectF), intent(in) :: self
        qrectf_right = self%x + self%width
    end function qrectf_right

    !> The bottom edge: `y + height`.
    pure real(dp) function qrectf_bottom(self)
        class(QRectF), intent(in) :: self
        qrectf_bottom = self%y + self%height
    end function qrectf_bottom

    !> The top-left corner.
    pure type(QPointF) function qrectf_topLeft(self)
        class(QRectF), intent(in) :: self
        qrectf_topLeft = QPointF(self%x, self%y)
    end function qrectf_topLeft

    !> The top-right corner.
    pure type(QPointF) function qrectf_topRight(self)
        class(QRectF), intent(in) :: self
        qrectf_topRight = QPointF(self%x + self%width, self%y)
    end function qrectf_topRight

    !> The bottom-left corner.
    pure type(QPointF) function qrectf_bottomLeft(self)
        class(QRectF), intent(in) :: self
        qrectf_bottomLeft = QPointF(self%x, self%y + self%height)
    end function qrectf_bottomLeft

    !> The bottom-right corner.
    pure type(QPointF) function qrectf_bottomRight(self)
        class(QRectF), intent(in) :: self
        qrectf_bottomRight = QPointF(self%x + self%width, self%y + self%height)
    end function qrectf_bottomRight

    !> The center.
    pure type(QPointF) function qrectf_center(self)
        class(QRectF), intent(in) :: self
        qrectf_center = QPointF(self%x + self%width / 2, self%y + self%height / 2)
    end function qrectf_center

    !> The size.
    pure type(QSizeF) function qrectf_size(self)
        class(QRectF), intent(in) :: self
        qrectf_size = QSizeF(self%width, self%height)
    end function qrectf_size

    !> True if width and height are both 0.
    pure logical function qrectf_isNull(self)
        class(QRectF), intent(in) :: self
        qrectf_isNull = self%width == 0.0_dp .and. self%height == 0.0_dp
    end function qrectf_isNull

    !> True if width or height is not positive.
    pure logical function qrectf_isEmpty(self)
        class(QRectF), intent(in) :: self
        qrectf_isEmpty = self%width <= 0.0_dp .or. self%height <= 0.0_dp
    end function qrectf_isEmpty

    !> True if width and height are both positive.
    pure logical function qrectf_isValid(self)
        class(QRectF), intent(in) :: self
        qrectf_isValid = self%width > 0.0_dp .and. self%height > 0.0_dp
    end function qrectf_isValid

    !> The rectangle with a non-negative width and height.
    pure type(QRectF) function qrectf_normalized(self) result(r)
        class(QRectF), intent(in) :: self
        r = self
        if (r%width < 0.0_dp) then
            r%x = r%x + r%width
            r%width = -r%width
        end if
        if (r%height < 0.0_dp) then
            r%y = r%y + r%height
            r%height = -r%height
        end if
    end function qrectf_normalized

    !> True if `point` is inside or on the edge of the rectangle.
    pure logical function qrectf_containsPoint(self, point) result(inside)
        class(QRectF), intent(in) :: self
        type(QPointF), intent(in) :: point
        type(QRectF) :: n
        n = self%normalized()
        inside = .false.
        if (n%width == 0.0_dp .or. n%height == 0.0_dp) return
        inside = point%x >= n%x .and. point%x <= n%right() .and. point%y >= n%y .and. point%y <= n%bottom()
    end function qrectf_containsPoint

    !> True if `rect` is inside or on the edge of the rectangle.
    pure logical function qrectf_containsRect(self, rect) result(inside)
        class(QRectF), intent(in) :: self
        type(QRectF), intent(in) :: rect
        type(QRectF) :: a, b
        a = self%normalized()
        b = rect%normalized()
        inside = .false.
        if (a%width == 0.0_dp .or. a%height == 0.0_dp .or. b%width == 0.0_dp .or. b%height == 0.0_dp) return
        inside = b%x >= a%x .and. b%right() <= a%right() .and. b%y >= a%y .and. b%bottom() <= a%bottom()
    end function qrectf_containsRect

    !> True if the rectangles overlap (touching edges do not count).
    pure logical function qrectf_intersects(self, rect)
        class(QRectF), intent(in) :: self
        type(QRectF), intent(in) :: rect
        type(QRectF) :: a, b
        a = self%normalized()
        b = rect%normalized()
        qrectf_intersects = max(a%x, b%x) < min(a%right(), b%right()) .and. &
                            max(a%y, b%y) < min(a%bottom(), b%bottom())
    end function qrectf_intersects

    !> The overlap of the rectangles (an empty QRectF() if none).
    pure type(QRectF) function qrectf_intersected(self, rect) result(r)
        class(QRectF), intent(in) :: self
        type(QRectF), intent(in) :: rect
        type(QRectF) :: a, b
        real(dp) :: l, t, rr, bb
        r = QRectF()
        if (.not. self%intersects(rect)) return
        a = self%normalized()
        b = rect%normalized()
        l = max(a%x, b%x)
        t = max(a%y, b%y)
        rr = min(a%right(), b%right())
        bb = min(a%bottom(), b%bottom())
        r = QRectF(l, t, rr - l, bb - t)
    end function qrectf_intersected

    !> The bounding rectangle of both rectangles (a null rectangle is ignored).
    pure type(QRectF) function qrectf_united(self, rect) result(r)
        class(QRectF), intent(in) :: self
        type(QRectF), intent(in) :: rect
        type(QRectF) :: a, b
        real(dp) :: l, t, rr, bb
        if (self%isNull()) then
            r = rect
            return
        end if
        if (rect%isNull()) then
            r = self
            return
        end if
        a = self%normalized()
        b = rect%normalized()
        l = min(a%x, b%x)
        t = min(a%y, b%y)
        rr = max(a%right(), b%right())
        bb = max(a%bottom(), b%bottom())
        r = QRectF(l, t, rr - l, bb - t)
    end function qrectf_united

    !> The rectangle moved by (dx, dy).
    pure type(QRectF) function qrectf_translated(self, dx, dy)
        class(QRectF), intent(in) :: self
        real(dp), intent(in) :: dx, dy
        qrectf_translated = QRectF(self%x + dx, self%y + dy, self%width, self%height)
    end function qrectf_translated

    !> The rectangle moved by `offset`.
    pure type(QRectF) function qrectf_translatedPoint(self, offset)
        class(QRectF), intent(in) :: self
        type(QPointF), intent(in) :: offset
        qrectf_translatedPoint = QRectF(self%x + offset%x, self%y + offset%y, self%width, self%height)
    end function qrectf_translatedPoint

    !> The rectangle with dx1, dy1 added to its top-left and dx2, dy2 to its
    !> bottom-right corner.
    pure type(QRectF) function qrectf_adjusted(self, dx1, dy1, dx2, dy2)
        class(QRectF), intent(in) :: self
        real(dp), intent(in) :: dx1, dy1, dx2, dy2
        qrectf_adjusted = QRectF(self%x + dx1, self%y + dy1, self%width + dx2 - dx1, self%height + dy2 - dy1)
    end function qrectf_adjusted

    !> Move the rectangle so that its top-left corner is at `topLeft` (the size is kept).
    pure subroutine qrectf_moveTo(self, topLeft)
        class(QRectF), intent(inout) :: self
        type(QPointF), intent(in) :: topLeft
        self%x = topLeft%x
        self%y = topLeft%y
    end subroutine qrectf_moveTo

    !> Move the rectangle so that its center is at `center` (the size is kept).
    pure subroutine qrectf_moveCenter(self, center)
        class(QRectF), intent(inout) :: self
        type(QPointF), intent(in) :: center
        self%x = center%x - self%width / 2
        self%y = center%y - self%height / 2
    end subroutine qrectf_moveCenter

    !> The rectangle rounded to whole pixels (as Qt 6: the corners and the size
    !> each move by less than a pixel).
    pure type(QRect) function qrectf_toRect(self)
        class(QRectF), intent(in) :: self
        integer :: l, t
        l = round(self%x)
        t = round(self%y)
        qrectf_toRect = QRect(l, t, round(self%width + (self%x - l) / 2), round(self%height + (self%y - t) / 2))
    end function qrectf_toRect

    !> The smallest integer rectangle that contains this one.
    pure type(QRect) function qrectf_toAlignedRect(self)
        class(QRectF), intent(in) :: self
        integer :: l, t
        l = floor(self%x)
        t = floor(self%y)
        qrectf_toAlignedRect = QRect(l, t, ceiling(self%x + self%width) - l, ceiling(self%y + self%height) - t)
    end function qrectf_toAlignedRect

    !> `rect + margins`: the rectangle grown by the margins.
    elemental type(QRectF) function qrectf_plus_margins(rect, margins)
        type(QRectF), intent(in) :: rect
        type(QMargins), intent(in) :: margins
        qrectf_plus_margins = rect%adjusted(real(-margins%left, dp), real(-margins%top, dp), &
                                            real(margins%right, dp), real(margins%bottom, dp))
    end function qrectf_plus_margins

    !> True if two rectangles are (fuzzily) equal.
    elemental logical function qrectf_eq(a, b)
        type(QRectF), intent(in) :: a, b
        qrectf_eq = fuzzy_eq(a%x, b%x) .and. fuzzy_eq(a%y, b%y) .and. &
                    fuzzy_eq(a%width, b%width) .and. fuzzy_eq(a%height, b%height)
    end function qrectf_eq

    !> True if two rectangles differ.
    elemental logical function qrectf_ne(a, b)
        type(QRectF), intent(in) :: a, b
        qrectf_ne = .not. qrectf_eq(a, b)
    end function qrectf_ne

    ! ------------------------------------------------------------------
    ! QLineF

    !> The line from `p1` to `p2`.
    pure type(QLineF) function qlinef_fromPoints(p1, p2)
        type(QPointF), intent(in) :: p1, p2
        qlinef_fromPoints = QLineF(p1%x, p1%y, p2%x, p2%y)
    end function qlinef_fromPoints

    !> A line from (0, 0) with the given length and angle (degrees).
    pure type(QLineF) function QLineF_fromPolar(length, angle)
        real(dp), intent(in) :: length, angle
        real(dp) :: a
        a = angle * acos(-1.0_dp) / 180
        QLineF_fromPolar = QLineF(0.0_dp, 0.0_dp, cos(a) * length, -sin(a) * length)
    end function QLineF_fromPolar

    !> The start point.
    pure type(QPointF) function qlinef_p1(self)
        class(QLineF), intent(in) :: self
        qlinef_p1 = QPointF(self%x1, self%y1)
    end function qlinef_p1

    !> The end point.
    pure type(QPointF) function qlinef_p2(self)
        class(QLineF), intent(in) :: self
        qlinef_p2 = QPointF(self%x2, self%y2)
    end function qlinef_p2

    !> `x2 - x1`.
    pure real(dp) function qlinef_dx(self)
        class(QLineF), intent(in) :: self
        qlinef_dx = self%x2 - self%x1
    end function qlinef_dx

    !> `y2 - y1`.
    pure real(dp) function qlinef_dy(self)
        class(QLineF), intent(in) :: self
        qlinef_dy = self%y2 - self%y1
    end function qlinef_dy

    !> True if the start and end points are the same.
    pure logical function qlinef_isNull(self)
        class(QLineF), intent(in) :: self
        qlinef_isNull = fuzzy_eq(self%x1, self%x2) .and. fuzzy_eq(self%y1, self%y2)
    end function qlinef_isNull

    !> The length of the line.
    pure real(dp) function qlinef_length(self)
        class(QLineF), intent(in) :: self
        qlinef_length = hypot(self%dx(), self%dy())
    end function qlinef_length

    !> Change the length, keeping the start point and direction (no change for a null line).
    pure subroutine qlinef_setLength(self, length)
        class(QLineF), intent(inout) :: self
        real(dp), intent(in) :: length
        real(dp) :: l
        l = self%length()
        if (l == 0.0_dp) return
        self%x2 = self%x1 + self%dx() * (length / l)
        self%y2 = self%y1 + self%dy() * (length / l)
    end subroutine qlinef_setLength

    !> The angle of the line in degrees (0 to 360), counterclockwise from 3 o'clock.
    pure real(dp) function qlinef_angle(self)
        class(QLineF), intent(in) :: self
        qlinef_angle = atan2(-self%dy(), self%dx()) * 180 / acos(-1.0_dp)
        if (qlinef_angle < 0.0_dp) qlinef_angle = qlinef_angle + 360
        if (fuzzy_eq(qlinef_angle, 360.0_dp)) qlinef_angle = 0.0_dp
    end function qlinef_angle

    !> Change the angle (degrees), keeping the start point and length.
    pure subroutine qlinef_setAngle(self, angle)
        class(QLineF), intent(inout) :: self
        real(dp), intent(in) :: angle
        type(QLineF) :: polar
        polar = QLineF_fromPolar(self%length(), angle)
        self%x2 = self%x1 + polar%x2
        self%y2 = self%y1 + polar%y2
    end subroutine qlinef_setAngle

    !> The angle (degrees, 0 to 360) from this line to `line`, counterclockwise.
    pure real(dp) function qlinef_angleTo(self, line)
        class(QLineF), intent(in) :: self
        type(QLineF), intent(in) :: line
        if (self%isNull() .or. line%isNull()) then
            qlinef_angleTo = 0.0_dp
            return
        end if
        qlinef_angleTo = line%angle() - self%angle()
        if (qlinef_angleTo < 0.0_dp) qlinef_angleTo = qlinef_angleTo + 360
        if (fuzzy_eq(qlinef_angleTo, 360.0_dp)) qlinef_angleTo = 0.0_dp
    end function qlinef_angleTo

    !> The midpoint.
    pure type(QPointF) function qlinef_center(self)
        class(QLineF), intent(in) :: self
        qlinef_center = QPointF((self%x1 + self%x2) / 2, (self%y1 + self%y2) / 2)
    end function qlinef_center

    !> The point at fraction `t` along the line (0: start, 1: end).
    pure type(QPointF) function qlinef_pointAt(self, t)
        class(QLineF), intent(in) :: self
        real(dp), intent(in) :: t
        qlinef_pointAt = QPointF(self%x1 + self%dx() * t, self%y1 + self%dy() * t)
    end function qlinef_pointAt

    !> A line of length 1 from the start point in the same direction.
    pure type(QLineF) function qlinef_unitVector(self) result(u)
        class(QLineF), intent(in) :: self
        real(dp) :: l
        u = self
        l = self%length()
        if (l == 0.0_dp) return
        u = QLineF(self%x1, self%y1, self%x1 + self%dx() / l, self%y1 + self%dy() / l)
    end function qlinef_unitVector

    !> A line from the start point, perpendicular to this one, with the same length.
    pure type(QLineF) function qlinef_normalVector(self)
        class(QLineF), intent(in) :: self
        qlinef_normalVector = QLineF(self%x1, self%y1, self%x1 + self%dy(), self%y1 - self%dx())
    end function qlinef_normalVector

    !> How this line and `line` intersect (QLineF_NoIntersection, _BoundedIntersection
    !> or _UnboundedIntersection); `point` receives the intersection point of the
    !> infinite lines (unchanged when they are parallel).
    function qlinef_intersects(self, line, point) result(kind)
        class(QLineF), intent(in) :: self
        type(QLineF), intent(in) :: line
        type(QPointF), intent(out), optional :: point
        integer :: kind
        real(dp) :: ax, ay, bx, by, cx, cy, denom, reciprocal, na, nb
        ax = self%dx()
        ay = self%dy()
        bx = line%x1 - line%x2
        by = line%y1 - line%y2
        denom = ay * bx - ax * by
        if (denom == 0.0_dp .or. .not. is_finite(denom)) then
            kind = QLineF_NoIntersection
            return
        end if
        cx = self%x1 - line%x1
        cy = self%y1 - line%y1
        reciprocal = 1 / denom
        na = (by * cx - bx * cy) * reciprocal
        if (present(point)) point = self%pointAt(na)
        if (na < 0.0_dp .or. na > 1.0_dp) then
            kind = QLineF_UnboundedIntersection
            return
        end if
        nb = (ax * cy - ay * cx) * reciprocal
        if (nb < 0.0_dp .or. nb > 1.0_dp) then
            kind = QLineF_UnboundedIntersection
        else
            kind = QLineF_BoundedIntersection
        end if
    contains
        !> True if `v` is neither infinite nor NaN.
        pure logical function is_finite(v)
            real(dp), intent(in) :: v
            is_finite = abs(v) <= huge(v)
        end function is_finite
    end function qlinef_intersects

    !> The line moved by (dx, dy).
    pure type(QLineF) function qlinef_translated(self, dx, dy)
        class(QLineF), intent(in) :: self
        real(dp), intent(in) :: dx, dy
        qlinef_translated = QLineF(self%x1 + dx, self%y1 + dy, self%x2 + dx, self%y2 + dy)
    end function qlinef_translated

    !> The line moved by `offset`.
    pure type(QLineF) function qlinef_translatedPoint(self, offset)
        class(QLineF), intent(in) :: self
        type(QPointF), intent(in) :: offset
        qlinef_translatedPoint = self%translated(offset%x, offset%y)
    end function qlinef_translatedPoint

    !> True if two lines are (fuzzily) equal.
    elemental logical function qlinef_eq(a, b)
        type(QLineF), intent(in) :: a, b
        qlinef_eq = fuzzy_eq(a%x1, b%x1) .and. fuzzy_eq(a%y1, b%y1) .and. &
                    fuzzy_eq(a%x2, b%x2) .and. fuzzy_eq(a%y2, b%y2)
    end function qlinef_eq

    !> True if two lines differ.
    elemental logical function qlinef_ne(a, b)
        type(QLineF), intent(in) :: a, b
        qlinef_ne = .not. qlinef_eq(a, b)
    end function qlinef_ne

end module qt_geometry
