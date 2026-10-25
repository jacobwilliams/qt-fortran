"""Generate the C++ shim and the high-level Fortran module of a binding module
from its spec (spec/<module>.toml).

Usage:
    python tools/gen_bindings.py           # regenerate from every spec
    python tools/gen_bindings.py --check   # fail if any output is out of date

Outputs per spec: `src/shim/qtf_<module>.cpp` and `src/<module>/qt_<module>.f90`.
`tools/gen_c_interfaces.py` then generates the raw `bind(C)` module from the shim.

Spec format (TOML)
------------------
Module keys:
    module        module name, e.g. "widgets"
    doc           module docstring (Markdown, may span lines)
    uses          Fortran `use` lines for the high-level module
    cpp_includes  C++ headers
    cpp_prelude   verbatim C++ placed before the generated functions
    fortran_decls verbatim Fortran declarations (after the enums)
    signal_base   first signal id of the module (ids are assigned in order)
    handle_types  non-QObject handle types from other modules (bound with `%ptr = ...`)
    value_types   Fortran value types passed to C++ field by field:
                  [value_types.QColor] fields = ["r: int", ...], cpp = "QColor({r}, ...)"
                  (fields are int, double, bool, double[N] or another value type)
    functions     module-level free functions: "name(args) [-> type] -- doc" strings
                  or tables {sig, doc, cpp}; the Fortran name is `name`, the C name
                  `qtf_<name>`
    fortran_decls_after  verbatim Fortran declarations after the generated types
    fortran_procedures   verbatim Fortran procedures (module level)

[[enum]]: `doc` and `values`, each "Name = value" (value: integer, 0x hex, or a
Fortran expression).

[[class]] keys:
    name, base, doc
    handle        true for a non-QObject class held through `ptr` (no `attach`)
    ctor          "(args) -- doc" (omit for abstract classes)
    cpp_ctor      C++ expression for the constructor (placeholders below)
    ctors         several constructors: tables {sig, name, cpp, doc}
    ctor_post     Fortran statements run after a constructor binds `res`
    fortran_components  verbatim component declarations
    methods       list of "[static ]name(args) [-> type] -- doc" strings, or
                  tables {sig, doc, cpp, nopass, fortran_name}. Methods sharing a
                  `fortran_name` become one generic binding.
    signals       list of "name: kind -- doc" strings, or tables {sig, doc, cpp_signal, connector}
    fortran_bindings / fortran_procedures / cpp: verbatim additions

Argument and result types:
    int  bool  double  string  strings (results only)
    num                    integer or real(c_double): generates `_i`/`_d` specifics
                           under a generic binding (double in C++)
    num[]                  integer or real(c_double) array (const double * in C++);
                           the element count is passed as `{n}`
    double[] / int[]       real(c_double) / integer array (const double * / const int *);
                           the element count is passed as `{n}`
    Scope::Enum            an enum/flags value (integer in Fortran)
    QClass / QClass?       an object handle (`?`: optional, null when absent)
    a value type           see `value_types`
An argument may have a default (`name: int = 0`), which makes it optional; the
default is a Fortran expression.

C++ placeholders in `cpp` / `cpp_ctor`: `{self}` and `{argname}` expand to the
converted C++ values. The default is `{self}->name(args...)`, `Class::name(...)`
for static methods, and `new Class(args...)` for constructors.

Signal kinds: void, bool, int, double, string (Qt signals, connected with a
generated lambda) and painter, mouse, key, wheel, resize (QtfWidget events; these
need an explicit `connector`).
"""

import os
import re
import sys
import tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC_DIR = os.path.join(ROOT, "spec")

