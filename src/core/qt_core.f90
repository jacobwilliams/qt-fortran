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
            class(*), intent(inout), optional :: data
        end subroutine qt_slot
        !> Slot for signals with a single string argument.
        subroutine qt_slot_string(value, data)
            character(len=*), intent(in) :: value
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_string
        !> Slot for signals with a single logical argument.
        subroutine qt_slot_bool(value, data)
            logical, intent(in) :: value
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_bool
        !> Slot for signals with a single integer argument.
        subroutine qt_slot_int(value, data)
            integer, intent(in) :: value
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_int
        !> Slot for signals with a single real argument.
        subroutine qt_slot_double(value, data)
            import :: c_double
            real(c_double), intent(in) :: value
            class(*), intent(inout), optional :: data
        end subroutine qt_slot_double
    end interface
    public :: qt_slot, qt_slot_string, qt_slot_bool, qt_slot_int, qt_slot_double

    !> Base for slot kinds defined outside this module (e.g. event and painter
    !> slots in qt_gui). An extension stores a typed procedure pointer and
    !> converts the raw `qtf_args` in `invoke`.
    type, abstract, public :: qt_slot_handler
    contains
        procedure(qt_handler_invoke), deferred :: invoke
    end type qt_slot_handler

    abstract interface
        subroutine qt_handler_invoke(self, args, data)
            import :: qt_slot_handler, qtf_args
            class(qt_slot_handler), intent(in) :: self
            type(qtf_args), intent(in) :: args
            class(*), pointer, intent(in) :: data   !! null if no data was given
        end subroutine qt_handler_invoke
    end interface

    !> A signal without arguments.
    type, public :: QSignal
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignal_connect
    end type QSignal

    !> A signal with a single string argument.
    type, public :: QSignalString
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignalstring_connect
    end type QSignalString

    !> A signal with a single logical argument.
    type, public :: QSignalBool
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignalbool_connect
    end type QSignalBool

    !> A signal with a single integer argument.
    type, public :: QSignalInt
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignalint_connect
    end type QSignalInt

    !> A signal with a single real argument.
    type, public :: QSignalDouble
        type(c_ptr) :: sender = c_null_ptr
        integer(c_int) :: id = 0
    contains
        procedure :: connect => qsignaldouble_connect
    end type QSignalDouble

    type, public :: QObject
        type(c_ptr) :: ptr = c_null_ptr
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
    end type QObject
    interface QObject
        module procedure :: qobject_new
    end interface QObject

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

    public :: QTimer_singleShot, QCoreApplication_sendEvent
    public :: qtf_ptr, qt_slot_count, qt_connect_handler

    ! ------------------------------------------------------------------
    ! slot registry: the shim refers to Fortran slots by index into `slots`

    integer, parameter :: SLOT_VOID = 1, SLOT_STRING = 2, SLOT_BOOL = 3, SLOT_INT = 4, SLOT_DOUBLE = 5, &
                          SLOT_HANDLER = 6

    type :: slot_entry
        integer :: kind = 0     !! 0 = free
        procedure(qt_slot), pointer, nopass :: void => null()
        procedure(qt_slot_string), pointer, nopass :: string => null()
        procedure(qt_slot_bool), pointer, nopass :: bool => null()
        procedure(qt_slot_int), pointer, nopass :: int => null()
        procedure(qt_slot_double), pointer, nopass :: double => null()
        class(qt_slot_handler), allocatable :: handler
        class(*), pointer :: data => null()
    end type slot_entry

    type(slot_entry), allocatable, save :: slots(:)
    integer, save :: nslots = 0     !! number of slots in use
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
    subroutine connect_slot(sender, signal, id)
        type(c_ptr), intent(in) :: sender
        integer(c_int), intent(in) :: signal
        integer, intent(in) :: id
        ! on failure the shim has already released the slot
        if (qtf_connect(sender, signal, int(id, c_int)) == 0) &
            error stop 'qt: failed to connect signal (null or unsupported sender)'
    end subroutine connect_slot

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

    subroutine qsignal_connect(self, slot, data)
        class(QSignal), intent(in) :: self
        procedure(qt_slot) :: slot
        class(*), intent(inout), target, optional :: data
        integer :: id
        id = new_slot(SLOT_VOID)
        slots(id)%void => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self%sender, self%id, id)
    end subroutine qsignal_connect

    subroutine qsignalstring_connect(self, slot, data)
        class(QSignalString), intent(in) :: self
        procedure(qt_slot_string) :: slot
        class(*), intent(inout), target, optional :: data
        integer :: id
        id = new_slot(SLOT_STRING)
        slots(id)%string => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self%sender, self%id, id)
    end subroutine qsignalstring_connect

    subroutine qsignalbool_connect(self, slot, data)
        class(QSignalBool), intent(in) :: self
        procedure(qt_slot_bool) :: slot
        class(*), intent(inout), target, optional :: data
        integer :: id
        id = new_slot(SLOT_BOOL)
        slots(id)%bool => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self%sender, self%id, id)
    end subroutine qsignalbool_connect

    subroutine qsignalint_connect(self, slot, data)
        class(QSignalInt), intent(in) :: self
        procedure(qt_slot_int) :: slot
        class(*), intent(inout), target, optional :: data
        integer :: id
        id = new_slot(SLOT_INT)
        slots(id)%int => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self%sender, self%id, id)
    end subroutine qsignalint_connect

    subroutine qsignaldouble_connect(self, slot, data)
        class(QSignalDouble), intent(in) :: self
        procedure(qt_slot_double) :: slot
        class(*), intent(inout), target, optional :: data
        integer :: id
        id = new_slot(SLOT_DOUBLE)
        slots(id)%double => slot
        if (present(data)) slots(id)%data => data
        call connect_slot(self%sender, self%id, id)
    end subroutine qsignaldouble_connect

    !> Connect `signal` of `sender` to a handler (a slot kind defined outside
    !> this module). The handler is copied.
    subroutine qt_connect_handler(sender, signal, handler, data)
        type(c_ptr), intent(in) :: sender
        integer(c_int), intent(in) :: signal
        class(qt_slot_handler), intent(in) :: handler
        class(*), intent(inout), target, optional :: data
        integer :: id
        id = new_slot(SLOT_HANDLER)
        allocate(slots(id)%handler, source=handler)
        if (present(data)) slots(id)%data => data
        call connect_slot(sender, signal, id)
    end subroutine qt_connect_handler

    ! ------------------------------------------------------------------
    ! QEvent

    integer function qevent_type(self)
        class(QEvent), intent(in) :: self
        qevent_type = qtf_qevent_type(self%ptr)
    end function qevent_type

    subroutine qevent_accept(self)
        class(QEvent), intent(in) :: self
        call qtf_qevent_accept(self%ptr)
    end subroutine qevent_accept

    subroutine qevent_ignore(self)
        class(QEvent), intent(in) :: self
        call qtf_qevent_ignore(self%ptr)
    end subroutine qevent_ignore

    logical function qevent_isAccepted(self)
        class(QEvent), intent(in) :: self
        qevent_isAccepted = qtf_logical(qtf_qevent_isAccepted(self%ptr))
    end function qevent_isAccepted

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

    !> Handle of an optional object (null when absent), e.g. for `parent` arguments.
    type(c_ptr) function qtf_ptr(obj)
        class(QObject), intent(in), optional :: obj
        qtf_ptr = c_null_ptr
        if (present(obj)) qtf_ptr = obj%ptr
    end function qtf_ptr

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
        self%destroyed = QSignal(ptr, QTF_SIG_QOBJECT_DESTROYED)
        self%objectNameChanged = QSignalString(ptr, QTF_SIG_QOBJECT_OBJECTNAMECHANGED)
    end subroutine qobject_attach

    logical function qobject_isNull(self)
        class(QObject), intent(in) :: self
        qobject_isNull = .not. c_associated(self%ptr)
    end function qobject_isNull

    !> Delete the object now (its children are deleted by Qt) and null the handle.
    subroutine qobject_delete(self)
        class(QObject), intent(inout) :: self
        if (c_associated(self%ptr)) call qtf_qobject_delete(self%ptr)
        call self%attach(c_null_ptr)
    end subroutine qobject_delete

    !> Schedule deletion when control returns to the event loop.
    subroutine qobject_deleteLater(self)
        class(QObject), intent(in) :: self
        call qtf_qobject_deleteLater(self%ptr)
    end subroutine qobject_deleteLater

    function qobject_objectName(self) result(name)
        class(QObject), intent(in) :: self
        character(len=:), allocatable :: name
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qobject_objectName(self%ptr, n)
        name = qtf_take_string(p, n)
    end function qobject_objectName

    subroutine qobject_setObjectName(self, name)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: name
        call qtf_qobject_setObjectName(self%ptr, name, len(name, c_int))
    end subroutine qobject_setObjectName

    !> Set the parent (which then owns this object); no argument clears it.
    subroutine qobject_setParent(self, parent)
        class(QObject), intent(in) :: self
        class(QObject), intent(in), optional :: parent
        call qtf_qobject_setParent(self%ptr, qtf_ptr(parent))
    end subroutine qobject_setParent

    function qobject_parent(self) result(parent)
        class(QObject), intent(in) :: self
        type(QObject) :: parent
        call parent%attach(qtf_qobject_parent(self%ptr))
    end function qobject_parent

    !> Name of the object's most derived Qt class, e.g. "QTimer".
    function qobject_className(self) result(name)
        class(QObject), intent(in) :: self
        character(len=:), allocatable :: name
        integer(c_int) :: n
        type(c_ptr) :: p
        p = qtf_qobject_className(self%ptr, n)
        name = qtf_take_string(p, n)
    end function qobject_className

    logical function qobject_inherits(self, className)
        class(QObject), intent(in) :: self
        character(len=*), intent(in) :: className
        qobject_inherits = qtf_logical(qtf_qobject_inherits(self%ptr, className, len(className, c_int)))
    end function qobject_inherits

    ! ------------------------------------------------------------------
    ! QTimer

    function qtimer_new(parent) result(t)
        class(QObject), intent(in), optional :: parent
        type(QTimer) :: t
        call t%attach(qtf_qtimer_new(qtf_ptr(parent)))
    end function qtimer_new

    subroutine qtimer_attach(self, ptr)
        class(QTimer), intent(inout) :: self
        type(c_ptr), intent(in) :: ptr
        call self%QObject%attach(ptr)
        self%timeout = QSignal(ptr, QTF_SIG_QTIMER_TIMEOUT)
    end subroutine qtimer_attach

    !> Start (or restart) the timer, optionally setting the interval in ms.
    subroutine qtimer_start(self, msec)
        class(QTimer), intent(in) :: self
        integer, intent(in), optional :: msec
        integer(c_int) :: m
        m = -1
        if (present(msec)) m = int(msec, c_int)
        call qtf_qtimer_start(self%ptr, m)
    end subroutine qtimer_start

    subroutine qtimer_stop(self)
        class(QTimer), intent(in) :: self
        call qtf_qtimer_stop(self%ptr)
    end subroutine qtimer_stop

    subroutine qtimer_setInterval(self, msec)
        class(QTimer), intent(in) :: self
        integer, intent(in) :: msec
        call qtf_qtimer_setInterval(self%ptr, int(msec, c_int))
    end subroutine qtimer_setInterval

    integer function qtimer_interval(self)
        class(QTimer), intent(in) :: self
        qtimer_interval = qtf_qtimer_interval(self%ptr)
    end function qtimer_interval

    logical function qtimer_isActive(self)
        class(QTimer), intent(in) :: self
        qtimer_isActive = qtf_logical(qtf_qtimer_isActive(self%ptr))
    end function qtimer_isActive

    subroutine qtimer_setSingleShot(self, singleShot)
        class(QTimer), intent(in) :: self
        logical, intent(in) :: singleShot
        call qtf_qtimer_setSingleShot(self%ptr, qtf_int(singleShot))
    end subroutine qtimer_setSingleShot

    logical function qtimer_isSingleShot(self)
        class(QTimer), intent(in) :: self
        qtimer_isSingleShot = qtf_logical(qtf_qtimer_isSingleShot(self%ptr))
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

end module qt_core
