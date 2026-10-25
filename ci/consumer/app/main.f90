!> A program in another fpm project that uses qt-fortran: shows a window, clicks
!> its button from a timer and quits. Prints "consumer OK" on success.
module consumer_slots

    use qt
    implicit none

contains

    !> Button slot: change the label.
    subroutine on_click(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (QLabel)
            call data%setText('clicked')
        end select
    end subroutine on_click

    !> Timer slot: quit the event loop.
    subroutine on_timeout(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_timeout

end module consumer_slots

!> Uses qt-fortran from a separate fpm project.
program consumer

    use qt
    use consumer_slots
    implicit none

    type(QApplication) :: app
    type(QWidget) :: window
    type(QVBoxLayout) :: layout
    type(QLabel), target :: label
    type(QPushButton) :: button
    integer :: ierr

    app = QApplication()
    window = QWidget()
    layout = QVBoxLayout(window)
    label = QLabel('not clicked')
    button = QPushButton('Click')
    call layout%addWidget(label)
    call layout%addWidget(button)
    call button%clicked%connect(on_click, label)
    call window%show()

    call button%click()
    call QTimer_singleShot(50, on_timeout)
    ierr = app%exec()

    if (label%text() /= 'clicked') error stop 'consumer: slot did not run'
    write(*,'(A)') 'consumer OK'

end program consumer