SIGNAL_TYPES = {
    "void": "QSignal", "bool": "QSignalBool", "int": "QSignalInt", "double": "QSignalDouble",
    "string": "QSignalString", "painter": "QSignalPainter", "mouse": "QSignalMouseEvent",
    "key": "QSignalKeyEvent", "wheel": "QSignalWheelEvent", "resize": "QSignalResizeEvent",
}
SIGNAL_LAMBDAS = {
    "void": ("", "qtf_emit(ref)"),
    "bool": ("bool v", "qtf_emit_bool(ref, v)"),
    "int": ("int v", "qtf_emit_int(ref, v)"),
    "double": ("double v", "qtf_emit_double(ref, v)"),
    "string": ("const QString &v", "qtf_emit(ref, v)"),
}


# C++ keywords that are plausible Fortran argument names; renamed on the C side
CPP_KEYWORDS = {"default", "delete", "new", "class", "template", "this", "operator", "private",
                "public", "protected", "register", "union", "auto", "signed", "unsigned"}


def cname(name):
    """C/C++ parameter name for a Fortran argument name."""
    return name + "_" if name in CPP_KEYWORDS else name


def fail(msg):
    sys.exit(f"gen_bindings: {msg}")


# ---------------------------------------------------------------------------
# signatures

class Arg:
    def __init__(self, text, where):
        m = re.fullmatch(r"\s*(\w+)\s*:\s*([\w:]+(?:\[\])?\??)\s*(?:=\s*(.+?))?\s*", text)
        if not m:
            fail(f"bad argument '{text}' in {where}")
        self.name, typ, self.default = m.group(1), m.group(2), m.group(3)
        self.nullable = typ.endswith("?")
        self.type = typ.rstrip("?")
        self.optional = self.nullable or self.default is not None
        kind(self.type, where)

    @property
    def is_object(self):
        return kind(self.type) == "object"


VALUE_TYPES = {}   # name -> {"fields": [(name, type)], "cpp": template}; set per spec


def kind(typ, where=""):
    if typ in ("int", "bool", "double", "string", "strings", "num"):
        return typ
    if typ == "num[]":
        return "numarray"
    if typ == "double[]":
        return "doublearray"
    if typ == "int[]":
        return "intarray"
    if typ in VALUE_TYPES:
        return "value"
    if "::" in typ:
        return "enum"
    if re.fullmatch(r"Q\w+", typ):
        return "object"
    fail(f"unknown type '{typ}' {where}")


class Sig:
    """A parsed method, constructor or static function signature."""

    def __init__(self, text, where, ctor=False):
        doc = None
        if " -- " in text:
            text, doc = text.split(" -- ", 1)
        self.doc = doc.strip() if doc else None
        text = text.strip()
        self.static = text.startswith("static ")
        if self.static:
            text = text[len("static "):]
        pattern = r"\((.*)\)\s*(?:->\s*([\w:]+))?" if ctor else r"(\w+)\((.*)\)\s*(?:->\s*([\w:]+))?"
        m = re.fullmatch(pattern, text)
        if not m:
            fail(f"bad signature '{text}' in {where}")
        groups = m.groups()
        self.name = "new" if ctor else groups[0]
        argtext, self.ret = groups[-2], groups[-1]
        self.args = [Arg(a, where) for a in split_args(argtext)] if argtext.strip() else []
        if self.ret:
            kind(self.ret, where)


def split_args(text):
    """Split on commas outside parentheses and quotes."""
    parts, depth, cur, quote = [], 0, "", None
    for ch in text:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
            cur += ch
        elif ch == "(":
            depth += 1
            cur += ch
        elif ch == ")":
            depth -= 1
            cur += ch
        elif ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return [p for p in parts if p.strip()]


def entries(items, where):
    """Normalize a list of strings / tables into (sig_text, table) pairs."""
    out = []
    for it in items or []:
        if isinstance(it, str):
            out.append((it, {}))
        else:
            sig = it["sig"] + (f" -- {it['doc']}" if "doc" in it else "")
            out.append((sig, it))
    return out


# ---------------------------------------------------------------------------
# C++ generation

ARRAY_FIELD = re.compile(r"double\[\d+\]")


