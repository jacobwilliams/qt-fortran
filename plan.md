# qt-fortran: plan

A Modern Fortran interface to Qt 6. It uses standard Fortran C interoperability
(`iso_c_binding`) to call Qt through a thin C++ shim, much as PySide6 wraps the
Qt C++ API for Python. Builds use fpm, and everything compiles inside the pixi
environment.

## Decisions

| Topic | Decision |
|-------|----------|
| API naming | Qt style: `QPushButton`, `btn%setText(...)`, `clicked`. The Qt/PySide docs carry over directly. |
| Qt modules | QtCore, QtGui, QtWidgets, plus QtOpenGL / QtOpenGLWidgets for 3D. |
| Platforms | Cross-platform: Linux, macOS, Windows. |
| Build | fpm builds everything, including the C++ shim in `src/shim` (Linux, macOS, MinGW). `tools/fpm_qt.py` supplies the C++ compiler and Qt flags. Only Windows with conda's MSVC Qt uses a separate shim DLL. |
| Toolchain | gfortran on all OSes. See the table below. |
| moc | Not used. Signals connect through C++ lambdas, and virtual overrides use small C++ subclasses without `Q_OBJECT`. |

## Architecture

```
user code   ->  use qt                      Modern Fortran OO API
                qt.f90 -> qt_core, qt_gui_types, qt_gui, qt_widgets
            ->  qt_c_*.f90                  raw bind(C) interfaces (GENERATED from the shim)
                qt_c_util.f90               hand-written: qtf_args, string/bool conversion
            ->  src/shim/qtf_*.cpp          extern "C" shim over Qt C++ (compiled by fpm)
            ->  libQt6Core / Gui / Widgets
```

- **Bindings are generated from specs.** `spec/<module>.toml` describes each
  class: its base, docs, constructors, methods and signals, in a compact
  signature syntax such as `"setRange(minimum: int, maximum: int) -- doc"`.
  `tools/gen_bindings.py` turns it into the C++ shim (`src/shim/qtf_<module>.cpp`)
  and the high-level module (`src/<module>/qt_<module>.f90`). Irregular code
  stays in the spec as verbatim C++/Fortran blocks (e.g. the QtfWidget class,
  `QPainter%end`). The docstring at the top of gen_bindings.py documents the format.

  | module | source |
  |--------|--------|
  | widgets | generated from `spec/widgets.toml` |
  | gui | generated from `spec/gui.toml`; value types hand-written in `qt_gui_types.f90` |
  | core | hand-written (dispatcher, QObject, QTimer, QEvent: infrastructure, not bindings) |

  To add an API, edit the spec and run `pixi run gen`. Never edit generated files.
- **C++ shim**: flat `extern "C"` functions (`qtf_<class>_<method>`). Qt objects
  are passed as opaque `void*`, and only C types are used.
- **Raw Fortran layer**: one interface per shim function. No logic.
  `tools/gen_c_interfaces.py` generates these modules (and the `QTF_SIG_*` ids)
  from the `QTF_API` declarations, so don't edit them by hand: change the shim,
  then run `pixi run gen`. CI runs `pixi run gen-check` (Linux job) to catch drift.
- **High-level layer**: derived types follow the Qt class hierarchy
  (`QObject -> QWidget -> QLabel ...`). Each one holds a `type(c_ptr)`.
  Constructors are generic interfaces named after the type
  (`label = QLabel("text", parent=w)`), and methods are type-bound procedures.

### Conventions

- **Strings in**: pass `character(*)` plus its length. The shim calls
  `QString::fromUtf8(p, len)`, so no NUL terminator is needed.
- **Strings out**: the shim returns a malloc'd UTF-8 buffer and its length.
  Fortran copies it into `character(len=:), allocatable` and calls `qtf_free`.
