!> QMatrix4x4 math (pure Fortran; no OpenGL needed).
program test_matrix

    use qt
    use testing
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    real(dp), parameter :: tol = 1.0e-12_dp
    type(QMatrix4x4) :: a, b, c
    real(dp) :: p(3), n(3, 3)
    logical :: ok

    call check(all(abs(a%m - eye4()) < tol), 'default is identity')

    call a%translate(1.0_dp, 2.0_dp, 3.0_dp)
    call check(close3(a%map([0.0_dp, 0.0_dp, 0.0_dp]), [1.0_dp, 2.0_dp, 3.0_dp]), 'translate')

    call a%setToIdentity()
    call a%scale(2.0_dp, 3.0_dp, 4.0_dp)
    call check(close3(a%map([1.0_dp, 1.0_dp, 1.0_dp]), [2.0_dp, 3.0_dp, 4.0_dp]), 'scale(x, y, z)')
    call a%setToIdentity()
    call a%scale(2.0_dp)
    call check(close3(a%map([1.0_dp, -1.0_dp, 0.5_dp]), [2.0_dp, -2.0_dp, 1.0_dp]), 'scale(factor)')

    ! 90 degrees about z takes x to y (right-handed)
    call a%setToIdentity()
    call a%rotate(90.0_dp, 0.0_dp, 0.0_dp, 1.0_dp)
    call check(close3(a%map([1.0_dp, 0.0_dp, 0.0_dp]), [0.0_dp, 1.0_dp, 0.0_dp]), 'rotate about z')
    call a%setToIdentity()
    call a%rotate(90.0_dp, 0.0_dp, 2.0_dp, 0.0_dp)   ! axis is normalized
    call check(close3(a%map([1.0_dp, 0.0_dp, 0.0_dp]), [0.0_dp, 0.0_dp, -1.0_dp]), 'rotate about y')

    ! post-multiplication, as in Qt: translate then rotate applies the rotation first
    call a%setToIdentity()
    call a%translate(10.0_dp, 0.0_dp, 0.0_dp)
    call a%rotate(90.0_dp, 0.0_dp, 0.0_dp, 1.0_dp)
    call check(close3(a%map([1.0_dp, 0.0_dp, 0.0_dp]), [10.0_dp, 1.0_dp, 0.0_dp]), 'post-multiplication order')

    ! operator(*) composes the same way
    b = QMatrix4x4()
    call b%translate(10.0_dp, 0.0_dp, 0.0_dp)
    c = QMatrix4x4()
    call c%rotate(90.0_dp, 0.0_dp, 0.0_dp, 1.0_dp)
    c = b * c
    call check(all(abs(c%m - a%m) < tol), 'operator(*)')

    ! inverse
    b = a%inverted(ok)
    c = a * b
    call check(ok .and. all(abs(c%m - eye4()) < tol), 'inverted')
    b%m = 0.0_dp
    c = b%inverted(ok)
    call check(.not. ok .and. all(abs(c%m - eye4()) < tol), 'singular matrix inverts to identity')
    c = a%transposed()
    call check(all(abs(c%m - transpose(a%m)) < tol), 'transposed')

    ! lookAt: the camera maps its target onto the -z axis at the right distance
    call a%setToIdentity()
    call a%lookAt([0.0_dp, 0.0_dp, 5.0_dp], [0.0_dp, 0.0_dp, 0.0_dp], [0.0_dp, 1.0_dp, 0.0_dp])
    call check(close3(a%map([0.0_dp, 0.0_dp, 0.0_dp]), [0.0_dp, 0.0_dp, -5.0_dp]), 'lookAt target')
    call check(close3(a%map([0.0_dp, 1.0_dp, 0.0_dp]), [0.0_dp, 1.0_dp, -5.0_dp]), 'lookAt up')

    ! perspective: the near plane maps to z = -1, the far plane to z = +1
    call a%setToIdentity()
    call a%perspective(90.0_dp, 1.0_dp, 1.0_dp, 10.0_dp)
    p = a%map([0.0_dp, 0.0_dp, -1.0_dp])
    call check(abs(p(3) + 1.0_dp) < 1.0e-9_dp, 'perspective near plane')
    p = a%map([0.0_dp, 0.0_dp, -10.0_dp])
    call check(abs(p(3) - 1.0_dp) < 1.0e-9_dp, 'perspective far plane')
    p = a%map([1.0_dp, 1.0_dp, -1.0_dp])
    call check(abs(p(1) - 1.0_dp) < 1.0e-9_dp .and. abs(p(2) - 1.0_dp) < 1.0e-9_dp, &
               'perspective 90 degree field of view')

    ! ortho maps the box onto [-1, 1]^3
    call a%setToIdentity()
    call a%ortho(0.0_dp, 4.0_dp, 0.0_dp, 2.0_dp, -1.0_dp, 1.0_dp)
    ! (near/far are distances along -z: z = -near maps to -1, z = -far to +1)
    call check(close3(a%map([4.0_dp, 2.0_dp, 1.0_dp]), [1.0_dp, 1.0_dp, -1.0_dp]), 'ortho near corner')
    call check(close3(a%map([0.0_dp, 0.0_dp, -1.0_dp]), [-1.0_dp, -1.0_dp, 1.0_dp]), 'ortho far corner')

    ! normal matrix of a non-uniform scale is the inverse scale
    call a%setToIdentity()
    call a%scale(2.0_dp, 4.0_dp, 1.0_dp)
    n = a%normalMatrix()
    call check(abs(n(1, 1) - 0.5_dp) < tol .and. abs(n(2, 2) - 0.25_dp) < tol .and. abs(n(3, 3) - 1) < tol, &
               'normalMatrix')

    write(*,'(A)') 'test_matrix: all checks passed'

contains

    !> The 4x4 identity.
    pure function eye4() result(e)
        real(dp) :: e(4, 4)
        integer :: i
        e = 0.0_dp
        do i = 1, 4
            e(i, i) = 1.0_dp
        end do
    end function eye4

    !> True if two 3-vectors agree to within `tol`.
    pure logical function close3(u, v)
        real(dp), intent(in) :: u(3), v(3)
        close3 = all(abs(u - v) < 1.0e-12_dp)
    end function close3

end program test_matrix