def value_c_params(vt, prefix):
    out = []
    for f, t in VALUE_TYPES[vt]["fields"]:
        if t in VALUE_TYPES:
            out += value_c_params(t, f"{prefix}_{f}")
        elif ARRAY_FIELD.fullmatch(t):
            out.append(f"const double *{prefix}_{f}")
        else:
            out.append(f"{'double' if t == 'double' else 'int'} {prefix}_{f}")
    return out


def value_cpp(vt, prefix):
    vals = {}
    for f, t in VALUE_TYPES[vt]["fields"]:
        if t in VALUE_TYPES:
            vals[f] = value_cpp(t, f"{prefix}_{f}")
        else:
            vals[f] = f"({prefix}_{f} != 0)" if t == "bool" else f"{prefix}_{f}"
    return VALUE_TYPES[vt]["cpp"].format(**vals)


def value_f_args(vt, expr):
    out = []
    for f, t in VALUE_TYPES[vt]["fields"]:
        e = f"{expr}%{f}"
        if t in VALUE_TYPES:
            out += value_f_args(t, e)
        elif ARRAY_FIELD.fullmatch(t):
            out.append(e)
        else:
            out.append({"double": e, "bool": f"qtf_int({e})"}.get(t, f"int({e}, c_int)"))
    return out


ARRAY_KINDS = ("numarray", "doublearray", "intarray")


def has_arrays(sig):
    return any(kind(a.type) in ARRAY_KINDS for a in sig.args)


def cpp_params(sig, has_self):
    params = ["void *self"] if has_self else []
    for a in sig.args:
        k, n = kind(a.type), cname(a.name)
        if k == "string":
            params += [f"const char *{n}", f"int {n}_len"]
        elif k == "object":
            params.append(f"void *{n}")
        elif k in ("double", "num"):
            params.append(f"double {n}")
        elif k in ("numarray", "doublearray"):
            params.append(f"const double *{n}")
        elif k == "intarray":
            params.append(f"const int *{n}")
        elif k == "value":
            params += value_c_params(a.type, n)
        else:
            params.append(f"int {n}")
    if has_arrays(sig):
        params.append("int n")
    if sig.ret in ("string", "strings"):
        params.append("int *len")
    return params


def cpp_value(a):
    k, n = kind(a.type), cname(a.name)
    return {
        "string": f"qtf_qstring({n}, {n}_len)",
        "bool": f"({n} != 0)",
        "enum": f"{a.type}({n})",
        "object": f"as<{a.type}>({n})",
        "value": value_cpp(a.type, n) if k == "value" else None,
    }.get(k, n)


def cpp_call(cls, sig, template, ctor=False):
    values = {a.name: cpp_value(a) for a in sig.args}
    values["self"] = f"as<{cls}>(self)"
    values["n"] = "n"
    if cls is None and not template:
        fail(f"free function {sig.name} needs a `cpp` expression")
    if template:
        try:
            return template.format(**values)
        except KeyError as e:
            fail(f"unknown placeholder {e} in C++ for {cls}::{sig.name}")
    args = ", ".join(values[a.name] for a in sig.args)
    if ctor:
        return f"new {cls}({args})"
    if sig.static:
        return f"{cls}::{sig.name}({args})"
    return f"as<{cls}>(self)->{sig.name}({args})"


def cpp_function(cls, sig, template, ctor=False):
    cfunc = f"qtf_{sig.name}" if cls is None else f"qtf_{cls.lower()}_{sig.name}"
    call = cpp_call(cls, sig, template, ctor)
    ret = "void *" if ctor else {
        None: "void ", "int": "int ", "bool": "int ", "double": "double ", "enum": "int ",
        "string": "char *", "strings": "char *", "object": "void *",
    }[kind(sig.ret) if sig.ret else None]
    if ctor:
        body = f"return {call};"
    elif not sig.ret:
        body = f"{call};"
    else:
        body = {
            "bool": f"return qtf_bool({call});",
            "enum": f"return int({call});",
            "string": f"return qtf_to_c({call}, len);",
            "strings": f"return qtf_list_to_c({call}, len);",
        }.get(kind(sig.ret), f"return {call};")
    params = ", ".join(cpp_params(sig, not (ctor or sig.static or cls is None))) or "void"
    head = f"QTF_API {ret}{cfunc}({params})"
    doc = "".join(f"// {l}\n" for l in sig.doc.splitlines()) if sig.doc else ""
    if len(head) + len(body) + 5 <= 110:
        return f"{doc}{head} {{ {body} }}\n", cfunc
    return f"{doc}{head} {{\n    {body}\n}}\n", cfunc


