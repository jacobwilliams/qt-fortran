!> An external engine rendering into a Qt window from its own thread, the way
!> OpenFrames does: the host gives the engine C callbacks that make a
!> QOpenGLContext current on a plain QWindow and swap its buffers; the engine
!> calls them from its render thread. The window is embedded with
!> QWidget_createWindowContainer, and its events reach Fortran through a
!> QtfEventFilter. Needs a display (the offscreen platform has no OpenGL):
!> run with `pixi run test-gl`; it skips otherwise.
!>
!> Two ways, by platform:
!> * threaded OpenGL (Windows, Linux): the context is created and used on the
!>   render thread;
!> * otherwise (macOS, where AppKit must attach the context to the window on
!>   the main thread), as OpenFrames does: the context is created on the GUI
!>   thread, Qt_AA_DontCheckOpenGLContextThreadAffinity is set, and on every
!>   expose and resize the GUI thread pauses the engine and makes the context
!>   current once (makeCurrent + doneCurrent) before rendering resumes.
!> In both, the context is released after every frame (in the swap callback).
module test_render_thread_host

    use qt
    use iso_c_binding
    implicit none

    !> The callbacks an engine is given (as in openframes-fortran).
    abstract interface
        !> Make the GL context current for window `winid`.
        subroutine make_current_fn(winid, success) bind(C)
            import :: c_int, c_bool
            implicit none
            integer(c_int), intent(in) :: winid
            logical(c_bool), intent(out) :: success
        end subroutine make_current_fn
        !> Show the frame rendered into window `winid`.
        subroutine swap_buffers_fn(winid) bind(C)
            import :: c_int
            implicit none
            integer(c_int), intent(in) :: winid
        end subroutine swap_buffers_fn
    end interface

    integer, parameter :: nframes = 20

    !> The simulated engine: what it was given and what it saw. Only the
    !> render thread writes the "seen by the engine" fields.
    type :: engine_t
        type(c_funptr) :: make_current = c_null_funptr   !! host callbacks, as C function pointers
        type(c_funptr) :: swap_buffers = c_null_funptr
        type(QSignalInt) :: frameDone                     !! frame number, emitted from the render thread
        type(QThread) :: gui_thread
        ! seen by the engine
        integer :: frames = 0
        logical :: on_render_thread = .false., current_ok = .true., pixels_ok = .true.
        type(QColor) :: last_pixel
        ! seen on the GUI thread
        integer :: reports = 0
        logical :: reports_on_gui = .true.
    end type engine_t

    ! the host's window and context, used by the C callbacks (which, like
    ! OpenFrames' callbacks, only get a window id)
    type(QWindow), save :: host_window
    type(QOpenGLContext), save :: host_context
    logical, save :: gui_thread_updates = .false.   !! macOS: context updates on the GUI thread

    ! pausing the engine (GUI thread asks, render thread acknowledges)
    logical, volatile, save :: pause_request = .false., paused = .false.

    !> GUI-side state.
    type :: host_t
        type(QWidget) :: widget
        type(QThread) :: render_thread
        logical :: started = .false.
        integer :: exposes = 0, resizes = 0, width = 0, height = 0
        integer :: presses = 0, keys = 0
        real(c_double) :: x = -1, y = -1
    end type host_t

