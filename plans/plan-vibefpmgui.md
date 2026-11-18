# Side project: porting VibeFPMGUI to qt-fortran

[VibeFPMGUI](https://github.com/jacobwilliams/VibeFPMGUI) is a GUI for fpm,
written in Python with PySide6 (through `qtpy`). This plan covers what
qt-fortran needs before the same GUI can be built in Fortran, and in what
order. The app's non-GUI Python dependencies (plotting with
pyqtgraph/numpy, ...) are out of scope.

Survey of the repository as of 2026-10-25: 91 modules, about 52k lines of
Python, using about 120 Qt classes from QtCore, QtGui, QtWidgets and QtSvg.

> **Status (2026-11-17): the Qt bindings are done.** Every item of gaps A
> and B below is checked off, with tests and examples (`editor`, `themes`,
> `ide`). What remains is the non-Qt work of gap C and the port of the
> application itself (see Milestones).

## Verdict

The GUI can be built with qt-fortran.

- **Already there:** about two thirds of the Qt it uses was bound already, or
  only needed spec entries. *(All done.)*
- **New machinery:** three areas needed new binding machinery: the code
  editor, a general event-filter/override hook, and custom-painted item
  delegates. *(All done.)*
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

- [x] **`QProcess`** and `QProcessEnvironment`: start, kill, terminate,
      write, closeWriteChannel, working directory, environment, merged
      channels, waitForFinished, startDetached; signals `started`, `finished`
      (exit code and status), `errorOccurred`, `readyReadStandardOutput`/`Error`.
      The app runs fpm, git and the language servers through it (`.start`
      x115, `finished` x40). *Done (spec/core_classes.toml,
      test/test_process.f90); output is read as raw bytes.*
- [x] Painting: `QPainterPath`, `QLinearGradient`, `QFontMetrics(F)`
      (horizontalAdvance, height, elidedText), more `QPointF`/`QRectF`
      drawing calls. *Done.*
- [x] Theming: `QPalette` (roles x groups; `setColor`, `QApplication_setPalette`)
      and `QStyleFactory` / `QApplication_setStyle('Fusion')`. The app uses
      `QPalette` 149 times for its themes and dark mode. *Done, plus
      `QGuiApplication_colorScheme`/`setColorScheme` (example/themes.f90).*
- [x] Services:
  - [x] `QClipboard` (text);
  - [x] `QToolTip_showText` / `hideText`;
  - [x] `QDesktopServices_openUrl`;
  - [x] `QCursor_pos`, override cursor;
  - [x] `QFontDatabase_systemFont(FixedFont)` (as `QFontDatabase_fixedFamily`);
  - [x] `QKeySequence` standard keys and native text
        (`QKeySequence_standardKey`, `QKeySequence_nativeText`,
        `QAction%setStandardShortcut`; also `QShortcut`).
- [x] Widgets and layout:
  - `QActionGroup`, `QStackedLayout`;
  - `QTabBar` (standalone);
  - `QHeaderView` options (resize modes, section sizes);
  - `QScrollBar` access (value, range, signals).
  *Done; the scroll bars come from a new `QAbstractScrollArea` base.*
- [x] Docks:
  - [x] `resizeDocks`, `splitDockWidget`, `setCorner`, `setTitleBarWidget`;
  - [x] `tabifiedDockWidgets`, `setTabPosition`, `setDockOptions`
        (also `setFloating`/`isFloating`, `setAllowedAreas`, `tabifyDockWidget`);
  - [x] signal `dockLocationChanged` (also `topLevelChanged`, `visibilityChanged`).
  *Done (example/ide.f90, test/test_panels.f90).*
- [x] Files: `QFileSystemWatcher`, `QFileIconProvider`. *Done, plus
      `QDir_entryList`/`QDir_isDir`.*
- [x] QtSvg: `QSvgRenderer` (SVG icons) and `QSvgGenerator` (graph export).
      `Qt6Svg` is now linked. *Done (`toIcon`/`toImage`; generators write
      to a file or memory).*
- [x] Item data: an integer (and string) value per item on `QTreeWidgetItem`,
      `QTableWidgetItem` and `QListWidgetItem`. The app attaches objects to
      items 46 times (`Qt.UserRole`); in Fortran, store an index into your own
      arrays. *Done: `setData`/`data`/`stringData`, and `findData` on the
      widgets (QListWidget items are addressed by row).*
- [x] More cell roles for `QtfTableModel`/`QtfTreeModel`: tooltip,
      foreground and background color, font, icon
      (`request%setToolTip(...)`, ...). *Done (also check boxes, status
      tips, alignment).*

### B. New machinery

