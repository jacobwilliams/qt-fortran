!> Modal dialog tests: QDialog exec/accept, QMessageBox instance and static
!> functions. The modal dialogs are driven from single-shot timer slots.
!> Run headless with QT_QPA_PLATFORM=offscreen.
module test_dialogs_slots

    use qt
    implicit none

    !> Records dialog signals.
    type :: dialog_log
        integer :: accepted = 0
        integer :: finished = -1
    end type dialog_log

contains

    !> Accept the active modal dialog (retry until it is shown).
    subroutine accept_modal(data)
        class(*), intent(inout), optional :: data
        type(QWidget) :: w
        type(QDialog) :: d
        w = QApplication_activeModalWidget()
        if (w%isNull()) then
            call QTimer_singleShot(10, accept_modal)
            return
        end if
        call d%attach(w%ptr)   ! cast: the modal widget is a QDialog
        call d%accept()
    end subroutine accept_modal

    !> Click "No" in the active message box (retry until it is shown).
    subroutine click_no(data)
        class(*), intent(inout), optional :: data
        type(QWidget) :: w
        type(QMessageBox) :: box
        type(QAbstractButton) :: b
        w = QApplication_activeModalWidget()
        if (w%isNull()) then
            call QTimer_singleShot(10, click_no)
            return
        end if
        if (.not. w%inherits('QMessageBox')) error stop 'active modal widget is not a QMessageBox'
        call box%attach(w%ptr)
        b = box%button(QMessageBox_No)
        call b%click()
    end subroutine click_no

    !> Count accepted emissions.
    subroutine on_accepted(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (dialog_log)
            data%accepted = data%accepted + 1
        end select
    end subroutine on_accepted

    !> Record the result code of finished.
    subroutine on_finished(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (dialog_log)
            data%finished = value
        end select
    end subroutine on_finished

end module test_dialogs_slots

!> Tests modal dialogs and message boxes.
program test_dialogs

    use qt
    use testing
    use test_dialogs_slots
    implicit none

    type(QApplication) :: app
    type(QDialog) :: dlg
    type(QMessageBox) :: box
    type(QAbstractButton) :: b
    type(dialog_log), target :: log
    integer :: r

    app = QApplication()

    ! --- QDialog: exec blocks until accepted from a timer slot
    dlg = QDialog()
    call dlg%accepted%connect(on_accepted, log)
    call dlg%finished%connect(on_finished, log)
    call QTimer_singleShot(0, accept_modal)
    r = dlg%exec()
    call check(r == QDialog_Accepted, 'QDialog exec returns Accepted')
    call check(dlg%result() == QDialog_Accepted, 'QDialog result')
    call check(log%accepted == 1 .and. log%finished == QDialog_Accepted, 'accepted/finished signals')
    call dlg%delete()

    ! --- QMessageBox instance
    box = QMessageBox()
    call box%setText('Save changes?')
    call box%setInformativeText('Unsaved work will be lost.')
    call box%setIcon(QMessageBox_Icon_Question)
    call box%setStandardButtons(ior(QMessageBox_Save, QMessageBox_Cancel))
    call box%setDefaultButton(QMessageBox_Save)
    call check(box%text() == 'Save changes?', 'QMessageBox text')
    call check(box%informativeText() == 'Unsaved work will be lost.', 'QMessageBox informativeText')
    b = box%button(QMessageBox_Save)
    call check(.not. b%isNull(), 'standard button present')
    b = box%button(QMessageBox_Yes)
    call check(b%isNull(), 'absent standard button is null')
    call check(box%inherits('QDialog'), 'QMessageBox inherits QDialog')
    call box%delete()

    ! --- static QMessageBox_question: click "No" (not the default) from a slot
    call QTimer_singleShot(0, click_no)
    r = QMessageBox_question('Question', 'Continue?', defaultButton=QMessageBox_Yes)
    call check(r == QMessageBox_No, 'QMessageBox_question returns the clicked button')

    write(*,'(A)') 'test_dialogs: all checks passed'

end program test_dialogs