def cpp_connector(cls, name, k, table):
    if "connector" in table:
        return table["connector"]
    if k not in SIGNAL_LAMBDAS:
        fail(f"signal {cls}::{name} of kind '{k}' needs an explicit connector")
    params, emit = SIGNAL_LAMBDAS[k]
    sig = table.get("cpp_signal", f"&{cls}::{name}")
    return (f"[](void *s, const qtf_slot &ref) {{\n"
            f"        return bool(QObject::connect(as<{cls}>(s), {sig}, as<{cls}>(s), "
            f"[ref]({params}) {{ {emit}; }}));\n    }}")


# ---------------------------------------------------------------------------
# Fortran generation

def f_dummy(a, handle_types, variant=None):
    k = kind(a.type)
    opt = ", optional" if a.optional else ""
    decl = {
        "int": "integer", "enum": "integer", "bool": "logical", "double": "real(c_double)",
        "string": "character(len=*)",
    }.get(k)
    dims = "(:)" if k in ARRAY_KINDS else ""
    if k in ("num", "numarray"):
        decl = "integer" if variant == "i" else "real(c_double)"
    elif k == "doublearray":
        decl = "real(c_double)"
    elif k == "intarray":
        decl = "integer"
    elif k == "value":
        decl = f"type({a.type})"
    elif k == "object":
        decl = f"type({a.type})" if a.type in handle_types else f"class({a.type})"
    return f"{decl}, intent(in){opt} :: {a.name}{dims}"


def f_locals_and_args(sig, handle_types, variant=None):
    """Local declarations, default assignments, and the raw-call argument list."""
    decls, setup, args = [], [], []
    for a in sig.args:
        k = kind(a.type)
        n = a.name
        if k in ("num", "numarray"):
            args.append(f"real({n}, c_double)" if variant == "i" else n)
            continue
        if k == "doublearray":
            args.append(n)
            continue
        if k == "intarray":
            args.append(f"int({n}, c_int)")
            continue
        if k == "value":
            args += value_f_args(a.type, n)
            continue
        if k == "object":
            if a.nullable:
                args.append(f"qtf_ptr({n})" if a.type not in handle_types else f"{n}%ptr")
            else:
                args.append(f"{n}%ptr")
            continue
        if not a.optional:
            args += {
                "string": [n, f"len({n}, c_int)"],
                "bool": [f"qtf_int({n})"],
                "double": [n],
            }.get(k, [f"int({n}, c_int)"])
            continue
        # optional with a default: copy into a local
        local = f"{n}_"
        if k == "string":
            decls.append(f"character(len=:), allocatable :: {local}")
            setup += [f"{local} = {a.default}", f"if (present({n})) {local} = {n}"]
            args += [local, f"len({local}, c_int)"]
        elif k == "bool":
            decls.append(f"logical :: {local}")
            setup += [f"{local} = {a.default}", f"if (present({n})) {local} = {n}"]
            args.append(f"qtf_int({local})")
        elif k == "double":
            decls.append(f"real(c_double) :: {local}")
            setup += [f"{local} = {a.default}", f"if (present({n})) {local} = {n}"]
            args.append(local)
        else:
            decls.append(f"integer(c_int) :: {local}")
            setup += [f"{local} = {a.default}", f"if (present({n})) {local} = int({n}, c_int)"]
            args.append(local)
    arrays = [a.name for a in sig.args if kind(a.type) in ARRAY_KINDS]
    if arrays:
        sizes = ", ".join(f"size({x})" for x in arrays)
        args.append(f"int(min({sizes}), c_int)" if len(arrays) > 1 else f"int({sizes}, c_int)")
    return decls, setup, args


