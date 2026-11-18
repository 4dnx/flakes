# Checks Apple code signatures without macOS, for downloads whose integrity
# rests on them. Needs rcodesign and openssl on PATH; standard library only.
#   python3 codesign-check.py APPLE_ROOT_CA TEAM_ID PATH...
# Each PATH is a Mach-O file or an .app / .framework bundle.
#
# A Mach-O file: every slice's code pages match its code directory (rcodesign
# verify), and its CMS signature over that code directory is by a Developer
# ID Application certificate of TEAM_ID chaining to APPLE_ROOT_CA.
#
# A bundle: its main executable as above; its Info.plist and its seal
# (_CodeSignature/CodeResources) match the hashes in that signed code
# directory; every file the seal lists matches its hash, every symlink its
# target, and every nested bundle or Mach-O is checked the same way and
# matches the cdhash the seal records; and no file is left outside the seal
# except the ones Apple's rules omit (and a stapled notarization ticket).
#
# After numtide/llm-agents.nix's codesignCheckHook (Mach-O signatures).
import hashlib
import os
import plistlib
import re
import struct
import subprocess
import sys
import tempfile

ROOT_CA, TEAM = sys.argv[1], sys.argv[2]
if not re.fullmatch(r"[A-Z0-9]{10}", TEAM):
    sys.exit(f"codesign-check: bad team ID {TEAM!r}")

CD_MAGIC = 0xFADE0C02
HASHES = {1: hashlib.sha1, 2: hashlib.sha256}
# Code directory special slots.
INFO_SLOT, RESOURCES_SLOT = 1, 3


class Bad(Exception):
    pass


