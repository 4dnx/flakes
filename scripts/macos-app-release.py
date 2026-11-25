# Select a WhatsApp, Telegram or Rex release from its official Sparkle feed:
# the newest by version and build whose download is at the URL the vendor
# uses for it. Prints its version, build, URL and Sparkle EdDSA signature
# (edSignature, empty when the feed has none) as JSON.
# python3 macos-app-release.py {whatsapp,telegram,rex-app} < feed.xml
import json
import re
import sys
import xml.etree.ElementTree as ET

name = sys.argv[1]
ns = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
releases = []
for item in ET.parse(sys.stdin).findall(".//item"):
    enclosure = item.find("enclosure")
    if enclosure is None or enclosure.get("forbidden") == "true":
        continue
    version = item.findtext(ns + "shortVersionString") or enclosure.get(ns + "shortVersionString", "")
    build = item.findtext(ns + "version") or enclosure.get(ns + "version", "")
    url = enclosure.get("url", "")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,3}", version) or not re.fullmatch(r"[0-9]{1,16}", build):
        continue
    expected = {
        "whatsapp": f"https://web.whatsapp.com/desktop/mac_native/release/?version=2.{version}&extension=zip&configuration=Release&branch=master&is_buck=true",
        "telegram": f"https://osx.telegram.org/updates/Telegram-{version}.{build}.app.zip",
        "rex-app": f"https://blob.superlogical.com/public/rex-app/preview/Rex-{version}-{build}.dmg",
    }[name]
    if url != expected:
        continue
    signature = enclosure.get(ns + "edSignature", "")
    releases.append((tuple(map(int, version.split("."))), int(build), version, build, url, signature))
if not releases:
    sys.exit(f"{name}: no valid stable release in official feed")
# Telegram's pubDate values are unreliable; compare versions and build numbers.
_, _, version, build, url, signature = max(releases)
print(json.dumps({"version": version, "build": build, "url": url, "edSignature": signature}))
