!> Qt Core: signals and slots, QObject, QTimer, and Qt namespace constants.
!>
!> Signals are components of the object that emits them, as in PySide:
!>
!>     call timer%timeout%connect(on_tick, state)
!>
!> A slot is any procedure matching the signal's slot interface (e.g. [[qt_slot]]).
!> The optional `data` passed to `connect` is handed back to the slot on every
!> call. It is stored by reference, so it must have the TARGET (or POINTER)
!> attribute and outlive the connection.
!>
!> Connections last until the sender is destroyed, or until they are broken
!> with `call sig%disconnect()` (all Fortran slots of that signal) or
!> `QObject_disconnect(connection)` (one connection, from `connect`'s
!> optional `connection` argument).
!>
!> Signals can also be defined in Fortran: `sig = QSignalInt(parent)` creates
!> one, and `call sig%emit(42)` calls its slots.
module qt_core

    use iso_c_binding
    use qt_c_core
    use qt_c_util
    implicit none
    private

    ! Qt::AlignmentFlag
    integer(c_int), parameter, public :: Qt_AlignLeft    = int(z'0001', c_int)
    integer(c_int), parameter, public :: Qt_AlignRight   = int(z'0002', c_int)
    integer(c_int), parameter, public :: Qt_AlignHCenter = int(z'0004', c_int)
    integer(c_int), parameter, public :: Qt_AlignJustify = int(z'0008', c_int)
    integer(c_int), parameter, public :: Qt_AlignTop     = int(z'0020', c_int)
    integer(c_int), parameter, public :: Qt_AlignBottom  = int(z'0040', c_int)
    integer(c_int), parameter, public :: Qt_AlignVCenter = int(z'0080', c_int)
    integer(c_int), parameter, public :: Qt_AlignCenter  = ior(Qt_AlignHCenter, Qt_AlignVCenter)

    ! QEvent::Type (subset)
    integer(c_int), parameter, public :: QEvent_MouseButtonPress    = 2
    integer(c_int), parameter, public :: QEvent_MouseButtonRelease  = 3
    integer(c_int), parameter, public :: QEvent_MouseButtonDblClick = 4
    integer(c_int), parameter, public :: QEvent_MouseMove           = 5
    integer(c_int), parameter, public :: QEvent_KeyPress            = 6
    integer(c_int), parameter, public :: QEvent_KeyRelease          = 7
    integer(c_int), parameter, public :: QEvent_Paint               = 12
    integer(c_int), parameter, public :: QEvent_Resize              = 14
    integer(c_int), parameter, public :: QEvent_Close               = 19
    integer(c_int), parameter, public :: QEvent_Wheel               = 31
    integer(c_int), parameter, public :: QEvent_FocusIn             = 8
    integer(c_int), parameter, public :: QEvent_FocusOut            = 9
    integer(c_int), parameter, public :: QEvent_Enter               = 10
    integer(c_int), parameter, public :: QEvent_Leave               = 11
    integer(c_int), parameter, public :: QEvent_Show                = 17
    integer(c_int), parameter, public :: QEvent_Hide                = 18
    integer(c_int), parameter, public :: QEvent_ContextMenu         = 82

    ! Qt::FocusPolicy
    integer(c_int), parameter, public :: Qt_NoFocus     = 0
    integer(c_int), parameter, public :: Qt_TabFocus    = 1
    integer(c_int), parameter, public :: Qt_ClickFocus  = 2
    integer(c_int), parameter, public :: Qt_StrongFocus = 11
    integer(c_int), parameter, public :: Qt_WheelFocus  = 15

    ! Qt::Orientation
    integer(c_int), parameter, public :: Qt_Horizontal = 1
    integer(c_int), parameter, public :: Qt_Vertical   = 2

    abstract interface
        !> Slot for signals without arguments.
        subroutine qt_slot(data)
            implicit none
            class(*), intent(inout), optional :: data
        end subroutine qt_slot
        !> Slot for signals with a single string argument.
        subroutine qt_slot_string(value, data)
            implicit none
            character(len=*), intent(in) :: value
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_string
        !> Slot for signals with a single logical argument.
        subroutine qt_slot_bool(value, data)
            implicit none
            logical, intent(in) :: value
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_bool
        !> Slot for signals with a single integer argument.
        subroutine qt_slot_int(value, data)
            implicit none
            integer, intent(in) :: value
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_int
        !> Slot for signals with a single real argument.
        subroutine qt_slot_double(value, data)
            import :: c_double
            implicit none
            real(c_double), intent(in) :: value
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_double
    end interface
    public :: qt_slot, qt_slot_string, qt_slot_bool, qt_slot_int, qt_slot_double

    abstract interface
        !> Slot for signals with two integer arguments (e.g. row, column).
        subroutine qt_slot_int2(a, b, data)
            implicit none
            integer, intent(in) :: a, b
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_int2
        !> Slot for signals with three integer arguments (e.g. year, month, day).
        subroutine qt_slot_int3(a, b, c, data)
            implicit none
            integer, intent(in) :: a, b, c
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_int3
        !> Slot for signals with four integer arguments (e.g. current and previous row, column).
        subroutine qt_slot_int4(a, b, c, d, data)
            implicit none
            integer, intent(in) :: a, b, c, d
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_int4
    end interface
    public :: qt_slot_int2, qt_slot_int3, qt_slot_int4

    !> A calendar date (QDate as a value type).
    type, public :: QDate
        integer :: year = 2000   !! year (e.g. 2026)
        integer :: month = 1     !! month, 1..12
        integer :: day = 1       !! day of the month, 1..31
    end type QDate

    !> A time of day (QTime as a value type).
    type, public :: QTime
        integer :: hour = 0      !! 0..23
        integer :: minute = 0    !! 0..59
        integer :: second = 0    !! 0..59
    end type QTime

    !> A date and time of day in local time (QDateTime as a value type), e.g.
    !> `QDateTime(2026, 10, 25, 14, 30)`. All zeros is the invalid date-time.
    type, public :: QDateTime
        integer :: year = 0
        integer :: month = 0     !! 1..12
        integer :: day = 0       !! 1..31
        integer :: hour = 0      !! 0..23
        integer :: minute = 0    !! 0..59
        integer :: second = 0    !! 0..59
        integer :: msec = 0      !! 0..999
    contains
        procedure :: isValid => qdatetime_isValid
        procedure :: toString => qdatetime_toString
        procedure :: addMSecs => qdatetime_addMSecs
        procedure :: addSecs => qdatetime_addSecs
        procedure :: addDays => qdatetime_addDays
        procedure :: addMonths => qdatetime_addMonths
        procedure :: addYears => qdatetime_addYears
        procedure :: msecsTo => qdatetime_msecsTo
        procedure :: secsTo => qdatetime_secsTo
        procedure :: daysTo => qdatetime_daysTo
        procedure :: toMSecsSinceEpoch => qdatetime_toMSecsSinceEpoch
        procedure :: dayOfWeek => qdatetime_dayOfWeek
        procedure :: date => qdatetime_date
        procedure :: time => qdatetime_time
        procedure, private :: qdatetime_eq, qdatetime_ne, qdatetime_lt, qdatetime_le, qdatetime_gt, qdatetime_ge
        generic :: operator(==) => qdatetime_eq
        generic :: operator(/=) => qdatetime_ne
        generic :: operator(<) => qdatetime_lt
        generic :: operator(<=) => qdatetime_le
        generic :: operator(>) => qdatetime_gt
        generic :: operator(>=) => qdatetime_ge
    end type QDateTime

    !> Base for slot kinds defined outside this module (e.g. event and painter
    !> slots in qt_gui). An extension stores a typed procedure pointer and
    !> converts the raw `qtf_args` in `invoke`.
    type, abstract, public :: qt_slot_handler
    contains
        procedure(qt_handler_invoke), deferred :: invoke
    end type qt_slot_handler

    abstract interface
        !> Deliver one emission to the typed slot, converting the raw arguments.
        subroutine qt_handler_invoke(self, args, data)
            import :: qt_slot_handler, qtf_args
            implicit none
            class(qt_slot_handler), intent(in) :: self
            type(qtf_args), intent(in) :: args
            class(*), pointer, intent(in) :: data   !! null if no data was given
        end subroutine qt_handler_invoke
    end interface

    !> Base of all signal types: the sender object and the signal's id.
    type, abstract, public :: QtfSignal
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
        integer(c_int) :: serial = 0   !! the sender's serial number (see QObject)
    contains
        procedure :: disconnect => qtfsignal_disconnect
    end type QtfSignal

    !> One connection, from `connect`'s optional `connection` argument; break it
    !> with QObject_disconnect.
    type, public :: QMetaObject_Connection
        private
        integer :: slot = 0              !! the slot's registry index
        integer(c_int64_t) :: serial = 0 !! tells this connection from a later one reusing the index
    end type QMetaObject_Connection

    !> A signal without arguments.
    type, extends(QtfSignal), public :: QSignal
    contains
        procedure :: connect => qsignal_connect
        procedure :: emit => qsignal_emit
    end type QSignal

    !> A signal with a single string argument.
    type, extends(QtfSignal), public :: QSignalString
    contains
        procedure :: connect => qsignalstring_connect
        procedure :: emit => qsignalstring_emit
    end type QSignalString

    !> A signal with a single logical argument.
    type, extends(QtfSignal), public :: QSignalBool
    contains
        procedure :: connect => qsignalbool_connect
        procedure :: emit => qsignalbool_emit
    end type QSignalBool

    !> A signal with a single integer argument.
    type, extends(QtfSignal), public :: QSignalInt
    contains
        procedure :: connect => qsignalint_connect
        procedure :: emit => qsignalint_emit
    end type QSignalInt

    !> A signal with two integer arguments.
    type, extends(QtfSignal), public :: QSignalInt2
    contains
        procedure :: connect => qsignalint2_connect
        procedure :: emit => qsignalint2_emit
    end type QSignalInt2

    !> A signal with three integer arguments.
    type, extends(QtfSignal), public :: QSignalInt3
    contains
        procedure :: connect => qsignalint3_connect
        procedure :: emit => qsignalint3_emit
    end type QSignalInt3

    !> A signal with four integer arguments.
    type, extends(QtfSignal), public :: QSignalInt4
    contains
        procedure :: connect => qsignalint4_connect
        procedure :: emit => qsignalint4_emit
    end type QSignalInt4

    !> A signal with a single real argument.
    type, extends(QtfSignal), public :: QSignalDouble
    contains
        procedure :: connect => qsignaldouble_connect
        procedure :: emit => qsignaldouble_emit
    end type QSignalDouble

    !> Constructor: `QSignal(parent)` creates a signal defined in Fortran (emit it with `emit`).
    interface QSignal
        module procedure :: qsignal_new
    end interface QSignal
    !> Constructor: `QSignalString(parent)` creates a signal defined in Fortran (emit it with `emit`).
    interface QSignalString
        module procedure :: qsignalstring_new
    end interface QSignalString
    !> Constructor: `QSignalBool(parent)` creates a signal defined in Fortran (emit it with `emit`).
    interface QSignalBool
        module procedure :: qsignalbool_new
    end interface QSignalBool
    !> Constructor: `QSignalInt(parent)` creates a signal defined in Fortran (emit it with `emit`).
    interface QSignalInt
        module procedure :: qsignalint_new
    end interface QSignalInt
    !> Constructor: `QSignalInt2(parent)` creates a signal defined in Fortran (emit it with `emit`).
    interface QSignalInt2
        module procedure :: qsignalint2_new
    end interface QSignalInt2
    !> Constructor: `QSignalInt3(parent)` creates a signal defined in Fortran (emit it with `emit`).
    interface QSignalInt3
        module procedure :: qsignalint3_new
    end interface QSignalInt3
    !> Constructor: `QSignalInt4(parent)` creates a signal defined in Fortran (emit it with `emit`).
    interface QSignalInt4
        module procedure :: qsignalint4_new
    end interface QSignalInt4
    !> Constructor: `QSignalDouble(parent)` creates a signal defined in Fortran (emit it with `emit`).
    interface QSignalDouble
        module procedure :: qsignaldouble_new
    end interface QSignalDouble

    !> Base of all Qt objects: a handle (`ptr`) to a C++ QObject plus its signals.
    type, public :: QObject
        type(c_ptr) :: ptr = c_null_ptr
        integer(c_int) :: serial = 0   !! identifies the object: tells a deleted one from a new one at the same address
        type(QSignal) :: destroyed
        type(QSignalString) :: objectNameChanged
    contains
        procedure :: attach => qobject_attach
        procedure :: isNull => qobject_isNull
        procedure :: delete => qobject_delete
        procedure :: deleteLater => qobject_deleteLater
        procedure :: objectName => qobject_objectName
        procedure :: setObjectName => qobject_setObjectName
        procedure :: setParent => qobject_setParent
        procedure :: parent => qobject_parent
        procedure :: className => qobject_className
        procedure :: inherits => qobject_inherits
        procedure, private :: qobject_setPropertyString, qobject_setPropertyInt, qobject_setPropertyDouble, &
                              qobject_setPropertyBool
        generic :: setProperty => qobject_setPropertyString, qobject_setPropertyInt, qobject_setPropertyDouble, &
                                  qobject_setPropertyBool
        procedure :: stringProperty => qobject_stringProperty
        procedure :: intProperty => qobject_intProperty
        procedure :: doubleProperty => qobject_doubleProperty
        procedure :: boolProperty => qobject_boolProperty
        procedure :: hasProperty => qobject_hasProperty
        procedure :: findChild => qobject_findChild
    end type QObject
    !> Constructor: `QObject([parent])`.
    interface QObject
        module procedure :: qobject_new
    end interface QObject

    !> A repeating or single-shot timer; connect to `timeout`.
    type, extends(QObject), public :: QTimer
        type(QSignal) :: timeout
    contains
        procedure :: attach => qtimer_attach
        procedure :: start => qtimer_start
        procedure :: stop => qtimer_stop
        procedure :: setInterval => qtimer_setInterval
        procedure :: interval => qtimer_interval
        procedure :: isActive => qtimer_isActive
        procedure :: setSingleShot => qtimer_setSingleShot
        procedure :: isSingleShot => qtimer_isSingleShot
    end type QTimer
    !> Constructor: `QTimer([parent])`.
    interface QTimer
        module procedure :: qtimer_new
    end interface QTimer

    !> Base of all events. Events received in slots are owned by Qt; events
    !> created from Fortran (e.g. QMouseEvent(...)) must be released with `delete`.
    type, public :: QEvent
        type(c_ptr) :: ptr = c_null_ptr
    contains
        procedure :: type => qevent_type
        procedure :: accept => qevent_accept
        procedure :: ignore => qevent_ignore
        procedure :: isAccepted => qevent_isAccepted
        procedure :: delete => qevent_delete
    end type QEvent
    !> Constructor: `QEvent(type)`, a synthetic event (e.g. QEvent_FocusIn, QEvent_Enter,
    !> QEvent_Show) to send with QCoreApplication_sendEvent; delete it after use.
    interface QEvent
        module procedure :: qevent_new
    end interface QEvent

    !> Slot handler for QSignalInt2.
    type, extends(qt_slot_handler) :: int2_handler
        procedure(qt_slot_int2), pointer, nopass :: f => null()
    contains
        procedure :: invoke => int2_handler_invoke
    end type int2_handler

    !> Slot handler for QSignalInt3.
    type, extends(qt_slot_handler) :: int3_handler
        procedure(qt_slot_int3), pointer, nopass :: f => null()
    contains
        procedure :: invoke => int3_handler_invoke
    end type int3_handler

    !> Slot handler for QSignalInt4.
    type, extends(qt_slot_handler) :: int4_handler
        procedure(qt_slot_int4), pointer, nopass :: f => null()
    contains
        procedure :: invoke => int4_handler_invoke
    end type int4_handler

    public :: QTimer_singleShot, QCoreApplication_sendEvent
    public :: QDateTime_currentDateTime, QDateTime_fromString, QDateTime_fromMSecsSinceEpoch
    public :: qtf_ptr, qtf_live, qt_slot_count, qt_connect_handler, QObject_disconnect

    ! ------------------------------------------------------------------
    ! slot registry: the shim refers to Fortran slots by index into `slots`

    integer, parameter :: SLOT_VOID = 1, SLOT_STRING = 2, SLOT_BOOL = 3, SLOT_INT = 4, SLOT_DOUBLE = 5, &
                          SLOT_HANDLER = 6

    !> One registered Fortran slot: its kind, procedure pointer and user data.
    type :: slot_entry
        integer :: kind = 0     !! 0 = free
        procedure(qt_slot), pointer, nopass :: void => null()
        procedure(qt_slot_string), pointer, nopass :: string => null()
        procedure(qt_slot_bool), pointer, nopass :: bool => null()
        procedure(qt_slot_int), pointer, nopass :: int => null()
        procedure(qt_slot_double), pointer, nopass :: double => null()
        class(qt_slot_handler), allocatable :: handler
        class(*), pointer :: data => null()
        type(c_ptr) :: sender = c_null_ptr     !! the connected signal
        integer :: signal = 0
        integer(c_int64_t) :: serial = 0       !! see QMetaObject_Connection
    end type slot_entry

    type(slot_entry), allocatable, save :: slots(:)
    integer, save :: nslots = 0     !! number of slots in use
    integer(c_int64_t), save :: last_serial = 0
    logical, save :: dispatcher_registered = .false.

