!> File dialogs, driven from single-shot timer slots (Qt's own dialog, not the
!> platform's native one). Run headless with QT_QPA_PLATFORM=offscreen.
module test_filedialog_slots

    use qt
    implicit none

    character(len=*), parameter :: dir = 'build'
    character(len=*), parameter :: existing = 'qtf_test_open.txt'
    character(len=*), parameter :: new_file = 'qtf_test_save.dat'

contains

    !> The active modal QFileDialog (null if none yet).
    function active_file_dialog() result(d)
        type(QFileDialog) :: d
        type(QWidget) :: w
        w = QApplication_activeModalWidget()
        if (w%isNull()) return
        if (.not. w%inherits('QFileDialog')) error stop 'active modal widget is not a QFileDialog'
        call d%attach(w%ptr)
    end function active_file_dialog

    !> Select the existing test file in the active file dialog and accept it.
    subroutine choose_existing(data)
        class(*), intent(inout), optional :: data
        type(QFileDialog) :: d
        d = active_file_dialog()
        if (d%isNull()) then
            call QTimer_singleShot(10, choose_existing)
            return
        end if
        call d%selectFile(existing)
        call d%accept()
    end subroutine choose_existing

    !> Enter a new file name in the active file dialog and accept it.
    subroutine choose_new(data)
        class(*), intent(inout), optional :: data
        type(QFileDialog) :: d
        d = active_file_dialog()
        if (d%isNull()) then
            call QTimer_singleShot(10, choose_new)
            return
        end if
        call d%selectFile(new_file)
        call d%accept()
    end subroutine choose_new

    !> Cancel the active file dialog.
    subroutine cancel(data)
        class(*), intent(inout), optional :: data
        type(QFileDialog) :: d
        d = active_file_dialog()
        if (d%isNull()) then
            call QTimer_singleShot(10, cancel)
            return
        end if
        call d%reject()
    end subroutine cancel

end module test_filedialog_slots

!> Tests the static and object QFileDialog APIs.
program test_filedialog

    use qt
    use testing
    use test_filedialog_slots
    implicit none

    type(QApplication) :: app
    type(QFileDialog) :: d
    type(qt_string), allocatable :: files(:)
    character(len=:), allocatable :: path
    integer :: u, r

    app = QApplication()

    open(newunit=u, file=dir//'/'//existing, status='replace', action='write')
    write(u, '(A)') 'hello'
    close(u)

    ! --- static open: choose an existing file
    call QTimer_singleShot(0, choose_existing)
    path = QFileDialog_getOpenFileName('Open', dir, 'Text (*.txt)', options=QFileDialog_DontUseNativeDialog)
    call check(ends_with(path, '/'//existing), 'getOpenFileName returns the chosen file')

    ! --- static save: choose a new name
    call QTimer_singleShot(0, choose_new)
    path = QFileDialog_getSaveFileName('Save', dir, options=QFileDialog_DontUseNativeDialog)
    call check(ends_with(path, '/'//new_file), 'getSaveFileName returns the chosen name')

    ! --- cancelled dialog returns an empty string
    call QTimer_singleShot(0, cancel)
    path = QFileDialog_getOpenFileName('Open', dir, options=QFileDialog_DontUseNativeDialog)
    call check(path == '', 'cancel returns empty string')

    ! --- instance API with a string list result
    d = QFileDialog('Pick', dir, 'Text (*.txt)')
    call d%setOption(QFileDialog_DontUseNativeDialog)
    call d%setFileMode(QFileDialog_ExistingFiles)
    call QTimer_singleShot(0, choose_existing)
    r = d%exec()
    call check(r == QDialog_Accepted, 'QFileDialog exec accepted')
    files = d%selectedFiles()
    call check(size(files) == 1, 'selectedFiles size')
    call check(ends_with(files(1)%s, '/'//existing), 'selectedFiles name')
    call d%delete()

    open(newunit=u, file=dir//'/'//existing, status='old')
    close(u, status='delete')

    write(*,'(A)') 'test_filedialog: all checks passed'

contains

    !> True if `s` ends with `suffix`.
    logical function ends_with(s, suffix)
        character(len=*), intent(in) :: s, suffix
        ends_with = .false.
        if (len(s) >= len(suffix)) ends_with = s(len(s)-len(suffix)+1:) == suffix
    end function ends_with

end program test_filedialog