- **Signals & slots**: signals are components of the emitting object, as in PySide:
  `call timer%timeout%connect(on_tick, state)`. There is one signal type per
  argument shape, each with a matching slot interface: `QSignal`/`qt_slot`
  (no argument), `QSignalBool`, `QSignalInt`, `QSignalDouble`, `QSignalString`,
  and, in qt_gui, `QSignalPainter`, `QSignalMouseEvent`, `QSignalKeyEvent`,
  `QSignalWheelEvent`, `QSignalResizeEvent`.
  - **Slots** are ordinary Fortran procedures (no `bind(C)`) with a final
    `class(*), intent(inout), optional :: data` argument.
  - **`data`** is stored by reference. It must have TARGET/POINTER and outlive
    the connection.
  - **Dispatch**: C++ calls one Fortran `bind(C)` dispatcher with a slot index
    and a `qtf_args` block. Fortran keeps a registry of procedure pointers plus data.
  - **Lifetime**: each connection holds a `shared_ptr` slot handle. When Qt
    destroys the connection (sender deleted, single-shot fired), the
    registry entry is released (`qt_slot_count()`).
  - **Connectors**: signal ids (`QTF_SIG_*`) live in `src/shim/qtf_common.h` (core)
    or in the generated shims (assigned from each spec's `signal_base`).
    gen_c_interfaces copies them into the raw modules. Each shim file
    registers its connectors at load time.
  - **Extension point**: slot kinds defined outside qt_core (the gui event and
    painter slots) extend the abstract `qt_slot_handler` with a typed procedure
    pointer and an `invoke` that converts the raw `qtf_args` (an event or painter
    pointer arrives in `args%p`). They connect through `qt_connect_handler`.
  - **Avoid host association in slots**: put slots in modules and pass state
    through `data`. Internal procedures that use host variables need gfortran
    trampolines, which aren't portable.
- **Object wrappers**: each type holds `ptr` plus its signal components.
  `%attach(ptr)` binds a wrapper to an existing Qt object. Extended types
  override it to bind their own signals.
- **Static methods**: exposed as free procedures `QClass_method`
  (`QTimer_singleShot`, `QApplication_quit`) and, where natural, as `nopass`
  bindings (`app%exec()`).
- **Ownership**: follows Qt's parent/child model. No finalizers. Parented
  objects belong to Qt, and top-level objects use an explicit `%delete()`.
  A `QPointer`-backed handle may be added later to detect use after delete.
- **Enums/flags**: `integer(c_int), parameter` constants. Qt namespace values are
  `Qt_<Value>` (e.g. `Qt_AlignCenter`), and class enums are `QClass_<Value>`
  (e.g. `QMessageBox_Yes`, `QDialog_Accepted`). Flags combine with `ior`.
  **Fortran is case-insensitive**, so when a constant would clash with a
  function, the constant is qualified with its enum name, as in PySide6:
  `QMessageBox_Icon_Information` vs the function `QMessageBox_information`.
- **Indices are 0-based**, as in Qt (combo box items, grid rows/columns, ...),
  so the Qt docs apply unchanged.
- **Scalars**: Qt `int` is default `integer`, `bool` is `logical`, and `double`
  is `real(c_double)` (= real64). Shim booleans cross the boundary as 0/1 `int`.
- **Optional `parent`** comes last in constructors (as in Qt) and also in static
  functions, e.g. `QMessageBox_question(title, text, buttons, defaultButton, parent)`.
  This differs from Qt's order, because Fortran can't conveniently omit a
  leading optional argument.
- **Signals whose argument is rarely wanted** drop it, e.g. `clicked` is a
  no-argument `QSignal`; the state is available via `toggled` / `isChecked()`.
- **Method overloads that Fortran can't express as overrides** (e.g.
  `addWidget` differs between box and grid layouts) are defined on each
  concrete base (`QBoxLayout`, `QGridLayout`), not on `QLayout`.
- **Casting**: `call box%attach(w%ptr)` rebinds a handle as a more derived type
  (check `w%inherits('QMessageBox')` first). Used for `activeModalWidget()` etc.