def run(*args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode != 0:
        raise Bad(f"{' '.join(args[:3])}: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def slices(path):
    """Slice indexes for rcodesign's --universal-index; None for a thin file."""
    with open(path, "rb") as f:
        head = f.read(8)
    if len(head) < 8:
        raise Bad(f"{path}: not a Mach-O file")
    magic = head[:4].hex()
    if magic in ("feedface", "feedfacf", "cefaedfe", "cffaedfe"):
        return [None]
    if magic in ("cafebabe", "cafebabf"):
        count = struct.unpack(">I", head[4:8])[0]
        if not 1 <= count <= 16:
            raise Bad(f"{path}: implausible universal binary")
        return list(range(count))
    raise Bad(f"{path}: not a Mach-O file")


def code_directory(path, index):
    """The one code directory of a slice, which its CMS signature covers."""
    flag = [] if index is None else ["--universal-index", str(index)]
    blob = run("rcodesign", "extract", *flag, "signature-raw", path)
    if len(blob) < 12 or struct.unpack_from(">I", blob)[0] != 0xFADE0CC0:
        raise Bad(f"{path}: no embedded signature")
    count = struct.unpack_from(">I", blob, 8)[0]
    cds = []
    for i in range(count):
        kind, offset = struct.unpack_from(">II", blob, 12 + 8 * i)
        magic, length = struct.unpack_from(">II", blob, offset)
        if magic == CD_MAGIC:
            cds.append((kind, blob[offset : offset + length]))
    # With alternate code directories, the cdhashes the seal records would
    # rest on a CMS attribute this script doesn't read; refuse rather than
    # trust them unchecked.
    if [kind for kind, _ in cds] != [0]:
        raise Bad(f"{path}: expected exactly one code directory, found kinds {[hex(k) for k, _ in cds]}")
    cd = cds[0][1]
    if cd != run("rcodesign", "extract", *flag, "code-directory-raw", path):
        raise Bad(f"{path}: code directory mismatch")
    return cd


def check_cms(path, index):
    """The CMS signature covers the code directory and names TEAM's Developer ID."""
    flag = [] if index is None else ["--universal-index", str(index)]
    with tempfile.TemporaryDirectory() as tmp:
        cms, cd, signer = (os.path.join(tmp, n) for n in ("cms.pem", "cd.bin", "signer.pem"))
        with open(cms, "wb") as f:
            f.write(run("rcodesign", "extract", *flag, "cms-pem", path))
        with open(cd, "wb") as f:
            f.write(run("rcodesign", "extract", *flag, "code-directory-raw", path))
        # Apple marks its Developer ID extension critical, which openssl
        # rejects unless told to ignore it. The certificate's validity period
        # isn't checked: a pinned download has to keep building after it
        # expires.
        run("openssl", "cms", "-verify", "-binary", "-inform", "PEM", "-in", cms, "-content", cd,
            "-CAfile", ROOT_CA, "-purpose", "any", "-ignore_critical", "-no_check_time",
            "-out", os.devnull, "-signer", signer)
        subject = run("openssl", "x509", "-in", signer, "-noout", "-subject", "-nameopt", "RFC2253").decode()
    if "CN=Developer ID Application:" not in subject or f"OU={TEAM}," not in subject:
        raise Bad(f"{path}: signed by {subject.strip()!r}, expected team {TEAM}")


def special_slot(cd, slot):
    """The hash a code directory records for a special slot, or None."""
    hash_offset, n_special = struct.unpack_from(">II", cd, 16)[0], struct.unpack_from(">I", cd, 24)[0]
    size = cd[36]
    if slot > n_special:
        return None
    value = cd[hash_offset - slot * size : hash_offset - (slot - 1) * size]
    return None if value == bytes(size) else value


def digest(cd, data):
    return HASHES[cd[37]](data).digest()


def check_macho(path):
    """Returns the slices' code directories, keyed by cdhash."""
    run("rcodesign", "verify", path)
    cds = {}
    for index in slices(path):
        check_cms(path, index)
        cd = code_directory(path, index)
        cds[digest(cd, cd)[:20]] = cd
    return cds


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.digest()


def bundle_layout(root):
    """(content dir, Info.plist, main executable, top-level paths to skip)."""
    if os.path.isdir(os.path.join(root, "Contents")):
        if os.listdir(root) != ["Contents"]:
            raise Bad(f"{root}: unexpected entries beside Contents")
        content = os.path.join(root, "Contents")
        info = os.path.join(content, "Info.plist")
        exe_dir = "MacOS"
    elif os.path.islink(os.path.join(root, "Versions", "Current")):
        current = os.readlink(os.path.join(root, "Versions", "Current"))
        if "/" in current or sorted(os.listdir(os.path.join(root, "Versions"))) != sorted([current, "Current"]):
            raise Bad(f"{root}: unexpected Versions layout")
        # The framework's top level holds only symlinks into the current version.
        for name in os.listdir(root):
            entry = os.path.join(root, name)
            if name != "Versions" and not (os.path.islink(entry) and os.readlink(entry) == f"Versions/Current/{name}"):
                raise Bad(f"{root}: unsealed top-level entry {name!r}")
        content = os.path.join(root, "Versions", current)
        info = os.path.join(content, "Resources", "Info.plist")
        exe_dir = ""
    else:
        raise Bad(f"{root}: not an app or framework bundle")
    with open(info, "rb") as f:
        exe = os.path.join(exe_dir, plistlib.load(f)["CFBundleExecutable"])
    return content, info, exe


def check_bundle(root):
    content, info, exe = bundle_layout(root)
    seal_path = os.path.join(content, "_CodeSignature", "CodeResources")
    cds = check_macho(os.path.join(content, exe))
    with open(info, "rb") as f:
        info_data = f.read()
    with open(seal_path, "rb") as f:
        seal_data = f.read()
    for cd in cds.values():
        if special_slot(cd, INFO_SLOT) != digest(cd, info_data):
            raise Bad(f"{info}: doesn't match the signed code directory")
        if special_slot(cd, RESOURCES_SLOT) != digest(cd, seal_data):
            raise Bad(f"{seal_path}: doesn't match the signed code directory")
    seal = plistlib.loads(seal_data)
    files, rules = seal["files2"], seal.get("rules2", {})
    omit = [re.compile(p) for p, r in rules.items() if isinstance(r, dict) and r.get("omit")]
    nested = set()
    for rel, entry in files.items():
        path = os.path.join(content, rel)
        if not isinstance(entry, dict):
            raise Bad(f"{path}: unsupported seal entry")
        if "cdhash" in entry:
            nested.add(rel)
            found = check_bundle(path) if os.path.isdir(path) and not os.path.islink(path) else check_macho(path)
            if entry["cdhash"] not in found:
                raise Bad(f"{path}: cdhash doesn't match its bundle's seal")
        elif "symlink" in entry:
            if not os.path.islink(path) or os.readlink(path) != entry["symlink"]:
                raise Bad(f"{path}: symlink doesn't match its bundle's seal")
        elif "hash2" in entry:
            if not os.path.lexists(path) and entry.get("optional"):
                continue
            if os.path.islink(path) or not os.path.isfile(path) or sha256(path) != entry["hash2"]:
                raise Bad(f"{path}: doesn't match its bundle's seal")
        else:
            raise Bad(f"{path}: unsupported seal entry {sorted(entry)}")
    # Nothing outside the seal: the main executable and Info.plist are sealed
    # by the code directory, Contents/CodeResources is a stapled notarization
    # ticket, and nested code by its own seal.
    unsealed_ok = {exe, os.path.relpath(info, content), "CodeResources"}
    for dirpath, dirnames, filenames in os.walk(content):
        rel_dir = os.path.relpath(dirpath, content)
        rel_dir = "" if rel_dir == "." else rel_dir + "/"
        if rel_dir == "_CodeSignature/":
            dirnames[:] = []
            continue
        leaves = list(filenames)
        for d in list(dirnames):
            if os.path.islink(os.path.join(dirpath, d)) or rel_dir + d in nested:
                dirnames.remove(d)
                leaves.append(d)
        for name in leaves:
            rel = rel_dir + name
            if rel in files or rel in unsealed_ok or any(p.search(rel) for p in omit):
                continue
            raise Bad(f"{os.path.join(content, rel)}: not covered by its bundle's seal")
    return cds


failed = False
for target in sys.argv[3:]:
    try:
        if os.path.isdir(target):
            check_bundle(target)
        else:
            check_macho(target)
        print(f"codesign-check: {target}: intact, Developer ID of team {TEAM}")
    except (Bad, OSError, KeyError, struct.error, plistlib.InvalidFileException) as e:
        print(f"codesign-check: {e}", file=sys.stderr)
        failed = True
sys.exit(1 if failed else 0)
