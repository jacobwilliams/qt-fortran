!> Widget tests: QWidget/QLabel properties, ownership, UTF-8 strings.
!> Run headless with QT_QPA_PLATFORM=offscreen.
module test_widgets_slots

    implicit none

contains

    !> Increment the integer passed as `data`.
    subroutine count_calls(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (integer)
            data = data + 1
        end select
    end subroutine count_calls

end module test_widgets_slots

!> Tests QWidget and QLabel properties, ownership and UTF-8 strings.
program test_widgets

    use qt
    use testing
    use iso_c_binding, only: c_associated
    use test_widgets_slots
    implicit none

    type(QApplication) :: app
    type(QWidget) :: win
    type(QLabel) :: label
    type(QObject) :: p
    integer, target :: ndestroyed
    ! 'héllo → Qt' as explicit UTF-8 bytes, so the source stays ASCII
    character(len=*), parameter :: msg = 'h'//achar(195)//achar(169)//'llo '// &
                                         achar(226)//achar(134)//achar(146)//' Qt'

    app = QApplication()

    win = QWidget()
    call check(win%className() == 'QWidget', 'QWidget class')
    call win%setWindowTitle(msg)
    call check(win%windowTitle() == msg, 'windowTitle UTF-8 round-trip')
    call win%resize(320, 200)
    call check(win%width() == 320 .and. win%height() == 200, 'resize/width/height')

    label = QLabel('initial', win)
    call check(label%className() == 'QLabel', 'QLabel class')
    call check(label%inherits('QWidget'), 'QLabel inherits QWidget')
    call check(label%text() == 'initial', 'QLabel constructor text')
    call label%setText(msg)
    call check(label%text() == msg, 'QLabel text UTF-8 round-trip')
    call check(len(label%text()) == len(msg), 'byte length preserved')
    call label%setAlignment(Qt_AlignCenter)
    p = label%parent()
    call check(c_associated(p%ptr, win%ptr), 'label parented to window')

    call win%show()
    call check(win%isVisible() .and. label%isVisible(), 'show')
    call win%hide()
    call check(.not. win%isVisible(), 'hide')

    ndestroyed = 0
    call label%destroyed%connect(count_calls, ndestroyed)
    call win%delete()
    call check(ndestroyed == 1, 'deleting window deletes child label')

    write(*,'(A)') 'test_widgets: all checks passed'

end program test_widgets
