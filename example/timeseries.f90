!> Time Series Lab: simulate a stochastic process, flag outliers with a
!> rolling z-score, and explore the result in a table, a plot and a statistics
!> tree.
!>
!> * Left dock: model, number of samples, noise, spike rate (injected glitches
!>   for the detector to find), outlier detection (rolling
!>   window and threshold, in a checkable group), random seed (dial + LCD),
!>   plot style, Run / Cancel and a progress bar. Runs are computed in a worker
!>   thread (QThread_create) that reports progress through a Fortran-defined
!>   signal, so the window stays responsive and the run can be cancelled.
!> * Tabs: Data (a table of millions of rows served straight from the Fortran
!>   arrays, next to the list of runs), Plot, Statistics (a tree per run and an
!>   LCD outlier count) and Log.
!> * The value column of the table is editable: edits recompute the statistics.
!>   Runs can be renamed (double-click, or Run > Rename run).
!> * Right-click the plot for a context menu (style, color, save as image).
!> * The window layout and the parameters are remembered between runs
!>   (QSettings); closing asks first while a run is in progress or edited
!>   values have not been exported (a vetoable close event).
!>
!> `timeseries --screenshot out.png [--tab N]` runs once with tab N (default 1,
!> the plot) shown, saves the window and exits.
module timeseries_app

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    real(dp), parameter :: pi = acos(-1.0_dp)
    integer, parameter :: chunk = 50000                  !! samples per progress update

    character(len=24), parameter :: model_names(3) = &
        [character(len=24) :: 'Random walk', 'Ornstein-Uhlenbeck', 'Sine + noise']
    character(len=10), parameter :: columns(5) = &
        [character(len=10) :: '#', 'value', 'mean', 'z-score', 'flag']

    !> One simulation, run in a worker thread: inputs copied from the widgets
    !> before it starts, and the results it leaves behind. The worker touches
    !> nothing else; it reports progress through `progress`.
    type :: sim_job
        ! inputs
        integer :: n = 0, which = 0, seed = 0, window = 0
        real(dp) :: sigma = 0, rate = 0, threshold = 0
        logical :: detect = .true.
        ! results
        real(dp), allocatable :: v(:), mean(:), z(:)
        logical, allocatable :: outlier(:)
        integer :: noutliers = 0
        logical :: cancelled = .false.
        type(QSignalInt) :: progress                      !! percent done
    end type sim_job

    !> Widgets, simulation data and state of the lab.
    type :: lab_t
        ! window
        type(QMainWindow) :: window
        type(QStatusBar) :: status
        type(QTabWidget) :: tabs
        type(QDockWidget) :: dock
        type(QAction) :: run_action, cancel_action
        ! parameters (dock)
        type(QComboBox) :: model
        type(QSpinBox) :: samples, window_size
        type(QDoubleSpinBox) :: noise, spikes, threshold
        type(QGroupBox) :: detection
        type(QDial) :: seed
        type(QLCDNumber) :: seed_display
        type(QButtonGroup) :: style
        type(QPushButton) :: run_button, cancel_button
        type(QProgressBar) :: progress
        ! tabs
        type(QTableView) :: table
        type(QtfTableModel) :: data_model
        type(QListWidget) :: runs
        type(QtfWidget) :: plot
        type(QTreeWidget) :: stats
        type(QLCDNumber) :: outlier_count
        type(QPlainTextEdit) :: log
        type(QMenu) :: plot_menu
        type(QAction) :: points_action
        type(QColor) :: color = QColor(30, 100, 200)
        ! data of the current run
        real(dp), allocatable :: v(:), mean(:), z(:)
        logical, allocatable :: outlier(:)
        integer :: n = 0, noutliers = 0, nruns = 0
        logical :: running = .false.
        ! the worker thread and its job
        type(QThread) :: worker
        type(sim_job) :: job
        integer(8) :: t0 = 0
        logical :: edited = .false.                      !! table edits not yet exported
        ! --screenshot
        character(len=:), allocatable :: screenshot
    end type lab_t

