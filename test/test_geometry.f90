!> Geometry, vector and quaternion value types (pure Fortran; no display needed).
!> Expected values marked "Qt" come from Qt 6 itself (via PySide6), which
!> computes vectors and quaternions in single precision.
program test_geometry

    use qt
    use testing
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    real(dp), parameter :: tol = 1.0e-12_dp
    real(dp), parameter :: ftol = 2.0e-5_dp   ! for Qt's single-precision results

    call test_points()
    call test_sizes()
    call test_rects()
    call test_rectfs()
    call test_lines()
    call test_vectors()
    call test_quaternions()
    call test_matrix()
    write(*,'(A)') 'test_geometry: all checks passed'

contains

    !> QPoint and QPointF.
    subroutine test_points()
        type(QPoint) :: p, z
        type(QPointF) :: f
        p = QPoint(3, 4)
        z = QPoint()
        call check(p + QPoint(1, 1) == QPoint(4, 5) .and. p - QPoint(1, 1) == QPoint(2, 3), 'QPoint + -')
        call check(-p == QPoint(-3, -4) .and. 2 * p == QPoint(6, 8) .and. p * 2 == QPoint(6, 8), 'QPoint negate, * int')
        ! Qt rounds halfway cases away from zero
        call check(p * 1.5_dp == QPoint(5, 6) .and. QPoint(-3, 4) * 0.5_dp == QPoint(-2, 2), 'QPoint * real rounds (Qt)')
        call check(QPoint(5, 5) / 2.0_dp == QPoint(3, 3) .and. QPoint(-5, 3) / 2.0_dp == QPoint(-3, 2), &
                   'QPoint / real rounds (Qt)')
        call check(p%manhattanLength() == 7 .and. p%transposed() == QPoint(4, 3), 'QPoint manhattanLength, transposed')
        call check(z%isNull() .and. .not. p%isNull() .and. p /= QPoint(4, 3), 'QPoint isNull, /=')

        f = QPointF(1, 2)   ! the structure constructor converts integers
        call check(f%x == 1.0_dp .and. f%y == 2.0_dp, 'QPointF from integers')
        call check(QPointF(p) == QPointF(3.0_dp, 4.0_dp) .and. p%toPointF() == QPointF(3, 4), 'QPoint <-> QPointF')
        f = QPointF(2.5_dp, -2.5_dp)
        call check(f%toPoint() == QPoint(3, -3), 'QPointF%toPoint rounds')
        f = (QPointF(1, 2) + QPointF(1, 1)) * 2.0_dp - QPointF(0.5_dp, 0.5_dp) / 0.5_dp
        call check(f == QPointF(3, 5), 'QPointF arithmetic')
        call check(QPointF(0.1_dp + 0.2_dp, 1) == QPointF(0.3_dp, 1.0_dp), 'QPointF fuzzy ==')
        call check(abs(QPointF_dotProduct(QPointF(1, 2), QPointF(3, 4)) - 11) < tol, 'QPointF_dotProduct')
    end subroutine test_points

    !> QSize, QSizeF and QMargins.
    subroutine test_sizes()
        type(QSize) :: s, z
        type(QSizeF) :: f
        type(QMargins) :: m
        s = QSize(100, 50)
        z = QSize()
        call check(s%isValid() .and. .not. s%isEmpty() .and. .not. s%isNull(), 'QSize valid')
        call check(z%isNull() .and. z%isEmpty(), 'QSize null')
        z = QSize(-1, 5)
        call check(.not. z%isValid(), 'QSize invalid')
        call check(s%scaled(QSize(60, 60), Qt_KeepAspectRatio) == QSize(60, 30), 'QSize scaled keep (Qt)')
        call check(s%scaled(QSize(60, 60), Qt_KeepAspectRatioByExpanding) == QSize(120, 60), 'QSize scaled expanding (Qt)')
        call check(s%scaled(QSize(60, 60)) == QSize(60, 60), 'QSize scaled ignore')
        call check(s%expandedTo(QSize(80, 80)) == QSize(100, 80) .and. s%boundedTo(QSize(80, 80)) == QSize(80, 50), &
                   'QSize expandedTo, boundedTo')
        call check(s%transposed() == QSize(50, 100) .and. s * 0.5_dp == QSize(50, 25), 'QSize transposed, scale')
        m = QMargins(1, 2, 3, 4)
        call check(s%grownBy(m) == QSize(104, 56) .and. s%shrunkBy(m) == QSize(96, 44), 'QSize grownBy, shrunkBy')
        call check(m + m == QMargins(2, 4, 6, 8) .and. -m == QMargins(-1, -2, -3, -4), 'QMargins + -')
        m = m - m
        call check(m%isNull(), 'QMargins isNull')
        f = QSizeF(2.4_dp, 2.6_dp)
        call check(QSizeF(s) == QSizeF(100, 50) .and. f%toSize() == QSize(2, 3), 'QSize <-> QSizeF')
        f = QSizeF(4, 2)
        call check(f%scaled(QSizeF(1, 1), Qt_KeepAspectRatio) == QSizeF(1.0_dp, 0.5_dp), 'QSizeF scaled')
    end subroutine test_sizes

    !> QRect, against Qt.
    subroutine test_rects()
        type(QRect) :: r, t
        r = QRect(0, 0, 10, 10)
        call check(r%right() == 9 .and. r%bottom() == 9 .and. r%bottomRight() == QPoint(9, 9), 'QRect right/bottom inclusive')
        t = QRect(-5, -5, 4, 4)
        call check(r%center() == QPoint(4, 4) .and. t%center() == QPoint(-3, -3), 'QRect center (Qt)')
        t = QRect()
        call check(r%size() == QSize(10, 10) .and. r%isValid() .and. t%isNull(), 'QRect size, valid, null')
        t = QRect(10, 10, -5, -3)
        call check(t%normalized() == QRect(5, 7, 5, 3), 'QRect normalized (Qt)')
        t = QRect(10, 10, 0, -3)
        call check(t%normalized() == QRect(10, 7, 0, 3), 'QRect normalized zero width (Qt)')
        call check(r%intersected(QRect(5, 5, 10, 10)) == QRect(5, 5, 5, 5), 'QRect intersected (Qt)')
        call check(r%intersected(QRect(10, 0, 5, 5)) == QRect(), 'QRect intersected, disjoint (Qt)')
        call check(r%intersects(QRect(9, 9, 5, 5)) .and. .not. r%intersects(QRect(10, 0, 5, 5)), 'QRect intersects (Qt)')
        t = QRect()
        call check(r%united(QRect(20, 5, 5, 10)) == QRect(0, 0, 25, 15) .and. t%united(r) == r, 'QRect united (Qt)')
        call check(r%contains(QPoint(9, 9)) .and. .not. r%contains(QPoint(10, 5)), 'QRect contains point (Qt)')
        call check(.not. r%contains(QPoint(0, 5), proper=.true.), 'QRect contains point, proper (Qt)')
        call check(r%contains(r) .and. .not. r%contains(r, .true.), 'QRect contains rect (Qt)')
        call check(r%adjusted(1, 2, -3, -4) == QRect(1, 2, 6, 4), 'QRect adjusted (Qt)')
        call check(r%marginsAdded(QMargins(1, 2, 3, 4)) == QRect(-1, -2, 14, 16), 'QRect marginsAdded (Qt)')
        call check(r + QMargins(1, 2, 3, 4) - QMargins(1, 2, 3, 4) == r, 'QRect +- QMargins')
        call check(QRect(QPoint(1, 2), QSize(3, 4)) == QRect(1, 2, 3, 4), 'QRect(topLeft, size)')
        call check(QRect(QPoint(1, 2), QPoint(3, 4)) == QRect(1, 2, 3, 3), 'QRect(topLeft, bottomRight)')
        call check(r%translated(2, 3) == QRect(2, 3, 10, 10) .and. r%translated(QPoint(-1, 0)) == QRect(-1, 0, 10, 10), &
                   'QRect translated')
        call r%moveCenter(QPoint(20, 20))
        call check(r%center() == QPoint(20, 20) .and. r%size() == QSize(10, 10), 'QRect moveCenter')
        call r%moveTo(QPoint(1, 1))
        call check(r == QRect(1, 1, 10, 10), 'QRect moveTo')
    end subroutine test_rects

    !> QRectF, against Qt.
    subroutine test_rectfs()
        type(QRectF) :: r, t
        r = QRectF(0, 0, 10, 10)
        call check(abs(r%right() - 10) < tol .and. r%center() == QPointF(5, 5), 'QRectF right, center')
        t = QRectF(0, 0, 10, 0)
        call check(r%contains(QPointF(10, 10)) .and. .not. t%contains(QPointF(5, 0)), 'QRectF contains point (Qt)')
        call check(.not. r%intersects(QRectF(10, 0, 5, 5)), 'QRectF touching edges do not intersect (Qt)')
        call check(r%intersected(QRectF(5, -5, 10, 10)) == QRectF(5, 0, 5, 5), 'QRectF intersected (Qt)')
        call check(r%united(QRectF(20, 20, 0, 5)) == QRectF(0, 0, 20, 25), 'QRectF united, zero width (Qt)')
        t = QRectF(1.5_dp, 2.5_dp, 3.4_dp, 4.6_dp)
        call check(t%toRect() == QRect(2, 3, 3, 4), 'QRectF toRect (Qt)')
        call check(t%toAlignedRect() == QRect(1, 2, 4, 6), 'QRectF toAlignedRect (Qt)')
        t = QRectF(-1.5_dp, -2.5_dp, 3.5_dp, 4.5_dp)
        call check(t%toRect() == QRect(-2, -3, 4, 5), 'QRectF toRect negative (Qt)')
        call check(QRectF(QRect(1, 2, 3, 4)) == QRectF(1, 2, 3, 4), 'QRectF(QRect)')
        call check(QRectF(QPointF(1, 1), QPointF(3, 4)) == QRectF(1, 1, 2, 3), 'QRectF(topLeft, bottomRight)')
        t = QRectF(4, 4, -2, -2)
        call check(t%normalized() == QRectF(2, 2, 2, 2), 'QRectF normalized')
    end subroutine test_rectfs

    !> QLineF, against Qt.
    subroutine test_lines()
        type(QLineF) :: l
        type(QPointF) :: p
        l = QLineF(0, 0, 10, -10)
        call check(abs(l%angle() - 45) < tol, 'QLineF angle (y down, counterclockwise) (Qt)')
        l = QLineF(0, 0, 1, 0)
        call check(abs(l%angleTo(QLineF(0, 0, 0, 1)) - 270) < tol, 'QLineF angleTo (Qt)')
        call check(QLineF_fromPolar(2.0_dp, 30.0_dp) == QLineF(0.0_dp, 0.0_dp, sqrt(3.0_dp), -1.0_dp), 'QLineF_fromPolar (Qt)')
        call check(l%intersects(QLineF(0, 1, 1, 1)) == QLineF_NoIntersection, 'QLineF parallel (Qt)')
        l = QLineF(0, 0, 10, 10)
        call check(l%intersects(QLineF(0, 10, 10, 0), p) == QLineF_BoundedIntersection .and. p == QPointF(5, 5), &
                   'QLineF bounded intersection (Qt)')
        l = QLineF(0, 0, 1, 1)
        call check(l%intersects(QLineF(0, 10, 10, 0), p) == QLineF_UnboundedIntersection .and. p == QPointF(5, 5), &
                   'QLineF unbounded intersection (Qt)')
        l = QLineF(QPointF(1, 1), QPointF(4, 5))
        call check(l%normalVector() == QLineF(1, 1, 5, -2), 'QLineF normalVector (Qt)')
        call check(l%unitVector() == QLineF(1.0_dp, 1.0_dp, 1.6_dp, 1.8_dp), 'QLineF unitVector (Qt)')
        call check(abs(l%length() - 5) < tol .and. l%center() == QPointF(2.5_dp, 3.0_dp), 'QLineF length, center')
        call l%setLength(10.0_dp)
        call check(l%p2() == QPointF(7, 9), 'QLineF setLength')
        call l%setAngle(90.0_dp)
        call check(l%p2() == QPointF(1, -9), 'QLineF setAngle')
    end subroutine test_lines

    !> QVector2D, QVector3D, QVector4D.
    subroutine test_vectors()
        type(QVector2D) :: u
        type(QVector3D) :: a, b, v, z
        type(QVector4D) :: v4
        a = QVector3D(1, 0, 0)
        b = QVector3D([0.0_dp, 1.0_dp, 0.0_dp])
        call check(QVector3D_crossProduct(a, b) == QVector3D(0, 0, 1), 'QVector3D_crossProduct')
        call check(abs(QVector3D_dotProduct(a + b, b) - 1) < tol, 'QVector3D_dotProduct')
        v = QVector3D(3, 4, 12)
        call check(abs(v%length() - 13) < tol .and. abs(v%lengthSquared() - 169) < tol, 'QVector3D length')
        v = QVector3D(0, 3, 4)
        z = QVector3D()
        call check(v%normalized() == QVector3D(0.0_dp, 0.6_dp, 0.8_dp) .and. z%normalized() == z, 'QVector3D normalized')
        call check(abs(v%distanceToLine(QVector3D(), QVector3D(2, 0, 0)) - 5) < tol, 'distanceToLine')
        call check(2.0_dp * a - b / 2.0_dp == QVector3D(2.0_dp, -0.5_dp, 0.0_dp) .and. -a == QVector3D(-1, 0, 0), &
                   'QVector3D arithmetic')
        call check(QVector3D(1, 2, 3) * QVector3D(2, 2, 2) == QVector3D(2, 4, 6), 'QVector3D component-wise *')
        call check(QVector3D_normal(QVector3D(0, 0, 0), QVector3D(2, 0, 0), QVector3D(0, 2, 0)) == QVector3D(0, 0, 1), &
                   'QVector3D_normal (3 points)')
        v = QVector3D(1, 1, 5)
        call check(abs(v%distanceToPlane(QVector3D(), QVector3D(0, 0, 1)) - 5) < tol, 'distanceToPlane')
        call check(abs(v%distanceToPlane(QVector3D(), QVector3D(1, 0, 0), QVector3D(0, 1, 0)) - 5) < tol, &
                   'distanceToPlane (3 points)')
        v = QVector3D(1, 2, 2)
        call check(abs(v%distanceToPoint(QVector3D()) - 3) < tol, 'distanceToPoint')
        v = QVector3D(1, 2, 3)
        call check(all(abs(v%toArray() - [1, 2, 3]) < tol), 'QVector3D toArray')
        call check(QVector3D(QVector2D(1, 2), 3.0_dp) == v, 'QVector3D(QVector2D, z)')
        u = QVector2D(1.4_dp, 2.6_dp)
        call check(QVector2D(QPointF(1.5_dp, 2.0_dp)) == QVector2D(1.5_dp, 2.0_dp) .and. u%toPoint() == QPoint(1, 3), &
                   'QVector2D <-> points')
        u = QVector2D(0, 3)
        call check(abs(u%distanceToLine(QVector2D(), QVector2D(1, 0)) - 3) < tol, 'QVector2D distanceToLine')
        v4 = QVector4D(QVector3D(2, 4, 6), 2.0_dp)
        call check(v4%toVector3DAffine() == v .and. v4%toVector2DAffine() == QVector2D(1, 2), 'QVector4D affine')
        call check(abs(QVector4D_dotProduct(v4, QVector4D(1, 1, 1, 1)) - 14) < tol .and. abs(v4%length() - sqrt(60.0_dp)) < tol, &
                   'QVector4D dot, length')
        v4 = QVector4D([1.0_dp, 2.0_dp, 3.0_dp, 4.0_dp])
        call check(v4%toVector3D() == v, 'QVector4D(array)')
    end subroutine test_vectors

    !> QQuaternion, against Qt.
    subroutine test_quaternions()
        type(QQuaternion) :: q, a, b
        type(QVector3D) :: axis, e
        real(dp) :: angle
        q = QQuaternion()
        call check(q%isIdentity(), 'QQuaternion default identity')
        q = QQuaternion_fromAxisAndAngle(QVector3D(0, 0, 1), 90.0_dp)
        call check(q%rotatedVector(QVector3D(1, 0, 0)) == QVector3D(0, 1, 0), 'rotate x about z')
        call check(q * QVector3D(1, 0, 0) == QVector3D(0, 1, 0), 'quaternion * vector')
        call check(closeq(QQuaternion_fromEulerAngles(30.0_dp, 45.0_dp, 60.0_dp), &
                          QQuaternion(0.8223631_dp, 0.3919038_dp, 0.2005621_dp, 0.3604234_dp)), 'fromEulerAngles (Qt)')
        ! the Euler convention: roll about z, then pitch about x, then yaw about y
        a = QQuaternion_fromAxisAndAngle(0.0_dp, 1.0_dp, 0.0_dp, 45.0_dp) * &
            QQuaternion_fromAxisAndAngle(1.0_dp, 0.0_dp, 0.0_dp, 30.0_dp) * &
            QQuaternion_fromAxisAndAngle(0.0_dp, 0.0_dp, 1.0_dp, 60.0_dp)
        call check(closeq(a, QQuaternion_fromEulerAngles(QVector3D(30, 45, 60))), 'Euler order yaw * pitch * roll')
        q = QQuaternion_fromAxisAndAngle(QVector3D(1, 2, 3), 170.0_dp)
        call check(closeq(q, QQuaternion(0.0871558_dp, 0.2662442_dp, 0.5324885_dp, 0.7987327_dp)), 'fromAxisAndAngle (Qt)')
        e = q%toEulerAngles()
        call check(closev(e, QVector3D(-53.535225_dp, 60.668365_dp, 134.655579_dp), 1.0e-3_dp), 'toEulerAngles (Qt)')
        call check(closeq(QQuaternion_fromEulerAngles(e), q), 'Euler angles round trip')
        ! gimbal lock: Qt gives roll 0 and puts yaw -+ roll into yaw
        call check(lock(90, 30, 0, 30) .and. lock(90, 30, 20, 10) .and. lock(-90, 30, 20, 50) &
                   .and. lock(-90, -70, 10, -60) .and. lock(90, 0, 45, -45), 'toEulerAngles at gimbal lock (Qt)')
        call check(closeq(QQuaternion_fromRotationMatrix(q%toRotationMatrix()), q), 'rotation matrix round trip')
        call q%getAxisAndAngle(axis, angle)
        e = QVector3D(1, 2, 3)
        call check(axis == e%normalized() .and. abs(angle - 170) < 1.0e-9_dp, 'getAxisAndAngle')
        call check(closeq(QQuaternion_rotationTo(QVector3D(0, 0, 1), QVector3D(0, 0, -1)), QQuaternion(0, 0, -1, 0)), &
                   'rotationTo opposite (Qt)')
        call check(closeq(QQuaternion_rotationTo(QVector3D(1, 0, 0), QVector3D(0, 1, 1)), &
                          QQuaternion(0.7071068_dp, 0.0_dp, -0.5_dp, 0.5_dp)), 'rotationTo (Qt)')
        call check(closeq(QQuaternion_fromDirection(QVector3D(1, 1, 0), QVector3D(0, 1, 0)), &
                          QQuaternion(0.6532815_dp, -0.2705980_dp, 0.6532815_dp, 0.2705980_dp)), 'fromDirection (Qt)')
        a = QQuaternion_fromAxisAndAngle(0.0_dp, 0.0_dp, 1.0_dp, 10.0_dp)
        b = QQuaternion_fromAxisAndAngle(0.0_dp, 1.0_dp, 0.0_dp, 120.0_dp)
        call check(closeq(QQuaternion_slerp(a, b, 0.3_dp), QQuaternion(0.9485908_dp, 0.0_dp, 0.3092521_dp, 0.0673701_dp)), &
                   'slerp (Qt)')
        call check(closeq(QQuaternion_nlerp(a, b, 0.3_dp), QQuaternion(0.9538103_dp, 0.0_dp, 0.2924544_dp, 0.0686752_dp)), &
                   'nlerp (Qt)')
        call check(closeq(a * b, QQuaternion(0.4980973_dp, -0.0754791_dp, 0.8627300_dp, 0.0435779_dp)), 'product (Qt)')
        call check(closev(b%rotatedVector(QVector3D(1, 2, 3)), QVector3D(2.098076_dp, 2.0_dp, -2.366026_dp), ftol), &
                   'rotatedVector (Qt)')
        call check(closeq(q * q%inverted(), QQuaternion()) .and. closeq(q * q%conjugated(), QQuaternion()), &
                   'inverted, conjugated')
    end subroutine test_quaternions

    !> QMatrix4x4 with vectors and quaternions.
    subroutine test_matrix()
        type(QMatrix4x4) :: m, mv, pr
        type(QQuaternion) :: q
        type(QVector3D) :: p
        real(dp), parameter :: qt_rot(16) = &   ! row-major, as QMatrix4x4::copyDataTo
                                            [-0.843036_dp, 0.144316_dp, 0.518135_dp, 0.0_dp, &
                                             0.422772_dp, -0.41772_dp, 0.804222_dp, 0.0_dp, &
                                             0.332497_dp, 0.897041_dp, 0.29114_dp, 0.0_dp, &
                                             0.0_dp, 0.0_dp, 0.0_dp, 1.0_dp]
        q = QQuaternion_fromAxisAndAngle(QVector3D(1, 2, 3), 170.0_dp)
        call m%rotate(q)
        call check(all(abs(reshape(transpose(m%m), [16]) - qt_rot) < ftol), 'rotate(quaternion) (Qt)')
        call check(m%map(QVector3D(1, 0, 0)) == q%rotatedVector(QVector3D(1, 0, 0)), 'map(QVector3D)')
        m = QMatrix4x4()
        call m%rotate(90.0_dp, QVector3D(0, 0, 1))
        call check(m * QVector3D(1, 0, 0) == QVector3D(0, 1, 0), 'rotate(angle, axis), matrix * QVector3D')
        m = QMatrix4x4()
        call m%translate(QVector3D(1, 2, 3))
        call m%scale(QVector3D(2, 2, 2))
        call check(m%map(QVector3D(1, 1, 1)) == QVector3D(3, 4, 5), 'translate/scale(QVector3D)')
        call check(m%mapVector(QVector3D(1, 1, 1)) == QVector3D(2, 2, 2), 'mapVector ignores translation')
        call check(m * QVector4D(1, 1, 1, 0) == QVector4D(2, 2, 2, 0) .and. m * QVector4D(1, 1, 1, 1) == QVector4D(3, 4, 5, 1), &
                   'matrix * QVector4D')

        ! project / unproject (Qt)
        call mv%lookAt(QVector3D(0, 0, 5), QVector3D(0, 0, 0), QVector3D(0, 1, 0))
        call mv%rotate(30.0_dp, 0.0_dp, 1.0_dp, 0.0_dp)
        call pr%perspective(45.0_dp, 4.0_dp / 3, 0.1_dp, 100.0_dp)
        p = QVector3D_project(QVector3D(1, 2, -1), mv, pr, QRect(0, 0, 800, 600))
        call check(closev(p, QVector3D(441.642761_dp, 527.540405_dp, 0.985277_dp), 1.0e-3_dp), 'QVector3D_project (Qt)')
        p = QVector3D_unproject(p, mv, pr, QRect(0, 0, 800, 600))
        call check(closev(p, QVector3D(1, 2, -1), 1.0e-9_dp), 'QVector3D_unproject round trip')
    end subroutine test_matrix

    !> True if the Euler angles (pitch, yaw, roll) come back as (pitch, yaw2, 0).
    logical function lock(pitch, yaw, roll, yaw2)
        integer, intent(in) :: pitch, yaw, roll, yaw2
        type(QQuaternion) :: q
        q = QQuaternion_fromEulerAngles(QVector3D(pitch, yaw, roll))
        lock = closev(q%toEulerAngles(), QVector3D(pitch, yaw2, 0), 1.0e-6_dp)
    end function lock

    !> True if two quaternions are the same to single precision.
    logical function closeq(a, b)
        type(QQuaternion), intent(in) :: a, b
        closeq = all(abs([a%scalar - b%scalar, a%x - b%x, a%y - b%y, a%z - b%z]) < ftol)
    end function closeq

    !> True if two vectors agree to within `t`.
    logical function closev(a, b, t)
        type(QVector3D), intent(in) :: a, b
        real(dp), intent(in) :: t
        closev = all(abs([a%x - b%x, a%y - b%y, a%z - b%z]) < t)
    end function closev

end program test_geometry
