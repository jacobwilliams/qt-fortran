!> QtfWidget: painting and input events delivered to Fortran slots.
!> Events are synthesized with QCoreApplication_sendEvent.
!> Run headless with QT_QPA_PLATFORM=offscreen.
module test_events_slots

    use qt
    use iso_c_binding, only: c_double
    implicit none

    !> Records which events arrived and their properties.
    type :: event_log
        integer :: paints = 0
        integer :: presses = 0, releases = 0, moves = 0, doubles = 0
        integer :: wheels = 0, keys = 0, resizes = 0
        real(c_double) :: x = -1, y = -1
        integer :: button = -1, buttons = -1, modifiers = -1
        integer :: key = -1, delta = 0
        character(len=:), allocatable :: text
        integer :: width = -1, height = -1, oldWidth = -1, oldHeight = -1
        integer :: surfaces_created = 0, surfaces_destroyed = 0
    end type event_log

contains

    !> Paint the widget red with a blue square at the top left.
    subroutine on_paint(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%paints = data%paints + 1
        end select
        call painter%fillRect(0, 0, painter%deviceWidth(), painter%deviceHeight(), Qt_red)
        call painter%fillRect(0, 0, 10, 10, Qt_blue)
        call painter%end()    ! no-op for a painter received in a slot
    end subroutine on_paint

    !> Copy a mouse event's properties into the log.
    subroutine record_mouse(e, log)
        type(QMouseEvent), intent(in) :: e
        type(event_log), intent(inout) :: log
        log%x = e%x()
        log%y = e%y()
        log%button = e%button()
        log%buttons = e%buttons()
        log%modifiers = e%modifiers()
    end subroutine record_mouse

    !> Record a mouse press.
    subroutine on_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%presses = data%presses + 1
            call record_mouse(event, data)
        end select
    end subroutine on_press

    !> Record a mouse release.
    subroutine on_release(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%releases = data%releases + 1
            call record_mouse(event, data)
        end select
    end subroutine on_release

    !> Record a mouse move.
    subroutine on_move(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%moves = data%moves + 1
            call record_mouse(event, data)
        end select
    end subroutine on_move

    !> Count double clicks.
    subroutine on_double(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%doubles = data%doubles + 1
        end select
    end subroutine on_double

    !> Record a wheel event.
    subroutine on_wheel(event, data)
        type(QWheelEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%wheels = data%wheels + 1
            data%delta = event%angleDeltaY()
            data%x = event%x()
            data%modifiers = event%modifiers()
        end select
    end subroutine on_wheel

    !> Record a key press.
    subroutine on_key(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%keys = data%keys + 1
            data%key = event%key()
            data%text = event%text()
            data%modifiers = event%modifiers()
        end select
    end subroutine on_key

    !> Record a resize.
    subroutine on_resize(event, data)
        type(QResizeEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%resizes = data%resizes + 1
            data%width = event%width()
            data%height = event%height()
            data%oldWidth = event%oldWidth()
            data%oldHeight = event%oldHeight()
        end select
    end subroutine on_resize

    !> Record a window's native surface created.
    subroutine on_surface_created(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%surfaces_created = data%surfaces_created + 1
        end select
    end subroutine on_surface_created

    !> Record a window's native surface about to be destroyed.
    subroutine on_surface_destroyed(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_log)
            data%surfaces_destroyed = data%surfaces_destroyed + 1
        end select
    end subroutine on_surface_destroyed

end module test_events_slots

!> Tests QtfWidget painting and input events.
program test_events

    use qt
    use testing
    use test_events_slots
    use iso_c_binding, only: c_double
    implicit none

    type(QApplication) :: app
    type(QtfWidget) :: canvas, plain
    type(QPixmap) :: pix
    type(QImage) :: img
    type(QMouseEvent) :: me
    type(QKeyEvent) :: ke
    type(QWheelEvent) :: we
    type(QResizeEvent) :: re
    type(event_log), target :: log, surfaces
    type(QWindow) :: window
    type(QtfEventFilter) :: window_events
    logical :: handled

    app = QApplication()

    canvas = QtfWidget()
    call canvas%resize(60, 40)

    ! --- painting: grab renders through the Fortran paint slot
    call canvas%paintEvent%connect(on_paint, log)
    pix = canvas%grab()
    call check(pix%width() == 60 .and. pix%height() == 40, 'grab size')
    img = pix%toImage()
    call check(log%paints >= 1, 'paint slot called')
    call check(img%pixelColor(5, 5) == Qt_blue .and. img%pixelColor(30, 20) == Qt_red, 'painted pixels')
    call img%delete()
    call pix%delete()

    ! --- mouse
    call canvas%mousePressEvent%connect(on_press, log)
    call canvas%mouseReleaseEvent%connect(on_release, log)
    call canvas%mouseMoveEvent%connect(on_move, log)
    call canvas%mouseDoubleClickEvent%connect(on_double, log)

    me = QMouseEvent(QEvent_MouseButtonPress, 12.5_c_double, 7.0_c_double, Qt_LeftButton, &
                     modifiers=Qt_ShiftModifier)
    handled = QCoreApplication_sendEvent(canvas, me)
    call check(log%presses == 1, 'mousePressEvent')
    call check(log%x == 12.5_c_double .and. log%y == 7.0_c_double, 'mouse position')
    call check(log%button == Qt_LeftButton .and. log%modifiers == Qt_ShiftModifier, 'mouse button/modifiers')
    call check(me%type() == QEvent_MouseButtonPress .and. me%isAccepted(), 'event type, accepted')
    call me%delete()

    me = QMouseEvent(QEvent_MouseMove, 20.0_c_double, 9.0_c_double, Qt_NoButton, buttons=Qt_LeftButton)
    handled = QCoreApplication_sendEvent(canvas, me)
    call check(log%moves == 1 .and. log%buttons == Qt_LeftButton .and. log%x == 20, 'mouseMoveEvent (drag)')
    call me%delete()

    me = QMouseEvent(QEvent_MouseButtonRelease, 21.0_c_double, 9.0_c_double, Qt_LeftButton, buttons=Qt_NoButton)
    handled = QCoreApplication_sendEvent(canvas, me)
    call check(log%releases == 1 .and. log%button == Qt_LeftButton, 'mouseReleaseEvent')
    call me%delete()

    me = QMouseEvent(QEvent_MouseButtonDblClick, 1.0_c_double, 1.0_c_double, Qt_RightButton)
    handled = QCoreApplication_sendEvent(canvas, me)
    call check(log%doubles == 1, 'mouseDoubleClickEvent')
    call me%delete()

    ! --- wheel
    call canvas%wheelEvent%connect(on_wheel, log)
    we = QWheelEvent(30.0_c_double, 15.0_c_double, 0, -120, modifiers=Qt_ControlModifier)
    handled = QCoreApplication_sendEvent(canvas, we)
    call check(log%wheels == 1 .and. log%delta == -120, 'wheelEvent angleDelta')
    call check(log%x == 30 .and. log%modifiers == Qt_ControlModifier, 'wheel position/modifiers')
    call we%delete()

    ! --- keys (only key press is connected; release keeps Qt's default handling)
    call canvas%keyPressEvent%connect(on_key, log)
    ke = QKeyEvent(QEvent_KeyPress, Qt_Key_A, Qt_NoModifier, 'a')
    handled = QCoreApplication_sendEvent(canvas, ke)
    call check(log%keys == 1 .and. log%key == Qt_Key_A .and. log%text == 'a', 'keyPressEvent key/text')
    call ke%delete()
    ke = QKeyEvent(QEvent_KeyPress, Qt_Key_Left, Qt_ShiftModifier)
    handled = QCoreApplication_sendEvent(canvas, ke)
    call check(log%key == Qt_Key_Left .and. log%text == '' .and. log%modifiers == Qt_ShiftModifier, &
               'keyPressEvent special key')
    call ke%delete()
    ke = QKeyEvent(QEvent_KeyRelease, Qt_Key_A)
    handled = QCoreApplication_sendEvent(canvas, ke)
    call check(log%keys == 2 .and. .not. ke%isAccepted(), 'unconnected keyRelease uses default (ignored)')
    call ke%delete()

    ! --- resize: synthetic event, then a real resize of a visible widget
    call canvas%resizeEvent%connect(on_resize, log)
    re = QResizeEvent(80, 50, 60, 40)
    handled = QCoreApplication_sendEvent(canvas, re)
    call check(log%resizes == 1 .and. log%width == 80 .and. log%oldHeight == 40, 'resizeEvent (synthetic)')
    call re%delete()
    call canvas%show()
    call canvas%resize(120, 90)
    call check(log%width == 120 .and. log%height == 90, 'resizeEvent from resize()')

    ! --- a QtfWidget without paint slots paints like a plain QWidget
    plain = QtfWidget()
    call plain%resize(10, 10)
    pix = plain%grab()
    call check(.not. pix%isNull(), 'default paint without slots')
    call pix%delete()
    call plain%delete()

    call check(canvas%hasMouseTracking() .eqv. .false., 'mouse tracking off by default')
    call canvas%setMouseTracking(.true.)
    call check(canvas%hasMouseTracking(), 'setMouseTracking')
    call canvas%delete()
    call check(qt_slot_count() == 0, 'event slots released with the widget')

    ! --- a window's native surface: created, about to be destroyed, created again
    window = QWindow()
    window_events = QtfEventFilter(window)
    call window_events%surfaceCreated%connect(on_surface_created, surfaces)
    call window_events%surfaceAboutToBeDestroyed%connect(on_surface_destroyed, surfaces)
    call window%create()
    call check(surfaces%surfaces_created == 1 .and. surfaces%surfaces_destroyed == 0, 'surfaceCreated (create)')
    call window%destroy()
    call check(surfaces%surfaces_destroyed == 1, 'surfaceAboutToBeDestroyed (destroy)')
    call window%create()
    call check(surfaces%surfaces_created == 2, 'surfaceCreated again')
    call window%delete()
    call check(surfaces%surfaces_destroyed == 2, 'surfaceAboutToBeDestroyed (window deleted)')
    call check(qt_slot_count() == 0, 'window event slots released with the window')

    write(*,'(A)') 'test_events: all checks passed'

end program test_events
