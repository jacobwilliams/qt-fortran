# qt-fortran: plan

A Modern Fortran interface to Qt 6. It uses standard Fortran C interoperability
(`iso_c_binding`) to call Qt through a thin C++ shim, much as PySide6 wraps the
Qt C++ API for Python. Builds use fpm, and everything compiles inside the pixi
environment.

## Decisions

| Topic | Decision |
|-------|----------|
| API naming | Qt style: `QPushButton`, `btn%setText(...)`, `clicked`. The Qt/PySide docs carry over directly. |
| Qt modules | Minimum for now: QtCore, QtGui, QtWidgets. |
| Platforms | Cross-platform: Linux, macOS, Windows. |
| Build | `tools/fpm_qt.py` builds the C++ shim as a shared library (`qtf`), then fpm builds the Fortran code (gfortran everywhere) and links `-lqtf`. |
| Toolchain | gfortran on all OSes. See the table below. |
| moc | Not used. Signals connect through C++ lambdas, and virtual overrides use small C++ subclasses without `Q_OBJECT`. |

## Architecture

```
user code   ->  use qt                      Modern Fortran OO API
                qt.f90 (later qt_core / qt_gui / qt_widgets)
            ->  qt_c_*.f90                  raw bind(C) interfaces (iso_c_binding only)
            ->  shim/qtf_*.cpp  (libqtf)    extern "C" shim over Qt C++
            ->  libQt6Core / Gui / Widgets
```

- **C++ shim**: flat `extern "C"` functions (`qtf_<class>_<method>`). Qt objects
  are passed as opaque `void*`, and only C types are used.
- **Raw Fortran layer**: one interface per shim function. No logic.
- **High-level layer**: derived types follow the Qt class hierarchy
  (`QObject -> QWidget -> QLabel ...`). Each one holds a `type(c_ptr)`.
  Constructors are generic interfaces named after the type
  (`label = QLabel("text", parent=w)`), and methods are type-bound procedures.

### Conventions

- **Strings in**: pass `character(*)` plus its length. The shim calls
  `QString::fromUtf8(p, len)`, so no NUL terminator is needed.
- **Strings out**: the shim returns a malloc'd UTF-8 buffer and its length.
  Fortran copies it into `character(len=:), allocatable` and calls `qtf_free`.
- **Callbacks** (phase 1): C++ stores an integer slot id and calls one Fortran
  `bind(C)` dispatcher. Fortran keeps a table of procedure pointers plus
  `class(*)` user data, so user callbacks don't need `bind(C)`. The spike still
  uses a raw `bind(C)` callback with `c_ptr` data.
- **Ownership**: follows Qt's parent/child model. No finalizers. Parented
  objects belong to Qt, and top-level objects use an explicit `%delete()`.
  A `QPointer`-backed handle may be added later to detect use after delete.
- **Enums/flags**: `integer(c_int), parameter` constants named `Qt_<Name>`
  (e.g. `Qt_AlignCenter`).

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
changes, then runs fpm with `--link-flag "-L build/qtf -lqtf ..."`. fpm sees
only Fortran sources. The shim lives in `shim/`, outside fpm's `src/`.

Consequences:
- Every shim function is exported with `QTF_API` (`shim/qtf_common.h`).
- Memory allocated by the shim must be freed by the shim (`qtf_free`), never by
  Fortran. On Windows the two sides use different C runtimes.
- On Windows, the MSVC linker/SDK come from `cxx-compiler` (vs2022
  activation), so Visual Studio Build Tools must be installed on the host.
  GitHub's Windows runners have them.
- The project path must not contain spaces, because fpm splits `--link-flag` on spaces.

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
pixi run example hello     # run an example
```

## Layout (target)

```
src/
  qt.f90                    umbrella module: use qt
  core/    qt_c_core.f90    qt_core.f90      QCoreApplication, QObject, QTimer, strings, callbacks
  gui/     qt_c_gui.f90     qt_gui.f90       QColor, QFont, QPainter, QPixmap...
  widgets/ qt_c_widgets.f90 qt_widgets.f90   QApplication, QWidget, buttons, layouts...
shim/      qtf_common.h qtf_core.cpp qtf_gui.cpp qtf_widgets.cpp   (built into libqtf)
tools/     fpm_qt.py  (builds shim, drives fpm)
example/   hello, button_click, form, painter, timer
test/      strings, signals, widgets
```

## Phases

| # | Goal | Done when | Status |
|---|------|-----------|--------|
| 0. Spike | C++ compiler in pixi, pixi tasks, minimal shim, Fortran `QLabel` window | `pixi run example hello` shows a window; the headless test passes | **done** (macOS verified) |
| 0b. Cross-platform | Shim as shared library, gfortran everywhere, `tools/fpm_qt.py` driver, GitHub Actions matrix (ubuntu/macos/windows, offscreen tests) | CI green on all three | in progress (Linux/Windows still need a CI run) |
| 1. Core infra | String helpers, callback dispatcher, `QApplication`/`exec`, `QObject` base (`objectName`, `deleteLater`, `setParent`), `QTimer` | Unit tests pass offscreen; a timer fires a Fortran procedure with `class(*)` user data | |
| 2. Basic widgets | `QWidget`, `QMainWindow`, `QLabel`, `QPushButton`, `QLineEdit`, `QCheckBox`, `QSpinBox`, `QSlider`, `QComboBox`, box/grid layouts, `QMessageBox`, plus their main signals | A "form" example works | |
| 3. GUI & extensibility | `QAction`/`QMenuBar`, `QFileDialog`, `QPainter`/`QColor`/`QPen`, a custom widget with a Fortran `paintEvent`, mouse/key events | A live-plot painter example driven by `QTimer` | |
| 4. Binding generator | A Python script that generates the shim, raw interfaces and type-bound methods from a spec. It can mine PySide6's `share/PySide6/typesystems/*.xml` for signatures. | Phase 2 classes regenerate identically | |
| 5. Polish | FORD docs, README, Windows packaging notes | Docs published | |

Phases 0-3 are hand-written to settle the patterns. Phase 4 then automates them.

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
- Windows: MinGW gfortran linking the MSVC-built `qtf.dll` (through `qtf.lib` or
  the DLL directly), and clang++ finding the MSVC linker, are still unverified in CI.
- Every phase must stay green on all three CI platforms before it counts as done.
