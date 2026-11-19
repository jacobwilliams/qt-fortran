!> Application paths, QTemporaryDir, QSaveFile, JSON (QJsonDocument,
!> QJsonObject, QJsonArray, QJsonValue) and QtNetwork (QNetworkAccessManager
!> with file: and data: URLs, so no network is needed). Run headless with
!> QT_QPA_PLATFORM=offscreen.
module test_json_network_slots

    use qt
    implicit none

    !> What the reply slots saw.
    type :: reply_log
        type(QNetworkReply) :: reply
        integer :: finished = 0, progress = 0
        character(len=:), allocatable :: body
    end type reply_log

contains

    !> A reply finished: keep its body, stop the event loop.
    subroutine on_finished(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (reply_log)
            data%finished = data%finished + 1
            data%body = data%reply%readAll()
        end select
        call QApplication_quit()
    end subroutine on_finished

    !> Count progress reports.
    subroutine on_progress(received, total, data)
        integer, intent(in) :: received, total
        class(*), intent(inout), optional :: data
        select type (data)
        type is (reply_log)
            data%progress = data%progress + 1
        end select
    end subroutine on_progress

    !> Stop a hung event loop.
    subroutine on_timeout(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_timeout

end module test_json_network_slots

!> Tests for the core additions: paths, files, JSON and networking.
program test_json_network

    use qt
    use testing
    use test_json_network_slots
    use iso_c_binding, only: c_double, c_long_long
    implicit none

    type(QApplication) :: app
    type(reply_log), target :: log
    character(len=:), allocatable :: dir, exe, exe_dir
    logical :: found

    app = QApplication()

    ! (not checked by name: Windows may report a short 8.3 path)
    exe = QCoreApplication_applicationFilePath()
    exe_dir = QCoreApplication_applicationDirPath()
    inquire(file=exe, exist=found)
    if (.not. found .or. index(exe, exe_dir) /= 1) print '(4A)', 'applicationFilePath: ', exe, ', dir: ', exe_dir
    call check(len(exe) > 0 .and. found, 'applicationFilePath: the program file')
    call check(len(exe_dir) > 0 .and. index(exe, exe_dir) == 1, 'applicationDirPath: its directory')

    call test_files()
    call test_json()
    call test_network()

contains

    !> QTemporaryDir and QSaveFile.
    subroutine test_files()
        type(QTemporaryDir) :: tmp, tmp2
        type(QSaveFile) :: f
        character(len=:), allocatable :: path, text
        real(c_double) :: values(3), back(3)
        integer :: u, ios, n
        logical :: exists

        tmp = QTemporaryDir()
        call check(tmp%isValid() .and. QDir_exists(tmp%path()), 'QTemporaryDir created')
        dir = tmp%path()
        call check(tmp%filePath('a.txt') == dir//'/a.txt', 'filePath')
        call check(tmp%autoRemove(), 'autoRemove by default')

        ! QSaveFile: text, binary with a byte count, raw arrays
        path = tmp%filePath('out.bin')
        f = QSaveFile(path)
        call check(f%open(), 'QSaveFile open')
        call check(f%isOpen() .and. f%fileName() == path, 'isOpen, fileName')
        call check(f%write('header'//achar(0)//achar(255)//'tail', 8) == 8_c_long_long, 'write with a byte count')
        values = [1.5_c_double, -2.0_c_double, 1.0e300_c_double]
        call check(f%writeDoubles(values) == 24_c_long_long, 'writeDoubles')
        call check(f%writeInts([7, 8]) == 8_c_long_long, 'writeInts')
        inquire(file=path, exist=exists)
        call check(.not. exists, 'nothing at the target before commit')
        call check(f%commit(), 'commit')
        call f%delete()
        open(newunit=u, file=path, access='stream', form='unformatted', status='old', action='read', iostat=ios)
        call check(ios == 0, 'the target exists after commit')
        allocate(character(len=8) :: text)
        read(u) text
        read(u) back
        close(u)
        call check(text == 'header'//achar(0)//achar(255), 'binary bytes written as they are')
        call check(all(back == values), 'doubles written raw')

        ! cancelWriting leaves the target unchanged
        f = QSaveFile(path)
        call check(f%open(ior(QIODevice_WriteOnly, QIODevice_Text)), 'open (text)')
        n = int(f%write('replacement'))
        call f%cancelWriting()
        call check(.not. f%commit(), 'commit after cancelWriting fails')
        call f%delete()
        open(newunit=u, file=path, access='stream', form='unformatted', status='old', action='read')
        read(u) text
        close(u)
        call check(text(1:6) == 'header', 'cancelWriting: target unchanged')

        f = QSaveFile(tmp%filePath('no-such-dir/x.txt'))
        call check(.not. f%open() .and. len(f%errorString()) > 0, 'open fails in a missing directory')
        call f%delete()

        call tmp%delete()
        call check(.not. QDir_exists(dir), 'QTemporaryDir removed on delete')

        tmp2 = QTemporaryDir(QDir_tempPath()//'/qtf-test-XXXXXX')
        call check(tmp2%isValid() .and. index(tmp2%path(), 'qtf-test-') > 0, 'QTemporaryDir from a template')
        call tmp2%setAutoRemove(.false.)
        dir = tmp2%path()
        call tmp2%delete()
        call check(QDir_exists(dir), 'setAutoRemove(.false.) keeps it')
        call check(QDir_removeRecursively(dir), 'clean up')
    end subroutine test_files

    !> JSON: build, write, parse, read back.
    subroutine test_json()
        type(QJsonDocument) :: doc, doc2
        type(QJsonObject) :: obj, inner, back, inner_back
        type(QJsonArray) :: arr, arr_back
        type(QJsonValue) :: v
        type(qt_string), allocatable :: keys(:)
        real(c_double), allocatable :: xs(:)
        integer, allocatable :: is(:)
        character(len=:), allocatable :: text

        obj = QJsonObject()
        call check(obj%isEmpty(), 'QJsonObject empty')
        call obj%insert('name', 'run 1 – ü')
        call obj%insert('steps', 100)
        call obj%insert('dt', 0.25_c_double)
        call obj%insert('converged', .true.)
        call obj%insertNull('comment')
        arr = QJsonArray()
        call arr%appendDoubles([1.0_c_double, 2.5_c_double, -3.0_c_double])
        call arr%append('four')
        call check(arr%size() == 4, 'QJsonArray appendDoubles, append')
        call obj%insert('values', arr)
        inner = QJsonObject()
        call inner%insert('solver', 'rk4')
        call obj%insert('options', inner)
        v = QJsonValue(42)
        call obj%insert('answer', v)
        call v%delete()
        call check(obj%size() == 8 .and. obj%contains('dt'), 'size, contains')
        keys = obj%keys()
        call check(size(keys) == 8 .and. keys(1)%s == 'answer', 'keys (sorted)')

        text = obj%toJson(compact=.true.)
        call check(index(text, '"steps":100') > 0 .and. index(text, '"comment":null') > 0, 'toJson (compact)')

        ! round trip through text
        doc = QJsonDocument_fromJson(obj%toJson())
        call check(.not. doc%isNull() .and. doc%isObject() .and. doc%errorString() == '', 'fromJson')
        back = doc%object()
        call check(back%stringValue('name') == 'run 1 – ü', 'stringValue (UTF-8)')
        call check(back%intValue('steps') == 100 .and. back%doubleValue('dt') == 0.25_c_double, 'intValue, doubleValue')
        call check(back%boolValue('converged') .and. back%valueType('comment') == QJsonValue_Null, 'boolValue, null')
        call check(back%intValue('missing', fallback=-1) == -1 .and. back%stringValue('steps', 'x') == 'x', &
                   'fallbacks for missing keys and other types')
        call check(back%valueType('missing') == QJsonValue_Undefined, 'valueType: undefined')
        arr_back = back%arrayValue('values')
        xs = arr_back%toDoubles()
        call check(size(xs) == 4 .and. xs(2) == 2.5_c_double .and. xs(4) == 0.0_c_double, 'arrayValue, toDoubles')
        call check(arr_back%stringAt(3) == 'four' .and. arr_back%typeAt(3) == QJsonValue_String, 'stringAt, typeAt')
        call check(arr_back%doubleAt(10, -9.0_c_double) == -9.0_c_double, 'doubleAt: out of range')
        is = arr_back%toInts()
        call check(all(is == [1, 2, -3, 0]), 'toInts')
        inner_back = back%objectValue('options')
        call check(inner_back%stringValue('solver') == 'rk4', 'objectValue')
        v = back%value('answer')
        call check(v%isDouble() .and. v%toInt() == 42 .and. v%valueType() == QJsonValue_Double, 'QJsonValue number')
        call v%delete()
        v = back%value('options')
        call check(v%isObject(), 'QJsonValue object')
        call v%delete()
        call back%remove('options')
        call check(.not. back%contains('options'), 'remove')

        ! values
        v = QJsonValue('text')
        call check(v%isString() .and. v%toString() == 'text' .and. v%toInt(7) == 7, 'QJsonValue string')
        call v%delete()
        v = QJsonValue()
        call check(v%isNull(), 'QJsonValue null')
        call v%delete()
        v = QJsonValue(.false.)
        call check(v%isBool() .and. .not. v%toBool(.true.), 'QJsonValue bool')
        call v%delete()

        ! arrays as documents, and parse errors
        doc2 = QJsonDocument(arr)
        call check(doc2%isArray() .and. index(doc2%toJson(.true.), '[1,2.5,-3,"four"]') > 0, 'QJsonDocument(array)')
        call doc2%delete()
        doc2 = QJsonDocument_fromJson('{"a": [1, 2,}')
        call check(doc2%isNull() .and. len(doc2%errorString()) > 0 .and. doc2%errorOffset() > 0, &
                   'parse error: message and offset')
        call doc2%delete()

        call doc%delete()
        call obj%delete()
        call inner%delete()
        call arr%delete()
        call back%delete()
        call arr_back%delete()
        call inner_back%delete()
    end subroutine test_json

    !> QNetworkAccessManager with local URLs.
    subroutine test_network()
        type(QNetworkAccessManager) :: net
        type(QNetworkRequest) :: req
        type(QNetworkReply) :: reply
        type(QTemporaryDir) :: tmp
        character(len=:), allocatable :: path
        integer :: u, ierr

        tmp = QTemporaryDir()
        path = tmp%filePath('data.json')
        open(newunit=u, file=path, status='replace', action='write')
        write(u, '(A)') '{"x": 1}'
        close(u)

        net = QNetworkAccessManager()

        ! a file: URL, waiting
        req = QNetworkRequest(QUrl_fromLocalFile(path))
        call req%setRawHeader('X-Test', 'yes')
        call check(req%rawHeader('X-Test') == 'yes' .and. index(req%url(), 'data.json') > 0, 'QNetworkRequest')
        call check(QUrl_toLocalFile(req%url()) == path, 'QUrl_fromLocalFile / toLocalFile')
        call req%setTransferTimeout(5000)
        reply = net%get(req)
        call check(reply%waitForFinished(10000), 'waitForFinished')
        call check(reply%isFinished() .and. reply%error() == QNetworkReply_NoError, 'file: no error')
        call check(index(reply%readAll(), '"x": 1') > 0, 'file: readAll')
        call check(reply%statusCode() == 0 .or. reply%statusCode() == 200, 'statusCode for a file: URL')
        call reply%deleteLater()

        ! a data: URL, through slots in the event loop
        call req%setUrl('data:text/plain;charset=utf-8,hello%20there')
        log%reply = net%get(req)
        call log%reply%finished%connect(on_finished, log)
        call log%reply%downloadProgress%connect(on_progress, log)
        call QTimer_singleShot(10000, on_timeout)
        if (.not. log%reply%isFinished()) then
            ierr = app%exec()
        else
            call on_finished(log)
        end if
        call check(log%finished == 1 .and. log%body == 'hello there', 'data: URL through finished')
        call check(index(log%reply%contentType(), 'text/plain') > 0, 'contentType')
        call log%reply%deleteLater()

        ! a missing file
        call req%setUrl(QUrl_fromLocalFile(tmp%filePath('missing.json')))
        reply = net%get(req)
        call check(reply%waitForFinished(10000), 'missing file: finished')
        call check(reply%error() /= QNetworkReply_NoError .and. len(reply%errorString()) > 0, 'missing file: error')
        call reply%deleteLater()

        call req%delete()
        call net%delete()
        call tmp%delete()
    end subroutine test_network

end program test_json_network
