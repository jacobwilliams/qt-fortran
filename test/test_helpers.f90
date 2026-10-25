!> Widget enter/leave, focus and show/hide events; QDateTime; dynamic
!> properties; findChild. Run headless with QT_QPA_PLATFORM=offscreen.
module test_helpers_slots

    use qt
    implicit none

    !> Counts of the observed events.
    type :: event_counts
        integer :: enter = 0, leave = 0, focus_in = 0, focus_out = 0, show = 0, hide = 0
        integer :: reason = -1
    end type event_counts

contains

    !> Count enter events.
    subroutine on_enter(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_counts)
            data%enter = data%enter + 1
        end select
    end subroutine on_enter

    !> Count leave events.
    subroutine on_leave(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_counts)
            data%leave = data%leave + 1
        end select
    end subroutine on_leave

    !> Count focus-in events and keep the reason.
    subroutine on_focus_in(reason, data)
        integer, intent(in) :: reason
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_counts)
            data%focus_in = data%focus_in + 1
            data%reason = reason
        end select
    end subroutine on_focus_in

    !> Count focus-out events.
    subroutine on_focus_out(reason, data)
        integer, intent(in) :: reason
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_counts)
            data%focus_out = data%focus_out + 1
        end select
    end subroutine on_focus_out

    !> Count show events.
    subroutine on_show(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_counts)
            data%show = data%show + 1
        end select
    end subroutine on_show

    !> Count hide events.
    subroutine on_hide(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (event_counts)
            data%hide = data%hide + 1
        end select
    end subroutine on_hide

end module test_helpers_slots

!> Tests the extra widget events, QDateTime, properties and findChild.
program test_helpers

    use qt
    use testing
    use test_helpers_slots
    use iso_c_binding, only: c_double, c_long_long
    implicit none

    type(QApplication) :: app
    type(QWidget) :: w, found
    type(QPushButton) :: ok, button
    type(QLabel) :: label
    type(QVBoxLayout) :: box
    type(QEvent) :: ev
    type(event_counts), target :: counts
    type(QDateTime) :: t, u, now, bad
    type(QDate) :: d
    logical :: handled

    app = QApplication()

    ! --- enter/leave, focus, show/hide events (observed; the widget still gets them)
    w = QWidget()
    call w%enterEvent%connect(on_enter, counts)
    call w%leaveEvent%connect(on_leave, counts)
    call w%focusInEvent%connect(on_focus_in, counts)
    call w%focusOutEvent%connect(on_focus_out, counts)
    call w%showEvent%connect(on_show, counts)
    call w%hideEvent%connect(on_hide, counts)
    call w%show()
    call check(counts%show == 1, 'showEvent')
    call w%hide()
    call check(counts%hide == 1, 'hideEvent')
    ev = QEvent(QEvent_Enter)
    handled = QCoreApplication_sendEvent(w, ev)
    call ev%delete()
    ev = QEvent(QEvent_Leave)
    handled = QCoreApplication_sendEvent(w, ev)
    call ev%delete()
    call check(counts%enter == 1 .and. counts%leave == 1, 'enterEvent, leaveEvent')
    ev = QEvent(QEvent_FocusIn)
    call check(ev%type() == QEvent_FocusIn, 'QEvent(type)')
    handled = QCoreApplication_sendEvent(w, ev)
    call ev%delete()
    ev = QEvent(QEvent_FocusOut)
    handled = QCoreApplication_sendEvent(w, ev)
    call ev%delete()
    call check(counts%focus_in == 1 .and. counts%focus_out == 1, 'focusInEvent, focusOutEvent')
    call check(counts%reason == Qt_OtherFocusReason, 'focus reason')

    ! --- dynamic properties
    call w%setProperty('state', 'error')
    call w%setProperty('count', 7)
    call w%setProperty('scale', 1.5_c_double)
    call w%setProperty('dirty', .true.)
    call check(w%stringProperty('state') == 'error', 'string property')
    call check(w%intProperty('count') == 7, 'int property')
    call check(w%doubleProperty('scale') == 1.5_c_double, 'double property')
    call check(w%boolProperty('dirty'), 'bool property')
    call check(w%stringProperty('missing', 'none') == 'none' .and. w%intProperty('missing', -1) == -1 &
               .and. .not. w%hasProperty('missing') .and. w%hasProperty('state'), 'missing property defaults')
    call check(w%hasProperty('objectName'), 'Qt property')
    call w%setStyleSheet('QWidget[state="error"] { background: red; }')
    call w%repolish()
    call check(.true., 'repolish')

    ! --- findChild by object name (recursive)
    box = QVBoxLayout(w)
    label = QLabel('label')
    ok = QPushButton('OK')
    call ok%setObjectName('okButton')
    call box%addWidget(label)
    call box%addWidget(ok)
    call w%findChild('okButton', button)
    call check(.not. button%isNull() .and. button%text() == 'OK', 'findChild (typed)')
    call w%findChild('okButton', found)
    call check(found%inherits('QPushButton'), 'findChild as a base type')
    call w%findChild('nothing', found)
    call check(found%isNull(), 'findChild: not found')
    call w%delete()

    ! --- QDateTime
    t = QDateTime(2026, 10, 25, 14, 30)
    bad = QDateTime(2026, 2, 30)
    u = QDateTime()
    call check(t%isValid() .and. .not. bad%isValid() .and. .not. u%isValid(), 'isValid')
    call check(t%toString('yyyy-MM-dd HH:mm') == '2026-10-25 14:30', 'toString(format)')
    call check(t%toString() == '2026-10-25T14:30:00.000', 'toString() ISO')
    u = QDateTime_fromString('25.10.2026 14:30', 'dd.MM.yyyy HH:mm')
    call check(u == t, 'fromString(format), ==')
    u = QDateTime_fromString('2026-10-25T14:30:00')
    call check(u == t, 'fromString ISO')
    bad = QDateTime_fromString('not a date')
    call check(.not. bad%isValid() .and. bad%year == 0, 'fromString invalid')
    u = t%addSecs(90)
    call check(u%minute == 31 .and. u%second == 30 .and. t%secsTo(u) == 90 .and. t < u .and. u > t, 'addSecs, secsTo, <')
    u = t%addDays(10)
    call check(u%month == 11 .and. u%day == 4 .and. u%hour == 14 .and. t%daysTo(u) == 10, 'addDays across a month')
    u = QDateTime(2026, 1, 31)
    u = u%addMonths(1)
    call check(u%month == 2 .and. u%day == 28, 'addMonths clamps the day')
    u = t%addYears(-1)
    call check(u%year == 2025 .and. u /= t, 'addYears, /=')
    u = t%addMSecs(1500_c_long_long)
    call check(u%second == 1 .and. u%msec == 500 .and. t%msecsTo(u) == 1500, 'addMSecs, msecsTo')
    u = QDateTime_fromMSecsSinceEpoch(t%toMSecsSinceEpoch())
    call check(u == t .and. u%hour == 14, 'MSecsSinceEpoch round trip')
    call check(t%dayOfWeek() == 7, 'dayOfWeek (Sunday)')
    d = t%date()
    call check(d%year == 2026 .and. d%month == 10 .and. d%day == 25, 'date()')
    now = QDateTime_currentDateTime()
    call check(now%isValid() .and. now%year >= 2025 .and. now > t%addYears(-10), 'currentDateTime')

    write(*,'(A)') 'test_helpers: all checks passed'

end program test_helpers
