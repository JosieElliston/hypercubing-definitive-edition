import struct, sys
path, mode = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "show"
b = bytearray(open(path, "rb").read())
pe = struct.unpack_from("<I", b, 0x3C)[0]
nsec = struct.unpack_from("<H", b, pe + 6)[0]
optsz = struct.unpack_from("<H", b, pe + 20)[0]
opt = pe + 24
magic = struct.unpack_from("<H", b, opt)[0]
dd = opt + (96 if magic == 0x10B else 112)
cli_rva, cli_sz = struct.unpack_from("<II", b, dd + 14 * 8)
sec = opt + optsz
def rva2off(rva):
    for i in range(nsec):
        s = sec + i * 40
        vsz, va, rsz, raw = struct.unpack_from("<IIII", b, s + 8)
        if va <= rva < va + max(vsz, rsz):
            return rva - va + raw
    raise SystemExit("rva not found")
off = rva2off(cli_rva) + 16
flags = struct.unpack_from("<I", b, off)[0]
print(f"magic={magic:#x} machine={struct.unpack_from('<H', b, pe+4)[0]:#x} clrflags={flags:#x} (ILONLY={flags&1} 32BITREQ={(flags>>1)&1} 32BITPREF={(flags>>17)&1})")
if mode == "anycpu":
    flags &= ~0x2 & ~0x20000
    struct.pack_into("<I", b, off, flags)
    open(path, "wb").write(b)
    print(f"patched -> {flags:#x}")