- **Value types**: `QColor`, `QPen`, `QBrush`, `QFont` are plain Fortran types
  (as Qt treats them as values), built with structure constructors, e.g.
  `QPen(Qt_red, 2.0_c_double)`, `QFont(pointSize=9d0, bold=.true.)`, with fields
  passed to the shim as scalars. No C++ allocation, nothing to free.
  `QColor('steelblue')` parses names. `Qt_red` etc. are `QColor` parameters.
- **C++-backed non-QObjects** (`QImage`, `QPixmap`, a `QPainter` on an image,
  synthetic events built with `QMouseEvent(...)` etc.) are owned by Fortran:
  release them with `delete` (or `end` for painters). Events and painters
  received in slots are borrowed: never delete or end them.
- **Overriding virtual functions**: `QtfWidget` (a `Qtf` prefix marks a
  qt-fortran class, not a Qt one) forwards `paintEvent`, mouse, wheel, key and
  resize handlers to signals, e.g. `canvas%paintEvent%connect(on_paint, s)`.
  An event without slots gets Qt's default handling. This departs from PySide:
  paint slots receive a painter that is already active and is ended by Qt
  afterwards, so the "forgot `painter.end()`" bug can't happen.
- **Integer or real coordinates**: drawing methods are generics over default
  `integer` and `real(c_double)` (`drawLine(0, 0, 10, 10)` or with reals).
- **String lists** are returned as `type(qt_string)` arrays (`files(i)%s`). The
  shim sends them as one buffer of NUL-terminated strings.
- **Qt functions that return a rarely used pointer** (`QMenu::addSeparator`,
  `QToolBar::addWidget` return a `QAction*`) are subroutines.
- **C++ pitfall**: `slots`, `signals` and `emit` are Qt macros; don't use them as
  identifiers in the shim.

## Platforms & toolchains (and fpm packaging)

gfortran 15 is the Fortran compiler on every platform. The C++ shim
(`src/shim/*.cpp`) has a pure C interface (opaque pointers, ints, `char*`,
function pointers). It must be compiled by a C++ compiler that matches the ABI
of the Qt binaries.

**Linux, macOS, and Windows with a MinGW Qt (MSYS2): fpm builds the shim** as
part of the `qt-fortran` library, like any C++ source in `src/`. This holds for
qt-fortran itself and for every project that depends on it.
- **`fpm.toml` declares the Qt libraries** in `[build] link`. They propagate to
  dependent projects and are placed *after* the objects on the link line.
- **The C++ runtime** comes from a `default` feature, which fpm always applies:
  `default.macos.link-time-flags = "-lc++"` and
  `default.linux.link-time-flags = "-lstdc++"`. These are also placed after the
  objects.
- **Machine-specific settings** come from fpm's standard environment variables:
  - `FPM_CXX`: `clang++` on macOS (libc++, like Qt), `g++` elsewhere.
  - `FPM_CXXFLAGS`: `-std=c++17 -fPIC` plus the Qt include paths from pkg-config.
    Qt requires position-independent code.
  - `FPM_LDFLAGS`: the Qt library directory and rpath.
- **`tools/fpm_qt.py`** computes these settings. `--env` prints them as exports;
  otherwise it runs fpm with them. It works from any project root.

**Windows with conda-forge Qt (MSVC-built): separate shim DLL.** gfortran there
is MinGW, which can't link MSVC C++ objects.
- `fpm_qt.py` builds `build/qtf/qtf.dll` with clang++ in MSVC mode.
- fpm compiles the shim sources as empty files (`-DQTF_EXTERNAL_SHIM` guards
  every shim file).
- The DLL is passed to the linker as an *input file*, not `-lqtf`. ld resolves
  symbols from a DLL regardless of its position on the command line, whereas an
  import library before the objects would be skipped.
- Qt and the DLL are found through `PATH` at run time.

