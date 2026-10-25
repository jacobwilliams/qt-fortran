"""Generate the raw Fortran `bind(C)` interface modules from the C++ shim.

Every function declared `QTF_API` in a shim source becomes one interface in the
matching `qt_c_*` module, together with the `QTF_SIG_*` signal ids (from
src/shim/qtf_common.h) that fall in that module's range.

Usage:
    python tools/gen_c_interfaces.py           # regenerate all modules
    python tools/gen_c_interfaces.py --check   # fail if any module is out of date

Supported C types (anything else is an error, so new types are added here):

    parameters                  Fortran dummy
    void *x                     type(c_ptr), value
    const char *x               character(kind=c_char), dimension(*), intent(in)
    const double *x             real(c_double), dimension(*), intent(in)
    const int *x                integer(c_int), dimension(*), intent(in)
    int *x                      integer(c_int), intent(out)
    double *x                   real(c_double), intent(out)
    int x                       integer(c_int), value
    double x                    real(c_double), value
    qtf_*_fn x                  type(c_funptr), value

    return: void, void *, char *, int *, int, double
"""

import os
import re
import sys
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMMON = os.path.join(ROOT, "src", "shim", "qtf_common.h")

# shim source, generated module, module name, signal-id range
MODULES = [
    ("src/shim/qtf_core.cpp", "src/core/qt_c_core.f90", "qt_c_core", (1, 999)),
    ("src/shim/qtf_gui.cpp", "src/gui/qt_c_gui.f90", "qt_c_gui", (2000, 2999)),
    ("src/shim/qtf_widgets.cpp", "src/widgets/qt_c_widgets.f90", "qt_c_widgets", (1000, 1999)),
    ("src/shim/qtf_opengl.cpp", "src/opengl/qt_c_opengl.f90", "qt_c_opengl", (3000, 3999)),
    ("src/shim/qtf_core_classes.cpp", "src/core/qt_c_core_classes.f90", "qt_c_core_classes", (4000, 4999)),
]

PARAMS = [
    (r"void \*", "type(c_ptr), value", "c_ptr"),
    (r"const char \*", "character(kind=c_char), dimension(*), intent(in)", "c_char"),
    (r"const double \*", "real(c_double), dimension(*), intent(in)", "c_double"),
    (r"const int \*", "integer(c_int), dimension(*), intent(in)", "c_int"),
    (r"int \*", "integer(c_int), intent(out)", "c_int"),
    (r"double \*", "real(c_double), intent(out)", "c_double"),
    (r"int ", "integer(c_int), value", "c_int"),
    (r"double ", "real(c_double), value", "c_double"),
    (r"qtf_\w+_fn ", "type(c_funptr), value", "c_funptr"),
]

RETURNS = {
    "void": None,
    "void *": ("type(c_ptr)", "c_ptr"),
    "char *": ("type(c_ptr)", "c_ptr"),
    "int *": ("type(c_ptr)", "c_ptr"),
    "int": ("integer(c_int)", "c_int"),
    "double": ("real(c_double)", "c_double"),
}

DECL = re.compile(r"QTF_API\s+([\w\s\*]+?)\s*\b(qtf_\w+)\s*\(([^)]*)\)", re.S)
COMMENT = re.compile(r"((?:[ \t]*//[^\n]*\n)*)[ \t]*QTF_API\s+[\w\s\*]+?\b(qtf_\w+)\s*\(", re.S)


def fail(msg):
    sys.exit(f"gen_c_interfaces: {msg}")


def normalize(text):
    """Collapse whitespace and write pointers as `type *name`."""
    return re.sub(r"\s*\*\s*", " *", " ".join(text.split())).strip()


def parse_param(text, func):
    text = normalize(text)
    for pattern, decl, kind in PARAMS:
        m = re.fullmatch(pattern + r"(\w+)", text)
        if m:
            return m.group(1), decl, kind
    fail(f"unsupported parameter '{text}' in {func}")


