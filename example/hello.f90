!> Spike: open a window with a label, from Fortran.
program hello

    use qt
    implicit none

    type(QApplication) :: app
    type(QLabel) :: label

    app = QApplication()

    label = QLabel("Hello from Fortran!")
    call label%setWindowTitle("qt-fortran")
    call label%setAlignment(Qt_AlignCenter)
    call label%resize(320, 120)
    call label%show()

    stop app%exec()

end program hello