contains

    ! ==================================================================
    ! small helpers

    !> Integer as text.
    function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=:), allocatable :: s
        character(len=24) :: buf
        write(buf, '(I0)') i
        s = trim(buf)
    end function itoa

    !> Real as text with `d` decimals (with a leading zero).
    function rtoa(x, d) result(s)
        real(dp), intent(in) :: x
        integer, intent(in) :: d
        character(len=:), allocatable :: s
        character(len=40) :: buf, fmt
        write(fmt, '(A,I0,A)') '(F40.', d, ')'
        write(buf, fmt) x
        s = trim(adjustl(buf))
    end function rtoa

    !> Append a time-stamped line to the log.
    subroutine log_line(s, text)
        type(lab_t), intent(inout) :: s
        character(len=*), intent(in) :: text
        integer :: v(8)
        character(len=10) :: stamp
        call date_and_time(values=v)
        write(stamp, '(I2.2,A,I2.2,A,I2.2)') v(5), ':', v(6), ':', v(7)
        call s%log%appendPlainText('[' // trim(stamp) // '] ' // text)
    end subroutine log_line

    !> A standard normal random number (Box-Muller).
    real(dp) function gaussian()
        real(dp) :: u(2)
        call random_number(u)
        gaussian = sqrt(-2 * log(max(u(1), 1.0e-300_dp))) * cos(2 * pi * u(2))
    end function gaussian

    !> Seed the random number generator from an integer.
    subroutine set_seed(seed)
        integer, intent(in) :: seed
        integer :: k, i
        integer, allocatable :: put(:)
        call random_seed(size=k)
        allocate(put(k))
        put = [(104729 * seed + 7919 * i + 1, i = 1, k)]
        call random_seed(put=put)
    end subroutine set_seed

    ! ==================================================================
    ! the simulation

    !> Rolling mean, z-score and outlier flags of a series (window `w`, flags
    !> where |z| > `threshold` if `detect`). Plain Fortran: used by the worker
    !> and by the GUI.
    subroutine statistics(v, w, detect, threshold, mean, z, outlier, noutliers)
        real(dp), intent(in) :: v(:)
        integer, intent(in) :: w
        logical, intent(in) :: detect
        real(dp), intent(in) :: threshold
        real(dp), intent(out) :: mean(:), z(:)
        logical, intent(out) :: outlier(:)
        integer, intent(out) :: noutliers
        real(dp), allocatable :: s1(:), s2(:)
        real(dp) :: m, var
        integer :: i, lo, n
        n = size(v)
        allocate(s1(0:n), s2(0:n))
        s1(0) = 0
        s2(0) = 0
        do i = 1, n                         ! prefix sums
            s1(i) = s1(i - 1) + v(i)
            s2(i) = s2(i - 1) + v(i)**2
        end do
        do i = 1, n
            lo = max(0, i - w)
            m = (s1(i) - s1(lo)) / (i - lo)
            var = max((s2(i) - s2(lo)) / (i - lo) - m * m, 0.0_dp)
            mean(i) = m
            z(i) = 0
            if (var > 0) z(i) = (v(i) - m) / sqrt(var)
        end do
        outlier = detect .and. abs(z) > threshold .and. [(i > w, i = 1, n)]
        noutliers = count(outlier)
    end subroutine statistics

    !> Recompute the statistics of the current series with the detection settings.
    subroutine compute_statistics(s)
        type(lab_t), intent(inout) :: s
        call statistics(s%v, s%window_size%value(), s%detection%isChecked(), s%threshold%value(), &
                        s%mean, s%z, s%outlier, s%noutliers)
    end subroutine compute_statistics

    !> The worker: generate a series with the job's inputs. Runs in its own
    !> thread, so it touches only the job; it reports progress through the
    !> job's signal and stops early if the thread is asked to.
    subroutine simulate(data)
        class(*), intent(inout), optional :: data
        real(dp) :: x, u, spread
        logical, allocatable :: glitch(:)
        integer :: i
        select type (job => data)
        type is (sim_job)
            job%cancelled = .false.
            if (allocated(job%v)) deallocate(job%v, job%mean, job%z, job%outlier)
            allocate(job%v(job%n), job%mean(job%n), job%z(job%n), job%outlier(job%n))
            call set_seed(job%seed)      ! (each thread has its own random numbers)
            x = 0
            do i = 1, job%n
                select case (job%which)
                case (0)        ! random walk
                    if (i > 1) x = x + job%sigma * gaussian()
                case (1)        ! Ornstein-Uhlenbeck: mean-reverting
                    if (i > 1) x = x - 0.02_dp * x + job%sigma * gaussian()
                case default    ! sine + noise
                    x = sin(2 * pi * i / 2000.0_dp) + job%sigma * gaussian()
                end select
                job%v(i) = x
                call random_number(u)
                job%outlier(i) = u < job%rate      ! where to put a glitch (below)
                if (mod(i, chunk) == 0) then
                    call job%progress%emit(int(100.0_dp * i / job%n))   ! delivered on the GUI thread
                    if (QThread_isInterruptionRequested()) then
                        job%cancelled = .true.
                        return
                    end if
                end if
            end do
            ! glitches: 8 times the spread of the clean series about its rolling mean
            if (any(job%outlier)) then
                glitch = job%outlier
                call statistics(job%v, job%window, job%detect, job%threshold, job%mean, job%z, &
                                job%outlier, job%noutliers)
                spread = sqrt(sum((job%v - job%mean)**2) / job%n)
                do i = 1, job%n
                    if (glitch(i)) job%v(i) = job%v(i) + sign(8 * spread, gaussian())
                end do
            end if
            call statistics(job%v, job%window, job%detect, job%threshold, job%mean, job%z, &
                            job%outlier, job%noutliers)
        end select
    end subroutine simulate

    ! ==================================================================
    ! presenting a run

    !> Two column texts for a tree item. (Built in a fixed-length array on
    !> purpose: gfortran 15 miscompiles an array constructor with a type-spec
    !> whose elements include a deferred-length function result, e.g.
    !> [character(len=40) :: 'samples', itoa(n)], overflowing the heap.)
    function row(a, b) result(r)
        character(len=*), intent(in) :: a, b
        character(len=40) :: r(2)
        r(1) = a
        r(2) = b
    end function row

    !> Add a run's summary to the statistics tree (and collapse older runs).
    subroutine add_stats(s, name)
        type(lab_t), intent(inout) :: s
        character(len=*), intent(in) :: name
        type(QTreeWidgetItem) :: run, group, leaf
        call s%stats%collapseAll()
        run = QTreeWidgetItem(s%stats, row(name, ''))
        group = QTreeWidgetItem(run, row('Value', ''))
        leaf = QTreeWidgetItem(group, row('mean', rtoa(sum(s%v) / s%n, 4)))
        leaf = QTreeWidgetItem(group, row('std. deviation', &
                               rtoa(sqrt(max(sum(s%v**2) / s%n - (sum(s%v) / s%n)**2, 0.0_dp)), 4)))
        leaf = QTreeWidgetItem(group, row('minimum', rtoa(minval(s%v), 4)))
        leaf = QTreeWidgetItem(group, row('maximum', rtoa(maxval(s%v), 4)))
        group = QTreeWidgetItem(run, row('Settings', ''))
        leaf = QTreeWidgetItem(group, row('model', s%model%currentText()))
        leaf = QTreeWidgetItem(group, row('samples', itoa(s%n)))
        leaf = QTreeWidgetItem(group, row('noise', rtoa(s%noise%value(), 3)))
        leaf = QTreeWidgetItem(group, row('spike rate', rtoa(s%spikes%value(), 3) // ' %'))
        leaf = QTreeWidgetItem(group, row('seed', itoa(s%seed%value())))
        leaf = QTreeWidgetItem(run, row('Outliers', itoa(s%noutliers)))
        call run%setExpanded(.true.)
        group = run%child(0)
        call group%setExpanded(.true.)
        call s%stats%setCurrentItem(run)
        call s%stats%resizeColumnToContents(0)
    end subroutine add_stats

    !> Show the current data everywhere (table, plot, LCD).
    subroutine show_data(s)
        type(lab_t), intent(inout) :: s
        call s%data_model%setRowCount(s%n)
        call s%data_model%refresh()
        call s%outlier_count%display(s%noutliers)
        call s%plot%update()
    end subroutine show_data

    ! ==================================================================
    ! table model slots

    !> Provide one table cell from the Fortran arrays.
    subroutine on_cell(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        integer :: i
        select type (s => data)
        type is (lab_t)
            i = row + 1
            if (i > s%n) return
            select case (column)
            case (0)
                call request%setInt(i)
            case (1)
                call request%setText(rtoa(s%v(i), 4))
            case (2)
                call request%setText(rtoa(s%mean(i), 4))
            case (3)
                call request%setText(rtoa(s%z(i), 2))
            case (4)
                if (s%outlier(i)) call request%setText('outlier')
            end select
        end select
    end subroutine on_cell

    !> The user edited a cell: accept new values and recompute the statistics.
    subroutine on_cell_edited(row, column, text, data)
        integer, intent(in) :: row, column
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        real(dp) :: x
        integer :: ios
        select type (s => data)
        type is (lab_t)
            if (column /= 1) then
                call s%status%showMessage('Only the value column can be edited', 3000)
                return
            end if
            read(text, *, iostat=ios) x
            if (ios /= 0) then
                call s%status%showMessage('Not a number: ' // text, 3000)
                return
            end if
            s%v(row + 1) = x
            s%edited = .true.
            call compute_statistics(s)
            call show_data(s)
            call log_line(s, 'Edited sample ' // itoa(row + 1) // ' = ' // rtoa(x, 4) // &
                          '; outliers now ' // itoa(s%noutliers))
        end select
    end subroutine on_cell_edited

    ! ==================================================================
    ! the plot

    !> Draw the series (decimated), its rolling mean and the outliers.
    subroutine on_paint(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        real(dp) :: left, right, top, bottom, lo, hi, x, y
        real(dp), allocatable :: xs(:), ys(:), ms(:), ex(:), ey(:)
        integer :: w, h, stride, i, k, np, i2
        select type (s => data)
        type is (lab_t)
            w = painter%deviceWidth()
            h = painter%deviceHeight()
            call painter%fillRect(0, 0, w, h, Qt_white)
            call painter%setRenderHint(QPainter_Antialiasing)
            call painter%setFont(QFont(pointSize=10.0_dp))
            if (s%n == 0) then
                call painter%setPen(Qt_gray)
                call painter%drawText(0, 0, w, h, Qt_AlignCenter, 'Press Run to simulate')
                return
            end if
            left = 60
            right = w - 15
            top = 20
            bottom = h - 30
            lo = minval(s%v)
            hi = max(maxval(s%v), lo + 1.0e-9_dp)

            ! frame and y labels
            call painter%setPen(Qt_lightGray)
            do i = 0, 4
                y = bottom - i * (bottom - top) / 4
                call painter%drawLine(left, y, right, y)
                call painter%setPen(Qt_darkGray)
                call painter%drawText(0.0_dp, y - 8, left - 6, 16.0_dp, ior(Qt_AlignRight, Qt_AlignVCenter), &
                                      rtoa(lo + i * (hi - lo) / 4, 2))
                call painter%setPen(Qt_lightGray)
            end do
            call painter%setPen(Qt_darkGray)
            call painter%drawText(left, bottom + 6, right - left, 18.0_dp, Qt_AlignCenter, &
                                  itoa(s%n) // ' samples, ' // itoa(s%noutliers) // ' outliers')

            ! decimate to at most max_plot_points points
            stride = max(1, s%n / max(1, int(right - left)))   ! about one bucket per pixel
            np = (s%n - 1) / stride + 1
            allocate(xs(np), ys(np), ms(np))
            do k = 1, np
                i = 1 + (k - 1) * stride
                xs(k) = left + (i - 1) * (right - left) / max(1, s%n - 1)
                ys(k) = bottom - (s%v(i) - lo) / (hi - lo) * (bottom - top)
                ms(k) = bottom - (s%mean(i) - lo) / (hi - lo) * (bottom - top)
            end do
            if (s%style%checkedId() == 1) then          ! points
                call painter%setPen(QPen(style=Qt_NoPen))
                call painter%setBrush(s%color)
                do k = 1, np
                    call painter%drawEllipse(xs(k) - 1.5_dp, ys(k) - 1.5_dp, 3.0_dp, 3.0_dp)
                end do
            else                                         ! line: min/max envelope per bucket
                allocate(ex(2 * np), ey(2 * np))         ! (keeps every peak visible)
                do k = 1, np
                    i = 1 + (k - 1) * stride
                    i2 = min(s%n, i + stride - 1)
                    ex(2 * k - 1:2 * k) = xs(k)
                    ey(2 * k - 1) = bottom - (maxval(s%v(i:i2)) - lo) / (hi - lo) * (bottom - top)
                    ey(2 * k) = bottom - (minval(s%v(i:i2)) - lo) / (hi - lo) * (bottom - top)
                end do
                call painter%setPen(QPen(s%color, 1.0_dp))
                call painter%drawPolyline(ex, ey)
            end if
            if (s%detection%isChecked()) then
                call painter%setPen(QPen(QColor(240, 140, 20), 2.0_dp))
                call painter%drawPolyline(xs, ms)
                call painter%setPen(QPen(Qt_darkRed, 1.0_dp))
                call painter%setBrush(QColor(230, 40, 40, 200))
                k = 0
                do i = 1, s%n
                    if (.not. s%outlier(i)) cycle
                    k = k + 1
                    if (k > 5000) exit                   ! enough to see them
                    x = left + (i - 1) * (right - left) / max(1, s%n - 1)
                    y = bottom - (s%v(i) - lo) / (hi - lo) * (bottom - top)
                    call painter%drawEllipse(x - 3, y - 3, 6.0_dp, 6.0_dp)
                end do
            end if
            call painter%setPen(Qt_gray)
            call painter%setBrush(QBrush(style=Qt_NoBrush))
            call painter%drawRect(left, top, right - left, bottom - top)
        end select
    end subroutine on_paint

    ! ==================================================================
    ! commands

    !> Run a simulation with the current settings.
    subroutine on_run(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            if (s%running) return
            s%running = .true.
            call set_running(s, .true.)
            call log_line(s, 'Running ' // s%model%currentText() // ' with ' // itoa(s%samples%value()) // &
                          ' samples (seed ' // itoa(s%seed%value()) // ')')
            ! the worker must not read widgets: copy its inputs now
            s%job%n = s%samples%value()
            s%job%which = s%model%currentIndex()
            s%job%sigma = s%noise%value()
            s%job%rate = s%spikes%value() / 100
            s%job%seed = s%seed%value()
            s%job%window = s%window_size%value()
            s%job%threshold = s%threshold%value()
            s%job%detect = s%detection%isChecked()
            call system_clock(s%t0)
            call s%worker%start()        ! on_finished runs when it is done
        end select
    end subroutine on_run

    !> Progress report from the worker (delivered on the GUI thread).
    subroutine on_progress(percent, data)
        integer, intent(in) :: percent
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            call s%progress%setValue(percent)
        end select
    end subroutine on_progress

    !> The worker returned: show the new series, or keep the old one if cancelled.
    subroutine on_finished(data)
        class(*), intent(inout), optional :: data
        integer(8) :: t1, rate
        character(len=:), allocatable :: name
        select type (s => data)
        type is (lab_t)
            if (.not. s%job%cancelled) then
                call system_clock(t1, rate)
                ! take over the results (the job is not running, so this is safe)
                call move_alloc(s%job%v, s%v)
                call move_alloc(s%job%mean, s%mean)
                call move_alloc(s%job%z, s%z)
                call move_alloc(s%job%outlier, s%outlier)
                s%n = s%job%n
                s%noutliers = s%job%noutliers
                s%nruns = s%nruns + 1
                name = 'Run ' // itoa(s%nruns) // ': ' // s%model%currentText()
                call s%runs%addItem(name // ' (' // itoa(s%n) // ', ' // itoa(s%noutliers) // ' outliers)')
                call s%runs%setCurrentRow(s%runs%count() - 1)
                call add_stats(s, name)
                s%edited = .false.
                call show_data(s)
                call log_line(s, 'Done in ' // rtoa(real(t1 - s%t0, dp) / rate, 3) // ' s: ' // &
                              itoa(s%noutliers) // ' outliers')
                call s%status%showMessage(name // ' finished', 4000)
            else
                call log_line(s, 'Cancelled')
                call s%status%showMessage('Cancelled', 3000)
            end if
            call set_running(s, .false.)
            s%running = .false.
            if (allocated(s%screenshot)) call QTimer_singleShot(400, on_screenshot, s)
        end select
    end subroutine on_finished

    !> Enable or disable the controls while a run is in progress.
    subroutine set_running(s, running)
        type(lab_t), intent(inout) :: s
        logical, intent(in) :: running
        call s%run_action%setEnabled(.not. running)
        call s%run_button%setEnabled(.not. running)
        call s%cancel_action%setEnabled(running)
        call s%cancel_button%setEnabled(running)
        call s%progress%setValue(merge(0, 100, running))
    end subroutine set_running

    !> Ask a running simulation to stop.
    subroutine on_cancel(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            call s%worker%requestInterruption()
        end select
    end subroutine on_cancel

    !> Rename the selected run (also on double-click).
    subroutine on_rename(data)
        class(*), intent(inout), optional :: data
        integer :: row
        logical :: ok
        character(len=:), allocatable :: name
        type(QTreeWidgetItem) :: item
        select type (s => data)
        type is (lab_t)
            row = s%runs%currentRow()
            if (row < 0) then
                call s%status%showMessage('Select a run first', 3000)
                return
            end if
            name = QInputDialog_getText('Rename run', 'Name:', s%runs%itemText(row), ok, parent=s%window)
            if (.not. ok .or. name == '') return
            call s%runs%setItemText(row, name)
            item = s%stats%topLevelItem(row)
            if (.not. item%isNull()) call item%setText(0, name)
            call log_line(s, 'Renamed run ' // itoa(row + 1) // ' to "' // name // '"')
        end select
    end subroutine on_rename

    !> Rename on double-click in the run list.
    subroutine on_run_double_clicked(row, data)
        integer, intent(in) :: row
        class(*), intent(inout), optional :: data
        call on_rename(data)
    end subroutine on_run_double_clicked

    !> Show the selected run's statistics.
    subroutine on_run_selected(row, data)
        integer, intent(in) :: row
        class(*), intent(inout), optional :: data
        type(QTreeWidgetItem) :: item
        select type (s => data)
        type is (lab_t)
            if (row < 0) return
            item = s%stats%topLevelItem(row)
            if (item%isNull()) return
            call s%stats%collapseAll()
            call item%setExpanded(.true.)
            call s%stats%setCurrentItem(item)
        end select
    end subroutine on_run_selected

    !> Choose the plot color.
    subroutine on_color(data)
        class(*), intent(inout), optional :: data
        type(QColor) :: c
        select type (s => data)
        type is (lab_t)
            c = QColorDialog_getColor(s%color, 'Plot color', parent=s%window)
            if (.not. c%isValid()) return
            s%color = c
            call s%plot%update()
            call s%tabs%setCurrentIndex(1)
        end select
    end subroutine on_color

    !> Export the current run as CSV.
    subroutine on_export(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        integer :: u, i, ios, button
        select type (s => data)
        type is (lab_t)
            if (s%n == 0) then
                button = QMessageBox_information('Export', 'Nothing to export yet: press Run first.', &
                                                 parent=s%window)
                return
            end if
            path = QFileDialog_getSaveFileName('Export CSV', 'timeseries.csv', 'CSV files (*.csv)', parent=s%window)
            if (path == '') return
            open(newunit=u, file=path, status='replace', action='write', iostat=ios)
            if (ios /= 0) then
                button = QMessageBox_warning('Export', 'Could not write ' // path, parent=s%window)
                return
            end if
            write(u, '(A)') 'index,value,mean,zscore,outlier'
            do i = 1, s%n
                write(u, '(I0,3(",",ES16.8),",",I0)') i, s%v(i), s%mean(i), s%z(i), merge(1, 0, s%outlier(i))
            end do
            close(u)
            s%edited = .false.
            call log_line(s, 'Exported ' // itoa(s%n) // ' rows to ' // path)
            call s%status%showMessage('Exported ' // path, 4000)
        end select
    end subroutine on_export

    !> Detection settings changed: recompute flags for the current data.
    subroutine on_detection_changed(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            if (s%n == 0 .or. s%running) return
            call compute_statistics(s)
            call show_data(s)
        end select
    end subroutine on_detection_changed

    !> Detection settings changed (integer signal).
    subroutine on_detection_int(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        call on_detection_changed(data)
    end subroutine on_detection_int

    !> Detection settings changed (real signal).
    subroutine on_detection_real(value, data)
        real(dp), intent(in) :: value
        class(*), intent(inout), optional :: data
        call on_detection_changed(data)
    end subroutine on_detection_real

    !> Detection enabled or disabled.
    subroutine on_detection_toggled(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        call on_detection_changed(data)
    end subroutine on_detection_toggled

    !> Show the seed on the LCD.
    subroutine on_seed(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            call s%seed_display%display(value)
        end select
    end subroutine on_seed

    !> Plot style changed.
    subroutine on_style(id, data)
        integer, intent(in) :: id
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            call s%points_action%setChecked(id == 1)
            call s%plot%update()
        end select
    end subroutine on_style

    !> Plot context menu: switch between lines and points.
    subroutine on_points_toggled(checked, data)
        logical, intent(in) :: checked
        class(*), intent(inout), optional :: data
        type(QAbstractButton) :: button
        select type (s => data)
        type is (lab_t)
            button = s%style%button(merge(1, 0, checked))
            call button%setChecked(.true.)
            call s%plot%update()
        end select
    end subroutine on_points_toggled

    !> Right click on the plot: show its context menu at the cursor.
    subroutine on_plot_menu(event, data)
        type(QContextMenuEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            call s%plot_menu%popup(event%globalX(), event%globalY())
        end select
    end subroutine on_plot_menu

    !> Save the plot as an image file.
    subroutine on_save_plot(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: path
        type(QPixmap) :: pix
        integer :: button
        select type (s => data)
        type is (lab_t)
            path = QFileDialog_getSaveFileName('Save plot', 'plot.png', 'Images (*.png *.jpg *.bmp)', &
                                               parent=s%window)
            if (path == '') return
            pix = s%plot%grab()
            if (pix%save(path)) then
                call log_line(s, 'Saved the plot to ' // path)
            else
                button = QMessageBox_warning('Save plot', 'Could not write ' // path, parent=s%window)
            end if
            call pix%delete()
        end select
    end subroutine on_save_plot

    !> Report the selected tab.
    subroutine on_tab(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            call s%status%showMessage(s%tabs%tabText(index), 1500)
        end select
    end subroutine on_tab

    !> Preset: a long random walk.
    subroutine on_preset_walk(data)
        class(*), intent(inout), optional :: data
        call apply_preset(data, 0, 1000000, 1.0_dp, 0.01_dp, 100, 5.0_dp)
    end subroutine on_preset_walk

    !> Preset: a mean-reverting process.
    subroutine on_preset_ou(data)
        class(*), intent(inout), optional :: data
        call apply_preset(data, 1, 20000, 0.5_dp, 0.1_dp, 200, 4.5_dp)
    end subroutine on_preset_ou

    !> Preset: a noisy sine wave.
    subroutine on_preset_sine(data)
        class(*), intent(inout), optional :: data
        call apply_preset(data, 2, 20000, 0.1_dp, 0.2_dp, 50, 4.0_dp)
    end subroutine on_preset_sine

    !> Set the parameters of a preset.
    subroutine apply_preset(data, model, n, noise, spikes, window, threshold)
        class(*), intent(inout), optional :: data
        integer, intent(in) :: model, n, window
        real(dp), intent(in) :: noise, spikes, threshold
        select type (s => data)
        type is (lab_t)
            call s%model%setCurrentIndex(model)
            call s%samples%setValue(n)
            call s%noise%setValue(noise)
            call s%spikes%setValue(spikes)
            call s%window_size%setValue(window)
            call s%threshold%setValue(threshold)
            call s%detection%setChecked(.true.)
            call s%status%showMessage('Preset: ' // s%model%currentText() // ' - press Run', 3000)
        end select
    end subroutine apply_preset

    !> Clear the log.
    subroutine on_clear_log(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            call s%log%clear()
        end select
    end subroutine on_clear_log

    !> Show the about box.
    subroutine on_about(data)
        class(*), intent(inout), optional :: data
        integer :: button
        select type (s => data)
        type is (lab_t)
            button = QMessageBox_information('About Time Series Lab', &
                'Time Series Lab' // new_line('a') // new_line('a') // &
                'Simulates a stochastic process and flags outliers with a rolling' // new_line('a') // &
                'z-score. Written in Modern Fortran with qt-fortran.', parent=s%window)
        end select
    end subroutine on_about

    !> Quit: close the main window (which asks first if needed, see on_close).
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (lab_t)
            call s%window%close()
        end select
    end subroutine on_quit

    !> The main window is closing: confirm if work would be lost (`event%ignore()`
    !> keeps the window open), stop a running simulation and save the settings.
    subroutine on_close(event, data)
        type(QCloseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: question
        select type (s => data)
        type is (lab_t)
            if (allocated(s%screenshot)) return
            if (s%running) then
                question = 'A simulation is running. Stop it and quit?'
            else if (s%edited) then
                question = 'The edited values have not been exported. Quit anyway?'
            end if
            if (allocated(question)) then
                if (QMessageBox_question('Quit Time Series Lab', question, parent=s%window) /= QMessageBox_Yes) then
                    call event%ignore()
                    return
                end if
            end if
            call s%worker%requestInterruption()   ! the window waits for it when deleted
            call save_settings(s)
        end select
    end subroutine on_close

    ! ==================================================================
    ! settings (QSettings; the store is chosen by the organization and
    ! application names set in the main program)

    !> Restore the window layout and the parameters of the last session.
    subroutine load_settings(s)
        type(lab_t), intent(inout) :: s
        type(QSettings) :: settings
        type(QAbstractButton) :: button
        logical :: ok
        settings = QSettings()
        ! (both return .false., leaving the window as it is, on the first run)
        ok = s%window%restoreGeometry(settings%stringValue('window/geometry'))
        ok = s%window%restoreState(settings%stringValue('window/state'))
        call settings%beginGroup('parameters')
        call s%model%setCurrentIndex(settings%intValue('model', s%model%currentIndex()))
        call s%samples%setValue(settings%intValue('samples', s%samples%value()))
        call s%noise%setValue(settings%doubleValue('noise', s%noise%value()))
        call s%spikes%setValue(settings%doubleValue('spikes', s%spikes%value()))
        call s%detection%setChecked(settings%boolValue('detection', s%detection%isChecked()))
        call s%window_size%setValue(settings%intValue('window', s%window_size%value()))
        call s%threshold%setValue(settings%doubleValue('threshold', s%threshold%value()))
        call s%seed%setValue(settings%intValue('seed', s%seed%value()))
        call settings%endGroup()
        call settings%beginGroup('plot')
        button = s%style%button(settings%intValue('style', 0))
        if (.not. button%isNull()) call button%setChecked(.true.)
        call s%points_action%setChecked(s%style%checkedId() == 1)
        s%color = QColor(settings%intValue('red', s%color%r), settings%intValue('green', s%color%g), &
                         settings%intValue('blue', s%color%b))
        call settings%endGroup()
        call settings%delete()
    end subroutine load_settings

    !> Remember the window layout and the parameters for the next session.
    subroutine save_settings(s)
        type(lab_t), intent(inout) :: s
        type(QSettings) :: settings
        settings = QSettings()
        call settings%setValue('window/geometry', s%window%saveGeometry())
        call settings%setValue('window/state', s%window%saveState())
        call settings%beginGroup('parameters')
        call settings%setValue('model', s%model%currentIndex())
        call settings%setValue('samples', s%samples%value())
        call settings%setValue('noise', s%noise%value())
        call settings%setValue('spikes', s%spikes%value())
        call settings%setValue('detection', s%detection%isChecked())
        call settings%setValue('window', s%window_size%value())
        call settings%setValue('threshold', s%threshold%value())
        call settings%setValue('seed', s%seed%value())
        call settings%endGroup()
        call settings%beginGroup('plot')
        call settings%setValue('style', s%style%checkedId())
        call settings%setValue('red', s%color%r)
        call settings%setValue('green', s%color%g)
        call settings%setValue('blue', s%color%b)
        call settings%endGroup()
        call settings%delete()    ! writes the changes
    end subroutine save_settings

    !> --screenshot: show the plot tab, save the window and quit.
    subroutine on_screenshot(data)
        class(*), intent(inout), optional :: data
        type(QPixmap) :: pix
        select type (s => data)
        type is (lab_t)
            pix = s%window%grab()
            if (.not. pix%save(s%screenshot)) write(*,'(A)') 'could not save ' // s%screenshot
            call pix%delete()
            call QApplication_quit()
        end select
    end subroutine on_screenshot

    ! ==================================================================
    ! construction

    !> Create an action connected to `slot`.
    function new_action(s, text, shortcut, slot) result(a)
        type(lab_t), intent(inout), target :: s
        character(len=*), intent(in) :: text, shortcut
        procedure(qt_slot) :: slot
        type(QAction) :: a
        a = QAction(text, s%window)
        if (shortcut /= '') call a%setShortcut(shortcut)
        call a%triggered%connect(slot, s)
    end function new_action

    !> Build the parameter panel (in the dock).
    function build_panel(s) result(panel)
        type(lab_t), intent(inout), target :: s
        type(QWidget) :: panel
        type(QVBoxLayout) :: vbox
        type(QFormLayout) :: form, detection_form
        type(QGroupBox) :: simulation, seed_box, style_box
        type(QHBoxLayout) :: seed_row, style_row, buttons
        type(QRadioButton) :: line, points

        panel = QWidget()
        vbox = QVBoxLayout(panel)

        ! simulation parameters
        simulation = QGroupBox('Simulation')
        form = QFormLayout(simulation)
        s%model = QComboBox()
        call s%model%addItems(model_names)
        call s%model%setCurrentIndex(1)
        call form%addRow('Model', s%model)
        s%samples = QSpinBox()
        call s%samples%setRange(1000, 5000000)
        call s%samples%setSingleStep(10000)
        call s%samples%setValue(20000)
        call form%addRow('Samples', s%samples)
        s%noise = QDoubleSpinBox()
        call s%noise%setRange(0.0_dp, 5.0_dp)
        call s%noise%setSingleStep(0.1_dp)
        call s%noise%setValue(0.5_dp)
        call form%addRow('Noise', s%noise)
        s%spikes = QDoubleSpinBox()
        call s%spikes%setRange(0.0_dp, 5.0_dp)
        call s%spikes%setDecimals(3)
        call s%spikes%setSingleStep(0.01_dp)
        call s%spikes%setValue(0.1_dp)
        call s%spikes%setSuffix(' %')
        call s%spikes%setToolTip('Fraction of samples hit by a glitch (8 times the series spread)')
        call form%addRow('Spike rate', s%spikes)
        call vbox%addWidget(simulation)

        ! outlier detection (checkable group: unchecking disables its fields)
        s%detection = QGroupBox('Outlier detection')
        call s%detection%setCheckable(.true.)
        detection_form = QFormLayout(s%detection)
        s%window_size = QSpinBox()
        call s%window_size%setRange(5, 5000)
        call s%window_size%setValue(200)
        call s%window_size%setSuffix(' samples')
        call detection_form%addRow('Rolling window', s%window_size)
        s%threshold = QDoubleSpinBox()
        call s%threshold%setRange(1.0_dp, 8.0_dp)
        call s%threshold%setSingleStep(0.25_dp)
        call s%threshold%setValue(4.5_dp)
        call s%threshold%setPrefix('|z| > ')
        call detection_form%addRow('Threshold', s%threshold)
        call vbox%addWidget(s%detection)

        ! seed: dial + LCD
        seed_box = QGroupBox('Random seed')
        seed_row = QHBoxLayout(seed_box)
        s%seed = QDial()
        call s%seed%setRange(0, 99)
        call s%seed%setWrapping(.true.)
        call s%seed%setNotchesVisible(.true.)
        call s%seed%setFixedSize(70, 70)
        s%seed_display = QLCDNumber(2)
        call s%seed_display%setSegmentStyle(QLCDNumber_Flat)
        call s%seed_display%setMinimumSize(70, 40)
        call seed_row%addWidget(s%seed)
        call seed_row%addWidget(s%seed_display, stretch=1)
        call vbox%addWidget(seed_box)

        ! plot style: exclusive radio buttons with ids
        style_box = QGroupBox('Plot style')
        style_row = QHBoxLayout(style_box)
        line = QRadioButton('Line')
        points = QRadioButton('Points')
        call line%setChecked(.true.)
        s%style = QButtonGroup(s%window)
        call s%style%addButton(line, 0)
        call s%style%addButton(points, 1)
        call style_row%addWidget(line)
        call style_row%addWidget(points)
        call vbox%addWidget(style_box)

        ! run / cancel / progress
        buttons = QHBoxLayout()
        s%run_button = QPushButton('Run')
        s%cancel_button = QPushButton('Cancel')
        call s%cancel_button%setEnabled(.false.)
        call buttons%addWidget(s%run_button)
        call buttons%addWidget(s%cancel_button)
        call vbox%addLayout(buttons)
        s%progress = QProgressBar()
        call s%progress%setValue(0)
        call vbox%addWidget(s%progress)
        call vbox%addStretch()

        call s%model%currentIndexChanged%connect(on_detection_int, s)
        call s%window_size%valueChanged%connect(on_detection_int, s)
        call s%threshold%valueChanged%connect(on_detection_real, s)
        call s%detection%toggled%connect(on_detection_toggled, s)
        call s%seed%valueChanged%connect(on_seed, s)
        call s%seed%setValue(42)
        call s%style%idClicked%connect(on_style, s)
        call s%run_button%clicked%connect(on_run, s)
        call s%cancel_button%clicked%connect(on_cancel, s)
    end function build_panel

    !> Build the tabs: data (table + runs), plot, statistics, log.
    subroutine build_tabs(s)
        type(lab_t), intent(inout), target :: s
        type(QSplitter) :: split
        type(QWidget) :: stats_page
        type(QVBoxLayout) :: stats_box
        type(QHBoxLayout) :: count_row

        s%tabs = QTabWidget()

        ! Data: the table (served from the Fortran arrays) and the run list
        s%data_model = QtfTableModel(0, size(columns), s%window)
        call s%data_model%setHorizontalHeaderLabels(columns)
        call s%data_model%setEditable(.true.)
        call s%data_model%dataRequested%connect(on_cell, s)
        call s%data_model%dataEdited%connect(on_cell_edited, s)
        s%table = QTableView()
        call s%table%setModel(s%data_model)
        call s%table%setAlternatingRowColors(.true.)
        call s%table%setSelectionBehavior(QAbstractItemView_SelectRows)
        call s%table%setStretchLastSection(.true.)
        call s%table%setVerticalHeaderVisible(.false.)
        s%runs = QListWidget()
        split = QSplitter(Qt_Horizontal)
        call split%addWidget(s%table)
        call split%addWidget(s%runs)
        call split%setStretchFactor(0, 3)
        call split%setStretchFactor(1, 1)
        call s%tabs%addTab(split, 'Data')

        ! Plot
        s%plot = QtfWidget()
        call s%plot%paintEvent%connect(on_paint, s)
        call s%tabs%addTab(s%plot, 'Plot')

        ! Statistics: a tree per run and a big outlier count
        stats_page = QWidget()
        stats_box = QVBoxLayout(stats_page)
        s%stats = QTreeWidget()
        call s%stats%setColumnCount(2)
        call s%stats%setHeaderLabels([character(len=8) :: 'Quantity', 'Value'])
        call s%stats%setAlternatingRowColors(.true.)
        call stats_box%addWidget(s%stats, stretch=1)
        count_row = QHBoxLayout()
        s%outlier_count = QLCDNumber(8)
        call s%outlier_count%setSegmentStyle(QLCDNumber_Flat)
        call s%outlier_count%setMinimumSize(220, 60)
        call count_row%addWidget(QLabel('<b>Outliers in the current run</b>'))
        call count_row%addStretch()
        call count_row%addWidget(s%outlier_count)
        call stats_box%addLayout(count_row)
        call s%tabs%addTab(stats_page, 'Statistics')

        ! Log console
        s%log = QPlainTextEdit()
        call s%log%setReadOnly(.true.)
        call s%log%setMaximumBlockCount(1000)
        call s%log%setPlaceholderText('Messages appear here')
        call s%tabs%addTab(s%log, 'Log')

        call s%runs%currentRowChanged%connect(on_run_selected, s)
        call s%runs%itemDoubleClicked%connect(on_run_double_clicked, s)
        call s%tabs%currentChanged%connect(on_tab, s)
    end subroutine build_tabs

    !> Build the main window.
    subroutine build(s)
        type(lab_t), intent(inout), target :: s
        type(QMenuBar) :: bar
        type(QMenu) :: file_menu, run_menu, view_menu, help_menu, presets
        type(QToolBar) :: tools
        type(QToolButton) :: preset_button
        type(QAction) :: export, quit, rename, color, clear_log, about, walk, ou, sine, save_plot

        s%window = QMainWindow()
        call s%window%setWindowTitle('Time Series Lab - qt-fortran')
        s%status = s%window%statusBar()

        call build_tabs(s)
        call s%window%setCentralWidget(s%tabs)

        s%dock = QDockWidget('Parameters', s%window)
        call s%dock%setWidget(build_panel(s))
        call s%dock%setObjectName('parameters')    ! saveState identifies docks and tool bars by name
        call s%dock%setFeatures(ior(QDockWidget_DockWidgetMovable, QDockWidget_DockWidgetFloatable))
        call s%window%addDockWidget(Qt_LeftDockWidgetArea, s%dock)

        ! actions
        s%run_action = new_action(s, '&Run', 'Ctrl+R', on_run)
        s%cancel_action = new_action(s, '&Cancel', 'Ctrl+.', on_cancel)
        call s%cancel_action%setEnabled(.false.)
        export = new_action(s, '&Export CSV...', 'Ctrl+E', on_export)
        quit = new_action(s, '&Quit', 'Ctrl+Q', on_quit)
        rename = new_action(s, 'Re&name run...', 'Ctrl+N', on_rename)
        color = new_action(s, 'Plot &color...', '', on_color)
        clear_log = new_action(s, 'C&lear log', '', on_clear_log)
        about = new_action(s, '&About', '', on_about)
        walk = new_action(s, 'Long random walk', '', on_preset_walk)
        ou = new_action(s, 'Mean-reverting (OU)', '', on_preset_ou)
        sine = new_action(s, 'Noisy sine', '', on_preset_sine)
        save_plot = new_action(s, '&Save plot as image...', '', on_save_plot)

        ! menus
        bar = s%window%menuBar()
        file_menu = bar%addMenu('&File')
        call file_menu%addAction(export)
        call file_menu%addSeparator()
        call file_menu%addAction(quit)
        run_menu = bar%addMenu('&Run')
        call run_menu%addAction(s%run_action)
        call run_menu%addAction(s%cancel_action)
        call run_menu%addSeparator()
        call run_menu%addAction(rename)
        view_menu = bar%addMenu('&View')
        call view_menu%addAction(s%dock%toggleViewAction())
        call view_menu%addAction(color)
        call view_menu%addAction(clear_log)
        help_menu = bar%addMenu('&Help')
        call help_menu%addAction(about)

        ! toolbar, with a tool button that pops up the presets
        presets = QMenu('Presets', s%window)
        call presets%addAction(walk)
        call presets%addAction(ou)
        call presets%addAction(sine)
        preset_button = QToolButton()
        call preset_button%setText('Presets')
        call preset_button%setMenu(presets)
        call preset_button%setPopupMode(QToolButton_InstantPopup)
        tools = s%window%addToolBar('Main')
        call tools%setObjectName('main')
        call tools%addAction(s%run_action)
        call tools%addAction(s%cancel_action)
        call tools%addSeparator()
        call tools%addWidget(preset_button)
        call tools%addSeparator()
        call tools%addAction(export)
        call tools%addAction(color)

        ! plot context menu (right click)
        s%points_action = QAction('Draw &points', s%window)
        call s%points_action%setCheckable(.true.)
        call s%points_action%toggled%connect(on_points_toggled, s)
        s%plot_menu = QMenu('Plot', s%window)
        call s%plot_menu%addAction(s%points_action)
        call s%plot_menu%addAction(color)
        call s%plot_menu%addSeparator()
        call s%plot_menu%addAction(save_plot)
        call s%plot%contextMenuEvent%connect(on_plot_menu, s)

        call s%window%closeEvent%connect(on_close, s)

        ! the worker thread: runs `simulate` on s%job, reports progress, then `finished`
        s%job%progress = QSignalInt(s%window)
        call s%job%progress%connect(on_progress, s)
        s%worker = QThread_create(simulate, s%job, s%window)
        call s%worker%finished%connect(on_finished, s)
    end subroutine build

end module timeseries_app

!> Time Series Lab (see the module documentation).
program timeseries

    use qt
    use timeseries_app
    implicit none

    type(QApplication) :: app
    type(lab_t), target :: s
    character(len=1024) :: arg
    integer :: ierr, tab

    app = QApplication()
    call QApplication_setOrganizationName('qt-fortran')
    call QApplication_setApplicationName('Time Series Lab')
    call build(s)
    call s%window%resize(1200, 760)
    call log_line(s, 'Ready. Set the parameters and press Run.')

    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        tab = 1
        call get_command_argument(3, arg)
        if (arg == '--tab') then
            call get_command_argument(4, arg)
            read(arg, *) tab
        end if
        call s%tabs%setCurrentIndex(tab)
        call QTimer_singleShot(100, on_run, s)
    else
        call load_settings(s)    ! (not for screenshots, which use the defaults)
    end if

    call s%window%show()
    ierr = app%exec()

end program timeseries
