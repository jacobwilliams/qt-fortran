"""Run fpm with the C++ compiler, Qt and linker settings that qt-fortran needs.

Works in qt-fortran itself and in any fpm project that depends on it (run it
from that project's root, e.g. `python build/dependencies/qt-fortran/tools/fpm_qt.py`).

Usage:
    python fpm_qt.py <fpm command> [fpm args...]   e.g. build, test, run --example hello
    python fpm_qt.py --env                         print `export ...` lines; then plain
                                                   `fpm build` works in that shell

The Fortran compiler is gfortran unless `--compiler <fc>` is given (anywhere on
the command line, as with fpm) or FPM_FC is set, e.g. `--compiler ifx`.

How the C++ shim (src/shim/*.cpp) is built:

  Linux, macOS, and Windows with a MinGW Qt (e.g. MSYS2):
      fpm compiles it as part of the qt-fortran library, and links the Qt libraries
      and C++ runtime declared in qt-fortran's fpm.toml. This script only supplies
      the machine-specific settings, through fpm's standard environment variables:
        FPM_CXX       clang++ (macOS) / g++
        FPM_CXXFLAGS  -std=c++17 -fPIC + Qt include paths (pkg-config)
        FPM_LDFLAGS   Qt library directory and rpath (pkg-config)

  Windows with conda-forge Qt (built with MSVC):
      gfortran (MinGW) cannot link MSVC C++ objects, so the shim is built with
      clang++ (MSVC target) into build/qtf/qtf.dll, which has a plain C interface.
      fpm compiles the shim sources as empty files (-DQTF_EXTERNAL_SHIM) and links
      the DLL; the DLL and Qt are found through PATH at run time.
      With Intel Fortran (ifx/ifort), which links with MSVC's link.exe, the DLL's
      import library qtf.lib is linked instead. Its directory and Qt's are put in
      the LIB environment variable (link.exe's search path), so no paths, and no
      spaces in paths, appear on fpm's command lines.

Override the compilers with FPM_FC / FPM_CXX if needed. FPM_CXXFLAGS and
FPM_LDFLAGS already set in the environment are kept (appended), e.g. for the
libraries of other dependencies.
"""

import glob
import os
import shlex
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # qt-fortran checkout
SHIM_SRC = os.path.join(ROOT, "src", "shim")
QT_MODULES = ["Core", "Gui", "Widgets", "OpenGL", "OpenGLWidgets"]
CXX_STD = "-std=c++17"
WINDOWS = os.name == "nt"
MACOS = sys.platform == "darwin"


def which(*names):
    for n in names:
        if shutil.which(n):
            return n
    sys.exit(f"fpm_qt: none of {names} found on PATH")


