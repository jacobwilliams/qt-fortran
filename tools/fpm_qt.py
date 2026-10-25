"""Run fpm with the compiler and Qt flags for the current platform.

Usage (inside the pixi env):  python tools/fpm_qt.py <fpm command> [fpm args...]

  linux / macOS : gfortran + g++ / clang++, Qt flags from pkg-config
  windows       : flang + clang++ (MSVC ABI, to match conda-forge's MSVC-built Qt);
                  Qt ships no pkg-config files there, so flags are built from the prefix
"""

import os
import shutil
import subprocess
import sys

QT_MODULES = ["Core", "Gui", "Widgets"]
CXX_STD = "-std=c++17"


def which(*names):
    for n in names:
        if shutil.which(n):
            return n
    sys.exit(f"fpm_qt: none of {names} found on PATH (run inside `pixi run`)")


def pkg_config(*args):
    pkgs = [f"Qt6{m}" for m in QT_MODULES]
    return subprocess.check_output(["pkg-config", *args, *pkgs], text=True).strip()


def unix_flags(prefix):
    fc = os.environ.get("FPM_FC") or which("gfortran")
    if sys.platform == "darwin":
        cxx = os.environ.get("FPM_CXX") or which("clang++")
        cxx_lib = "-lc++"
    else:
        cxx = os.environ.get("FPM_CXX") or which("g++", "c++")
        cxx_lib = "-lstdc++"
    cxx_flags = f"{CXX_STD} -fPIC {pkg_config('--cflags')}"
    link_flags = f"{pkg_config('--libs')} {cxx_lib} -Wl,-rpath,{prefix}/lib"
    return fc, cxx, "", cxx_flags, link_flags


def windows_flags(prefix):
    lib = os.path.join(prefix, "Library")
    inc = os.path.join(lib, "include", "qt6")
    fc = os.environ.get("FPM_FC") or which("flang", "flang-new")
    cxx = os.environ.get("FPM_CXX") or which("clang++")
    # Qt DLLs use the dynamic CRT (/MD); every object must match.
    crt = "-fms-runtime-lib=dll"
    incs = [inc] + [os.path.join(inc, f"Qt{m}") for m in QT_MODULES]
    defs = [f"-DQT_{m.upper()}_LIB" for m in QT_MODULES]
    cxx_flags = " ".join([CXX_STD, crt, *defs, *(f'-I"{p}"' for p in incs)])
    libs = " ".join(f"-lQt6{m}" for m in QT_MODULES)
    link_flags = f'-L"{os.path.join(lib, "lib")}" {libs} {crt}'
    return fc, cxx, crt, cxx_flags, link_flags


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    prefix = os.environ.get("CONDA_PREFIX")
    if not prefix:
        sys.exit("fpm_qt: CONDA_PREFIX is not set (run inside `pixi run`)")

    if os.name == "nt":
        fc, cxx, fflags, cxx_flags, link_flags = windows_flags(prefix)
    else:
        fc, cxx, fflags, cxx_flags, link_flags = unix_flags(prefix)

    cmd = ["fpm", sys.argv[1], "--compiler", fc, "--cxx-compiler", cxx,
           "--cxx-flag", cxx_flags, "--link-flag", link_flags]
    if fflags:
        cmd += ["--flag", fflags]
    cmd += sys.argv[2:]
    print("+", " ".join(cmd), flush=True)
    sys.exit(subprocess.call(cmd))


if __name__ == "__main__":
    main()