| Setup | Shim built by | C++ compiler | C++ runtime | Qt flags | Runtime lookup |
|-------|---------------|--------------|-------------|----------|----------------|
| Linux | fpm | g++ | `-lstdc++` (fpm feature) | pkg-config | rpath |
| macOS | fpm | clang++ (libc++) | `-lc++` (fpm feature) | pkg-config | rpath |
| Windows, MinGW Qt (MSYS2) | fpm | g++ | `-lstdc++` (fpm_qt.py) | pkg-config | `PATH` |
| Windows, conda-forge Qt | fpm_qt.py → `qtf.dll` | clang++ `--target=x86_64-pc-windows-msvc`, `-fms-runtime-lib=dll` | inside the DLL | from `%CONDA_PREFIX%\Library` (no .pc files) | `PATH` |

Consequences:
- Every shim function is declared with `QTF_API` (`src/shim/qtf_common.h`).
- The Windows DLL links only the dynamic CRT (`/NODEFAULTLIB` for libcmt,
  libucrt, libvcruntime, libcpmt). Otherwise malloc/free bind into a second,
  static runtime (`LNK4098`/`LNK4217`).
- Memory allocated by the shim must be freed by the shim (`qtf_free`), never by
  Fortran. With the Windows DLL, the two sides use different C runtimes.
- On Windows with conda, the MSVC linker/SDK come from `cxx-compiler` (vs2022
  activation), so Visual Studio Build Tools must be installed on the host.
  GitHub's Windows runners have them.
- The project path must not contain spaces, because fpm splits flag strings on spaces.
- fpm does not relink executables when only an external library changed. So
  when `fpm_qt.py` rebuilds the Windows DLL, it clears fpm's object cache.
- Qt is linked as plain `-lQt6Xxx` libraries. Distributions that ship Qt only
  as macOS frameworks (Homebrew) are not supported; conda-forge Qt is.
- CI builds and runs `ci/consumer`, a separate fpm project that depends on
  qt-fortran (`path = "../.."`).

History:
- **First attempt:** fpm compiled the shim, with flang + clang++ on Windows.
  flang on Windows proved unusable in CI (`iso_c_binding` was unavailable).
- **Second design:** the shim became a separate shared library on every platform.
  That made qt-fortran awkward to use as an fpm dependency.
- **Current design:** fpm 0.13 can compile C++ in a dependency's `src/`,
  propagates `[build] link`, and supports per-OS `link-time-flags` through a
  `default` feature. So the shim went back into fpm on Linux/macOS (and MinGW).
  The DLL is kept only for conda's MSVC Qt on Windows.

Portability rules for sources:
- Keep Fortran sources ASCII. Build non-ASCII test strings from explicit
  UTF-8 bytes (`achar(...)`), because compilers treat non-ASCII literals differently.
- Use only standard `iso_c_binding` in Fortran. No compiler extensions.
- No `-fPIC` or other unix-only flags in shared settings. Flags live in
  `tools/fpm_qt.py`, one set per OS.

## Build & run

```sh
pixi run build             # fpm build with Qt flags
pixi run test              # headless (QT_QPA_PLATFORM=offscreen)
pixi run example hello     # run an example (hello, timer, form, plot, explorer, surface3d, orbit3d)
pixi run gen               # specs -> shims + high-level modules -> raw bind(C) modules
pixi run gen-check         # fail if any generated file is stale (CI)
pixi run lint              # docstrings + implicit none in interface bodies (CI)
pixi run test-gl           # the OpenGL test on the real display (CI: macOS)
```

Every module, program, procedure, derived type and generic interface has a
FORD docstring (`!>` before or `!!` after, per `ford.md`), and every interface
body has `implicit none`. Interface bodies do not inherit the host's implicit
typing rules. `tools/check_fortran.py` enforces both. The generated raw modules
take their docstrings from the `//` comment above each shim function, plus its
C prototype.

