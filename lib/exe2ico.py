"""Extract the first icon group from a Windows PE file into a .ico file.

usage: python3 -I exe2ico.py <in.exe> <out.ico>
Exits 1 if the exe has no icon.
"""
import struct
import sys

RT_ICON, RT_GROUP_ICON = 3, 14


def main(src, dst):
    b = open(src, "rb").read()
    pe = struct.unpack_from("<I", b, 0x3C)[0]
    nsec = struct.unpack_from("<H", b, pe + 6)[0]
    optsz = struct.unpack_from("<H", b, pe + 20)[0]
    opt = pe + 24
    magic = struct.unpack_from("<H", b, opt)[0]
    dd = opt + (96 if magic == 0x10B else 112)
    rsrc_rva = struct.unpack_from("<I", b, dd + 2 * 8)[0]
    secs = [struct.unpack_from("<8sIIII", b, opt + optsz + i * 40) for i in range(nsec)]

    def off(rva):
        for _, vsz, va, rawsz, raw in secs:
            if va <= rva < va + max(vsz, rawsz):
                return rva - va + raw
        raise ValueError("rva not in any section")

    base = off(rsrc_rva)

    def entries(dir_off):
        named, ids = struct.unpack_from("<HH", b, dir_off + 12)
        for i in range(named + ids):
            name, target = struct.unpack_from("<II", b, dir_off + 16 + i * 8)
            yield name, target

    def leaf(target):
        # Descend through subdirectories (name, language) to the first data entry.
        while target & 0x80000000:
            target = next(entries(base + (target & 0x7FFFFFFF)))[1]
        rva, size = struct.unpack_from("<II", b, base + target)
        return b[off(rva):off(rva) + size]

    types = dict(entries(base))
    if RT_GROUP_ICON not in types or RT_ICON not in types:
        sys.exit(1)
    icons = {name: t for name, t in entries(base + (types[RT_ICON] & 0x7FFFFFFF))}
    group = leaf(next(entries(base + (types[RT_GROUP_ICON] & 0x7FFFFFFF)))[1])
    count = struct.unpack_from("<H", group, 4)[0]
    images, header = [], bytearray(group[:6])
    for i in range(count):
        w, h, cc, r, planes, bpp, size, icon_id = struct.unpack_from("<BBBBHHIH", group, 6 + i * 14)
        images.append((w, h, cc, r, planes, bpp, leaf(icons[icon_id])))
    data_off = 6 + 16 * count
    out = bytearray(header)
    blobs = b""
    for w, h, cc, r, planes, bpp, data in images:
        out += struct.pack("<BBBBHHII", w, h, cc, r, planes, bpp, len(data), data_off + len(blobs))
        blobs += data
    open(dst, "wb").write(bytes(out) + blobs)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
