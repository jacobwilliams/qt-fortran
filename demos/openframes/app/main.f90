!> OpenFrames in a qt-fortran GUI: a spacecraft orbiting the Earth, rendered by
!> OpenFrames (OpenSceneGraph) from its own render thread into a QWindow that
!> is embedded in a QMainWindow, next to a dock of qt-fortran controls.
!>
!> How the pieces fit (the qt-fortran counterpart of OpenFrames' PySide
!> integration, OFInterfaces/PyQtOFInterfaceC.py and PyQtOF.py):
!>
!> * The host owns a plain QWindow (OpenGL surface) and a QOpenGLContext.
!>   OpenFrames gets two C callbacks, `make_current` and `swap_buffers`, which
!>   its render thread calls every frame.
!> * A QtfEventFilter forwards the window's events: the first expose starts
!>   OpenFrames, resizes go to ofwin_resizewindow, mouse and keys to its
!>   trackball (coordinates in physical pixels).
!> * Where Qt reports no threaded OpenGL (macOS), AppKit must attach the
!>   context to the window on the main thread: the context is created on the
!>   GUI thread, Qt_AA_DontCheckOpenGLContextThreadAffinity is set, and at each
!>   expose and resize the GUI thread pauses OpenFrames (ofwin_pauseanimation
!>   waits for the render thread) and does makeCurrent + doneCurrent.
!>
!> Run with `pixi run run`. Options: `--capture name` saves a rendered frame
!> (name_0_0.png) after a few seconds, `--quit-after seconds` closes the demo,
!> `--view spacecraft` starts with the spacecraft view.
module ofdemo

    use qt
    use openframes_module
    use iso_c_binding
    use iso_fortran_env, only: real32, real64, int32
    implicit none

    integer(int32), parameter :: winid = 1              !! the OpenFrames window proxy
    real(real64), parameter :: pi = acos(-1.0_real64)
    real(real64), parameter :: mu = 398600.4418_real64  !! Earth's gravitational parameter (km^3/s^2)
    real(real64), parameter :: earth_radius = 6378.137_real64

    ! used by the C callbacks, which (as OpenFrames calls them) only get a window id
    type(QWindow), save :: window
    type(QOpenGLContext), save :: context
    logical, save :: gui_thread_updates = .false.       !! macOS: context updates on the GUI thread
    logical, save :: started = .false.                  !! OpenFrames' render thread is running

    !> The GUI.
    type :: app_t
        type(QMainWindow) :: main
        type(QWidget) :: container
        type(QtfEventFilter) :: events
        type(QDoubleSpinBox) :: time_scale
        type(QCheckBox) :: pause_time
        type(QComboBox) :: view
        type(QLabel) :: clock
        type(QTimer) :: timer
        character(len=:), allocatable :: capture
        real(real64) :: quit_after = -1
        integer :: start_view = 0
    end type app_t

