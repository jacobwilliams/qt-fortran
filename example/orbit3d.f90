!> Spacecraft orbit visualizer: a two-body (Kepler) propagator with an OpenGL
!> 3D view and a settings side panel.
!>
!> * Side panel: presets (ISS, GPS, Molniya, ...), the six classical orbital
!>   elements, the central body (Earth, Moon, Mars), the simulation clock with a
!>   logarithmic time warp, display options, and live readouts (period,
!>   altitudes, speed, ...).
!> * 3D view: the rotating central body with a day/night side, the orbit, the
!>   spacecraft with its velocity vector, periapsis/apoapsis markers, the line of
!>   nodes, an equatorial grid and the inertial axes. Drag to orbit the camera,
!>   wheel to zoom; Space plays/pauses, +/- change the time warp.
!>
!> `orbit3d --screenshot out.png` runs a Molniya orbit for a moment, saves the
!> whole window and exits (needs a display with OpenGL 3.3).
module orbit3d_app

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    real(dp), parameter :: pi = acos(-1.0_dp)
    real(dp), parameter :: deg = pi / 180            !! degrees to radians
    real(dp), parameter :: scale = 1.0e-3_dp         !! scene units are 1000 km
    integer, parameter :: floats_per_vertex = 9      !! position(3), normal(3), color(3)
    integer, parameter :: stride = floats_per_vertex * 4
    integer, parameter :: orbit_points = 721

    !> A central body.
    type :: body_t
        character(len=8) :: name
        real(dp) :: mu        !! gravitational parameter [km^3/s^2]
        real(dp) :: radius    !! equatorial radius [km]
        real(dp) :: rotation  !! sidereal rotation rate [deg/s]
    end type body_t

    type(body_t), parameter :: bodies(3) = [ &
        body_t('Earth', 398600.4418_dp, 6378.137_dp, 360.0_dp / 86164.0905_dp), &
        body_t('Moon', 4902.800066_dp, 1737.4_dp, 360.0_dp / (27.321661_dp * 86400)), &
        body_t('Mars', 42828.37_dp, 3396.19_dp, 360.0_dp / 88642.66_dp)]

    character(len=20), parameter :: preset_names(7) = [character(len=20) :: &
        'Custom', 'ISS (LEO)', 'Sun-synchronous', 'GPS (MEO)', 'Molniya', 'GTO', 'Geostationary']
    !> Preset elements (Earth): a [km], e, i, RAAN, argument of periapsis, true anomaly [deg].
    real(dp), parameter :: presets(6, 6) = reshape([ &
        6778.0_dp, 0.0005_dp, 51.64_dp, 30.0_dp, 0.0_dp, 0.0_dp, &
        7078.0_dp, 0.001_dp, 98.2_dp, 120.0_dp, 90.0_dp, 0.0_dp, &
        26560.0_dp, 0.01_dp, 55.0_dp, 60.0_dp, 0.0_dp, 0.0_dp, &
        26600.0_dp, 0.74_dp, 63.4_dp, 40.0_dp, 270.0_dp, 0.0_dp, &
        24371.0_dp, 0.73_dp, 28.5_dp, 0.0_dp, 180.0_dp, 0.0_dp, &
        42164.0_dp, 0.0_dp, 0.0_dp, 0.0_dp, 0.0_dp, 0.0_dp], [6, 6])

    character(len=*), parameter :: nl = new_line('a')
    character(len=*), parameter :: vertex_shader = &
        '#version 330 core' // nl // &
        'layout(location = 0) in vec3 position;' // nl // &
        'layout(location = 1) in vec3 normal;' // nl // &
        'layout(location = 2) in vec3 color;' // nl // &
        'uniform mat4 mvp;' // nl // &
        'uniform mat3 normalMatrix;' // nl // &
        'out vec3 vNormal;' // nl // &
        'out vec3 vColor;' // nl // &
        'void main() {' // nl // &
        '    gl_Position = mvp * vec4(position, 1.0);' // nl // &
        '    vNormal = normalMatrix * normal;' // nl // &
        '    vColor = color;' // nl // &
        '}' // nl
    character(len=*), parameter :: fragment_shader = &
        '#version 330 core' // nl // &
        'in vec3 vNormal;' // nl // &
        'in vec3 vColor;' // nl // &
        'uniform vec3 lightDirection;' // nl // &
        'uniform int unlit;' // nl // &
        'uniform int overrideColor;' // nl // &
        'uniform vec3 color;' // nl // &
        'uniform float ambient;' // nl // &
        'out vec4 fragColor;' // nl // &
        'void main() {' // nl // &
        '    vec3 c = overrideColor != 0 ? color : vColor;' // nl // &
        '    if (unlit != 0) { fragColor = vec4(c, 1.0); return; }' // nl // &
        '    float diffuse = max(dot(normalize(vNormal), normalize(lightDirection)), 0.0);' // nl // &
        '    fragColor = vec4(c * (ambient + (1.0 - ambient) * diffuse), 1.0);' // nl // &
        '}' // nl

    !> A set of lines (or a line strip) with its own vertex array and buffer.
    type :: line_set
        type(QOpenGLVertexArrayObject) :: vao
        type(QOpenGLBuffer) :: vbo
        integer :: count = 0                !! number of vertices
        integer :: mode = GL_LINES          !! GL_LINES or GL_LINE_STRIP
    end type line_set

    !> Position and velocity at one instant, plus derived quantities.
    type :: state_t
        real(dp) :: r(3), v(3)        !! position [km], velocity [km/s]
        real(dp) :: nu                !! true anomaly [rad]
    end type state_t

    !> The whole application: widgets, simulation, camera and GL resources.
    type :: app_t
        ! main window
        type(QMainWindow) :: window
        type(QtfOpenGLWidget) :: view
        type(QStatusBar) :: status
        type(QTimer) :: timer
        type(QAction) :: play_action
        ! side panel
        type(QComboBox) :: preset, body
        type(QDoubleSpinBox) :: a, e, i, raan, argp, nu0
        type(QPushButton) :: play
        type(QSlider) :: warp
        type(QLabel) :: warp_label
        type(QCheckBox) :: show_grid, show_axes, show_graticule, show_nodes, show_velocity
        type(QCheckBox) :: lighting, rotate_body
        type(QLabel) :: period, periapsis, apoapsis, altitude, speed, anomaly, clock, warning
        ! simulation
        real(dp) :: t = 0.0_dp                !! time since epoch [s]
        logical :: applying_preset = .false.  !! suppress "Custom" while a preset fills the fields
        ! camera (orbiting the origin; z is up)
        real(dp) :: yaw = -60.0_dp, pitch = 25.0_dp, distance = 60.0_dp
        real(dp) :: last_x = 0.0_dp, last_y = 0.0_dp
        ! GL resources
        type(QOpenGLShaderProgram) :: program
        type(QOpenGLVertexArrayObject) :: sphere_vao
        type(QOpenGLBuffer) :: sphere_vbo, sphere_ibo
        integer :: sphere_indices = 0
        type(line_set) :: orbit, grid, axes, nodes, graticule, velocity
        logical :: ready = .false.
        logical :: body_dirty = .true., orbit_dirty = .true.
        ! --screenshot
        character(len=:), allocatable :: screenshot
        integer :: frames_left = 90
    end type app_t

