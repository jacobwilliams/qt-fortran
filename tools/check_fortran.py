"""Check Fortran sources for documentation and `implicit none` in interface bodies.

Usage:  python tools/check_fortran.py [paths...]   (default: src test example)

Rules:
  1. Every module, program, procedure, derived type and named (generic)
     interface has a FORD docstring: a `!>` / `!<` comment block directly
     before it, or a `!!` comment directly after it (see ford.md).
  2. Every procedure body inside an `interface` block has `implicit none`
     (interface bodies do not inherit the host's implicit typing rules).

Exits non-zero and lists the offending lines if any rule is broken.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PREFIX = r"(?:(?:pure|elemental|impure|recursive|non_recursive|module)\s+)*"
RESULT_TYPE = r"(?:(?:integer|logical|real|complex|character|type|class)\s*(?:\([^)]*\))?\s+)?"
PROC = re.compile(rf"^{PREFIX}{RESULT_TYPE}(subroutine|function)\s+(\w+)", re.I)
TYPE = re.compile(r"^type\s*(?:,[^:]*)?::\s*(\w+)|^type\s+(?!is\b)(\w+)\s*$", re.I)
GENERIC = re.compile(r"^interface\s+(\w+|operator\s*\(.*\)|assignment\s*\(.*\))", re.I)
UNIT = re.compile(r"^(module|program)\s+(?!procedure\b)(\w+)", re.I)
INTERFACE_START = re.compile(r"^(abstract\s+)?interface\b", re.I)
INTERFACE_END = re.compile(r"^end\s*interface\b", re.I)
PROC_END = re.compile(r"^end\s*(subroutine|function)\b", re.I)


def fortran_files(paths):
    for p in paths:
        p = os.path.join(ROOT, p)
        if os.path.isfile(p):
            yield p
        for dirpath, _, files in os.walk(p):
            for f in sorted(files):
                if f.endswith(".f90"):
                    yield os.path.join(dirpath, f)


def is_doc_before(lines, i):
    """A `!>` or `!<` comment block ends on the line before i."""
    j = i - 1
    while j >= 0 and lines[j].strip().startswith("&"):   # continued declaration
        j -= 1
    return j >= 0 and lines[j].strip()[:2] in ("!>", "!<")


def is_doc_after(lines, i):
    """A `!!` comment follows the (possibly continued) declaration at line i."""
    j = i
    while lines[j].rstrip().endswith("&") and j + 1 < len(lines):
        j += 1
    return j + 1 < len(lines) and lines[j + 1].strip().startswith("!!")


def check(path):
    problems = []
    lines = open(path).read().splitlines()
    rel = os.path.relpath(path, ROOT)
    in_interface = False
    body = None   # (name, line) of the current interface body
    body_has_implicit = False
    for i, raw in enumerate(lines):
        line = raw.strip()
        code = line.split("!", 1)[0].strip()
        if not code:
            continue
        if INTERFACE_END.match(code):
            in_interface = False
            continue
        m = INTERFACE_START.match(code)
        if m:
            in_interface = True
        if in_interface:
            pm = PROC.match(code)
            if pm and not code.lower().startswith("end"):
                body, body_has_implicit = (pm.group(2), i + 1), False
            elif re.match(r"^implicit\s+none\b", code, re.I):
                body_has_implicit = True
            elif PROC_END.match(code) and body:
                if not body_has_implicit:
                    problems.append(f"{rel}:{body[1]}: interface body '{body[0]}' lacks implicit none")
                body = None
        if code.lower().startswith("end"):
            continue
        name = None
        for regex in (PROC, TYPE, GENERIC, UNIT):
            m = regex.match(code)
            if m:
                name = [g for g in m.groups() if g][-1]   # the name is the last group matched
                break
        if name and not (is_doc_before(lines, i) or is_doc_after(lines, i)):
            problems.append(f"{rel}:{i + 1}: '{name}' has no docstring")
    return problems


def main():
    paths = sys.argv[1:] or ["src", "test", "example"]
    problems = [p for f in fortran_files(paths) for p in check(f)]
    for p in problems:
        print(p)
    if problems:
        sys.exit(f"check_fortran: {len(problems)} problem(s)")


if __name__ == "__main__":
    main()
