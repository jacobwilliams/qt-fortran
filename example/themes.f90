!> Themes, styles and shortcuts: an application that restyles itself.
!>
!> * View > Theme (a QActionGroup: one checked at a time): System, Light,
!>   Dark, Solarized and High contrast palettes (QPalette, applied with
!>   QApplication_setPalette), plus an accent color picked with a color dialog.
!>   Ctrl+T (a QShortcut) cycles through the themes.
!> * View > Style: every style of QStyleFactory_keys (another action group).
!> * Pages chosen with a standalone QTabBar over a QStackedLayout:
!>   - Controls: buttons, inputs, sliders, a progress bar and disabled
!>     widgets in the current theme; a button that shows a QToolTip on demand.
!>   - Palette: every color role of the current palette, in the active and
!>     disabled groups (a QTableWidget, its header set up with QHeaderView
!>     resize modes).
!>   - Shortcuts: the platform's keys for standard actions (QKeySequence), in
!>     portable and native text; click a column title to sort. The status bar
!>     follows the table's scroll bar (QScrollBar).
!> * File > Open and Quit use standard shortcuts; Help opens the Qt
!>   documentation in the browser (QDesktopServices_openUrl).
!>
!> `themes --screenshot out.png [theme [page]]` (theme 0-4, page 0-2) saves the
!> window and exits (useful headless, with QT_QPA_PLATFORM=offscreen).
module themes_app

    use qt
    implicit none

    integer, parameter :: ntheme = 5
    character(len=13), parameter :: theme_names(ntheme) = &
        [character(len=13) :: 'System', 'Light', 'Dark', 'Solarized', 'High contrast']

    integer, parameter :: nkeys = 18
    integer, parameter :: standard_keys(nkeys) = [QKeySequence_New, QKeySequence_Open, QKeySequence_Save, &
        QKeySequence_SaveAs, QKeySequence_Close, QKeySequence_Quit, QKeySequence_Undo, QKeySequence_Redo, &
        QKeySequence_Cut, QKeySequence_Copy, QKeySequence_Paste, QKeySequence_SelectAll, QKeySequence_Find, &
        QKeySequence_FindNext, QKeySequence_ZoomIn, QKeySequence_ZoomOut, QKeySequence_Preferences, &
        QKeySequence_FullScreen]
    character(len=12), parameter :: key_names(nkeys) = [character(len=12) :: 'New', 'Open', 'Save', 'Save As', &
        'Close', 'Quit', 'Undo', 'Redo', 'Cut', 'Copy', 'Paste', 'Select All', 'Find', 'Find Next', 'Zoom In', &
        'Zoom Out', 'Preferences', 'Full Screen']

    integer, parameter :: nroles = 22
    character(len=16), parameter :: role_names(nroles) = [character(len=16) :: 'WindowText', 'Button', 'Light', &
        'Midlight', 'Dark', 'Mid', 'Text', 'BrightText', 'ButtonText', 'Base', 'Window', 'Shadow', 'Highlight', &
        'HighlightedText', 'Link', 'LinkVisited', 'AlternateBase', 'NoRole', 'ToolTipBase', 'ToolTipText', &
        'PlaceholderText', 'Accent']

    !> The application's state.
    type :: app_state
        type(QMainWindow) :: window
        type(QStatusBar) :: status
        type(QActionGroup) :: themes, styles
        type(QAction) :: theme_actions(ntheme)
        type(QTabBar) :: tabs
        type(QStackedLayout) :: pages
        type(QTableWidget) :: palette_table, keys_table
        type(QPushButton) :: tip_button
        type(QPalette) :: system_palette     !! the palette at start, for the System theme
        integer :: theme = 1
        type(QColor) :: accent = QColor(0, 0, 0, 255, .false.)   !! unset: the theme's own
        character(len=:), allocatable :: screenshot
    end type app_state