def variants(sig):
    """("" , None) normally; ("_d", "d") and ("_i", "i") for `num` arguments."""
    if any(kind(a.type) in ("num", "numarray") for a in sig.args):
        return [("_d", "d"), ("_i", "i")]
    return [("", None)]


def f_procedure(cls, sig, handle_types, ctor=False, suffix="", variant=None, handle=False, ctor_post=()):
    """A high-level Fortran procedure wrapping one shim function."""
    if cls is None:   # module-level free function
        raw, pname = f"qtf_{sig.name}", sig.name
    else:
        cl = cls.lower()
        raw = f"qtf_{cl}_{sig.name}"
        if ctor:
            pname = f"{cl}_{sig.name}"
        elif sig.static:
            pname = f"{cls}_{sig.name}"
        else:
            pname = f"{cl}_{sig.name}{suffix}"
    has_self = not (ctor or sig.static or cls is None)
    dummies = (["self"] if has_self else []) + [a.name for a in sig.args]
    decls = [f"class({cls}), intent(in) :: self"] if has_self else []
    decls += [f_dummy(a, handle_types, variant) for a in sig.args]
    locals_, setup, args = f_locals_and_args(sig, handle_types, variant)
    if has_self:
        args.insert(0, "self%ptr")
    rk = "ctor" if ctor else (kind(sig.ret) if sig.ret else None)
    body = []
    if rk is None:
        head, end = f"subroutine {pname}({', '.join(dummies)})", f"end subroutine {pname}"
        body.append(f"call {raw}({', '.join(args)})")
    else:
        head, end = f"function {pname}({', '.join(dummies)}) result(res)", f"end function {pname}"
        if rk == "ctor":
            decls.append(f"type({cls}) :: res")
            if handle:
                body.append(f"res%ptr = {raw}({', '.join(args)})")
            else:
                body.append(f"call res%attach({raw}({', '.join(args)}))")
            body += list(ctor_post)
        elif rk in ("int", "enum"):
            decls.append("integer :: res")
            body.append(f"res = {raw}({', '.join(args)})")
        elif rk == "bool":
            decls.append("logical :: res")
            body.append(f"res = qtf_logical({raw}({', '.join(args)}))")
        elif rk == "double":
            decls.append("real(c_double) :: res")
            body.append(f"res = {raw}({', '.join(args)})")
        elif rk in ("string", "strings"):
            decls.append("character(len=:), allocatable :: res" if rk == "string"
                         else "type(qt_string), allocatable :: res(:)")
            locals_ += ["integer(c_int) :: n_", "type(c_ptr) :: p_"]
            args.append("n_")
            body += [f"p_ = {raw}({', '.join(args)})",
                     f"res = {'qtf_take_string' if rk == 'string' else 'qtf_take_string_list'}(p_, n_)"]
        elif rk == "object":
            decls.append(f"type({sig.ret}) :: res")
            if sig.ret in handle_types:
                body.append(f"res%ptr = {raw}({', '.join(args)})")
            else:
                body.append(f"call res%attach({raw}({', '.join(args)}))")
    lines = [f"    !> {line}" if line else "    !>" for line in sig.doc.splitlines()]
    lines.append(f"    {head}")
    lines += [f"        {d}" for d in decls + locals_]
    lines += [f"        {s}" for s in setup + body]
    lines.append(f"    {end}")
    return "\n".join(wrap_line(l) for l in lines), pname


def wrap_line(line, limit=120):
    """Break a long Fortran statement after a comma."""
    if len(line) <= limit or line.lstrip().startswith("!"):
        return line
    indent = re.match(r"\s*", line).group(0) + "        "
    cut = line.rfind(", ", 0, limit - 2)
    if cut < 0:
        return line
    return line[:cut + 1] + " &\n" + wrap_line(indent + line[cut + 2:], limit)


