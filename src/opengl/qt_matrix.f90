!> QMatrix4x4: a 4x4 transformation matrix for 3D graphics, in pure Fortran.
!>
!> The matrix is stored column-major in `m(4,4)` (`m(row, column)`), as in Qt and
!> OpenGL, and starts as the identity. As in Qt, the transformation methods
!> post-multiply: `call mvp%rotate(...)` sets `mvp = mvp * R`. So a typical
!> model-view-projection matrix is built in the order projection, view, model:
!>
!>     call mvp%perspective(45.0_dp, aspect, 0.1_dp, 100.0_dp)
!>     call mvp%lookAt([0d0, 0d0, 5d0], [0d0, 0d0, 0d0], [0d0, 1d0, 0d0])
!>     call mvp%rotate(angle, 0d0, 1d0, 0d0)
!>
!> Angles are in degrees.
module qt_matrix

    use iso_c_binding, only: c_double
    implicit none
    private

    integer, parameter :: dp = c_double
    real(dp), parameter :: identity(4, 4) = reshape([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1] * 1.0_dp, [4, 4])

    !> A 4x4 matrix (column-major, `m(row, column)`), initially the identity.
    type, public :: QMatrix4x4
        real(dp) :: m(4, 4) = identity   !! the elements, column-major
    contains
        procedure :: setToIdentity => qmatrix4x4_setToIdentity
        procedure :: translate => qmatrix4x4_translate
        procedure, private :: qmatrix4x4_scale3, qmatrix4x4_scale1
        generic :: scale => qmatrix4x4_scale3, qmatrix4x4_scale1
        procedure :: rotate => qmatrix4x4_rotate
        procedure :: perspective => qmatrix4x4_perspective
        procedure :: ortho => qmatrix4x4_ortho
        procedure :: lookAt => qmatrix4x4_lookAt
        procedure :: map => qmatrix4x4_map
        procedure :: transposed => qmatrix4x4_transposed
        procedure :: inverted => qmatrix4x4_inverted
        procedure :: normalMatrix => qmatrix4x4_normalMatrix
    end type QMatrix4x4

    !> Matrix product `a * b` (apply `b` first, then `a`).
    interface operator(*)
        module procedure :: qmatrix4x4_multiply
    end interface operator(*)
    public :: operator(*)

