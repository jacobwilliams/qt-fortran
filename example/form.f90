!> A small form: type a name, pick options, click Submit to see a summary.
module form_slots

    use qt
    implicit none

    type :: form
        type(QMainWindow) :: window
        type(QLineEdit) :: name
        type(QSpinBox) :: age
        type(QComboBox) :: color
        type(QCheckBox) :: subscribe
        type(QPushButton) :: submit
        type(QStatusBar) :: status
    end type form

contains

    !> Enable Submit only when a name has been entered.
    subroutine on_name_changed(text, data)
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        select type (data)
        type is (form)
            call data%submit%setEnabled(len_trim(text) > 0)
            call data%status%showMessage('Editing: '//text)
        end select
    end subroutine on_name_changed

    subroutine on_submit(data)
        class(*), intent(inout), optional :: data
        character(len=16) :: age
        integer :: button
        select type (data)
        type is (form)
            write(age, '(I0)') data%age%value()
            button = QMessageBox_information('Submitted', &
                'Name: '//data%name%text()//new_line('a')// &
                'Age: '//trim(age)//new_line('a')// &
                'Favorite color: '//data%color%currentText()//new_line('a')// &
                'Subscribed: '//merge('yes', 'no ', data%subscribe%isChecked()), parent=data%window)
            call data%status%showMessage('Submitted', 3000)
        end select
    end subroutine on_submit

end module form_slots

program form_example

    use qt
    use form_slots
    implicit none

    type(QApplication) :: app
    type(form), target :: f
    type(QWidget) :: central
    type(QGridLayout) :: grid
    type(QVBoxLayout) :: vbox
    type(QHBoxLayout) :: buttons
    integer :: ierr

    app = QApplication()

    f%window = QMainWindow()
    call f%window%setWindowTitle('qt-fortran form')
    central = QWidget()
    vbox = QVBoxLayout(central)

    ! labelled fields in a grid
    grid = QGridLayout()
    f%name = QLineEdit()
    call f%name%setPlaceholderText('Your name')
    f%age = QSpinBox()
    call f%age%setRange(0, 150)
    call f%age%setValue(30)
    call f%age%setSuffix(' years')
    f%color = QComboBox()
    call f%color%addItems(['Red  ', 'Green', 'Blue '])
    f%subscribe = QCheckBox('Subscribe to newsletter')

    call grid%addWidget(QLabel('Name:'), 0, 0)
    call grid%addWidget(f%name, 0, 1)
    call grid%addWidget(QLabel('Age:'), 1, 0)
    call grid%addWidget(f%age, 1, 1)
    call grid%addWidget(QLabel('Color:'), 2, 0)
    call grid%addWidget(f%color, 2, 1)
    call grid%addWidget(f%subscribe, 3, 0, columnSpan=2)
    call grid%setColumnStretch(1, 1)
    call vbox%addLayout(grid)
    call vbox%addStretch()

    ! right-aligned Submit button
    buttons = QHBoxLayout()
    f%submit = QPushButton('Submit')
    call f%submit%setEnabled(.false.)
    call buttons%addStretch()
    call buttons%addWidget(f%submit)
    call vbox%addLayout(buttons)

    call f%window%setCentralWidget(central)
    f%status = f%window%statusBar()
    call f%status%showMessage('Enter your name')

    call f%name%textChanged%connect(on_name_changed, f)
    call f%submit%clicked%connect(on_submit, f)

    call f%window%resize(360, 220)
    call f%window%show()
    ierr = app%exec()

end program form_example
