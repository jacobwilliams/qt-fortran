!> QInputDialog, QColorDialog, QFontDialog and QProgressDialog, driven from
!> single-shot timer slots. Run headless with QT_QPA_PLATFORM=offscreen.
module test_input_dialogs_slots

    use qt
    implicit none

contains

    !> The active modal dialog (null if none yet).
    function active_dialog() result(d)
        type(QDialog) :: d
        type(QWidget) :: w
        w = QApplication_activeModalWidget()
        if (.not. w%isNull()) call d%attach(w%ptr)
    end function active_dialog

    !> Accept the active dialog (retry until it is shown).
    subroutine accept_dialog(data)
        class(*), intent(inout), optional :: data
        type(QDialog) :: d
        d = active_dialog()
        if (d%isNull()) then
            call QTimer_singleShot(10, accept_dialog)
            return
        end if
        call d%accept()
    end subroutine accept_dialog

    !> Reject the active dialog (retry until it is shown).
    subroutine reject_dialog(data)
        class(*), intent(inout), optional :: data
        type(QDialog) :: d
        d = active_dialog()
        if (d%isNull()) then
            call QTimer_singleShot(10, reject_dialog)
            return
        end if
        call d%reject()
    end subroutine reject_dialog

    !> Count a signal.
    subroutine count_calls(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (integer)
            data = data + 1
        end select
    end subroutine count_calls

end module test_input_dialogs_slots

!> Tests the input dialogs.
program test_input_dialogs

    use qt
    use testing
    use test_input_dialogs_slots
    use iso_c_binding, only: c_double
    implicit none

    type(QApplication) :: app
    type(QColor) :: c
    type(QFont) :: f
    type(QProgressDialog) :: progress
    character(len=:), allocatable :: text
    integer :: n
    real(c_double) :: x
    logical :: ok
    integer, target :: canceled

    app = QApplication()

    ! --- QInputDialog: accept returns the initial value with ok = .true.; reject sets ok = .false.
    call QTimer_singleShot(0, accept_dialog)
    text = QInputDialog_getText('Name', 'Your name:', 'Ada', ok)
    call check(ok .and. text == 'Ada', 'getText accepted')
    call QTimer_singleShot(0, reject_dialog)
    text = QInputDialog_getText('Name', 'Your name:', 'Ada', ok)
    call check(.not. ok, 'getText cancelled (ok = .false.)')
    call QTimer_singleShot(0, accept_dialog)
    n = QInputDialog_getInt('Count', 'How many?', 42, 0, 100, ok=ok)
    call check(ok .and. n == 42, 'getInt')
    call QTimer_singleShot(0, accept_dialog)
    x = QInputDialog_getDouble('Value', 'x =', 2.5_c_double, decimals=3, ok=ok)
    call check(ok .and. x == 2.5_c_double, 'getDouble')
    call QTimer_singleShot(0, accept_dialog)
    text = QInputDialog_getItem('Pick', 'Color:', ['red  ', 'green', 'blue '], current=1, editable=.false., ok=ok)
    call check(ok .and. text == 'green', 'getItem (string array argument)')
    call QTimer_singleShot(0, accept_dialog)
    text = QInputDialog_getText('Name', 'No ok flag:', 'x')
    call check(text == 'x', 'getText without the optional ok')

    ! --- QColorDialog: a value-type result; cancel gives an invalid color
    call QTimer_singleShot(0, accept_dialog)
    c = QColorDialog_getColor(QColor(10, 20, 30), 'Color')
    call check(c%isValid() .and. c == QColor(10, 20, 30), 'getColor accepted returns the color')
    call QTimer_singleShot(0, reject_dialog)
    c = QColorDialog_getColor(Qt_red)
    call check(.not. c%isValid(), 'getColor cancelled returns an invalid color')

    ! --- QFontDialog
    call QTimer_singleShot(0, accept_dialog)
    ! What the dialog returns for a font that is not installed is up to Qt and
    ! the platform (family substitution, size snapping, or a pixel-sized font
    ! with pointSize -1, e.g. on the offscreen platforms), so only `ok` is
    ! checked; the result is printed for the log.
    f = QFontDialog_getFont(QFont(pointSize=17.0_c_double, bold=.true.), 'Font', ok)
    write(*,'(A,A,A,F0.1,A,L1)') 'info: getFont returned family "', f%family, '", size ', &
        f%pointSize, ', bold ', f%bold
    call check(ok, 'getFont accepted (ok = .true.)')
    call QTimer_singleShot(0, reject_dialog)
    f = QFontDialog_getFont(ok=ok)
    call check(.not. ok, 'getFont cancelled')

    ! --- QProgressDialog
    progress = QProgressDialog('Working...', 'Stop', 0, 10)
    canceled = 0
    call progress%canceled%connect(count_calls, canceled)
    call progress%setValue(5)
    call check(progress%value() == 5 .and. .not. progress%wasCanceled(), 'QProgressDialog value')
    ! (cancel() sets wasCanceled; the `canceled` signal is only emitted by the Cancel button)
    call progress%cancel()
    call check(progress%wasCanceled(), 'QProgressDialog cancel / wasCanceled')
    call progress%delete()

    write(*,'(A)') 'test_input_dialogs: all checks passed'

end program test_input_dialogs
