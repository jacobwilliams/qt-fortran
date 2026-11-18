!> Text documents, cursors, syntax highlighting and the code editor
!> (QtfPlainTextEdit). Run headless with QT_QPA_PLATFORM=offscreen.
module test_code_editor_slots

    use qt
    implicit none

    type(QTextCharFormat), parameter :: keyword_fmt = QTextCharFormat(foreground=Qt_blue, bold=.true.)
    type(QTextCharFormat), parameter :: string_fmt = QTextCharFormat(foreground=Qt_darkRed)
    type(QTextCharFormat), parameter :: comment_fmt = QTextCharFormat(foreground=Qt_darkGreen, italic=.true.)

    !> Counts calls.
    type :: counter
        integer :: calls = 0
        integer :: last = -1
    end type counter

    !> A key filter's state: the editor it edits and how many keys it consumed.
    type :: key_state
        type(QtfPlainTextEdit) :: editor
        integer :: consumed = 0
    end type key_state

contains

    !> Highlight 'program', '...' strings (which may continue on the next
    !> line: block state 1) and ! comments.
    subroutine on_highlight(text, block, data)
        character(len=*), intent(in) :: text
        type(QtfHighlightBlock), intent(in) :: block
        class(*), intent(inout), optional :: data
        integer :: i, k
        if (present(data)) then
            select type (data)
            type is (counter)
                data%calls = data%calls + 1
            end select
        end if
        i = 1
        call block%setCurrentBlockState(0)
        if (block%previousBlockState() == 1) then
            k = index(text, "'")
            if (k == 0) then
                call block%setFormat(0, len(text), string_fmt)
                call block%setCurrentBlockState(1)
                return
            end if
            call block%setFormat(0, k, string_fmt)
            i = k + 1
        end if
        k = index(text, 'program')
        if (k > 0) call block%setFormat(k - 1, 7, keyword_fmt)
        do while (i <= len(text))
            if (text(i:i) == '!') then
                call block%setFormat(i - 1, len(text) - i + 1, comment_fmt)
                exit
            else if (text(i:i) == "'") then
                k = index(text(i + 1:), "'")
                if (k == 0) then
                    call block%setFormat(i - 1, len(text) - i + 1, string_fmt)
                    call block%setCurrentBlockState(1)
                    exit
                end if
                call block%setFormat(i - 1, k + 1, string_fmt)
                i = i + k + 1
                cycle
            end if
            i = i + 1
        end do
    end subroutine on_highlight

    !> Count paint calls.
    subroutine on_paint(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        select type (data)
        type is (counter)
            data%calls = data%calls + 1
            data%last = painter%deviceWidth()
        end select
    end subroutine on_paint

    !> Count a signal without arguments.
    subroutine on_void(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (counter)
            data%calls = data%calls + 1
        end select
    end subroutine on_void

    !> Return: a new line indented like the current one (consumed); other keys pass.
    subroutine on_key(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        type(QTextBlock) :: block
        character(len=:), allocatable :: line
        integer :: n
        select type (data)
        type is (key_state)
            if (event%key() /= Qt_Key_Return) return
            block = data%editor%textBlock()
            line = block%text()
            n = verify(line, ' ') - 1
            if (n < 0) n = len(line)
            call data%editor%insertPlainText(new_line('a')//repeat(' ', n))
            call event%accept()
            data%consumed = data%consumed + 1
        end select
    end subroutine on_key

end module test_code_editor_slots

!> Tests for the code editor bindings.
program test_code_editor

    use qt
    use testing
    use test_code_editor_slots
    implicit none

    type(QApplication) :: app
    type(QTextDocument) :: doc, doc2
    type(QTextCursor) :: c, found
    type(QTextBlock) :: block
    type(QtfSyntaxHighlighter) :: hl, hl2
    type(QtfPlainTextEdit) :: ed
    type(QtfWidget) :: gutter
    type(QTextDocument) :: edoc
    type(QMargins) :: margins
    type(QPointF) :: offset
    type(QtfEventFilter) :: keys
    type(QKeyEvent) :: kev
    type(QPixmap) :: pix
    type(QRectF) :: r0, r1
    type(QRect) :: cr
    type(counter), target :: highlights, changes, gutter_paints, viewport_paints, moves
    type(key_state), target :: ks
    integer :: n, pos
    logical :: sent

    app = QApplication()

    ! ---- QTextDocument and QTextBlock
    doc = QTextDocument('line one'//new_line('a')//'  second'//new_line('a')//'third')
    call doc%contentsChanged%connect(on_void, changes)
    call check(doc%blockCount() == 3, 'QTextDocument blockCount')
    call check(doc%blockText(1) == '  second', 'QTextDocument blockText')
    call check(doc%blockPosition(1) == 9 .and. doc%blockLength(1) == 9, 'QTextDocument blockPosition / blockLength')
    call check(doc%blockPosition(7) == -1 .and. doc%blockText(7) == '', 'QTextDocument block out of range')
    call check(doc%blockNumberAt(10) == 1 .and. doc%blockNumberAt(999) == -1, 'QTextDocument blockNumberAt')
    call check(doc%characterCount() == 24, 'QTextDocument characterCount')
    call check(doc%characterAt(8) == new_line('a'), 'QTextDocument characterAt (a line break)')
    block = doc%firstBlock()
    n = 0
    do while (block%isValid())
        n = n + 1
        block = block%next()
    end do
    call check(n == 3, 'QTextBlock next walks all blocks')
    block = doc%lastBlock()
    call check(block%blockNumber() == 2 .and. block%text() == 'third', 'QTextDocument lastBlock')
    block = block%previous()
    call check(block%text() == '  second' .and. block%position() == 9, 'QTextBlock previous / position')
    call check(block%containsPosition(12) .and. .not. block%containsPosition(3), 'QTextBlock containsPosition')
    call block%setUserState(42)
    call check(block%userState() == 42 .and. doc%blockUserState(1) == 42, 'QTextBlock user state')
    block = doc%findBlock(20)
    call check(block%blockNumber() == 2, 'QTextDocument findBlock')
    block = doc%findBlockByNumber(5)
    call check(.not. block%isValid(), 'QTextDocument findBlockByNumber out of range')

    ! ---- QTextCursor
    c = QTextCursor(doc)
    call check(c%position() == 0 .and. c%atStart() .and. .not. c%isNull(), 'QTextCursor at the start')
    call check(c%movePosition(QTextCursor_EndOfBlock, QTextCursor_KeepAnchor), 'QTextCursor movePosition')
    call check(c%hasSelection() .and. c%selectedText() == 'line one', 'QTextCursor selectedText')
    call c%insertText('LINE')
    call check(doc%blockText(0) == 'LINE' .and. changes%calls > 0, 'QTextCursor insertText replaces the selection')
    call doc%undo()
    call check(doc%blockText(0) == 'line one', 'QTextDocument undo')
    call c%setPosition(9)
    call c%beginEditBlock()
    call c%insertText('a')
    call c%insertText('b')
    call c%endEditBlock()
    call check(doc%blockText(1) == 'ab  second', 'QTextCursor edit block')
    call doc%undo()
    call check(doc%blockText(1) == '  second', 'an edit block undoes as one step')
    call c%setPosition(13)
    call check(c%blockNumber() == 1 .and. c%columnNumber() == 4 .and. c%positionInBlock() == 4, &
               'QTextCursor blockNumber / columnNumber')
    block = c%block()
    call check(block%blockNumber() == 1, 'QTextCursor block')
    call c%select(QTextCursor_WordUnderCursor)
    call check(c%selectedText() == 'second', 'QTextCursor select word')
    call c%setPosition(0)
    call check(c%movePosition(QTextCursor_NextBlock, n=2) .and. c%position() == 18, 'QTextCursor move n times')
    call c%setPosition(0)
    call check(c%movePosition(QTextCursor_End, QTextCursor_KeepAnchor), 'QTextCursor move to the end')
    call check(c%selectedText() == 'line one'//new_line('a')//'  second'//new_line('a')//'third', &
               'QTextCursor selectedText has newlines')
    call c%delete()
    found = doc%find('THIRD')
    call check(found%selectionStart() == 18 .and. found%selectionEnd() == 23, 'QTextDocument find')
    call found%delete()
    found = doc%find('THIRD', flags=QTextDocument_FindCaseSensitively)
    call check(found%isNull(), 'QTextDocument find: no match')
    call found%delete()
    found = doc%findRegularExpression('s\w+d')
    call check(found%selectedText() == 'second', 'QTextDocument findRegularExpression')
    call found%delete()

    ! ---- QtfSyntaxHighlighter
    call doc%setPlainText("program x ! main"//new_line('a')//"s = 'abc&"//new_line('a')//"  def' ! end")
    hl = QtfSyntaxHighlighter(doc)
    call hl%highlightBlock%connect(on_highlight, highlights)
    call check(highlights%calls == 3, 'connecting a highlighter highlights every line')
    call check(doc%formatForegroundAt(0) == '#0000ff' .and. doc%formatIsBoldAt(3), 'keyword format')
    call check(doc%formatForegroundAt(7) == '', 'unformatted text')
    call check(doc%formatForegroundAt(10) == '#008000' .and. doc%formatIsItalicAt(12), 'comment format')
    call check(doc%formatForegroundAt(21) == '#800000', 'string format')
    call check(doc%blockUserState(1) == 1 .and. doc%blockUserState(2) == 0, 'block states')
    call check(doc%formatForegroundAt(29) == '#800000' .and. doc%formatForegroundAt(34) == '#008000', &
               'a string continued from the previous line')
    call hl%rehighlight()
    call check(highlights%calls == 6, 'rehighlight')
    ! non-ASCII text: setFormat offsets are bytes of the slot's text
    doc2 = QTextDocument("x = 'é' ! ü")
    hl2 = QtfSyntaxHighlighter(doc2)
    call hl2%highlightBlock%connect(on_highlight)
    call check(doc2%formatForegroundAt(5) == '#800000' .and. doc2%formatForegroundAt(7) == '', &
               'non-ASCII: string format')
    call check(doc2%formatForegroundAt(8) == '#008000' .and. doc2%formatForegroundAt(10) == '#008000', &
               'non-ASCII: comment format starts at the right character')
    call doc2%delete()

    ! ---- QtfPlainTextEdit
    ed = QtfPlainTextEdit('program demo'//new_line('a')//'    x = 1'//new_line('a')//'end program')
    call ed%resize(400, 300)
    call ed%setFont(QFont(QFontDatabase_fixedFamily(), 12.0d0))
    call ed%show()
    call check(ed%textWidth('9999') > ed%textWidth('9') .and. ed%lineHeight() > 0, 'textWidth / lineHeight')
    call ed%cursorPositionChanged%connect(on_void, moves)
    call ed%setGutterWidth(40)
    margins = ed%viewportMargins()
    call check(ed%gutterWidth() == 40 .and. margins%left == 40, 'gutter width sets the margin')
    gutter = ed%gutter()
    call check(gutter%width() == 40, 'gutter widget width')
    call gutter%paintEvent%connect(on_paint, gutter_paints)
    call ed%viewportPaintEvent%connect(on_paint, viewport_paints)
    pix = ed%grab()
    call pix%delete()
    call check(gutter_paints%calls > 0 .and. gutter_paints%last == 40, 'gutter paintEvent')
    call check(viewport_paints%calls > 0, 'viewportPaintEvent')
    call check(ed%firstVisibleBlockNumber() == 0 .and. ed%lastVisibleBlockNumber() == 2, 'visible blocks')
    block = ed%firstVisibleBlock()
    call check(block%text() == 'program demo', 'firstVisibleBlock')
    r0 = ed%blockBoundingGeometry(0)
    r1 = ed%blockBoundingGeometry(1)
    call check(r0%height > 0 .and. r1%y >= r0%y + r0%height - 1, 'blockBoundingGeometry')
    r1 = ed%blockBoundingGeometry(9)
    call check(r1%height == 0, 'blockBoundingGeometry: no such block')
    offset = ed%contentOffset()
    call check(abs(offset%y - r0%y) < 1.0d-9, 'contentOffset: where the first block starts')

    call ed%setCursorPosition(17)
    call check(ed%cursorPosition() == 17 .and. moves%calls > 0, 'setCursorPosition / cursorPositionChanged')
    block = ed%textBlock()
    call check(block%blockNumber() == 1, 'textBlock')
    cr = ed%cursorRectAt(17)
    pos = ed%positionAt(cr%x + 1, cr%y + cr%height / 2)
    call check(pos == 17, 'cursorRectAt / positionAt round trip')
    c = ed%textCursor()
    call check(c%movePosition(QTextCursor_EndOfBlock, QTextCursor_KeepAnchor), 'editor cursor copy moves')
    call ed%setTextCursor(c)
    call c%delete()
    call check(ed%cursorPosition() == 22, 'textCursor / setTextCursor')
    call ed%setCursorPosition(0)
    call check(ed%find('program') .and. ed%cursorPosition() == 7, 'QPlainTextEdit find')
    call check(ed%find('program') .and. ed%cursorPosition() == 34, 'QPlainTextEdit find next')
    call check(.not. ed%find('nothing'), 'QPlainTextEdit find: no match')

    call ed%addExtraSelection(0, 0, QTextCharFormat(background=Qt_yellow), fullWidth=.true.)
    call ed%addExtraSelections([0, 27], [7, 34], QTextCharFormat(background=Qt_cyan))
    call check(ed%extraSelectionCount() == 3, 'extra selections')
    call ed%clearExtraSelections()
    call check(ed%extraSelectionCount() == 0, 'clearExtraSelections')

    ! keys: a filter on the editor consumes Return (auto-indent); other keys pass
    ks%editor = ed
    keys = QtfEventFilter(ed)
    call keys%keyPressEvent%connect(on_key, ks)
    call ed%setCursorPosition(22)
    kev = QKeyEvent(QEvent_KeyPress, Qt_Key_Return, text=achar(13))
    sent = QCoreApplication_sendEvent(ed, kev)
    call kev%delete()
    call check(ks%consumed == 1 .and. ed%blockCount() == 4, 'consumed Return')
    edoc = ed%document()
    call check(edoc%blockText(2) == '    ', 'auto-indent from the key filter')
    kev = QKeyEvent(QEvent_KeyPress, Qt_Key_Y, text='y')
    sent = QCoreApplication_sendEvent(ed, kev)
    call kev%delete()
    call check(edoc%blockText(2) == '    y' .and. ks%consumed == 1, 'other keys reach the editor')

    call ed%delete()
    call doc%delete()

end program test_code_editor