contains

    ! ------------------------------------------------------------------
    ! slot registry & dispatch

    !> Number of live Fortran slots (connections not yet destroyed by Qt).
    integer function qt_slot_count()
        qt_slot_count = nslots
    end function qt_slot_count

    !> Reserve a free slot entry of the given kind and return its index.
    integer function new_slot(kind) result(id)
        integer, intent(in) :: kind
        type(slot_entry), allocatable :: tmp(:)
        if (.not. dispatcher_registered) then
            call qtf_set_dispatcher(c_funloc(qtf_dispatch), c_funloc(qtf_release))
            dispatcher_registered = .true.
        end if
        if (.not. allocated(slots)) allocate(slots(16))
        do id = 1, size(slots)
            if (slots(id)%kind == 0) exit
        end do
        if (id > size(slots)) then
            allocate(tmp(2*size(slots)))
            tmp(1:size(slots)) = slots
            call move_alloc(tmp, slots)
        end if
        slots(id)%kind = kind
        nslots = nslots + 1
    end function new_slot

    !> Connect `signal` of `sender` to the reserved slot `id`.
    subroutine connect_slot(sig, id, connection)
        class(QtfSignal), intent(in) :: sig
        integer, intent(in) :: id
        type(QMetaObject_Connection), intent(out), optional :: connection
        call check_sender(sig, 'connect')
        last_serial = last_serial + 1
        slots(id)%sender = sig%sender
        slots(id)%signal = sig%id
        slots(id)%serial = last_serial
        if (present(connection)) connection = QMetaObject_Connection(id, last_serial)
        ! on failure the shim has already released the slot
        if (qtf_connect(sig%sender, sig%id, int(id, c_int)) == 0) &
            error stop 'qt: failed to connect signal (null or unsupported sender)'
    end subroutine connect_slot

    !> Stop with a message if the signal's object is null or has been deleted.
    subroutine check_sender(sig, what)
        class(QtfSignal), intent(in) :: sig
        character(len=*), intent(in) :: what
        if (.not. c_associated(sig%sender)) then
            error stop 'qt: ' // what // ': the signal belongs to a null handle (object never created)'
        else if (qtf_object_alive(sig%sender, sig%serial) == 0) then
            error stop 'qt: ' // what // ': the object of this signal has been deleted'
        end if
    end subroutine check_sender

    !> Break one connection made by `connect`; returns .false. if it was
    !> already broken (disconnected, or its sender destroyed).
    logical function QObject_disconnect(connection)
        type(QMetaObject_Connection), intent(in) :: connection
        QObject_disconnect = .false.
        if (.not. allocated(slots)) return
        if (connection%slot < 1 .or. connection%slot > size(slots)) return
        if (slots(connection%slot)%kind == 0 .or. slots(connection%slot)%serial /= connection%serial) return
        QObject_disconnect = qtf_disconnect(int(connection%slot, c_int)) /= 0
    end function QObject_disconnect

    !> Disconnect all Fortran slots connected to this signal.
    subroutine qtfsignal_disconnect(self)
        class(QtfSignal), intent(in) :: self
        integer :: id
        integer(c_int) :: found
        if (.not. allocated(slots) .or. .not. c_associated(self%sender)) return
        if (qtf_object_alive(self%sender, self%serial) == 0) return   ! deleted: its slots are gone
        do id = 1, size(slots)
            if (slots(id)%kind == 0 .or. slots(id)%signal /= self%id) cycle
            if (.not. c_associated(slots(id)%sender, self%sender)) cycle
            found = qtf_disconnect(int(id, c_int))   ! releases slots(id)
        end do
    end subroutine qtfsignal_disconnect

    !> Called by the shim when a signal fires.
    subroutine qtf_dispatch(id, args) bind(C)
        integer(c_int), value :: id
        type(qtf_args), intent(in) :: args
        procedure(qt_slot), pointer :: f_void
        procedure(qt_slot_string), pointer :: f_string
        procedure(qt_slot_bool), pointer :: f_bool
        procedure(qt_slot_int), pointer :: f_int
        procedure(qt_slot_double), pointer :: f_double
        class(qt_slot_handler), allocatable :: handler
        class(*), pointer :: data
        ! copy out first: the slot may connect (reallocating `slots`) or release itself
        f_void => slots(id)%void
        f_string => slots(id)%string
        f_bool => slots(id)%bool
        f_int => slots(id)%int
        f_double => slots(id)%double
        data => slots(id)%data
        if (slots(id)%kind == SLOT_HANDLER) allocate(handler, source=slots(id)%handler)
        select case (slots(id)%kind)
        case (SLOT_VOID)
            if (associated(data)) then
                call f_void(data)
            else
                call f_void()
            end if
        case (SLOT_STRING)
            if (associated(data)) then
                call f_string(qtf_string(args%s, args%slen), data)
            else
                call f_string(qtf_string(args%s, args%slen))
            end if
        case (SLOT_BOOL)
            if (associated(data)) then
                call f_bool(args%i(1) /= 0, data)
            else
                call f_bool(args%i(1) /= 0)
            end if
        case (SLOT_INT)
            if (associated(data)) then
                call f_int(int(args%i(1)), data)
            else
                call f_int(int(args%i(1)))
            end if
        case (SLOT_DOUBLE)
            if (associated(data)) then
                call f_double(args%d(1), data)
            else
                call f_double(args%d(1))
            end if
        case (SLOT_HANDLER)
            call handler%invoke(args, data)
        end select
    end subroutine qtf_dispatch

    !> Called by the shim when a connection is destroyed.
    subroutine qtf_release(id) bind(C)
        integer(c_int), value :: id
        if (.not. allocated(slots)) return
        if (id < 1 .or. id > size(slots)) return
        if (slots(id)%kind == 0) return
        slots(id) = slot_entry()
        nslots = nslots - 1
    end subroutine qtf_release

    ! ------------------------------------------------------------------
    ! signals

    !> Connect a slot (with optional user data) to this signal.
    subroutine qsignal_connect(self, slot, data, connection)
        class(QSignal), intent(in) :: self
        procedure(qt_slot) :: slot
        class(*), intent(inout), target, optional :: data
        type(QMetaObject_Connection), intent(out), optional :: connection   !! to disconnect it later
        integer :: id
        id = new_slot(SLOT_VOID)
        slots(id)%void => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self, id, connection)
    end subroutine qsignal_connect

    !> Connect a slot (with optional user data) to this signal.
    subroutine qsignalstring_connect(self, slot, data, connection)
        class(QSignalString), intent(in) :: self
        procedure(qt_slot_string) :: slot
        class(*), intent(inout), target, optional :: data
        type(QMetaObject_Connection), intent(out), optional :: connection   !! to disconnect it later
        integer :: id
        id = new_slot(SLOT_STRING)
        slots(id)%string => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self, id, connection)
    end subroutine qsignalstring_connect

    !> Connect a slot (with optional user data) to this signal.
    subroutine qsignalbool_connect(self, slot, data, connection)
        class(QSignalBool), intent(in) :: self
        procedure(qt_slot_bool) :: slot
        class(*), intent(inout), target, optional :: data
        type(QMetaObject_Connection), intent(out), optional :: connection   !! to disconnect it later
        integer :: id
        id = new_slot(SLOT_BOOL)
        slots(id)%bool => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self, id, connection)
    end subroutine qsignalbool_connect

    !> Connect a slot (with optional user data) to this signal.
    subroutine qsignalint_connect(self, slot, data, connection)
        class(QSignalInt), intent(in) :: self
        procedure(qt_slot_int) :: slot
        class(*), intent(inout), target, optional :: data
        type(QMetaObject_Connection), intent(out), optional :: connection   !! to disconnect it later
        integer :: id
        id = new_slot(SLOT_INT)
        slots(id)%int => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self, id, connection)
    end subroutine qsignalint_connect

    !> Connect a slot (with optional user data) to this signal.
    subroutine qsignaldouble_connect(self, slot, data, connection)
        class(QSignalDouble), intent(in) :: self
        procedure(qt_slot_double) :: slot
        class(*), intent(inout), target, optional :: data
        type(QMetaObject_Connection), intent(out), optional :: connection   !! to disconnect it later
        integer :: id
        id = new_slot(SLOT_DOUBLE)
        slots(id)%double => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self, id, connection)
    end subroutine qsignaldouble_connect

    !> Connect a signal to a handler (a slot kind defined outside this module).
    !> The handler is copied.
    subroutine qt_connect_handler(sig, handler, data, connection)
        class(QtfSignal), intent(in) :: sig
        class(qt_slot_handler), intent(in) :: handler
        class(*), intent(inout), target, optional :: data
        type(QMetaObject_Connection), intent(out), optional :: connection
        integer :: id
        id = new_slot(SLOT_HANDLER)
        allocate(slots(id)%handler, source=handler)
        if (present(data)) slots(id)%data => data
        call connect_slot(sig, id, connection)
    end subroutine qt_connect_handler

    !> Connect a slot (with optional user data) to this signal.
    subroutine qsignalint2_connect(self, slot, data, connection)
        class(QSignalInt2), intent(in) :: self
        procedure(qt_slot_int2) :: slot
        class(*), intent(inout), target, optional :: data
        type(QMetaObject_Connection), intent(out), optional :: connection   !! to disconnect it later
        type(int2_handler) :: h
        h%f => slot
        call qt_connect_handler(self, h, data, connection)
    end subroutine qsignalint2_connect

    !> Call the slot with the first two integer arguments.
    subroutine int2_handler_invoke(self, args, data)
        class(int2_handler), intent(in) :: self
        type(qtf_args), intent(in) :: args
        class(*), pointer, intent(in) :: data
        if (associated(data)) then
            call self%f(int(args%i(1)), int(args%i(2)), data)
        else
            call self%f(int(args%i(1)), int(args%i(2)))
        end if
    end subroutine int2_handler_invoke

    !> Connect a slot (with optional user data) to this signal.
    subroutine qsignalint3_connect(self, slot, data, connection)
        class(QSignalInt3), intent(in) :: self
        procedure(qt_slot_int3) :: slot
        class(*), intent(inout), target, optional :: data
        type(QMetaObject_Connection), intent(out), optional :: connection   !! to disconnect it later
        type(int3_handler) :: h
        h%f => slot
        call qt_connect_handler(self, h, data, connection)
    end subroutine qsignalint3_connect

    !> Call the slot with the first three integer arguments.
    subroutine int3_handler_invoke(self, args, data)
        class(int3_handler), intent(in) :: self
        type(qtf_args), intent(in) :: args
        class(*), pointer, intent(in) :: data
        if (associated(data)) then
            call self%f(int(args%i(1)), int(args%i(2)), int(args%i(3)), data)
        else
            call self%f(int(args%i(1)), int(args%i(2)), int(args%i(3)))
        end if
    end subroutine int3_handler_invoke

    !> Connect a slot (with optional user data) to this signal.
    subroutine qsignalint4_connect(self, slot, data, connection)
        class(QSignalInt4), intent(in) :: self
        procedure(qt_slot_int4) :: slot
        class(*), intent(inout), target, optional :: data
        type(QMetaObject_Connection), intent(out), optional :: connection   !! to disconnect it later
        type(int4_handler) :: h
        h%f => slot
        call qt_connect_handler(self, h, data, connection)
    end subroutine qsignalint4_connect

    !> Call the slot with the four integer arguments.
    subroutine int4_handler_invoke(self, args, data)
        class(int4_handler), intent(in) :: self
        type(qtf_args), intent(in) :: args
        class(*), pointer, intent(in) :: data
        if (associated(data)) then
            call self%f(int(args%i(1)), int(args%i(2)), int(args%i(3)), int(args%i(4)), data)
        else
            call self%f(int(args%i(1)), int(args%i(2)), int(args%i(3)), int(args%i(4)))
        end if
    end subroutine int4_handler_invoke

    ! ------------------------------------------------------------------
    ! signals defined in Fortran

    !> A new Fortran-defined signal source, owned by `parent` if given (one
    !> without a parent lives until the program ends).
    type(c_ptr) function new_source(parent)
        class(QObject), intent(in), optional :: parent
        new_source = qtf_qtfsignal_new(qtf_ptr(parent))
    end function new_source

    !> Call the slots of a Fortran-defined signal.
    subroutine emit_args(sig, ints, d, s)
        class(QtfSignal), intent(in) :: sig
        integer, intent(in), optional :: ints(:)
        real(c_double), intent(in), optional :: d
        character(len=*), intent(in), optional :: s
        integer(c_int) :: i(4)
        real(c_double) :: d_
        i = 0
        d_ = 0
        if (present(ints)) i(1:size(ints)) = int(ints, c_int)
        if (present(d)) d_ = d
        call check_sender(sig, 'emit')
        if (present(s)) then
            if (qtf_qtfsignal_emit(sig%sender, i, d_, s, len(s, c_int)) == 0) &
                error stop 'qt: only signals created in Fortran (e.g. QSignal(parent)) can be emitted'
        else
            if (qtf_qtfsignal_emit(sig%sender, i, d_, '', 0_c_int) == 0) &
                error stop 'qt: only signals created in Fortran (e.g. QSignal(parent)) can be emitted'
        end if
    end subroutine emit_args

    !> Create a signal defined in Fortran, owned by `parent` if given.
    function qsignal_new(parent) result(sig)
        class(QObject), intent(in), optional :: parent
        type(QSignal) :: sig
        sig%sender = new_source(parent)
        sig%id = QTF_SIG_QTFSIGNAL
        sig%serial = qtf_object_serial(sig%sender)
    end function qsignal_new

    !> Call the connected slots. Only for signals created in Fortran.
    subroutine qsignal_emit(self)
        class(QSignal), intent(in) :: self
        call emit_args(self)
    end subroutine qsignal_emit

    !> Create a signal defined in Fortran, owned by `parent` if given.
    function qsignalstring_new(parent) result(sig)
        class(QObject), intent(in), optional :: parent
        type(QSignalString) :: sig
        sig%sender = new_source(parent)
        sig%id = QTF_SIG_QTFSIGNAL
        sig%serial = qtf_object_serial(sig%sender)
    end function qsignalstring_new

    !> Call the connected slots with `value`. Only for signals created in Fortran.
    subroutine qsignalstring_emit(self, value)
        class(QSignalString), intent(in) :: self
        character(len=*), intent(in) :: value
        call emit_args(self, s=value)
    end subroutine qsignalstring_emit

    !> Create a signal defined in Fortran, owned by `parent` if given.
    function qsignalbool_new(parent) result(sig)
        class(QObject), intent(in), optional :: parent
        type(QSignalBool) :: sig
        sig%sender = new_source(parent)
        sig%id = QTF_SIG_QTFSIGNAL
        sig%serial = qtf_object_serial(sig%sender)
    end function qsignalbool_new

    !> Call the connected slots with `value`. Only for signals created in Fortran.
    subroutine qsignalbool_emit(self, value)
        class(QSignalBool), intent(in) :: self
        logical, intent(in) :: value
        call emit_args(self, [merge(1, 0, value)])
    end subroutine qsignalbool_emit

    !> Create a signal defined in Fortran, owned by `parent` if given.
    function qsignalint_new(parent) result(sig)
        class(QObject), intent(in), optional :: parent
        type(QSignalInt) :: sig
        sig%sender = new_source(parent)
        sig%id = QTF_SIG_QTFSIGNAL
        sig%serial = qtf_object_serial(sig%sender)
    end function qsignalint_new

    !> Call the connected slots with `value`. Only for signals created in Fortran.
    subroutine qsignalint_emit(self, value)
        class(QSignalInt), intent(in) :: self
        integer, intent(in) :: value
        call emit_args(self, [value])
    end subroutine qsignalint_emit

    !> Create a signal defined in Fortran, owned by `parent` if given.
    function qsignalint2_new(parent) result(sig)
        class(QObject), intent(in), optional :: parent
        type(QSignalInt2) :: sig
        sig%sender = new_source(parent)
        sig%id = QTF_SIG_QTFSIGNAL
        sig%serial = qtf_object_serial(sig%sender)
    end function qsignalint2_new

    !> Call the connected slots with (a, b). Only for signals created in Fortran.
    subroutine qsignalint2_emit(self, a, b)
        class(QSignalInt2), intent(in) :: self
        integer, intent(in) :: a, b
        call emit_args(self, [a, b])
    end subroutine qsignalint2_emit

    !> Create a signal defined in Fortran, owned by `parent` if given.
    function qsignalint3_new(parent) result(sig)
        class(QObject), intent(in), optional :: parent
        type(QSignalInt3) :: sig
        sig%sender = new_source(parent)
        sig%id = QTF_SIG_QTFSIGNAL
        sig%serial = qtf_object_serial(sig%sender)
    end function qsignalint3_new

    !> Call the connected slots with (a, b, c). Only for signals created in Fortran.
    subroutine qsignalint3_emit(self, a, b, c)
        class(QSignalInt3), intent(in) :: self
        integer, intent(in) :: a, b, c
        call emit_args(self, [a, b, c])
    end subroutine qsignalint3_emit

    !> Create a signal defined in Fortran, owned by `parent` if given.
    function qsignalint4_new(parent) result(sig)
        class(QObject), intent(in), optional :: parent
        type(QSignalInt4) :: sig
        sig%sender = new_source(parent)
        sig%id = QTF_SIG_QTFSIGNAL
        sig%serial = qtf_object_serial(sig%sender)
    end function qsignalint4_new

    !> Call the connected slots with (a, b, c, d). Only for signals created in Fortran.
    subroutine qsignalint4_emit(self, a, b, c, d)
        class(QSignalInt4), intent(in) :: self
        integer, intent(in) :: a, b, c, d
        call emit_args(self, [a, b, c, d])
    end subroutine qsignalint4_emit

    !> Create a signal defined in Fortran, owned by `parent` if given.
    function qsignaldouble_new(parent) result(sig)
        class(QObject), intent(in), optional :: parent
        type(QSignalDouble) :: sig
        sig%sender = new_source(parent)
        sig%id = QTF_SIG_QTFSIGNAL
        sig%serial = qtf_object_serial(sig%sender)
    end function qsignaldouble_new

    !> Call the connected slots with `value`. Only for signals created in Fortran.
    subroutine qsignaldouble_emit(self, value)
        class(QSignalDouble), intent(in) :: self
        real(c_double), intent(in) :: value
        call emit_args(self, d=value)
    end subroutine qsignaldouble_emit

    ! ------------------------------------------------------------------
    ! QEvent

    !> The event type (a QEvent_* constant).
    integer function qevent_type(self)
        class(QEvent), intent(in) :: self
        qevent_type = qtf_qevent_type(self%ptr)
    end function qevent_type

    !> Mark the event as handled.
    subroutine qevent_accept(self)
        class(QEvent), intent(in) :: self
        call qtf_qevent_accept(self%ptr)
    end subroutine qevent_accept

    !> Mark the event as not handled, so it may propagate to the parent widget.
    subroutine qevent_ignore(self)
        class(QEvent), intent(in) :: self
        call qtf_qevent_ignore(self%ptr)
    end subroutine qevent_ignore

    !> True if the event was accepted.
    logical function qevent_isAccepted(self)
        class(QEvent), intent(in) :: self
        qevent_isAccepted = qtf_logical(qtf_qevent_isAccepted(self%ptr))
    end function qevent_isAccepted

    !> A synthetic event of the given type (a QEvent_* constant); delete it after use.
    function qevent_new(type) result(e)
        integer, intent(in) :: type
        type(QEvent) :: e
        e%ptr = qtf_qevent_new(int(type, c_int))
    end function qevent_new

    !> Delete an event created from Fortran (never one received in a slot).
    subroutine qevent_delete(self)
        class(QEvent), intent(inout) :: self
        if (c_associated(self%ptr)) call qtf_qevent_delete(self%ptr)
        self%ptr = c_null_ptr
    end subroutine qevent_delete

    !> Deliver `event` to `receiver` synchronously; returns whether it was handled.
    logical function QCoreApplication_sendEvent(receiver, event)
        class(QObject), intent(in) :: receiver
        class(QEvent), intent(in) :: event
        QCoreApplication_sendEvent = qtf_logical(qtf_qcoreapplication_sendEvent(receiver%ptr, event%ptr))
    end function QCoreApplication_sendEvent

    ! ------------------------------------------------------------------
    ! QObject

    !> Handle of an optional object (null when absent or a null handle), e.g. for
    !> `parent` arguments. Stops if the object has been deleted.
    type(c_ptr) function qtf_ptr(obj)
        class(QObject), intent(in), optional :: obj
        qtf_ptr = c_null_ptr
        if (.not. present(obj)) return
        if (.not. c_associated(obj%ptr)) return
        if (qtf_object_alive(obj%ptr, obj%serial) == 0) &
            error stop 'qt: an object passed as an argument has been deleted (e.g. together with its parent)'
        qtf_ptr = obj%ptr
    end function qtf_ptr

    !> The C++ object of a handle, checked: stops with a message naming `where`
    !> (e.g. 'QLabel%setText') if the handle is null or its object was deleted.
    type(c_ptr) function qtf_live(obj, where)
        class(QObject), intent(in) :: obj
        character(len=*), intent(in) :: where
        if (.not. c_associated(obj%ptr)) then
            error stop 'qt: ' // where // ': null handle (the object was never created, or was deleted through it)'
        else if (qtf_object_alive(obj%ptr, obj%serial) == 0) then
            error stop 'qt: ' // where // ': the object has been deleted (e.g. together with its parent)'
        end if
        qtf_live = obj%ptr
    end function qtf_live

    !> Create a QObject, owned by `parent` if given.
    function qobject_new(parent) result(o)
        class(QObject), intent(in), optional :: parent
        type(QObject) :: o
        call o%attach(qtf_qobject_new(qtf_ptr(parent)))
    end function qobject_new

    !> Point this wrapper at an existing Qt object and bind its signals.
    !> Extended types override this to bind their own signals.
    subroutine qobject_attach(self, ptr)
        class(QObject), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        self%ptr = ptr
        self%serial = qtf_object_serial(ptr)
        self%destroyed = QSignal(ptr, QTF_SIG_QOBJECT_DESTROYED, self%serial)
        self%objectNameChanged = QSignalString(ptr, QTF_SIG_QOBJECT_OBJECTNAMECHANGED, self%serial)
    end subroutine qobject_attach

    !> True if this handle does not refer to a live object: it was never set,
    !> or the object has been deleted (through any handle, or by Qt, e.g.
    !> together with its parent), like QPointer::isNull.
    logical function qobject_isNull(self)
        class(QObject), intent(in) :: self
        qobject_isNull = .true.
        if (c_associated(self%ptr)) qobject_isNull = qtf_object_alive(self%ptr, self%serial) == 0
    end function qobject_isNull

    !> Delete the object now (its children are deleted by Qt) and null the handle.
    !> Does nothing if the object was already deleted.
    subroutine qobject_delete(self)
        class(QObject), intent(inout) :: self
        if (.not. self%isNull()) call qtf_qobject_delete(self%ptr)
        call self%attach(c_null_ptr)
    end subroutine qobject_delete

    !> Schedule deletion when control returns to the event loop.
    subroutine qobject_deleteLater(self)
        class(QObject), intent(in) :: self
        call qtf_qobject_deleteLater(qtf_live(self, 'QObject%deleteLater'))
    end subroutine qobject_deleteLater

    !> The object's name.
    function qobject_objectName(self) result(name)
        class(QObject), intent(in) :: self
        character(len=:), allocatable :: name
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qobject_objectName(qtf_live(self, 'QObject%objectName'), n)
        name = qtf_take_string(p, n)
    end function qobject_objectName

    !> Set the object's name (emits objectNameChanged).
    subroutine qobject_setObjectName(self, name)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        call qtf_qobject_setObjectName(qtf_live(self, 'QObject%setObjectName'), name, len(name, c_int))
    end subroutine qobject_setObjectName

    !> Set the parent (which then owns this object); no argument clears it.
    subroutine qobject_setParent(self, parent)
        class(QObject), intent(in) :: self
        class(QObject), intent(in), optional :: parent
        call qtf_qobject_setParent(qtf_live(self, 'QObject%setParent'), qtf_ptr(parent))
    end subroutine qobject_setParent

    !> The parent object (a null handle if there is none).
    function qobject_parent(self) result(parent)
        class(QObject), intent(in) :: self
        type(QObject) :: parent
        call parent%attach(qtf_qobject_parent(qtf_live(self, 'QObject%parent')))
    end function qobject_parent

    !> Name of the object's most derived Qt class, e.g. "QTimer".
    function qobject_className(self) result(name)
        class(QObject), intent(in) :: self
        character(len=:), allocatable :: name
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qobject_className(qtf_live(self, 'QObject%className'), n)
        name = qtf_take_string(p, n)
    end function qobject_className

    !> Set a dynamic property to a string. Properties can select style sheet
    !> rules, e.g. `*[state="error"] { color: red }` (call `repolish` on a
    !> widget after changing one that its style depends on).
    subroutine qobject_setPropertyString(self, name, value)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name, value
        call qtf_qobject_setPropertyString(qtf_live(self, 'QObject%setProperty'), name, len(name, c_int), &
                                           value, len(value, c_int))
    end subroutine qobject_setPropertyString

    !> Set a dynamic property to an integer.
    subroutine qobject_setPropertyInt(self, name, value)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        integer, intent(in) :: value
        call qtf_qobject_setPropertyInt(qtf_live(self, 'QObject%setProperty'), name, len(name, c_int), &
                                        int(value, c_int))
    end subroutine qobject_setPropertyInt

    !> Set a dynamic property to a real number.
    subroutine qobject_setPropertyDouble(self, name, value)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        real(c_double), intent(in) :: value
        call qtf_qobject_setPropertyDouble(qtf_live(self, 'QObject%setProperty'), name, len(name, c_int), value)
    end subroutine qobject_setPropertyDouble

    !> Set a dynamic property to a logical.
    subroutine qobject_setPropertyBool(self, name, value)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        logical, intent(in) :: value
        call qtf_qobject_setPropertyBool(qtf_live(self, 'QObject%setProperty'), name, len(name, c_int), &
                                         qtf_int(value))
    end subroutine qobject_setPropertyBool

    !> A property as a string (`default` if it is not set).
    function qobject_stringProperty(self, name, default) result(value)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        character(len=*), intent(in), optional :: default
        character(len=:), allocatable :: value
        integer(c_int) :: n
        type(c_ptr) :: p
        if (present(default)) then
            p = qtf_qobject_propertyString(qtf_live(self, 'QObject%stringProperty'), name, len(name, c_int), &
                                           default, len(default, c_int), n)
        else
            p = qtf_qobject_propertyString(qtf_live(self, 'QObject%stringProperty'), name, len(name, c_int), &
                                           '', 0_c_int, n)
        end if
        value = qtf_take_string(p, n)
    end function qobject_stringProperty

    !> A property as an integer (`default`, or 0, if it is not set).
    integer function qobject_intProperty(self, name, default)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        integer, intent(in), optional :: default
        integer(c_int) :: d
        d = 0
        if (present(default)) d = int(default, c_int)
        qobject_intProperty = qtf_qobject_propertyInt(qtf_live(self, 'QObject%intProperty'), name, len(name, c_int), d)
    end function qobject_intProperty

    !> A property as a real number (`default`, or 0, if it is not set).
    real(c_double) function qobject_doubleProperty(self, name, default)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        real(c_double), intent(in), optional :: default
        real(c_double) :: d
        d = 0
        if (present(default)) d = default
        qobject_doubleProperty = qtf_qobject_propertyDouble(qtf_live(self, 'QObject%doubleProperty'), name, &
                                                            len(name, c_int), d)
    end function qobject_doubleProperty

    !> A property as a logical (`default`, or .false., if it is not set).
    logical function qobject_boolProperty(self, name, default)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        logical, intent(in), optional :: default
        logical :: d
        d = .false.
        if (present(default)) d = default
        qobject_boolProperty = qtf_logical(qtf_qobject_propertyBool(qtf_live(self, 'QObject%boolProperty'), name, &
                                                                    len(name, c_int), qtf_int(d)))
    end function qobject_boolProperty

    !> True if the object has the property (a dynamic one, or a Qt property such as "objectName").
    logical function qobject_hasProperty(self, name)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        qobject_hasProperty = qtf_logical(qtf_qobject_hasProperty(qtf_live(self, 'QObject%hasProperty'), name, &
                                                                  len(name, c_int)))
    end function qobject_hasProperty

    !> Find a descendant by object name (searched recursively) and bind `child`
    !> to it, e.g. `call window%findChild('okButton', button)`; `child` is a
    !> null handle if there is none. `child` must have the object's type (or a
    !> base of it): check with `inherits` when unsure.
    subroutine qobject_findChild(self, name, child)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        class(QObject), intent(inout) :: child
        call child%attach(qtf_qobject_findChild(qtf_live(self, 'QObject%findChild'), name, len(name, c_int)))
    end subroutine qobject_findChild

    !> True if the object is an instance of `className` or of a class derived from it.
    logical function qobject_inherits(self, className)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: className
        qobject_inherits = qtf_logical(qtf_qobject_inherits(qtf_live(self, 'QObject%inherits'), className, len(className, c_int)))
    end function qobject_inherits

    ! ------------------------------------------------------------------
    ! QTimer

    !> Create a timer, owned by `parent` if given.
    function qtimer_new(parent) result(t)
        class(QObject), intent(in), optional :: parent
        type(QTimer) :: t
        call t%attach(qtf_qtimer_new(qtf_ptr(parent)))
    end function qtimer_new

    !> Bind to a C++ QTimer and its `timeout` signal.
    subroutine qtimer_attach(self, ptr)
        class(QTimer), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QObject%attach(ptr)
        self%timeout = QSignal(ptr, QTF_SIG_QTIMER_TIMEOUT, self%serial)
    end subroutine qtimer_attach

    !> Start (or restart) the timer, optionally setting the interval in ms.
    subroutine qtimer_start(self, msec)
        class(QTimer), intent(in) :: self
        integer, intent(in), optional :: msec
        integer(c_int) :: m
        m = -1
        if (present(msec)) m = int(msec, c_int)
        call qtf_qtimer_start(qtf_live(self, 'QTimer%start'), m)
    end subroutine qtimer_start

    !> Stop the timer.
    subroutine qtimer_stop(self)
        class(QTimer), intent(in) :: self
        call qtf_qtimer_stop(qtf_live(self, 'QTimer%stop'))
    end subroutine qtimer_stop

    !> Set the timeout interval in milliseconds.
    subroutine qtimer_setInterval(self, msec)
        class(QTimer), intent(in) :: self
        integer, intent(in) :: msec
        call qtf_qtimer_setInterval(qtf_live(self, 'QTimer%setInterval'), int(msec, c_int))
    end subroutine qtimer_setInterval

    !> The timeout interval in milliseconds.
    integer function qtimer_interval(self)
        class(QTimer), intent(in) :: self
        qtimer_interval = qtf_qtimer_interval(qtf_live(self, 'QTimer%interval'))
    end function qtimer_interval

    !> True while the timer is running.
    logical function qtimer_isActive(self)
        class(QTimer), intent(in) :: self
        qtimer_isActive = qtf_logical(qtf_qtimer_isActive(qtf_live(self, 'QTimer%isActive')))
    end function qtimer_isActive

    !> Fire only once per start (`.true.`) or repeatedly.
    subroutine qtimer_setSingleShot(self, singleShot)
        class(QTimer), intent(in) :: self
        logical, intent(in) :: singleShot
        call qtf_qtimer_setSingleShot(qtf_live(self, 'QTimer%setSingleShot'), qtf_int(singleShot))
    end subroutine qtimer_setSingleShot

    !> True if the timer fires only once per start.
    logical function qtimer_isSingleShot(self)
        class(QTimer), intent(in) :: self
        qtimer_isSingleShot = qtf_logical(qtf_qtimer_isSingleShot(qtf_live(self, 'QTimer%isSingleShot')))
    end function qtimer_isSingleShot

    !> Call `slot` once after `msec` milliseconds (QTimer::singleShot).
    subroutine QTimer_singleShot(msec, slot, data)
        integer, intent(in) :: msec
        procedure(qt_slot) :: slot
        class(*), intent(inout), target, optional :: data
        integer :: id
        id = new_slot(SLOT_VOID)
        slots(id)%void => slot
        if (present(data)) slots(id)%data => data
        call qtf_qtimer_singleShot(int(msec, c_int), int(id, c_int))
    end subroutine QTimer_singleShot

    ! ------------------------------------------------------------------
    ! QDateTime

    !> The current local date and time.
    function QDateTime_currentDateTime() result(t)
        type(QDateTime) :: t
        call qtf_qdatetime_current(t%year, t%month, t%day, t%hour, t%minute, t%second, t%msec)
    end function QDateTime_currentDateTime

    !> Parse a date-time with a Qt format, e.g. 'dd.MM.yyyy HH:mm' (ISO 8601,
    !> e.g. '2026-10-25T14:30:00', if `format` is absent); invalid if it does not parse.
    function QDateTime_fromString(text, format) result(t)
        character(len=*), intent(in) :: text
        character(len=*), intent(in), optional :: format
        type(QDateTime) :: t
        if (present(format)) then
            call qtf_qdatetime_fromString(text, len(text, c_int), format, len(format, c_int), t%year, t%month, &
                                          t%day, t%hour, t%minute, t%second, t%msec)
        else
            call qtf_qdatetime_fromString(text, len(text, c_int), '', 0_c_int, t%year, t%month, t%day, t%hour, &
                                          t%minute, t%second, t%msec)
        end if
    end function QDateTime_fromString

    !> The local date-time `msecs` milliseconds after 1970-01-01T00:00:00 UTC.
    function QDateTime_fromMSecsSinceEpoch(msecs) result(t)
        integer(c_long_long), intent(in) :: msecs
        type(QDateTime) :: t
        call qtf_qdatetime_fromMSecsSinceEpoch(msecs, t%year, t%month, t%day, t%hour, t%minute, t%second, t%msec)
    end function QDateTime_fromMSecsSinceEpoch

    !> True if the fields form a valid date and time.
    logical function qdatetime_isValid(self)
        class(QDateTime), intent(in) :: self
        qdatetime_isValid = qtf_logical(qtf_qdatetime_isValid(self%year, self%month, self%day, self%hour, &
                                                              self%minute, self%second, self%msec))
    end function qdatetime_isValid

    !> The date-time as text with a Qt format, e.g. 'yyyy-MM-dd HH:mm:ss' or
    !> 'ddd d MMM yyyy' (ISO 8601 with milliseconds if `format` is absent).
    function qdatetime_toString(self, format) result(text)
        class(QDateTime), intent(in) :: self
        character(len=*), intent(in), optional :: format
        character(len=:), allocatable :: text
        integer(c_int) :: n
        type(c_ptr) :: p
        if (present(format)) then
            p = qtf_qdatetime_toString(self%year, self%month, self%day, self%hour, self%minute, self%second, &
                                       self%msec, format, len(format, c_int), n)
        else
            p = qtf_qdatetime_toString(self%year, self%month, self%day, self%hour, self%minute, self%second, &
                                       self%msec, '', 0_c_int, n)
        end if
        text = qtf_take_string(p, n)
    end function qdatetime_toString

    !> Calendar arithmetic: the date-time moved by years, months, days, then milliseconds.
    function datetime_add(t, years, months, days, msecs) result(r)
        class(QDateTime), intent(in) :: t
        integer, intent(in) :: years, months, days
        integer(c_long_long), intent(in) :: msecs
        type(QDateTime) :: r
        call qtf_qdatetime_add(t%year, t%month, t%day, t%hour, t%minute, t%second, t%msec, int(years, c_int), &
                               int(months, c_int), int(days, c_int), msecs, r%year, r%month, r%day, r%hour, &
                               r%minute, r%second, r%msec)
    end function datetime_add

    !> The date-time `msecs` milliseconds later (earlier if negative).
    function qdatetime_addMSecs(self, msecs) result(r)
        class(QDateTime), intent(in) :: self
        integer(c_long_long), intent(in) :: msecs
        type(QDateTime) :: r
        r = datetime_add(self, 0, 0, 0, msecs)
    end function qdatetime_addMSecs

    !> The date-time `secs` seconds later (earlier if negative).
    function qdatetime_addSecs(self, secs) result(r)
        class(QDateTime), intent(in) :: self
        integer, intent(in) :: secs
        type(QDateTime) :: r
        r = datetime_add(self, 0, 0, 0, 1000_c_long_long * secs)
    end function qdatetime_addSecs

    !> The date-time `days` days later, at the same time of day.
    function qdatetime_addDays(self, days) result(r)
        class(QDateTime), intent(in) :: self
        integer, intent(in) :: days
        type(QDateTime) :: r
        r = datetime_add(self, 0, 0, days, 0_c_long_long)
    end function qdatetime_addDays

    !> The date-time `months` months later (the day is clamped to the month's length).
    function qdatetime_addMonths(self, months) result(r)
        class(QDateTime), intent(in) :: self
        integer, intent(in) :: months
        type(QDateTime) :: r
        r = datetime_add(self, 0, months, 0, 0_c_long_long)
    end function qdatetime_addMonths

    !> The date-time `years` years later.
    function qdatetime_addYears(self, years) result(r)
        class(QDateTime), intent(in) :: self
        integer, intent(in) :: years
        type(QDateTime) :: r
        r = datetime_add(self, years, 0, 0, 0_c_long_long)
    end function qdatetime_addYears

    !> Milliseconds since 1970-01-01T00:00:00 UTC.
    integer(c_long_long) function qdatetime_toMSecsSinceEpoch(self)
        class(QDateTime), intent(in) :: self
        qdatetime_toMSecsSinceEpoch = qtf_qdatetime_toMSecsSinceEpoch(self%year, self%month, self%day, self%hour, &
                                                                      self%minute, self%second, self%msec)
    end function qdatetime_toMSecsSinceEpoch

    !> Milliseconds from this date-time to `other` (negative if `other` is earlier).
    integer(c_long_long) function qdatetime_msecsTo(self, other)
        class(QDateTime), intent(in) :: self
        type(QDateTime), intent(in) :: other
        qdatetime_msecsTo = other%toMSecsSinceEpoch() - self%toMSecsSinceEpoch()
    end function qdatetime_msecsTo

    !> Whole seconds from this date-time to `other`.
    integer(c_long_long) function qdatetime_secsTo(self, other)
        class(QDateTime), intent(in) :: self
        type(QDateTime), intent(in) :: other
        qdatetime_secsTo = self%msecsTo(other) / 1000
    end function qdatetime_secsTo

    !> Calendar days from this date to `other`'s date.
    integer function qdatetime_daysTo(self, other)
        class(QDateTime), intent(in) :: self
        type(QDateTime), intent(in) :: other
        type(QDateTime) :: a, b
        a = QDateTime(self%year, self%month, self%day, 12)     ! noon: clear of DST changes
        b = QDateTime(other%year, other%month, other%day, 12)
        qdatetime_daysTo = int(nint(real(a%msecsTo(b), c_double) / 86400000.0_c_double))
    end function qdatetime_daysTo

    !> Day of the week: 1 (Monday) to 7 (Sunday); 0 if invalid.
    integer function qdatetime_dayOfWeek(self)
        class(QDateTime), intent(in) :: self
        qdatetime_dayOfWeek = qtf_qdatetime_dayOfWeek(self%year, self%month, self%day)
    end function qdatetime_dayOfWeek

    !> The date part.
    type(QDate) function qdatetime_date(self)
        class(QDateTime), intent(in) :: self
        qdatetime_date = QDate(self%year, self%month, self%day)
    end function qdatetime_date

    !> The time part (whole seconds).
    type(QTime) function qdatetime_time(self)
        class(QDateTime), intent(in) :: self
        qdatetime_time = QTime(self%hour, self%minute, self%second)
    end function qdatetime_time

    !> True if both are the same instant.
    logical function qdatetime_eq(a, b)
        class(QDateTime), intent(in) :: a, b
        qdatetime_eq = a%toMSecsSinceEpoch() == b%toMSecsSinceEpoch()
    end function qdatetime_eq

    !> True if they are different instants.
    logical function qdatetime_ne(a, b)
        class(QDateTime), intent(in) :: a, b
        qdatetime_ne = a%toMSecsSinceEpoch() /= b%toMSecsSinceEpoch()
    end function qdatetime_ne

    !> True if `a` is earlier than `b`.
    logical function qdatetime_lt(a, b)
        class(QDateTime), intent(in) :: a, b
        qdatetime_lt = a%toMSecsSinceEpoch() < b%toMSecsSinceEpoch()
    end function qdatetime_lt

    !> True if `a` is not later than `b`.
    logical function qdatetime_le(a, b)
        class(QDateTime), intent(in) :: a, b
        qdatetime_le = a%toMSecsSinceEpoch() <= b%toMSecsSinceEpoch()
    end function qdatetime_le

    !> True if `a` is later than `b`.
    logical function qdatetime_gt(a, b)
        class(QDateTime), intent(in) :: a, b
        qdatetime_gt = a%toMSecsSinceEpoch() > b%toMSecsSinceEpoch()
    end function qdatetime_gt

    !> True if `a` is not earlier than `b`.
    logical function qdatetime_ge(a, b)
        class(QDateTime), intent(in) :: a, b
        qdatetime_ge = a%toMSecsSinceEpoch() >= b%toMSecsSinceEpoch()
    end function qdatetime_ge

end module qt_core
