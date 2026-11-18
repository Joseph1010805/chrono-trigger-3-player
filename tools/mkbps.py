"""Create a BPS patch.  usage: mkbps.py source.sfc target.sfc out.bps"""
import sys, zlib, struct


def vint(n):
    out = bytearray()
    while True:
        x = n & 0x7F
        n >>= 7
        if n == 0:
            out.append(0x80 | x)
            return bytes(out)
        out.append(x)
        n -= 1


def make(src, tgt):
    out = bytearray(b'BPS1')
    out += vint(len(src)) + vint(len(tgt)) + vint(0)
    i, n = 0, len(tgt)
    while i < n:
        same = i < len(src) and src[i] == tgt[i]
        j = i
        while j < n and (j < len(src) and src[j] == tgt[j]) == same:
            j += 1
        # don't break a literal run for a tiny match (cheaper as literal)
        if same and j - i < 4 and j < n:
            same = False
        length = j - i
        if same:
            out += vint(((length - 1) << 2) | 0)          # SourceRead
        else:
            out += vint(((length - 1) << 2) | 1)          # TargetRead
            out += tgt[i:j]
        i = j
    out += struct.pack('<I', zlib.crc32(src))
    out += struct.pack('<I', zlib.crc32(tgt))
    out += struct.pack('<I', zlib.crc32(bytes(out)))
    return bytes(out)


if __name__ == '__main__':
    s = open(sys.argv[1], 'rb').read()
    t = open(sys.argv[2], 'rb').read()
    p = make(s, t)
    open(sys.argv[3], 'wb').write(p)
    print('wrote', sys.argv[3], len(p), 'bytes')
