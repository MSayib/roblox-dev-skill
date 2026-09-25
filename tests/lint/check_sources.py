#!/usr/bin/env python3
"""Source hygiene checks that no general-purpose linter covers. Each rule exists because the bug it
prevents actually happened, or would fail silently on a user's machine.

    python3 tests/lint/check_sources.py
"""
import glob, os, py_compile, re, sys, tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
os.chdir(ROOT)
errors = []


def err(msg):
    errors.append(msg)


def read_bytes(p):
    with open(p, "rb") as f:
        return f.read()


# 1. PowerShell 5.1 reads BOM-less UTF-8 as ANSI, and cmd.exe uses the OEM code page.
for p in ["install.ps1", "install.cmd"] + glob.glob("tests/**/*.ps1", recursive=True):
    for n, line in enumerate(read_bytes(p).split(b"\n"), 1):
        if any(b > 127 for b in line):
            err(f"{p}:{n}: non-ASCII byte (Windows PowerShell 5.1 would misread it)")

# 2. cmd.exe can mis-parse bare LF; raw.githubusercontent serves the blob bytes as stored.
data = read_bytes("install.cmd")
bare_lf = data.count(b"\n") - data.count(b"\r\n")
if bare_lf:
    err(f"install.cmd: {bare_lf} bare LF line ending(s); must be CRLF throughout")

# 3. Unix scripts must be LF — a CRLF install.sh dies with "$'\r': command not found".
for p in ["install.sh"] + glob.glob("tools/**/*.sh", recursive=True) + glob.glob("tests/**/*.sh", recursive=True) \
        + glob.glob("tools/**/*.py", recursive=True) + glob.glob("tests/**/*.py", recursive=True):
    if b"\r\n" in read_bytes(p):
        err(f"{p}: CRLF line endings; must be LF")

# 4. bash 3.2 in a UTF-8 locale reads a non-ASCII byte right after a variable name as part of the
#    name: "$REF…" looked up REF\xe2… and killed install.sh under set -u (v2.13.0, fixed in 2.13.1).
for p in ["install.sh"] + glob.glob("tools/**/*.sh", recursive=True) + glob.glob("tests/**/*.sh", recursive=True):
    for n, line in enumerate(open(p, encoding="utf-8").read().splitlines(), 1):
        for m in re.finditer(r"\$([A-Za-z_][A-Za-z0-9_]*)(?=[^\x00-\x7f])", line):
            err(f"{p}:{n}: ${m.group(1)} is followed by a non-ASCII character; write ${{{m.group(1)}}}")

# 5. The installer's whole body must sit inside main(), called on the final line, so a truncated
#    `curl | bash` download executes nothing.
lines = [l for l in open("install.sh", encoding="utf-8").read().splitlines() if l.strip()]
if lines[-1].strip() != 'main "$@"':
    err('install.sh: the last line must be `main "$@"` (truncation safety)')

# 6. Every Python tool must compile.
with tempfile.TemporaryDirectory() as d:
    for p in glob.glob("tools/**/*.py", recursive=True) + glob.glob("tests/**/*.py", recursive=True):
        try:
            py_compile.compile(p, cfile=os.path.join(d, "x.pyc"), doraise=True)
        except py_compile.PyCompileError as e:
            err(f"{p}: does not compile: {e.msg}")

# 7. The skill name must match the folder it installs into (agentskills.io spec).
name = re.search(r"^name:\s*(\S+)", open("SKILL.md", encoding="utf-8").read(), re.M)
if not name or name.group(1) != "roblox-dev-skill":
    err("SKILL.md: name must be roblox-dev-skill (the installers create a folder of that name)")
for p in ("install.sh", "install.ps1"):
    if "roblox-dev-skill" not in open(p, encoding="utf-8").read():
        err(f"{p}: does not reference the skill folder name roblox-dev-skill")

# 8. Windows opens text in its legacy code page unless told otherwise; UTF-8 Markdown then fails to
#    decode (audit-skill-examples.py crashed on byte 0x8f in CI). Every open() must name an encoding.
for p in glob.glob("tools/**/*.py", recursive=True):
    for n, line in enumerate(open(p, encoding="utf-8").read().splitlines(), 1):
        # judge the rest of the line after "open(": nested calls like os.path.join(...) close early
        for m in re.finditer(r"(?<![\w.])open\(", line):
            rest = line[m.end():]
            if "encoding=" not in rest and not re.search(r"['\"][rwa]?b\+?['\"]", rest):
                err(f"{p}:{n}: open() without encoding= (Windows would use cp1252)")

if errors:
    print(f"{len(errors)} source problem(s):")
    for e in errors:
        print(f"  {e}")
    sys.exit(1)
print("source checks passed")
