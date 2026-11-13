!> The geometry value types (QPoint, QSize, QRect, QPointF, QRectF, QLineF,
!> QMargins) in the Qt API: widget geometry, painting, paths, transforms, events
!> and screens. Run headless with QT_QPA_PLATFORM=offscreen.
program test_geometry_api

    use qt
    use testing
    use iso_c_binding, only: c_double, c_associated
    implicit none

    integer, parameter :: dp = c_double
    type(QApplication) :: app
    type(QWidget) :: window, child
    type(QWidget) :: found
    type(QVBoxLayout) :: layout
    type(QImage) :: img
    type(QPainter) :: p
    type(QPainterPath) :: path
    type(QTransform) :: t
    type(QFontMetrics) :: fm
    type(QResizeEvent) :: re
    type(QMouseEvent) :: me
    type(QWheelEvent) :: we
    type(QContextMenuEvent) :: ce
    type(QScreen) :: screen
    type(QRect) :: r, g
    type(QRectF) :: rf
    type(QPointF) :: pf
    type(QSize) :: s
    type(QPoint) :: q

    app = QApplication()

    ! --- widget geometry
    window = QWidget()
    call window%resize(QSize(200, 150))
    s = window%size()
    call check(s == QSize(200, 150) .and. window%width() == 200, 'resize(QSize), size()')
    r = window%rect()
    call check(r == QRect(0, 0, 200, 150), 'rect()')
    call window%move(QPoint(30, 40))
    call check(window%pos() == QPoint(30, 40) .and. window%x() == 30, 'move(QPoint), pos()')
    call window%setContentsMargins(QMargins(1, 2, 3, 4))
    call check(window%contentsMargins() == QMargins(1, 2, 3, 4), 'setContentsMargins(QMargins)')
    r = window%contentsRect()
    call check(r == QRect(1, 2, 196, 144), 'contentsRect')
    call window%setMinimumSize(QSize(50, 60))
    call check(window%minimumSize() == QSize(50, 60), 'setMinimumSize(QSize), minimumSize()')
    call window%setMaximumSize(QSize(500, 400))
    call check(window%maximumSize() == QSize(500, 400), 'setMaximumSize(QSize), maximumSize()')

    child = QWidget(window)
    call child%setGeometry(QRect(10, 20, 30, 40))
    g = child%geometry()
    call check(g == QRect(10, 20, 30, 40) .and. child%pos() == g%topLeft(), 'setGeometry(QRect), geometry()')
    call check(child%mapToParent(QPoint(1, 1)) == QPoint(11, 21), 'mapToParent')
    call check(child%mapFromParent(QPoint(11, 21)) == QPoint(1, 1), 'mapFromParent')
    call check(child%mapTo(window, QPoint(0, 0)) == QPoint(10, 20), 'mapTo(ancestor)')
    call check(child%mapFrom(window, QPoint(10, 20)) == QPoint(0, 0), 'mapFrom(ancestor)')
    q = child%mapToGlobal(QPoint(0, 0))
    call check(child%mapFromGlobal(q) == QPoint(0, 0), 'mapToGlobal / mapFromGlobal round trip')
    call window%show()
    found = window%childAt(QPoint(15, 25))
    call check(c_associated(found%ptr, child%ptr), 'childAt(QPoint)')
    found = window%childAt(QPoint(100, 100))
    call check(found%isNull(), 'childAt: nothing there')
    s = child%sizeHint()   ! (-1, -1) for a plain widget without a layout
    call check(.not. s%isValid(), 'sizeHint of a plain widget is invalid')

    layout = QVBoxLayout()
    call layout%setContentsMargins(QMargins(5, 6, 7, 8))
    call check(layout%contentsMargins() == QMargins(5, 6, 7, 8), 'QLayout setContentsMargins(QMargins)')
    call layout%delete()
    call window%delete()

    ! --- painting with points, lines and rectangles
    img = QImage(40, 20)
    call check(img%size() == QSize(40, 20), 'QImage size()')
    call img%fill(Qt_white)
    p = QPainter(img)
    call p%fillRect(QRectF(10, 5, 10, 5), Qt_blue)
    call p%setPen(QPen(Qt_red, 1.0_dp))
    call p%drawLine(QPointF(0.5_dp, 0.5_dp), QPointF(39.5_dp, 0.5_dp))
    call p%setPen(Qt_black)
    call p%drawLine(QLineF(0.5_dp, 19.5_dp, 9.5_dp, 19.5_dp))
    call p%drawPoint(QPointF(39.5_dp, 19.5_dp))
    call p%setPen(QPen(style=Qt_NoPen))
    call p%setBrush(Qt_green)
    call p%drawRect(QRectF(30, 10, 5, 5))
    call p%drawEllipse(QPointF(25, 15), 2.0_dp, 2.0_dp)
    call p%setClipRect(QRectF(0, 0, 5, 5))
    call p%fillRect(QRectF(0, 0, 40, 20), Qt_magenta)   ! only the clipped corner
    call p%end()
    call check(img%pixelColor(12, 7) == Qt_blue, 'fillRect(QRectF)')
    call check(img%pixelColor(20, 0) == Qt_red, 'drawLine(QPointF, QPointF)')
    call check(img%pixelColor(5, 19) == Qt_black, 'drawLine(QLineF)')
    call check(img%pixelColor(39, 19) == Qt_black, 'drawPoint(QPointF)')
    call check(img%pixelColor(32, 12) == Qt_green, 'drawRect(QRectF)')
    call check(img%pixelColor(25, 15) == Qt_green, 'drawEllipse(center, rx, ry)')
    call check(img%pixelColor(2, 2) == Qt_magenta .and. img%pixelColor(12, 7) == Qt_blue, 'setClipRect(QRectF)')
    call img%delete()

    ! --- paths
    path = QPainterPath()
    call path%moveTo(QPointF(10, 10))
    call path%lineTo(QPointF(40, 10))
    call path%lineTo(QPointF(40, 30))
    call check(path%currentPosition() == QPointF(40, 30), 'moveTo/lineTo(QPointF), currentPosition')
    call path%closeSubpath()
    call check(path%boundingRect() == QRectF(10, 10, 30, 20), 'boundingRect')
    call check(path%containsPoint(QPointF(35, 15)) .and. .not. path%containsPoint(QPointF(15, 25)), &
               'containsPoint(QPointF)')
    call check(path%pointAtPercent(0.0_dp) == QPointF(10, 10), 'pointAtPercent')
    call path%addRect(QRectF(100, 100, 10, 10))
    rf = path%boundingRect()
    call check(rf%bottomRight() == QPointF(110, 110), 'addRect(QRectF)')
    call path%delete()

    ! --- transforms
    t = QTransform()
    call t%translate(10.0_dp, 20.0_dp)
    call t%scale(2.0_dp, 3.0_dp)
    pf = t%map(QPointF(1, 1))
    call check(pf == QPointF(12, 23), 'QTransform map(QPointF)')
    call check(t%mapRect(QRectF(0, 0, 1, 1)) == QRectF(10, 20, 2, 3), 'QTransform mapRect(QRectF)')
    call t%delete()

    ! --- font metrics
    fm = QFontMetrics()
    r = fm%boundingRect('Hello')
    ! (only font-independent properties: the glyph box varies with the platform's fonts)
    if (r%width /= fm%boundingWidth('Hello') .or. r%height < 0) &
        write(*,'(A,4(1X,I0))') 'boundingRect x y w h:', r%x, r%y, r%width, r%height
    call check(r%width == fm%boundingWidth('Hello') .and. r%height >= 0, 'QFontMetrics boundingRect')
    s = fm%size(0, 'Hello')
    call check(s%width >= fm%horizontalAdvance('Hello') - 1 .and. s%height == fm%height(), 'QFontMetrics size')
    call fm%delete()

    ! --- events
    re = QResizeEvent(80, 50, 60, 40)
    call check(re%size() == QSize(80, 50) .and. re%oldSize() == QSize(60, 40), 'QResizeEvent size, oldSize')
    call re%delete()
    me = QMouseEvent(QEvent_MouseButtonPress, 12.5_dp, 7.0_dp, Qt_LeftButton)
    call check(me%position() == QPointF(12.5_dp, 7.0_dp), 'QMouseEvent position')
    call me%delete()
    we = QWheelEvent(30.0_dp, 15.0_dp, 0, -120)
    call check(we%angleDelta() == QPoint(0, -120) .and. we%position() == QPointF(30, 15), 'QWheelEvent angleDelta')
    call we%delete()
    ce = QContextMenuEvent(QContextMenuEvent_Mouse, 3, 4, 103, 104)
    call check(ce%pos() == QPoint(3, 4) .and. ce%globalPos() == QPoint(103, 104), 'QContextMenuEvent pos, globalPos')
    call ce%delete()

    ! --- screens
    screen = QGuiApplication_primaryScreen()
    g = screen%geometry()
    call check(g == QRect(screen%x(), screen%y(), screen%width(), screen%height()) .and. g%size() == screen%size(), &
               'QScreen geometry, size')
    r = screen%availableGeometry()
    call check(g%contains(r), 'QScreen availableGeometry inside geometry')

    write(*,'(A)') 'test_geometry_api: all checks passed'

end program test_geometry_api
