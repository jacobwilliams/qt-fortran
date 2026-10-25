!> QDialogButtonBox, validators, QCompleter, QDateTimeEdit, QTextBrowser,
!> QToolBox, QSplashScreen, QMdiArea, QWizard, QUndoStack/QUndoView and
!> window states. Run headless with QT_QPA_PLATFORM=offscreen.
module test_more_widgets_slots

    use qt
    implicit none

    !> What the slots saw, and the "document" the undo commands edit.
    type :: state_t
        integer :: accepted = 0, rejected = 0, button = -99, role = -99, changed = 0, page = -1
        integer :: value = 0                 !! the edited document
        integer :: old(10) = 0, new(10) = 0  !! per command id: value before and after
        character(len=:), allocatable :: text
    end type state_t

contains

    !> Count accepted.
    subroutine on_accepted(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (state_t)
            data%accepted = data%accepted + 1
        end select
    end subroutine on_accepted

    !> Count rejected.
    subroutine on_rejected(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (state_t)
            data%rejected = data%rejected + 1
        end select
    end subroutine on_rejected

    !> Record the clicked standard button.
    subroutine on_clicked(button, data)
        integer, intent(in) :: button
        class(*), intent(inout), optional :: data
        select type (data)
        type is (state_t)
            data%button = button
        end select
    end subroutine on_clicked

    !> Record the clicked button's role.
    subroutine on_role(role, data)
        integer, intent(in) :: role
        class(*), intent(inout), optional :: data
        select type (data)
        type is (state_t)
            data%role = role
        end select
    end subroutine on_role

    !> Count changes.
    subroutine on_changed(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (state_t)
            data%changed = data%changed + 1
        end select
    end subroutine on_changed

    !> Record an integer (a page index or id).
    subroutine on_page(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (data)
        type is (state_t)
            data%page = index
        end select
    end subroutine on_page

    !> Perform (redo) command `id`.
    subroutine on_redo(id, data)
        integer, intent(in) :: id
        class(*), intent(inout), optional :: data
        select type (data)
        type is (state_t)
            data%value = data%new(id)
        end select
    end subroutine on_redo

    !> Reverse command `id`.
    subroutine on_undo(id, data)
        integer, intent(in) :: id
        class(*), intent(inout), optional :: data
        select type (data)
        type is (state_t)
            data%value = data%old(id)
        end select
    end subroutine on_undo

    !> Record a string.
    subroutine on_text(text, data)
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        select type (data)
        type is (state_t)
            data%text = text
        end select
    end subroutine on_text

    !> Leave the event loop.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

    !> Run the event loop briefly (deferred deletions, layout).
    subroutine spin()
        integer :: ierr
        call QTimer_singleShot(0, on_quit)
        ierr = QApplication_exec()
    end subroutine spin

    !> Record a new value for command `id` and push it.
    subroutine set_value(stack, s, id, v)
        type(QUndoStack), intent(in) :: stack
        type(state_t), intent(inout) :: s
        integer, intent(in) :: id, v
        character(len=12) :: text
        s%old(id) = s%value
        s%new(id) = v
        write(text, '(A,I0)') 'Set ', v
        call stack%push(trim(text), id)
    end subroutine set_value

end module test_more_widgets_slots

!> Tests the widgets added for complex applications.
program test_more_widgets

    use qt
    use testing
    use test_more_widgets_slots
    use iso_c_binding, only: c_associated, c_double
    implicit none

    character(len=*), parameter :: page1 = 'build/test_help1.html', page2 = 'build/test_help2.html'
    type(QApplication) :: app
    type(QObject) :: owner
    type(QDialog) :: dialog
    type(QDialogButtonBox) :: box
    type(QPushButton) :: ok, extra
    type(QIntValidator) :: iv
    type(QDoubleValidator) :: dv
    type(QRegularExpressionValidator) :: rv
    type(QLineEdit) :: line, name_edit
    type(QCompleter) :: completer
    type(QDateTimeEdit) :: dte
    type(QDateTime) :: t
    type(QTextBrowser) :: browser
    type(QToolBox) :: toolbox
    type(QSplashScreen) :: splash
    type(QPixmap) :: pix
    type(QWidget) :: window
    type(QMdiArea) :: area
    type(QMdiSubWindow) :: sub1, sub2, active
    type(QWizard) :: wizard
    type(QWizardPage) :: p1, p2
    type(QSpinBox) :: spin_box
    type(QVBoxLayout) :: layout
    type(QUndoStack) :: stack
    type(QUndoView) :: undo_view
    type(QAction) :: undo_action
    type(state_t), target :: s
    integer :: u

    app = QApplication()
    owner = QObject()

    ! --- QDialogButtonBox
    dialog = QDialog()
    box = QDialogButtonBox(ior(QDialogButtonBox_Ok, QDialogButtonBox_Cancel), dialog)
    call box%accepted%connect(on_accepted, s)
    call box%rejected%connect(on_rejected, s)
    call box%clicked%connect(on_clicked, s)
    call box%clickedRole%connect(on_role, s)
    call check(box%standardButtons() == ior(QDialogButtonBox_Ok, QDialogButtonBox_Cancel), 'standardButtons')
    ok = box%button(QDialogButtonBox_Ok)
    call ok%click()
    call check(s%accepted == 1 .and. s%button == QDialogButtonBox_Ok .and. s%role == QDialogButtonBox_AcceptRole, &
               'OK: accepted, clicked, role')
    ok = box%button(QDialogButtonBox_Cancel)
    call ok%click()
    call check(s%rejected == 1 .and. s%button == QDialogButtonBox_Cancel, 'Cancel: rejected')
    extra = box%addButton('Plot', QDialogButtonBox_ActionRole)
    call extra%click()
    call check(s%button == QDialogButtonBox_NoButton .and. s%role == QDialogButtonBox_ActionRole, 'custom button')
    ok = box%button(QDialogButtonBox_Save)
    call check(ok%isNull(), 'absent button is null')
    call dialog%delete()

    ! --- validators
    iv = QIntValidator(0, 100, owner)
    call check(iv%validate('50') == QValidator_Acceptable .and. iv%validate('abc') == QValidator_Invalid, 'QIntValidator')
    call check(iv%top() == 100 .and. iv%bottom() == 0, 'QIntValidator range')
    dv = QDoubleValidator(0.0_c_double, 10.0_c_double, 2, owner)
    call check(dv%validate('3.14') == QValidator_Acceptable .and. dv%validate('3.141') == QValidator_Invalid, &
               'QDoubleValidator decimals')
    call check(dv%validate('1e1') == QValidator_Acceptable .and. dv%validate('x') == QValidator_Invalid, &
               'QDoubleValidator scientific, C locale')
    rv = QRegularExpressionValidator('[A-Z]{2}[0-9]{2}', owner)
    call check(rv%validate('AB12') == QValidator_Acceptable .and. rv%validate('AB') == QValidator_Intermediate &
               .and. rv%validate('12') == QValidator_Invalid, 'QRegularExpressionValidator')
    call check(rv%pattern() == '[A-Z]{2}[0-9]{2}', 'pattern')
    line = QLineEdit()
    call line%setValidator(iv)
    call line%setText('42')
    call check(line%hasAcceptableInput(), 'acceptable input')
    call line%setValidator(rv)
    call line%setText('A')
    call check(.not. line%hasAcceptableInput(), 'intermediate input is not acceptable')
    call line%setValidator()
    call check(line%hasAcceptableInput(), 'validator removed')

    ! --- QCompleter
    completer = QCompleter(['apple  ', 'apricot', 'banana '], owner)
    call completer%setCompletionPrefix('ap')
    call check(completer%completionCount() == 2 .and. completer%currentCompletion() == 'apple', 'completions')
    call completer%setFilterMode(Qt_MatchContains)
    call completer%setCompletionPrefix('an')
    call check(completer%completionCount() == 1 .and. completer%currentCompletion() == 'banana', 'MatchContains')
    call completer%setItems(['cherry'])
    call completer%setCompletionPrefix('ch')
    call check(completer%completionCount() == 1, 'setItems')
    call line%setCompleter(completer)
    call line%setCompleter()

    ! --- QDateTimeEdit
    dte = QDateTimeEdit()
    call dte%dateTimeChanged%connect(on_changed, s)
    call dte%setDisplayFormat('yyyy-MM-dd HH:mm')
    call dte%setDateTime(QDateTime(2026, 10, 25, 14, 30))
    t = dte%dateTime()
    call check(t == QDateTime(2026, 10, 25, 14, 30) .and. s%changed == 1, 'QDateTimeEdit')
    call check(dte%displayFormat() == 'yyyy-MM-dd HH:mm', 'displayFormat')

    ! --- QTextBrowser with linked pages
    open(newunit=u, file=page1, status='replace')
    write(u, '(A)') '<h1>Page one</h1><a href="test_help2.html">next</a>'
    close(u)
    open(newunit=u, file=page2, status='replace')
    write(u, '(A)') '<h1>Page two</h1>'
    close(u)
    browser = QTextBrowser()
    call browser%sourceChanged%connect(on_text, s)
    call browser%setSource(page1)
    call check(index(browser%toPlainText(), 'Page one') > 0 .and. index(browser%source(), 'test_help1.html') > 0, &
               'setSource (file)')
    call browser%setSource(page2)
    call check(index(browser%toPlainText(), 'Page two') > 0 .and. browser%isBackwardAvailable(), 'second page')
    call browser%backward()
    call check(index(browser%toPlainText(), 'Page one') > 0 .and. index(s%text, 'test_help1.html') > 0, &
               'backward, sourceChanged')

    ! --- QToolBox
    toolbox = QToolBox()
    call toolbox%currentChanged%connect(on_page, s)
    call toolbox%addItem(QLabel('first'), 'First')
    call toolbox%addItem(QLabel('second'), 'Second')
    call toolbox%setCurrentIndex(1)
    call check(toolbox%count() == 2 .and. toolbox%currentIndex() == 1 .and. s%page == 1, 'QToolBox')
    call check(toolbox%itemText(0) == 'First', 'itemText')

    ! --- QSplashScreen
    window = QWidget()
    call window%resize(120, 60)
    pix = window%grab()
    splash = QSplashScreen(pix)
    call pix%delete()
    call splash%show()
    call splash%showMessage('Loading...')
    call check(splash%message() == 'Loading...', 'QSplashScreen message')
    call window%show()
    call splash%finish(window)

    ! --- window states
    call window%showMaximized()
    call check(window%isMaximized(), 'showMaximized')
    call window%showNormal()
    call check(.not. window%isMaximized(), 'showNormal')
    call window%raise()
    call window%activateWindow()

    ! --- QMdiArea
    area = QMdiArea()
    call area%resize(400, 300)
    call area%show()
    sub1 = area%addSubWindow(QLabel('document 1'))
    sub2 = area%addSubWindow(QLabel('document 2'))
    call sub1%show()
    call sub2%show()
    call check(area%subWindowCount() == 2, 'addSubWindow')
    call area%setActiveSubWindow(sub1)
    active = area%activeSubWindow()
    call check(c_associated(active%ptr, sub1%ptr), 'setActiveSubWindow')
    call area%tileSubWindows()
    call area%setViewMode(QMdiArea_TabbedView)
    call area%closeAllSubWindows()
    call spin()
    call check(area%subWindowCount() == 0 .and. sub1%isNull(), 'closeAllSubWindows')

    ! --- QWizard: a mandatory field, setComplete, field values
    wizard = QWizard()
    call wizard%currentIdChanged%connect(on_page, s)
    p1 = QWizardPage()
    call p1%setTitle('Name')
    layout = QVBoxLayout(p1)
    name_edit = QLineEdit()
    call layout%addWidget(name_edit)
    call p1%registerField('name*', name_edit)
    p2 = QWizardPage()
    call p2%setTitle('Count')
    layout = QVBoxLayout(p2)
    spin_box = QSpinBox()
    call layout%addWidget(spin_box)
    call p2%registerField('count', spin_box)
    call p2%setFinalPage(.true.)
    call wizard%addPage(p1)
    call wizard%addPage(p2)
    call wizard%show()
    call check(wizard%currentId() == 0 .and. .not. p1%isComplete(), 'mandatory field: incomplete')
    call name_edit%setText('run 1')
    call check(p1%isComplete(), 'mandatory field filled')
    call wizard%next()
    call check(wizard%currentId() == 1 .and. s%page == 1, 'next page')
    call spin_box%setValue(5)
    call check(wizard%stringField('name') == 'run 1' .and. wizard%intField('count') == 5, 'field values')
    call p2%setComplete(.false.)
    call check(.not. p2%isComplete(), 'setComplete(.false.)')
    call wizard%back()
    call check(wizard%currentId() == 0, 'back')
    call wizard%delete()

    ! --- QUndoStack
    stack = QUndoStack(owner)
    call stack%redoRequested%connect(on_redo, s)
    call stack%undoRequested%connect(on_undo, s)
    undo_action = stack%createUndoAction(owner)
    call set_value(stack, s, 1, 5)
    call check(s%value == 5 .and. stack%count() == 1, 'push performs the command')
    call set_value(stack, s, 2, 7)
    call check(s%value == 7 .and. stack%undoText() == 'Set 7', 'second command')
    call check(index(undo_action%text(), 'Set 7') > 0, 'undo action text')
    call stack%undo()
    call check(s%value == 5 .and. stack%canRedo() .and. stack%redoText() == 'Set 7', 'undo')
    call stack%redo()
    call check(s%value == 7 .and. stack%index() == 2, 'redo')
    call stack%setClean()
    call check(stack%isClean(), 'clean')
    call stack%setIndex(0)
    call check(s%value == 0 .and. .not. stack%isClean(), 'setIndex(0) undoes all')
    call set_value(stack, s, 3, 9)
    call check(stack%count() == 1 .and. s%value == 9, 'push discards undone commands')
    call stack%beginMacro('Two steps')
    call set_value(stack, s, 4, 1)
    call set_value(stack, s, 5, 2)
    call stack%endMacro()
    call check(stack%count() == 2 .and. s%value == 2 .and. stack%undoText() == 'Two steps', 'macro')
    call stack%undo()
    call check(s%value == 9, 'undo a macro')
    undo_view = QUndoView(stack)
    call undo_view%setEmptyLabel('<original>')
    call undo_view%delete()

    call line%delete()
    call dte%delete()
    call browser%delete()
    call toolbox%delete()
    call splash%delete()
    call window%delete()
    call area%delete()
    call owner%delete()

    write(*,'(A)') 'test_more_widgets: all checks passed'

end program test_more_widgets
