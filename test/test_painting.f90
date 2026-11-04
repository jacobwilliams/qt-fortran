!> Painting beyond the basics: QPainterPath, gradients, QTransform, clipping,
!> arcs and pies, and QFontMetrics. Drawn on images and checked pixel by pixel.
!> Run headless with QT_QPA_PLATFORM=offscreen.
program test_painting

    use qt
    use testing
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    type(QApplication) :: app
    type(QImage) :: img
    type(QPainter) :: p
    type(QPainterPath) :: path, a, b, c
    type(QLinearGradient) :: lin
    type(QRadialGradient) :: rad
    type(QConicalGradient) :: con
    type(QTransform) :: t, inv, r, shifted, got
    type(QFontMetrics) :: fm, big, pfm
    type(QFont) :: font
    type(QColor) :: px
    logical :: ok
    character(len=:), allocatable :: elided

    app = QApplication()

    ! --- QPainterPath: building and querying
    path = QPainterPath()
    call check(path%isEmpty(), 'empty path')
    call path%addRect(10, 10, 30, 30)
    call check(.not. path%isEmpty() .and. path%elementCount() == 5, 'addRect: move-to + 4 line-to')
    call check(path%containsPoint(20.0_dp, 20.0_dp) .and. .not. path%containsPoint(50.0_dp, 50.0_dp), &
               'containsPoint')
    call check(abs(path%boundingWidth() - 30) < 1e-9_dp .and. abs(path%boundingX() - 10) < 1e-9_dp, &
               'bounding rectangle')
    call check(abs(path%length() - 120) < 1e-9_dp, 'length')

    a = QPainterPath()
    call a%moveTo(0.0_dp, 0.0_dp)
    call a%cubicTo(10, 0, 20, 10, 30, 30)
    call check(abs(a%pointAtPercentX(0.0_dp)) < 1e-9_dp .and. abs(a%pointAtPercentX(1.0_dp) - 30) < 1e-6_dp &
               .and. abs(a%pointAtPercentY(1.0_dp) - 30) < 1e-6_dp, 'cubicTo, pointAtPercent')
    call a%delete()

    ! boolean operations on two overlapping squares
    a = QPainterPath()
    call a%addRect(0, 0, 20, 20)
    b = QPainterPath()
    call b%addRect(10, 0, 20, 20)
    c = a%united(b)
    call check(abs(c%boundingWidth() - 30) < 1e-6_dp, 'united')
    call c%delete()
    c = a%intersected(b)
    call check(abs(c%boundingWidth() - 10) < 1e-6_dp .and. abs(c%boundingX() - 10) < 1e-6_dp, 'intersected')
    call c%delete()
    c = a%subtracted(b)
    call check(abs(c%boundingWidth() - 10) < 1e-6_dp .and. abs(c%boundingX()) < 1e-6_dp, 'subtracted')
    call c%delete()
    c = a%copy()
    call c%translate(5, 0)
    call check(abs(c%boundingX() - 5) < 1e-9_dp .and. abs(a%boundingX()) < 1e-9_dp, 'copy, translate')
    call c%addPath(b)
    call check(abs(c%boundingWidth() - 25) < 1e-6_dp, 'addPath')
    call c%delete()
    call a%delete()
    call b%delete()

    ! a triangle from arrays (integer and real), and the fill rule
    a = QPainterPath()
    call a%addPolygon([0, 40, 0], [0, 0, 40])
    call a%closeSubpath()
    call a%setFillRule(Qt_WindingFill)
    call check(a%containsPoint(5.0_dp, 5.0_dp) .and. .not. a%containsPoint(35.0_dp, 35.0_dp), 'addPolygon')
    call a%delete()
    a = QPainterPath()
    call a%addEllipse(0.0_dp, 0.0_dp, 20.0_dp, 10.0_dp)
    call a%addRoundedRect(30, 0, 10, 10, 2, 2)
    call a%arcTo(0.0_dp, 20.0_dp, 10.0_dp, 10.0_dp, 0.0_dp, 90.0_dp)
    call a%quadTo(5, 40, 10, 50)
    call a%lineTo(0, 50)
    call check(abs(a%boundingHeight() - 50) < 1e-6_dp, 'ellipse, rounded rect, arcTo, quadTo')
    call a%delete()
    a = QPainterPath()
    call a%addText(0, 20, 'Fortran', pointSize=20.0_dp, bold=.true.)
    call check(.not. a%isEmpty() .and. a%boundingWidth() > 10, 'addText')
    call a%delete()

    ! --- drawing paths
    img = QImage(100, 100)
    call img%fill(Qt_white)
    p = QPainter(img)
    call p%fillPath(path, Qt_red)
    call p%end()
    call check(img%pixelColor(20, 20) == Qt_red .and. img%pixelColor(50, 50) == Qt_white, 'fillPath')

    p = QPainter(img)
    call p%strokePath(path, QPen(Qt_blue, 1.0_dp))
    call p%setPen(Qt_green)
    call p%setBrush(Qt_green)
    a = QPainterPath()
    call a%addRect(60, 60, 20, 20)
    call p%drawPath(a)
    call a%delete()
    call p%end()
    call check(img%pixelColor(70, 70) == Qt_green, 'drawPath')
    call check(img%pixelColor(10, 25) == Qt_blue .and. img%pixelColor(20, 20) == Qt_red, 'strokePath: outline only')

    ! --- gradients
    lin = QLinearGradient(0.0_dp, 0.0_dp, 100.0_dp, 0.0_dp)
    call lin%setColorAt(0.0_dp, Qt_red)
    call lin%setColorAt(1.0_dp, Qt_blue)
    call img%fill(Qt_white)
    p = QPainter(img)
    call p%fillRect(0, 0, 100, 20, lin)
    px = img%pixelColor(1, 10)
    call check(px%red() > 240 .and. px%blue() < 15, 'linear gradient: start color')
    px = img%pixelColor(98, 10)
    call check(px%blue() > 240 .and. px%red() < 15, 'linear gradient: end color')
    px = img%pixelColor(50, 10)
    call check(abs(px%red() - px%blue()) < 20 .and. px%red() > 100, 'linear gradient: halfway')

    rad = QRadialGradient(50.0_dp, 60.0_dp, 20.0_dp)
    call rad%setColorAt(0.0_dp, Qt_black)
    call rad%setColorAt(1.0_dp, Qt_white)
    call rad%setFocalPoint(50.0_dp, 60.0_dp)
    call p%setPen(Qt_transparent)
    call p%setBrush(rad)                 ! the gradient is copied: it can be deleted now
    call rad%delete()
    call p%drawRect(30, 40, 40, 40)
    px = img%pixelColor(50, 60)
    call check(px%red() < 20 .and. px%green() < 20, 'radial gradient through setBrush: center')
    px = img%pixelColor(32, 42)
    call check(px%red() > 240, 'radial gradient: beyond the radius')

    con = QConicalGradient(85.0_dp, 85.0_dp, 0.0_dp)
    call con%setColorAt(0.0_dp, Qt_green)
    call con%setColorAt(1.0_dp, Qt_green)
    call con%setSpread(QGradient_RepeatSpread)
    a = QPainterPath()
    call a%addEllipse(75, 75, 20, 20)
    call p%fillPath(a, con)
    call a%delete()
    call p%end()
    call check(img%pixelColor(85, 85) == Qt_green, 'conical gradient through fillPath')
    call lin%setCoordinateMode(QGradient_ObjectMode)
    call lin%setStart(0.0_dp, 0.0_dp)
    call lin%setFinalStop(0.0_dp, 1.0_dp)
    call lin%delete()
    call con%delete()

    ! --- QTransform
    t = QTransform()
    call check(t%isIdentity(), 'identity transform')
    call t%translate(10.0_dp, 20.0_dp)
    call check(abs(t%mapX(0.0_dp, 0.0_dp) - 10) < 1e-12_dp .and. abs(t%mapY(0.0_dp, 0.0_dp) - 20) < 1e-12_dp, &
               'translate, map')
    call t%scale(2.0_dp, 3.0_dp)       ! applies before the translation
    call check(abs(t%mapX(1.0_dp, 1.0_dp) - 12) < 1e-12_dp .and. abs(t%mapY(1.0_dp, 1.0_dp) - 23) < 1e-12_dp, &
               'scale applies first')
    call check(abs(t%m11() - 2) < 1e-12_dp .and. abs(t%m22() - 3) < 1e-12_dp .and. abs(t%dx() - 10) < 1e-12_dp &
               .and. abs(t%dy() - 20) < 1e-12_dp .and. abs(t%determinant() - 6) < 1e-12_dp, 'elements')
    inv = t%inverted(ok)
    call check(ok .and. abs(inv%mapX(12.0_dp, 23.0_dp) - 1) < 1e-12_dp .and. &
               abs(inv%mapY(12.0_dp, 23.0_dp) - 1) < 1e-12_dp, 'inverted')
    r = QTransform()
    call r%rotate(90.0_dp)
    call check(abs(r%mapX(1.0_dp, 0.0_dp)) < 1e-12_dp .and. abs(r%mapY(1.0_dp, 0.0_dp) - 1) < 1e-12_dp, &
               'rotate (y points down)')
    shifted = QTransform(1.0_dp, 0.0_dp, 0.0_dp, 1.0_dp, 5.0_dp, 6.0_dp)
    call check(abs(shifted%mapX(0.0_dp, 0.0_dp) - 5) < 1e-12_dp .and. abs(shifted%m12()) < 1e-12_dp &
               .and. abs(shifted%m21()) < 1e-12_dp, 'QTransform from affine elements')
    call inv%delete()
    inv = r%multiplied(shifted)          ! rotate, then shift
    call check(abs(inv%mapX(1.0_dp, 0.0_dp) - 5) < 1e-12_dp .and. abs(inv%mapY(1.0_dp, 0.0_dp) - 7) < 1e-12_dp, &
               'multiplied')
    call inv%delete()
    call r%shear(0.5_dp, 0.0_dp)
    call r%reset()
    call check(r%isIdentity() .and. r%isInvertible(), 'shear, reset')
    call r%delete()

    ! painting through a transform
    call img%fill(Qt_white)
    p = QPainter(img)
    call p%setTransform(shifted)
    call p%fillRect(0, 0, 4, 4, Qt_red)
    got = p%transform()
    call check(abs(got%dx() - 5) < 1e-12_dp, 'QPainter%transform')
    call got%delete()
    call p%setTransform(shifted, combine=.true.)  ! now shifted twice
    call p%fillRect(0, 0, 4, 4, Qt_blue)
    call p%resetTransform()
    call p%shear(0.0_dp, 0.0_dp)
    call p%end()
    call check(img%pixelColor(6, 7) == Qt_red .and. img%pixelColor(11, 13) == Qt_blue .and. &
               img%pixelColor(1, 1) == Qt_white, 'setTransform (and combine)')
    call shifted%delete()
    call t%delete()

    ! --- clipping, arcs, pies
    call img%fill(Qt_white)
    p = QPainter(img)
    call p%setClipRect(0, 0, 10, 10)
    call check(p%hasClipping(), 'setClipRect')
    call p%fillRect(0, 0, 100, 100, Qt_green)
    call p%setClipping(.false.)
    a = QPainterPath()
    call a%addEllipse(40, 40, 20, 20)
    call p%setClipPath(a)
    call p%fillRect(0, 0, 100, 100, Qt_red)
    call a%delete()
    call p%setClipping(.false.)
    call p%setPen(Qt_blue)
    call p%setBrush(Qt_blue)
    call p%drawPie(60, 0, 40, 40, 0.0_dp, 90.0_dp)        ! the top-right quarter of the circle
    call p%drawChord(0, 60, 40, 40, 180.0_dp, 180.0_dp)  ! the lower half
    call p%drawArc(0, 0, 100, 100, 0.0_dp, 360.0_dp)
    call p%end()
    call check(img%pixelColor(5, 5) == Qt_green .and. img%pixelColor(20, 20) /= Qt_green, 'clip rectangle')
    call check(img%pixelColor(50, 50) == Qt_red .and. img%pixelColor(41, 41) /= Qt_red, 'clip path')
    call check(img%pixelColor(90, 15) == Qt_blue .and. img%pixelColor(70, 30) /= Qt_blue, 'drawPie')
    call check(img%pixelColor(20, 90) == Qt_blue .and. img%pixelColor(20, 70) /= Qt_blue, 'drawChord')

    ! --- QFontMetrics
    fm = QFontMetrics()
    call check(fm%height() > 0 .and. fm%ascent() > 0 .and. fm%descent() >= 0 .and. fm%lineSpacing() >= fm%height(), &
               'QFontMetrics: line metrics')
    call check(fm%horizontalAdvance('MMMM') > fm%horizontalAdvance('M') .and. fm%boundingWidth('MMMM') > 0, &
               'horizontalAdvance, boundingWidth')
    call check(fm%averageCharWidth() > 0 .and. fm%maxWidth() > 0 .and. fm%capHeight() > 0 .and. &
               fm%xHeight() > 0 .and. fm%leading() >= 0, 'character metrics')
    elided = fm%elidedText('a rather long piece of text for a narrow column', Qt_ElideRight, 60)
    call check(len(elided) > 0 .and. len(elided) < 40 .and. fm%horizontalAdvance(elided) <= 60, 'elidedText')
    call check(fm%elidedText('short', Qt_ElideRight, 1000) == 'short', 'elidedText: fits')
    font%pointSize = 40.0_dp
    font%bold = .true.
    big = QFontMetrics(font)
    call check(big%height() > fm%height(), 'QFontMetrics(font)')
    p = QPainter(img)
    pfm = p%fontMetrics()
    call check(pfm%height() > 0, 'QPainter%fontMetrics')
    call p%end()
    call pfm%delete()
    call big%delete()
    call fm%delete()

    call path%delete()
    call img%delete()
    write(*,'(A)') 'test_painting: all checks passed'

end program test_painting
