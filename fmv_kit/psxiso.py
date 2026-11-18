"""List / extract files from a MODE2/2352 PlayStation disc image.
usage: psxiso.py image.bin list
       psxiso.py image.bin raw <path-substring> out.str   (raw 2352-byte sectors, for STR video)
"""
import sys, struct

SEC = 2352


def sector(f, lba):
    f.seek(lba * SEC)
    return f.read(SEC)


def user(f, lba):
    s = sector(f, lba)
    return s[24:24 + 2048]          # Mode 2 Form 1 user data


def walk(f, lba, size, path, out):
    data = b''
    for i in range((size + 2047) // 2048):
        data += user(f, lba + i)
    o = 0
    while o < len(data):
        n = data[o]
        if n == 0:
            o = ((o // 2048) + 1) * 2048
            continue
        rec = data[o:o + n]
        ext = struct.unpack_from('<I', rec, 2)[0]
        ln = struct.unpack_from('<I', rec, 10)[0]
        flags = rec[25]
        nl = rec[32]
        name = rec[33:33 + nl]
        o += n
        if name in (b'\x00', b'\x01'):
            continue
        name = name.decode('ascii', 'replace').split(';')[0]
        p = path + '/' + name
        if flags & 2:
            walk(f, ext, ln, p, out)
        else:
            out.append((p, ext, ln))


def files(f):
    pvd = user(f, 16)
    root = pvd[156:156 + 34]
    ext = struct.unpack_from('<I', root, 2)[0]
    ln = struct.unpack_from('<I', root, 10)[0]
    out = []
    walk(f, ext, ln, '', out)
    return out


if __name__ == '__main__':
    f = open(sys.argv[1], 'rb')
    fl = files(f)
    if sys.argv[2] == 'list':
        for p, e, l in fl:
            print('%-40s lba=%7d size=%10d' % (p, e, l))
    elif sys.argv[2] == 'raw':
        for p, e, l in fl:
            if sys.argv[3].lower() in p.lower():
                # STR files are Form 2: the directory size counts 2048 per sector
                n = (l + 2047) // 2048
                with open(sys.argv[4], 'wb') as o:
                    for i in range(n):
                        o.write(sector(f, e + i))
                print('wrote', p, n, 'sectors')
                break
