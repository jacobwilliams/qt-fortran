!> A small Fortran code editor, built on QtfPlainTextEdit:
!>
!> * Syntax highlighting (QtfSyntaxHighlighter): keywords, types, logical
!>   operators, numbers, strings and comments. A string continued with `&`
!>   carries over to the next line through the block state; an unterminated
!>   string gets a wavy red underline.
!> * A gutter with line numbers (the current one darker). Click it to toggle
!>   a bookmark (a blue dot). Bookmarks are QTextCursors, so they follow
!>   edits above them.
!> * Extra selections: the current line, every occurrence of the word under
!>   the cursor (or of the Find text), and a wavy underline past column 80.
!> * Painting over the text: a ruler at column 80, and the extra cursors.
!> * Keys and mouse, intercepted with QtfEventFilter: Return keeps the
!>   indentation (one level more after `do`, `then`, `program`, ...), Tab
!>   indents to the next multiple of 4, Alt+click adds a cursor, and typing,
!>   Backspace and Tab then act at every cursor (one undo step). Escape or a
!>   plain click drops the extra cursors.
!> * A Find field: Return jumps to the next match.
!>
!> `editor --screenshot out.png` sets up some bookmarks and cursors, saves the
!> window and exits (useful headless, with QT_QPA_PLATFORM=offscreen).
module editor_app

    use qt
    use iso_c_binding, only: c_double
    implicit none

    integer, parameter :: dp = c_double
    integer, parameter :: max_cursors = 64     !! extra cursors and bookmarks (each)
    integer, parameter :: max_matches = 2000   !! highlighted occurrences
    integer, parameter :: ruler_column = 80
    integer, parameter :: indent_width = 4

    ! block states of the highlighter
    integer, parameter :: in_code = 0
    integer, parameter :: in_single_quoted = 1   !! a '...' string continued with &
    integer, parameter :: in_double_quoted = 2   !! a "..." string continued with &

    type(QTextCharFormat), parameter :: keyword_fmt = QTextCharFormat(foreground=QColor(0, 0, 192), bold=.true.)
    type(QTextCharFormat), parameter :: type_fmt = QTextCharFormat(foreground=QColor(128, 0, 128), bold=.true.)
    type(QTextCharFormat), parameter :: operator_fmt = QTextCharFormat(foreground=QColor(0, 128, 128))
    type(QTextCharFormat), parameter :: number_fmt = QTextCharFormat(foreground=QColor(175, 95, 0))
    type(QTextCharFormat), parameter :: string_fmt = QTextCharFormat(foreground=QColor(160, 20, 20))
    type(QTextCharFormat), parameter :: comment_fmt = QTextCharFormat(foreground=QColor(0, 128, 0), italic=.true.)
    type(QTextCharFormat), parameter :: unterminated_fmt = &
        QTextCharFormat(foreground=QColor(160, 20, 20), underlineStyle=QTextCharFormat_WaveUnderline, &
                        underlineColor=Qt_red)

    !> Everything the slots need.
    type :: editor_state
        type(QMainWindow) :: window
        type(QtfPlainTextEdit) :: editor
        type(QTextDocument) :: doc
        type(QtfSyntaxHighlighter) :: highlighter
        type(QtfWidget) :: gutter
        type(QtfEventFilter) :: keys      !! on the editor
        type(QtfEventFilter) :: mouse     !! on the editor's viewport
        type(QLineEdit) :: find
        type(QStatusBar) :: status
        type(QTextCursor) :: cursors(max_cursors)     !! extra cursors
        integer :: ncursors = 0
        type(QTextCursor) :: bookmarks(max_cursors)   !! at the start of bookmarked lines
        integer :: nbookmarks = 0
        integer :: char_width = 8
        character(len=:), allocatable :: screenshot
    end type editor_state

