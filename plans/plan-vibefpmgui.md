# Side project: porting VibeFPMGUI to qt-fortran

[VibeFPMGUI](https://github.com/jacobwilliams/VibeFPMGUI) is a GUI for fpm,
written in Python with PySide6 (through `qtpy`). This plan covers what
qt-fortran needs before the same GUI can be built in Fortran, and in what
order. The app's non-GUI Python dependencies (plotting with
pyqtgraph/numpy, ...) are out of scope.

Survey of the repository as of 2026-10-25: 91 modules, about 52k lines of
Python, using about 120 Qt classes from QtCore, QtGui, QtWidgets and QtSvg.

## Verdict

The GUI can be built with qt-fortran.

- **Already there:** about two thirds of the Qt it uses is bound already, or
  only needs spec entries.
- **New machinery:** three areas need new binding machinery: the code editor,
  a general event-filter/override hook, and custom-painted item delegates.
- **Outside Qt:** the terminal panel and the LSP/DAP clients need work that
  isn't Qt at all.
- **The long pole:** porting the application logic (52k lines of Python,
  likely 1.5-2x that in Fortran). The Qt gaps won't block it.

## How the app uses Qt

- **Composite panels.** Most of its ~90 Qt subclasses are panels and dialogs
  made of child widgets, with no overridden virtuals (`SearchPanel`,
  `ProblemsPanel`, the dialogs, the cards). These map directly onto Fortran
  derived types holding the widgets, as in the explorer example.
- **Virtual overrides.** About 45 classes override Qt virtual methods. These
  define the gaps below.

## Already covered

| Area | Used by the app |
|---|---|
| Window structure | `QMainWindow`, `QDockWidget`, `saveState`/`restoreState`, `QSplitter`, `QStackedWidget`, `QScrollArea`, `QTabWidget` |
| Widgets | `QLabel`, `QPushButton`, `QToolButton`, `QLineEdit`, `QCheckBox`, `QRadioButton`, `QComboBox`, `QSpinBox`, `QButtonGroup`, `QFrame` |
| Layouts | `QVBoxLayout`, `QHBoxLayout`, `QGridLayout`, `QFormLayout` |
| Commands | `QMenu`, `QMenuBar`, `QToolBar`, `QAction` |
| Dialogs | `QDialog`, `QMessageBox`, `QFileDialog`, `QInputDialog`, `QFontDialog`, `QDialogButtonBox` |
| Items and models | `QTreeWidget`, `QTableWidget`, `QListWidget`, `QTableView`/`QTreeView` with `QtfTableModel`/`QtfTreeModel`, `QSortFilterProxyModel`, `QCompleter` |
| Text | `QTextBrowser` (its Markdown view), `QPlainTextEdit` (basic) |
| Core | `QTimer`, `QThread` (`QThread_create` for its workers), `QSettings` |
| Events | mouse, key, wheel, resize, close, context menu, focus, show/hide, enter/leave |
| Painting | `QtfWidget` + `QPainter`, `QColor`, `QPen`, `QBrush`, `QFont`, `QImage`, `QPixmap`, `QIcon`, `QStyle` standard icons |

`QtfWidget` covers the custom-drawn `QWidget` subclasses, which override
`paintEvent` and mouse/key/wheel events: the dependency graph, minimap, punch
card, progress line, git stats, animated logo, blame column and terminal view.

## Gaps

### A. Spec-only additions (the generator handles these)

- [ ] **`QProcess`** and `QProcessEnvironment`: start, kill, terminate,
      write, closeWriteChannel, working directory, environment, merged
      channels, waitForFinished, startDetached; signals `started`, `finished`
      (exit code and status), `errorOccurred`, `readyReadStandardOutput`/`Error`.
      The app runs fpm, git and the language servers through it (`.start`
      x115, `finished` x40). **Do this first.**
- [ ] Painting: `QPainterPath`, `QLinearGradient`, `QFontMetrics(F)`
      (horizontalAdvance, height, elidedText), more `QPointF`/`QRectF`
      drawing calls.
- [ ] Theming: `QPalette` (roles x groups; `setColor`, `QApplication_setPalette`)
      and `QStyleFactory` / `QApplication_setStyle('Fusion')`. The app uses
      `QPalette` 149 times for its themes and dark mode.
- [ ] Services:
  - `QClipboard` (text);
  - `QToolTip_showText` / `hideText`;
  - `QDesktopServices_openUrl`;
  - `QCursor_pos`, override cursor;
  - `QFontDatabase_systemFont(FixedFont)`;
  - `QKeySequence` standard keys and native text.
- [ ] Widgets and layout:
  - `QActionGroup`, `QStackedLayout`;
  - `QTabBar` (standalone);
  - `QHeaderView` options (resize modes, section sizes);
  - `QScrollBar` access (value, range, signals).
- [ ] Docks:
  - `resizeDocks`, `splitDockWidget`, `setCorner`, `setTitleBarWidget`;
  - `setFloating`/`isFloating`, `tabifiedDockWidgets`, `setTabPosition`,
    `setDockOptions`, `setAllowedAreas`;
  - signals `topLevelChanged`, `dockLocationChanged`, `visibilityChanged`.
- [ ] Files: `QFileSystemWatcher`, `QFileIconProvider`.
- [ ] QtSvg: `QSvgRenderer` (SVG icons) and `QSvgGenerator` (graph export).
      Add `Qt6Svg` to the link list (it is already in the pixi env).