def docstring(name, rtype, params, comments):
    """FORD docstring lines: the shim's `//` comment above the function, then its C prototype."""
    proto = f"{normalize(rtype)} {name}({', '.join(normalize(p) for p in params.split(',') if p.strip())})"
    proto = proto.replace("* ", "*")
    lines = [f"!> {c}" for c in comments.get(name, [])]
    if lines:
        lines.append("!>")
    lines.append(f"!> C: `{proto}`")
    return "\n".join(f"        {l}" for l in lines)


def interface(rtype, name, params):
    rtype = normalize(rtype)
    if rtype not in RETURNS:
        fail(f"unsupported return type '{rtype}' in {name}")
    args = [p.strip() for p in params.split(",") if p.strip() and p.strip() != "void"]
    dummies, lines, kinds = [], [], set()
    for a in args:
        n, decl, kind = parse_param(a, name)
        dummies.append(n)
        lines.append(f"{decl} :: {n}")
        kinds.add(kind)
    ret = RETURNS[rtype]
    if ret:
        kinds.add(ret[1])
    head = "function" if ret else "subroutine"
    first = f"        {head} {name}({', '.join(dummies)})"
    tail = f" result(res) bind(C, name='{name}')" if ret else f" bind(C, name='{name}')"
    if len(first + tail) <= 120:
        out = [first + tail]
    else:
        out = [first + " &", "                " + tail.strip()]
    if kinds:
        out.append(f"            import :: {', '.join(sorted(kinds))}")
    out.append("            implicit none")
    out += [f"            {l}" for l in lines]
    if ret:
        out.append(f"            {ret[0]} :: res")
    out.append(f"        end {head} {name}")
    return "\n".join(out)


def signal_ids(lo, hi, shim_src):
    """QTF_SIG_* ids in range, from qtf_common.h and the shim (generated shims define their own)."""
    text = open(COMMON).read() + shim_src
    ids = [(n, int(v)) for n, v in re.findall(r"\b(QTF_SIG_\w+)\s*=\s*(\d+)", text)]
    return [(n, v) for n, v in ids if lo <= v <= hi]


def generate(shim, module, signal_range):
    src = open(os.path.join(ROOT, shim)).read()
    decls = DECL.findall(src)
    if not decls:
        fail(f"no QTF_API functions found in {shim}")
    names = [d[1] for d in decls]
    comments = {}
    for block, name in COMMENT.findall(src):
        text = [l.strip()[2:].strip() for l in block.splitlines() if l.strip().startswith("//")]
        # skip section rulers (// -----) and the section titles that follow them
        if text and not set(text[0]) <= set("-"):
            comments[name] = text
    ifaces = "\n\n".join(docstring(d[1], d[0], d[2], comments) + "\n" + interface(*d) for d in decls)
    sigs = signal_ids(*signal_range, src)
    sig_block = ""
    if sigs:
        sig_block = "    ! Signal ids: must match `enum qtf_signal` in src/shim/qtf_common.h.\n" + "".join(
            f"    integer(c_int), parameter, public :: {n} = {v}\n" for n, v in sigs) + "\n"
    pubs = "".join(f"    public :: {line.rstrip(',')}\n"
                   for line in textwrap.wrap(", ".join(names), 96))
    return f"""!> Raw `bind(C)` interfaces to the C++ shim in `{shim}`.
!>
!> GENERATED by tools/gen_c_interfaces.py from the QTF_API declarations; do not edit.
module {module}

    use iso_c_binding
    implicit none
    private

{sig_block}    interface

{ifaces}

    end interface

{pubs}
end module {module}
"""


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    for shim, target, module, rng in MODULES:
        if not os.path.exists(os.path.join(ROOT, shim)):
            continue
        text = generate(shim, module, rng)
        path = os.path.join(ROOT, target)
        current = open(path).read() if os.path.exists(path) else None
        if current == text:
            continue
        if check:
            stale.append(target)
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", newline="\n") as f:
                f.write(text)
            print(f"wrote {target}")
    if stale:
        fail("out of date (run `pixi run gen`): " + ", ".join(stale))


if __name__ == "__main__":
    main()
