!> Worker threads (QThread_create): running Fortran work off the GUI thread,
!> progress through Fortran-defined signals, cancelling, restarting, waiting
!> and deleting a running thread. Run headless with QT_QPA_PLATFORM=offscreen.
module test_threads_work

    use qt
    use iso_c_binding, only: c_associated, c_double
    implicit none

    !> A job: inputs, results, and the signal it reports progress through.
    type :: job_t
        integer :: n = 0                     !! input: number of terms
        integer :: delay = 0                 !! input: msecs to sleep per chunk
        real(c_double) :: total = 0          !! result
        logical :: cancelled = .false.       !! result
        integer :: runs = 0                  !! result: times the work ran
        logical :: on_worker = .false.       !! the work did not run on the GUI thread
        type(QSignalInt) :: progress         !! percent done (emitted by the worker)
        ! seen on the GUI thread
        type(QThread) :: gui
        integer :: reports = 0, last = -1
        logical :: reports_on_gui = .true.
        integer :: finished = 0
    end type job_t

contains

    !> The work: sum 1/k^2 in chunks, reporting progress and honouring cancellation.
    subroutine work(data)
        class(*), intent(inout), optional :: data
        type(QThread) :: me
        integer :: k
        select type (job => data)
        type is (job_t)
            job%runs = job%runs + 1
            job%total = 0
            job%cancelled = .false.
            me = QThread_currentThread()
            job%on_worker = .not. c_associated(me%ptr, job%gui%ptr)
            do k = 1, job%n
                job%total = job%total + 1.0_c_double / real(k, c_double)**2
                if (mod(k, job%n / 10) == 0) then
                    call job%progress%emit(100 * k / job%n)
                    if (job%delay > 0) call QThread_msleep(job%delay)
                    if (QThread_isInterruptionRequested()) then
                        job%cancelled = .true.
                        return
                    end if
                end if
            end do
        end select
    end subroutine work

    !> Progress slot (GUI thread).
    subroutine on_progress(percent, data)
        integer, intent(in) :: percent
        class(*), intent(inout), optional :: data
        type(QThread) :: here
        select type (job => data)
        type is (job_t)
            here = QThread_currentThread()
            job%reports_on_gui = job%reports_on_gui .and. c_associated(here%ptr, job%gui%ptr)
            job%reports = job%reports + 1
            job%last = percent
        end select
    end subroutine on_progress

    !> The work returned (GUI thread): leave the event loop.
    subroutine on_finished(data)
        class(*), intent(inout), optional :: data
        select type (job => data)
        type is (job_t)
            job%finished = job%finished + 1
        end select
        call QApplication_quit()
    end subroutine on_finished

    !> Ask the thread to stop.
    subroutine on_cancel(data)
        class(*), intent(inout), optional :: data
        select type (thread => data)
        type is (QThread)
            call thread%requestInterruption()
        end select
    end subroutine on_cancel

end module test_threads_work

!> Tests QThread_create and cross-thread signals.
program test_threads

    use qt
    use testing
    use test_threads_work
    use iso_c_binding, only: c_double
    implicit none

    real(c_double), parameter :: pi = acos(-1.0_c_double)
    type(QApplication) :: app
    type(QObject) :: owner
    type(QThread), target :: thread, other
    type(job_t), target :: job, job2
    integer :: ierr, n0

    app = QApplication()
    n0 = qt_slot_count()
    owner = QObject()
    call check(QThread_idealThreadCount() >= 1, 'idealThreadCount')

    job%gui = QThread_currentThread()
    job%n = 2000000
    job%progress = QSignalInt(owner)
    call job%progress%connect(on_progress, job)
    thread = QThread_create(work, job, owner)
    call thread%finished%connect(on_finished, job)
    call check(.not. thread%isRunning() .and. .not. thread%isFinished(), 'not started')

    ! --- run to completion inside the event loop
    call thread%start()
    ierr = app%exec()
    call check(job%finished == 1 .and. thread%isFinished(), 'finished delivered')
    call check(job%on_worker, 'work ran on another thread')
    call check(job%reports == 10 .and. job%last == 100, 'progress reports')
    call check(job%reports_on_gui, 'progress slots ran on the GUI thread')
    call check(abs(job%total - pi**2 / 6) < 1.0e-6_c_double .and. .not. job%cancelled, 'result')

    ! --- start again; cancel from the GUI after a while
    job%delay = 30
    job%reports = 0
    call QTimer_singleShot(100, on_cancel, thread)
    call thread%start()
    call check(thread%isRunning(), 'isRunning')
    ierr = app%exec()
    call check(job%runs == 2 .and. job%finished == 2, 'restarted')
    call check(job%cancelled .and. job%reports < 10, 'cancelled')

    ! --- wait() blocks until the work returns; finished arrives with the next events
    job%delay = 0
    call thread%start()
    call thread%wait()
    call check(thread%isFinished() .and. job%runs == 3 .and. .not. job%cancelled, 'wait')
    call QApplication_processEvents()
    call check(job%finished == 3, 'finished after wait')

    ! --- deleting a running thread interrupts it and waits
    job2%gui = job%gui
    job2%n = 1000000000
    job2%delay = 20
    job2%progress = QSignalInt(owner)
    other = QThread_create(work, job2)
    call other%start()
    call QThread_msleep(50)
    call other%delete()
    call check(job2%runs == 1 .and. job2%cancelled, 'delete interrupts and waits')

    call owner%delete()
    call check(qt_slot_count() == n0, 'slots released')

    write(*,'(A)') 'test_threads: all checks passed'

end program test_threads