contains

    ! ------------------------------------------------------------------
    ! syntax highlighting

    !> Highlight one line of Fortran.
    subroutine on_highlight(text, block, data)
        character(len=*), intent(in) :: text
        type(QtfHighlightBlock), intent(in) :: block
        class(*), intent(inout), optional :: data
        integer :: i, j, n
        character :: quote
        n = len(text)
        i = 1
        call block%setCurrentBlockState(in_code)
        ! the rest of a string continued from the previous line
        select case (block%previousBlockState())
        case (in_single_quoted, in_double_quoted)
            quote = merge("'", '"', block%previousBlockState() == in_single_quoted)
            call string_end(text, 1, quote, block, i)
        end select
        do while (i <= n)
            if (text(i:i) == '!') then
                call block%setFormat(i - 1, n - i + 1, comment_fmt)
                return
            else if (text(i:i) == "'" .or. text(i:i) == '"') then
                call string_end(text, i + 1, text(i:i), block, j, i)
                i = j
            else if (is_letter(text(i:i))) then
                j = i
                do while (j < n)
                    if (.not. is_word_char(text(j + 1:j + 1))) exit
                    j = j + 1
                end do
                if (is_keyword(lower(text(i:j)))) then
                    call block%setFormat(i - 1, j - i + 1, keyword_fmt)
                else if (is_type(lower(text(i:j)))) then
                    call block%setFormat(i - 1, j - i + 1, type_fmt)
                end if
                i = j + 1
            else if (is_digit(text(i:i)) .and. .not. after_word(text, i)) then
                j = number_end(text, i)
                call block%setFormat(i - 1, j - i + 1, number_fmt)
                i = j + 1
            else if (text(i:i) == '.') then
                ! .and., .true., ...
                j = i + 1
                do while (j <= n)
                    if (.not. is_letter(text(j:j))) exit
                    j = j + 1
                end do
                if (j <= n .and. j > i + 1) then
                    if (text(j:j) == '.') then
                        call block%setFormat(i - 1, j - i + 1, operator_fmt)
                        i = j + 1
                        cycle
                    end if
                end if
                i = i + 1
            else
                i = i + 1
            end if
        end do
    end subroutine on_highlight

    !> Format a string from `from` (after its opening quote, at `start`) to its
    !> closing `quote`; `next` is the index after it. A string that is not
    !> closed continues on the next line if the line ends with `&`, and is
    !> marked as an error otherwise.
    subroutine string_end(text, from, quote, block, next, start)
        character(len=*), intent(in) :: text
        integer, intent(in) :: from
        character, intent(in) :: quote
        type(QtfHighlightBlock), intent(in) :: block
        integer, intent(out) :: next
        integer, intent(in), optional :: start
        integer :: s, k
        s = from
        if (present(start)) s = start
        k = 0
        if (from <= len(text)) k = index(text(from:), quote)
        if (k > 0) then
            next = from + k
            call block%setFormat(s - 1, next - s, string_fmt)
        else
            next = len(text) + 1
            if (len_trim(text) > 0 .and. text(max(len_trim(text), 1):len_trim(text)) == '&') then
                call block%setFormat(s - 1, next - s, string_fmt)
                call block%setCurrentBlockState(merge(in_single_quoted, in_double_quoted, quote == "'"))
            else
                call block%setFormat(s - 1, next - s, unterminated_fmt)
            end if
        end if
    end subroutine string_end

    !> The index of the last character of the number starting at `i`
    !> (digits, a decimal point, an exponent, a `_kind` suffix).
    integer function number_end(text, i) result(j)
        character(len=*), intent(in) :: text
        integer, intent(in) :: i
        j = i
        do while (j < len(text))
            associate (c => text(j + 1:j + 1))
                if (is_digit(c) .or. c == '.' .or. c == '_') then
                    j = j + 1
                else if (scan(c, 'eEdD') > 0 .and. j + 2 <= len(text)) then
                    if (scan(text(j + 2:j + 2), '0123456789+-') == 0) exit
                    j = j + 2
                else if (is_letter(c) .and. text(j:j) == '_') then
                    j = j + 1   ! a named kind: 1.0_dp
                else
                    exit
                end if
            end associate
        end do
        ! a trailing '.' starting an operator (1.and.) is not part of the number
        if (text(j:j) == '.' .and. j < len(text)) then
            if (is_letter(text(j + 1:j + 1))) j = j - 1
        end if
    end function number_end

    !> True for Fortran keywords (lower case).
    logical function is_keyword(word)
        character(len=*), intent(in) :: word
        select case (word)
        case ('program', 'end', 'module', 'submodule', 'contains', 'use', 'only', 'implicit', 'none', &
              'subroutine', 'function', 'result', 'call', 'return', 'if', 'then', 'else', 'elseif', &
              'endif', 'do', 'enddo', 'while', 'concurrent', 'exit', 'cycle', 'select', 'case', 'default', &
              'where', 'elsewhere', 'forall', 'intent', 'in', 'out', 'inout', 'parameter', 'allocatable', &
              'pointer', 'target', 'optional', 'save', 'public', 'private', 'interface', 'procedure', &
              'abstract', 'extends', 'class', 'allocate', 'deallocate', 'associate', 'block', 'stop', &
              'error', 'print', 'write', 'read', 'open', 'close', 'pure', 'elemental', 'recursive', &
              'value', 'bind', 'import', 'nullify', 'go', 'goto', 'continue', 'format', 'dimension')
            is_keyword = .true.
        case default
            is_keyword = .false.
        end select
    end function is_keyword

    !> True for Fortran type names (lower case).
    logical function is_type(word)
        character(len=*), intent(in) :: word
        select case (word)
        case ('integer', 'real', 'complex', 'logical', 'character', 'type', 'double', 'precision')
            is_type = .true.
        case default
            is_type = .false.
        end select
    end function is_type

    !> True if text(i:i) continues a name (e.g. the 2 in x2).
    logical function after_word(text, i)
        character(len=*), intent(in) :: text
        integer, intent(in) :: i
        after_word = .false.
        if (i > 1) after_word = is_word_char(text(i - 1:i - 1))
    end function after_word

    !> True for an ASCII letter.
    elemental logical function is_letter(c)
        character, intent(in) :: c
        is_letter = (c >= 'a' .and. c <= 'z') .or. (c >= 'A' .and. c <= 'Z')
    end function is_letter

    !> True for a decimal digit.
    elemental logical function is_digit(c)
        character, intent(in) :: c
        is_digit = c >= '0' .and. c <= '9'
    end function is_digit

    !> True for a character of a name.
    elemental logical function is_word_char(c)
        character, intent(in) :: c
        is_word_char = is_letter(c) .or. is_digit(c) .or. c == '_'
    end function is_word_char

    !> ASCII lower-case copy.
    pure function lower(s) result(t)
        character(len=*), intent(in) :: s
        character(len=len(s)) :: t
        integer :: i
        t = s
        do i = 1, len(s)
            if (s(i:i) >= 'A' .and. s(i:i) <= 'Z') t(i:i) = achar(iachar(s(i:i)) + 32)
        end do
    end function lower

    ! ------------------------------------------------------------------
    ! gutter

    !> Draw the line numbers and bookmarks of the visible lines.
    subroutine on_gutter_paint(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        type(QRectF) :: r
        type(QTextBlock) :: block
        integer :: n, current, w
        select type (s => data)
        type is (editor_state)
            w = s%editor%gutterWidth()
            call painter%fillRect(0, 0, w, painter%deviceHeight(), QColor(240, 240, 240))
            call painter%setRenderHint(QPainter_Antialiasing)
            block = s%editor%textBlock()
            current = block%number
            do n = s%editor%firstVisibleBlockNumber(), s%editor%lastVisibleBlockNumber()
                r = s%editor%blockBoundingGeometry(n)
                if (is_bookmarked(s, n)) then
                    call painter%setPen(QPen(QColor(30, 90, 200)))
                    call painter%setBrush(QColor(30, 90, 200))
                    call painter%drawEllipse(4.0_dp, r%y + r%height / 2 - 4, 8.0_dp, 8.0_dp)
                end if
                if (n == current) then
                    call painter%setPen(QColor(40, 40, 40))
                else
                    call painter%setPen(QColor(150, 150, 150))
                end if
                call painter%drawText(0.0_dp, r%y, real(w - 6, dp), r%height, ior(Qt_AlignRight, Qt_AlignVCenter), &
                                      itoa(n + 1))
            end do
        end select
    end subroutine on_gutter_paint

    !> A click in the gutter toggles the bookmark of the line there.
    subroutine on_gutter_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        integer :: line, k
        select type (s => data)
        type is (editor_state)
            line = s%doc%blockNumberAt(s%editor%positionAt(1, int(event%y())))
            if (line < 0) return
            do k = 1, s%nbookmarks
                if (s%bookmarks(k)%blockNumber() == line) then
                    call s%bookmarks(k)%delete()
                    s%bookmarks(k:s%nbookmarks - 1) = s%bookmarks(k + 1:s%nbookmarks)
                    s%nbookmarks = s%nbookmarks - 1
                    call refresh(s)
                    return
                end if
            end do
            if (s%nbookmarks == max_cursors) return
            s%nbookmarks = s%nbookmarks + 1
            s%bookmarks(s%nbookmarks) = QTextCursor(s%doc)
            call s%bookmarks(s%nbookmarks)%setPosition(s%doc%blockPosition(line))
            call refresh(s)
        end select
    end subroutine on_gutter_press

    !> True if line `n` has a bookmark.
    logical function is_bookmarked(s, n)
        type(editor_state), intent(in) :: s
        integer, intent(in) :: n
        integer :: k
        is_bookmarked = .false.
        do k = 1, s%nbookmarks
            if (s%bookmarks(k)%blockNumber() == n) is_bookmarked = .true.
        end do
    end function is_bookmarked

    ! ------------------------------------------------------------------
    ! painting over the text: the ruler and the extra cursors

    !> Draw the column ruler and the extra cursors over the text.
    subroutine on_viewport_paint(painter, data)
        type(QPainter), intent(inout) :: painter
        class(*), intent(inout), optional :: data
        type(QRect) :: r
        integer :: x, k
        select type (s => data)
        type is (editor_state)
            r = s%editor%cursorRectAt(s%doc%blockPosition(s%editor%firstVisibleBlockNumber()))
            x = r%x + ruler_column * s%char_width
            call painter%setPen(QPen(QColor(220, 200, 200), 1.0_dp, Qt_DashLine))
            call painter%drawLine(x, 0, x, painter%deviceHeight())
            do k = 1, s%ncursors
                r = s%editor%cursorRectAt(s%cursors(k)%position())
                call painter%fillRect(r%x, r%y, 2, r%height, QColor(220, 40, 40))
            end do
        end select
    end subroutine on_viewport_paint

    ! ------------------------------------------------------------------
    ! extra selections and status

    !> Redo the extra selections (current line, occurrences, long lines),
    !> the status bar and the gutter.
    subroutine refresh(s)
        type(editor_state), intent(inout) :: s
        type(QTextCursor) :: c
        type(QTextBlock) :: block
        character(len=:), allocatable :: word
        type(QWidget) :: viewport
        integer :: starts(max_matches), ends(max_matches), n, flags, len_line
        character(len=160) :: msg, marks

        call s%editor%clearExtraSelections()
        ! the current line
        call s%editor%addExtraSelection(s%editor%cursorPosition(), s%editor%cursorPosition(), &
                                        QTextCharFormat(background=QColor(255, 250, 220)), fullWidth=.true.)
        ! occurrences of the Find text, or else of the word under the cursor
        word = s%find%text()
        flags = 0
        if (len(word) == 0) then
            c = s%editor%textCursor()
            call c%select(QTextCursor_WordUnderCursor)
            word = c%selectedText()
            call c%delete()
            flags = QTextDocument_FindWholeWords
            if (len(word) < 2) word = ''
            if (len(word) > 0) then
                if (.not. is_letter(word(1:1))) word = ''
            end if
        end if
        n = 0
        if (len(word) > 0) then
            c = s%doc%find(word, 0, flags)
            do while (.not. c%isNull() .and. n < max_matches)
                n = n + 1
                starts(n) = c%selectionStart()
                ends(n) = c%selectionEnd()
                call c%delete()
                c = s%doc%find(word, ends(n), flags)
            end do
            call c%delete()
            call s%editor%addExtraSelections(starts(1:n), ends(1:n), QTextCharFormat(background=QColor(255, 210, 120)))
        end if
        ! past the ruler: a wavy underline
        block = s%doc%firstBlock()
        do while (block%isValid())
            len_line = block%length() - 1
            if (len_line > ruler_column) &
                call s%editor%addExtraSelection(block%position() + ruler_column, block%position() + len_line, &
                    QTextCharFormat(underlineStyle=QTextCharFormat_WaveUnderline, underlineColor=QColor(230, 120, 0)))
            block = block%next()
        end do

        block = s%editor%textBlock()
        c = s%editor%textCursor()
        write(msg, '(A,I0,A,I0,A,I0,A,I0,A,I0,A)') 'Ln ', block%number + 1, ', Col ', c%columnNumber() + 1, &
            '    ', s%doc%blockCount(), ' lines    ', n, ' matches    ', s%ncursors + 1, ' cursors'
        call c%delete()
        marks = ''
        if (s%nbookmarks > 0) write(marks, '(A,I0,A)') '    ', s%nbookmarks, ' bookmarks'
        call s%status%showMessage(trim(msg)//trim(marks))
        call s%gutter%update()
        viewport = s%editor%viewport()
        call viewport%update()
    end subroutine refresh

    !> The cursor moved or the text changed.
    subroutine on_changed(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (editor_state)
            call refresh(s)
        end select
    end subroutine on_changed

    !> The Find text changed.
    subroutine on_find_changed(text, data)
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (editor_state)
            call refresh(s)
        end select
    end subroutine on_find_changed

    !> Return in the Find field: select the next match (wrapping around).
    subroutine on_find_next(data)
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: text
        select type (s => data)
        type is (editor_state)
            text = s%find%text()
            if (len(text) == 0) return
            if (.not. s%editor%find(text)) then
                call s%editor%setCursorPosition(0)
                if (.not. s%editor%find(text)) return
            end if
            call s%editor%centerCursor()
        end select
    end subroutine on_find_next

    ! ------------------------------------------------------------------
    ! keys and mouse

    !> Keys of the editor: auto-indent, Tab, and edits at every cursor.
    subroutine on_key(event, data)
        type(QKeyEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        character(len=:), allocatable :: text
        select type (s => data)
        type is (editor_state)
            if (iand(event%modifiers(), ior(Qt_ControlModifier, Qt_MetaModifier)) /= 0) return
            select case (event%key())
            case (Qt_Key_Return, Qt_Key_Enter)
                call drop_cursors(s)
                call new_line_indented(s)
                call event%accept()
            case (Qt_Key_Escape)
                if (s%ncursors == 0) return
                call drop_cursors(s)
                call event%accept()
            case (Qt_Key_Tab)
                call edit_all(s, 'tab')
                call event%accept()
            case (Qt_Key_Backspace)
                if (s%ncursors == 0) return
                call edit_all(s, 'backspace')
                call event%accept()
            case default
                text = event%text()
                if (s%ncursors == 0 .or. len(text) == 0) return
                if (iachar(text(1:1)) < 32 .or. iachar(text(1:1)) == 127) return
                call edit_all(s, 'insert', text)
                call event%accept()
            end select
        end select
    end subroutine on_key

    !> Return: a new line with the current line's indentation, one level
    !> more after a line that opens a block.
    subroutine new_line_indented(s)
        type(editor_state), intent(inout) :: s
        type(QTextBlock) :: block
        character(len=:), allocatable :: line, code
        integer :: indent, k
        block = s%editor%textBlock()
        line = block%text()
        indent = verify(line, ' ') - 1
        if (indent < 0) indent = len(line)
        k = index(line, '!')
        code = lower(trim(adjustl(line)))
        if (k > 0) code = lower(trim(adjustl(line(:k - 1))))
        if (opens_block(code)) indent = indent + indent_width
        call s%editor%insertPlainText(new_line('a')//repeat(' ', indent))
        call s%editor%ensureCursorVisible()
    end subroutine new_line_indented

    !> True if a line (lower case, trimmed, without its comment) opens a block.
    logical function opens_block(code)
        character(len=*), intent(in) :: code
        integer :: n
        n = len(code)
        opens_block = .false.
        if (n == 0) return
        if (n >= 4) opens_block = code(n - 3:) == 'then'
        if (starts_with(code, 'end')) return
        opens_block = opens_block .or. starts_with(code, 'do') .or. starts_with(code, 'program ') &
                      .or. starts_with(code, 'module ') .or. starts_with(code, 'subroutine ') &
                      .or. starts_with(code, 'function ') .or. starts_with(code, 'select ') &
                      .or. code == 'contains' .or. code == 'else' .or. starts_with(code, 'case ') &
                      .or. starts_with(code, 'type ') .or. starts_with(code, 'type::') &
                      .or. starts_with(code, 'associate')
    end function opens_block

    !> True if `s` starts with `prefix` (followed by a non-name character).
    logical function starts_with(s, prefix)
        character(len=*), intent(in) :: s, prefix
        integer :: n
        n = len(prefix)
        starts_with = .false.
        if (len(s) < n) return
        if (s(1:n) /= prefix) return
        starts_with = .true.
        if (len(s) > n .and. is_word_char(prefix(n:n))) starts_with = .not. is_word_char(s(n + 1:n + 1))
    end function starts_with

    !> Insert text, delete backwards or indent at the editor's cursor and at
    !> every extra cursor, as one undo step. The extra cursors are
    !> QTextCursors, so each edit moves the others as needed.
    subroutine edit_all(s, what, text)
        type(editor_state), intent(inout) :: s
        character(len=*), intent(in) :: what
        character(len=*), intent(in), optional :: text
        type(QTextCursor) :: main
        integer :: k
        main = s%editor%textCursor()
        call main%beginEditBlock()
        call edit_at(main, what, text)
        do k = 1, s%ncursors
            call edit_at(s%cursors(k), what, text)
        end do
        call main%endEditBlock()
        call s%editor%setTextCursor(main)
        call main%delete()
        call refresh(s)
    end subroutine edit_all

    !> One edit at one cursor.
    subroutine edit_at(c, what, text)
        type(QTextCursor), intent(inout) :: c
        character(len=*), intent(in) :: what
        character(len=*), intent(in), optional :: text
        select case (what)
        case ('insert')
            call c%insertText(text)
        case ('backspace')
            call c%deletePreviousChar()
        case ('tab')
            call c%insertText(repeat(' ', indent_width - mod(c%columnNumber(), indent_width)))
        end select
    end subroutine edit_at

    !> Alt+click adds a cursor; a plain click drops the extra ones.
    subroutine on_mouse_press(event, data)
        type(QMouseEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        integer :: pos
        select type (s => data)
        type is (editor_state)
            if (event%button() /= Qt_LeftButton) return
            if (iand(event%modifiers(), Qt_AltModifier) == 0) then
                call drop_cursors(s)
                return      ! not consumed: the editor moves its cursor as usual
            end if
            pos = s%editor%positionAt(int(event%x()), int(event%y()))
            call add_cursor(s, pos)
            call event%accept()    ! consumed: the editor's own cursor stays
        end select
    end subroutine on_mouse_press

    !> Add an extra cursor at `pos` (unless one is there already).
    subroutine add_cursor(s, pos)
        type(editor_state), intent(inout) :: s
        integer, intent(in) :: pos
        integer :: k
        if (s%ncursors == max_cursors .or. pos == s%editor%cursorPosition()) return
        do k = 1, s%ncursors
            if (s%cursors(k)%position() == pos) return
        end do
        s%ncursors = s%ncursors + 1
        s%cursors(s%ncursors) = QTextCursor(s%doc)
        call s%cursors(s%ncursors)%setPosition(pos)
        call refresh(s)
    end subroutine add_cursor

    !> Remove the extra cursors.
    subroutine drop_cursors(s)
        type(editor_state), intent(inout) :: s
        integer :: k
        if (s%ncursors == 0) return
        do k = 1, s%ncursors
            call s%cursors(k)%delete()
        end do
        s%ncursors = 0
        call refresh(s)
    end subroutine drop_cursors

    ! ------------------------------------------------------------------

    !> Save the window for `--screenshot` and quit.
    subroutine on_screenshot(data)
        class(*), intent(inout), optional :: data
        type(QPixmap) :: pix
        select type (s => data)
        type is (editor_state)
            pix = s%window%grab()
            if (.not. pix%save(s%screenshot)) write(*, '(A)') 'could not save '//s%screenshot
            call pix%delete()
            call QApplication_quit()
        end select
    end subroutine on_screenshot

    !> An integer as text.
    function itoa(i) result(s)
        integer, intent(in) :: i
        character(len=:), allocatable :: s
        character(len=12) :: buf
        write(buf, '(I0)') i
        s = trim(buf)
    end function itoa

    !> The sample program shown at start.
    function sample() result(text)
        character(len=:), allocatable :: text
        character, parameter :: nl = new_line('a')
        text = &
            '!> Integrate an orbit with a fixed-step RK4 integrator.'//nl// &
            'program orbit'//nl// &
            '    use iso_fortran_env, only: dp => real64'//nl// &
            '    implicit none'//nl//nl// &
            '    real(dp), parameter :: mu = 398600.4418_dp   ! km^3/s^2'//nl// &
            '    real(dp) :: x(6), t, dt'//nl// &
            '    integer :: i, n'//nl// &
            '    logical :: verbose = .true.'//nl// &
            "    character(len=*), parameter :: title = 'A string that continues &"//nl// &
            "        &on the next line'"//nl//nl// &
            '    x = [7000.0_dp, 0.0_dp, 0.0_dp, 0.0_dp, 7.5_dp, 1.0e-3_dp]'//nl// &
            '    t = 0.0_dp'//nl// &
            '    dt = 10.0_dp'//nl// &
            '    n = 600'//nl// &
            '    do i = 1, n'//nl// &
            '        call rk4(x, t, dt)'//nl// &
            '        if (verbose .and. mod(i, 100) == 0) then'//nl// &
            "            print '(A,F10.1,A,3F12.3)', 't = ', t, '  r = ', x(1:3)   ! this line is longer than 80 columns"//nl// &
            '        end if'//nl// &
            '    end do'//nl//nl// &
            'contains'//nl//nl// &
            '    subroutine rk4(x, t, h)'//nl// &
            '        real(dp), intent(inout) :: x(6), t'//nl// &
            '        real(dp), intent(in) :: h'//nl// &
            '        real(dp), dimension(6) :: k1, k2, k3, k4'//nl// &
            '        k1 = deriv(x)'//nl// &
            '        k2 = deriv(x + h/2*k1)'//nl// &
            '        k3 = deriv(x + h/2*k2)'//nl// &
            '        k4 = deriv(x + h*k3)'//nl// &
            '        x = x + h/6*(k1 + 2*k2 + 2*k3 + k4)'//nl// &
            '        t = t + h'//nl// &
            '    end subroutine rk4'//nl//nl// &
            '    pure function deriv(x) result(dx)'//nl// &
            '        real(dp), intent(in) :: x(6)'//nl// &
            '        real(dp) :: dx(6)'//nl// &
            '        dx(1:3) = x(4:6)'//nl// &
            '        dx(4:6) = -mu * x(1:3) / norm2(x(1:3))**3'//nl// &
            '    end function deriv'//nl//nl// &
            'end program orbit'
    end function sample

end module editor_app

!> The code editor example.
program editor

    use editor_app
    implicit none

    type(QApplication) :: app
    type(editor_state), target :: s
    type(QWidget) :: central
    type(QVBoxLayout) :: layout
    type(QHBoxLayout) :: bar
    type(QLabel) :: label
    character(len=512) :: arg
    integer :: ierr

    app = QApplication()

    s%window = QMainWindow()
    call s%window%setWindowTitle('qt-fortran: code editor')
    central = QWidget()
    layout = QVBoxLayout(central)
    call layout%setContentsMargins(4, 4, 4, 4)

    ! the find bar
    bar = QHBoxLayout()
    label = QLabel('Find:')
    call bar%addWidget(label)
    s%find = QLineEdit()
    call s%find%setPlaceholderText('text to highlight (Return: next match)')
    call s%find%setClearButtonEnabled(.true.)
    call bar%addWidget(s%find, 1)
    call layout%addLayout(bar)

    ! the editor
    s%editor = QtfPlainTextEdit(sample())
    call s%editor%setFont(QFont(QFontDatabase_fixedFamily(), 12.0_dp))
    call s%editor%setLineWrapMode(QPlainTextEdit_NoWrap)
    s%char_width = s%editor%textWidth('x')
    call s%editor%setTabStopDistance(real(indent_width * s%char_width, dp))
    call layout%addWidget(s%editor, 1)
    s%doc = s%editor%document()

    ! highlighting
    s%highlighter = QtfSyntaxHighlighter(s%doc)
    call s%highlighter%highlightBlock%connect(on_highlight)

    ! the gutter: line numbers and bookmarks
    call s%editor%setGutterWidth(s%editor%textWidth('9999') + 22)
    s%gutter = s%editor%gutter()
    call s%gutter%paintEvent%connect(on_gutter_paint, s)
    call s%gutter%mousePressEvent%connect(on_gutter_press, s)

    ! painting over the text, keys, mouse
    call s%editor%viewportPaintEvent%connect(on_viewport_paint, s)
    s%keys = QtfEventFilter(s%editor)
    call s%keys%keyPressEvent%connect(on_key, s)
    s%mouse = QtfEventFilter(s%editor%viewport())
    call s%mouse%mousePressEvent%connect(on_mouse_press, s)

    ! keeping the selections and the status up to date
    call s%editor%cursorPositionChanged%connect(on_changed, s)
    call s%editor%textChanged%connect(on_changed, s)
    call s%find%textChanged%connect(on_find_changed, s)
    call s%find%returnPressed%connect(on_find_next, s)

    call s%window%setCentralWidget(central)
    s%status = s%window%statusBar()
    call s%window%resize(1000, 700)
    call s%editor%setCursorPosition(s%doc%blockPosition(17) + 14)   ! in 'rk4'
    call refresh(s)

    ! `--screenshot file.png`: show some bookmarks and cursors, save, exit
    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        s%nbookmarks = 2
        s%bookmarks(1) = QTextCursor(s%doc)
        call s%bookmarks(1)%setPosition(s%doc%blockPosition(16))
        s%bookmarks(2) = QTextCursor(s%doc)
        call s%bookmarks(2)%setPosition(s%doc%blockPosition(25))
        ! three cursors at the start of k2, k3 and k4
        call s%editor%setCursorPosition(s%doc%blockPosition(30) + 8)
        call add_cursor(s, s%doc%blockPosition(31) + 8)
        call add_cursor(s, s%doc%blockPosition(32) + 8)
        call QTimer_singleShot(300, on_screenshot, s)
    end if

    call s%window%show()
    call s%editor%setFocus()
    ierr = app%exec()

end program editor
