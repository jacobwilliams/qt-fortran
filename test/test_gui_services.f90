!> Clipboard, mime data, drag and drop (synthetic events), cursors and
!> screens. Run headless with QT_QPA_PLATFORM=offscreen (the clipboard is
!> then private to the process).
module test_gui_services_slots

    use qt
    use iso_c_binding, only: c_double
    implicit none

    !> What the drag-and-drop slots saw.
    type :: drops_t
        integer :: enters = 0, moves = 0, leaves = 0, drops = 0, clipboard_changes = 0
        logical :: accept = .true.
        real(c_double) :: x = -1, y = -1
        integer :: action = -1
        character(len=:), allocatable :: text
        type(qt_string), allocatable :: urls(:)
    end type drops_t

contains

    !> Accept a drag that carries text or files (if `accept` is set).
    subroutine on_drag_enter(event, data)
        type(QDropEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (drops_t)
            data%enters = data%enters + 1
            data%x = event%x()
            data%y = event%y()
            if (data%accept .and. (event%hasText() .or. event%hasUrls() .or. &
                                   event%hasFormat('application/x-qtf-test'))) call event%acceptProposedAction()
        end select
    end subroutine on_drag_enter

    !> Count moves (accepted: the drop may happen anywhere).
    subroutine on_drag_move(event, data)
        type(QDropEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (drops_t)
            data%moves = data%moves + 1
            call event%acceptProposedAction()
        end select
    end subroutine on_drag_move

    !> Count leaves.
    subroutine on_drag_leave(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (drops_t)
            data%leaves = data%leaves + 1
        end select
    end subroutine on_drag_leave

    !> Take the dropped text or files.
    subroutine on_drop(event, data)
        type(QDropEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        type(QMimeData) :: mime
        select type (data)
        type is (drops_t)
            data%drops = data%drops + 1
            data%action = event%proposedAction()
            if (event%hasText()) data%text = event%text()
            if (event%hasUrls()) data%urls = event%urls()
            mime = event%mimeData()
            if (mime%hasFormat('application/x-qtf-test')) data%text = event%data('application/x-qtf-test')
            call event%setDropAction(Qt_CopyAction)
            call event%accept()
        end select
    end subroutine on_drop

    !> Count clipboard changes.
    subroutine on_clipboard_changed(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (drops_t)
            data%clipboard_changes = data%clipboard_changes + 1
        end select
    end subroutine on_clipboard_changed

end module test_gui_services_slots

!> Tests the clipboard, drag and drop, cursors and screens.
program test_gui_services

    use qt
    use testing
    use test_gui_services_slots
    use iso_c_binding, only: c_double
    implicit none

    type(QApplication) :: app
    type(QClipboard) :: cb
    type(QMimeData) :: mime, mime2
    type(QWidget) :: w
    type(QDropEvent) :: ev
    type(QEvent) :: leave
    type(QDrag) :: drag
    type(QImage) :: img, got
    type(QPixmap) :: pix
    type(QScreen) :: screen, s0, none
    type(QWindow) :: win
    type(qt_string), allocatable :: list(:)
    type(drops_t), target :: d
    logical :: handled
    integer :: i, x0

    app = QApplication()

    ! --- QMimeData
    mime = QMimeData()
    call check(.not. mime%hasText() .and. size(mime%formats()) == 0, 'empty mime data')
    call mime%setText('hello')
    call mime%setHtml('<b>hello</b>')
    call mime%setUrls([character(len=24) :: '/tmp/qtf data.txt', 'https://fortran-lang.org'])
    call mime%setData('application/x-qtf-test', '42')
    call check(mime%hasText() .and. mime%text() == 'hello', 'text')
    call check(mime%hasHtml() .and. mime%html() == '<b>hello</b>', 'html')
    list = mime%urls()
    call check(mime%hasUrls() .and. size(list) == 2, 'urls')
    call check(list(1)%s == '/tmp/qtf data.txt' .and. list(2)%s == 'https://fortran-lang.org', &
               'urls: local files as paths')
    call check(mime%hasFormat('application/x-qtf-test') .and. mime%data('application/x-qtf-test') == '42', &
               'custom format')
    list = mime%formats()
    call check(any([(list(i)%s == 'text/uri-list', i = 1, size(list))]), 'formats')
    img = QImage(8, 4)
    call img%fill(Qt_red)
    call mime%setImage(img)
    got = mime%image()
    call check(mime%hasImage() .and. got%width() == 8 .and. got%pixelColor(1, 1) == Qt_red, 'image')
    call got%delete()
    call mime%clear()
    call check(.not. mime%hasText() .and. .not. mime%hasUrls(), 'clear')

    ! --- the clipboard
    cb = QGuiApplication_clipboard()
    call check(.not. cb%isNull(), 'QGuiApplication_clipboard')
    call cb%dataChanged%connect(on_clipboard_changed, d)
    call cb%setText('copied from Fortran')
    call check(cb%hasText() .and. cb%text() == 'copied from Fortran', 'clipboard text')
    call check(d%clipboard_changes >= 1, 'dataChanged')
    call cb%setImage(img)
    got = cb%image()
    call check(cb%hasImage() .and. got%height() == 4, 'clipboard image')
    call got%delete()
    mime2 = QMimeData()
    call mime2%setData('application/x-qtf-test', 'xyz')
    call cb%setMimeData(mime2)              ! the clipboard takes it
    mime2 = cb%mimeData()
    call check(mime2%hasFormat('application/x-qtf-test') .and. mime2%data('application/x-qtf-test') == 'xyz', &
               'clipboard mime data')
    call cb%clear()
    call check(cb%text() == '', 'clipboard clear')

    ! --- drag and drop on a widget, through synthetic events
    w = QWidget()
    call w%setAcceptDrops(.true.)
    call check(w%acceptDrops(), 'setAcceptDrops')
    call w%dragEnterEvent%connect(on_drag_enter, d)
    call w%dragMoveEvent%connect(on_drag_move, d)
    call w%dragLeaveEvent%connect(on_drag_leave, d)
    call w%dropEvent%connect(on_drop, d)

    call mime%setText('dropped text')
    ev = QDropEvent(QEvent_DragEnter, 5.0_c_double, 6.0_c_double, mime)
    handled = QCoreApplication_sendEvent(w, ev)
    call check(d%enters == 1 .and. d%x == 5 .and. d%y == 6, 'dragEnterEvent')
    call check(ev%isAccepted(), 'drag accepted in the slot')
    call ev%delete()
    ev = QDropEvent(QEvent_DragMove, 7.0_c_double, 8.0_c_double, mime)
    handled = QCoreApplication_sendEvent(w, ev)
    call check(d%moves == 1 .and. ev%isAccepted(), 'dragMoveEvent')
    call ev%delete()
    ev = QDropEvent(QEvent_Drop, 7.0_c_double, 8.0_c_double, mime, ior(Qt_CopyAction, Qt_MoveAction))
    call check(ev%possibleActions() == ior(Qt_CopyAction, Qt_MoveAction), 'possibleActions')
    handled = QCoreApplication_sendEvent(w, ev)
    call check(d%drops == 1 .and. d%text == 'dropped text' .and. d%action == Qt_CopyAction, 'dropEvent: text')
    call check(ev%isAccepted() .and. ev%dropAction() == Qt_CopyAction, 'drop accepted, setDropAction')
    call check(ev%buttons() == Qt_LeftButton .and. ev%modifiers() == Qt_NoModifier, 'buttons, modifiers')
    call ev%delete()

    ! files from the desktop (a drop needs an accepted drag-enter first, as in a real drag)
    call mime%clear()
    call mime%setUrls([character(len=12) :: '/tmp/a.dat', '/tmp/b.dat'])
    call check(drag_and_drop(), 'drag and drop of files accepted')
    call check(d%drops == 2 .and. size(d%urls) == 2, 'dropEvent: files')
    call check(d%urls(2)%s == '/tmp/b.dat', 'dropped file paths')

    ! a custom format, read through event%mimeData()
    call mime%clear()
    call mime%setData('application/x-qtf-test', 'custom')
    call check(drag_and_drop() .and. d%text == 'custom', 'dropEvent: custom format')

    ! a drag the slot does not accept: no drop follows
    d%accept = .false.
    call mime%setText('refused')
    call check(.not. drag_and_drop() .and. d%enters == 4 .and. d%drops == 3, 'drag not accepted, no drop')
    leave = QEvent(QEvent_DragLeave)
    handled = QCoreApplication_sendEvent(w, leave)
    call check(d%leaves == 1, 'dragLeaveEvent')
    call leave%delete()

    ! starting a drag (not executed here: exec waits for the mouse)
    drag = QDrag(w)
    mime2 = QMimeData()
    call mime2%setText('from Fortran')
    call drag%setMimeData(mime2)
    pix = QPixmap_fromImage(img)
    call drag%setPixmap(pix)
    call drag%setHotSpot(2, 2)
    call check(.not. drag%isNull(), 'QDrag')
    call drag%deleteLater()

    ! --- cursors
    call w%setCursor(Qt_CrossCursor)
    call check(w%cursorShape() == Qt_CrossCursor, 'setCursor')
    call w%unsetCursor()
    call check(w%cursorShape() == Qt_ArrowCursor, 'unsetCursor')
    call w%setCursorPixmap(pix)
    call check(w%cursorShape() /= Qt_ArrowCursor, 'setCursorPixmap')
    call check(QGuiApplication_overrideCursorShape() == -1, 'no override cursor')
    call QGuiApplication_setOverrideCursor(Qt_WaitCursor)
    call check(QGuiApplication_overrideCursorShape() == Qt_WaitCursor, 'setOverrideCursor')
    call QGuiApplication_changeOverrideCursor(Qt_BusyCursor)
    call check(QGuiApplication_overrideCursorShape() == Qt_BusyCursor, 'changeOverrideCursor')
    call QGuiApplication_restoreOverrideCursor()
    call check(QGuiApplication_overrideCursorShape() == -1, 'restoreOverrideCursor')
    x0 = QCursor_x() + QCursor_y()         ! (the position depends on the platform)
    call QCursor_setPos(10, 10)
    call pix%delete()

    ! --- screens
    call check(QGuiApplication_screenCount() >= 1, 'screenCount')
    screen = QGuiApplication_primaryScreen()
    call check(.not. screen%isNull(), 'primaryScreen')
    call check(screen%width() > 0 .and. screen%height() > 0, 'screen size')
    call check(screen%availableWidth() > 0 .and. screen%availableWidth() <= screen%width() .and. &
               screen%availableHeight() <= screen%height(), 'available area')
    call check(screen%availableX() >= screen%x() .and. screen%availableY() >= screen%y(), 'available origin')
    call check(screen%devicePixelRatio() >= 1 .and. screen%logicalDotsPerInch() > 0 .and. &
               screen%physicalDotsPerInch() > 0, 'resolution')
    call check(screen%depth() > 0 .and. screen%refreshRate() >= 0 .and. screen%physicalWidth() >= 0 .and. &
               screen%physicalHeight() >= 0, 'depth, refresh rate, physical size')
    call check(len(screen%name()) >= 0 .and. len(screen%manufacturer()) >= 0 .and. len(screen%model()) >= 0, &
               'names')
    s0 = QGuiApplication_screen(0)
    call check(.not. s0%isNull(), 'screen(0)')
    none = QGuiApplication_screen(999)
    call check(none%isNull(), 'screen(out of range) is null')
    s0 = QGuiApplication_screenAt(screen%x() + 1, screen%y() + 1)
    call check(.not. s0%isNull(), 'screenAt')
    s0 = w%screen()
    call check(.not. s0%isNull(), 'QWidget%screen')
    win = QWindow()
    s0 = win%screen()
    call check(.not. s0%isNull(), 'QWindow%screen')
    pix = screen%grab(0, 0, 10, 10)
    call pix%delete()

    call img%delete()
    call w%delete()
    call mime%delete()
    write(*,'(A)') 'test_gui_services: all checks passed'

contains

    !> Drag `mime` onto `w` and drop it; true if the drop was accepted.
    logical function drag_and_drop()
        type(QDropEvent) :: e
        logical :: sent
        e = QDropEvent(QEvent_DragEnter, 1.0_c_double, 1.0_c_double, mime)
        sent = QCoreApplication_sendEvent(w, e)
        call e%delete()
        e = QDropEvent(QEvent_Drop, 1.0_c_double, 1.0_c_double, mime)
        sent = QCoreApplication_sendEvent(w, e)
        drag_and_drop = e%isAccepted()
        call e%delete()
    end function drag_and_drop

end program test_gui_services
