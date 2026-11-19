# Google Drive's own copy of lib/pkg-signature-check.py, which only the Office
# apps use: kept apart so that a change for one doesn't rebuild the other (the
# Office apps are a ~1.4 GB download each).
# Checks the signature of a macOS flat installer package (.pkg, a xar
# archive) without macOS. Needs openssl on PATH; standard library only.
#   python3 pkg-signature-check.py APPLE_ROOT_CA TEAM_ID PKG [--bundle ID] [--cat PATH]
#
# The archive's table of contents (TOC) matches the checksum stored in its
# heap; that checksum carries an RSA signature and a CMS signature, both by
# the same Developer ID Installer certificate of TEAM_ID chaining to
# APPLE_ROOT_CA; and every file in the archive matches the checksum the TOC
# records for it. Installer checks the same before it trusts a package.
#
# Then, only once all of that holds:
#   --bundle ID  prints "CFBundleShortVersionString CFBundleVersion" of that
#                bundle, as the package's Distribution lists it;
#   --cat PATH   writes the archived file at PATH (such as
#                Component.pkg/Payload) to stdout, as stored: a component's
#                Payload is a gzip-compressed cpio archive.
import argparse
import hashlib
import os
import re
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zlib

parser = argparse.ArgumentParser()
parser.add_argument("root_ca")
parser.add_argument("team")
parser.add_argument("pkg")
parser.add_argument("--bundle")
parser.add_argument("--cat")
args = parser.parse_args()
PKG = args.pkg
if not re.fullmatch(r"[A-Z0-9]{10}", args.team):
    sys.exit(f"pkg-signature-check: bad team ID {args.team!r}")

HASHES = {"sha1": hashlib.sha1, "sha256": hashlib.sha256, "sha512": hashlib.sha512}


def fail(message):
    sys.exit(f"{PKG}: {message}")


