#!/usr/bin/env python3
"""Convert a PNG to an uncompressed 32-bit TGA — for WoW textures / a .toc `## IconTexture`.

WoW can't load PNG: textures and `## IconTexture` need **uncompressed TGA** (or BLP), ideally
power-of-two. This tool has NO Pillow/ImageMagick dependency (neither is reliably available here, and
`sips` only writes RLE-compressed TGA, which WoW rejects). It uses `sips` (macOS) to resize to a
power-of-two PNG, then a dependency-free PNG decoder + uncompressed-TGA encoder.

Usage:
    tools/png-to-tga.py <in.png> <out.tga> [size]      # size default 256 (square, power-of-two)

Output is bottom-origin (descriptor 0x08, rows bottom-to-top) — the WoW-canonical orientation
(WO-048; WoW rejects top-origin 0x28 files). If a texture somehow renders upside-down, flip back to
0x28 + top-to-bottom rows (see the memory note `png-to-wow-tga`).
"""
import sys
import os
import zlib
import struct
import subprocess
import tempfile


def resize_png(src, size):
    fd, tmp = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    subprocess.run(
        ["sips", "-z", str(size), str(size), "-s", "format", "png", src, "--out", tmp],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return tmp


def decode_png(path):
    d = open(path, "rb").read()
    assert d[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    i = 8
    W = H = ct = None
    idat = bytearray()
    while i < len(d):
        ln = struct.unpack(">I", d[i : i + 4])[0]
        typ = d[i + 4 : i + 8]
        data = d[i + 8 : i + 8 + ln]
        i += 12 + ln
        if typ == b"IHDR":
            W, H, bd, ct, comp, filt, interlace = struct.unpack(">IIBBBBB", data)
            assert bd == 8 and interlace == 0 and ct in (2, 6), f"unsupported PNG (bd={bd} ct={ct})"
        elif typ == b"IDAT":
            idat += data
        elif typ == b"IEND":
            break
    raw = zlib.decompress(bytes(idat))
    ch = 4 if ct == 6 else 3
    stride = W * ch
    out = bytearray()
    prev = bytearray(stride)

    def paeth(a, b, c):
        p = a + b - c
        pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
        return a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)

    pos = 0
    for _y in range(H):
        f = raw[pos]
        pos += 1
        line = bytearray(raw[pos : pos + stride])
        pos += stride
        if f == 1:
            for x in range(ch, stride):
                line[x] = (line[x] + line[x - ch]) & 255
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = line[x - ch] if x >= ch else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x - ch] if x >= ch else 0
                c = prev[x - ch] if x >= ch else 0
                line[x] = (line[x] + paeth(a, prev[x], c)) & 255
        out += line
        prev = line
    return W, H, ch, bytes(out)


def write_tga(path, W, H, ch, px):
    # Uncompressed truecolor (2), 32bpp, BOTTOM-origin + 8 alpha bits (descriptor 0x08 — origin
    # bottom-left, the WoW-canonical orientation). WoW's loader rejects top-origin (0x28) files, so both
    # the AddOns-list icon and header texture fail to load (WO-048). The PNG decodes top-to-bottom, so we
    # write the rows in REVERSE (bottom row first). Pixels are BGRA.
    hdr = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 0x08)
    stride = W * ch
    body = bytearray()
    for y in range(H - 1, -1, -1):
        row = px[y * stride : (y + 1) * stride]
        for p in range(0, stride, ch):
            r, g, b = row[p], row[p + 1], row[p + 2]
            a = row[p + 3] if ch == 4 else 255
            body += bytes((b, g, r, a))
    open(path, "wb").write(hdr + bytes(body))


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    src, dst = sys.argv[1], sys.argv[2]
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    tmp = resize_png(src, size)
    try:
        W, H, ch, px = decode_png(tmp)
        write_tga(dst, W, H, ch, px)
        print(f"wrote {dst} ({W}x{H}, {ch}ch -> 32-bit uncompressed TGA)")
    finally:
        os.remove(tmp)


if __name__ == "__main__":
    main()