contains

    ! ==================================================================
    ! OpenFrames' graphics callbacks (called on its render thread)

    !> Make the context current on the window (creating it on first use, unless
    !> the GUI thread has already created it).
    subroutine make_current(id, success) bind(C)
        integer(c_int), intent(in) :: id
        logical(c_bool), intent(out) :: success
        success = .false.
        if (context%isNull()) then
            context = QOpenGLContext()
            if (.not. context%create()) return
        end if
        success = logical(context%makeCurrent(window), c_bool)
    end subroutine make_current

    !> Show the frame.
    subroutine swap_buffers(id) bind(C)
        integer(c_int), intent(in) :: id
        call context%swapBuffers(window)
    end subroutine swap_buffers

    !> macOS: let AppKit attach the context to the window, on the GUI thread
    !> with OpenFrames paused (the first time, this creates the context).
    subroutine update_context()
        logical :: ok
        if (.not. gui_thread_updates .or. .not. window%isExposed()) return
        call ofwin_activate(winid)
        if (started) call ofwin_pauseanimation(.true.)     ! returns once the render thread is paused
        if (context%isNull()) then
            context = QOpenGLContext()
            ok = context%create()
        end if
        if (context%makeCurrent(window)) call context%doneCurrent()
        if (started) call ofwin_pauseanimation(.false.)
    end subroutine update_context

    ! ==================================================================
    ! the scene

    !> Position on an elliptical orbit at time t (Kepler's equation by Newton
    !> iteration), in km, with the given semi-major axis, eccentricity and inclination.
    function orbit_position(t, a, e, inc) result(r)
        real(real64), intent(in) :: t, a, e, inc
        real(real64) :: r(3)
        real(real64) :: m, ea, x, y
        integer :: k
        m = sqrt(mu / a**3) * t
        ea = m
        do k = 1, 20
            ea = ea - (ea - e * sin(ea) - m) / (1 - e * cos(ea))
        end do
        x = a * (cos(ea) - e)
        y = a * sqrt(1 - e**2) * sin(ea)
        r = [x, y * cos(inc), y * sin(inc)]
    end function orbit_position

    !> Build the scene: Earth with an orbit and a spacecraft that follows it,
    !> stars, and two views.
    subroutine build_scene(data_dir)
        character(len=*), intent(in) :: data_dir   !! OpenFrames' Demos folder ('' if unknown)
        real(real64), parameter :: a = 9000.0_real64, e = 0.2_real64, inc = 35 * pi / 180
        real(real64) :: period, t, r(3), size
        integer :: k
        integer, parameter :: n = 360

        if (data_dir /= '') call of_adddatafilepath(data_dir)

        ! the Earth (the root frame)
        call ofsphere_create('Earth')
        call ofsphere_setradius(earth_radius)
        if (data_dir /= '') call ofsphere_settexturemap('Images/EarthTexture.bmp')
        call offrame_showaxes(of_noaxes)
        call offrame_showaxeslabels(of_noaxes)
        call offrame_shownamelabel(.false.)

        ! the orbit: one period of positions, drawn as a curve
        period = 2 * pi * sqrt(a**3 / mu)
        call oftraj_create('Orbit', 3, 0)
        do k = 0, n
            t = period * k / n
            r = orbit_position(t, a, e, inc)
            call oftraj_addtime(t)
            call oftraj_addposition(r(1), r(2), r(3))
        end do
        call ofcurveartist_create('OrbitLine')
        call oftrajartist_settrajectory()
        ! (an artist made through the C interface has no data sources yet: plot x, y, z positions)
        call ofcurveartist_setxdata(of_posopt, of_x, 0, 1.0_real64)
        call ofcurveartist_setydata(of_posopt, of_y, 0, 1.0_real64)
        call ofcurveartist_setzdata(of_posopt, of_z, 0, 1.0_real64)
        call ofcurveartist_setcolor(1.0_real32, 0.75_real32, 0.2_real32)
        call ofcurveartist_setwidth(2.0_real32)
        call ofdrawtraj_create('OrbitDrawing')
        call ofdrawtraj_addartist('OrbitLine')
        call offrame_showaxes(of_noaxes)
        call offrame_shownamelabel(.false.)

        ! the spacecraft follows the orbit
        if (data_dir /= '') then
            call ofmodel_create('Spacecraft')
            call ofmodel_setmodel('Models/Hubble.3ds')
            call ofmodel_getmodelsize(size)               ! show it about 600 km across
            if (size > 0) call ofmodel_setmodelscale(600 / size, 600 / size, 600 / size)
        else
            call ofsphere_create('Spacecraft')
            call ofsphere_setradius(150.0_real64)
        end if
        call offrame_followtrajectory('Orbit')
        call offrame_followtype(offollow_position, offollow_loop)
        call offrame_showaxes(of_noaxes)
        call offrame_showaxeslabels(of_noaxes)

        call offrame_activate('Earth')
        call offrame_addchild('OrbitDrawing')
        call offrame_addchild('Spacecraft')

        ! the window: scene, background, time
        call offm_create(1)
        call offrame_activate('Earth')
        call offm_setframe()
        call ofwin_activate(winid)
        call ofwin_setscene(0, 0)
        call ofwin_setbackgroundcolor(0, 0, 0.0_real32, 0.0_real32, 0.02_real32)
        if (data_dir /= '') call ofwin_setbackgroundstardata(0, 0, -2.0_real32, 6.5_real32, 'Stars/Stars_HYGv3.txt')
        call ofwin_settimescale(200.0_real64)

        ! views: looking at the Earth, and riding with the spacecraft
        call ofview_create('EarthView')
        call ofview_setviewframe('Earth', 'Earth')
        call ofview_setdefaultviewdistance(30000.0_real64)
        call ofwin_addview(0, 0)
        call ofview_create('SpacecraftView')
        call ofview_setviewframe('Earth', 'Spacecraft')
        call ofview_setdefaultviewdistance(2500.0_real64)
        call ofwin_addview(0, 0)
        call ofview_activate('EarthView')
        call ofwin_selectview(0, 0)
    end subroutine build_scene

    ! ==================================================================
    ! window events (GUI thread)

    !> The window was exposed or hidden: start OpenFrames the first time.
    subroutine on_expose(data)
        class(*), intent(inout), optional :: data
        call update_context()
        if (window%isExposed() .and. .not. started) then
            started = .true.
            call ofwin_activate(winid)
            call ofwin_start()
        end if
    end subroutine on_expose

    !> Tell OpenFrames the new size (in physical pixels).
    subroutine on_resize(event, data)
        type(QResizeEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        real(c_double) :: dpr
        call update_context()
        dpr = window%devicePixelRatio()
        call ofwin_activate(winid)
        call ofwin_resizewindow(0, 0, int(event%width() * dpr, int32), int(event%height() * dpr, int32))
    end subroutine on_resize

    !> OpenFrames' mouse button numbers: 1 left, 2 middle, 3 right (0: other).
    integer(int32) function of_button(qt_button)
        integer, intent(in) :: qt_button
        select case (qt_button)
        case (Qt_LeftButton)
            of_button = 1
        case (Qt_MiddleButton)
            of_button = 2
        case (Qt_RightButton)
            of_button = 3
        case default
            of_button = 0
        end select
    end function of_button

    !> Mouse press: to OpenFrames' trackball (left: rotate, right: zoom, middle: pan).
    subroutine on_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        real(real32) :: dpr
        if (of_button(event%button()) == 0) return
        dpr = real(window%devicePixelRatio(), real32)
        call ofwin_activate(winid)
        call ofwin_buttonpress(real(event%x(), real32) * dpr, real(event%y(), real32) * dpr, of_button(event%button()))
        call event%accept()
    end subroutine on_press

    !> Mouse release.
    subroutine on_release(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        real(real32) :: dpr
        if (of_button(event%button()) == 0) return
        dpr = real(window%devicePixelRatio(), real32)
        call ofwin_activate(winid)
        call ofwin_buttonrelease(real(event%x(), real32) * dpr, real(event%y(), real32) * dpr, of_button(event%button()))
        call event%accept()
    end subroutine on_release

    !> Mouse motion.
    subroutine on_move(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        real(real32) :: dpr
        dpr = real(window%devicePixelRatio(), real32)
        call ofwin_activate(winid)
        call ofwin_mousemotion(real(event%x(), real32) * dpr, real(event%y(), real32) * dpr)
        call event%accept()
    end subroutine on_move

    !> Keys: letters as OpenSceneGraph expects them (lower case unless Shift).
    subroutine on_key(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        integer(int32) :: key
        key = event%key()
        if (key >= Qt_Key_A .and. key <= Qt_Key_Z .and. iand(event%modifiers(), Qt_ShiftModifier) == 0) &
            key = key + 32
        call ofwin_activate(winid)
        call ofwin_keypress(key)
        call event%accept()
    end subroutine on_key

    ! ==================================================================
    ! controls (GUI thread)

    !> Simulation time scale.
    subroutine on_time_scale(value, data)
        real(c_double), intent(in) :: value
        class(*), intent(inout), optional :: data
        call ofwin_activate(winid)
        call ofwin_settimescale(value)
    end subroutine on_time_scale

    !> Pause or resume the simulation time.
    subroutine on_pause_time(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        call ofwin_activate(winid)
        call ofwin_pausetime(checked)
    end subroutine on_pause_time

    !> Show the chosen view.
    subroutine on_view(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        call ofwin_activate(winid)
        call ofview_activate(merge('EarthView     ', 'SpacecraftView', index == 0))
        call ofwin_selectview(0, 0)
    end subroutine on_view

    !> Reset the current view (trackball) to its default.
    subroutine on_reset_view(data)
        class(*), intent(inout), optional :: data
        select type (a => data)
        type is (app_t)
            call ofwin_activate(winid)
            call ofview_activate(merge('EarthView     ', 'SpacecraftView', a%view%currentIndex() == 0))
            call ofview_reset()
        end select
    end subroutine on_reset_view

    !> Show the simulation time.
    subroutine on_tick(data)
        class(*), intent(inout), optional :: data
        real(real64) :: t
        character(len=40) :: text
        select type (a => data)
        type is (app_t)
            call ofwin_activate(winid)
            call ofwin_gettime(t)
            write(text, '(A,F10.1,A)') 'Simulation time: ', t, ' s'
            call a%clock%setText(trim(text))
        end select
    end subroutine on_tick

    !> --capture: save the next rendered frame (OpenFrames writes it).
    subroutine on_capture(data)
        class(*), intent(inout), optional :: data
        select type (a => data)
        type is (app_t)
            call ofwin_activate(winid)
            call ofwin_setwindowcapturefile(a%capture, 'png')
            call ofwin_capturewindow()
        end select
    end subroutine on_capture

    !> --quit-after: close the main window.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        select type (a => data)
        type is (app_t)
            call a%main%close()
        end select
    end subroutine on_quit

    !> The main window closes: stop OpenFrames' render thread before Qt goes away.
    subroutine on_close(event, data)
        type(QCloseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        integer(int32) :: running
        if (.not. started) return
        call ofwin_activate(winid)
        call ofwin_stop()
        do
            call ofwin_isrunning(running)
            if (running == 0) exit
            call QApplication_processEvents()
            call QThread_msleep(10)
        end do
        started = .false.
    end subroutine on_close

    ! ==================================================================
    ! construction

    !> The main window: OpenFrames in the center, controls in a dock.
    subroutine build_ui(a)
        type(app_t), intent(inout), target :: a
        type(QDockWidget) :: dock
        type(QWidget) :: panel
        type(QFormLayout) :: form
        type(QPushButton) :: reset

        a%main = QMainWindow()
        call a%main%setWindowTitle('OpenFrames in qt-fortran')

        window = QWindow()
        call window%setSurfaceType(QSurface_OpenGLSurface)
        a%container = QWidget_createWindowContainer(window)
        call a%container%setMinimumSize(320, 240)
        call a%main%setCentralWidget(a%container)

        a%events = QtfEventFilter(window)
        call a%events%exposeEvent%connect(on_expose)
        call a%events%resizeEvent%connect(on_resize)
        call a%events%mousePressEvent%connect(on_press)
        call a%events%mouseReleaseEvent%connect(on_release)
        call a%events%mouseMoveEvent%connect(on_move)
        call a%events%keyPressEvent%connect(on_key)
        call a%main%closeEvent%connect(on_close)

        ! controls
        panel = QWidget()
        form = QFormLayout(panel)
        a%time_scale = QDoubleSpinBox()
        call a%time_scale%setRange(1.0_c_double, 5000.0_c_double)
        call a%time_scale%setValue(200.0_c_double)
        call a%time_scale%setSuffix(' x')
        call a%time_scale%valueChanged%connect(on_time_scale)
        call form%addRow('Time scale', a%time_scale)
        a%pause_time = QCheckBox('Pause time')
        call a%pause_time%toggled%connect(on_pause_time)
        call form%addRow('', a%pause_time)
        a%view = QComboBox()
        call a%view%addItems([character(len=10) :: 'Earth', 'Spacecraft'])
        call a%view%currentIndexChanged%connect(on_view)
        call form%addRow('View', a%view)
        reset = QPushButton('Reset view')
        call reset%clicked%connect(on_reset_view, a)
        call form%addRow('', reset)
        a%clock = QLabel('Simulation time:')
        call form%addRow(a%clock)
        call form%addRow(QLabel('<small>Left drag: rotate<br>Right drag: zoom<br>Middle drag: pan</small>'))
        dock = QDockWidget('Controls', a%main)
        call dock%setWidget(panel)
        call a%main%addDockWidget(Qt_LeftDockWidgetArea, dock)

        a%timer = QTimer(a%main)
        call a%timer%timeout%connect(on_tick, a)
        call a%timer%start(200)
    end subroutine build_ui

end module ofdemo

!> OpenFrames in a qt-fortran GUI (see the module documentation).
program openframes_demo

    use qt
    use openframes_module
    use ofdemo
    implicit none

    type(QApplication) :: app
    type(QSurfaceFormat) :: fmt
    type(app_t), target :: a
    character(len=1024) :: arg, data_dir
    integer :: i, ierr, status

    ! depth buffer and multisampling for every OpenGL surface (before the application)
    fmt = QSurfaceFormat()
    call fmt%setDepthBufferSize(24)
    call fmt%setSamples(4)
    call QSurfaceFormat_setDefaultFormat(fmt)
    call fmt%delete()

    app = QApplication()
    gui_thread_updates = .not. QOpenGLContext_supportsThreadedOpenGL()
    if (gui_thread_updates) call QApplication_setAttribute(Qt_AA_DontCheckOpenGLContextThreadAffinity)

    i = 1
    do while (i <= command_argument_count())
        call get_command_argument(i, arg)
        select case (arg)
        case ('--capture')
            call get_command_argument(i + 1, arg)
            a%capture = trim(arg)
            i = i + 1
        case ('--view')
            call get_command_argument(i + 1, arg)
            if (arg == 'spacecraft') a%start_view = 1
            i = i + 1
        case ('--quit-after')
            call get_command_argument(i + 1, arg)
            read(arg, *) a%quit_after
            i = i + 1
        end select
        i = i + 1
    end do

    ! OpenFrames: an embedded window proxy (we supply the OpenGL context)
    call of_initialize()
    call ofwin_createproxy(0, 0, 1024, 768, 1, 1, .true., winid, .false.)
    call ofwin_setmakecurrentfunction(make_current)
    call ofwin_setswapbuffersfunction(swap_buffers)
    call get_environment_variable('OPENFRAMES_DATA', data_dir, status=status)
    if (status /= 0) data_dir = ''
    call build_scene(trim(data_dir))

    call build_ui(a)
    call a%view%setCurrentIndex(a%start_view)
    if (allocated(a%capture)) call QTimer_singleShot(3000, on_capture, a)
    if (a%quit_after > 0) call QTimer_singleShot(int(1000 * a%quit_after), on_quit, a)
    call a%main%resize(1100, 700)
    call a%main%show()
    ierr = app%exec()
    call of_cleanup()

end program openframes_demo
