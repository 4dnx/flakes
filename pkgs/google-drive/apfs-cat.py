# Copies one file out of an APFS volume image (the first volume; not
# encrypted, the file not compressed), without macOS or mounting it:
#   python3 apfs-cat.py IMAGE PATH OUT
# Google Drive's dmg is APFS, which undmg and 7-Zip can't read. dissect.apfs
# reads the file system; the file's extents are followed here by its data
# stream id, as dissect.apfs' own stream looks them up by inode id and skips
# the rest of an extent read from its middle, which leaves copied (cloned)
# files short.
import sys

from dissect.apfs import APFS
from dissect.apfs.stream import FileStream

image, path, out_path = sys.argv[1:4]
with open(image, "rb") as fh:
    volume = APFS(fh).volumes[0]
    if volume.is_encrypted:
        sys.exit(f"{image}: encrypted volume")
    node = volume.get(path)
    if node.is_compressed():
        sys.exit(f"{image}: {path} is compressed")
    stream = FileStream(volume, node.private_id, node.size)
    block = volume.container.block_size
    pos, size = 0, node.size
    with open(out_path, "wb") as out:
        while pos < size:
            logical, physical, length, _ = stream._lookup(pos)
            if not logical <= pos < logical + length:
                sys.exit(f"{image}: {path} has no extent at {pos}")
            data = volume.container._read_block(physical, length // block)[pos - logical :]
            data = data[: size - pos]
            out.write(data)
            pos += len(data)