- [ ] Item data: an integer (and string) value per item on `QTreeWidgetItem`,
      `QTableWidgetItem` and `QListWidgetItem`. The app attaches objects to
      items 46 times (`Qt.UserRole`); in Fortran, store an index into your own
      arrays.
- [ ] More cell roles for `QtfTableModel`/`QtfTreeModel`: tooltip,
      foreground and background color, font, icon
      (`request%setToolTip(...)`, ...).

### B. New machinery

1. **Code editor (the biggest item).** `CodeEditor` is a `QPlainTextEdit`
   with four mixins (gutter, issues, multi-cursor, line edits). It overrides
   11 virtuals and uses the text-document API heavily (`textCursor` x69,
   `document` x68, `blockNumber` x58, `setPosition` x53,
   `findBlockByNumber` x32). It needs:
   - [ ] Bindings for `QTextCursor` (movePosition, setPosition, selection,
         insertText, edit blocks), `QTextDocument`/`QTextBlock` (find by
         number, block count, text, position, user state), and
         `QTextCharFormat` (color, background, underline style, bold).
   - [ ] Extra selections (current line, matches, multi-cursor), as arrays
         of (cursor range, format).
   - [ ] `QtfPlainTextEdit`, which forwards key/mouse/wheel/focus/resize/
         context-menu events. Each event carries a "consume" flag, so Fortran
         can replace the default handling (completion, multi-cursor,
         auto-indent).
   - [ ] A viewport paint hook that runs after Qt draws the text (underlines,
         markers).
   - [ ] Access to protected methods: `firstVisibleBlock`,
         `blockBoundingGeometry`, `contentOffset`, `setViewportMargins` (for
         the line-number gutter).
   - [ ] `QtfSyntaxHighlighter`: a Fortran `highlightBlock(text)` slot calls
         `setFormat(start, length, format)` and gets/sets the block state.
         This is the same request pattern as the Fortran-backed models.
   - [ ] `cursorForPosition`, `cursorRect`, `centerCursor`,
         `ensureCursorVisible`, `find`, tab stop distance, wrap modes.
2. **General event filter / override hook.** The app uses `eventFilter` 14
   times, often on other objects (a viewport, the docks, the application).
   It also overrides `keyPressEvent` on `QLineEdit`, `QTreeWidget` and
   `QDialog`, `mouseReleaseEvent` on `QMenu`, and `sizeHint`/
   `minimumSizeHint` (16 times).
   - [ ] Extend `QtfEventFilter` to forward mouse/key/wheel/resize events from
         any object, with a "consume" result, and allow installing it on
         objects other than the widget itself (including the application).
   - [ ] `QtfWidget%setSizeHint` / `setMinimumSizeHint`; a few `Qtf`
         subclasses where a widget's size hint must come from Fortran.
3. **Custom-painted item delegates.** There are 10 `QStyledItemDelegate`
   subclasses with `paint` (most with `sizeHint`): build rows, test results,
   the git log graph, completion kinds, search results.
   - [ ] A `QtfItemDelegate` paint hook: a slot that gets a painter, the cell
         rectangle, its state (selected, hover, focus) and the cell (row and
         column, or node); plus a size request.
   - [ ] A `QSortFilterProxyModel` filter callback into Fortran
         (`filterAcceptsRow`).

### C. Outside Qt (needed by the app, not the GUI)

- **Terminal panel:**
  - a pseudo-terminal (`forkpty` on Unix, ConPTY/winpty on Windows) through C
    interop, plus `QSocketNotifier` (easy to bind);
  - a VT100 emulator, which `pyte` provides today.

  Start with a plain `QProcess` console instead.
- **LSP and DAP clients:** JSON-RPC over `QProcess`; JSON from json-fortran.
- **Other pieces:**
  - `fpm.toml` and `vibefpm.json`: toml-f and json-fortran;
  - syntax lexers (`pygments` today): hand-written Fortran and TOML
    tokenizers for the highlighter;
  - git: through `QProcess`.
- **Small ones:** `QProxyStyle::styleHint` (one tweak; emulate or drop);
  `QRunnable`/`QThreadPool` (use `QThread_create`).

## Milestones

1. **Skeleton app.** Gap A: `QProcess` first, then docks, services and
   `QPalette`. Build the main window and docks, the *Build options* panel,
   the project tree, fpm build/run/test with live output, the problems list,
   and settings. This proves the app's architecture in Fortran early.
2. **Editor.** Gap B1: text-document bindings, `QtfPlainTextEdit`,
   `QtfSyntaxHighlighter`, the gutter. Fortran and TOML lexers. Most of the
   binding design happens here.
3. **Polished panels.** Gaps B2 and B3: the general event filter and painted
   delegates, for the test monitor, git log graph, command palette, quick
   open and completion popup.
4. **Custom docking.** The `dock_snap.py` behavior (snapping, grips,
   collapsing sides). It needs B2 and the dock APIs from A. Port it last.
5. **Terminal, LSP and DAP.** The non-Qt work of gap C, alongside the other
   milestones.

## Effort

- **Bindings:** gap A is mostly mechanical. B1 needs real design work; B2 and
  B3 are moderate. In total, roughly 10-15 sessions like the recent
  qt-fortran ones.
- **Application port:** 52k lines of Python, likely 1.5-2x as many lines of
  Fortran. This dominates the total.
