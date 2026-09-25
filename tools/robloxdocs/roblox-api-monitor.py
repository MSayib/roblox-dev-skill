#!/usr/bin/env python3
"""roblox-api-monitor — keep a local, split copy of the Roblox Full API Dump current.

check -> download -> validate -> diff -> split -> audit, on macOS, Linux and Windows alike.
Needs only Python 3.6+ (curl is used as a fallback if Python's TLS certificates are missing).

Part of roblox-dev-skill: https://github.com/MSayib/roblox-dev-skill

Usage:
    roblox-api-monitor.py [--force] [--refs DIR] [--audit warn|strict|off] [--keep N]

    --force        re-download even if this version is already present
    --refs DIR     the skill's references/ directory, for grep-back and the example audit
    --audit MODE   warn (default): report doc-example defects, exit 0
                   strict:          exit non-zero on any defect (for skill maintainers)
                   off:             skip the audit
    --keep N       prune to the newest N dumps. Omit it and nothing is ever deleted:
                   old dumps are forensic evidence (see CHANGELOG 2.12.0).

Configuration, lowest to highest precedence:
    $ROBLOX_DOCS_HOME/config    KEY=VALUE lines: SKILL_REFS, AUDIT_MODE (parsed, never executed)
    environment                 ROBLOX_DOCS_HOME, ROBLOX_SKILL_REFS, ROBLOX_AUDIT_MODE
    command-line flags
"""
import datetime, glob, json, os, re, shutil, ssl, subprocess, sys, tempfile
import urllib.error, urllib.request

# Windows pipes default to a legacy code page (cp1252) that cannot encode emoji; without this a
# final "✅" print crashed split-api-dump.py AFTER it had written every file (found by CI).
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(errors="replace")
    except (AttributeError, ValueError):   # Python 3.6, or a stream that cannot be reconfigured
        pass

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CLIENTSETTINGS = "https://clientsettings.roblox.com/v2/client-version/{}"
CDN_DUMP = "https://setup.rbxcdn.com/{}-Full-API-Dump.json"
ISSUES = "https://github.com/MSayib/roblox-dev-skill/issues"
IS_WINDOWS = os.name == "nt"


def emit(msg=""):
    # Windows consoles on legacy code pages cannot print every emoji; degrade instead of crashing.
    try:
        print(msg, flush=True)
    except UnicodeEncodeError:
        print(msg.encode("ascii", "replace").decode("ascii"), flush=True)


# ─── Configuration ──────────────────────────────────────────────────────
def read_config(path):
    cfg = {}
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                m = re.match(r"\s*([A-Z_]+)\s*=\s*(.*?)\s*$", line)
                if m:
                    cfg[m.group(1)] = m.group(2).strip("\"'")
    except OSError:
        pass
    return cfg


def parse_args(argv, cfg):
    o = dict(force=False, keep=0,
             refs=os.environ.get("ROBLOX_SKILL_REFS") or cfg.get("SKILL_REFS") or "",
             audit=os.environ.get("ROBLOX_AUDIT_MODE") or cfg.get("AUDIT_MODE") or "warn")
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--force":
            o["force"] = True
        elif a == "--refs":
            i += 1; o["refs"] = argv[i]
        elif a == "--audit":
            i += 1; o["audit"] = argv[i]
        elif a == "--strict-audit":
            o["audit"] = "strict"
        elif a == "--no-audit":
            o["audit"] = "off"
        elif a == "--keep":
            i += 1; o["keep"] = argv[i]
        elif a in ("-h", "--help"):
            emit(__doc__); sys.exit(0)
        else:
            sys.exit(f"unknown argument: {a} (try --help)")
        i += 1
    if o["audit"] not in ("warn", "strict", "off"):
        sys.exit(f"invalid --audit '{o['audit']}' (warn|strict|off)")
    if not str(o["keep"]).isdigit():
        sys.exit("--keep needs a non-negative integer")
    o["keep"] = int(o["keep"])
    o["refs"] = os.path.expanduser(o["refs"]) if o["refs"] else ""
    if not o["refs"]:
        data_home = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
        candidates = [os.path.join(data_home, "roblox-dev-skill", "roblox-dev-skill", "references")]
        if os.environ.get("LOCALAPPDATA"):
            candidates.append(os.path.join(os.environ["LOCALAPPDATA"], "roblox-dev-skill", "roblox-dev-skill", "references"))
        home = os.path.expanduser("~")
        candidates += [os.path.join(home, ".agents", "skills", "roblox-dev-skill", "references"),
                       os.path.join(home, ".claude", "skills", "roblox-dev-skill", "references"),
                       os.path.join(home, ".claude", "skills", "roblox-dev", "references")]
        o["refs"] = next((c for c in candidates if os.path.isdir(c)), "")
    return o