1. **Code editor (the biggest item).** `CodeEditor` is a `QPlainTextEdit`
   with four mixins (gutter, issues, multi-cursor, line edits). It overrides
   11 virtuals and uses the text-document API heavily (`textCursor` x69,
   `document` x68, `blockNumber` x58, `setPosition` x53,
   `findBlockByNumber` x32). It needs:
   - [x] Bindings for `QTextCursor` (movePosition, setPosition, selection,
         insertText, edit blocks), `QTextDocument`/`QTextBlock` (find by
         number, block count, text, position, user state), and
         `QTextCharFormat` (color, background, underline style, bold).
         *Done: QTextBlock is a plain Fortran value (document + number);
         QTextCharFormat a value type in qt_gui_types.*
   - [x] Extra selections (current line, matches, multi-cursor), as arrays
         of (cursor range, format). *Done: `addExtraSelection(s)`,
         `clearExtraSelections` on QPlainTextEdit.*
   - [x] `QtfPlainTextEdit`, which forwards key/mouse/wheel/focus/resize/
         context-menu events. Each event carries a "consume" flag, so Fortran
         can replace the default handling (completion, multi-cursor,
         auto-indent). *Done through `QtfEventFilter` on the editor (keys)
         and on its `viewport()` (mouse), whose slots consume an event by
         accepting it.*
   - [x] A viewport paint hook that runs after Qt draws the text (underlines,
         markers). *Done: `viewportPaintEvent`.*
   - [x] Access to protected methods: `firstVisibleBlock`,
         `blockBoundingGeometry`, `contentOffset`, `setViewportMargins` (for
         the line-number gutter). *Done, plus `lastVisibleBlockNumber` and a
         built-in gutter (`setGutterWidth`, `gutter()`: a QtfWidget kept in
         place and scrolled with the text).*
   - [x] `QtfSyntaxHighlighter`: a Fortran `highlightBlock(text)` slot calls
         `setFormat(start, length, format)` and gets/sets the block state.
         This is the same request pattern as the Fortran-backed models.
         *Done; offsets are bytes of the slot's text, converted to Qt's
         UTF-16 positions.*
   - [x] `cursorForPosition`, `cursorRect`, `centerCursor`,
         `ensureCursorVisible`, `find`, tab stop distance, wrap modes.
         *Done (example/editor.f90, test/test_code_editor.f90).*
2. **General event filter / override hook.** The app uses `eventFilter` 14
   times, often on other objects (a viewport, the docks, the application).
   It also overrides `keyPressEvent` on `QLineEdit`, `QTreeWidget` and
   `QDialog`, `mouseReleaseEvent` on `QMenu`, and `sizeHint`/
   `minimumSizeHint` (16 times).
   - [x] Extend `QtfEventFilter` to forward mouse/key/wheel/resize events from
         any object, with a "consume" result, and allow installing it on
         objects other than the widget itself (including the application).
         *Done: `QtfEventFilter(target)` on any QObject.*
   - [x] `QtfWidget%setSizeHint` / `setMinimumSizeHint`; a few `Qtf`
         subclasses where a widget's size hint must come from Fortran.
         *Done on QtfWidget (wrap other widgets in one, with a layout, when
         their hint must come from Fortran).*
3. **Custom-painted item delegates.** There are 10 `QStyledItemDelegate`
   subclasses with `paint` (most with `sizeHint`): build rows, test results,
   the git log graph, completion kinds, search results.
   - [x] A `QtfItemDelegate` paint hook: a slot that gets a painter, the cell
         rectangle, its state (selected, hover, focus) and the cell (row and
         column, or node); plus a size request. *Done: `paintCell` with a
         `QtfPaintCell`, and `setSizeHint`.*
   - [x] A `QSortFilterProxyModel` filter callback into Fortran
         (`filterAcceptsRow`). *Done: `QtfSortFilterProxyModel`.*

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

The bindings were milestones' prerequisites; they are all in place, so each
milestone below is now port work.

1. **Skeleton app.** The main window and docks, the *Build options* panel,
   the project tree, fpm build/run/test with live output (`QProcess`), the
   problems list, and settings. This proves the app's architecture in
   Fortran early. The `ide` example already has the main-window, project-tree
   and dock-layout pieces (file icons, item data, a file watcher, quick open
   with a Fortran filter).
2. **Editor.** Fortran and TOML lexers for `QtfSyntaxHighlighter`, on the
   existing `QtfPlainTextEdit` (gutter, extra selections, viewport painting,
   event filters). The `editor` example is the starting point.
3. **Polished panels.** The test monitor, git log graph, command palette,
   quick open and completion popup, with painted delegates
   (`QtfItemDelegate%paintCell`), event filters and `QtfSortFilterProxyModel`.
4. **Custom docking.** The `dock_snap.py` behavior (snapping, grips,
   collapsing sides), on the dock APIs and `QtfEventFilter`. Port it last.
5. **Terminal, LSP and DAP.** The non-Qt work of gap C, alongside the other
   milestones. Start the terminal as a plain `QProcess` console.

### Bindings that may still turn up

Not checked against the app's source; add them when the port needs them:

- ~~`QSocketNotifier`, for a pseudo-terminal's file descriptor (gap C).~~
  *Done, with `QWinEventNotifier` for ConPTY handles on Windows.*
- A `lessThan` sort callback on `QtfSortFilterProxyModel`, if sorting in
  Fortran is needed beyond `QtfTableModel`'s `sortRequested`.
- Anything else a ported module uses that isn't bound: most such additions
  are spec entries.

## Effort

- **Bindings:** done (gaps A and B, over the qt-fortran sessions up to
  2026-11-17). Expect only small spec additions during the port.
- **Gap C:** moderate. The lexers and the JSON/TOML handling are
  straightforward with toml-f and json-fortran; the pseudo-terminal and a
  VT100 emulator are the largest pieces.
- **Application port:** 52k lines of Python, likely 1.5-2x as many lines of
  Fortran. This dominates the total.
