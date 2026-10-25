!> Layout and main window tests. Run headless with QT_QPA_PLATFORM=offscreen.
program test_layouts

    use qt
    use testing
    use iso_c_binding, only: c_associated
    implicit none

    type(QApplication) :: app
    type(QMainWindow) :: main
    type(QWidget) :: central, w
    type(QVBoxLayout) :: vbox
    type(QHBoxLayout) :: hbox
    type(QGridLayout) :: grid
    type(QLayout) :: l
    type(QLabel) :: title, a, b, c
    type(QPushButton) :: ok, cancel
    type(QStatusBar) :: bar
    type(QObject) :: p

    app = QApplication()

    ! --- box layouts: widgets added to a layout get reparented to its widget
    central = QWidget()
    vbox = QVBoxLayout(central)
    l = central%layout()
    call check(c_associated(l%ptr, vbox%ptr), 'QVBoxLayout(parent) installs itself')
    title = QLabel('Title')
    call vbox%addWidget(title, alignment=Qt_AlignCenter)
    p = title%parent()
    call check(c_associated(p%ptr, central%ptr), 'addWidget reparents widget')

    hbox = QHBoxLayout()
    ok = QPushButton('OK')
    cancel = QPushButton('Cancel')
    call hbox%addStretch()
    call hbox%addWidget(ok)
    call hbox%addSpacing(8)
    call hbox%addWidget(cancel, stretch=1)
    call check(hbox%count() == 4, 'QHBoxLayout count (stretch, widget, spacing, widget)')
    call vbox%addLayout(hbox)
    call check(vbox%count() == 2, 'nested layout')
    p = ok%parent()
    call check(c_associated(p%ptr, central%ptr), 'nested layout widgets reparented')
    call vbox%setSpacing(6)
    call check(vbox%spacing() == 6, 'setSpacing/spacing')
    call vbox%setContentsMargins(4, 4, 4, 4)

    ! --- grid layout
    w = QWidget()
    grid = QGridLayout(w)
    a = QLabel('a')
    b = QLabel('b')
    c = QLabel('c')
    call grid%addWidget(a, 0, 0)
    call grid%addWidget(b, 0, 1)
    call grid%addWidget(c, 1, 0, columnSpan=2)
    call check(grid%rowCount() == 2 .and. grid%columnCount() == 2, 'grid rows/columns')
    call grid%setColumnStretch(1, 1)
    call grid%setRowStretch(1, 1)
    call check(grid%count() == 3, 'grid count')
    call w%delete()

    ! --- main window, central widget, status bar
    main = QMainWindow()
    call main%setCentralWidget(central)
    w = main%centralWidget()
    call check(c_associated(w%ptr, central%ptr), 'setCentralWidget/centralWidget')
    bar = main%statusBar()
    call check(bar%className() == 'QStatusBar', 'statusBar')
    call bar%showMessage('Ready')
    call check(bar%currentMessage() == 'Ready', 'showMessage/currentMessage')
    call bar%clearMessage()
    call check(bar%currentMessage() == '', 'clearMessage')
    call main%resize(400, 300)
    call main%show()
    call check(main%isVisible() .and. ok%isVisible(), 'main window and children visible')

    call main%delete()
    call check(main%isNull(), 'main window deleted')

    write(*,'(A)') 'test_layouts: all checks passed'

end program test_layouts
