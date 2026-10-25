!> Input widget tests: buttons, line edit, spin boxes, slider, combo box,
!> and every signal argument kind (none, logical, integer, real, string).
!> Run headless with QT_QPA_PLATFORM=offscreen.
module test_controls_slots

    use iso_c_binding, only: c_double
    implicit none

    !> Records what a slot received.
    type :: recorder
        integer :: calls = 0
        logical :: b = .false.
        integer :: i = -999
        real(c_double) :: d = -999.0_c_double
        character(len=:), allocatable :: s
    end type recorder

contains

    !> Count an emission of a signal without arguments.
    subroutine on_void(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
        end select
    end subroutine on_void

    !> Record a logical signal argument.
    subroutine on_bool(value, data)
        logical, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            data%b = value
        end select
    end subroutine on_bool

    !> Record an integer signal argument.
    subroutine on_int(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            data%i = value
        end select
    end subroutine on_int

    !> Record a real signal argument.
    subroutine on_double(value, data)
        real(c_double), intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            data%d = value
        end select
    end subroutine on_double

    !> Record a string signal argument.
    subroutine on_string(value, data)
        character(len=*), intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (recorder)
            data%calls = data%calls + 1
            data%s = value
        end select
    end subroutine on_string

end module test_controls_slots

!> Tests input widgets and every signal argument kind.
program test_controls

    use qt
    use testing
    use test_controls_slots
    use iso_c_binding, only: c_double
    implicit none

    type(QApplication) :: app
    type(QWidget) :: win
    type(QPushButton) :: button
    type(QCheckBox) :: check_box
    type(QRadioButton) :: radio
    type(QLineEdit) :: edit
    type(QSpinBox) :: spin
    type(QDoubleSpinBox) :: dspin
    type(QSlider) :: slider
    type(QComboBox) :: combo
    type(recorder), target :: clicked, toggled, text_changed, spin_changed, dspin_changed, &
                              slider_changed, index_changed, combo_text

    app = QApplication()
    win = QWidget()

    ! --- QPushButton: clicked (no argument), toggled (logical)
    button = QPushButton('Go', win)
    call check(button%text() == 'Go' .and. button%className() == 'QPushButton', 'QPushButton')
    call check(button%inherits('QAbstractButton'), 'QPushButton inherits QAbstractButton')
    call button%clicked%connect(on_void, clicked)
    call button%click()
    call button%click()
    call check(clicked%calls == 2, 'clicked fired per click')
    call button%setCheckable(.true.)
    call button%toggled%connect(on_bool, toggled)
    call button%click()
    call check(button%isChecked() .and. toggled%calls == 1 .and. toggled%b, 'toggled(.true.) on click')
    call button%toggle()
    call check(.not. button%isChecked() .and. toggled%calls == 2 .and. .not. toggled%b, 'toggled(.false.)')
    call button%setText('Stop')
    call check(button%text() == 'Stop', 'button setText')
    call button%setEnabled(.false.)
    call check(.not. button%isEnabled(), 'setEnabled(.false.)')

    ! --- QCheckBox / QRadioButton
    check_box = QCheckBox('Option', win)
    call check(check_box%isCheckable() .and. .not. check_box%isChecked(), 'QCheckBox initial state')
    call check_box%setChecked(.true.)
    call check(check_box%isChecked(), 'QCheckBox setChecked')
    radio = QRadioButton('Choice', win)
    call check(radio%className() == 'QRadioButton' .and. radio%text() == 'Choice', 'QRadioButton')

    ! --- QLineEdit: textChanged (string)
    edit = QLineEdit(parent=win)
    call edit%textChanged%connect(on_string, text_changed)
    call edit%setText('hello')
    call check(edit%text() == 'hello', 'QLineEdit setText/text')
    call check(text_changed%calls == 1 .and. text_changed%s == 'hello', 'textChanged(string)')
    call edit%clear()
    call check(edit%text() == '' .and. text_changed%s == '', 'clear emits empty text')
    call edit%setPlaceholderText('name')
    call check(edit%placeholderText() == 'name', 'placeholderText')
    call edit%setMaxLength(3)
    call edit%setText('abcdef')
    call check(edit%maxLength() == 3 .and. edit%text() == 'abc', 'maxLength truncates')
    call edit%setReadOnly(.true.)
    call check(edit%isReadOnly(), 'setReadOnly')

    ! --- QSpinBox: valueChanged (integer), clamping
    spin = QSpinBox(win)
    call spin%setRange(0, 10)
    call check(spin%minimum() == 0 .and. spin%maximum() == 10, 'QSpinBox range')
    call spin%valueChanged%connect(on_int, spin_changed)
    call spin%setValue(15)
    call check(spin%value() == 10, 'QSpinBox clamps to maximum')
    call check(spin_changed%calls == 1 .and. spin_changed%i == 10, 'valueChanged(integer)')
    call spin%setSingleStep(2)
    call check(spin%singleStep() == 2, 'QSpinBox singleStep')
    call spin%setSuffix(' px')

    ! --- QDoubleSpinBox: valueChanged (real)
    dspin = QDoubleSpinBox(win)
    call dspin%setRange(-1.0_c_double, 1.0_c_double)
    call dspin%setDecimals(3)
    call check(dspin%decimals() == 3, 'QDoubleSpinBox decimals')
    call dspin%valueChanged%connect(on_double, dspin_changed)
    call dspin%setValue(0.25_c_double)
    call check(dspin%value() == 0.25_c_double, 'QDoubleSpinBox value')
    call check(dspin_changed%calls == 1 .and. dspin_changed%d == 0.25_c_double, 'valueChanged(real)')
    call dspin%setValue(5.0_c_double)
    call check(dspin%value() == dspin%maximum(), 'QDoubleSpinBox clamps to maximum')

    ! --- QSlider: valueChanged (integer)
    slider = QSlider(Qt_Horizontal, win)
    call check(slider%orientation() == Qt_Horizontal, 'QSlider orientation')
    call slider%setRange(0, 100)
    call slider%valueChanged%connect(on_int, slider_changed)
    call slider%setValue(42)
    call check(slider%value() == 42 .and. slider_changed%i == 42, 'QSlider valueChanged')

    ! --- QComboBox: currentIndexChanged (integer), currentTextChanged (string)
    combo = QComboBox(win)
    call combo%addItems(['red  ', 'green', 'blue '])
    call check(combo%count() == 3, 'addItems (trimmed)')
    call check(combo%currentIndex() == 0 .and. combo%currentText() == 'red', 'first item selected')
    call combo%currentIndexChanged%connect(on_int, index_changed)
    call combo%currentTextChanged%connect(on_string, combo_text)
    call combo%setCurrentIndex(2)
    call check(index_changed%i == 2 .and. combo_text%s == 'blue', 'currentIndexChanged/currentTextChanged')
    call check(combo%findText('green') == 1 .and. combo%findText('pink') == -1, 'findText (0-based)')
    call check(combo%itemText(1) == 'green', 'itemText')
    call combo%insertItem(0, 'black')
    call check(combo%itemText(0) == 'black' .and. combo%count() == 4, 'insertItem')
    call combo%removeItem(0)
    call combo%clear()
    call check(combo%count() == 0 .and. combo%currentIndex() == -1, 'clear')

    call win%delete()
    call check(qt_slot_count() == 0, 'all slots released with the window')

    write(*,'(A)') 'test_controls: all checks passed'

end program test_controls