def ctor_usage(cls, sig):
    """`QLabel([text, parent])` style usage string for constructor docs."""
    req = [a.name for a in sig.args if not a.optional]
    opt = [a.name for a in sig.args if a.optional]
    inner = ", ".join(req)
    if opt:
        inner += (" [, " if req else "[") + ", ".join(opt) + "]"
    return f"{cls}({inner})"


def f_value(v):
    v = str(v).strip()
    if re.fullmatch(r"0x[0-9a-fA-F]+", v):
        return f"int(z'{v[2:].upper().zfill(8)}', c_int)"
    return v


# ---------------------------------------------------------------------------

MODULE_KEYS = {"module", "doc", "uses", "cpp_includes", "cpp_prelude", "fortran_decls", "signal_base",
               "handle_types", "value_types", "fortran_decls_after", "fortran_procedures", "enum", "class",
               "functions"}
CLASS_KEYS = {"name", "base", "doc", "handle", "ctor", "cpp_ctor", "ctors", "ctor_post", "fortran_components",
              "methods", "signals", "fortran_bindings", "fortran_procedures", "cpp"}


def validate(spec):
    """Reject unknown keys (e.g. a module key accidentally placed inside a [[class]] table)."""
    for k in spec:
        if k not in MODULE_KEYS:
            fail(f"unknown module key '{k}'")
    for c in spec.get("class", []):
        for k in c:
            if k not in CLASS_KEYS:
                fail(f"unknown key '{k}' in class {c.get('name')} (module keys must come before [[class]])")


