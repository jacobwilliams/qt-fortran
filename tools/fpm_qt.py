"""Build the qtf C++ shim library, then run fpm with gfortran linked against it.

Usage (inside the pixi env):  python tools/fpm_qt.py <fpm command> [fpm args...]

The shim (shim/*.cpp) is compiled with a C++ compiler matching the ABI of the
Qt binaries into a shared library exposing a pure C interface:

  linux   : g++                      -> build/qtf/libqtf.so
  macOS   : clang++ (libc++)         -> build/qtf/libqtf.dylib
  windows : clang++ (MSVC target)    -> build/qtf/qtf.dll   (conda-forge Qt is MSVC-built)

fpm then builds only Fortran code, with gfortran on every platform, and links -lqtf.
Because the boundary is plain C, the MinGW-based gfortran on Windows can link the
MSVC-built DLL.
"""

import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHIM_SRC = os.path.join(ROOT, "shim")
SHIM_OUT = os.path.join(ROOT, "build", "qtf")
QT_MODULES = ["Core", "Gui", "Widgets"]
CXX_STD = "-std=c++17"
WINDOWS = os.name == "nt"
MACOS = sys.platform == "darwin"


def which(*names):
    for n in names:
        if shutil.which(n):
            return n
    sys.exit(f"fpm_qt: none of {names} found on PATH (run inside `pixi run`)")


def run(cmd, env=None):
    print("+", " ".join(cmd), flush=True)
    return subprocess.call(cmd, env=env)


def pkg_config(*args):
    pkgs = [f"Qt6{m}" for m in QT_MODULES]
    return subprocess.check_output(["pkg-config", *args, *pkgs], text=True).split()


def shim_library():
    if WINDOWS:
        return os.path.join(SHIM_OUT, "qtf.dll")
    return os.path.join(SHIM_OUT, "libqtf.dylib" if MACOS else "libqtf.so")


def shim_command(prefix, sources, lib):
    """Compiler command line that builds the shim shared library."""
    if WINDOWS:
        qt = os.path.join(prefix, "Library")
        inc = os.path.join(qt, "include", "qt6")
        cxx = os.environ.get("QTF_CXX") or which("clang++")
        return [cxx, "--target=x86_64-pc-windows-msvc", CXX_STD,
                # Qt DLLs use the dynamic CRT (/MD); the shim must match.
                "-fms-runtime-lib=dll", "-shared", "-o", lib,
                # keep the static CRT out of the link, otherwise malloc/free resolve
                # into a second (static) runtime (LNK4098/LNK4217)
                *(f"-Wl,/NODEFAULTLIB:{crt}" for crt in
                  ("libcmt", "libucrt", "libvcruntime", "libcpmt")),
                *(f"-DQT_{m.upper()}_LIB" for m in QT_MODULES),
                f"-I{inc}", *(f"-I{os.path.join(inc, 'Qt' + m)}" for m in QT_MODULES),
                *sources,
                f"-L{os.path.join(qt, 'lib')}", *(f"-lQt6{m}" for m in QT_MODULES)]
    if MACOS:
        cxx = os.environ.get("QTF_CXX") or which("clang++")
        soname = ["-Wl,-install_name,@rpath/libqtf.dylib"]
    else:
        cxx = os.environ.get("QTF_CXX") or which("g++", "c++")
        soname = ["-Wl,-soname,libqtf.so"]
    return [cxx, CXX_STD, "-fPIC", "-shared", "-fvisibility=hidden", "-o", lib,
            *pkg_config("--cflags"), *sources, *pkg_config("--libs"),
            *soname, f"-Wl,-rpath,{os.path.join(prefix, 'lib')}"]


def build_shim(prefix):
    """Rebuild the shim library if any shim source is newer than it."""
    sources = sorted(glob.glob(os.path.join(SHIM_SRC, "*.cpp")))
    deps = sources + glob.glob(os.path.join(SHIM_SRC, "*.h"))
    lib = shim_library()
    if os.path.exists(lib) and all(os.path.getmtime(d) <= os.path.getmtime(lib) for d in deps):
        return
    os.makedirs(SHIM_OUT, exist_ok=True)
    if run(shim_command(prefix, sources, lib)) != 0:
        sys.exit("fpm_qt: shim build failed")
    # The shim's C interface may have changed. fpm does not relink executables
    # when only the library changed, so start its build from scratch.
    for d in glob.glob(os.path.join(ROOT, "build", "gfortran_*")):
        shutil.rmtree(d)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    prefix = os.environ.get("CONDA_PREFIX")
    if not prefix:
        sys.exit("fpm_qt: CONDA_PREFIX is not set (run inside `pixi run`)")

    build_shim(prefix)

    # -lqtf itself comes from `link = ["qtf"]` in fpm.toml, which fpm places after
    # the objects (required for the Windows import library and --as-needed on linux).
    # fpm splits flag strings on spaces, so the project path must not contain any.
    link = f"-L{SHIM_OUT}"
    env = dict(os.environ)
    if WINDOWS:
        # qtf.dll and the Qt DLLs are located through PATH at run time.
        env["PATH"] = SHIM_OUT + os.pathsep + env.get("PATH", "")
    else:
        link += f" -Wl,-rpath,{SHIM_OUT}"
        if not MACOS:
            # let ld resolve libqtf's own Qt dependencies at link time
            link += f" -Wl,-rpath-link,{os.path.join(prefix, 'lib')}"

    fc = os.environ.get("FPM_FC") or which("gfortran")
    cmd = ["fpm", sys.argv[1], "--compiler", fc, "--link-flag", link, *sys.argv[2:]]
    sys.exit(run(cmd, env))


if __name__ == "__main__":
    main()
