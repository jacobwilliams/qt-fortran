!> Qt's vector and quaternion value types for 2D/3D math, in pure Fortran:
!> QVector2D, QVector3D, QVector4D and QQuaternion.
!>
!> These are plain Fortran types with public components (`v%x`, `q%scalar`), in
!> double precision like QMatrix4x4 (Qt itself uses single precision). They have
!> Qt's methods and the usual operators:
!>
!>     type(QVector3D) :: a, b, n
!>     type(QQuaternion) :: q
!>     a = QVector3D(1, 0, 0)
!>     b = QVector3D([0.0_c_double, 1.0_c_double, 0.0_c_double])
!>     n = QVector3D_crossProduct(a, b)                   ! (0, 0, 1)
!>     q = QQuaternion_fromAxisAndAngle(n, 90.0_c_double)
!>     b = q%rotatedVector(a)                             ! (0, 1, 0)
!>
!> `toArray()` gives the components as an array, e.g. for QMatrix4x4 or OpenGL
!> buffers. Angles are in degrees. Vectors compare (`==`) to within a relative
!> 1e-12, as Qt compares them fuzzily.
module qt_vectors

    use iso_c_binding, only: c_double
    use qt_geometry, only: QPoint, QPointF
    implicit none
    private

    integer, parameter :: dp = c_double
    real(dp), parameter :: pi = acos(-1.0_dp)
    real(dp), parameter :: deg = pi / 180   ! radians per degree

    ! ------------------------------------------------------------------
    ! types

    !> A 2D vector: `QVector2D(x, y)`, `QVector2D(array)` or `QVector2D(point)`.
    type, public :: QVector2D
        real(dp) :: x = 0.0_dp   !! x component
        real(dp) :: y = 0.0_dp   !! y component
    contains
        procedure :: isNull => qvector2d_isNull
        procedure :: length => qvector2d_length
        procedure :: lengthSquared => qvector2d_lengthSquared
        procedure :: normalized => qvector2d_normalized
        procedure :: normalize => qvector2d_normalize
        procedure :: distanceToPoint => qvector2d_distanceToPoint
        procedure :: distanceToLine => qvector2d_distanceToLine
        procedure :: toVector3D => qvector2d_toVector3D
        procedure :: toVector4D => qvector2d_toVector4D
        procedure :: toPoint => qvector2d_toPoint
        procedure :: toPointF => qvector2d_toPointF
        procedure :: toArray => qvector2d_toArray
    end type QVector2D
    !> `QVector2D(x, y)` is the structure constructor; also `QVector2D(array)`,
    !> `QVector2D(QPoint)` and `QVector2D(QPointF)`.
    interface QVector2D
        module procedure :: qvector2d_fromArray, qvector2d_fromPoint, qvector2d_fromPointF
    end interface QVector2D

    !> A 3D vector or point: `QVector3D(x, y, z)`, `QVector3D(array)` or
    !> `QVector3D(vector2d, z)`.
    type, public :: QVector3D
        real(dp) :: x = 0.0_dp   !! x component
        real(dp) :: y = 0.0_dp   !! y component
        real(dp) :: z = 0.0_dp   !! z component
    contains
        procedure :: isNull => qvector3d_isNull
        procedure :: length => qvector3d_length
        procedure :: lengthSquared => qvector3d_lengthSquared
        procedure :: normalized => qvector3d_normalized
        procedure :: normalize => qvector3d_normalize
        procedure :: distanceToPoint => qvector3d_distanceToPoint
        procedure :: distanceToLine => qvector3d_distanceToLine
        procedure, private :: qvector3d_distanceToPlane, qvector3d_distanceToPlane3
        generic :: distanceToPlane => qvector3d_distanceToPlane, qvector3d_distanceToPlane3
        procedure :: toVector2D => qvector3d_toVector2D
        procedure :: toVector4D => qvector3d_toVector4D
        procedure :: toPoint => qvector3d_toPoint
        procedure :: toPointF => qvector3d_toPointF
        procedure :: toArray => qvector3d_toArray
    end type QVector3D
    !> `QVector3D(x, y, z)` is the structure constructor; also `QVector3D(array)`
    !> and `QVector3D(vector2d [, z])`.
    interface QVector3D
        module procedure :: qvector3d_fromArray, qvector3d_fromVector2D
    end interface QVector3D

    !> A 4D vector (e.g. homogeneous coordinates or RGBA): `QVector4D(x, y, z, w)`,
    !> `QVector4D(array)` or `QVector4D(vector3d, w)`.
    type, public :: QVector4D
        real(dp) :: x = 0.0_dp   !! x component
        real(dp) :: y = 0.0_dp   !! y component
        real(dp) :: z = 0.0_dp   !! z component
        real(dp) :: w = 0.0_dp   !! w component
    contains
        procedure :: isNull => qvector4d_isNull
        procedure :: length => qvector4d_length
        procedure :: lengthSquared => qvector4d_lengthSquared
        procedure :: normalized => qvector4d_normalized
        procedure :: normalize => qvector4d_normalize
        procedure :: toVector2D => qvector4d_toVector2D
        procedure :: toVector2DAffine => qvector4d_toVector2DAffine
        procedure :: toVector3D => qvector4d_toVector3D
        procedure :: toVector3DAffine => qvector4d_toVector3DAffine
        procedure :: toPoint => qvector4d_toPoint
        procedure :: toPointF => qvector4d_toPointF
        procedure :: toArray => qvector4d_toArray
    end type QVector4D
    !> `QVector4D(x, y, z, w)` is the structure constructor; also `QVector4D(array)`,
    !> `QVector4D(vector3d [, w])` and `QVector4D(vector2d [, z, w])`.
    interface QVector4D
        module procedure :: qvector4d_fromArray, qvector4d_fromVector3D, qvector4d_fromVector2D
    end interface QVector4D

    !> A quaternion `scalar + x i + y j + z k`, used for 3D rotations:
    !> `QQuaternion(scalar, x, y, z)` or `QQuaternion(scalar, vector3d)`.
    !> The default is the identity (no rotation). Build rotations with
    !> QQuaternion_fromAxisAndAngle, QQuaternion_fromEulerAngles, ...
    type, public :: QQuaternion
        real(dp) :: scalar = 1.0_dp   !! the scalar (real) part
        real(dp) :: x = 0.0_dp        !! the i component
        real(dp) :: y = 0.0_dp        !! the j component
        real(dp) :: z = 0.0_dp        !! the k component
    contains
        procedure :: isNull => qquaternion_isNull
        procedure :: isIdentity => qquaternion_isIdentity
        procedure :: vector => qquaternion_vector
        procedure :: length => qquaternion_length
        procedure :: lengthSquared => qquaternion_lengthSquared
        procedure :: normalized => qquaternion_normalized
        procedure :: normalize => qquaternion_normalize
        procedure :: conjugated => qquaternion_conjugated
        procedure :: inverted => qquaternion_inverted
        procedure :: rotatedVector => qquaternion_rotatedVector
        procedure :: getAxisAndAngle => qquaternion_getAxisAndAngle
        procedure :: toEulerAngles => qquaternion_toEulerAngles
        procedure :: toRotationMatrix => qquaternion_toRotationMatrix
        procedure :: toVector4D => qquaternion_toVector4D
    end type QQuaternion
    !> `QQuaternion(scalar, x, y, z)` is the structure constructor; also
    !> `QQuaternion(scalar, vector3d)` and `QQuaternion(vector4d)` (w is the scalar).
    interface QQuaternion
        module procedure :: qquaternion_fromScalarVector, qquaternion_fromVector4D
    end interface QQuaternion

    public :: QVector2D_dotProduct
    public :: QVector3D_dotProduct, QVector3D_crossProduct, QVector3D_normal
    public :: QVector4D_dotProduct
    public :: QQuaternion_dotProduct, QQuaternion_fromAxisAndAngle, QQuaternion_fromEulerAngles
    public :: QQuaternion_fromRotationMatrix, QQuaternion_fromAxes, QQuaternion_fromDirection
    public :: QQuaternion_rotationTo, QQuaternion_slerp, QQuaternion_nlerp

    !> `QVector3D_normal(v1, v2)`: the unit normal of the plane through the origin
    !> spanned by v1 and v2; `QVector3D_normal(v1, v2, v3)`: of the plane through
    !> the three points.
    interface QVector3D_normal
        module procedure :: qvector3d_normal2, qvector3d_normal3
    end interface QVector3D_normal

    !> `QQuaternion_fromAxisAndAngle(axis, angle)` or `(x, y, z, angle)`: a rotation
    !> of `angle` degrees about the axis.
    interface QQuaternion_fromAxisAndAngle
        module procedure :: qquaternion_fromAxisAndAngle_v, qquaternion_fromAxisAndAngle_xyz
    end interface QQuaternion_fromAxisAndAngle

    !> `QQuaternion_fromEulerAngles(pitch, yaw, roll)` or `(angles)` (x = pitch,
    !> y = yaw, z = roll; degrees): rotation about z by roll, then about x by pitch,
    !> then about y by yaw.
    interface QQuaternion_fromEulerAngles
        module procedure :: qquaternion_fromEulerAngles_xyz, qquaternion_fromEulerAngles_v
    end interface QQuaternion_fromEulerAngles

    ! ------------------------------------------------------------------
    ! operators

    !> Sum of vectors or quaternions.
    interface operator(+)
        module procedure :: qvector2d_add, qvector3d_add, qvector4d_add, qquaternion_add
    end interface operator(+)

    !> Difference (or negation) of vectors or quaternions.
    interface operator(-)
        module procedure :: qvector2d_sub, qvector3d_sub, qvector4d_sub, qquaternion_sub
        module procedure :: qvector2d_neg, qvector3d_neg, qvector4d_neg, qquaternion_neg
    end interface operator(-)

    !> Vector times number (or component-wise vector times vector); quaternion
    !> product (rotation composition: `q1 * q2` applies q2 first); quaternion
    !> times a QVector3D rotates the vector.
    interface operator(*)
        module procedure :: qvector2d_mul_d, qvector2d_d_mul, qvector2d_mul_v
        module procedure :: qvector3d_mul_d, qvector3d_d_mul, qvector3d_mul_v
        module procedure :: qvector4d_mul_d, qvector4d_d_mul, qvector4d_mul_v
        module procedure :: qquaternion_mul_d, qquaternion_d_mul, qquaternion_mul_q, qquaternion_mul_v3
    end interface operator(*)

    !> Vector divided by a number (or component-wise by a vector); quaternion
    !> divided by a number.
    interface operator(/)
        module procedure :: qvector2d_div_d, qvector2d_div_v, qvector3d_div_d, qvector3d_div_v
        module procedure :: qvector4d_div_d, qvector4d_div_v, qquaternion_div_d
    end interface operator(/)

    !> Equality to within a relative 1e-12.
    interface operator(==)
        module procedure :: qvector2d_eq, qvector3d_eq, qvector4d_eq, qquaternion_eq
    end interface operator(==)

    !> Inequality: `.not. (a == b)`.
    interface operator(/=)
        module procedure :: qvector2d_ne, qvector3d_ne, qvector4d_ne, qquaternion_ne
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

    !> True if `a` is 0 to within 1e-12.
    elemental logical function fuzzy_zero(a)
        real(dp), intent(in) :: a
        fuzzy_zero = abs(a) <= 1.0e-12_dp
    end function fuzzy_zero

    !> Round to the nearest integer, halfway cases away from zero (as qRound).
    elemental integer function round(a)
        real(dp), intent(in) :: a
        round = nint(a)
    end function round

    ! ------------------------------------------------------------------
    ! QVector2D

    !> A vector from the first two elements of an array.
    pure type(QVector2D) function qvector2d_fromArray(a)
        real(dp), intent(in) :: a(:)
        qvector2d_fromArray = QVector2D(a(1), a(2))
    end function qvector2d_fromArray

    !> A vector from a QPoint.
    pure type(QVector2D) function qvector2d_fromPoint(p)
        type(QPoint), intent(in) :: p
        qvector2d_fromPoint = QVector2D(real(p%x, dp), real(p%y, dp))
    end function qvector2d_fromPoint

    !> A vector from a QPointF.
    pure type(QVector2D) function qvector2d_fromPointF(p)
        type(QPointF), intent(in) :: p
        qvector2d_fromPointF = QVector2D(p%x, p%y)
    end function qvector2d_fromPointF

    !> True if all components are 0.
    pure logical function qvector2d_isNull(self)
        class(QVector2D), intent(in) :: self
        qvector2d_isNull = self%x == 0.0_dp .and. self%y == 0.0_dp
    end function qvector2d_isNull

    !> The length.
    pure real(dp) function qvector2d_length(self)
        class(QVector2D), intent(in) :: self
        qvector2d_length = hypot(self%x, self%y)
    end function qvector2d_length

    !> The squared length (cheaper than `length()`).
    pure real(dp) function qvector2d_lengthSquared(self)
        class(QVector2D), intent(in) :: self
        qvector2d_lengthSquared = self%x**2 + self%y**2
    end function qvector2d_lengthSquared

    !> The unit vector in the same direction (a null vector stays null).
    pure type(QVector2D) function qvector2d_normalized(self) result(v)
        class(QVector2D), intent(in) :: self
        real(dp) :: l
        l = self%length()
        v = QVector2D()
        if (l > 0.0_dp) v = QVector2D(self%x / l, self%y / l)
    end function qvector2d_normalized

    !> Scale the vector to length 1 (a null vector stays null).
    pure subroutine qvector2d_normalize(self)
        class(QVector2D), intent(inout) :: self
        type(QVector2D) :: v
        v = self%normalized()
        self%x = v%x
        self%y = v%y
    end subroutine qvector2d_normalize

    !> The distance from this point to `point`.
    pure real(dp) function qvector2d_distanceToPoint(self, point)
        class(QVector2D), intent(in) :: self
        type(QVector2D), intent(in) :: point
        qvector2d_distanceToPoint = hypot(self%x - point%x, self%y - point%y)
    end function qvector2d_distanceToPoint

    !> The distance from this point to the infinite line through `point` with
    !> `direction` (to `point` if `direction` is null).
    pure real(dp) function qvector2d_distanceToLine(self, point, direction) result(d)
        class(QVector2D), intent(in) :: self
        type(QVector2D), intent(in) :: point, direction
        type(QVector2D) :: u, p
        if (direction%isNull()) then
            d = self%distanceToPoint(point)
            return
        end if
        u = direction%normalized()
        p = point + u * QVector2D_dotProduct(QVector2D(self%x, self%y) - point, u)
        d = self%distanceToPoint(p)
    end function qvector2d_distanceToLine

    !> The vector as a QVector3D with the given z (default 0).
    pure type(QVector3D) function qvector2d_toVector3D(self, z)
        class(QVector2D), intent(in) :: self
        real(dp), intent(in), optional :: z
        qvector2d_toVector3D = QVector3D(self%x, self%y, 0.0_dp)
        if (present(z)) qvector2d_toVector3D%z = z
    end function qvector2d_toVector3D

    !> The vector as a QVector4D (z = w = 0).
    pure type(QVector4D) function qvector2d_toVector4D(self)
        class(QVector2D), intent(in) :: self
        qvector2d_toVector4D = QVector4D(self%x, self%y, 0.0_dp, 0.0_dp)
    end function qvector2d_toVector4D

    !> The vector as a QPoint (rounded).
    pure type(QPoint) function qvector2d_toPoint(self)
        class(QVector2D), intent(in) :: self
        qvector2d_toPoint = QPoint(round(self%x), round(self%y))
    end function qvector2d_toPoint

    !> The vector as a QPointF.
    pure type(QPointF) function qvector2d_toPointF(self)
        class(QVector2D), intent(in) :: self
        qvector2d_toPointF = QPointF(self%x, self%y)
    end function qvector2d_toPointF

    !> The components as an array `[x, y]`.
    pure function qvector2d_toArray(self) result(a)
        class(QVector2D), intent(in) :: self
        real(dp) :: a(2)
        a = [self%x, self%y]
    end function qvector2d_toArray

    !> Dot product.
    pure real(dp) function QVector2D_dotProduct(a, b)
        type(QVector2D), intent(in) :: a, b
        QVector2D_dotProduct = a%x * b%x + a%y * b%y
    end function QVector2D_dotProduct

    !> Sum.
    elemental type(QVector2D) function qvector2d_add(a, b)
        type(QVector2D), intent(in) :: a, b
        qvector2d_add = QVector2D(a%x + b%x, a%y + b%y)
    end function qvector2d_add

    !> Difference.
    elemental type(QVector2D) function qvector2d_sub(a, b)
        type(QVector2D), intent(in) :: a, b
        qvector2d_sub = QVector2D(a%x - b%x, a%y - b%y)
    end function qvector2d_sub

    !> Negation.
    elemental type(QVector2D) function qvector2d_neg(a)
        type(QVector2D), intent(in) :: a
        qvector2d_neg = QVector2D(-a%x, -a%y)
    end function qvector2d_neg

    !> Vector times number.
    elemental type(QVector2D) function qvector2d_mul_d(a, f)
        type(QVector2D), intent(in) :: a
        real(dp), intent(in) :: f
        qvector2d_mul_d = QVector2D(a%x * f, a%y * f)
    end function qvector2d_mul_d

    !> Number times vector.
    elemental type(QVector2D) function qvector2d_d_mul(f, a)
        real(dp), intent(in) :: f
        type(QVector2D), intent(in) :: a
        qvector2d_d_mul = QVector2D(a%x * f, a%y * f)
    end function qvector2d_d_mul

    !> Component-wise product.
    elemental type(QVector2D) function qvector2d_mul_v(a, b)
        type(QVector2D), intent(in) :: a, b
        qvector2d_mul_v = QVector2D(a%x * b%x, a%y * b%y)
    end function qvector2d_mul_v

    !> Vector divided by number.
    elemental type(QVector2D) function qvector2d_div_d(a, f)
        type(QVector2D), intent(in) :: a
        real(dp), intent(in) :: f
        qvector2d_div_d = QVector2D(a%x / f, a%y / f)
    end function qvector2d_div_d

    !> Component-wise quotient.
    elemental type(QVector2D) function qvector2d_div_v(a, b)
        type(QVector2D), intent(in) :: a, b
        qvector2d_div_v = QVector2D(a%x / b%x, a%y / b%y)
    end function qvector2d_div_v

    !> True if the vectors are (fuzzily) equal.
    elemental logical function qvector2d_eq(a, b)
        type(QVector2D), intent(in) :: a, b
        qvector2d_eq = fuzzy_eq(a%x, b%x) .and. fuzzy_eq(a%y, b%y)
    end function qvector2d_eq

    !> True if the vectors differ.
    elemental logical function qvector2d_ne(a, b)
        type(QVector2D), intent(in) :: a, b
        qvector2d_ne = .not. qvector2d_eq(a, b)
    end function qvector2d_ne

    ! ------------------------------------------------------------------
    ! QVector3D

    !> A vector from the first three elements of an array.
    pure type(QVector3D) function qvector3d_fromArray(a)
        real(dp), intent(in) :: a(:)
        qvector3d_fromArray = QVector3D(a(1), a(2), a(3))
    end function qvector3d_fromArray

    !> A vector from a QVector2D and z (default 0).
    pure type(QVector3D) function qvector3d_fromVector2D(v, z)
        type(QVector2D), intent(in) :: v
        real(dp), intent(in), optional :: z
        qvector3d_fromVector2D = v%toVector3D(z)
    end function qvector3d_fromVector2D

    !> True if all components are 0.
    pure logical function qvector3d_isNull(self)
        class(QVector3D), intent(in) :: self
        qvector3d_isNull = self%x == 0.0_dp .and. self%y == 0.0_dp .and. self%z == 0.0_dp
    end function qvector3d_isNull

    !> The length.
    pure real(dp) function qvector3d_length(self)
        class(QVector3D), intent(in) :: self
        qvector3d_length = norm2([self%x, self%y, self%z])
    end function qvector3d_length

    !> The squared length (cheaper than `length()`).
    pure real(dp) function qvector3d_lengthSquared(self)
        class(QVector3D), intent(in) :: self
        qvector3d_lengthSquared = self%x**2 + self%y**2 + self%z**2
    end function qvector3d_lengthSquared

    !> The unit vector in the same direction (a null vector stays null).
    pure type(QVector3D) function qvector3d_normalized(self) result(v)
        class(QVector3D), intent(in) :: self
        real(dp) :: l
        l = self%length()
        v = QVector3D()
        if (l > 0.0_dp) v = QVector3D(self%x / l, self%y / l, self%z / l)
    end function qvector3d_normalized

    !> Scale the vector to length 1 (a null vector stays null).
    pure subroutine qvector3d_normalize(self)
        class(QVector3D), intent(inout) :: self
        type(QVector3D) :: v
        v = self%normalized()
        self%x = v%x
        self%y = v%y
        self%z = v%z
    end subroutine qvector3d_normalize

    !> The distance from this point to `point`.
    pure real(dp) function qvector3d_distanceToPoint(self, point)
        class(QVector3D), intent(in) :: self
        type(QVector3D), intent(in) :: point
        qvector3d_distanceToPoint = norm2([self%x - point%x, self%y - point%y, self%z - point%z])
    end function qvector3d_distanceToPoint

    !> The distance from this point to the infinite line through `point` with
    !> `direction` (to `point` if `direction` is null).
    pure real(dp) function qvector3d_distanceToLine(self, point, direction) result(d)
        class(QVector3D), intent(in) :: self
        type(QVector3D), intent(in) :: point, direction
        type(QVector3D) :: u, p, s
        s = QVector3D(self%x, self%y, self%z)
        if (direction%isNull()) then
            d = s%distanceToPoint(point)
            return
        end if
        u = direction%normalized()
        p = point + u * QVector3D_dotProduct(s - point, u)
        d = s%distanceToPoint(p)
    end function qvector3d_distanceToLine

    !> The signed distance from this point to the plane through `plane` with
    !> `normal` (a unit vector); positive on the side the normal points to.
    pure real(dp) function qvector3d_distanceToPlane(self, plane, normal)
        class(QVector3D), intent(in) :: self
        type(QVector3D), intent(in) :: plane, normal
        qvector3d_distanceToPlane = QVector3D_dotProduct(QVector3D(self%x, self%y, self%z) - plane, normal)
    end function qvector3d_distanceToPlane

    !> The signed distance from this point to the plane through the points
    !> plane1, plane2, plane3 (positive on the side of the normal
    !> `(plane2 - plane1) x (plane3 - plane1)`).
    pure real(dp) function qvector3d_distanceToPlane3(self, plane1, plane2, plane3)
        class(QVector3D), intent(in) :: self
        type(QVector3D), intent(in) :: plane1, plane2, plane3
        type(QVector3D) :: n
        n = QVector3D_normal(plane2 - plane1, plane3 - plane1)
        qvector3d_distanceToPlane3 = QVector3D_dotProduct(QVector3D(self%x, self%y, self%z) - plane1, n)
    end function qvector3d_distanceToPlane3

    !> The x and y components as a QVector2D.
    pure type(QVector2D) function qvector3d_toVector2D(self)
        class(QVector3D), intent(in) :: self
        qvector3d_toVector2D = QVector2D(self%x, self%y)
    end function qvector3d_toVector2D

    !> The vector as a QVector4D with the given w (default 0).
    pure type(QVector4D) function qvector3d_toVector4D(self, w)
        class(QVector3D), intent(in) :: self
        real(dp), intent(in), optional :: w
        qvector3d_toVector4D = QVector4D(self%x, self%y, self%z, 0.0_dp)
        if (present(w)) qvector3d_toVector4D%w = w
    end function qvector3d_toVector4D

    !> The x and y components as a QPoint (rounded).
    pure type(QPoint) function qvector3d_toPoint(self)
        class(QVector3D), intent(in) :: self
        qvector3d_toPoint = QPoint(round(self%x), round(self%y))
    end function qvector3d_toPoint

    !> The x and y components as a QPointF.
    pure type(QPointF) function qvector3d_toPointF(self)
        class(QVector3D), intent(in) :: self
        qvector3d_toPointF = QPointF(self%x, self%y)
    end function qvector3d_toPointF

    !> The components as an array `[x, y, z]`.
    pure function qvector3d_toArray(self) result(a)
        class(QVector3D), intent(in) :: self
        real(dp) :: a(3)
        a = [self%x, self%y, self%z]
    end function qvector3d_toArray

    !> Dot product.
    pure real(dp) function QVector3D_dotProduct(a, b)
        type(QVector3D), intent(in) :: a, b
        QVector3D_dotProduct = a%x * b%x + a%y * b%y + a%z * b%z
    end function QVector3D_dotProduct

    !> Cross product `a x b` (right-handed).
    pure type(QVector3D) function QVector3D_crossProduct(a, b)
        type(QVector3D), intent(in) :: a, b
        QVector3D_crossProduct = QVector3D(a%y * b%z - a%z * b%y, a%z * b%x - a%x * b%z, a%x * b%y - a%y * b%x)
    end function QVector3D_crossProduct

    !> The unit normal of the plane spanned by v1 and v2: `normalized(v1 x v2)`.
    pure type(QVector3D) function qvector3d_normal2(v1, v2)
        type(QVector3D), intent(in) :: v1, v2
        qvector3d_normal2 = QVector3D_crossProduct(v1, v2)
        call qvector3d_normal2%normalize()
    end function qvector3d_normal2

    !> The unit normal of the plane through three points: `normalized((v2 - v1) x (v3 - v1))`.
    pure type(QVector3D) function qvector3d_normal3(v1, v2, v3)
        type(QVector3D), intent(in) :: v1, v2, v3
        qvector3d_normal3 = qvector3d_normal2(v2 - v1, v3 - v1)
    end function qvector3d_normal3

    !> Sum.
    elemental type(QVector3D) function qvector3d_add(a, b)
        type(QVector3D), intent(in) :: a, b
        qvector3d_add = QVector3D(a%x + b%x, a%y + b%y, a%z + b%z)
    end function qvector3d_add

    !> Difference.
    elemental type(QVector3D) function qvector3d_sub(a, b)
        type(QVector3D), intent(in) :: a, b
        qvector3d_sub = QVector3D(a%x - b%x, a%y - b%y, a%z - b%z)
    end function qvector3d_sub

    !> Negation.
    elemental type(QVector3D) function qvector3d_neg(a)
        type(QVector3D), intent(in) :: a
        qvector3d_neg = QVector3D(-a%x, -a%y, -a%z)
    end function qvector3d_neg

    !> Vector times number.
    elemental type(QVector3D) function qvector3d_mul_d(a, f)
        type(QVector3D), intent(in) :: a
        real(dp), intent(in) :: f
        qvector3d_mul_d = QVector3D(a%x * f, a%y * f, a%z * f)
    end function qvector3d_mul_d

    !> Number times vector.
    elemental type(QVector3D) function qvector3d_d_mul(f, a)
        real(dp), intent(in) :: f
        type(QVector3D), intent(in) :: a
        qvector3d_d_mul = QVector3D(a%x * f, a%y * f, a%z * f)
    end function qvector3d_d_mul

    !> Component-wise product.
    elemental type(QVector3D) function qvector3d_mul_v(a, b)
        type(QVector3D), intent(in) :: a, b
        qvector3d_mul_v = QVector3D(a%x * b%x, a%y * b%y, a%z * b%z)
    end function qvector3d_mul_v

    !> Vector divided by number.
    elemental type(QVector3D) function qvector3d_div_d(a, f)
        type(QVector3D), intent(in) :: a
        real(dp), intent(in) :: f
        qvector3d_div_d = QVector3D(a%x / f, a%y / f, a%z / f)
    end function qvector3d_div_d

    !> Component-wise quotient.
    elemental type(QVector3D) function qvector3d_div_v(a, b)
        type(QVector3D), intent(in) :: a, b
        qvector3d_div_v = QVector3D(a%x / b%x, a%y / b%y, a%z / b%z)
    end function qvector3d_div_v

    !> True if the vectors are (fuzzily) equal.
    elemental logical function qvector3d_eq(a, b)
        type(QVector3D), intent(in) :: a, b
        qvector3d_eq = fuzzy_eq(a%x, b%x) .and. fuzzy_eq(a%y, b%y) .and. fuzzy_eq(a%z, b%z)
    end function qvector3d_eq

    !> True if the vectors differ.
    elemental logical function qvector3d_ne(a, b)
        type(QVector3D), intent(in) :: a, b
        qvector3d_ne = .not. qvector3d_eq(a, b)
    end function qvector3d_ne

    ! ------------------------------------------------------------------
    ! QVector4D

    !> A vector from the first four elements of an array.
    pure type(QVector4D) function qvector4d_fromArray(a)
        real(dp), intent(in) :: a(:)
        qvector4d_fromArray = QVector4D(a(1), a(2), a(3), a(4))
    end function qvector4d_fromArray

    !> A vector from a QVector3D and w (default 0).
    pure type(QVector4D) function qvector4d_fromVector3D(v, w)
        type(QVector3D), intent(in) :: v
        real(dp), intent(in), optional :: w
        qvector4d_fromVector3D = v%toVector4D(w)
    end function qvector4d_fromVector3D

    !> A vector from a QVector2D, z and w (defaults 0).
    pure type(QVector4D) function qvector4d_fromVector2D(v, z, w)
        type(QVector2D), intent(in) :: v
        real(dp), intent(in), optional :: z, w
        qvector4d_fromVector2D = QVector4D(v%x, v%y, 0.0_dp, 0.0_dp)
        if (present(z)) qvector4d_fromVector2D%z = z
        if (present(w)) qvector4d_fromVector2D%w = w
    end function qvector4d_fromVector2D

    !> True if all components are 0.
    pure logical function qvector4d_isNull(self)
        class(QVector4D), intent(in) :: self
        qvector4d_isNull = self%x == 0.0_dp .and. self%y == 0.0_dp .and. self%z == 0.0_dp .and. self%w == 0.0_dp
    end function qvector4d_isNull

    !> The length.
    pure real(dp) function qvector4d_length(self)
        class(QVector4D), intent(in) :: self
        qvector4d_length = norm2([self%x, self%y, self%z, self%w])
    end function qvector4d_length

    !> The squared length (cheaper than `length()`).
    pure real(dp) function qvector4d_lengthSquared(self)
        class(QVector4D), intent(in) :: self
        qvector4d_lengthSquared = self%x**2 + self%y**2 + self%z**2 + self%w**2
    end function qvector4d_lengthSquared

    !> The unit vector in the same direction (a null vector stays null).
    pure type(QVector4D) function qvector4d_normalized(self) result(v)
        class(QVector4D), intent(in) :: self
        real(dp) :: l
        l = self%length()
        v = QVector4D()
        if (l > 0.0_dp) v = QVector4D(self%x / l, self%y / l, self%z / l, self%w / l)
    end function qvector4d_normalized

    !> Scale the vector to length 1 (a null vector stays null).
    pure subroutine qvector4d_normalize(self)
        class(QVector4D), intent(inout) :: self
        type(QVector4D) :: v
        v = self%normalized()
        self%x = v%x
        self%y = v%y
        self%z = v%z
        self%w = v%w
    end subroutine qvector4d_normalize

    !> The x and y components as a QVector2D.
    pure type(QVector2D) function qvector4d_toVector2D(self)
        class(QVector4D), intent(in) :: self
        qvector4d_toVector2D = QVector2D(self%x, self%y)
    end function qvector4d_toVector2D

    !> (x/w, y/w): the 2D point of homogeneous coordinates (null if w = 0).
    pure type(QVector2D) function qvector4d_toVector2DAffine(self)
        class(QVector4D), intent(in) :: self
        qvector4d_toVector2DAffine = QVector2D()
        if (self%w /= 0.0_dp) qvector4d_toVector2DAffine = QVector2D(self%x / self%w, self%y / self%w)
    end function qvector4d_toVector2DAffine

    !> The x, y and z components as a QVector3D.
    pure type(QVector3D) function qvector4d_toVector3D(self)
        class(QVector4D), intent(in) :: self
        qvector4d_toVector3D = QVector3D(self%x, self%y, self%z)
    end function qvector4d_toVector3D

    !> (x/w, y/w, z/w): the 3D point of homogeneous coordinates (null if w = 0).
    pure type(QVector3D) function qvector4d_toVector3DAffine(self)
        class(QVector4D), intent(in) :: self
        qvector4d_toVector3DAffine = QVector3D()
        if (self%w /= 0.0_dp) qvector4d_toVector3DAffine = QVector3D(self%x / self%w, self%y / self%w, self%z / self%w)
    end function qvector4d_toVector3DAffine

    !> The x and y components as a QPoint (rounded).
    pure type(QPoint) function qvector4d_toPoint(self)
        class(QVector4D), intent(in) :: self
        qvector4d_toPoint = QPoint(round(self%x), round(self%y))
    end function qvector4d_toPoint

    !> The x and y components as a QPointF.
    pure type(QPointF) function qvector4d_toPointF(self)
        class(QVector4D), intent(in) :: self
        qvector4d_toPointF = QPointF(self%x, self%y)
    end function qvector4d_toPointF

    !> The components as an array `[x, y, z, w]`.
    pure function qvector4d_toArray(self) result(a)
        class(QVector4D), intent(in) :: self
        real(dp) :: a(4)
        a = [self%x, self%y, self%z, self%w]
    end function qvector4d_toArray

    !> Dot product.
    pure real(dp) function QVector4D_dotProduct(a, b)
        type(QVector4D), intent(in) :: a, b
        QVector4D_dotProduct = a%x * b%x + a%y * b%y + a%z * b%z + a%w * b%w
    end function QVector4D_dotProduct

    !> Sum.
    elemental type(QVector4D) function qvector4d_add(a, b)
        type(QVector4D), intent(in) :: a, b
        qvector4d_add = QVector4D(a%x + b%x, a%y + b%y, a%z + b%z, a%w + b%w)
    end function qvector4d_add

    !> Difference.
    elemental type(QVector4D) function qvector4d_sub(a, b)
        type(QVector4D), intent(in) :: a, b
        qvector4d_sub = QVector4D(a%x - b%x, a%y - b%y, a%z - b%z, a%w - b%w)
    end function qvector4d_sub

    !> Negation.
    elemental type(QVector4D) function qvector4d_neg(a)
        type(QVector4D), intent(in) :: a
        qvector4d_neg = QVector4D(-a%x, -a%y, -a%z, -a%w)
    end function qvector4d_neg

    !> Vector times number.
    elemental type(QVector4D) function qvector4d_mul_d(a, f)
        type(QVector4D), intent(in) :: a
        real(dp), intent(in) :: f
        qvector4d_mul_d = QVector4D(a%x * f, a%y * f, a%z * f, a%w * f)
    end function qvector4d_mul_d

    !> Number times vector.
    elemental type(QVector4D) function qvector4d_d_mul(f, a)
        real(dp), intent(in) :: f
        type(QVector4D), intent(in) :: a
        qvector4d_d_mul = QVector4D(a%x * f, a%y * f, a%z * f, a%w * f)
    end function qvector4d_d_mul

    !> Component-wise product.
    elemental type(QVector4D) function qvector4d_mul_v(a, b)
        type(QVector4D), intent(in) :: a, b
        qvector4d_mul_v = QVector4D(a%x * b%x, a%y * b%y, a%z * b%z, a%w * b%w)
    end function qvector4d_mul_v

    !> Vector divided by number.
    elemental type(QVector4D) function qvector4d_div_d(a, f)
        type(QVector4D), intent(in) :: a
        real(dp), intent(in) :: f
        qvector4d_div_d = QVector4D(a%x / f, a%y / f, a%z / f, a%w / f)
    end function qvector4d_div_d

    !> Component-wise quotient.
    elemental type(QVector4D) function qvector4d_div_v(a, b)
        type(QVector4D), intent(in) :: a, b
        qvector4d_div_v = QVector4D(a%x / b%x, a%y / b%y, a%z / b%z, a%w / b%w)
    end function qvector4d_div_v

    !> True if the vectors are (fuzzily) equal.
    elemental logical function qvector4d_eq(a, b)
        type(QVector4D), intent(in) :: a, b
        qvector4d_eq = fuzzy_eq(a%x, b%x) .and. fuzzy_eq(a%y, b%y) .and. fuzzy_eq(a%z, b%z) .and. fuzzy_eq(a%w, b%w)
    end function qvector4d_eq

    !> True if the vectors differ.
    elemental logical function qvector4d_ne(a, b)
        type(QVector4D), intent(in) :: a, b
        qvector4d_ne = .not. qvector4d_eq(a, b)
    end function qvector4d_ne

    ! ------------------------------------------------------------------
    ! QQuaternion

    !> A quaternion from its scalar and vector parts.
    pure type(QQuaternion) function qquaternion_fromScalarVector(scalar, vector)
        real(dp), intent(in) :: scalar
        type(QVector3D), intent(in) :: vector
        qquaternion_fromScalarVector = QQuaternion(scalar, vector%x, vector%y, vector%z)
    end function qquaternion_fromScalarVector

    !> A quaternion from a QVector4D (w is the scalar).
    pure type(QQuaternion) function qquaternion_fromVector4D(v)
        type(QVector4D), intent(in) :: v
        qquaternion_fromVector4D = QQuaternion(v%w, v%x, v%y, v%z)
    end function qquaternion_fromVector4D

    !> True if all components are 0.
    pure logical function qquaternion_isNull(self)
        class(QQuaternion), intent(in) :: self
        qquaternion_isNull = self%scalar == 0.0_dp .and. self%x == 0.0_dp .and. self%y == 0.0_dp .and. self%z == 0.0_dp
    end function qquaternion_isNull

    !> True if this is the identity (1, 0, 0, 0).
    pure logical function qquaternion_isIdentity(self)
        class(QQuaternion), intent(in) :: self
        qquaternion_isIdentity = self%scalar == 1.0_dp .and. self%x == 0.0_dp .and. self%y == 0.0_dp &
                                 .and. self%z == 0.0_dp
    end function qquaternion_isIdentity

    !> The vector part (x, y, z).
    pure type(QVector3D) function qquaternion_vector(self)
        class(QQuaternion), intent(in) :: self
        qquaternion_vector = QVector3D(self%x, self%y, self%z)
    end function qquaternion_vector

    !> The length.
    pure real(dp) function qquaternion_length(self)
        class(QQuaternion), intent(in) :: self
        qquaternion_length = norm2([self%scalar, self%x, self%y, self%z])
    end function qquaternion_length

    !> The squared length.
    pure real(dp) function qquaternion_lengthSquared(self)
        class(QQuaternion), intent(in) :: self
        qquaternion_lengthSquared = self%scalar**2 + self%x**2 + self%y**2 + self%z**2
    end function qquaternion_lengthSquared

    !> The unit quaternion (a null quaternion stays null).
    pure type(QQuaternion) function qquaternion_normalized(self) result(q)
        class(QQuaternion), intent(in) :: self
        real(dp) :: l
        l = self%length()
        q = QQuaternion(0.0_dp, 0.0_dp, 0.0_dp, 0.0_dp)
        if (l > 0.0_dp) q = QQuaternion(self%scalar / l, self%x / l, self%y / l, self%z / l)
    end function qquaternion_normalized

    !> Scale to length 1 (a null quaternion stays null).
    pure subroutine qquaternion_normalize(self)
        class(QQuaternion), intent(inout) :: self
        type(QQuaternion) :: v
        v = self%normalized()
        self%scalar = v%scalar
        self%x = v%x
        self%y = v%y
        self%z = v%z
    end subroutine qquaternion_normalize

    !> The conjugate (scalar, -x, -y, -z): the inverse rotation of a unit quaternion.
    pure type(QQuaternion) function qquaternion_conjugated(self)
        class(QQuaternion), intent(in) :: self
        qquaternion_conjugated = QQuaternion(self%scalar, -self%x, -self%y, -self%z)
    end function qquaternion_conjugated

    !> The inverse (conjugate / lengthSquared); all zero for a null quaternion.
    pure type(QQuaternion) function qquaternion_inverted(self) result(q)
        class(QQuaternion), intent(in) :: self
        real(dp) :: l2
        l2 = self%lengthSquared()
        q = QQuaternion(0.0_dp, 0.0_dp, 0.0_dp, 0.0_dp)
        if (.not. fuzzy_zero(l2)) q = QQuaternion(self%scalar / l2, -self%x / l2, -self%y / l2, -self%z / l2)
    end function qquaternion_inverted

    !> `vector` rotated by this (unit) quaternion.
    pure type(QVector3D) function qquaternion_rotatedVector(self, vector)
        class(QQuaternion), intent(in) :: self
        type(QVector3D), intent(in) :: vector
        type(QQuaternion) :: q, r
        q = QQuaternion(self%scalar, self%x, self%y, self%z)
        r = q * QQuaternion(0.0_dp, vector%x, vector%y, vector%z) * q%conjugated()
        qquaternion_rotatedVector = r%vector()
    end function qquaternion_rotatedVector

    !> The rotation's unit axis and angle (degrees); a zero axis and angle for
    !> no rotation.
    pure subroutine qquaternion_getAxisAndAngle(self, axis, angle)
        class(QQuaternion), intent(in) :: self
        type(QVector3D), intent(out) :: axis
        real(dp), intent(out) :: angle
        type(QQuaternion) :: q
        real(dp) :: l
        q = self%normalized()
        l = norm2([q%x, q%y, q%z])
        if (fuzzy_zero(l)) then
            axis = QVector3D()
            angle = 0.0_dp
            return
        end if
        axis = QVector3D(q%x / l, q%y / l, q%z / l)
        angle = 2 * acos(max(-1.0_dp, min(1.0_dp, q%scalar))) / deg
    end subroutine qquaternion_getAxisAndAngle

    !> The Euler angles (degrees) of the rotation: x = pitch, y = yaw, z = roll
    !> (see QQuaternion_fromEulerAngles). At pitch = +-90 degrees (gimbal lock)
    !> roll is 0, as in Qt.
    pure type(QVector3D) function qquaternion_toEulerAngles(self) result(angles)
        class(QQuaternion), intent(in) :: self
        type(QQuaternion) :: q
        real(dp) :: xx, xy, xz, xw, yy, yz, yw, zz, zw, sinp, pitch, yaw, roll
        q = self%normalized()
        xx = q%x * q%x
        xy = q%x * q%y
        xz = q%x * q%z
        xw = q%x * q%scalar
        yy = q%y * q%y
        yz = q%y * q%z
        yw = q%y * q%scalar
        zz = q%z * q%z
        zw = q%z * q%scalar
        sinp = -2 * (yz - xw)
        if (abs(sinp) >= 1 - 1.0e-12_dp) then
            ! gimbal lock (pitch = +-90): only yaw -+ roll is defined; roll is set to 0
            pitch = sign(pi / 2, sinp)
            roll = 0.0_dp
            yaw = atan2(sign(2.0_dp, sinp) * (xy - zw), 1 - 2 * (yy + zz))
        else
            pitch = asin(sinp)
            yaw = atan2(2 * (xz + yw), 1 - 2 * (xx + yy))
            roll = atan2(2 * (xy + zw), 1 - 2 * (xx + zz))
        end if
        angles = QVector3D(pitch / deg, yaw / deg, roll / deg)
    end function qquaternion_toEulerAngles

    !> The 3x3 rotation matrix (`m(row, column)`) of this unit quaternion.
    pure function qquaternion_toRotationMatrix(self) result(m)
        class(QQuaternion), intent(in) :: self
        real(dp) :: m(3, 3)
        real(dp) :: f2x, f2y, f2z, f2xw, f2yw, f2zw, f2xx, f2xy, f2xz, f2yy, f2yz, f2zz
        f2x = self%x + self%x
        f2y = self%y + self%y
        f2z = self%z + self%z
        f2xw = f2x * self%scalar
        f2yw = f2y * self%scalar
        f2zw = f2z * self%scalar
        f2xx = f2x * self%x
        f2xy = f2x * self%y
        f2xz = f2x * self%z
        f2yy = f2y * self%y
        f2yz = f2y * self%z
        f2zz = f2z * self%z
        m(1, :) = [1 - (f2yy + f2zz), f2xy - f2zw, f2xz + f2yw]
        m(2, :) = [f2xy + f2zw, 1 - (f2xx + f2zz), f2yz - f2xw]
        m(3, :) = [f2xz - f2yw, f2yz + f2xw, 1 - (f2xx + f2yy)]
    end function qquaternion_toRotationMatrix

    !> The quaternion as a QVector4D (x, y, z, w = scalar).
    pure type(QVector4D) function qquaternion_toVector4D(self)
        class(QQuaternion), intent(in) :: self
        qquaternion_toVector4D = QVector4D(self%x, self%y, self%z, self%scalar)
    end function qquaternion_toVector4D

    !> Dot product of two quaternions (as 4-vectors).
    pure real(dp) function QQuaternion_dotProduct(q1, q2)
        type(QQuaternion), intent(in) :: q1, q2
        QQuaternion_dotProduct = q1%scalar * q2%scalar + q1%x * q2%x + q1%y * q2%y + q1%z * q2%z
    end function QQuaternion_dotProduct

    !> A rotation of `angle` degrees about `axis`.
    pure type(QQuaternion) function qquaternion_fromAxisAndAngle_v(axis, angle) result(q)
        type(QVector3D), intent(in) :: axis
        real(dp), intent(in) :: angle
        type(QVector3D) :: a
        real(dp) :: h
        a = axis%normalized()
        h = angle * deg / 2
        q = QQuaternion(cos(h), a%x * sin(h), a%y * sin(h), a%z * sin(h))
        call q%normalize()
    end function qquaternion_fromAxisAndAngle_v

    !> A rotation of `angle` degrees about the axis (x, y, z).
    pure type(QQuaternion) function qquaternion_fromAxisAndAngle_xyz(x, y, z, angle)
        real(dp), intent(in) :: x, y, z, angle
        qquaternion_fromAxisAndAngle_xyz = qquaternion_fromAxisAndAngle_v(QVector3D(x, y, z), angle)
    end function qquaternion_fromAxisAndAngle_xyz

    !> The rotation with Euler angles pitch (about x), yaw (about y) and roll
    !> (about z), in degrees, applied in the order roll, pitch, yaw.
    pure type(QQuaternion) function qquaternion_fromEulerAngles_xyz(pitch, yaw, roll)
        real(dp), intent(in) :: pitch, yaw, roll
        real(dp) :: c1, s1, c2, s2, c3, s3
        c1 = cos(yaw * deg / 2)
        s1 = sin(yaw * deg / 2)
        c2 = cos(roll * deg / 2)
        s2 = sin(roll * deg / 2)
        c3 = cos(pitch * deg / 2)
        s3 = sin(pitch * deg / 2)
        qquaternion_fromEulerAngles_xyz = QQuaternion(c1 * c2 * c3 + s1 * s2 * s3, &
                                                      c1 * c2 * s3 + s1 * s2 * c3, &
                                                      s1 * c2 * c3 - c1 * s2 * s3, &
                                                      c1 * s2 * c3 - s1 * c2 * s3)
    end function qquaternion_fromEulerAngles_xyz

    !> The rotation with Euler angles (x = pitch, y = yaw, z = roll; degrees).
    pure type(QQuaternion) function qquaternion_fromEulerAngles_v(angles)
        type(QVector3D), intent(in) :: angles
        qquaternion_fromEulerAngles_v = qquaternion_fromEulerAngles_xyz(angles%x, angles%y, angles%z)
    end function qquaternion_fromEulerAngles_v

    !> The rotation of a 3x3 rotation matrix (`m(row, column)`).
    pure type(QQuaternion) function QQuaternion_fromRotationMatrix(m) result(q)
        real(dp), intent(in) :: m(3, 3)
        real(dp) :: t, s, v(3)
        integer :: i, j, k
        t = m(1, 1) + m(2, 2) + m(3, 3)
        if (t > 0.0_dp) then
            s = sqrt(t + 1) * 2
            q = QQuaternion(s / 4, (m(3, 2) - m(2, 3)) / s, (m(1, 3) - m(3, 1)) / s, (m(2, 1) - m(1, 2)) / s)
        else
            ! the largest diagonal element picks the most stable formula
            i = 1
            if (m(2, 2) > m(1, 1)) i = 2
            if (m(3, 3) > m(i, i)) i = 3
            j = modulo(i, 3) + 1
            k = modulo(j, 3) + 1
            s = sqrt(m(i, i) - m(j, j) - m(k, k) + 1) * 2
            v(i) = s / 4
            v(j) = (m(j, i) + m(i, j)) / s
            v(k) = (m(k, i) + m(i, k)) / s
            q = QQuaternion((m(k, j) - m(j, k)) / s, v(1), v(2), v(3))
        end if
        call q%normalize()
    end function QQuaternion_fromRotationMatrix

    !> The rotation that takes the x, y and z axes to `xAxis`, `yAxis`, `zAxis`
    !> (orthonormal).
    pure type(QQuaternion) function QQuaternion_fromAxes(xAxis, yAxis, zAxis)
        type(QVector3D), intent(in) :: xAxis, yAxis, zAxis
        real(dp) :: m(3, 3)
        m(:, 1) = xAxis%toArray()
        m(:, 2) = yAxis%toArray()
        m(:, 3) = zAxis%toArray()
        QQuaternion_fromAxes = QQuaternion_fromRotationMatrix(m)
    end function QQuaternion_fromAxes

    !> The rotation that points the z axis along `direction`, with the y axis as
    !> close to `up` as possible (the identity for a null direction).
    pure type(QQuaternion) function QQuaternion_fromDirection(direction, up) result(q)
        type(QVector3D), intent(in) :: direction, up
        type(QVector3D) :: xAxis, yAxis, zAxis
        q = QQuaternion()
        if (direction%isNull()) return
        zAxis = direction%normalized()
        xAxis = QVector3D_crossProduct(up, zAxis)
        if (fuzzy_zero(xAxis%lengthSquared())) then
            ! up is parallel to direction (or null): the shortest arc to it
            q = QQuaternion_rotationTo(QVector3D(0.0_dp, 0.0_dp, 1.0_dp), zAxis)
            return
        end if
        call xAxis%normalize()
        yAxis = QVector3D_crossProduct(zAxis, xAxis)
        q = QQuaternion_fromAxes(xAxis, yAxis, zAxis)
    end function QQuaternion_fromDirection

    !> The shortest-arc rotation that takes the direction `from` to `to`.
    pure type(QQuaternion) function QQuaternion_rotationTo(from, to) result(q)
        type(QVector3D), intent(in) :: from, to
        type(QVector3D) :: v0, v1, axis
        real(dp) :: d
        v0 = from%normalized()
        v1 = to%normalized()
        d = QVector3D_dotProduct(v0, v1) + 1
        if (fuzzy_zero(d)) then
            ! opposite directions: half a turn about any perpendicular axis
            axis = QVector3D_crossProduct(QVector3D(1.0_dp, 0.0_dp, 0.0_dp), v0)
            if (fuzzy_zero(axis%lengthSquared())) axis = QVector3D_crossProduct(QVector3D(0.0_dp, 1.0_dp, 0.0_dp), v0)
            call axis%normalize()
            q = QQuaternion(0.0_dp, axis%x, axis%y, axis%z)
            return
        end if
        d = sqrt(2 * d)
        axis = QVector3D_crossProduct(v0, v1) / d
        q = QQuaternion(d / 2, axis%x, axis%y, axis%z)
        call q%normalize()
    end function QQuaternion_rotationTo

    !> Spherical linear interpolation between unit quaternions (t = 0: q1,
    !> t = 1: q2), along the shortest path.
    pure type(QQuaternion) function QQuaternion_slerp(q1, q2, t) result(q)
        type(QQuaternion), intent(in) :: q1, q2
        real(dp), intent(in) :: t
        type(QQuaternion) :: q2b
        real(dp) :: dot, f1, f2, angle, s
        if (t <= 0.0_dp) then
            q = q1
            return
        else if (t >= 1.0_dp) then
            q = q2
            return
        end if
        q2b = q2
        dot = QQuaternion_dotProduct(q1, q2)
        if (dot < 0.0_dp) then
            q2b = -q2b
            dot = -dot
        end if
        f1 = 1 - t
        f2 = t
        if (1 - dot > 1.0e-7_dp) then
            angle = acos(min(dot, 1.0_dp))
            s = sin(angle)
            if (s > 1.0e-7_dp) then
                f1 = sin((1 - t) * angle) / s
                f2 = sin(t * angle) / s
            end if
        end if
        q = q1 * f1 + q2b * f2
    end function QQuaternion_slerp

    !> Normalized linear interpolation between unit quaternions (faster than
    !> slerp, but not at constant speed), along the shortest path.
    pure type(QQuaternion) function QQuaternion_nlerp(q1, q2, t) result(q)
        type(QQuaternion), intent(in) :: q1, q2
        real(dp), intent(in) :: t
        type(QQuaternion) :: q2b
        if (t <= 0.0_dp) then
            q = q1
            return
        else if (t >= 1.0_dp) then
            q = q2
            return
        end if
        q2b = q2
        if (QQuaternion_dotProduct(q1, q2) < 0.0_dp) q2b = -q2b
        q = q1 * (1 - t) + q2b * t
        call q%normalize()
    end function QQuaternion_nlerp

    !> Sum.
    elemental type(QQuaternion) function qquaternion_add(a, b)
        type(QQuaternion), intent(in) :: a, b
        qquaternion_add = QQuaternion(a%scalar + b%scalar, a%x + b%x, a%y + b%y, a%z + b%z)
    end function qquaternion_add

    !> Difference.
    elemental type(QQuaternion) function qquaternion_sub(a, b)
        type(QQuaternion), intent(in) :: a, b
        qquaternion_sub = QQuaternion(a%scalar - b%scalar, a%x - b%x, a%y - b%y, a%z - b%z)
    end function qquaternion_sub

    !> Negation.
    elemental type(QQuaternion) function qquaternion_neg(a)
        type(QQuaternion), intent(in) :: a
        qquaternion_neg = QQuaternion(-a%scalar, -a%x, -a%y, -a%z)
    end function qquaternion_neg

    !> Quaternion times number.
    elemental type(QQuaternion) function qquaternion_mul_d(a, f)
        type(QQuaternion), intent(in) :: a
        real(dp), intent(in) :: f
        qquaternion_mul_d = QQuaternion(a%scalar * f, a%x * f, a%y * f, a%z * f)
    end function qquaternion_mul_d

    !> Number times quaternion.
    elemental type(QQuaternion) function qquaternion_d_mul(f, a)
        real(dp), intent(in) :: f
        type(QQuaternion), intent(in) :: a
        qquaternion_d_mul = QQuaternion(a%scalar * f, a%x * f, a%y * f, a%z * f)
    end function qquaternion_d_mul

    !> Quaternion (Hamilton) product: the rotation `b`, then `a`.
    elemental type(QQuaternion) function qquaternion_mul_q(a, b)
        type(QQuaternion), intent(in) :: a, b
        qquaternion_mul_q = QQuaternion(a%scalar * b%scalar - a%x * b%x - a%y * b%y - a%z * b%z, &
                                        a%scalar * b%x + a%x * b%scalar + a%y * b%z - a%z * b%y, &
                                        a%scalar * b%y - a%x * b%z + a%y * b%scalar + a%z * b%x, &
                                        a%scalar * b%z + a%x * b%y - a%y * b%x + a%z * b%scalar)
    end function qquaternion_mul_q

    !> `q * v`: the vector rotated by the quaternion (`q%rotatedVector(v)`).
    elemental type(QVector3D) function qquaternion_mul_v3(q, v)
        type(QQuaternion), intent(in) :: q
        type(QVector3D), intent(in) :: v
        qquaternion_mul_v3 = q%rotatedVector(v)
    end function qquaternion_mul_v3

    !> Quaternion divided by number.
    elemental type(QQuaternion) function qquaternion_div_d(a, f)
        type(QQuaternion), intent(in) :: a
        real(dp), intent(in) :: f
        qquaternion_div_d = QQuaternion(a%scalar / f, a%x / f, a%y / f, a%z / f)
    end function qquaternion_div_d

    !> True if the quaternions are (fuzzily) equal.
    elemental logical function qquaternion_eq(a, b)
        type(QQuaternion), intent(in) :: a, b
        qquaternion_eq = fuzzy_eq(a%scalar, b%scalar) .and. fuzzy_eq(a%x, b%x) .and. fuzzy_eq(a%y, b%y) &
                         .and. fuzzy_eq(a%z, b%z)
    end function qquaternion_eq

    !> True if the quaternions differ.
    elemental logical function qquaternion_ne(a, b)
        type(QQuaternion), intent(in) :: a, b
        qquaternion_ne = .not. qquaternion_eq(a, b)
    end function qquaternion_ne

end module qt_vectors
