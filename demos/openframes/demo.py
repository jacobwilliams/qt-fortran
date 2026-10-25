"""Build OpenFrames from source and build/run the qt-fortran OpenFrames demo.

Usage (from this directory, in its pixi environment):
    python demo.py openframes        clone OpenFrames (pinned commit), build and install it in build/
    python demo.py build             build the demo with fpm
    python demo.py run [args...]     run the demo (args go to the program, e.g. --capture out --quit-after 4)

OpenFrames is compiled with CMake against conda-forge's OpenSceneGraph. The
demo is built with qt-fortran's tools/fpm_qt.py (C++ shim and Qt settings),
plus the OpenFrames library directory and an rpath to it.
"""

import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
QT_FORTRAN = os.path.dirname(os.path.dirname(ROOT))
BUILD = os.path.join(ROOT, "build")
OF_REPO = "https://github.com/ravidavi/OpenFrames.git"
OF_COMMIT = "798dc4a"                       # the commit this demo was written against
OF_SRC = os.path.join(BUILD, "OpenFrames")
OF_BUILD = os.path.join(BUILD, "openframes-build")
OF_PREFIX = os.path.join(BUILD, "openframes-install")


def run(cmd, env=None):
    print("+", " ".join(cmd), flush=True)
    if subprocess.call(cmd, env=env) != 0:
        sys.exit(f"demo.py: failed: {' '.join(cmd)}")


def openframes():
    """Clone, configure, build and install OpenFrames (only the libraries)."""
    if not os.path.isdir(OF_SRC):
        run(["git", "clone", OF_REPO, OF_SRC])
    run(["git", "-C", OF_SRC, "checkout", "-q", OF_COMMIT])
    prefix = os.environ["CONDA_PREFIX"]
    run(["cmake", "-S", OF_SRC, "-B", OF_BUILD, "-G", "Ninja",
         "-DCMAKE_BUILD_TYPE=Release", f"-DCMAKE_INSTALL_PREFIX={OF_PREFIX}",
         f"-DOSG_DIR={prefix}", f"-DCMAKE_PREFIX_PATH={prefix}",
         "-DOF_BUILD_DEMOS=OFF", "-DOF_PYTHON_MODULE=OFF", "-DOF_FORTRAN_MODULE=OFF", "-DOF_QT_SUPPORT=OFF"])
    run(["cmake", "--build", OF_BUILD])
    run(["cmake", "--install", OF_BUILD])


def libdir():
    for d in ("lib", "lib64"):
        if glob.glob(os.path.join(OF_PREFIX, d, "*OpenFrames_Interface_C*")):
            return os.path.join(OF_PREFIX, d)
    sys.exit("demo.py: OpenFrames is not built yet: run `pixi run openframes` first")


def fpm(command, args):
    """Run fpm through qt-fortran's fpm_qt.py, adding the OpenFrames library."""
    lib = libdir()
    env = dict(os.environ)
    env["FPM_LDFLAGS"] = f"{env.get('FPM_LDFLAGS', '')} -L{lib} -Wl,-rpath,{lib}".strip()
    env["OPENFRAMES_DATA"] = os.path.join(OF_SRC, "Demos")   # textures, models, star catalog
    fpm_args = [command] + (["--"] + args if args else [])
    run([sys.executable, os.path.join(QT_FORTRAN, "tools", "fpm_qt.py"), *fpm_args], env)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("openframes", "build", "run"):
        sys.exit(__doc__)
    if sys.argv[1] == "openframes":
        openframes()
    else:
        fpm(sys.argv[1], sys.argv[2:])


if __name__ == "__main__":
    main()