def run(*cmd, data=None):
    result = subprocess.run(cmd, input=data, capture_output=True)
    if result.returncode != 0:
        fail(f"{' '.join(cmd[:3])}: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def pem(b64):
    body = "".join(b64.split())
    lines = [body[i : i + 64] for i in range(0, len(body), 64)]
    return "-----BEGIN CERTIFICATE-----\n" + "\n".join(lines) + "\n-----END CERTIFICATE-----\n"


def certificates(element):
    ns = "{http://www.w3.org/2000/09/xmldsig#}"
    return [c.text or "" for c in element.iter(ns + "X509Certificate")]


def files(parent, prefix=""):
    """(path, <file> element) for every entry, by its path in the archive."""
    for entry in parent.findall("file"):
        name = entry.findtext("name") or ""
        if not name or "/" in name or name in (".", ".."):
            fail(f"bad file name {name!r}")
        path = prefix + name
        yield path, entry
        yield from files(entry, path + "/")


with open(PKG, "rb") as f:
    header = f.read(28)
    if len(header) < 28:
        fail("not a xar archive")
    magic, header_size, _, toc_length, _, _ = struct.unpack(">4sHHQQI", header)
    if magic != b"xar!" or header_size < 28:
        fail("not a xar archive")
    f.seek(header_size)
    toc_raw = f.read(toc_length)
    heap = header_size + toc_length
    try:
        toc = ET.fromstring(zlib.decompress(toc_raw)).find("toc")
    except (zlib.error, ET.ParseError) as e:
        fail(f"unreadable table of contents: {e}")
    if toc is None:
        fail("no table of contents")

    def heap_range(element):
        """(offset, length) in the file of a heap entry the TOC points to."""
        offset = int(element.findtext("offset") or -1)
        length = int(element.findtext("length") or element.findtext("size") or -1)
        if offset < 0 or length < 0:
            fail("bad heap offset")
        return heap + offset, length

    def read(element):
        offset, length = heap_range(element)
        f.seek(offset)
        data = f.read(length)
        if len(data) != length:
            fail("heap entry past the end of the archive")
        return data

    def chunks(element):
        offset, left = heap_range(element)
        f.seek(offset)
        while left:
            chunk = f.read(min(left, 1 << 20))
            if not chunk:
                fail("heap entry past the end of the archive")
            left -= len(chunk)
            yield chunk

    # The TOC's checksum, which both signatures sign.
    checksum = toc.find("checksum")
    style = checksum.get("style") if checksum is not None else None
    if style not in HASHES:
        fail(f"unsupported TOC checksum {style!r}")
    toc_hash = HASHES[style](toc_raw).digest()
    if read(checksum) != toc_hash:
        fail("TOC does not match its checksum")

    rsa = toc.find("signature")
    cms = toc.find("x-signature")
    if rsa is None or rsa.get("style") != "RSA" or cms is None or cms.get("style") != "CMS":
        fail("expected an RSA and a CMS signature")

    with tempfile.TemporaryDirectory() as tmp:
        path = lambda name: os.path.join(tmp, name)  # noqa: E731
        with open(path("hash"), "wb") as out:
            out.write(toc_hash)
        # BER, padded to its reserved size; openssl reads up to its end.
        with open(path("cms"), "wb") as out:
            out.write(read(cms))
        # Apple marks its Developer ID extension critical, which openssl
        # rejects unless told to ignore it. The certificates' validity period
        # isn't checked: a pinned download has to keep building after they
        # expire.
        run("openssl", "cms", "-verify", "-binary", "-inform", "DER", "-in", path("cms"),
            "-content", path("hash"), "-CAfile", args.root_ca, "-purpose", "any",
            "-ignore_critical", "-no_check_time", "-out", os.devnull, "-signer", path("signer.pem"))
        signer = run("openssl", "x509", "-in", path("signer.pem"), "-outform", "DER")
        subject = run("openssl", "x509", "-in", path("signer.pem"), "-noout", "-subject",
                      "-nameopt", "RFC2253").decode()
        if "CN=Developer ID Installer:" not in subject or f"OU={args.team}," not in subject:
            fail(f"signed by {subject.strip()!r}, expected a Developer ID Installer of team {args.team}")

        # The RSA signature, by the same certificate.
        leaf = certificates(rsa)
        if not leaf:
            fail("RSA signature without a certificate")
        if run("openssl", "x509", "-outform", "DER", data=pem(leaf[0]).encode()) != signer:
            fail("RSA and CMS signatures are by different certificates")
        with open(path("rsa"), "wb") as out:
            out.write(read(rsa))
        with open(path("key.pem"), "wb") as out:
            out.write(run("openssl", "x509", "-in", path("signer.pem"), "-noout", "-pubkey"))
        run("openssl", "pkeyutl", "-verify", "-pubin", "-inkey", path("key.pem"), "-pkeyopt",
            f"digest:{style}", "-in", path("hash"), "-sigfile", path("rsa"))

    # Every file's archived data, against the checksum the signed TOC records.
    entries = {}
    for name, entry in files(toc):
        if name in entries:
            fail(f"{name}: listed twice")
        entries[name] = entry
        data = entry.find("data")
        if data is None:
            continue
        archived = data.find("archived-checksum")
        if archived is None or archived.get("style") not in HASHES:
            fail(f"{name}: no supported archived checksum")
        h = HASHES[archived.get("style")]()
        for chunk in chunks(data):
            h.update(chunk)
        if h.hexdigest() != (archived.text or "").strip().lower():
            fail(f"{name}: does not match its checksum")

    signer_name = re.search(r"CN=([^,]+)", subject).group(1)
    print(f"{PKG}: signature by {signer_name} verified", file=sys.stderr)

    def data_of(name):
        entry = entries.get(name)
        data = entry.find("data") if entry is not None else None
        if data is None or entry.findtext("type") != "file":
            fail(f"no file {name}")
        encoding = data.find("encoding")
        return data, encoding.get("style") if encoding is not None else "application/octet-stream"

    if args.bundle:
        data, encoding = data_of("Distribution")
        raw = read(data)
        if encoding in ("application/x-gzip", "application/zlib"):
            raw = zlib.decompress(raw, zlib.MAX_WBITS | 32)
        elif encoding != "application/octet-stream":
            fail(f"Distribution: unsupported encoding {encoding}")
        bundles = [b for b in ET.fromstring(raw).iter("bundle") if b.get("id") == args.bundle]
        versions = {(b.get("CFBundleShortVersionString"), b.get("CFBundleVersion")) for b in bundles}
        if len(versions) != 1 or None in next(iter(versions)):
            fail(f"Distribution lists no single version for {args.bundle}")
        print(*next(iter(versions)))

    if args.cat:
        data, encoding = data_of(args.cat)
        if encoding != "application/octet-stream":
            fail(f"{args.cat}: stored with {encoding}, not as is")
        out = sys.stdout.buffer
        for chunk in chunks(data):
            out.write(chunk)
        out.flush()