contains

    ! ------------------------------------------------------------------
    ! host callbacks (called on the render thread)

    !> Create the context on first use (on the render thread), then make it current.
    subroutine host_make_current(winid, success) bind(C)
        integer(c_int), intent(in) :: winid
        logical(c_bool), intent(out) :: success
        success = .false.
        if (host_context%isNull()) then
            host_context = QOpenGLContext()
            if (.not. host_context%create()) return
        end if
        success = logical(host_context%makeCurrent(host_window), c_bool)
    end subroutine host_make_current

    !> Show the frame, and release the context until the next one.
    subroutine host_swap_buffers(winid) bind(C)
        integer(c_int), intent(in) :: winid
        call host_context%swapBuffers(host_window)
        call host_context%doneCurrent()
    end subroutine host_swap_buffers

    ! ------------------------------------------------------------------
    ! the simulated engine (the work of the render thread)

    !> Render `nframes` frames through the host callbacks: clear to a color,
    !> read it back, swap. Releases the context at the end.
    subroutine engine_run(data)
        class(*), intent(inout), optional :: data
        procedure(make_current_fn), pointer :: make_current
        procedure(swap_buffers_fn), pointer :: swap_buffers
        type(QThread) :: me
        type(QColor) :: expected
        logical(c_bool) :: ok
        integer :: k
        select type (e => data)
        type is (engine_t)
            call c_f_procpointer(e%make_current, make_current)
            call c_f_procpointer(e%swap_buffers, swap_buffers)
            me = QThread_currentThread()
            e%on_render_thread = .not. c_associated(me%ptr, e%gui_thread%ptr)
            do k = 1, nframes
                if (QThread_isInterruptionRequested()) exit
                do while (pause_request)               ! the GUI thread is updating the context
                    paused = .true.
                    call QThread_msleep(1)
                end do
                paused = .false.
                call make_current(0_c_int, ok)
                if (.not. ok) then
                    e%current_ok = .false.
                    exit
                end if
                expected = QColor(51, 102, mod(10 * k, 256))
                call glClearColor(expected%r / 255.0_c_double, expected%g / 255.0_c_double, &
                                  expected%b / 255.0_c_double, 1.0_c_double)
                call glClear(GL_COLOR_BUFFER_BIT)
                e%last_pixel = glReadPixel(1, 1)
                e%pixels_ok = e%pixels_ok .and. e%last_pixel%r == expected%r .and. &
                              e%last_pixel%g == expected%g .and. e%last_pixel%b == expected%b
                call swap_buffers(0_c_int)
                e%frames = k
                call e%frameDone%emit(k)               ! queued to the GUI thread
                call QThread_msleep(5)
            end do
        end select
    end subroutine engine_run

    !> macOS: let AppKit attach the context to the window, on the GUI thread
    !> (the first time this creates the context), with the engine paused.
    subroutine update_context(h)
        type(host_t), intent(inout) :: h
        logical :: ok
        if (.not. gui_thread_updates .or. .not. host_window%isExposed()) return
        if (h%started) then
            pause_request = .true.
            do while (.not. paused .and. h%render_thread%isRunning())
                call QThread_msleep(1)
            end do
        end if
        if (host_context%isNull()) then
            host_context = QOpenGLContext()
            ok = host_context%create()
        end if
        if (host_context%makeCurrent(host_window)) call host_context%doneCurrent()
        pause_request = .false.
    end subroutine update_context

    ! ------------------------------------------------------------------
    ! GUI-thread slots

    !> The window was exposed: start rendering the first time (like ofwin_start).
    subroutine on_expose(data)
        class(*), intent(inout), optional :: data
        select type (h => data)
        type is (host_t)
            h%exposes = h%exposes + 1
            call update_context(h)
            if (host_window%isExposed() .and. .not. h%started) then
                h%started = .true.
                call h%render_thread%start()
            end if
        end select
    end subroutine on_expose

    !> Record the window size (an engine would get ofwin_resizewindow).
    subroutine on_resize(event, data)
        type(QResizeEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (h => data)
        type is (host_t)
            h%resizes = h%resizes + 1
            h%width = event%width()
            h%height = event%height()
            call update_context(h)
        end select
    end subroutine on_resize

    !> Forward a mouse press to the engine, and consume it.
    subroutine on_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (h => data)
        type is (host_t)
            h%presses = h%presses + 1
            h%x = event%x()
            h%y = event%y()
            call event%accept()
        end select
    end subroutine on_press

    !> Observe a key press without consuming it.
    subroutine on_key(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (h => data)
        type is (host_t)
            h%keys = h%keys + 1
        end select
    end subroutine on_key

    !> A frame was rendered (GUI thread).
    subroutine on_frame(k, data)
        integer, intent(in) :: k
        class(*), intent(inout), optional :: data
        type(QThread) :: here
        select type (e => data)
        type is (engine_t)
            here = QThread_currentThread()
            e%reports = e%reports + 1
            e%reports_on_gui = e%reports_on_gui .and. c_associated(here%ptr, e%gui_thread%ptr)
        end select
    end subroutine on_frame

    !> Resize the host while the engine renders.
    subroutine on_resize_now(data)
        class(*), intent(inout), optional :: data
        select type (h => data)
        type is (host_t)
            call h%widget%resize(300, 220)
        end select
    end subroutine on_resize_now

    !> The render thread finished, or time is up: leave the event loop.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

end module test_render_thread_host

!> Tests rendering from an external engine's thread into an embedded QWindow.
program test_render_thread

    use qt
    use testing
    use test_render_thread_host
    use iso_c_binding
    implicit none

    type(QApplication) :: app
    type(QOpenGLContext) :: probe
    type(QWidget) :: host_widget, container
    type(QVBoxLayout) :: layout
    type(QtfEventFilter) :: events
    type(QMouseEvent) :: me
    type(QKeyEvent) :: ke
    type(engine_t), target :: engine
    type(host_t), target :: host
    logical :: handled
    integer :: ierr

    app = QApplication()

    probe = QOpenGLContext()
    if (.not. probe%create()) then
        write(*,'(A)') 'test_render_thread: SKIP (no OpenGL on this platform)'
        stop
    end if
    call probe%delete()
    gui_thread_updates = .not. QOpenGLContext_supportsThreadedOpenGL()
    if (gui_thread_updates) then
        write(*,'(A)') 'info: no threaded OpenGL: context updates on the GUI thread (as on macOS)'
        call QApplication_setAttribute(Qt_AA_DontCheckOpenGLContextThreadAffinity)
    else
        write(*,'(A)') 'info: threaded OpenGL: the context is created on the render thread'
    end if

    ! --- host: a plain QWindow with an OpenGL surface, embedded among widgets
    host_window = QWindow()
    call host_window%setSurfaceType(QSurface_OpenGLSurface)
    call check(host_window%surfaceType() == QSurface_OpenGLSurface, 'QWindow surface type')
    host_widget = QWidget()
    host%widget = host_widget
    layout = QVBoxLayout(host_widget)
    container = QWidget_createWindowContainer(host_window)
    call layout%addWidget(container)
    call host_widget%resize(240, 180)
    events = QtfEventFilter(host_window)
    call events%exposeEvent%connect(on_expose, host)
    call events%resizeEvent%connect(on_resize, host)
    call events%mousePressEvent%connect(on_press, host)
    call events%keyPressEvent%connect(on_key, host)

    ! --- engine: callbacks handed over as C function pointers, its own thread
    engine%make_current = c_funloc(host_make_current)
    engine%swap_buffers = c_funloc(host_swap_buffers)
    engine%gui_thread = QThread_currentThread()
    engine%frameDone = QSignalInt(host_widget)
    call engine%frameDone%connect(on_frame, engine)
    host%render_thread = QThread_create(engine_run, engine, host_widget)
    call host%render_thread%finished%connect(on_quit)

    call QTimer_singleShot(10000, on_quit)       ! a time limit
    call QTimer_singleShot(60, on_resize_now, host)   ! a resize while the engine renders
    call host_widget%show()                      ! exposing the window starts the engine
    ierr = app%exec()

    call check(host%exposes >= 1 .and. host%started, 'exposeEvent starts the engine')
    call check(host%resizes >= 2 .and. host%width > 240 .and. host%height > 0, 'resizeEvent of the window (also while rendering)')
    call check(host_window%devicePixelRatio() >= 1.0_c_double, 'devicePixelRatio')
    call check(engine%on_render_thread, 'the engine ran on its own thread')
    call check(engine%current_ok, 'makeCurrent from the render thread')
    call check(engine%frames == nframes, 'all frames rendered')
    call check(engine%pixels_ok, 'each frame cleared to its color (read back on the render thread)')
    call check(engine%reports == nframes .and. engine%reports_on_gui, 'frame reports delivered on the GUI thread')
    call check(.not. host%render_thread%isRunning(), 'engine finished')
    call host_context%delete()

    ! --- input reaches the host through the event filter
    me = QMouseEvent(QEvent_MouseButtonPress, 12.0_c_double, 34.0_c_double, Qt_LeftButton)
    handled = QCoreApplication_sendEvent(host_window, me)
    call check(host%presses == 1 .and. host%x == 12.0_c_double .and. host%y == 34.0_c_double, 'mouse press forwarded')
    call check(me%isAccepted(), 'accepted in the slot: consumed')
    call me%delete()
    ke = QKeyEvent(QEvent_KeyPress, Qt_Key_A)
    handled = QCoreApplication_sendEvent(host_window, ke)
    call check(host%keys == 1 .and. .not. ke%isAccepted(), 'key observed, not consumed (the window ignored it)')
    call ke%delete()

    ! --- teardown: the window and filter go with the container's parent
    call host_widget%delete()
    call check(host_window%isNull() .and. events%isNull() .and. container%isNull(), 'window, filter, container deleted')

    write(*,'(A)') 'test_render_thread: all checks passed'

end program test_render_thread
