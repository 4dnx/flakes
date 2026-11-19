# Install check for a macOS app bundle, without opening it: the executable
# Info.plist names is there, and, given a version, the bundle says it is that
# version. Optional BUILD and ARCH also validate the bundle build and Mach-O
# CPU slice. python3 check-app.py APP [VERSION [BUILD [ARCH]]]
import os
import plistlib
import struct
import sys

app = sys.argv[1]
version = sys.argv[2] if len(sys.argv) > 2 else ""
# lstrip: some apps ship an XML plist with whitespace before <?xml, which
# macOS accepts and plistlib doesn't.
with open(os.path.join(app, "Contents", "Info.plist"), "rb") as f:
    info = plistlib.loads(f.read().lstrip())
exe = os.path.join(app, "Contents", "MacOS", info["CFBundleExecutable"])
if not os.access(exe, os.X_OK):
    sys.exit(f"{app}: {exe} is not an executable")
found = info.get("CFBundleShortVersionString", "")
if version and found != version:
    sys.exit(f"{app}: bundle version {found!r}, expected {version!r}")
build = sys.argv[3] if len(sys.argv) > 3 else ""
if build and str(info.get("CFBundleVersion", "")) != build:
    sys.exit(f"{app}: bundle build does not match {build!r}")
if len(sys.argv) > 4:
    arch = sys.argv[4]
    cpu = {"arm64": 0x0100000C, "x86_64": 0x01000007}[arch]
    with open(exe, "rb") as f:
        header = f.read(4096)
    magic = header[:4].hex()
    if magic in ("cafebabe", "cafebabf", "bebafeca", "bfbafeca"):
        endian = ">" if magic.startswith("cafe") else "<"
        count = struct.unpack_from(endian + "I", header, 4)[0]
        stride = 32 if magic in ("cafebabf", "bfbafeca") else 20
        if not 1 <= count <= 64:
            sys.exit(f"{app}: invalid Mach-O architecture count")
        cpus = [struct.unpack_from(endian + "I", header, 8 + stride * i)[0] for i in range(count)]
    elif magic in ("feedface", "feedfacf", "cefaedfe", "cffaedfe"):
        endian = ">" if magic.startswith("feed") else "<"
        cpus = [struct.unpack_from(endian + "I", header, 4)[0]]
    else:
        sys.exit(f"{app}: executable is not Mach-O")
    if cpu not in cpus:
        sys.exit(f"{app}: executable has no native {arch} slice")
print(f"{app}: {info['CFBundleExecutable']} {found}")
