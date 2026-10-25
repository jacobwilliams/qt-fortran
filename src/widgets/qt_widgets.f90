!> Qt Widgets: application, basic widgets, layouts, main window and dialogs.
!>
!> Indices (e.g. combo box items) are 0-based, as in Qt.
module qt_widgets

    use iso_c_binding
    use qt_c_core, only: qtf_take_string, qtf_logical, qtf_int
    use qt_c_widgets
    use qt_core
    implicit none
    private

    ! QDialog::DialogCode
    integer(c_int), parameter, public :: QDialog_Rejected = 0
    integer(c_int), parameter, public :: QDialog_Accepted = 1

    ! QMessageBox::StandardButton
    integer(c_int), parameter, public :: QMessageBox_NoButton        = 0
    integer(c_int), parameter, public :: QMessageBox_Ok              = int(z'00000400', c_int)
    integer(c_int), parameter, public :: QMessageBox_Save            = int(z'00000800', c_int)
    integer(c_int), parameter, public :: QMessageBox_SaveAll         = int(z'00001000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Open            = int(z'00002000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Yes             = int(z'00004000', c_int)
    integer(c_int), parameter, public :: QMessageBox_YesToAll        = int(z'00008000', c_int)
    integer(c_int), parameter, public :: QMessageBox_No              = int(z'00010000', c_int)
    integer(c_int), parameter, public :: QMessageBox_NoToAll         = int(z'00020000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Abort           = int(z'00040000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Retry           = int(z'00080000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Ignore          = int(z'00100000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Close           = int(z'00200000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Cancel          = int(z'00400000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Discard         = int(z'00800000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Help            = int(z'01000000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Apply           = int(z'02000000', c_int)
    integer(c_int), parameter, public :: QMessageBox_Reset           = int(z'04000000', c_int)
    integer(c_int), parameter, public :: QMessageBox_RestoreDefaults = int(z'08000000', c_int)

    ! QMessageBox::Icon (qualified with the enum name: Fortran is case-insensitive,
    ! so QMessageBox_Information would clash with the QMessageBox_information function)
    integer(c_int), parameter, public :: QMessageBox_Icon_NoIcon      = 0
    integer(c_int), parameter, public :: QMessageBox_Icon_Information = 1
    integer(c_int), parameter, public :: QMessageBox_Icon_Warning     = 2
    integer(c_int), parameter, public :: QMessageBox_Icon_Critical    = 3
    integer(c_int), parameter, public :: QMessageBox_Icon_Question    = 4

    ! ------------------------------------------------------------------

    !> The application object. Create exactly one, before any widget.
    type, extends(QObject), public :: QApplication
    contains
        procedure, nopass :: exec => QApplication_exec
        procedure, nopass :: quit => QApplication_quit
        procedure, nopass :: processEvents => QApplication_processEvents
    end type QApplication
    interface QApplication
        module procedure :: qapplication_new
    end interface QApplication

    type, extends(QObject), public :: QWidget
    contains
        procedure :: show => qwidget_show
        procedure :: hide => qwidget_hide
        procedure :: close => qwidget_close
        procedure :: setVisible => qwidget_setVisible
        procedure :: isVisible => qwidget_isVisible
        procedure :: setEnabled => qwidget_setEnabled
        procedure :: isEnabled => qwidget_isEnabled
        procedure :: resize => qwidget_resize
        procedure :: width => qwidget_width
        procedure :: height => qwidget_height
        procedure :: setMinimumSize => qwidget_setMinimumSize
        procedure :: setFixedSize => qwidget_setFixedSize
        procedure :: setWindowTitle => qwidget_setWindowTitle
        procedure :: windowTitle => qwidget_windowTitle
        procedure :: setToolTip => qwidget_setToolTip
        procedure :: toolTip => qwidget_toolTip
        procedure :: setStyleSheet => qwidget_setStyleSheet
        procedure :: setFocus => qwidget_setFocus
        procedure :: setLayout => qwidget_setLayout
        procedure :: layout => qwidget_layout
    end type QWidget
    interface QWidget
        module procedure :: qwidget_new
    end interface QWidget

    type, extends(QWidget), public :: QLabel
    contains
        procedure :: setText => qlabel_setText
        procedure :: text => qlabel_text
        procedure :: setAlignment => qlabel_setAlignment
        procedure :: setWordWrap => qlabel_setWordWrap
    end type QLabel
    interface QLabel
        module procedure :: qlabel_new
    end interface QLabel

    !> Base of push buttons, check boxes and radio buttons.
    !> `clicked` carries no argument; use `toggled` for the checked state.
    type, extends(QWidget), public :: QAbstractButton
        type(QSignal) :: clicked
        type(QSignalBool) :: toggled
        type(QSignal) :: pressed
        type(QSignal) :: released
    contains
        procedure :: attach => qabstractbutton_attach
        procedure :: setText => qabstractbutton_setText
        procedure :: text => qabstractbutton_text
        procedure :: setCheckable => qabstractbutton_setCheckable
        procedure :: isCheckable => qabstractbutton_isCheckable
        procedure :: setChecked => qabstractbutton_setChecked
        procedure :: isChecked => qabstractbutton_isChecked
        procedure :: click => qabstractbutton_click
        procedure :: toggle => qabstractbutton_toggle
    end type QAbstractButton

    type, extends(QAbstractButton), public :: QPushButton
    contains
        procedure :: setDefault => qpushbutton_setDefault
    end type QPushButton
    interface QPushButton
        module procedure :: qpushbutton_new
    end interface QPushButton

    type, extends(QAbstractButton), public :: QCheckBox
    end type QCheckBox
    interface QCheckBox
        module procedure :: qcheckbox_new
    end interface QCheckBox

    type, extends(QAbstractButton), public :: QRadioButton
    end type QRadioButton
    interface QRadioButton
        module procedure :: qradiobutton_new
    end interface QRadioButton

    type, extends(QWidget), public :: QLineEdit
        type(QSignalString) :: textChanged
        type(QSignalString) :: textEdited
        type(QSignal) :: returnPressed
        type(QSignal) :: editingFinished
    contains
        procedure :: attach => qlineedit_attach
        procedure :: setText => qlineedit_setText
        procedure :: text => qlineedit_text
        procedure :: setPlaceholderText => qlineedit_setPlaceholderText
        procedure :: placeholderText => qlineedit_placeholderText
        procedure :: setReadOnly => qlineedit_setReadOnly
        procedure :: isReadOnly => qlineedit_isReadOnly
        procedure :: setMaxLength => qlineedit_setMaxLength
        procedure :: maxLength => qlineedit_maxLength
        procedure :: clear => qlineedit_clear
    end type QLineEdit
    interface QLineEdit
        module procedure :: qlineedit_new
    end interface QLineEdit

    type, extends(QWidget), public :: QSpinBox
        type(QSignalInt) :: valueChanged
    contains
        procedure :: attach => qspinbox_attach
        procedure :: setRange => qspinbox_setRange
        procedure :: minimum => qspinbox_minimum
        procedure :: maximum => qspinbox_maximum
        procedure :: setValue => qspinbox_setValue
        procedure :: value => qspinbox_value
        procedure :: setSingleStep => qspinbox_setSingleStep
        procedure :: singleStep => qspinbox_singleStep
        procedure :: setPrefix => qspinbox_setPrefix
        procedure :: setSuffix => qspinbox_setSuffix
    end type QSpinBox
    interface QSpinBox
        module procedure :: qspinbox_new
    end interface QSpinBox

    !> Spin box for real values (`real(c_double)`, i.e. real64).
    type, extends(QWidget), public :: QDoubleSpinBox
        type(QSignalDouble) :: valueChanged
    contains
        procedure :: attach => qdoublespinbox_attach
        procedure :: setRange => qdoublespinbox_setRange
        procedure :: minimum => qdoublespinbox_minimum
        procedure :: maximum => qdoublespinbox_maximum
        procedure :: setValue => qdoublespinbox_setValue
        procedure :: value => qdoublespinbox_value
        procedure :: setSingleStep => qdoublespinbox_setSingleStep
        procedure :: singleStep => qdoublespinbox_singleStep
        procedure :: setDecimals => qdoublespinbox_setDecimals
        procedure :: decimals => qdoublespinbox_decimals
        procedure :: setPrefix => qdoublespinbox_setPrefix
        procedure :: setSuffix => qdoublespinbox_setSuffix
    end type QDoubleSpinBox
    interface QDoubleSpinBox
        module procedure :: qdoublespinbox_new
    end interface QDoubleSpinBox

    type, extends(QWidget), public :: QAbstractSlider
        type(QSignalInt) :: valueChanged
        type(QSignalInt) :: sliderMoved
        type(QSignal) :: sliderPressed
        type(QSignal) :: sliderReleased
    contains
        procedure :: attach => qabstractslider_attach
        procedure :: setRange => qabstractslider_setRange
        procedure :: minimum => qabstractslider_minimum
        procedure :: maximum => qabstractslider_maximum
        procedure :: setValue => qabstractslider_setValue
        procedure :: value => qabstractslider_value
        procedure :: setSingleStep => qabstractslider_setSingleStep
        procedure :: setPageStep => qabstractslider_setPageStep
        procedure :: setOrientation => qabstractslider_setOrientation
        procedure :: orientation => qabstractslider_orientation
    end type QAbstractSlider

    type, extends(QAbstractSlider), public :: QSlider
    end type QSlider
    interface QSlider
        module procedure :: qslider_new
    end interface QSlider

    type, extends(QWidget), public :: QComboBox
        type(QSignalInt) :: currentIndexChanged
        type(QSignalString) :: currentTextChanged
        type(QSignalInt) :: activated
    contains
        procedure :: attach => qcombobox_attach
        procedure :: addItem => qcombobox_addItem
        procedure :: addItems => qcombobox_addItems
        procedure :: insertItem => qcombobox_insertItem
        procedure :: removeItem => qcombobox_removeItem
        procedure :: clear => qcombobox_clear
        procedure :: count => qcombobox_count
        procedure :: currentIndex => qcombobox_currentIndex
        procedure :: setCurrentIndex => qcombobox_setCurrentIndex
        procedure :: currentText => qcombobox_currentText
        procedure :: setCurrentText => qcombobox_setCurrentText
        procedure :: itemText => qcombobox_itemText
        procedure :: findText => qcombobox_findText
        procedure :: setEditable => qcombobox_setEditable
    end type QComboBox
    interface QComboBox
        module procedure :: qcombobox_new
    end interface QComboBox

    !> Base of all layouts. `addWidget` is defined per layout type, since box
    !> and grid layouts take different arguments.
    type, extends(QObject), public :: QLayout
    contains
        procedure :: setContentsMargins => qlayout_setContentsMargins
        procedure :: setSpacing => qlayout_setSpacing
        procedure :: spacing => qlayout_spacing
        procedure :: count => qlayout_count
    end type QLayout

    type, extends(QLayout), public :: QBoxLayout
    contains
        procedure :: addWidget => qboxlayout_addWidget
        procedure :: addLayout => qboxlayout_addLayout
        procedure :: addStretch => qboxlayout_addStretch
        procedure :: addSpacing => qboxlayout_addSpacing
    end type QBoxLayout

    type, extends(QBoxLayout), public :: QVBoxLayout
    end type QVBoxLayout
    interface QVBoxLayout
        module procedure :: qvboxlayout_new
    end interface QVBoxLayout

    type, extends(QBoxLayout), public :: QHBoxLayout
    end type QHBoxLayout
    interface QHBoxLayout
        module procedure :: qhboxlayout_new
    end interface QHBoxLayout

    type, extends(QLayout), public :: QGridLayout
    contains
        procedure :: addWidget => qgridlayout_addWidget
        procedure :: addLayout => qgridlayout_addLayout
        procedure :: setRowStretch => qgridlayout_setRowStretch
        procedure :: setColumnStretch => qgridlayout_setColumnStretch
        procedure :: rowCount => qgridlayout_rowCount
        procedure :: columnCount => qgridlayout_columnCount
    end type QGridLayout
    interface QGridLayout
        module procedure :: qgridlayout_new
    end interface QGridLayout

    type, extends(QWidget), public :: QStatusBar
    contains
        procedure :: showMessage => qstatusbar_showMessage
        procedure :: clearMessage => qstatusbar_clearMessage
        procedure :: currentMessage => qstatusbar_currentMessage
    end type QStatusBar

    type, extends(QWidget), public :: QMainWindow
    contains
        procedure :: setCentralWidget => qmainwindow_setCentralWidget
        procedure :: centralWidget => qmainwindow_centralWidget
        procedure :: statusBar => qmainwindow_statusBar
    end type QMainWindow
    interface QMainWindow
        module procedure :: qmainwindow_new
    end interface QMainWindow

    type, extends(QWidget), public :: QDialog
        type(QSignal) :: accepted
        type(QSignal) :: rejected
        type(QSignalInt) :: finished
    contains
        procedure :: attach => qdialog_attach
        procedure :: exec => qdialog_exec
        procedure :: open => qdialog_open
        procedure :: accept => qdialog_accept
        procedure :: reject => qdialog_reject
        procedure :: done => qdialog_done
        procedure :: result => qdialog_result
        procedure :: setModal => qdialog_setModal
    end type QDialog
    interface QDialog
        module procedure :: qdialog_new
    end interface QDialog

    type, extends(QDialog), public :: QMessageBox
    contains
        procedure :: setText => qmessagebox_setText
        procedure :: text => qmessagebox_text
        procedure :: setInformativeText => qmessagebox_setInformativeText
        procedure :: informativeText => qmessagebox_informativeText
        procedure :: setIcon => qmessagebox_setIcon
        procedure :: setStandardButtons => qmessagebox_setStandardButtons
        procedure :: setDefaultButton => qmessagebox_setDefaultButton
        procedure :: button => qmessagebox_button
    end type QMessageBox
    interface QMessageBox
        module procedure :: qmessagebox_new
    end interface QMessageBox

    public :: QApplication_exec, QApplication_quit, QApplication_processEvents
    public :: QApplication_activeModalWidget
    public :: QMessageBox_information, QMessageBox_warning, QMessageBox_critical
    public :: QMessageBox_question

contains

    ! ------------------------------------------------------------------
    ! QApplication

    function qapplication_new() result(app)
        type(QApplication) :: app
        call app%attach(qtf_qapplication_new())
    end function qapplication_new

    !> Run the event loop until quit; returns the exit code.
    integer function QApplication_exec()
        QApplication_exec = qtf_qapplication_exec()
    end function QApplication_exec

    subroutine QApplication_quit()
        call qtf_qapplication_quit()
    end subroutine QApplication_quit

    subroutine QApplication_processEvents()
        call qtf_qapplication_processEvents()
    end subroutine QApplication_processEvents

    !> The active modal dialog (null if none).
    function QApplication_activeModalWidget() result(w)
        type(QWidget) :: w
        call w%attach(qtf_qapplication_activeModalWidget())
    end function QApplication_activeModalWidget

    ! ------------------------------------------------------------------
    ! QWidget

    function qwidget_new(parent) result(w)
        class(QWidget), intent(in), optional :: parent
        type(QWidget) :: w
        call w%attach(qtf_qwidget_new(qtf_ptr(parent)))
    end function qwidget_new

    subroutine qwidget_show(self)
        class(QWidget), intent(in) :: self
        call qtf_qwidget_show(self%ptr)
    end subroutine qwidget_show

    subroutine qwidget_hide(self)
        class(QWidget), intent(in) :: self
        call qtf_qwidget_hide(self%ptr)
    end subroutine qwidget_hide

    subroutine qwidget_close(self)
        class(QWidget), intent(in) :: self
        call qtf_qwidget_close(self%ptr)
    end subroutine qwidget_close

    subroutine qwidget_setVisible(self, visible)
        class(QWidget), intent(in) :: self
        logical, intent(in) :: visible
        call qtf_qwidget_setVisible(self%ptr, qtf_int(visible))
    end subroutine qwidget_setVisible

    logical function qwidget_isVisible(self)
        class(QWidget), intent(in) :: self
        qwidget_isVisible = qtf_logical(qtf_qwidget_isVisible(self%ptr))
    end function qwidget_isVisible

    subroutine qwidget_setEnabled(self, enabled)
        class(QWidget), intent(in) :: self
        logical, intent(in) :: enabled
        call qtf_qwidget_setEnabled(self%ptr, qtf_int(enabled))
    end subroutine qwidget_setEnabled

    logical function qwidget_isEnabled(self)
        class(QWidget), intent(in) :: self
        qwidget_isEnabled = qtf_logical(qtf_qwidget_isEnabled(self%ptr))
    end function qwidget_isEnabled

    subroutine qwidget_resize(self, width, height)
        class(QWidget), intent(in) :: self
        integer, intent(in) :: width, height
        call qtf_qwidget_resize(self%ptr, int(width, c_int), int(height, c_int))
    end subroutine qwidget_resize

    integer function qwidget_width(self)
        class(QWidget), intent(in) :: self
        qwidget_width = qtf_qwidget_width(self%ptr)
    end function qwidget_width

    integer function qwidget_height(self)
        class(QWidget), intent(in) :: self
        qwidget_height = qtf_qwidget_height(self%ptr)
    end function qwidget_height

    subroutine qwidget_setMinimumSize(self, width, height)
        class(QWidget), intent(in) :: self
        integer, intent(in) :: width, height
        call qtf_qwidget_setMinimumSize(self%ptr, int(width, c_int), int(height, c_int))
    end subroutine qwidget_setMinimumSize

    subroutine qwidget_setFixedSize(self, width, height)
        class(QWidget), intent(in) :: self
        integer, intent(in) :: width, height
        call qtf_qwidget_setFixedSize(self%ptr, int(width, c_int), int(height, c_int))
    end subroutine qwidget_setFixedSize

    subroutine qwidget_setWindowTitle(self, title)
        class(QWidget), intent(in) :: self
        character(len=*), intent(in) :: title
        call qtf_qwidget_setWindowTitle(self%ptr, title, len(title, c_int))
    end subroutine qwidget_setWindowTitle

    function qwidget_windowTitle(self) result(title)
        class(QWidget), intent(in) :: self
        character(len=:), allocatable :: title
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qwidget_windowTitle(self%ptr, n)
        title = qtf_take_string(p, n)
    end function qwidget_windowTitle

    subroutine qwidget_setToolTip(self, text)
        class(QWidget), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qwidget_setToolTip(self%ptr, text, len(text, c_int))
    end subroutine qwidget_setToolTip

    function qwidget_toolTip(self) result(text)
        class(QWidget), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qwidget_toolTip(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qwidget_toolTip

    subroutine qwidget_setStyleSheet(self, styleSheet)
        class(QWidget), intent(in) :: self
        character(len=*), intent(in) :: styleSheet
        call qtf_qwidget_setStyleSheet(self%ptr, styleSheet, len(styleSheet, c_int))
    end subroutine qwidget_setStyleSheet

    subroutine qwidget_setFocus(self)
        class(QWidget), intent(in) :: self
        call qtf_qwidget_setFocus(self%ptr)
    end subroutine qwidget_setFocus

    !> Install `layout` on this widget (the widget takes ownership).
    subroutine qwidget_setLayout(self, layout)
        class(QWidget), intent(in) :: self
        class(QLayout), intent(in) :: layout
        call qtf_qwidget_setLayout(self%ptr, layout%ptr)
    end subroutine qwidget_setLayout

    function qwidget_layout(self) result(layout)
        class(QWidget), intent(in) :: self
        type(QLayout) :: layout
        call layout%attach(qtf_qwidget_layout(self%ptr))
    end function qwidget_layout

    ! ------------------------------------------------------------------
    ! QLabel

    function qlabel_new(text, parent) result(w)
        character(len=*), intent(in), optional :: text
        class(QWidget), intent(in), optional :: parent
        type(QLabel) :: w
        if (present(text)) then
            call w%attach(qtf_qlabel_new(text, len(text, c_int), qtf_ptr(parent)))
        else
            call w%attach(qtf_qlabel_new('', 0_c_int, qtf_ptr(parent)))
        end if
    end function qlabel_new

    subroutine qlabel_setText(self, text)
        class(QLabel), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qlabel_setText(self%ptr, text, len(text, c_int))
    end subroutine qlabel_setText

    function qlabel_text(self) result(text)
        class(QLabel), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qlabel_text(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qlabel_text

    subroutine qlabel_setAlignment(self, alignment)
        class(QLabel), intent(in) :: self
        integer, intent(in) :: alignment
        call qtf_qlabel_setAlignment(self%ptr, int(alignment, c_int))
    end subroutine qlabel_setAlignment

    subroutine qlabel_setWordWrap(self, on)
        class(QLabel), intent(in) :: self
        logical, intent(in) :: on
        call qtf_qlabel_setWordWrap(self%ptr, qtf_int(on))
    end subroutine qlabel_setWordWrap

    ! ------------------------------------------------------------------
    ! QAbstractButton, QPushButton, QCheckBox, QRadioButton

    subroutine qabstractbutton_attach(self, ptr)
        class(QAbstractButton), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QWidget%attach(ptr)
        self%clicked = QSignal(ptr, QTF_SIG_QABSTRACTBUTTON_CLICKED)
        self%toggled = QSignalBool(ptr, QTF_SIG_QABSTRACTBUTTON_TOGGLED)
        self%pressed = QSignal(ptr, QTF_SIG_QABSTRACTBUTTON_PRESSED)
        self%released = QSignal(ptr, QTF_SIG_QABSTRACTBUTTON_RELEASED)
    end subroutine qabstractbutton_attach

    subroutine qabstractbutton_setText(self, text)
        class(QAbstractButton), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qabstractbutton_setText(self%ptr, text, len(text, c_int))
    end subroutine qabstractbutton_setText

    function qabstractbutton_text(self) result(text)
        class(QAbstractButton), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qabstractbutton_text(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qabstractbutton_text

    subroutine qabstractbutton_setCheckable(self, checkable)
        class(QAbstractButton), intent(in) :: self
        logical, intent(in) :: checkable
        call qtf_qabstractbutton_setCheckable(self%ptr, qtf_int(checkable))
    end subroutine qabstractbutton_setCheckable

    logical function qabstractbutton_isCheckable(self)
        class(QAbstractButton), intent(in) :: self
        qabstractbutton_isCheckable = qtf_logical(qtf_qabstractbutton_isCheckable(self%ptr))
    end function qabstractbutton_isCheckable

    subroutine qabstractbutton_setChecked(self, checked)
        class(QAbstractButton), intent(in) :: self
        logical, intent(in) :: checked
        call qtf_qabstractbutton_setChecked(self%ptr, qtf_int(checked))
    end subroutine qabstractbutton_setChecked

    logical function qabstractbutton_isChecked(self)
        class(QAbstractButton), intent(in) :: self
        qabstractbutton_isChecked = qtf_logical(qtf_qabstractbutton_isChecked(self%ptr))
    end function qabstractbutton_isChecked

    !> Simulate a click (emits pressed, released, clicked, and toggled if checkable).
    subroutine qabstractbutton_click(self)
        class(QAbstractButton), intent(in) :: self
        call qtf_qabstractbutton_click(self%ptr)
    end subroutine qabstractbutton_click

    subroutine qabstractbutton_toggle(self)
        class(QAbstractButton), intent(in) :: self
        call qtf_qabstractbutton_toggle(self%ptr)
    end subroutine qabstractbutton_toggle

    function qpushbutton_new(text, parent) result(b)
        character(len=*), intent(in), optional :: text
        class(QWidget), intent(in), optional :: parent
        type(QPushButton) :: b
        if (present(text)) then
            call b%attach(qtf_qpushbutton_new(text, len(text, c_int), qtf_ptr(parent)))
        else
            call b%attach(qtf_qpushbutton_new('', 0_c_int, qtf_ptr(parent)))
        end if
    end function qpushbutton_new

    subroutine qpushbutton_setDefault(self, default)
        class(QPushButton), intent(in) :: self
        logical, intent(in) :: default
        call qtf_qpushbutton_setDefault(self%ptr, qtf_int(default))
    end subroutine qpushbutton_setDefault

    function qcheckbox_new(text, parent) result(b)
        character(len=*), intent(in), optional :: text
        class(QWidget), intent(in), optional :: parent
        type(QCheckBox) :: b
        if (present(text)) then
            call b%attach(qtf_qcheckbox_new(text, len(text, c_int), qtf_ptr(parent)))
        else
            call b%attach(qtf_qcheckbox_new('', 0_c_int, qtf_ptr(parent)))
        end if
    end function qcheckbox_new

    function qradiobutton_new(text, parent) result(b)
        character(len=*), intent(in), optional :: text
        class(QWidget), intent(in), optional :: parent
        type(QRadioButton) :: b
        if (present(text)) then
            call b%attach(qtf_qradiobutton_new(text, len(text, c_int), qtf_ptr(parent)))
        else
            call b%attach(qtf_qradiobutton_new('', 0_c_int, qtf_ptr(parent)))
        end if
    end function qradiobutton_new

    ! ------------------------------------------------------------------
    ! QLineEdit

    function qlineedit_new(text, parent) result(e)
        character(len=*), intent(in), optional :: text
        class(QWidget), intent(in), optional :: parent
        type(QLineEdit) :: e
        if (present(text)) then
            call e%attach(qtf_qlineedit_new(text, len(text, c_int), qtf_ptr(parent)))
        else
            call e%attach(qtf_qlineedit_new('', 0_c_int, qtf_ptr(parent)))
        end if
    end function qlineedit_new

    subroutine qlineedit_attach(self, ptr)
        class(QLineEdit), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QWidget%attach(ptr)
        self%textChanged = QSignalString(ptr, QTF_SIG_QLINEEDIT_TEXTCHANGED)
        self%textEdited = QSignalString(ptr, QTF_SIG_QLINEEDIT_TEXTEDITED)
        self%returnPressed = QSignal(ptr, QTF_SIG_QLINEEDIT_RETURNPRESSED)
        self%editingFinished = QSignal(ptr, QTF_SIG_QLINEEDIT_EDITINGFINISHED)
    end subroutine qlineedit_attach

    subroutine qlineedit_setText(self, text)
        class(QLineEdit), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qlineedit_setText(self%ptr, text, len(text, c_int))
    end subroutine qlineedit_setText

    function qlineedit_text(self) result(text)
        class(QLineEdit), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qlineedit_text(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qlineedit_text

    subroutine qlineedit_setPlaceholderText(self, text)
        class(QLineEdit), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qlineedit_setPlaceholderText(self%ptr, text, len(text, c_int))
    end subroutine qlineedit_setPlaceholderText

    function qlineedit_placeholderText(self) result(text)
        class(QLineEdit), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qlineedit_placeholderText(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qlineedit_placeholderText

    subroutine qlineedit_setReadOnly(self, readOnly)
        class(QLineEdit), intent(in) :: self
        logical, intent(in) :: readOnly
        call qtf_qlineedit_setReadOnly(self%ptr, qtf_int(readOnly))
    end subroutine qlineedit_setReadOnly

    logical function qlineedit_isReadOnly(self)
        class(QLineEdit), intent(in) :: self
        qlineedit_isReadOnly = qtf_logical(qtf_qlineedit_isReadOnly(self%ptr))
    end function qlineedit_isReadOnly

    subroutine qlineedit_setMaxLength(self, n)
        class(QLineEdit), intent(in) :: self
        integer, intent(in) :: n
        call qtf_qlineedit_setMaxLength(self%ptr, int(n, c_int))
    end subroutine qlineedit_setMaxLength

    integer function qlineedit_maxLength(self)
        class(QLineEdit), intent(in) :: self
        qlineedit_maxLength = qtf_qlineedit_maxLength(self%ptr)
    end function qlineedit_maxLength

    subroutine qlineedit_clear(self)
        class(QLineEdit), intent(in) :: self
        call qtf_qlineedit_clear(self%ptr)
    end subroutine qlineedit_clear

    ! ------------------------------------------------------------------
    ! QSpinBox

    function qspinbox_new(parent) result(s)
        class(QWidget), intent(in), optional :: parent
        type(QSpinBox) :: s
        call s%attach(qtf_qspinbox_new(qtf_ptr(parent)))
    end function qspinbox_new

    subroutine qspinbox_attach(self, ptr)
        class(QSpinBox), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QWidget%attach(ptr)
        self%valueChanged = QSignalInt(ptr, QTF_SIG_QSPINBOX_VALUECHANGED)
    end subroutine qspinbox_attach

    subroutine qspinbox_setRange(self, minimum, maximum)
        class(QSpinBox), intent(in) :: self
        integer, intent(in) :: minimum, maximum
        call qtf_qspinbox_setRange(self%ptr, int(minimum, c_int), int(maximum, c_int))
    end subroutine qspinbox_setRange

    integer function qspinbox_minimum(self)
        class(QSpinBox), intent(in) :: self
        qspinbox_minimum = qtf_qspinbox_minimum(self%ptr)
    end function qspinbox_minimum

    integer function qspinbox_maximum(self)
        class(QSpinBox), intent(in) :: self
        qspinbox_maximum = qtf_qspinbox_maximum(self%ptr)
    end function qspinbox_maximum

    subroutine qspinbox_setValue(self, value)
        class(QSpinBox), intent(in) :: self
        integer, intent(in) :: value
        call qtf_qspinbox_setValue(self%ptr, int(value, c_int))
    end subroutine qspinbox_setValue

    integer function qspinbox_value(self)
        class(QSpinBox), intent(in) :: self
        qspinbox_value = qtf_qspinbox_value(self%ptr)
    end function qspinbox_value

    subroutine qspinbox_setSingleStep(self, step)
        class(QSpinBox), intent(in) :: self
        integer, intent(in) :: step
        call qtf_qspinbox_setSingleStep(self%ptr, int(step, c_int))
    end subroutine qspinbox_setSingleStep

    integer function qspinbox_singleStep(self)
        class(QSpinBox), intent(in) :: self
        qspinbox_singleStep = qtf_qspinbox_singleStep(self%ptr)
    end function qspinbox_singleStep

    subroutine qspinbox_setPrefix(self, prefix)
        class(QSpinBox), intent(in) :: self
        character(len=*), intent(in) :: prefix
        call qtf_qspinbox_setPrefix(self%ptr, prefix, len(prefix, c_int))
    end subroutine qspinbox_setPrefix

    subroutine qspinbox_setSuffix(self, suffix)
        class(QSpinBox), intent(in) :: self
        character(len=*), intent(in) :: suffix
        call qtf_qspinbox_setSuffix(self%ptr, suffix, len(suffix, c_int))
    end subroutine qspinbox_setSuffix

    ! ------------------------------------------------------------------
    ! QDoubleSpinBox

    function qdoublespinbox_new(parent) result(s)
        class(QWidget), intent(in), optional :: parent
        type(QDoubleSpinBox) :: s
        call s%attach(qtf_qdoublespinbox_new(qtf_ptr(parent)))
    end function qdoublespinbox_new

    subroutine qdoublespinbox_attach(self, ptr)
        class(QDoubleSpinBox), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QWidget%attach(ptr)
        self%valueChanged = QSignalDouble(ptr, QTF_SIG_QDOUBLESPINBOX_VALUECHANGED)
    end subroutine qdoublespinbox_attach

    subroutine qdoublespinbox_setRange(self, minimum, maximum)
        class(QDoubleSpinBox), intent(in) :: self
        real(c_double), intent(in) :: minimum, maximum
        call qtf_qdoublespinbox_setRange(self%ptr, minimum, maximum)
    end subroutine qdoublespinbox_setRange

    real(c_double) function qdoublespinbox_minimum(self)
        class(QDoubleSpinBox), intent(in) :: self
        qdoublespinbox_minimum = qtf_qdoublespinbox_minimum(self%ptr)
    end function qdoublespinbox_minimum

    real(c_double) function qdoublespinbox_maximum(self)
        class(QDoubleSpinBox), intent(in) :: self
        qdoublespinbox_maximum = qtf_qdoublespinbox_maximum(self%ptr)
    end function qdoublespinbox_maximum

    subroutine qdoublespinbox_setValue(self, value)
        class(QDoubleSpinBox), intent(in) :: self
        real(c_double), intent(in) :: value
        call qtf_qdoublespinbox_setValue(self%ptr, value)
    end subroutine qdoublespinbox_setValue

    real(c_double) function qdoublespinbox_value(self)
        class(QDoubleSpinBox), intent(in) :: self
        qdoublespinbox_value = qtf_qdoublespinbox_value(self%ptr)
    end function qdoublespinbox_value

    subroutine qdoublespinbox_setSingleStep(self, step)
        class(QDoubleSpinBox), intent(in) :: self
        real(c_double), intent(in) :: step
        call qtf_qdoublespinbox_setSingleStep(self%ptr, step)
    end subroutine qdoublespinbox_setSingleStep

    real(c_double) function qdoublespinbox_singleStep(self)
        class(QDoubleSpinBox), intent(in) :: self
        qdoublespinbox_singleStep = qtf_qdoublespinbox_singleStep(self%ptr)
    end function qdoublespinbox_singleStep

    subroutine qdoublespinbox_setDecimals(self, decimals)
        class(QDoubleSpinBox), intent(in) :: self
        integer, intent(in) :: decimals
        call qtf_qdoublespinbox_setDecimals(self%ptr, int(decimals, c_int))
    end subroutine qdoublespinbox_setDecimals

    integer function qdoublespinbox_decimals(self)
        class(QDoubleSpinBox), intent(in) :: self
        qdoublespinbox_decimals = qtf_qdoublespinbox_decimals(self%ptr)
    end function qdoublespinbox_decimals

    subroutine qdoublespinbox_setPrefix(self, prefix)
        class(QDoubleSpinBox), intent(in) :: self
        character(len=*), intent(in) :: prefix
        call qtf_qdoublespinbox_setPrefix(self%ptr, prefix, len(prefix, c_int))
    end subroutine qdoublespinbox_setPrefix

    subroutine qdoublespinbox_setSuffix(self, suffix)
        class(QDoubleSpinBox), intent(in) :: self
        character(len=*), intent(in) :: suffix
        call qtf_qdoublespinbox_setSuffix(self%ptr, suffix, len(suffix, c_int))
    end subroutine qdoublespinbox_setSuffix

    ! ------------------------------------------------------------------
    ! QAbstractSlider, QSlider

    !> A slider; `orientation` is Qt_Horizontal or Qt_Vertical (default, as in Qt).
    function qslider_new(orientation, parent) result(s)
        integer, intent(in), optional :: orientation
        class(QWidget), intent(in), optional :: parent
        type(QSlider) :: s
        integer(c_int) :: o
        o = Qt_Vertical
        if (present(orientation)) o = int(orientation, c_int)
        call s%attach(qtf_qslider_new(o, qtf_ptr(parent)))
    end function qslider_new

    subroutine qabstractslider_attach(self, ptr)
        class(QAbstractSlider), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QWidget%attach(ptr)
        self%valueChanged = QSignalInt(ptr, QTF_SIG_QABSTRACTSLIDER_VALUECHANGED)
        self%sliderMoved = QSignalInt(ptr, QTF_SIG_QABSTRACTSLIDER_SLIDERMOVED)
        self%sliderPressed = QSignal(ptr, QTF_SIG_QABSTRACTSLIDER_SLIDERPRESSED)
        self%sliderReleased = QSignal(ptr, QTF_SIG_QABSTRACTSLIDER_SLIDERRELEASED)
    end subroutine qabstractslider_attach

    subroutine qabstractslider_setRange(self, minimum, maximum)
        class(QAbstractSlider), intent(in) :: self
        integer, intent(in) :: minimum, maximum
        call qtf_qabstractslider_setRange(self%ptr, int(minimum, c_int), int(maximum, c_int))
    end subroutine qabstractslider_setRange

    integer function qabstractslider_minimum(self)
        class(QAbstractSlider), intent(in) :: self
        qabstractslider_minimum = qtf_qabstractslider_minimum(self%ptr)
    end function qabstractslider_minimum

    integer function qabstractslider_maximum(self)
        class(QAbstractSlider), intent(in) :: self
        qabstractslider_maximum = qtf_qabstractslider_maximum(self%ptr)
    end function qabstractslider_maximum

    subroutine qabstractslider_setValue(self, value)
        class(QAbstractSlider), intent(in) :: self
        integer, intent(in) :: value
        call qtf_qabstractslider_setValue(self%ptr, int(value, c_int))
    end subroutine qabstractslider_setValue

    integer function qabstractslider_value(self)
        class(QAbstractSlider), intent(in) :: self
        qabstractslider_value = qtf_qabstractslider_value(self%ptr)
    end function qabstractslider_value

    subroutine qabstractslider_setSingleStep(self, step)
        class(QAbstractSlider), intent(in) :: self
        integer, intent(in) :: step
        call qtf_qabstractslider_setSingleStep(self%ptr, int(step, c_int))
    end subroutine qabstractslider_setSingleStep

    subroutine qabstractslider_setPageStep(self, step)
        class(QAbstractSlider), intent(in) :: self
        integer, intent(in) :: step
        call qtf_qabstractslider_setPageStep(self%ptr, int(step, c_int))
    end subroutine qabstractslider_setPageStep

    subroutine qabstractslider_setOrientation(self, orientation)
        class(QAbstractSlider), intent(in) :: self
        integer, intent(in) :: orientation
        call qtf_qabstractslider_setOrientation(self%ptr, int(orientation, c_int))
    end subroutine qabstractslider_setOrientation

    integer function qabstractslider_orientation(self)
        class(QAbstractSlider), intent(in) :: self
        qabstractslider_orientation = qtf_qabstractslider_orientation(self%ptr)
    end function qabstractslider_orientation

    ! ------------------------------------------------------------------
    ! QComboBox

    function qcombobox_new(parent) result(c)
        class(QWidget), intent(in), optional :: parent
        type(QComboBox) :: c
        call c%attach(qtf_qcombobox_new(qtf_ptr(parent)))
    end function qcombobox_new

    subroutine qcombobox_attach(self, ptr)
        class(QComboBox), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QWidget%attach(ptr)
        self%currentIndexChanged = QSignalInt(ptr, QTF_SIG_QCOMBOBOX_CURRENTINDEXCHANGED)
        self%currentTextChanged = QSignalString(ptr, QTF_SIG_QCOMBOBOX_CURRENTTEXTCHANGED)
        self%activated = QSignalInt(ptr, QTF_SIG_QCOMBOBOX_ACTIVATED)
    end subroutine qcombobox_attach

    subroutine qcombobox_addItem(self, text)
        class(QComboBox), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qcombobox_addItem(self%ptr, text, len(text, c_int))
    end subroutine qcombobox_addItem

    !> Add several items; trailing blanks of each element are trimmed.
    subroutine qcombobox_addItems(self, texts)
        class(QComboBox), intent(in) :: self
        character(len=*), intent(in) :: texts(:)
        integer :: i
        do i = 1, size(texts)
            call self%addItem(trim(texts(i)))
        end do
    end subroutine qcombobox_addItems

    subroutine qcombobox_insertItem(self, index, text)
        class(QComboBox), intent(in) :: self
        integer, intent(in) :: index
        character(len=*), intent(in) :: text
        call qtf_qcombobox_insertItem(self%ptr, int(index, c_int), text, len(text, c_int))
    end subroutine qcombobox_insertItem

    subroutine qcombobox_removeItem(self, index)
        class(QComboBox), intent(in) :: self
        integer, intent(in) :: index
        call qtf_qcombobox_removeItem(self%ptr, int(index, c_int))
    end subroutine qcombobox_removeItem

    subroutine qcombobox_clear(self)
        class(QComboBox), intent(in) :: self
        call qtf_qcombobox_clear(self%ptr)
    end subroutine qcombobox_clear

    integer function qcombobox_count(self)
        class(QComboBox), intent(in) :: self
        qcombobox_count = qtf_qcombobox_count(self%ptr)
    end function qcombobox_count

    !> Index of the current item (0-based; -1 if none).
    integer function qcombobox_currentIndex(self)
        class(QComboBox), intent(in) :: self
        qcombobox_currentIndex = qtf_qcombobox_currentIndex(self%ptr)
    end function qcombobox_currentIndex

    subroutine qcombobox_setCurrentIndex(self, index)
        class(QComboBox), intent(in) :: self
        integer, intent(in) :: index
        call qtf_qcombobox_setCurrentIndex(self%ptr, int(index, c_int))
    end subroutine qcombobox_setCurrentIndex

    function qcombobox_currentText(self) result(text)
        class(QComboBox), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qcombobox_currentText(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qcombobox_currentText

    subroutine qcombobox_setCurrentText(self, text)
        class(QComboBox), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qcombobox_setCurrentText(self%ptr, text, len(text, c_int))
    end subroutine qcombobox_setCurrentText

    function qcombobox_itemText(self, index) result(text)
        class(QComboBox), intent(in) :: self
        integer, intent(in) :: index
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qcombobox_itemText(self%ptr, int(index, c_int), n)
        text = qtf_take_string(p, n)
    end function qcombobox_itemText

    !> Index of the item with this text (0-based; -1 if not found).
    integer function qcombobox_findText(self, text)
        class(QComboBox), intent(in) :: self
        character(len=*), intent(in) :: text
        qcombobox_findText = qtf_qcombobox_findText(self%ptr, text, len(text, c_int))
    end function qcombobox_findText

    subroutine qcombobox_setEditable(self, editable)
        class(QComboBox), intent(in) :: self
        logical, intent(in) :: editable
        call qtf_qcombobox_setEditable(self%ptr, qtf_int(editable))
    end subroutine qcombobox_setEditable

    ! ------------------------------------------------------------------
    ! QLayout, QBoxLayout, QVBoxLayout, QHBoxLayout, QGridLayout

    subroutine qlayout_setContentsMargins(self, left, top, right, bottom)
        class(QLayout), intent(in) :: self
        integer, intent(in) :: left, top, right, bottom
        call qtf_qlayout_setContentsMargins(self%ptr, int(left, c_int), int(top, c_int), &
                                            int(right, c_int), int(bottom, c_int))
    end subroutine qlayout_setContentsMargins

    subroutine qlayout_setSpacing(self, spacing)
        class(QLayout), intent(in) :: self
        integer, intent(in) :: spacing
        call qtf_qlayout_setSpacing(self%ptr, int(spacing, c_int))
    end subroutine qlayout_setSpacing

    integer function qlayout_spacing(self)
        class(QLayout), intent(in) :: self
        qlayout_spacing = qtf_qlayout_spacing(self%ptr)
    end function qlayout_spacing

    !> Number of items (widgets, layouts, stretches) in the layout.
    integer function qlayout_count(self)
        class(QLayout), intent(in) :: self
        qlayout_count = qtf_qlayout_count(self%ptr)
    end function qlayout_count

    !> A vertical box layout, installed on `parent` if given.
    function qvboxlayout_new(parent) result(l)
        class(QWidget), intent(in), optional :: parent
        type(QVBoxLayout) :: l
        call l%attach(qtf_qvboxlayout_new(qtf_ptr(parent)))
    end function qvboxlayout_new

    !> A horizontal box layout, installed on `parent` if given.
    function qhboxlayout_new(parent) result(l)
        class(QWidget), intent(in), optional :: parent
        type(QHBoxLayout) :: l
        call l%attach(qtf_qhboxlayout_new(qtf_ptr(parent)))
    end function qhboxlayout_new

    subroutine qboxlayout_addWidget(self, widget, stretch, alignment)
        class(QBoxLayout), intent(in) :: self
        class(QWidget), intent(in) :: widget
        integer, intent(in), optional :: stretch, alignment
        integer(c_int) :: s, a
        s = 0
        a = 0
        if (present(stretch)) s = int(stretch, c_int)
        if (present(alignment)) a = int(alignment, c_int)
        call qtf_qboxlayout_addWidget(self%ptr, widget%ptr, s, a)
    end subroutine qboxlayout_addWidget

    subroutine qboxlayout_addLayout(self, layout, stretch)
        class(QBoxLayout), intent(in) :: self
        class(QLayout), intent(in) :: layout
        integer, intent(in), optional :: stretch
        integer(c_int) :: s
        s = 0
        if (present(stretch)) s = int(stretch, c_int)
        call qtf_qboxlayout_addLayout(self%ptr, layout%ptr, s)
    end subroutine qboxlayout_addLayout

    subroutine qboxlayout_addStretch(self, stretch)
        class(QBoxLayout), intent(in) :: self
        integer, intent(in), optional :: stretch
        integer(c_int) :: s
        s = 0
        if (present(stretch)) s = int(stretch, c_int)
        call qtf_qboxlayout_addStretch(self%ptr, s)
    end subroutine qboxlayout_addStretch

    subroutine qboxlayout_addSpacing(self, size)
        class(QBoxLayout), intent(in) :: self
        integer, intent(in) :: size
        call qtf_qboxlayout_addSpacing(self%ptr, int(size, c_int))
    end subroutine qboxlayout_addSpacing

    !> A grid layout, installed on `parent` if given.
    function qgridlayout_new(parent) result(l)
        class(QWidget), intent(in), optional :: parent
        type(QGridLayout) :: l
        call l%attach(qtf_qgridlayout_new(qtf_ptr(parent)))
    end function qgridlayout_new

    !> Add a widget at (row, column), both 0-based, optionally spanning cells.
    subroutine qgridlayout_addWidget(self, widget, row, column, rowSpan, columnSpan, alignment)
        class(QGridLayout), intent(in) :: self
        class(QWidget), intent(in) :: widget
        integer, intent(in) :: row, column
        integer, intent(in), optional :: rowSpan, columnSpan, alignment
        integer(c_int) :: rs, cs, a
        rs = 1
        cs = 1
        a = 0
        if (present(rowSpan)) rs = int(rowSpan, c_int)
        if (present(columnSpan)) cs = int(columnSpan, c_int)
        if (present(alignment)) a = int(alignment, c_int)
        call qtf_qgridlayout_addWidget(self%ptr, widget%ptr, int(row, c_int), int(column, c_int), rs, cs, a)
    end subroutine qgridlayout_addWidget

    subroutine qgridlayout_addLayout(self, layout, row, column, rowSpan, columnSpan, alignment)
        class(QGridLayout), intent(in) :: self
        class(QLayout), intent(in) :: layout
        integer, intent(in) :: row, column
        integer, intent(in), optional :: rowSpan, columnSpan, alignment
        integer(c_int) :: rs, cs, a
        rs = 1
        cs = 1
        a = 0
        if (present(rowSpan)) rs = int(rowSpan, c_int)
        if (present(columnSpan)) cs = int(columnSpan, c_int)
        if (present(alignment)) a = int(alignment, c_int)
        call qtf_qgridlayout_addLayout(self%ptr, layout%ptr, int(row, c_int), int(column, c_int), rs, cs, a)
    end subroutine qgridlayout_addLayout

    subroutine qgridlayout_setRowStretch(self, row, stretch)
        class(QGridLayout), intent(in) :: self
        integer, intent(in) :: row, stretch
        call qtf_qgridlayout_setRowStretch(self%ptr, int(row, c_int), int(stretch, c_int))
    end subroutine qgridlayout_setRowStretch

    subroutine qgridlayout_setColumnStretch(self, column, stretch)
        class(QGridLayout), intent(in) :: self
        integer, intent(in) :: column, stretch
        call qtf_qgridlayout_setColumnStretch(self%ptr, int(column, c_int), int(stretch, c_int))
    end subroutine qgridlayout_setColumnStretch

    integer function qgridlayout_rowCount(self)
        class(QGridLayout), intent(in) :: self
        qgridlayout_rowCount = qtf_qgridlayout_rowCount(self%ptr)
    end function qgridlayout_rowCount

    integer function qgridlayout_columnCount(self)
        class(QGridLayout), intent(in) :: self
        qgridlayout_columnCount = qtf_qgridlayout_columnCount(self%ptr)
    end function qgridlayout_columnCount

    ! ------------------------------------------------------------------
    ! QStatusBar, QMainWindow

    !> Show a message; it is cleared after `timeout` ms (default 0: stays).
    subroutine qstatusbar_showMessage(self, message, timeout)
        class(QStatusBar), intent(in) :: self
        character(len=*), intent(in) :: message
        integer, intent(in), optional :: timeout
        integer(c_int) :: t
        t = 0
        if (present(timeout)) t = int(timeout, c_int)
        call qtf_qstatusbar_showMessage(self%ptr, message, len(message, c_int), t)
    end subroutine qstatusbar_showMessage

    subroutine qstatusbar_clearMessage(self)
        class(QStatusBar), intent(in) :: self
        call qtf_qstatusbar_clearMessage(self%ptr)
    end subroutine qstatusbar_clearMessage

    function qstatusbar_currentMessage(self) result(message)
        class(QStatusBar), intent(in) :: self
        character(len=:), allocatable :: message
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qstatusbar_currentMessage(self%ptr, n)
        message = qtf_take_string(p, n)
    end function qstatusbar_currentMessage

    function qmainwindow_new(parent) result(m)
        class(QWidget), intent(in), optional :: parent
        type(QMainWindow) :: m
        call m%attach(qtf_qmainwindow_new(qtf_ptr(parent)))
    end function qmainwindow_new

    !> Set the central widget (the window takes ownership).
    subroutine qmainwindow_setCentralWidget(self, widget)
        class(QMainWindow), intent(in) :: self
        class(QWidget), intent(in) :: widget
        call qtf_qmainwindow_setCentralWidget(self%ptr, widget%ptr)
    end subroutine qmainwindow_setCentralWidget

    function qmainwindow_centralWidget(self) result(w)
        class(QMainWindow), intent(in) :: self
        type(QWidget) :: w
        call w%attach(qtf_qmainwindow_centralWidget(self%ptr))
    end function qmainwindow_centralWidget

    !> The window's status bar (created on first use).
    function qmainwindow_statusBar(self) result(bar)
        class(QMainWindow), intent(in) :: self
        type(QStatusBar) :: bar
        call bar%attach(qtf_qmainwindow_statusBar(self%ptr))
    end function qmainwindow_statusBar

    ! ------------------------------------------------------------------
    ! QDialog

    function qdialog_new(parent) result(d)
        class(QWidget), intent(in), optional :: parent
        type(QDialog) :: d
        call d%attach(qtf_qdialog_new(qtf_ptr(parent)))
    end function qdialog_new

    subroutine qdialog_attach(self, ptr)
        class(QDialog), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QWidget%attach(ptr)
        self%accepted = QSignal(ptr, QTF_SIG_QDIALOG_ACCEPTED)
        self%rejected = QSignal(ptr, QTF_SIG_QDIALOG_REJECTED)
        self%finished = QSignalInt(ptr, QTF_SIG_QDIALOG_FINISHED)
    end subroutine qdialog_attach

    !> Show as a modal dialog and block until closed; returns the result code.
    integer function qdialog_exec(self)
        class(QDialog), intent(in) :: self
        qdialog_exec = qtf_qdialog_exec(self%ptr)
    end function qdialog_exec

    !> Show as a window-modal dialog and return immediately.
    subroutine qdialog_open(self)
        class(QDialog), intent(in) :: self
        call qtf_qdialog_open(self%ptr)
    end subroutine qdialog_open

    subroutine qdialog_accept(self)
        class(QDialog), intent(in) :: self
        call qtf_qdialog_accept(self%ptr)
    end subroutine qdialog_accept

    subroutine qdialog_reject(self)
        class(QDialog), intent(in) :: self
        call qtf_qdialog_reject(self%ptr)
    end subroutine qdialog_reject

    subroutine qdialog_done(self, r)
        class(QDialog), intent(in) :: self
        integer, intent(in) :: r
        call qtf_qdialog_done(self%ptr, int(r, c_int))
    end subroutine qdialog_done

    integer function qdialog_result(self)
        class(QDialog), intent(in) :: self
        qdialog_result = qtf_qdialog_result(self%ptr)
    end function qdialog_result

    subroutine qdialog_setModal(self, modal)
        class(QDialog), intent(in) :: self
        logical, intent(in) :: modal
        call qtf_qdialog_setModal(self%ptr, qtf_int(modal))
    end subroutine qdialog_setModal

    ! ------------------------------------------------------------------
    ! QMessageBox

    function qmessagebox_new(parent) result(m)
        class(QWidget), intent(in), optional :: parent
        type(QMessageBox) :: m
        call m%attach(qtf_qmessagebox_new(qtf_ptr(parent)))
    end function qmessagebox_new

    subroutine qmessagebox_setText(self, text)
        class(QMessageBox), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qmessagebox_setText(self%ptr, text, len(text, c_int))
    end subroutine qmessagebox_setText

    function qmessagebox_text(self) result(text)
        class(QMessageBox), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qmessagebox_text(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qmessagebox_text

    subroutine qmessagebox_setInformativeText(self, text)
        class(QMessageBox), intent(in) :: self
        character(len=*), intent(in) :: text
        call qtf_qmessagebox_setInformativeText(self%ptr, text, len(text, c_int))
    end subroutine qmessagebox_setInformativeText

    function qmessagebox_informativeText(self) result(text)
        class(QMessageBox), intent(in) :: self
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qmessagebox_informativeText(self%ptr, n)
        text = qtf_take_string(p, n)
    end function qmessagebox_informativeText

    subroutine qmessagebox_setIcon(self, icon)
        class(QMessageBox), intent(in) :: self
        integer, intent(in) :: icon
        call qtf_qmessagebox_setIcon(self%ptr, int(icon, c_int))
    end subroutine qmessagebox_setIcon

    !> Set the buttons, e.g. ior(QMessageBox_Yes, QMessageBox_No).
    subroutine qmessagebox_setStandardButtons(self, buttons)
        class(QMessageBox), intent(in) :: self
        integer, intent(in) :: buttons
        call qtf_qmessagebox_setStandardButtons(self%ptr, int(buttons, c_int))
    end subroutine qmessagebox_setStandardButtons

    subroutine qmessagebox_setDefaultButton(self, button)
        class(QMessageBox), intent(in) :: self
        integer, intent(in) :: button
        call qtf_qmessagebox_setDefaultButton(self%ptr, int(button, c_int))
    end subroutine qmessagebox_setDefaultButton

    !> The button widget for a standard button (null if not present).
    function qmessagebox_button(self, which) result(b)
        class(QMessageBox), intent(in) :: self
        integer, intent(in) :: which
        type(QAbstractButton) :: b
        call b%attach(qtf_qmessagebox_button(self%ptr, int(which, c_int)))
    end function qmessagebox_button

    !> Shared implementation of the static QMessageBox dialogs.
    integer function messagebox_static(which, title, text, buttons, defaultButton, parent)
        integer(c_int), intent(in) :: which
        character(len=*), intent(in) :: title, text
        integer, intent(in) :: buttons
        integer, intent(in), optional :: defaultButton
        class(QWidget), intent(in), optional :: parent
        integer(c_int) :: d
        d = QMessageBox_NoButton
        if (present(defaultButton)) d = int(defaultButton, c_int)
        messagebox_static = qtf_qmessagebox_static(which, qtf_ptr(parent), title, len(title, c_int), &
                                                   text, len(text, c_int), int(buttons, c_int), d)
    end function messagebox_static

    !> Modal information box; returns the standard button clicked.
    integer function QMessageBox_information(title, text, buttons, defaultButton, parent)
        character(len=*), intent(in) :: title, text
        integer, intent(in), optional :: buttons, defaultButton
        class(QWidget), intent(in), optional :: parent
        integer :: b
        b = QMessageBox_Ok
        if (present(buttons)) b = buttons
        QMessageBox_information = messagebox_static(1_c_int, title, text, b, defaultButton, parent)
    end function QMessageBox_information

    !> Modal warning box; returns the standard button clicked.
    integer function QMessageBox_warning(title, text, buttons, defaultButton, parent)
        character(len=*), intent(in) :: title, text
        integer, intent(in), optional :: buttons, defaultButton
        class(QWidget), intent(in), optional :: parent
        integer :: b
        b = QMessageBox_Ok
        if (present(buttons)) b = buttons
        QMessageBox_warning = messagebox_static(2_c_int, title, text, b, defaultButton, parent)
    end function QMessageBox_warning

    !> Modal critical-error box; returns the standard button clicked.
    integer function QMessageBox_critical(title, text, buttons, defaultButton, parent)
        character(len=*), intent(in) :: title, text
        integer, intent(in), optional :: buttons, defaultButton
        class(QWidget), intent(in), optional :: parent
        integer :: b
        b = QMessageBox_Ok
        if (present(buttons)) b = buttons
        QMessageBox_critical = messagebox_static(3_c_int, title, text, b, defaultButton, parent)
    end function QMessageBox_critical

    !> Modal question box (default buttons Yes|No); returns the standard button clicked.
    integer function QMessageBox_question(title, text, buttons, defaultButton, parent)
        character(len=*), intent(in) :: title, text
        integer, intent(in), optional :: buttons, defaultButton
        class(QWidget), intent(in), optional :: parent
        integer :: b
        b = ior(QMessageBox_Yes, QMessageBox_No)
        if (present(buttons)) b = buttons
        QMessageBox_question = messagebox_static(4_c_int, title, text, b, defaultButton, parent)
    end function QMessageBox_question

end module qt_widgets
