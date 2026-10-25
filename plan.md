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
| Build | `tools/fpm_qt.py` builds the C++ shim as a shared library (`qtf`), then fpm builds the Fortran code (gfortran everywhere) and links `-lqtf`. |
| Toolchain | gfortran on all OSes. See the table below. |
| moc | Not used. Signals connect through C++ lambdas, and virtual overrides use small C++ subclasses without `Q_OBJECT`. |

## Architecture

```
user code   ->  use qt                      Modern Fortran OO API
                qt.f90 -> qt_core, qt_gui_types, qt_gui, qt_widgets
            ->  qt_c_*.f90                  raw bind(C) interfaces (GENERATED from the shim)
                qt_c_util.f90               hand-written: qtf_args, string/bool conversion
            ->  shim/qtf_*.cpp  (libqtf)    extern "C" shim over Qt C++
            ->  libQt6Core / Gui / Widgets
```

- **Bindings are generated from specs.** `spec/<module>.toml` describes each
  class: its base, docs, constructors, methods and signals, in a compact
  signature syntax such as `"setRange(minimum: int, maximum: int) -- doc"`.
  `tools/gen_bindings.py` turns it into the C++ shim (`shim/qtf_<module>.cpp`)
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
  - **Connectors**: signal ids (`QTF_SIG_*`) live in `shim/qtf_common.h` (core)
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

## Platforms & toolchains

gfortran 15 is the Fortran compiler on every platform. The C++ shim is built
**separately as a shared library** (`qtf`) by a C++ compiler that matches the
ABI of the conda-forge Qt binaries. The shim's interface is pure C (opaque
pointers, ints, `char*`, function pointers), so gfortran can link it on every
OS, including MinGW gfortran against an MSVC-built DLL on Windows.

| OS | Fortran | Shim compiler | Shim library | Qt flags | Runtime lookup |
|----|---------|---------------|--------------|----------|----------------|
| Linux | gfortran 15 | g++ | `build/qtf/libqtf.so` | `pkg-config` | rpath |
| macOS | gfortran 15 | clang++ (libc++) | `build/qtf/libqtf.dylib` | `pkg-config` | rpath (`@rpath` install name) |
| Windows | gfortran 15 (MinGW/UCRT) | clang++ `--target=x86_64-pc-windows-msvc`, `-fms-runtime-lib=dll` | `build/qtf/qtf.dll` | built from `%CONDA_PREFIX%\Library` (Qt ships no .pc files) | `PATH` |

`tools/fpm_qt.py` does both steps. It rebuilds the shim when a `shim/*` file
changes, then runs fpm with `--link-flag "-L build/qtf ..."` (search path and rpath only).
The library itself is declared in `fpm.toml` as `link = ["qtf"]`. fpm places it
*after* the objects. This matters: fpm puts `--link-flag` contents before the
objects, so ld would skip the Windows import library (and `--as-needed` on Linux
would drop it). fpm sees only Fortran sources. The shim lives in `shim/`,
outside fpm's `src/`.

Consequences:
- Every shim function is exported with `QTF_API` (`shim/qtf_common.h`).
- The Windows shim links only the dynamic CRT (`/NODEFAULTLIB` for libcmt,
  libucrt, libvcruntime, libcpmt). Otherwise malloc/free bind into a second,
  static runtime (`LNK4098`/`LNK4217`).
- Memory allocated by the shim must be freed by the shim (`qtf_free`), never by
  Fortran. On Windows the two sides use different C runtimes.
- On Windows, the MSVC linker/SDK come from `cxx-compiler` (vs2022
  activation), so Visual Studio Build Tools must be installed on the host.
  GitHub's Windows runners have them.
- The project path must not contain spaces, because fpm splits `--link-flag` on spaces.
- fpm does not relink executables when only a library dependency changed. So
  whenever `tools/fpm_qt.py` rebuilds the shim, it also clears fpm's object
  cache (`build/gfortran_*`), forcing a full Fortran rebuild against the new C
  interface.

History: we first tried fpm compiling the shim directly, with flang + clang++ on
Windows. flang on Windows proved unusable in CI (`iso_c_binding` was unavailable),
so we switched to this shared-library design.

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
shim/      qtf_common.h qtf_core.cpp  qtf_gui.cpp** qtf_widgets.cpp**   (built into libqtf)
tools/     fpm_qt.py           builds the shim, drives fpm
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