# ─── Network ────────────────────────────────────────────────────────────
def _curl(url, dest, timeout):
    cmd = ["curl", "-fsSL", "--max-time", str(timeout), url]
    if dest:
        cmd[1:1] = ["-o", dest]
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if r.returncode != 0:
        raise OSError(f"curl failed ({r.returncode}): {r.stderr.decode(errors='replace').strip()}")
    return r.stdout


def fetch(url, dest=None, timeout=30):
    """GET url -> bytes (or into dest). Falls back to curl when Python has no usable CA bundle,
    which is the default state of a python.org install on macOS."""
    req = urllib.request.Request(url, headers={"User-Agent": "roblox-dev-skill-monitor"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if dest is None:
                return resp.read()
            with open(dest, "wb") as f:
                shutil.copyfileobj(resp, f)
            return b""
    except (ssl.SSLError, urllib.error.URLError) as e:
        reason = getattr(e, "reason", e)
        if isinstance(reason, ssl.SSLError) or "CERTIFICATE" in str(reason).upper():
            if shutil.which("curl"):
                return _curl(url, dest, timeout)
        raise


def json_url(url):
    try:
        return json.loads(fetch(url, timeout=20).decode("utf-8"))
    except Exception:
        return {}


# ─── Lock ───────────────────────────────────────────────────────────────
def pid_alive(pid):
    if pid <= 0:
        return False
    if IS_WINDOWS:
        # os.kill(pid, 0) is NOT a liveness probe on Windows: signal 0 is CTRL_C_EVENT, so it
        # would interrupt the other process. Ask the kernel instead.
        import ctypes
        k32 = ctypes.windll.kernel32
        h = k32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
        if not h:
            return False
        code = ctypes.c_ulong()
        k32.GetExitCodeProcess(h, ctypes.byref(code))
        k32.CloseHandle(h)
        return code.value == 259  # STILL_ACTIVE
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


class Lock:
    """A directory lock that records its PID, so a run killed before cleanup cannot wedge
    every later run."""

    def __init__(self, path):
        self.path = path

    def __enter__(self):
        try:
            os.mkdir(self.path)
        except FileExistsError:
            try:
                owner = int(open(os.path.join(self.path, "pid")).read().strip() or 0)
            except (OSError, ValueError):
                owner = 0
            if pid_alive(owner):
                sys.exit(f"❌ another run is active (pid {owner}). Wait for it to finish.")
            emit(f"⚠️  clearing a stale lock (owner pid {owner or 'unknown'} is not running)")
            shutil.rmtree(self.path, ignore_errors=True)
            os.mkdir(self.path)
        with open(os.path.join(self.path, "pid"), "w") as f:
            f.write(str(os.getpid()))
        return self

    def __exit__(self, *exc):
        shutil.rmtree(self.path, ignore_errors=True)
        return False


# ─── Helpers ────────────────────────────────────────────────────────────
def version_key(path):
    return [int(x) for x in re.findall(r"\d+", os.path.basename(path).split("-")[0])]


def now_utc():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def validate_dump(path):
    """A truncated or malformed download must never become latest.json."""
    try:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
    except Exception as e:
        return None, f"not valid JSON ({e.__class__.__name__}: {e})"
    c, e = d.get("Classes"), d.get("Enums")
    if not isinstance(c, list) or not isinstance(e, list):
        return None, "Classes/Enums are not arrays"
    if len(c) < 500 or len(e) < 300:
        return None, f"only {len(c)} classes / {len(e)} enums — looks truncated"
    return f"{len(c)} classes, {len(e)} enums", None


def point_latest(dump_dir, dump_file):
    latest = os.path.join(dump_dir, "latest.json")
    if os.path.lexists(latest):
        os.remove(latest)
    try:
        os.symlink(dump_file, latest)
    except (OSError, NotImplementedError, AttributeError):
        # Windows without Developer Mode cannot create symlinks; a copy works everywhere.
        shutil.copyfile(dump_file, latest)


def tool(name, *args):
    return subprocess.run([sys.executable, os.path.join(SCRIPT_DIR, name)] + list(args)).returncode


# ─── Main ───────────────────────────────────────────────────────────────
def main(argv):
    root = os.path.expanduser(os.environ.get("ROBLOX_DOCS_HOME") or os.path.join("~", "RobloxDocs"))
    api = os.path.join(root, "RobloxAPI")
    dump_dir, diff_dir = os.path.join(api, "dumps"), os.path.join(api, "diffs")
    version_file = os.path.join(api, ".current-version")
    o = parse_args(argv, read_config(os.path.join(root, "config")))
    os.makedirs(dump_dir, exist_ok=True)
    os.makedirs(diff_dir, exist_ok=True)

    with Lock(os.path.join(root, ".monitor.lock")):
        import platform
        system = platform.system()
        local_platform = "MacStudio" if system == "Darwin" else "WindowsStudio64"
        emit(f"🖥️  Platform detected: {system} → checking {local_platform}")

        local_version = json_url(CLIENTSETTINGS.format(local_platform)).get("version", "unknown")
        emit(f"📋 {local_platform} version: {local_version}")

        # Full-API-Dump.json is only on the CDN under the WindowsStudio64 hash (MacStudio 403s).
        win = json_url(CLIENTSETTINGS.format("WindowsStudio64"))
        win_version, win_hash = win.get("version"), win.get("clientVersionUpload")
        if not win_version or not win_hash:
            emit("❌ Could not read version info from clientsettings.roblox.com. Network issue?")
            return 1
        if local_version != win_version and local_platform != "WindowsStudio64":
            emit(f"ℹ️  {local_platform} ({local_version}) ≠ WindowsStudio64 ({win_version}); using the Windows dump")

        dump_file = os.path.join(dump_dir, f"{win_version}-Full-API-Dump.json")

        def stamp(updated_at=None):
            now = now_utc()
            with open(version_file, "w", encoding="utf-8") as f:
                json.dump({"version": win_version, "platform": local_platform,
                           "platformVersion": local_version, "winHash": win_hash,
                           "updatedAt": updated_at or now, "checkedAt": now}, f)
                f.write("\n")

        if os.path.exists(dump_file) and not o["force"]:
            emit(f"✅ Already up-to-date: {win_version}")
            try:
                previous = json.load(open(version_file, encoding="utf-8")).get("updatedAt")
            except Exception:
                previous = None
            stamp(previous)
            return 0

        emit(f"📥 Downloading Full-API-Dump.json for {win_version} ({win_hash})...")
        fd, tmp = tempfile.mkstemp(prefix="rbx-dump.", suffix=".json", dir=dump_dir)
        os.close(fd)
        try:
            try:
                fetch(CDN_DUMP.format(win_hash), dest=tmp, timeout=240)
            except Exception as e:
                emit(f"❌ Download failed: {e}")
                return 1
            summary, problem = validate_dump(tmp)
            if problem:
                emit(f"❌ Downloaded dump failed validation: {problem}")
                emit("   The previous latest.json was left untouched.")
                return 1
            emit(f"   Validated: {summary}")

            others = [p for p in glob.glob(os.path.join(dump_dir, "*-Full-API-Dump.json"))
                      if os.path.basename(p) != os.path.basename(dump_file)]
            prev = max(others, key=version_key) if others else ""
            os.replace(tmp, dump_file)
            tmp = None
        finally:
            if tmp and os.path.exists(tmp):
                os.remove(tmp)

        emit(f"   Saved: {os.path.getsize(dump_file) / 1048576:.1f} MB")
        point_latest(dump_dir, dump_file)
        stamp()

        emit()
        if prev:
            label = os.path.basename(prev).replace("-Full-API-Dump.json", "")
            out = os.path.join(diff_dir, f"{label}-to-{win_version}.json")
            args = [prev, dump_file, "--json", out]
            if o["refs"] and os.path.isdir(o["refs"]):
                args += ["--refs", o["refs"]]
            tool("diff-api-dumps.py", *args)
        else:
            emit("ℹ️  First ingest on this machine — nothing to diff against yet.")

        emit()
        emit("🔄 Splitting the API dump...")
        if tool("split-api-dump.py", dump_file, "--root", root) != 0:
            emit("❌ Splitting failed.")
            return 1

        audit_status = 0
        if o["audit"] != "off":
            if not o["refs"] or not os.path.isdir(o["refs"]):
                emit()
                emit(f"ℹ️  skill references not found — skipping the example audit "
                     f"(set SKILL_REFS in {os.path.join(root, 'config')})")
            else:
                emit()
                emit(f"🔍 Auditing skill examples against {win_version} ({o['audit']} mode)...")
                status = tool("audit-skill-examples.py", o["refs"], "--dump", dump_file)
                if status != 0:
                    emit()
                    if o["audit"] == "strict":
                        emit(f"❌ EXAMPLE AUDIT FOUND DEFECTS — a doc example may not run on {win_version}.")
                        emit("   Fix the references before treating this ingest as complete.")
                        audit_status = status
                    else:
                        emit(f"⚠️  The example audit flagged doc examples that may not run on {win_version}.")
                        emit(f"   Your API data is fine. Please report it: {ISSUES}")

        if o["keep"] > 0:
            dumps = sorted(glob.glob(os.path.join(dump_dir, "*-Full-API-Dump.json")), key=version_key)
            for old in dumps[:-o["keep"]]:
                emit(f"🧹 removing {os.path.basename(old)}")
                os.remove(old)

        emit()
        emit(f"🏁 Done. Version: {win_version}")
        emit(f"   Dump: {dump_file}")
        return audit_status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