contains

    !> Reset to the identity matrix.
    subroutine qmatrix4x4_setToIdentity(self)
        class(QMatrix4x4), intent(inout) :: self
        self%m = identity
    end subroutine qmatrix4x4_setToIdentity

    !> Multiply by a translation by (x, y, z).
    subroutine qmatrix4x4_translate(self, x, y, z)
        class(QMatrix4x4), intent(inout) :: self
        real(dp), intent(in) :: x, y, z
        real(dp) :: t(4, 4)
        t = identity
        t(1:3, 4) = [x, y, z]
        self%m = matmul(self%m, t)
    end subroutine qmatrix4x4_translate

    !> Multiply by a scaling by (x, y, z).
    subroutine qmatrix4x4_scale3(self, x, y, z)
        class(QMatrix4x4), intent(inout) :: self
        real(dp), intent(in) :: x, y, z
        real(dp) :: t(4, 4)
        t = identity
        t(1, 1) = x
        t(2, 2) = y
        t(3, 3) = z
        self%m = matmul(self%m, t)
    end subroutine qmatrix4x4_scale3

    !> Multiply by a uniform scaling by `factor`.
    subroutine qmatrix4x4_scale1(self, factor)
        class(QMatrix4x4), intent(inout) :: self
        real(dp), intent(in) :: factor
        call self%scale(factor, factor, factor)
    end subroutine qmatrix4x4_scale1

    !> Multiply by a rotation of `angle` degrees about the axis (x, y, z).
    subroutine qmatrix4x4_rotate(self, angle, x, y, z)
        class(QMatrix4x4), intent(inout) :: self
        real(dp), intent(in) :: angle, x, y, z
        real(dp) :: r(4, 4), a(3), c, s, ic, len
        len = norm2([x, y, z])
        if (len == 0.0_dp) return
        a = [x, y, z] / len
        c = cos(angle * acos(-1.0_dp) / 180)
        s = sin(angle * acos(-1.0_dp) / 180)
        ic = 1 - c
        r = identity
        r(1, 1:3) = [a(1) * a(1) * ic + c,        a(1) * a(2) * ic - a(3) * s, a(1) * a(3) * ic + a(2) * s]
        r(2, 1:3) = [a(2) * a(1) * ic + a(3) * s, a(2) * a(2) * ic + c,        a(2) * a(3) * ic - a(1) * s]
        r(3, 1:3) = [a(3) * a(1) * ic - a(2) * s, a(3) * a(2) * ic + a(1) * s, a(3) * a(3) * ic + c]
        self%m = matmul(self%m, r)
    end subroutine qmatrix4x4_rotate

    !> Multiply by a perspective projection: vertical field of view `verticalAngle`
    !> (degrees), width/height `aspectRatio`, and clipping planes `nearPlane` / `farPlane`.
    subroutine qmatrix4x4_perspective(self, verticalAngle, aspectRatio, nearPlane, farPlane)
        class(QMatrix4x4), intent(inout) :: self
        real(dp), intent(in) :: verticalAngle, aspectRatio, nearPlane, farPlane
        real(dp) :: p(4, 4), half, cotan
        half = verticalAngle / 2 * acos(-1.0_dp) / 180
        if (sin(half) == 0.0_dp .or. nearPlane == farPlane .or. aspectRatio == 0.0_dp) return
        cotan = cos(half) / sin(half)
        p = 0.0_dp
        p(1, 1) = cotan / aspectRatio
        p(2, 2) = cotan
        p(3, 3) = -(nearPlane + farPlane) / (farPlane - nearPlane)
        p(3, 4) = -(2 * nearPlane * farPlane) / (farPlane - nearPlane)
        p(4, 3) = -1
        self%m = matmul(self%m, p)
    end subroutine qmatrix4x4_perspective

    !> Multiply by an orthographic projection of the given box.
    subroutine qmatrix4x4_ortho(self, left, right, bottom, top, nearPlane, farPlane)
        class(QMatrix4x4), intent(inout) :: self
        real(dp), intent(in) :: left, right, bottom, top, nearPlane, farPlane
        real(dp) :: o(4, 4)
        if (left == right .or. bottom == top .or. nearPlane == farPlane) return
        o = identity
        o(1, 1) = 2 / (right - left)
        o(1, 4) = -(right + left) / (right - left)
        o(2, 2) = 2 / (top - bottom)
        o(2, 4) = -(top + bottom) / (top - bottom)
        o(3, 3) = -2 / (farPlane - nearPlane)
        o(3, 4) = -(farPlane + nearPlane) / (farPlane - nearPlane)
        self%m = matmul(self%m, o)
    end subroutine qmatrix4x4_ortho

    !> Multiply by a viewing matrix: a camera at `eye` looking at `center`, with
    !> `up` pointing up.
    subroutine qmatrix4x4_lookAt(self, eye, center, up)
        class(QMatrix4x4), intent(inout) :: self
        real(dp), intent(in) :: eye(3), center(3), up(3)
        real(dp) :: v(4, 4), forward(3), side(3), upward(3)
        forward = center - eye
        if (norm2(forward) == 0.0_dp) return
        forward = forward / norm2(forward)
        side = cross(forward, up)
        if (norm2(side) == 0.0_dp) return
        side = side / norm2(side)
        upward = cross(side, forward)
        v = identity
        v(1, 1:3) = side
        v(2, 1:3) = upward
        v(3, 1:3) = -forward
        self%m = matmul(self%m, v)
        call self%translate(-eye(1), -eye(2), -eye(3))
    end subroutine qmatrix4x4_lookAt

    !> Cross product of two 3-vectors.
    pure function cross(a, b) result(c)
        real(dp), intent(in) :: a(3), b(3)
        real(dp) :: c(3)
        c = [a(2) * b(3) - a(3) * b(2), a(3) * b(1) - a(1) * b(3), a(1) * b(2) - a(2) * b(1)]
    end function cross

    !> Transform the point `p` (with perspective division).
    function qmatrix4x4_map(self, p) result(q)
        class(QMatrix4x4), intent(in) :: self
        real(dp), intent(in) :: p(3)
        real(dp) :: q(3), v(4)
        v = matmul(self%m, [p, 1.0_dp])
        q = v(1:3)
        if (v(4) /= 0.0_dp .and. v(4) /= 1.0_dp) q = q / v(4)
    end function qmatrix4x4_map

    !> The transposed matrix.
    function qmatrix4x4_transposed(self) result(t)
        class(QMatrix4x4), intent(in) :: self
        type(QMatrix4x4) :: t
        t%m = transpose(self%m)
    end function qmatrix4x4_transposed

    !> The inverse matrix; the identity if the matrix is singular (then
    !> `invertible` is false).
    function qmatrix4x4_inverted(self, invertible) result(inv)
        class(QMatrix4x4), intent(in) :: self
        logical, intent(out), optional :: invertible
        type(QMatrix4x4) :: inv
        logical :: ok
        call invert(self%m, inv%m, ok)
        if (.not. ok) inv%m = identity
        if (present(invertible)) invertible = ok
    end function qmatrix4x4_inverted

    !> The 3x3 matrix that transforms normals: the inverse transpose of the upper
    !> left 3x3 block (the identity if that block is singular).
    function qmatrix4x4_normalMatrix(self) result(n)
        class(QMatrix4x4), intent(in) :: self
        real(dp) :: n(3, 3)
        logical :: ok
        call invert(self%m(1:3, 1:3), n, ok)
        if (ok) then
            n = transpose(n)
        else
            n = identity(1:3, 1:3)
        end if
    end function qmatrix4x4_normalMatrix

    !> Invert a square matrix by Gauss-Jordan elimination with partial pivoting.
    pure subroutine invert(a, inv, ok)
        real(dp), intent(in) :: a(:, :)
        real(dp), intent(out) :: inv(size(a, 1), size(a, 1))
        logical, intent(out) :: ok
        real(dp) :: w(size(a, 1), 2 * size(a, 1)), row(2 * size(a, 1))
        integer :: n, i, k, p
        n = size(a, 1)
        w = 0.0_dp
        w(:, 1:n) = a
        do i = 1, n
            w(i, n + i) = 1.0_dp
        end do
        ok = .false.
        do i = 1, n
            p = i - 1 + maxloc(abs(w(i:n, i)), dim=1)
            if (abs(w(p, i)) < 1.0e-14_dp * max(1.0_dp, maxval(abs(a)))) return
            if (p /= i) then
                row = w(i, :)
                w(i, :) = w(p, :)
                w(p, :) = row
            end if
            w(i, :) = w(i, :) / w(i, i)
            do k = 1, n
                if (k /= i) w(k, :) = w(k, :) - w(k, i) * w(i, :)
            end do
        end do
        inv = w(:, n + 1:)
        ok = .true.
    end subroutine invert

    !> Matrix product `a * b`.
    function qmatrix4x4_multiply(a, b) result(c)
        type(QMatrix4x4), intent(in) :: a, b
        type(QMatrix4x4) :: c
        c%m = matmul(a%m, b%m)
    end function qmatrix4x4_multiply

end module qt_matrix
