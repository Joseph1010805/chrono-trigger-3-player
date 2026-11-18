"""Build the MSU1 data file (and PCM tracks) for the Chrono Trigger MSU-1
all-FMV player that is already in the ROM (qwertymodo's beta, CD:FA00).

Format (read from the player):
  "MSU1" + 4-byte offsets, one per video index (index n plays track 100+n)
  video: u16 frame count, then a VRAM stream written from word $0C00 on,
  interleaved with 512-byte palettes:
     frame0 ($A000) + frame1[:$40] + pal0,
     then per frame k>=1: frame k[$40:] + frame k+1[:$40] + pal k
  frame = 32x32 tilemap ($800 bytes) + 608 8bpp tiles ($9800 bytes)
  shown at 15 fps (4 screen frames each), BG mode 3, lines ~37..188 visible:
  tilemap rows 5..23 show the 19 tile rows of the 256x152 picture.

usage: encode.py out_dir name1.str [name2.str ...]   (in index order)
"""
import sys, os, struct, subprocess
import numpy as np
from PIL import Image

W, H = 256, 152
ROWS = H // 8            # 19
R0 = 5                   # tilemap row of picture row 0
FRAME = 0xA000
HEAD = 0x40
SPEED = 60.0988 / 4 / 15.0   # the player runs a hair faster than 15 fps

# crop the PS1 letterbox (320x178 at y=30) and fill the whole 256x152 strip
# (274x152, a few pixels off each side)
VF = 'crop=320:178:0:30,scale=274:152:flags=lanczos,crop=256:152:9:0'


def frames(path):
    p = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', path, '-vf', VF,
                          '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                         stdout=subprocess.PIPE)
    n = W * H * 3
    while True:
        b = p.stdout.read(n)
        if len(b) < n:
            break
        yield np.frombuffer(b, np.uint8).reshape(H, W, 3)
    p.wait()


def snes_frame(rgb):
    """-> (frame bytes $A000, palette bytes $200)"""
    # quantize in 15-bit colour space so the palette is exact on the SNES
    q = (rgb >> 3) << 3
    q = q.copy()
    q[:3] = 0                # first and last 3 lines black: the player switches
    q[-3:] = 0               # the screen on/off mid-line around them
    im = Image.fromarray(q, 'RGB').quantize(colors=256, method=Image.Quantize.MEDIANCUT,
                                            dither=Image.Dither.NONE)
    idx = np.asarray(im, np.uint8)
    pal = im.getpalette()[:768]
    pal += [0] * (768 - len(pal))
    pal = np.array(pal, np.uint16).reshape(256, 3) >> 3
    bgr = (pal[:, 0] | (pal[:, 1] << 5) | (pal[:, 2] << 10)).astype('<u2').tobytes()
    # tiles: (19, 32, 8, 8) -> 8bpp planar
    t = idx.reshape(ROWS, 8, 32, 8).transpose(0, 2, 1, 3).reshape(ROWS * 32, 8, 8)
    bits = np.unpackbits(t[..., None], axis=-1, bitorder='little')   # (n,8,8,8 planes)
    planes = np.packbits(bits, axis=2, bitorder='big')[:, :, 0, :]    # (n, 8 rows, 8 planes)
    out = np.empty((ROWS * 32, 4, 8, 2), np.uint8)                     # pairs of planes
    for pair in range(4):
        out[:, pair, :, 0] = planes[:, :, 2 * pair]
        out[:, pair, :, 1] = planes[:, :, 2 * pair + 1]
    chr_ = out.tobytes()
    # tilemap: picture rows at tilemap rows R0..; every other row shows the
    # first picture row upside down, so the one line of it that peeks out above
    # the strip is picture line 0 (black)
    tm = np.zeros((32, 32), '<u2')
    tm[:] = (np.arange(32) | 0x8000)[None, :]             # above: row 0 flipped
    tm[R0 + ROWS:] = ((np.arange(32) + (ROWS - 1) * 32) | 0x8000)[None, :]  # below: last row flipped
    for r in range(ROWS):
        tm[R0 + r] = np.arange(32) + r * 32
    return tm.tobytes() + chr_, bgr


def video(path):
    fr = [snes_frame(f) for f in frames(path)]
    n = len(fr)
    zero = bytes(FRAME)
    out = [struct.pack('<H', n)]
    nxt = fr[1][0] if n > 1 else zero
    out += [fr[0][0], nxt[:HEAD], fr[0][1]]
    for k in range(1, n):
        cur = fr[k][0]
        nxt = fr[k + 1][0] if k + 1 < n else zero
        out += [cur[HEAD:], nxt[:HEAD], fr[k][1]]
    return b''.join(out), n


def audio(path, dst):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-vn',
                          '-af', 'asetrate=%f,aresample=44100' % (37800 * SPEED),
                          '-ac', '2', '-ar', '44100', '-f', 's16le', '-'],
                         stdout=subprocess.PIPE, check=True).stdout
    with open(dst, 'wb') as f:
        f.write(b'MSU1' + struct.pack('<I', 0) + raw)


def main():
    # names in index order; "-" = no video at that index
    outdir, names = sys.argv[1], sys.argv[2:]
    base = os.path.join(outdir, 'ct')
    N = max(10, len(names))
    with open(base + '.msu', 'wb') as f:
        f.write(b'MSU1' + bytes(4 * N))
        empty = f.tell()
        f.write(bytes(2))                     # frame count 0: the player skips it
        offs = [empty] * N
        for i, nm in enumerate(names):
            if nm == '-':
                continue
            offs[i] = f.tell()
            data, n = video(nm)
            f.write(data)
            audio(nm, '%s-%d.pcm' % (base, 100 + i))
            print('video %d %s: %d frames, %.1f MB' % (i, os.path.basename(nm), n, len(data) / 1e6), flush=True)
        f.seek(4)
        for o in offs:
            f.write(struct.pack('<I', o))


if __name__ == '__main__':
    main()