`plot --screenshot out.png` renders the live plot headlessly to a PNG (with
`QT_QPA_PLATFORM=offscreen`). This is useful for docs and visual checks.

## Layout

```
src/
  qt.f90                    umbrella module: use qt
  core/    qt_c_core.f90*   qt_c_util.f90  qt_core.f90   QObject, QTimer, QEvent, signals/slots, Qt_* constants
  gui/     qt_c_gui.f90*    qt_gui.f90**   qt_gui_types.f90
                            QPainter, QImage, QPixmap, input events, QAction | QColor/QPen/QBrush/QFont
  widgets/ qt_c_widgets.f90* qt_widgets.f90**            QApplication, widgets, layouts, QtfWidget, menus,
                                                         dialogs, QFileDialog
           (* generated by gen_c_interfaces.py, ** generated by gen_bindings.py)
spec/      gui.toml widgets.toml                         binding specs
  shim/    qtf_common.h qtf_core.cpp  qtf_gui.cpp** qtf_widgets.cpp** qtf_opengl.cpp**  (C++ shim, compiled by fpm)
ci/consumer/                 a separate fpm project depending on qt-fortran (CI check and template)
tools/     fpm_qt.py           C++/Qt settings for fpm (or the Windows shim DLL), drives fpm
           gen_bindings.py     specs -> shim + high-level module
           gen_c_interfaces.py shim -> raw bind(C) module
           check_fortran.py    docstring / implicit-none checker
example/   hello, timer, form, plot, explorer (a tour of most features)
test/      testing.f90 (check helper), test_core, test_widgets, test_controls, test_layouts,
           test_dialogs, test_gui, test_events, test_menus, test_filedialog
```

## Phases

| # | Goal | Done when | Status |
|---|------|-----------|--------|
| 0. Spike | C++ compiler in pixi, pixi tasks, minimal shim, Fortran `QLabel` window | `pixi run example hello` shows a window; the headless test passes | **done** |
| 0b. Cross-platform | Shim as shared library, gfortran everywhere, `tools/fpm_qt.py` driver, GitHub Actions matrix (ubuntu/macos/windows, offscreen tests) | CI green on all three | **done**: CI green on ubuntu, macos, windows |
| 1. Core infra | String helpers, callback dispatcher, `QApplication`/`exec`, `QObject` base (`objectName`, `deleteLater`, `setParent`), `QTimer` | Unit tests pass offscreen; a timer fires a Fortran procedure with `class(*)` user data | **done** on macOS (CI pending) |
| 2. Basic widgets | `QWidget`, `QMainWindow`, `QLabel`, `QPushButton`, `QLineEdit`, `QCheckBox`, `QSpinBox`, `QSlider`, `QComboBox`, box/grid layouts, `QMessageBox`, plus their main signals | A "form" example works | **done** on macOS (CI pending). Also: `QRadioButton`, `QDoubleSpinBox`, `QStatusBar`, `QDialog`, and bool/int/double signal types. |
| 3. GUI & extensibility | `QAction`/`QMenuBar`, `QFileDialog`, `QPainter`/`QColor`/`QPen`, a custom widget with a Fortran `paintEvent`, mouse/key events | A live-plot painter example driven by `QTimer` | **done** on macOS (CI pending). Also: `QMenu`/`QToolBar`, `QImage`/`QPixmap`, `QBrush`/`QFont`, wheel/resize events, synthetic events + `QCoreApplication_sendEvent`, the raw-interface generator with its CI check. |
| 4. Binding generator | Stage 1: raw `bind(C)` modules generated from the shim. Stage 2: shim functions and high-level wrappers generated from `spec/*.toml` | Phase 2-3 classes regenerate equivalently | **done** on macOS (CI pending): widgets and gui are generated, and all tests pass unchanged. Possible next step: seed specs from PySide6's `share/PySide6/typesystems/*.xml`. |
| 5. Polish | FORD docs, README, Windows packaging notes | Docs published | |