contains

    ! ------------------------------------------------------------------
    ! themes

    !> Apply theme `k` (1..ntheme) with the accent color, if one was picked.
    subroutine apply_theme(s, k)
        type(app_state), intent(inout) :: s
        integer, intent(in) :: k
        type(QPalette) :: pal
        s%theme = k
        select case (k)
        case (1)
            pal = s%system_palette%copy()
        case (2)
            pal = make_palette(window=QColor(240, 240, 240), text=QColor(20, 20, 20), base=QColor(255, 255, 255), &
                               button=QColor(232, 232, 232), highlight=QColor(0, 120, 215), &
                               highlighted_text=QColor(255, 255, 255), link=QColor(0, 90, 180))
        case (3)
            pal = make_palette(window=QColor(45, 45, 48), text=QColor(230, 230, 230), base=QColor(30, 30, 30), &
                               button=QColor(60, 60, 64), highlight=QColor(42, 130, 218), &
                               highlighted_text=QColor(255, 255, 255), link=QColor(90, 170, 255))
        case (4)
            pal = make_palette(window=QColor(253, 246, 227), text=QColor(88, 110, 117), base=QColor(255, 251, 240), &
                               button=QColor(238, 232, 213), highlight=QColor(38, 139, 210), &
                               highlighted_text=QColor(253, 246, 227), link=QColor(108, 113, 196))
        case default
            pal = make_palette(window=QColor(0, 0, 0), text=QColor(255, 255, 255), base=QColor(0, 0, 0), &
                               button=QColor(0, 0, 0), highlight=QColor(255, 230, 0), &
                               highlighted_text=QColor(0, 0, 0), link=QColor(0, 255, 255))
        end select
        if (s%accent%isValid()) then
            call pal%setColor(QPalette_Highlight, s%accent)
            call pal%setColor(QPalette_Accent, s%accent)
        end if
        call QApplication_setPalette(pal)
        ! let native parts (title bars, ...) follow where the platform allows
        if (k == 1) then
            call QGuiApplication_setColorScheme(Qt_ColorScheme_Unknown)
        else if (pal%isDark()) then
            call QGuiApplication_setColorScheme(Qt_ColorScheme_Dark)
        else
            call QGuiApplication_setColorScheme(Qt_ColorScheme_Light)
        end if
        call pal%delete()
        call s%theme_actions(k)%setChecked(.true.)
        call fill_palette_table(s)
        call s%status%showMessage('Theme: '//trim(theme_names(k))//'    Style: '//QApplication_styleName())
    end subroutine apply_theme

    !> A palette from a few base colors; the other roles are derived from them.
    function make_palette(window, text, base, button, highlight, highlighted_text, link) result(pal)
        type(QColor), intent(in) :: window, text, base, button, highlight, highlighted_text, link
        type(QPalette) :: pal
        type(QColor) :: dim
        pal = QPalette(button, window)
        call pal%setColor(QPalette_Window, window)
        call pal%setColor(QPalette_WindowText, text)
        call pal%setColor(QPalette_Base, base)
        call pal%setColor(QPalette_AlternateBase, mix(base, window, 0.5))
        call pal%setColor(QPalette_Text, text)
        call pal%setColor(QPalette_Button, button)
        call pal%setColor(QPalette_ButtonText, text)
        call pal%setColor(QPalette_ToolTipBase, base)
        call pal%setColor(QPalette_ToolTipText, text)
        call pal%setColor(QPalette_Highlight, highlight)
        call pal%setColor(QPalette_HighlightedText, highlighted_text)
        call pal%setColor(QPalette_Link, link)
        call pal%setColor(QPalette_LinkVisited, mix(link, text, 0.3))
        call pal%setColor(QPalette_Accent, highlight)
        dim = mix(text, window, 0.5)
        call pal%setColor(QPalette_PlaceholderText, dim)
        ! disabled widgets: text halfway to the background
        call pal%setColor(QPalette_WindowText, dim, QPalette_Disabled)
        call pal%setColor(QPalette_Text, dim, QPalette_Disabled)
        call pal%setColor(QPalette_ButtonText, dim, QPalette_Disabled)
    end function make_palette

    !> `a` mixed with `b`: t = 0 gives a, t = 1 gives b.
    function mix(a, b, t) result(c)
        type(QColor), intent(in) :: a, b
        real, intent(in) :: t
        type(QColor) :: c
        c = QColor(nint(a%r + t * (b%r - a%r)), nint(a%g + t * (b%g - a%g)), nint(a%b + t * (b%b - a%b)))
    end function mix

    !> A theme was chosen in the menu: its index in the action group.
    subroutine on_theme(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            call apply_theme(s, index + 1)
        end select
    end subroutine on_theme

    !> Ctrl+T: the next theme.
    subroutine on_next_theme(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            call apply_theme(s, mod(s%theme, ntheme) + 1)
        end select
    end subroutine on_next_theme

    !> Pick an accent (highlight) color.
    subroutine on_accent(data)
        class(*), intent(inout), optional :: data
        type(QColor) :: c
        select type (s => data)
        type is (app_state)
            c = QColorDialog_getColor(QColor(42, 130, 218), 'Accent color', s%window)
            if (.not. c%isValid()) return
            s%accent = c
            call apply_theme(s, s%theme)
        end select
    end subroutine on_accent

    !> A style was chosen in the menu.
    subroutine on_style(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        type(qt_string), allocatable :: keys(:)
        select type (s => data)
        type is (app_state)
            keys = QStyleFactory_keys()
            if (QApplication_setStyle(keys(index + 1)%s)) call apply_theme(s, s%theme)
        end select
    end subroutine on_style

    ! ------------------------------------------------------------------
    ! pages

    !> Show every color role of the application palette.
    subroutine fill_palette_table(s)
        type(app_state), intent(inout) :: s
        type(QPalette) :: pal
        type(QTableWidgetItem) :: item
        type(QColor) :: c
        integer :: role, g
        pal = QApplication_palette()
        do role = 0, nroles - 1
            item = QTableWidgetItem(trim(role_names(role + 1)))
            call s%palette_table%setItem(role, 0, item)
            do g = 1, 2
                c = pal%color(role, merge(QPalette_Active, QPalette_Disabled, g == 1))
                item = QTableWidgetItem(c%name())
                call item%setBackground(c)
                if (lightness(c) < 128) then
                    call item%setForeground(QColor(255, 255, 255))
                else
                    call item%setForeground(QColor(0, 0, 0))
                end if
                call s%palette_table%setItem(role, g, item)
            end do
        end do
        call pal%delete()
    end subroutine fill_palette_table

    !> Perceived lightness of a color (0..255).
    integer function lightness(c)
        type(QColor), intent(in) :: c
        lightness = (299 * c%r + 587 * c%g + 114 * c%b) / 1000
    end function lightness

    !> Show the platform's keys for the standard actions.
    subroutine fill_keys_table(s)
        type(app_state), intent(inout) :: s
        type(QTableWidgetItem) :: item
        type(qt_string), allocatable :: bindings(:)
        character(len=:), allocatable :: all, portable
        integer :: i, j
        do i = 1, nkeys
            portable = QKeySequence_standardKey(standard_keys(i))
            bindings = QKeySequence_standardKeyBindings(standard_keys(i))
            all = ''
            do j = 1, size(bindings)
                if (j > 1) all = all//',  '
                all = all//bindings(j)%s
            end do
            item = QTableWidgetItem(trim(key_names(i)))
            call s%keys_table%setItem(i - 1, 0, item)
            item = QTableWidgetItem(portable)
            call s%keys_table%setItem(i - 1, 1, item)
            item = QTableWidgetItem(QKeySequence_nativeText(portable))
            call s%keys_table%setItem(i - 1, 2, item)
            item = QTableWidgetItem(all)
            call s%keys_table%setItem(i - 1, 3, item)
        end do
    end subroutine fill_keys_table

    !> The tab bar chose a page.
    subroutine on_tab(index, data)
        integer, intent(in) :: index
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            call s%pages%setCurrentIndex(s%tabs%tabData(index))
        end select
    end subroutine on_tab

    !> The shortcuts table scrolled.
    subroutine on_scrolled(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        character(len=60) :: msg
        select type (s => data)
        type is (app_state)
            write(msg, '(A,I0,A,I0)') 'Shortcuts table scrolled to row ', value + 1, ' of ', nkeys
            call s%status%showMessage(trim(msg), 2000)
        end select
    end subroutine on_scrolled

    !> Show a tool tip under the button, now.
    subroutine on_tip(data)
        class(*), intent(inout), optional :: data
        type(QPoint) :: p
        select type (s => data)
        type is (app_state)
            p = s%tip_button%mapToGlobal(QPoint(0, s%tip_button%height()))
            call QToolTip_showText(p%x, p%y, 'Theme: '//trim(theme_names(s%theme))//new_line('a')// &
                                   'Style: '//QApplication_styleName(), s%tip_button)
        end select
    end subroutine on_tip

    ! ------------------------------------------------------------------
    ! menus

    !> File > Open.
    subroutine on_open(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            call s%status%showMessage('Open... (a standard shortcut: '// &
                                      QKeySequence_nativeText(QKeySequence_standardKey(QKeySequence_Open))//')', 3000)
        end select
    end subroutine on_open

    !> File > Quit.
    subroutine on_quit(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_quit

    !> Help > Qt documentation.
    subroutine on_help(data)
        class(*), intent(inout), optional :: data
        select type (s => data)
        type is (app_state)
            if (.not. QDesktopServices_openUrl('https://doc.qt.io/qt-6/')) &
                call s%status%showMessage('Could not open the browser', 3000)
        end select
    end subroutine on_help

    !> Save the window for `--screenshot` and quit.
    subroutine on_screenshot(data)
        class(*), intent(inout), optional :: data
        type(QPixmap) :: pix
        select type (s => data)
        type is (app_state)
            pix = s%window%grab()
            if (.not. pix%save(s%screenshot)) write(*, '(A)') 'could not save '//s%screenshot
            call pix%delete()
            call QApplication_quit()
        end select
    end subroutine on_screenshot

    !> The Controls page: one of most kinds of widget, enabled and disabled.
    function controls_page(s) result(page)
        type(app_state), intent(inout) :: s
        type(QWidget) :: page
        type(QGridLayout) :: grid
        type(QGroupBox) :: box
        type(QVBoxLayout) :: col
        type(QPushButton) :: b
        type(QCheckBox) :: check
        type(QRadioButton) :: radio
        type(QLineEdit) :: line
        type(QSpinBox) :: spin
        type(QComboBox) :: combo
        type(QSlider) :: slider
        type(QProgressBar) :: progress
        type(QPlainTextEdit) :: text
        integer :: i
        logical :: on
        page = QWidget()
        grid = QGridLayout(page)
        do i = 1, 2
            on = i == 1
            box = QGroupBox(merge('Enabled ', 'Disabled', on))
            col = QVBoxLayout(box)
            b = QPushButton('Push button')
            call col%addWidget(b)
            check = QCheckBox('Check box')
            call check%setChecked(.true.)
            call col%addWidget(check)
            radio = QRadioButton('Radio button')
            call radio%setChecked(.true.)
            call col%addWidget(radio)
            line = QLineEdit()
            call line%setPlaceholderText('Placeholder text')
            call col%addWidget(line)
            spin = QSpinBox()
            call spin%setValue(42)
            call col%addWidget(spin)
            combo = QComboBox()
            call combo%addItems([character(len=8) :: 'Alpha', 'Beta', 'Gamma'])
            call col%addWidget(combo)
            slider = QSlider(Qt_Horizontal)
            call slider%setValue(60)
            call col%addWidget(slider)
            progress = QProgressBar()
            call progress%setValue(70)
            call col%addWidget(progress)
            call box%setEnabled(on)
            call grid%addWidget(box, 0, i - 1)
        end do
        text = QPlainTextEdit('Selected text uses the Highlight role.'//new_line('a')// &
                              'Links and the accent color follow the theme.')
        call text%selectAll()
        call grid%addWidget(text, 1, 0, 1, 2)
        s%tip_button = QPushButton('Show a tool tip here')
        call s%tip_button%setToolTip('This is the ordinary hover tool tip.')
        call s%tip_button%clicked%connect(on_tip, s)
        call grid%addWidget(s%tip_button, 2, 0)
        b = QPushButton('Accent color...')
        call b%clicked%connect(on_accent, s)
        call grid%addWidget(b, 2, 1)
    end function controls_page

end module themes_app

!> The themes example.
program themes

    use themes_app
    implicit none

    type(QApplication) :: app
    type(app_state), target :: s
    type(QWidget) :: central
    type(QVBoxLayout) :: layout
    type(QMenuBar) :: bar
    type(QMenu) :: file, view, theme_menu, style_menu, help
    type(QAction) :: act
    type(QShortcut) :: next_theme
    type(QHeaderView) :: header
    type(QScrollBar) :: scroll
    type(qt_string), allocatable :: keys(:)
    character(len=512) :: arg
    integer :: i, ierr, theme, tab

    app = QApplication()
    s%system_palette = QApplication_palette()
    if (QApplication_setStyle('Fusion')) continue   ! follows palettes fully on every platform

    s%window = QMainWindow()
    call s%window%setWindowTitle('qt-fortran: themes, styles and shortcuts')
    s%status = s%window%statusBar()

    ! menus
    bar = s%window%menuBar()
    file = bar%addMenu('&File')
    act = QAction('&Open...', s%window)
    call act%setStandardShortcut(QKeySequence_Open)
    call act%triggered%connect(on_open, s)
    call file%addAction(act)
    call file%addSeparator()
    act = QAction('&Quit', s%window)
    call act%setStandardShortcut(QKeySequence_Quit)
    call act%triggered%connect(on_quit, s)
    call file%addAction(act)

    view = bar%addMenu('&View')
    theme_menu = view%addMenu('&Theme')
    s%themes = QActionGroup(s%window)
    do i = 1, ntheme
        s%theme_actions(i) = QAction(trim(theme_names(i)), s%window)
        call s%theme_actions(i)%setCheckable(.true.)
        call s%themes%addAction(s%theme_actions(i))
        call theme_menu%addAction(s%theme_actions(i))
    end do
    call s%themes%triggered%connect(on_theme, s)
    call theme_menu%addSeparator()
    act = QAction('&Accent color...', s%window)
    call act%triggered%connect(on_accent, s)
    call theme_menu%addAction(act)
    style_menu = view%addMenu('&Style')
    s%styles = QActionGroup(s%window)
    keys = QStyleFactory_keys()
    do i = 1, size(keys)
        act = QAction(keys(i)%s, s%window)
        call act%setCheckable(.true.)
        call act%setChecked(keys(i)%s == 'Fusion')
        call s%styles%addAction(act)
        call style_menu%addAction(act)
    end do
    call s%styles%triggered%connect(on_style, s)
    next_theme = QShortcut('Ctrl+T', s%window)
    call next_theme%activated%connect(on_next_theme, s)

    help = bar%addMenu('&Help')
    act = QAction('Qt &documentation', s%window)
    call act%setStandardShortcut(QKeySequence_HelpContents)
    call act%triggered%connect(on_help, s)
    call help%addAction(act)

    ! pages: a tab bar over a stacked layout
    central = QWidget()
    layout = QVBoxLayout(central)
    s%tabs = QTabBar()
    call s%tabs%setExpanding(.false.)
    call layout%addWidget(s%tabs)
    s%pages = QStackedLayout()
    call layout%addLayout(s%pages)

    call s%pages%addWidget(controls_page(s))
    call s%tabs%addTab('Controls')

    s%palette_table = QTableWidget(nroles, 3)
    call s%palette_table%setHorizontalHeaderLabels([character(len=8) :: 'Role', 'Active', 'Disabled'])
    call s%palette_table%setVerticalHeaderVisible(.false.)
    header = s%palette_table%horizontalHeader()
    call header%setSectionResizeMode(0, QHeaderView_ResizeToContents)
    call header%setSectionResizeMode(1, QHeaderView_Stretch)
    call header%setSectionResizeMode(2, QHeaderView_Stretch)
    call s%pages%addWidget(s%palette_table)
    call s%tabs%addTab('Palette')

    s%keys_table = QTableWidget(nkeys, 4)
    call s%keys_table%setHorizontalHeaderLabels([character(len=13) :: 'Action', 'Portable text', 'Native text', &
                                                 'All bindings'])
    call fill_keys_table(s)
    call s%keys_table%setSortingEnabled(.true.)
    header = s%keys_table%horizontalHeader()
    call header%setSectionResizeMode(QHeaderView_ResizeToContents)
    call header%setStretchLastSection(.true.)
    call header%setSortIndicator(0, Qt_AscendingOrder)
    scroll = s%keys_table%verticalScrollBar()
    call scroll%valueChanged%connect(on_scrolled, s)
    call s%pages%addWidget(s%keys_table)
    call s%tabs%addTab('Shortcuts')

    do i = 0, s%tabs%count() - 1
        call s%tabs%setTabData(i, i)            ! the page of each tab (it follows the tab if moved)
    end do
    call s%tabs%setMovable(.true.)
    call s%tabs%currentChanged%connect(on_tab, s)

    call s%window%setCentralWidget(central)
    call s%window%resize(720, 620)

    ! `--screenshot file.png [theme [page]]`
    theme = 1
    tab = 0
    call get_command_argument(1, arg)
    if (arg == '--screenshot') then
        call get_command_argument(2, arg)
        s%screenshot = trim(arg)
        theme = 3
        call get_command_argument(3, arg)
        if (len_trim(arg) > 0) read(arg, *) theme
        call get_command_argument(4, arg)
        if (len_trim(arg) > 0) read(arg, *) tab
        call QTimer_singleShot(300, on_screenshot, s)
    end if
    call apply_theme(s, theme)
    call s%tabs%setCurrentIndex(tab)

    call s%window%show()
    ierr = app%exec()

end program themes
