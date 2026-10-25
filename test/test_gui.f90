!> Gui value types and painting on images. Run headless (QT_QPA_PLATFORM=offscreen).
program test_gui

    use qt
    use testing
    use iso_c_binding, only: c_double
    implicit none

    type(QApplication) :: app
    type(QColor) :: c
    type(QImage) :: img, loaded
    type(QPainter) :: p
    character(len=*), parameter :: png = 'build/test_gui.png'

    app = QApplication()

    ! --- QColor
    c = QColor(70, 130, 180)
    call check(c%red() == 70 .and. c%green() == 130 .and. c%blue() == 180 .and. c%alpha() == 255, &
               'QColor(r, g, b) components')
    call check(QColor('steelblue') == c, 'QColor(name) parses SVG color names')
    call check(QColor('#4682b4') == c, 'QColor(#hex)')
    call check(c%name() == '#4682b4', 'QColor name()')
    c = QColor('not-a-color')
    call check(.not. c%isValid(), 'invalid color name')
    call check(Qt_red == QColor(255, 0, 0) .and. Qt_red /= Qt_blue, 'Qt_* color constants, == and /=')
    call check(Qt_transparent%alpha() == 0, 'Qt_transparent')

    ! --- painting on an image
    img = QImage(40, 20)
    call check(.not. img%isNull() .and. img%width() == 40 .and. img%height() == 20, 'QImage(width, height)')
    call img%fill(Qt_white)
    call check(img%pixelColor(0, 0) == Qt_white, 'fill')

    p = QPainter(img)
    call check(p%isActive(), 'QPainter(image) is active')
    call check(p%deviceWidth() == 40 .and. p%deviceHeight() == 20, 'painter device size')
    call p%fillRect(10, 5, 10, 5, Qt_blue)                          ! integer coordinates
    call p%setPen(QPen(Qt_red, 1.0_c_double))
    call p%drawLine(0.5_c_double, 0.5_c_double, 39.5_c_double, 0.5_c_double)   ! real coordinates
    call p%setPen(QPen(style=Qt_NoPen))
    call p%setBrush(Qt_green)
    call p%drawRect(30, 10, 5, 5)
    call p%setPen(Qt_black)
    call p%drawPolyline([0, 5, 9], [19, 19, 19])
    call p%setFont(QFont(pointSize=8.0_c_double, bold=.true.))
    call check(p%textWidth('WWW') > p%textWidth('i') .and. p%fontHeight() > 0, 'font metrics')
    call p%end()
    call check(.not. p%isActive(), 'end')

    call check(img%pixelColor(12, 7) == Qt_blue, 'fillRect pixel')
    call check(img%pixelColor(20, 0) == Qt_red, 'drawLine pixel')
    call check(img%pixelColor(32, 12) == Qt_green, 'drawRect with brush and no pen')
    call check(img%pixelColor(5, 19) == Qt_black, 'drawPolyline (integer arrays)')
    call check(img%pixelColor(25, 15) == Qt_white, 'untouched pixel')
    call img%setPixelColor(39, 19, Qt_magenta)
    call check(img%pixelColor(39, 19) == Qt_magenta, 'setPixelColor')

    ! --- save and reload
    call check(img%save(png), 'QImage save PNG')
    loaded = QImage(png)
    call check(.not. loaded%isNull() .and. loaded%width() == 40, 'QImage(fileName) loads')
    call check(loaded%pixelColor(12, 7) == Qt_blue, 'reloaded pixel')
    loaded = QImage('does/not/exist.png')
    call check(loaded%isNull(), 'missing file gives a null image')
    call loaded%delete()
    call img%delete()

    write(*,'(A)') 'test_gui: all checks passed'

end program test_gui