Phases 0-3 were hand-written to settle the patterns, and phase 4 automated them.
The equivalence check was the unchanged test suite: all 157 checks pass
against the generated modules.

## Spike results (phase 0)

- Added `cxx-compiler` and `pkg-config` to `pixi.toml`.
- Mixed gfortran + clang++/libc++ linking works on macOS arm64. The binaries
  link `@rpath` Qt 6.11.1, `libc++` and `libgfortran` from the env, using
  `-Wl,-rpath,$CONDA_PREFIX/lib`.
- `test/test_spike.f90` passes headless:
  - QLabel construction
  - UTF-8 string round-trip, including the byte length
  - a `QTimer::singleShot` callback into Fortran from inside `exec()`
  - `quit()`
  - `delete`
- `example/hello.f90` opens a native window.

## Risks / open items

- Fortran polymorphism across the hierarchy: casting `QWidget` handles back
  to subclasses (e.g. `findChild`).
- Re-entrancy: Fortran callbacks running inside `exec()` that emit more signals.
- gfortran edge cases with `class(*)` in the dispatcher table.
- Every phase must stay green on all three CI platforms before it counts as done.

## OpenGL (added after phase 4)

**Decision:** modern OpenGL through Qt's helper classes, as PySide users write it.
Legacy fixed-function GL and a high-level scene API were the alternatives considered.

- **Spec and generated files:** `spec/opengl.toml` produces `qt_opengl`.
  - `QtfOpenGLWidget` forwards `initializeGL` / `resizeGL` / `paintGL` (with the
    context current) and input events to Fortran slots.
  - `QOpenGLShaderProgram` has a generic `setUniformValue` covering float, int,
    vec3, vec4, `QColor`, mat3 and mat4.
  - `QOpenGLBuffer%allocate` takes `real(c_double)` or integer arrays and stores
    them as 32-bit floats or uints. Byte offsets and strides therefore count 4
    bytes per element.
  - The other classes are `QOpenGLVertexArrayObject` and `QSurfaceFormat`.
- **GL functions:** a curated set of `glXxx` free procedures, routed through the
  current context's `QOpenGLFunctions`. No platform GL library is linked, and
  each is a no-op without a current context.
- **`QMatrix4x4`** is pure Fortran (`src/opengl/qt_matrix.f90`), not a binding.
  - Column-major `m(4,4)`, with Qt's post-multiply semantics and angles in degrees.
  - It's passed to C++ as a value type with a `double[16]` field.
- **Portability:** request OpenGL 3.3 core via `QSurfaceFormat_setDefaultFormat`
  before creating the application, and use `#version 330 core` shaders.
  - Works with macOS (4.1 core via Metal), Mesa and desktop drivers.
  - Linux needs `libgl-devel` for the GL headers that Qt's headers include.
