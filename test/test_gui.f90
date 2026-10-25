!> Gui value types and painting on images. Run headless (QT_QPA_PLATFORM=offscreen).
program test_gui

    use qt
    use testing
    use iso_c_binding, only: c_double
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
    implicit none

    type(QApplication) :: app
    type(QColor) :: c
    type(QImage) :: img, loaded, field, bar
    type(QPixmap) :: pix
    type(QIcon) :: icon
    type(QPainter) :: p
    type(QWindow) :: win
    real(c_double) :: values(4, 3)
    integer :: i
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

    ! --- arrays -> images through a colormap
    ! values(i, j) = 0, 1/11, ..., 1 (i fastest)
    values = reshape([(real(i, c_double) / 11, i = 0, 11)], [4, 3])
    field = QImage_fromArray(values, 'gray')
    call check(field%width() == 4 .and. field%height() == 3, 'fromArray size: (x, y) = shape')
    call check(field%pixelColor(0, 0) == Qt_black .and. field%pixelColor(3, 2) == Qt_white, &
               'gray: minimum black, maximum white')
    call check(field%pixelColor(1, 0) == QColor(23, 23, 23), 'gray: values(2, 1) = 1/11 at pixel (1, 0)')
    call field%delete()
    field = QImage_fromArray(values, 'gray', flipY=.true.)
    call check(field%pixelColor(0, 2) == Qt_black .and. field%pixelColor(3, 0) == Qt_white, &
               'flipY: values(:, 1) on the bottom row')
    call field%delete()
    field = QImage_fromArray(values, 'gray', vmin=0.25_c_double, vmax=0.5_c_double)
    call check(field%pixelColor(0, 0) == Qt_black .and. field%pixelColor(3, 2) == Qt_white, &
               'vmin/vmax: values outside are clamped')
    call field%delete()
    values(2, 2) = ieee_value(1.0_c_double, ieee_quiet_nan)
    field = QImage_fromArray(values)
    c = field%pixelColor(1, 1)
    call check(c%alpha() == 0, 'NaN is transparent')
    call check(field%pixelColor(0, 0) == QColor('#440154'), 'viridis is the default colormap')
    call check(field%pixelColor(3, 2) == QColor('#fde725'), 'viridis maximum')
    call field%delete()

    bar = QImage_colorbar('magma', 10, 100)
    call check(bar%width() == 10 .and. bar%height() == 100, 'colorbar size')
    call check(bar%pixelColor(5, 99) == QColor('#000004') .and. bar%pixelColor(5, 0) == QColor('#fcfdbf'), &
               'vertical colorbar: minimum at the bottom')
    pix = QPixmap_fromImage(bar)
    call check(pix%width() == 10 .and. pix%height() == 100, 'QPixmap_fromImage')
    icon = QIcon(pix)
    call check(.not. icon%isNull(), 'QIcon from a pixmap')
    call icon%delete()
    icon = QIcon('does/not/exist.png')
    call check(icon%isNull(), 'QIcon from a missing file is null')
    call icon%delete()
    call pix%delete()

    ! scaled drawing of a 2x1 image into a 40x20 rectangle
    field = QImage_fromArray(reshape([0.0_c_double, 1.0_c_double], [2, 1]), 'gray')
    img = QImage(40, 20)
    call img%fill(Qt_red)
    p = QPainter(img)
    call p%drawImage(0, 0, 40, 20, field)
    call p%end()
    call check(img%pixelColor(5, 10) == Qt_black .and. img%pixelColor(35, 10) == Qt_white, &
               'drawImage scaled into a rectangle')
    call img%delete()
    call field%delete()
    call bar%delete()

    ! the native handle of a window (for engines that render into it, e.g. Vulkan)
    win = QWindow()
    call win%create()
    call check(win%winId() /= 0, 'QWindow winId after create')

    write(*,'(A)') 'test_gui: all checks passed'

end program test_gui
