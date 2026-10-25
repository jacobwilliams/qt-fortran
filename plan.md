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
| Build | All fpm: fpm compiles the C++ shim and the Fortran code. The driver `tools/fpm_qt.py` picks the compilers and Qt flags for each OS. |
| Toolchain | See the table below. |
| moc | Not used. Signals connect through C++ lambdas, and virtual overrides use small C++ subclasses without `Q_OBJECT`. |

## Architecture

```
user code   ->  use qt                      Modern Fortran OO API
                qt.f90 (later qt_core / qt_gui / qt_widgets)
            ->  qt_c_*.f90                  raw bind(C) interfaces (iso_c_binding only)
            ->  src/cpp/qtf_*.cpp           extern "C" shim over Qt C++
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

The C++ shim must use the same C++ ABI as the Qt binaries from conda-forge, and
the Fortran compiler must be able to link against it.

| OS | Fortran | C++ (shim) | Qt flags | C++ runtime |
|----|---------|------------|----------|-------------|
| Linux | gfortran 15 | g++ | `pkg-config` | `-lstdc++`, rpath to env |
| macOS | gfortran 15 | clang++ (libc++, matches Qt) | `pkg-config` | `-lc++`, rpath to env |
| Windows | flang 23 | clang++ (MSVC target) | built from `%CONDA_PREFIX%\Library` (Qt ships no .pc files) | `-fms-runtime-lib=dll` (Qt is `/MD`) |

On Windows, conda-forge Qt is MSVC-built, while conda-forge gfortran is
MinGW-based, so it can't link MSVC C++ objects. That rules out gfortran on Windows.
flang + clang++ are both MSVC-ABI. The `cxx-compiler` package activates the MSVC
linker/SDK, so Visual Studio Build Tools must be installed on Windows hosts.
Qt DLLs are found through `PATH` (pixi puts `Library\bin` on it), so no rpath is needed.

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
  cpp/     qtf_common.h qtf_core.cpp qtf_gui.cpp qtf_widgets.cpp
example/   hello, button_click, form, painter, timer
test/      strings, signals, widgets
```

## Phases

| # | Goal | Done when | Status |
|---|------|-----------|--------|
| 0. Spike | C++ compiler in pixi, pixi tasks, minimal shim, Fortran `QLabel` window | `pixi run example hello` shows a window; the headless test passes | **done** (macOS verified) |
| 0b. Cross-platform | Per-OS toolchains, `tools/fpm_qt.py` driver, GitHub Actions matrix (ubuntu/macos/windows, offscreen tests) | CI green on all three | in progress (Linux/Windows still need a CI run) |
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
- Windows: fpm + flang on Windows is less proven than gfortran. Verify fpm's flang
  support, `-fms-runtime-lib=dll`, and `bind(C)` internal procedures in CI.
- Every phase must stay green on all three CI platforms before it counts as done.