- **Testing:** the offscreen platform has no OpenGL, so `test_opengl` prints
  SKIP there (and wherever 3.3 isn't available). `pixi run test-gl` runs it on
  the real display, and CI does so on macOS.
- **Qt behavior to know:** a hidden QOpenGLWidget's `grabFramebuffer` calls
  `initializeGL` and `paintGL` but not `resizeGL`, which follows real resize events.
- **Generator additions:** module-level free functions (`functions`),
  `double[]` / `int[]` array arguments, and `double[N]` fields in value types.

## Roadmap: what Qt coverage is still missing

Current coverage is about 50 classes across QtCore, QtGui, QtWidgets and QtOpenGL.
The gaps below are grouped by area. The **priorities** list at the end orders
them by value to Fortran (scientific) users. Most widget and dialog items are
spec-only work now; items marked *(design)* need new machinery.

### Inside the bound modules
- **Widgets: done** (all with tests). Item views:
  - `QTableWidget` (+`QTableWidgetItem`), `QListWidget`, `QTreeWidget`
    (+`QTreeWidgetItem`), with a shared `QAbstractItemView` base.
  - Model/view: `QTableView` with **`QtfTableModel`**. Its cells are provided on
    demand by a Fortran `dataRequested(row, column, request)` slot, so large
    arrays are not copied; edits arrive at `dataEdited(row, column, text)`.
  - Text: `QTextEdit`, `QPlainTextEdit`.
  - Containers: `QTabWidget`, `QSplitter`, `QScrollArea`, `QGroupBox`,
    `QStackedWidget`, `QDockWidget` (+`QMainWindow%addDockWidget`), and `QFrame`
    (now the base of `QLabel`).
  - Controls: `QProgressBar`, `QToolButton`, `QButtonGroup`, `QDial`,
    `QDateEdit`, `QTimeEdit`, `QCalendarWidget`, `QLCDNumber`.
  - Dialogs: `QInputDialog` (getText, getMultiLineText, getInt, getDouble,
    getItem, each with an optional `ok`), `QColorDialog`, `QFontDialog`,
    `QProgressDialog`.
  - Layout: `QFormLayout`, `setSizePolicy`, min/max/fixed width/height,
    `QBoxLayout%setStretchFactor`.
  - Value types `QDate` and `QTime` (in qt_core).
  - **Deferred:** `QGraphicsView` / `QGraphicsScene` (2D scene graph).
  - Not yet: a model for `QTreeView`/`QListView` (only the table model exists),
    item icons and check states.
- **Gui**
  - `QIcon` (icons on actions and buttons).
  - **`QImage` from Fortran arrays** (bulk pixel data) plus colormaps, for
    heatmaps and field plots. Today only per-pixel `setPixelColor` exists.
  - Painting: `QPainterPath` (curves), gradients, `QTransform`, standalone font metrics.
  - System: clipboard, cursors, drag and drop, screens/DPI.
- **Core**
  - **`QThread` / QtConcurrent**: long computations without freezing the UI. *(design)*
  - `QSettings`: persist preferences and window state.
  - Pass the real command-line arguments to `QApplication`. A fixed argv is used
    today, so Qt options such as `-platform` and `-style` are ignored.
  - `QDateTime`, `QObject` properties, `findChild`.
- **Events**: close (confirm on quit), enter/leave, focus, context menu,
  show/hide, drag/drop.

### Binding machinery *(design)*
- Signals defined in Fortran (custom signals).
- `disconnect` (connections currently live until the sender is destroyed).
- **Done:** signals with several integer arguments (`QSignalInt2/3/4`, e.g.
  `cellChanged(row, column)`, `dateChanged(year, month, day)`), and custom
  signal kinds (tree items, model requests).
- Use-after-delete detection for handles (`QPointer`-backed).

Generator features added for the widgets: `strings` arguments (character array
→ QStringList), `bool&` optional output flags, `int[]` results, value-type
results through per-field `out` templates (`QColor`, `QDate`, `QTime`),
value-type arguments with defaults, and `custom` signals (`fortran_type` plus
a C++ `lambda`/`emit`, with the sender as `s`).

### Other Qt modules
- **Available in the env, not bound:** QtSvg (SVG export and icons),
  QtPrintSupport (printing, PDF), QtNetwork, QtSql, QtConcurrent, and QtQuick/QML
  (a declarative UI; probably a poor fit for Fortran).
- **Not installed** (need extra conda packages): Qt Charts / Qt Graphs (2D and 3D
  charts, a big win for plotting), Qt3D, Multimedia, WebEngine.

### Priorities (for Fortran users)
1. `QImage` from Fortran arrays, plus colormaps.
2. Background computation (`QThread`-style worker, or a documented
   `processEvents` pattern with `QProgressBar`).
3. ~~`QTableWidget`, then model/view.~~ Done.
4. ~~Layout and polish widgets.~~ Done, except `QIcon` on actions (Gui).
5. Close event and `QSettings`.
6. Fortran-defined signals and `disconnect`.
7. Qt Charts / Qt Graphs.