def pkg_config(*args):
    pkgs = [f"Qt6{m}" for m in QT_MODULES]
    try:
        return subprocess.check_output(["pkg-config", *args, *pkgs], text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit("fpm_qt: pkg-config could not find Qt 6 (Qt6Core, Qt6Widgets, Qt6OpenGLWidgets, ...);\n"
                 "        install Qt 6 development files or set PKG_CONFIG_PATH")


def is_intel(fc):
    """True for Intel Fortran (ifx, ifort), which on Windows links like MSVC."""
    name = os.path.basename(fc).lower()
    return name.startswith("ifx") or name.startswith("ifort")


def conda_msvc_qt():
    """The conda-forge Library/ prefix if Qt there is MSVC-built (Windows), else None."""
    prefix = os.environ.get("CONDA_PREFIX")
    if not (WINDOWS and prefix):
        return None
    lib = os.path.join(prefix, "Library")
    return lib if os.path.exists(os.path.join(lib, "lib", "Qt6Core.lib")) else None


# ---------------------------------------------------------------------------
# Linux / macOS / MinGW: fpm builds the shim

def fpm_settings():
    """FPM_CXX, FPM_CXXFLAGS and FPM_LDFLAGS for building the shim with fpm."""
    cxx = os.environ.get("FPM_CXX") or (which("clang++") if MACOS else which("g++", "c++"))
    cxxflags = [CXX_STD]
    if not WINDOWS:
        cxxflags.append("-fPIC")             # Qt requires position-independent code
    cxxflags.append(pkg_config("--cflags"))
    libdir = pkg_config("--variable=libdir").split()[0]
    ldflags = [pkg_config("--libs-only-L")]
    if WINDOWS:
        ldflags.append("-lstdc++")           # MinGW: C++ runtime of the shim
    else:
        ldflags.append(f"-Wl,-rpath,{libdir}")
        if not MACOS:
            ldflags.append(f"-Wl,-rpath-link,{libdir}")
    return {"FPM_CXX": cxx, "FPM_CXXFLAGS": " ".join(cxxflags), "FPM_LDFLAGS": " ".join(ldflags)}, None


# ---------------------------------------------------------------------------
# Windows + conda-forge (MSVC) Qt: separate shim DLL

def build_shim_dll(lib):
    """Build build/qtf/qtf.dll from the shim sources if any of them is newer."""
    out_dir = os.path.join(os.getcwd(), "build", "qtf")
    dll = os.path.join(out_dir, "qtf.dll")
    implib = os.path.join(out_dir, "qtf.lib")    # import library, for MSVC-style linkers
    sources = sorted(glob.glob(os.path.join(SHIM_SRC, "*.cpp")))
    deps = sources + glob.glob(os.path.join(SHIM_SRC, "*.h"))
    if os.path.exists(dll) and os.path.exists(implib) and all(os.path.getmtime(d) <= os.path.getmtime(dll) for d in deps):
        return dll, False
    os.makedirs(out_dir, exist_ok=True)
    inc = os.path.join(lib, "include", "qt6")
    cxx = os.environ.get("QTF_CXX") or which("clang++")
    cmd = [cxx, "--target=x86_64-pc-windows-msvc", CXX_STD,
           # Qt DLLs use the dynamic CRT (/MD); keep the static one out of the link
           "-fms-runtime-lib=dll", "-shared", "-o", dll, f"-Wl,/IMPLIB:{implib}",
           *(f"-Wl,/NODEFAULTLIB:{crt}" for crt in ("libcmt", "libucrt", "libvcruntime", "libcpmt")),
           *(f"-DQT_{m.upper()}_LIB" for m in QT_MODULES),
           f"-I{inc}", *(f"-I{os.path.join(inc, 'Qt' + m)}" for m in QT_MODULES),
           *sources,
           f"-L{os.path.join(lib, 'lib')}", *(f"-lQt6{m}" for m in QT_MODULES)]
    if run(cmd) != 0:
        sys.exit("fpm_qt: shim build failed")
    return dll, True


def dll_settings(lib, intel):
    """Settings for fpm when the shim is the separately built DLL."""
    dll, rebuilt = build_shim_dll(lib)
    if rebuilt:
        # fpm does not relink executables when only the DLL changed
        # (fpm's build directories are named after the compiler)
        for fc in ("gfortran", "ifx", "ifort"):
            for d in glob.glob(os.path.join(os.getcwd(), "build", f"{fc}_*")):
                shutil.rmtree(d)
    dll_dir = os.path.dirname(dll)
    # fpm compiles C++ as `<cxx> -c x.cpp ... -o x.o`; MSVC's cl ignores -o for
    # objects (writes x.obj in the current directory), so don't use it here.
    # (setup-fortran's Intel toolchain sets FPM_CXX=cl.)
    cxx = os.environ.get("FPM_CXX")
    if cxx and os.path.splitext(os.path.basename(cxx))[0].lower() == "cl":
        print(f"fpm_qt: ignoring FPM_CXX={cxx} (cl doesn't accept fpm's -o); using clang++",
              flush=True)
        cxx = None
    env = {
        "FPM_CXX": cxx or which("clang++"),
        "FPM_CXXFLAGS": "-DQTF_EXTERNAL_SHIM",
    }
    if intel:
        # link.exe: link the import library (clang writes qtf.lib next to the
        # DLL) and find it and Qt's *.lib through LIB, not command-line paths
        env["FPM_LDFLAGS"] = "qtf.lib"
        env["LIB"] = os.pathsep.join(p for p in (dll_dir, os.path.join(lib, "lib"),
                                                 os.environ.get("LIB")) if p)
    else:
        # The DLL is passed as a linker input (not -lqtf): ld resolves symbols from a
        # DLL regardless of its position on the command line, unlike an import library.
        env["FPM_LDFLAGS"] = f"-L{os.path.join(lib, 'lib')} {dll.replace(os.sep, '/')}"
    return env, dll_dir


# ---------------------------------------------------------------------------

def run(cmd, env=None):
    print("+", " ".join(cmd), flush=True)
    return subprocess.call(cmd, env=env)


def keep_user_flags(settings):
    """Append flags already set in the environment (other dependencies' needs)."""
    for key in ("FPM_CXXFLAGS", "FPM_LDFLAGS"):
        extra = os.environ.get(key, "").strip()
        if extra:
            settings[key] = f"{settings[key]} {extra}"
    return settings


def pop_compiler(args):
    """Remove `--compiler X` / `--compiler=X` from args; return X (or None)."""
    for i, a in enumerate(args):
        if a == "--compiler" and i + 1 < len(args):
            fc = args[i + 1]
            del args[i:i + 2]
            return fc
        if a.startswith("--compiler="):
            del args[i]
            return a.split("=", 1)[1]
    return None


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        sys.exit(__doc__)
    fc = pop_compiler(args) or os.environ.get("FPM_FC") or which("gfortran")
    intel = is_intel(fc)
    lib = conda_msvc_qt()
    if WINDOWS and intel and not lib:
        sys.exit("fpm_qt: Intel Fortran on Windows is supported only with conda-forge's\n"
                 "        MSVC-built Qt (run inside the pixi/conda environment)")
    settings, dll_dir = dll_settings(lib, intel) if lib else fpm_settings()
    settings = keep_user_flags(settings)

    if args[0] == "--env":
        if intel:
            print(f"export FPM_FC={shlex.quote(fc)}")
        for k, v in settings.items():
            print(f"export {k}={shlex.quote(v)}")
        if dll_dir:
            print(f"export PATH={shlex.quote(dll_dir)}{os.pathsep}\"$PATH\"")
        return

    env = dict(os.environ, **settings)
    if dll_dir:
        env["PATH"] = dll_dir + os.pathsep + env.get("PATH", "")
    sys.exit(run(["fpm", args[0], "--compiler", fc, *args[1:]], env))


if __name__ == "__main__":
    main()