def generate(spec):
    validate(spec)
    mod = spec["module"]
    classes = spec.get("class", [])
    handle_types = set(spec.get("handle_types", [])) | {c["name"] for c in classes if c.get("handle")}
    VALUE_TYPES.clear()
    for name, vt in spec.get("value_types", {}).items():
        fields = [tuple(x.strip() for x in f.split(":")) for f in vt["fields"]]
        VALUE_TYPES[name] = {"fields": fields, "cpp": vt["cpp"]}
    next_id = spec.get("signal_base", 0)

    cpp_funcs, cpp_ids, cpp_regs = [], [], []
    f_types, f_procs, publics = [], [], []

    for c in classes:
        cls, base = c["name"], c.get("base", "QObject")
        handle = c.get("handle", False)
        where = f"class {cls}"
        if not c.get("doc"):
            fail(f"{where} has no doc")
        cl = cls.lower()
        bindings, components, attach = [], [], []
        cpp_class = [f"// {'-' * 75}\n// {cls}\n"]
        if c.get("cpp"):
            cpp_class.append(c["cpp"].strip("\n") + "\n")

        # signals
        for text, table in entries(c.get("signals"), where):
            body, _, doc = text.partition(" -- ")
            m = re.fullmatch(r"\s*(\w+)\s*:\s*(\w+)\s*", body)
            if not m or m.group(2) not in SIGNAL_TYPES:
                fail(f"bad signal '{text}' in {where}")
            if not doc:
                fail(f"signal {cls}::{m.group(1)} has no doc")
            name, k = m.groups()
            sid = f"QTF_SIG_{cls.upper()}_{name.upper()}"
            cpp_ids.append(f"    {sid} = {next_id},")
            next_id += 1
            cpp_regs.append(f"    qtf_register_connector({sid}, {cpp_connector(cls, name, k, table)});")
            components.append(f"        type({SIGNAL_TYPES[k]}) :: {name}   !! {doc.strip()}")
            attach.append(f"        self%{name} = {SIGNAL_TYPES[k]}(ptr, {sid})")
        if attach:
            bindings.append(f"        procedure :: attach => {cl}_attach")
            f_procs.append("\n".join([
                f"    !> Bind to a C++ {cls} and its signals.",
                f"    subroutine {cl}_attach(self, ptr)",
                f"        class({cls}), intent(inout) :: self",
                "        type(c_ptr), intent(in) :: ptr",
                f"        call self%{base}%attach(ptr)",
                *attach,
                f"    end subroutine {cl}_attach"]))

        # constructors
        ctor_iface = ""
        ctor_specs = [(c["ctor"], {"cpp": c.get("cpp_ctor")})] if c.get("ctor") else []
        ctor_specs += [(t["sig"] + f" -- {t['doc']}", t) for t in c.get("ctors", [])]
        usages, pnames = [], []
        for text, table in ctor_specs:
            sig = Sig(text, where, ctor=True)
            sig.name = table.get("name", "new")
            if not sig.doc:
                fail(f"{where}: constructor has no doc")
            src, _ = cpp_function(cls, sig, table.get("cpp"), ctor=True)
            cpp_class.append(src)
            post = [l.strip() for l in c.get("ctor_post", "").strip().splitlines()]
            proc, pname = f_procedure(cls, sig, handle_types, ctor=True, handle=handle, ctor_post=post)
            f_procs.append(proc)
            usages.append(f"`{ctor_usage(cls, sig)}`")
            pnames.append(pname)
        if pnames:
            ctor_iface = "\n".join([
                f"    !> Constructor: {' or '.join(usages)}.",
                f"    interface {cls}",
                f"        module procedure :: {', '.join(pnames)}",
                f"    end interface {cls}"])

        # methods (grouped by Fortran name: several specifics make a generic)
        groups = {}
        for text, table in entries(c.get("methods"), where):
            sig = Sig(text, where)
            if not sig.doc:
                fail(f"method {cls}::{sig.name} has no doc")
            src, _ = cpp_function(cls, sig, table.get("cpp"))
            cpp_class.append(src)
            for suffix, variant in variants(sig):
                proc, pname = f_procedure(cls, sig, handle_types, suffix=suffix, variant=variant)
                f_procs.append(proc)
                if sig.static:
                    publics.append(pname)
                    if table.get("nopass"):
                        bindings.append(f"        procedure, nopass :: {sig.name} => {pname}")
                else:
                    groups.setdefault(table.get("fortran_name", sig.name), []).append(pname)
        for fname, procs in groups.items():
            if len(procs) == 1 and procs[0].lower() == f"{cl}_{fname}".lower():
                bindings.append(f"        procedure :: {fname} => {procs[0]}")
            else:
                bindings.append(f"        procedure, private :: {', '.join(procs)}")
                bindings.append(f"        generic :: {fname} => {', '.join(procs)}")
        if c.get("fortran_bindings"):
            bindings += ["        " + l.strip() for l in c["fortran_bindings"].strip().splitlines()]
        if c.get("fortran_procedures"):
            f_procs.append(c["fortran_procedures"].strip("\n"))

        doc = [f"    !> {l}" if l else "    !>" for l in c["doc"].strip().splitlines()]
        if handle and "base" not in c:
            tdef = doc + [f"    type, public :: {cls}", "        type(c_ptr) :: ptr = c_null_ptr"]
        else:
            tdef = doc + [f"    type, extends({base}), public :: {cls}"]
        tdef += components
        if c.get("fortran_components"):
            tdef += ["        " + l.strip() for l in c["fortran_components"].strip().splitlines()]
        if bindings:
            tdef += ["    contains"] + bindings
        tdef.append(f"    end type {cls}")
        f_types.append("\n".join(tdef) + ("\n" + ctor_iface if ctor_iface else ""))
        cpp_funcs.append("\n".join(cpp_class))

    # ---- module-level free functions
    free_cpp = []
    for text, table in entries(spec.get("functions"), "functions"):
        sig = Sig(text, "functions")
        if not sig.doc:
            fail(f"function {sig.name} has no doc")
        if any(kind(a.type) in ("num", "numarray") for a in sig.args):
            fail(f"function {sig.name}: num types are only supported in methods")
        src, _ = cpp_function(None, sig, table.get("cpp"))
        free_cpp.append(src)
        proc, pname = f_procedure(None, sig, handle_types)
        f_procs.append(proc)
        publics.append(pname)
    if free_cpp:
        cpp_funcs.append(f"// {'-' * 75}\n// functions\n\n" + "\n".join(free_cpp))

    # ---- C++ file
    includes = "".join(f"#include <{h}>\n" for h in sorted(spec.get("cpp_includes", [])))
    ids = ("// Signal ids (shared with Fortran through the generated raw module).\n"
           "enum : int {\n" + "\n".join(cpp_ids) + "\n};\n\n") if cpp_ids else ""
    regs = ("// " + "-" * 75 + "\n// signal connectors\n\n"
            f"static const bool qtf_{mod}_registered = [] {{\n" + "\n".join(cpp_regs) +
            "\n    return true;\n}();\n") if cpp_regs else ""
    cpp = (f"// C ABI shim over Qt {mod.capitalize()}.\n"
           f"//\n// GENERATED by tools/gen_bindings.py from spec/{mod}.toml; do not edit.\n\n"
           "// Compiled by fpm as part of the qt-fortran library, unless the shim is\n"
           "// built separately as a shared library (QTF_EXTERNAL_SHIM; see tools/fpm_qt.py).\n"
           "#ifndef QTF_EXTERNAL_SHIM\n\n"
           f'#include "qtf_common.h"\n\n{includes}\n'
           "template <typename T> static T *as(void *p) { return static_cast<T *>(p); }\n\n"
           f"{ids}{spec.get('cpp_prelude', '').strip()}\n\n" + "\n".join(cpp_funcs) + "\n" + regs
           + "\n#endif // QTF_EXTERNAL_SHIM\n")

    # ---- Fortran module
    enums = []
    for e in spec.get("enum", []):
        enums.append(f"    ! {e['doc']}")
        for v in e["values"]:
            name, _, value = v.partition("=")
            enums.append(f"    integer(c_int), parameter, public :: {name.strip()} = {f_value(value)}")
        enums.append("")
    doc = "\n".join(f"!> {l}" if l else "!>" for l in spec["doc"].strip().splitlines())
    uses = "\n".join(f"    {u}" for u in spec.get("uses", []))
    pubs = "\n".join(f"    public :: {p}" for p in publics)
    decls = spec.get("fortran_decls", "").strip("\n")
    f90 = (f"{doc}\n!>\n!> GENERATED by tools/gen_bindings.py from spec/{mod}.toml; do not edit.\n"
           f"module qt_{mod}\n\n    use iso_c_binding\n{uses}\n    implicit none\n    private\n\n"
           + "\n".join(enums) + (f"\n{decls}\n\n" if decls else "\n")
           + "\n\n".join(f_types) + "\n\n"
           + (spec["fortran_decls_after"].strip("\n") + "\n\n" if spec.get("fortran_decls_after") else "")
           + (pubs + "\n\n" if pubs else "")
           + "contains\n\n" + "\n\n".join(f_procs)
           + ("\n\n" + spec["fortran_procedures"].strip("\n") if spec.get("fortran_procedures") else "")
           + f"\n\nend module qt_{mod}\n")
    return cpp, f90


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    for fn in sorted(os.listdir(SPEC_DIR)):
        if not fn.endswith(".toml"):
            continue
        with open(os.path.join(SPEC_DIR, fn), "rb") as f:
            spec = tomllib.load(f)
        mod = spec["module"]
        cpp, f90 = generate(spec)
        for rel, text in ((f"src/shim/qtf_{mod}.cpp", cpp), (f"src/{mod}/qt_{mod}.f90", f90)):
            path = os.path.join(ROOT, rel)
            current = open(path).read() if os.path.exists(path) else None
            if current == text:
                continue
            if check:
                stale.append(rel)
            else:
                with open(path, "w", newline="\n") as f:
                    f.write(text)
                print(f"wrote {rel}")
    if stale:
        fail("out of date (run `pixi run gen`): " + ", ".join(stale))


if __name__ == "__main__":
    main()