contains

    ! ==================================================================
    ! orbital mechanics

    !> The selected central body.
    type(body_t) function current_body(s)
        type(app_t), intent(in) :: s
        current_body = bodies(s%body%currentIndex() + 1)
    end function current_body

    !> Gravitational parameter of the selected body [km^3/s^2].
    real(dp) function body_mu(s)
        type(app_t), intent(in) :: s
        body_mu = bodies(s%body%currentIndex() + 1)%mu
    end function body_mu

    !> Equatorial radius of the selected body [km].
    real(dp) function body_radius(s)
        type(app_t), intent(in) :: s
        body_radius = bodies(s%body%currentIndex() + 1)%radius
    end function body_radius

    !> Columns of the perifocal-to-inertial rotation (P toward periapsis, Q 90 deg
    !> ahead in the orbit plane, W along the orbit normal).
    subroutine perifocal_axes(raan, argp, inc, p, q, w)
        real(dp), intent(in) :: raan, argp, inc    !! radians
        real(dp), intent(out) :: p(3), q(3), w(3)
        p = [cos(raan) * cos(argp) - sin(raan) * sin(argp) * cos(inc), &
             sin(raan) * cos(argp) + cos(raan) * sin(argp) * cos(inc), &
             sin(argp) * sin(inc)]
        q = [-cos(raan) * sin(argp) - sin(raan) * cos(argp) * cos(inc), &
             -sin(raan) * sin(argp) + cos(raan) * cos(argp) * cos(inc), &
             cos(argp) * sin(inc)]
        w = [sin(raan) * sin(inc), -cos(raan) * sin(inc), cos(inc)]
    end subroutine perifocal_axes

    !> Position at true anomaly `nu` [rad] for the current elements [km].
    function position_at(s, nu) result(r)
        type(app_t), intent(in) :: s
        real(dp), intent(in) :: nu
        real(dp) :: r(3), p(3), q(3), w(3), e, slr
        e = s%e%value()
        slr = s%a%value() * (1 - e * e)          ! semi-latus rectum
        call perifocal_axes(s%raan%value() * deg, s%argp%value() * deg, s%i%value() * deg, p, q, w)
        r = slr / (1 + e * cos(nu)) * (cos(nu) * p + sin(nu) * q)
    end function position_at

    !> Solve Kepler's equation M = E - e sin(E) for the eccentric anomaly E.
    pure real(dp) function eccentric_anomaly(m, e) result(ea)
        real(dp), intent(in) :: m, e
        real(dp) :: d
        integer :: k
        ea = m
        if (e > 0.8_dp) ea = pi
        do k = 1, 50
            d = (ea - e * sin(ea) - m) / (1 - e * cos(ea))
            ea = ea - d
            if (abs(d) < 1.0e-13_dp) exit
        end do
    end function eccentric_anomaly

    !> Propagate the current elements to time `t` [s] after the epoch (two-body).
    type(state_t) function propagate(s, t) result(st)
        type(app_t), intent(in) :: s
        real(dp), intent(in) :: t
        real(dp) :: a, e, mu, n, e0, m, ea, p(3), q(3), w(3), slr
        type(body_t) :: b
        b = current_body(s)
        mu = b%mu
        a = s%a%value()
        e = s%e%value()
        n = sqrt(mu / a**3)                                      ! mean motion
        e0 = atan2(sqrt(1 - e * e) * sin(s%nu0%value() * deg), e + cos(s%nu0%value() * deg))
        m = modulo(e0 - e * sin(e0) + n * t, 2 * pi)             ! mean anomaly at t
        ea = eccentric_anomaly(m, e)
        st%nu = atan2(sqrt(1 - e * e) * sin(ea), cos(ea) - e)
        slr = a * (1 - e * e)
        call perifocal_axes(s%raan%value() * deg, s%argp%value() * deg, s%i%value() * deg, p, q, w)
        st%r = a * (1 - e * cos(ea)) * (cos(st%nu) * p + sin(st%nu) * q)
        st%v = sqrt(mu / slr) * (-sin(st%nu) * p + (e + cos(st%nu)) * q)
    end function propagate

    !> Orbital period [s].
    real(dp) function period_of(s)
        type(app_t), intent(in) :: s
        period_of = 2 * pi * sqrt(s%a%value()**3 / body_mu(s))
    end function period_of

    !> Apoapsis radius [km].
    real(dp) function apoapsis_radius(s)
        type(app_t), intent(in) :: s
        apoapsis_radius = s%a%value() * (1 + s%e%value())
    end function apoapsis_radius

    ! ==================================================================
    ! geometry (vertex arrays in scene units; layout: position, normal, color)

    !> Write one vertex at `k` (advanced past it).
    subroutine put(v, k, p, c, n)
        real(dp), intent(inout) :: v(:)
        integer, intent(inout) :: k
        real(dp), intent(in) :: p(3), c(3)
        real(dp), intent(in), optional :: n(3)
        if (present(n)) then
            v(k + 1:k + 9) = [p, n, c]
        else
            v(k + 1:k + 9) = [p, 0.0_dp, 0.0_dp, 1.0_dp, c]
        end if
        k = k + floats_per_vertex
    end subroutine put

    !> Surface color of a body at latitude / longitude [rad] (procedural, stylized).
    function surface_color(which, lat, lon) result(c)
        integer, intent(in) :: which
        real(dp), intent(in) :: lat, lon
        real(dp) :: c(3), f
        f = sin(2 * lon + 0.5_dp) * cos(3 * lat) + 0.6_dp * sin(5 * lon - 1.3_dp) * sin(4 * lat + 0.7_dp) &
            + 0.4_dp * cos(7 * lon + 2 * lat)
        select case (which)
        case (2)   ! Moon: gray highlands, darker maria
            c = merge([0.36_dp, 0.36_dp, 0.38_dp], [0.66_dp, 0.65_dp, 0.62_dp], f > 0.45_dp)
        case (3)   ! Mars: rust, darker regions, polar caps
            c = merge([0.48_dp, 0.22_dp, 0.12_dp], [0.78_dp, 0.40_dp, 0.22_dp], f > 0.4_dp)
            if (abs(lat) > 78 * deg) c = [0.92_dp, 0.90_dp, 0.88_dp]
        case default   ! Earth: ocean, land, ice
            c = [0.07_dp, 0.22_dp, 0.55_dp]
            if (f > 0.55_dp) c = merge([0.45_dp, 0.38_dp, 0.22_dp], [0.20_dp, 0.48_dp, 0.20_dp], f > 1.05_dp)
            if (abs(lat) > 70 * deg) c = [0.92_dp, 0.94_dp, 0.97_dp]
        end select
    end function surface_color

    !> A unit sphere (radius 1) colored for body `which`: vertices and triangle indices.
    subroutine sphere_mesh(which, vertices, indices)
        integer, intent(in) :: which
        real(dp), allocatable, intent(out) :: vertices(:)
        integer, allocatable, intent(out) :: indices(:)
        integer, parameter :: nlat = 64, nlon = 128
        real(dp) :: lat, lon, p(3)
        integer :: i, j, k, v
        allocate(vertices(floats_per_vertex * (nlat + 1) * (nlon + 1)))
        k = 0
        do j = 0, nlat
            lat = -pi / 2 + j * pi / nlat
            do i = 0, nlon
                lon = i * 2 * pi / nlon
                p = [cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat)]
                call put(vertices, k, p, surface_color(which, lat, lon), p)
            end do
        end do
        allocate(indices(6 * nlat * nlon))
        k = 0
        do j = 0, nlat - 1
            do i = 0, nlon - 1
                v = j * (nlon + 1) + i
                ! counter-clockwise seen from outside
                indices(k + 1:k + 6) = [v, v + 1, v + nlon + 1, v + 1, v + nlon + 2, v + nlon + 1]
                k = k + 6
            end do
        end do
    end subroutine sphere_mesh

    !> Latitude/longitude lines just above a unit sphere, every 30 degrees.
    function graticule_lines() result(v)
        real(dp), allocatable :: v(:)
        integer, parameter :: segs = 96
        real(dp), parameter :: r = 1.004_dp, c(3) = [0.55_dp, 0.62_dp, 0.72_dp]
        real(dp) :: t1, t2, lat, lon
        integer :: i, j, k
        allocate(v(floats_per_vertex * 2 * segs * (5 + 12)))
        k = 0
        do j = -2, 2                            ! parallels at -60..60
            lat = j * 30 * deg
            do i = 0, segs - 1
                t1 = i * 2 * pi / segs
                t2 = (i + 1) * 2 * pi / segs
                call put(v, k, r * [cos(lat) * cos(t1), cos(lat) * sin(t1), sin(lat)], c)
                call put(v, k, r * [cos(lat) * cos(t2), cos(lat) * sin(t2), sin(lat)], c)
            end do
        end do
        do j = 0, 11                            ! meridians
            lon = j * 30 * deg
            do i = 0, segs - 1
                t1 = -pi / 2 + i * pi / segs
                t2 = -pi / 2 + (i + 1) * pi / segs
                call put(v, k, r * [cos(t1) * cos(lon), cos(t1) * sin(lon), sin(t1)], c)
                call put(v, k, r * [cos(t2) * cos(lon), cos(t2) * sin(lon), sin(t2)], c)
            end do
        end do
    end function graticule_lines

    !> The orbit as a closed line strip.
    function orbit_strip(s) result(v)
        type(app_t), intent(in) :: s
        real(dp), allocatable :: v(:)
        real(dp), parameter :: c(3) = [0.25_dp, 0.85_dp, 1.0_dp]
        integer :: i, k
        allocate(v(floats_per_vertex * orbit_points))
        k = 0
        do i = 0, orbit_points - 1
            call put(v, k, scale * position_at(s, i * 2 * pi / (orbit_points - 1)), c)
        end do
    end function orbit_strip

    !> A "nice" spacing (1, 2 or 5 times a power of ten) for about `n` steps over `width`.
    real(dp) function nice_step(width, n)
        real(dp), intent(in) :: width
        integer, intent(in) :: n
        real(dp) :: raw, mag
        raw = width / n
        mag = 10.0_dp**floor(log10(raw))
        if (raw / mag < 1.5_dp) then
            nice_step = mag
        else if (raw / mag < 3.5_dp) then
            nice_step = 2 * mag
        else
            nice_step = 5 * mag
        end if
    end function nice_step

    !> Equatorial-plane rings and spokes, sized to the orbit (scene units).
    function grid_lines(s) result(v)
        type(app_t), intent(in) :: s
        real(dp), allocatable :: v(:)
        integer, parameter :: segs = 128, spokes = 12
        real(dp), parameter :: c(3) = [0.22_dp, 0.26_dp, 0.34_dp]
        real(dp) :: step, rmax, rmin, r, t1, t2
        integer :: nrings, i, j, k
        rmax = 1.15_dp * scale * max(apoapsis_radius(s), 1.5_dp * body_radius(s))
        rmin = scale * body_radius(s)
        step = nice_step(rmax, 5)
        nrings = max(1, floor(rmax / step))
        allocate(v(floats_per_vertex * 2 * (nrings * segs + spokes)))
        k = 0
        do j = 1, nrings
            r = j * step
            do i = 0, segs - 1
                t1 = i * 2 * pi / segs
                t2 = (i + 1) * 2 * pi / segs
                call put(v, k, [r * cos(t1), r * sin(t1), 0.0_dp], c)
                call put(v, k, [r * cos(t2), r * sin(t2), 0.0_dp], c)
            end do
        end do
        do j = 0, spokes - 1
            t1 = j * 2 * pi / spokes
            call put(v, k, [rmin * cos(t1), rmin * sin(t1), 0.0_dp], c)
            call put(v, k, [nrings * step * cos(t1), nrings * step * sin(t1), 0.0_dp], c)
        end do
    end function grid_lines

    !> Inertial X (red), Y (green) and Z (blue) axes.
    function axes_lines(s) result(v)
        type(app_t), intent(in) :: s
        real(dp), allocatable :: v(:)
        real(dp) :: len
        integer :: k
        len = scale * max(2.0_dp * body_radius(s), 0.75_dp * apoapsis_radius(s))
        allocate(v(floats_per_vertex * 6))
        k = 0
        call put(v, k, [0.0_dp, 0.0_dp, 0.0_dp], [1.0_dp, 0.3_dp, 0.3_dp])
        call put(v, k, [len, 0.0_dp, 0.0_dp], [1.0_dp, 0.3_dp, 0.3_dp])
        call put(v, k, [0.0_dp, 0.0_dp, 0.0_dp], [0.3_dp, 1.0_dp, 0.3_dp])
        call put(v, k, [0.0_dp, len, 0.0_dp], [0.3_dp, 1.0_dp, 0.3_dp])
        call put(v, k, [0.0_dp, 0.0_dp, 0.0_dp], [0.35_dp, 0.55_dp, 1.0_dp])
        call put(v, k, [0.0_dp, 0.0_dp, len], [0.35_dp, 0.55_dp, 1.0_dp])
    end function axes_lines

    !> The line of nodes, from the descending to the ascending node.
    function node_line(s) result(v)
        type(app_t), intent(in) :: s
        real(dp), allocatable :: v(:)
        real(dp), parameter :: c(3) = [1.0_dp, 0.85_dp, 0.3_dp]
        real(dp) :: w
        integer :: k
        w = s%argp%value() * deg
        allocate(v(floats_per_vertex * 2))
        k = 0
        call put(v, k, scale * position_at(s, pi - w), c)    ! descending node
        call put(v, k, scale * position_at(s, -w), c)        ! ascending node
    end function node_line

    ! ==================================================================
    ! GL helpers (call with the context current)

    !> Describe the interleaved vertex layout of the bound buffer.
    subroutine set_layout(program)
        type(QOpenGLShaderProgram), intent(in) :: program
        call program%enableAttributeArray(0)
        call program%setAttributeBuffer(0, GL_FLOAT, 0, 3, stride)
        call program%enableAttributeArray(1)
        call program%setAttributeBuffer(1, GL_FLOAT, 12, 3, stride)
        call program%enableAttributeArray(2)
        call program%setAttributeBuffer(2, GL_FLOAT, 24, 3, stride)
    end subroutine set_layout

    !> Create the vertex array and buffer of a line set.
    subroutine create_lines(s, set, mode)
        type(app_t), intent(inout) :: s
        type(line_set), intent(inout) :: set
        integer, intent(in) :: mode
        logical :: ok
        set%mode = mode
        set%vao = QOpenGLVertexArrayObject(s%view)
        ok = set%vao%create()
        call set%vao%bind()
        set%vbo = QOpenGLBuffer()
        ok = set%vbo%create()
        call set%vbo%setUsagePattern(QOpenGLBuffer_DynamicDraw)
        ok = set%vbo%bind()
        call set_layout(s%program)
        call set%vao%release()
    end subroutine create_lines

    !> Replace the vertices of a line set.
    subroutine upload_lines(set, vertices)
        type(line_set), intent(inout) :: set
        real(dp), intent(in) :: vertices(:)
        logical :: ok
        call set%vao%bind()
        ok = set%vbo%bind()
        call set%vbo%allocate(vertices)
        set%count = size(vertices) / floats_per_vertex
        call set%vao%release()
    end subroutine upload_lines

    !> Draw a line set with the current uniforms.
    subroutine draw_lines(set)
        type(line_set), intent(in) :: set
        call set%vao%bind()
        call glDrawArrays(set%mode, 0, set%count)
        call set%vao%release()
    end subroutine draw_lines

    !> Upload the central body's sphere colors.
    subroutine upload_body(s)
        type(app_t), intent(inout) :: s
        real(dp), allocatable :: vertices(:)
        integer, allocatable :: indices(:)
        logical :: ok
        call sphere_mesh(s%body%currentIndex() + 1, vertices, indices)
        call s%sphere_vao%bind()
        ok = s%sphere_vbo%bind()
        call s%sphere_vbo%allocate(vertices)
        ok = s%sphere_ibo%bind()
        call s%sphere_ibo%allocate(indices)
        s%sphere_indices = size(indices)
        call s%sphere_vao%release()
    end subroutine upload_body

    !> Set the transform uniforms for a model matrix.
    subroutine set_transform(s, view_projection, model)
        type(app_t), intent(inout) :: s
        type(QMatrix4x4), intent(in) :: view_projection, model
        call s%program%setUniformValue('mvp', view_projection * model)
        call s%program%setUniformValue('normalMatrix', reshape(model%normalMatrix(), [9]))
    end subroutine set_transform

    !> Draw the unit sphere scaled by `radius` at `center`, in a flat color.
    subroutine draw_marker(s, view_projection, center, radius, color)
        type(app_t), intent(inout) :: s
        type(QMatrix4x4), intent(in) :: view_projection
        real(dp), intent(in) :: center(3), radius, color(3)
        type(QMatrix4x4) :: model
        call model%translate(center(1), center(2), center(3))
        call model%scale(radius)
        call set_transform(s, view_projection, model)
        call s%program%setUniformValue('overrideColor', 1)
        call s%program%setUniformValue('color', color(1), color(2), color(3))
        call s%program%setUniformValue('ambient', 0.55_dp)
        call s%sphere_vao%bind()
        call glDrawElements(GL_TRIANGLES, s%sphere_indices, GL_UNSIGNED_INT)
        call s%sphere_vao%release()
        call s%program%setUniformValue('overrideColor', 0)
    end subroutine draw_marker

    ! ==================================================================
    ! OpenGL slots

    !> Build the shader program and all buffers.
    subroutine on_initialize(data)
        class(*), intent(inout), optional :: data
        logical :: ok
        integer :: button
        select type (s => data)
        type is (app_t)
            call glEnable(GL_DEPTH_TEST)
            call glEnable(GL_MULTISAMPLE)
            call glClearColor(0.0_dp, 0.0_dp, 0.0_dp, 1.0_dp)
            s%program = QOpenGLShaderProgram(s%view)
            ok = s%program%addShaderFromSourceCode(QOpenGLShader_Vertex, vertex_shader)
            ok = ok .and. s%program%addShaderFromSourceCode(QOpenGLShader_Fragment, fragment_shader)
            ok = ok .and. s%program%link()
            if (.not. ok) then
                button = QMessageBox_critical('OpenGL', 'Could not build the shaders:' // nl // &
                                              s%program%log(), parent=s%window)
                return
            end if
            ok = s%program%bind()

            s%sphere_vao = QOpenGLVertexArrayObject(s%view)
            ok = s%sphere_vao%create()
            call s%sphere_vao%bind()
            s%sphere_vbo = QOpenGLBuffer()
            ok = s%sphere_vbo%create()
            ok = s%sphere_vbo%bind()
            call set_layout(s%program)
            s%sphere_ibo = QOpenGLBuffer(QOpenGLBuffer_IndexBuffer)
            ok = s%sphere_ibo%create()
            call s%sphere_vao%release()

            call create_lines(s, s%orbit, GL_LINE_STRIP)
            call create_lines(s, s%grid, GL_LINES)
            call create_lines(s, s%axes, GL_LINES)
            call create_lines(s, s%nodes, GL_LINES)
            call create_lines(s, s%graticule, GL_LINES)
            call create_lines(s, s%velocity, GL_LINES)
            call upload_lines(s%graticule, graticule_lines())
            call s%program%release()
            s%ready = .true.
        end select
    end subroutine on_initialize

    !> Draw the scene: body, graticule, grid, axes, orbit, nodes, markers, velocity.
    subroutine on_paint(data)
        class(*), intent(inout), optional :: data
        type(QMatrix4x4) :: view_projection, model, identity
        type(state_t) :: st
        type(body_t) :: b
        real(dp) :: eye(3), yaw, pitch, aspect, rbody, marker, v(18), dir(3)
        real(dp) :: periapsis(3), apoapsis(3)
        logical :: ok
        integer :: k
        select type (s => data)
        type is (app_t)
            call glClear(ior(GL_COLOR_BUFFER_BIT, GL_DEPTH_BUFFER_BIT))
            if (.not. s%ready) return
            ok = s%program%bind()

            ! geometry that depends on the settings is rebuilt here (context current)
            if (s%body_dirty) then
                call upload_body(s)
                s%body_dirty = .false.
            end if
            if (s%orbit_dirty) then
                call upload_lines(s%orbit, orbit_strip(s))
                call upload_lines(s%grid, grid_lines(s))
                call upload_lines(s%axes, axes_lines(s))
                call upload_lines(s%nodes, node_line(s))
                s%orbit_dirty = .false.
            end if

            ! camera
            yaw = s%yaw * deg
            pitch = s%pitch * deg
            eye = s%distance * [cos(pitch) * cos(yaw), cos(pitch) * sin(yaw), sin(pitch)]
            aspect = real(s%view%width(), dp) / max(1, s%view%height())
            call view_projection%perspective(40.0_dp, aspect, 0.01_dp * s%distance, 20 * s%distance)
            call view_projection%lookAt(eye, [0.0_dp, 0.0_dp, 0.0_dp], [0.0_dp, 0.0_dp, 1.0_dp])

            b = current_body(s)
            rbody = scale * b%radius
            call s%program%setUniformValue('lightDirection', 1.0_dp, 0.35_dp, 0.25_dp)
            call s%program%setUniformValue('overrideColor', 0)

            ! the central body, rotating about z
            call model%rotate(merge(b%rotation * s%t, 0.0_dp, s%rotate_body%isChecked()), &
                              0.0_dp, 0.0_dp, 1.0_dp)
            call model%scale(rbody)
            call set_transform(s, view_projection, model)
            call s%program%setUniformValue('unlit', 0)
            call s%program%setUniformValue('ambient', merge(0.12_dp, 1.0_dp, s%lighting%isChecked()))
            call s%sphere_vao%bind()
            call glDrawElements(GL_TRIANGLES, s%sphere_indices, GL_UNSIGNED_INT)
            call s%sphere_vao%release()

            ! lines (unlit)
            call s%program%setUniformValue('unlit', 1)
            if (s%show_graticule%isChecked()) then
                call set_transform(s, view_projection, model)
                call draw_lines(s%graticule)
            end if
            call set_transform(s, view_projection, identity)
            if (s%show_grid%isChecked()) call draw_lines(s%grid)
            if (s%show_axes%isChecked()) call draw_lines(s%axes)
            call draw_lines(s%orbit)
            if (s%show_nodes%isChecked() .and. s%i%value() > 0.05_dp) call draw_lines(s%nodes)

            ! spacecraft and its velocity vector
            st = propagate(s, s%t)
            marker = 0.009_dp * s%distance
            if (s%show_velocity%isChecked()) then
                dir = st%v / norm2(st%v)
                k = 0
                call put(v, k, scale * st%r, [1.0_dp, 0.5_dp, 0.9_dp])
                call put(v, k, scale * st%r + 0.12_dp * s%distance * dir, [1.0_dp, 0.5_dp, 0.9_dp])
                call upload_lines(s%velocity, v)
                call draw_lines(s%velocity)
            end if

            ! markers (lit, flat colors)
            call s%program%setUniformValue('unlit', 0)
            call draw_marker(s, view_projection, scale * st%r, marker, [1.0_dp, 0.85_dp, 0.2_dp])
            if (s%e%value() > 0.005_dp) then
                periapsis = scale * position_at(s, 0.0_dp)
                apoapsis = scale * position_at(s, pi)
                call draw_marker(s, view_projection, periapsis, 0.6_dp * marker, [1.0_dp, 0.3_dp, 0.25_dp])
                call draw_marker(s, view_projection, apoapsis, 0.6_dp * marker, [0.3_dp, 0.9_dp, 0.4_dp])
            end if
            call s%program%release()
        end select
    end subroutine on_paint

    ! ==================================================================
    ! readouts

    !> "1d 02h 03m 04s" style duration.
    function duration(t) result(text)
        real(dp), intent(in) :: t
        character(len=:), allocatable :: text
        character(len=32) :: buf
        integer :: total, d, h, m, sec
        total = nint(abs(t))
        d = total / 86400
        h = mod(total, 86400) / 3600
        m = mod(total, 3600) / 60
        sec = mod(total, 60)
        if (d > 0) then
            write(buf, '(I0,A,I2.2,A,I2.2,A,I2.2,A)') d, 'd ', h, 'h ', m, 'm ', sec, 's'
        else if (h > 0) then
            write(buf, '(I0,A,I2.2,A,I2.2,A)') h, 'h ', m, 'm ', sec, 's'
        else
            write(buf, '(I0,A,I2.2,A)') m, 'm ', sec, 's'
        end if
        text = trim(buf)
    end function duration

    !> `v` formatted with `fmt` and trimmed, followed by `unit`.
    function num(v, fmt, unit) result(text)
        real(dp), intent(in) :: v
        character(len=*), intent(in) :: fmt, unit
        character(len=:), allocatable :: text
        character(len=32) :: buf
        write(buf, fmt) v
        text = trim(adjustl(buf)) // unit
    end function num

    !> Refresh the readout labels for the current time.
    subroutine update_readouts(s)
        type(app_t), intent(inout) :: s
        type(state_t) :: st
        type(body_t) :: b
        real(dp) :: rp
        b = current_body(s)
        st = propagate(s, s%t)
        rp = s%a%value() * (1 - s%e%value())
        call s%period%setText(duration(period_of(s)))
        call s%periapsis%setText(num(rp - b%radius, '(F12.1)', ' km'))
        call s%apoapsis%setText(num(apoapsis_radius(s) - b%radius, '(F12.1)', ' km'))
        call s%altitude%setText(num(norm2(st%r) - b%radius, '(F12.1)', ' km'))
        call s%speed%setText(num(norm2(st%v), '(F10.4)', ' km/s'))
        call s%anomaly%setText(num(modulo(st%nu / deg, 360.0_dp), '(F8.2)', ' deg'))
        call s%clock%setText(duration(s%t))
        if (rp < b%radius) then
            call s%warning%setText('<span style="color:#e05040"><b>Periapsis is below the surface!</b></span>')
        else
            call s%warning%setText('')
        end if
    end subroutine update_readouts

    !> Fit the camera distance to the orbit.
    subroutine fit_view(s)
        type(app_t), intent(inout) :: s
        s%distance = 3.3_dp * scale * max(apoapsis_radius(s), 2.0_dp * body_radius(s))
    end subroutine fit_view

    ! ==================================================================
    ! panel slots

    !> Any orbital element changed: mark the preset as custom and redraw.
    subroutine on_element(value, data)
        real(dp), intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            if (.not. s%applying_preset) call s%preset%setCurrentIndex(0)
            s%orbit_dirty = .true.
            call update_readouts(s)
            call s%view%update()
        end select
    end subroutine on_element

    !> Apply a preset orbit (Earth).
    subroutine on_preset(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            if (index < 1) return
            s%applying_preset = .true.
            call s%body%setCurrentIndex(0)
            call s%a%setValue(presets(1, index))
            call s%e%setValue(presets(2, index))
            call s%i%setValue(presets(3, index))
            call s%raan%setValue(presets(4, index))
            call s%argp%setValue(presets(5, index))
            call s%nu0%setValue(presets(6, index))
            s%applying_preset = .false.
            s%t = 0.0_dp
            call fit_view(s)
            s%orbit_dirty = .true.
            call update_readouts(s)
            call s%status%showMessage('Preset: ' // trim(preset_names(index + 1)), 3000)
            call s%view%update()
        end select
    end subroutine on_preset

    !> A different central body: recolor the sphere and refit.
    subroutine on_body(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            if (.not. s%applying_preset) call s%preset%setCurrentIndex(0)
            s%body_dirty = .true.
            s%orbit_dirty = .true.
            call fit_view(s)
            call update_readouts(s)
            call s%view%update()
        end select
    end subroutine on_body

    !> A display option changed.
    subroutine on_option(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            call s%view%update()
        end select
    end subroutine on_option

    !> Start or stop the clock (shared by the panel button and the action).
    subroutine on_play(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            call s%play%setChecked(checked)        ! keep button and action in sync
            call s%play_action%setChecked(checked)
            call s%play%setText(merge('Pause', 'Play ', checked))
            if (checked) then
                call s%timer%start(16)
            else
                call s%timer%stop()
            end if
        end select
    end subroutine on_play

    !> Time-warp slider: 10^(value/25), from 1x to 10000x.
    subroutine on_warp(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        character(len=16) :: text
        select type (s => data)
        type is (app_t)
            write(text, '(I0,A)') nint(warp_factor(value)), 'x'
            call s%warp_label%setText(trim(text))
        end select
    end subroutine on_warp

    !> The time warp for a slider position.
    real(dp) function warp_factor(value)
        integer, intent(in) :: value
        warp_factor = 10.0_dp**(value / 25.0_dp)
    end function warp_factor

    !> Advance the clock; handles `--screenshot`.
    subroutine on_tick(data)
        class(*), intent(inout), optional :: data
        type(QPixmap) :: pix
        select type (s => data)
        type is (app_t)
            s%t = s%t + 0.016_dp * warp_factor(s%warp%value())
            call update_readouts(s)
            call s%view%update()
            if (allocated(s%screenshot)) then
                s%frames_left = s%frames_left - 1
                if (s%frames_left == 0) then
                    pix = s%window%grab()
                    if (.not. pix%save(s%screenshot)) write(*,'(A)') 'could not save ' // s%screenshot
                    call pix%delete()
                    call QApplication_quit()
                end if
            end if
        end select
    end subroutine on_tick

    !> Reset the clock to the epoch.
    subroutine on_reset_time(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            s%t = 0.0_dp
            call update_readouts(s)
            call s%view%update()
        end select
    end subroutine on_reset_time

    ! ==================================================================
    ! view slots

    !> Remember where a drag starts.
    subroutine on_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            s%last_x = event%x()
            s%last_y = event%y()
        end select
    end subroutine on_press

    !> Orbit the camera while dragging.
    subroutine on_move(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            if (event%buttons() == Qt_NoButton) return
            s%yaw = s%yaw - 0.4_dp * (event%x() - s%last_x)
            s%pitch = min(max(s%pitch + 0.4_dp * (event%y() - s%last_y), -89.0_dp), 89.0_dp)
            s%last_x = event%x()
            s%last_y = event%y()
            call s%view%update()
        end select
    end subroutine on_move

    !> Zoom with the wheel.
    subroutine on_wheel(event, data)
        type(QWheelEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            s%distance = min(max(s%distance * 0.9_dp**(event%angleDeltaY() / 120.0_dp), &
                                 1.5_dp * scale * body_radius(s)), 2000.0_dp)
            call s%view%update()
        end select
    end subroutine on_wheel

    !> Space: play/pause; +/-: time warp.
    subroutine on_key(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            select case (event%key())
            case (Qt_Key_Space)
                call s%play_action%trigger()
            case (Qt_Key_Plus)
                call s%warp%setValue(s%warp%value() + 5)
            case (Qt_Key_Minus)
                call s%warp%setValue(s%warp%value() - 5)
            end select
        end select
    end subroutine on_key

    ! ==================================================================
    ! menu commands

    !> Fit the camera to the orbit.
    subroutine on_fit(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            call fit_view(s)
            call s%view%update()
        end select
    end subroutine on_fit

    !> Look down on the equatorial plane.
    subroutine on_top_view(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            s%pitch = 89.0_dp
            s%yaw = -90.0_dp
            call s%view%update()
        end select
    end subroutine on_top_view

    !> Look along the equatorial plane.
    subroutine on_side_view(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_t)
            s%pitch = 0.0_dp
            s%yaw = -90.0_dp
            call s%view%update()
        end select
    end subroutine on_side_view

    !> Save the 3D view as a PNG.
    subroutine on_save_view(data)
        class(*), intent(inout), optional :: data
        type(QImage) :: img
        character(len=:), allocatable :: path
        select type (s => data)
        type is (app_t)
            path = QFileDialog_getSaveFileName('Save 3D view', 'orbit.png', 'PNG images (*.png)', parent=s%window)
            if (path == '') return
            img = s%view%grabFramebuffer()
            call report_save(s, path, img%save(path))
            call img%delete()
        end select
    end subroutine on_save_view

    !> Save the whole window as a PNG.
    subroutine on_save_window(data)
        class(*), intent(inout), optional :: data
        type(QPixmap) :: pix
        character(len=:), allocatable :: path
        select type (s => data)
        type is (app_t)
            path = QFileDialog_getSaveFileName('Save window', 'orbit-window.png', 'PNG images (*.png)', &
                                               parent=s%window)
            if (path == '') return
            pix = s%window%grab()
            call report_save(s, path, pix%save(path))
            call pix%delete()
        end select
    end subroutine on_save_window

    !> Report the result of saving an image.
    subroutine report_save(s, path, ok)
        type(app_t), intent(inout) :: s
        character(len=*), intent(in) :: path
        logical, intent(in) :: ok
        integer :: button
        if (ok) then
            call s%status%showMessage('Saved ' // path, 3000)
        else
            button = QMessageBox_warning('Save image', 'Could not write ' // path, parent=s%window)
        end if
    end subroutine report_save

    !> Show the about box.
    subroutine on_about(data)
        class(*), intent(inout), optional :: data
        integer :: button
        select type (s => data)
        type is (app_t)
            button = QMessageBox_information('About Orbit Viewer', &
                'Orbit Viewer' // nl // nl // &
                'Two-body (Kepler) propagation of a spacecraft orbit, written in' // nl // &
                'Modern Fortran with qt-fortran and OpenGL.' // nl // nl // &
                'Drag: rotate view    Wheel: zoom' // nl // &
                'Space: play / pause    +/-: time warp', parent=s%window)
        end select
    end subroutine on_about

    !> Quit the application.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

    ! ==================================================================
    ! construction

    !> A spin box for an orbital element.
    function element_box(lo, hi, step, decimals, suffix) result(box)
        real(dp), intent(in) :: lo, hi, step
        integer, intent(in) :: decimals
        character(len=*), intent(in) :: suffix
        type(QDoubleSpinBox) :: box
        box = QDoubleSpinBox()
        call box%setRange(lo, hi)
        call box%setSingleStep(step)
        call box%setDecimals(decimals)
        call box%setSuffix(suffix)
    end function element_box

    !> A section title in the side panel.
    function heading(text) result(label)
        character(len=*), intent(in) :: text
        type(QLabel) :: label
        label = QLabel('<b>' // text // '</b>')
    end function heading

    !> Add a "name: value" readout row to the grid.
    subroutine readout(grid, row, name, value)
        type(QGridLayout), intent(in) :: grid
        integer, intent(inout) :: row
        character(len=*), intent(in) :: name
        type(QLabel), intent(inout) :: value
        value = QLabel('-')
        call value%setAlignment(ior(Qt_AlignRight, Qt_AlignVCenter))
        call grid%addWidget(QLabel(name), row, 0)
        call grid%addWidget(value, row, 1)
        row = row + 1
    end subroutine readout

    !> Add a labelled widget row to the grid.
    subroutine field(grid, row, name, widget)
        type(QGridLayout), intent(in) :: grid
        integer, intent(inout) :: row
        character(len=*), intent(in) :: name
        class(QWidget), intent(in) :: widget
        call grid%addWidget(QLabel(name), row, 0)
        call grid%addWidget(widget, row, 1)
        row = row + 1
    end subroutine field

    !> Build the side panel.
    function build_panel(s) result(panel)
        type(app_t), intent(inout), target :: s
        type(QWidget) :: panel
        type(QGridLayout) :: grid
        type(QHBoxLayout) :: clock_row
        type(QPushButton) :: reset
        integer :: row, k
        character(len=8) :: body_names(size(bodies))

        panel = QWidget()
        call panel%setMinimumSize(290, 0)
        grid = QGridLayout(panel)
        call grid%setSpacing(6)
        row = 0

        ! preset and elements
        call grid%addWidget(heading('Orbit'), row, 0, columnSpan=2)
        row = row + 1
        s%preset = QComboBox()
        call s%preset%addItems(preset_names)
        call field(grid, row, 'Preset', s%preset)
        s%a = element_box(1000.0_dp, 400000.0_dp, 100.0_dp, 1, ' km')
        call field(grid, row, 'Semi-major axis', s%a)
        s%e = element_box(0.0_dp, 0.95_dp, 0.01_dp, 4, '')
        call field(grid, row, 'Eccentricity', s%e)
        s%i = element_box(0.0_dp, 180.0_dp, 1.0_dp, 2, ' deg')
        call field(grid, row, 'Inclination', s%i)
        s%raan = element_box(0.0_dp, 360.0_dp, 5.0_dp, 2, ' deg')
        call field(grid, row, 'RAAN', s%raan)
        s%argp = element_box(0.0_dp, 360.0_dp, 5.0_dp, 2, ' deg')
        call field(grid, row, 'Arg. of periapsis', s%argp)
        s%nu0 = element_box(0.0_dp, 360.0_dp, 5.0_dp, 2, ' deg')
        call field(grid, row, 'True anomaly (epoch)', s%nu0)
        s%body = QComboBox()
        body_names = [(bodies(k)%name, k = 1, size(bodies))]
        call s%body%addItems(body_names)
        call field(grid, row, 'Central body', s%body)

        ! simulation clock
        call grid%addWidget(heading('Simulation'), row, 0, columnSpan=2)
        row = row + 1
        clock_row = QHBoxLayout()
        s%play = QPushButton('Play ')
        call s%play%setCheckable(.true.)
        reset = QPushButton('Reset time')
        call clock_row%addWidget(s%play)
        call clock_row%addWidget(reset)
        call grid%addLayout(clock_row, row, 0, columnSpan=2)
        row = row + 1
        s%warp = QSlider(Qt_Horizontal)
        call s%warp%setRange(0, 100)
        s%warp_label = QLabel('')
        call grid%addWidget(QLabel('Time warp'), row, 0)
        call grid%addWidget(s%warp_label, row, 1, alignment=Qt_AlignRight)
        row = row + 1
        call grid%addWidget(s%warp, row, 0, columnSpan=2)
        row = row + 1

        ! display options
        call grid%addWidget(heading('Display'), row, 0, columnSpan=2)
        row = row + 1
        s%show_grid = option(grid, row, 0, 'Equatorial grid')
        s%show_axes = option(grid, row, 1, 'Inertial axes')
        row = row + 1
        s%show_graticule = option(grid, row, 0, 'Lat/long lines')
        s%show_nodes = option(grid, row, 1, 'Line of nodes')
        row = row + 1
        s%show_velocity = option(grid, row, 0, 'Velocity vector')
        s%lighting = option(grid, row, 1, 'Sun lighting')
        row = row + 1
        s%rotate_body = option(grid, row, 0, 'Rotate body')
        row = row + 1

        ! readouts
        call grid%addWidget(heading('Readouts'), row, 0, columnSpan=2)
        row = row + 1
        call readout(grid, row, 'Period', s%period)
        call readout(grid, row, 'Periapsis altitude', s%periapsis)
        call readout(grid, row, 'Apoapsis altitude', s%apoapsis)
        call readout(grid, row, 'Altitude', s%altitude)
        call readout(grid, row, 'Speed', s%speed)
        call readout(grid, row, 'True anomaly', s%anomaly)
        call readout(grid, row, 'Time since epoch', s%clock)
        s%warning = QLabel('')
        call s%warning%setWordWrap(.true.)
        call grid%addWidget(s%warning, row, 0, columnSpan=2)
        call grid%setRowStretch(row + 1, 1)
        call grid%setColumnStretch(1, 1)

        ! signals
        call s%preset%currentIndexChanged%connect(on_preset, s)
        call s%body%currentIndexChanged%connect(on_body, s)
        call s%a%valueChanged%connect(on_element, s)
        call s%e%valueChanged%connect(on_element, s)
        call s%i%valueChanged%connect(on_element, s)
        call s%raan%valueChanged%connect(on_element, s)
        call s%argp%valueChanged%connect(on_element, s)
        call s%nu0%valueChanged%connect(on_element, s)
        call s%play%toggled%connect(on_play, s)
        call reset%clicked%connect(on_reset_time, s)
        call s%warp%valueChanged%connect(on_warp, s)
        call s%show_grid%toggled%connect(on_option, s)
        call s%show_axes%toggled%connect(on_option, s)
        call s%show_graticule%toggled%connect(on_option, s)
        call s%show_nodes%toggled%connect(on_option, s)
        call s%show_velocity%toggled%connect(on_option, s)
        call s%lighting%toggled%connect(on_option, s)
        call s%rotate_body%toggled%connect(on_option, s)
    end function build_panel

    !> A checked option check box at (row, column).
    function option(grid, row, column, text) result(box)
        type(QGridLayout), intent(in) :: grid
        integer, intent(in) :: row, column
        character(len=*), intent(in) :: text
        type(QCheckBox) :: box
        box = QCheckBox(text)
        call box%setChecked(.true.)
        call grid%addWidget(box, row, column)
    end function option

    !> Create an action connected to `slot`.
    function new_action(s, text, shortcut, slot) result(a)
        type(app_t), intent(inout), target :: s
        character(len=*), intent(in) :: text, shortcut
        procedure(qt_slot) :: slot
        type(QAction) :: a
        a = QAction(text, s%window)
        if (shortcut /= '') call a%setShortcut(shortcut)
        call a%triggered%connect(slot, s)
    end function new_action

    !> Build the main window.
    subroutine build(s)
        type(app_t), intent(inout), target :: s
        type(QWidget) :: central
        type(QHBoxLayout) :: hbox
        type(QMenuBar) :: bar
        type(QMenu) :: file_menu, view_menu, sim_menu, help_menu
        type(QToolBar) :: tools
        type(QAction) :: save_view, save_window, quit, fit, top, side, reset_time, about

        s%window = QMainWindow()
        call s%window%setWindowTitle('Orbit Viewer - qt-fortran + OpenGL')
        s%status = s%window%statusBar()

        central = QWidget()
        hbox = QHBoxLayout(central)
        call hbox%addWidget(build_panel(s))
        s%view = QtfOpenGLWidget()
        call s%view%setMinimumSize(640, 520)
        call hbox%addWidget(s%view, stretch=1)
        call s%window%setCentralWidget(central)

        call s%view%initializeGL%connect(on_initialize, s)
        call s%view%paintGL%connect(on_paint, s)
        call s%view%mousePressEvent%connect(on_press, s)
        call s%view%mouseMoveEvent%connect(on_move, s)
        call s%view%wheelEvent%connect(on_wheel, s)
        call s%view%keyPressEvent%connect(on_key, s)

        ! actions and menus
        save_view = new_action(s, 'Save 3D &view...', 'Ctrl+S', on_save_view)
        save_window = new_action(s, 'Save &window...', 'Ctrl+Shift+S', on_save_window)
        quit = new_action(s, '&Quit', 'Ctrl+Q', on_quit)
        fit = new_action(s, '&Fit orbit', 'Ctrl+0', on_fit)
        top = new_action(s, '&Top view', 'Ctrl+1', on_top_view)
        side = new_action(s, '&Side view', 'Ctrl+2', on_side_view)
        reset_time = new_action(s, '&Reset time', 'Ctrl+R', on_reset_time)
        about = new_action(s, '&About', '', on_about)
        s%play_action = QAction('&Play', s%window)
        call s%play_action%setCheckable(.true.)
        call s%play_action%setShortcut('Ctrl+P')
        call s%play_action%toggled%connect(on_play, s)

        bar = s%window%menuBar()
        file_menu = bar%addMenu('&File')
        call file_menu%addAction(save_view)
        call file_menu%addAction(save_window)
        call file_menu%addSeparator()
        call file_menu%addAction(quit)
        view_menu = bar%addMenu('&View')
        call view_menu%addAction(fit)
        call view_menu%addAction(top)
        call view_menu%addAction(side)
        sim_menu = bar%addMenu('&Simulation')
        call sim_menu%addAction(s%play_action)
        call sim_menu%addAction(reset_time)
        help_menu = bar%addMenu('&Help')
        call help_menu%addAction(about)

        tools = s%window%addToolBar('Main')
        call tools%addAction(s%play_action)
        call tools%addAction(reset_time)
        call tools%addSeparator()
        call tools%addAction(fit)
        call tools%addAction(top)
        call tools%addAction(side)
        call tools%addSeparator()
        call tools%addAction(save_view)

        s%timer = QTimer()
        call s%timer%timeout%connect(on_tick, s)
    end subroutine build

end module orbit3d_app

!> Orbit viewer (see the module documentation).
program orbit3d

    use qt
    use orbit3d_app
    implicit none

    type(QApplication) :: app
    type(QSurfaceFormat) :: fmt
    type(app_t), target :: s
    character(len=1024) :: arg
    integer :: ierr

    ! OpenGL 3.3 core everywhere, with depth buffer and multisampling
    fmt = QSurfaceFormat()
    call fmt%setVersion(3, 3)
    call fmt%setProfile(QSurfaceFormat_CoreProfile)
    call fmt%setDepthBufferSize(24)
    call fmt%setSamples(4)
    call QSurfaceFormat_setDefaultFormat(fmt)
    call fmt%delete()

    app = QApplication()
    call build(s)
    call s%warp%setValue(50)                 ! 100x
    call s%preset%setCurrentIndex(1)         ! ISS

    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        call s%preset%setCurrentIndex(4)     ! Molniya
        call s%warp%setValue(75)             ! 1000x
        s%yaw = -35.0_dp
        s%pitch = 22.0_dp
        call s%play_action%setChecked(.true.)
    end if

    call s%status%showMessage('Drag to rotate, wheel to zoom, Space to play/pause, +/- for time warp')
    call s%window%resize(1180, 760)
    call s%window%show()
    call s%view%setFocus()
    ierr = app%exec()

end program orbit3d
