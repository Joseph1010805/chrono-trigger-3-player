"""Make the cutscene files for the Chrono Trigger FMV patch from your own copy
of the PlayStation release (Final Fantasy Chronicles - Chrono Trigger, USA).

usage:
    python make_videos.py "Final Fantasy Chronicles - Chrono Trigger (USA).bin" "My ROM name"

"My ROM name" is your patched ROM's file name without .sfc/.smc; the files
are written next to this script:
    My ROM name.msu          (the videos, ~390 MB)
    My ROM name-100.pcm ... My ROM name-109.pcm   (their sound)
Copy them into the same folder as the ROM.

Needs: Python 3 with numpy and pillow (pip install numpy pillow), and
ffmpeg on the PATH (https://ffmpeg.org).
"""
import os, sys, shutil, tempfile
import psxiso, encode

# video index -> file on the disc (index n plays with track 100+n)
VIDEOS = ['MOVIE/OP.STR',                       # 0 opening (title screen)
          'MOVIE/M1.STR', 'MOVIE/M2.STR', 'MOVIE/M3.STR', 'MOVIE/M4.STR',
          'MOVIE/M5.STR', 'MOVIE/M6.STR', 'MOVIE/M7.STR',   # 1-7 story
          'MOVIE/ENOSP1.STR', 'MOVIE/ENOSP2.STR']           # 8-9 ending (no text)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    disc, name = sys.argv[1], sys.argv[2]
    if not shutil.which('ffmpeg'):
        sys.exit('ffmpeg was not found on the PATH')
    here = os.path.dirname(os.path.abspath(__file__))
    tmp = tempfile.mkdtemp()
    try:
        f = open(disc, 'rb')
        files = psxiso.files(f)
        strs = []
        for v in VIDEOS:
            hit = [x for x in files if x[0].upper().endswith('/' + v)]
            if not hit:
                sys.exit('%s is not on this disc - is it the US Final Fantasy Chronicles CT disc?' % v)
            p, lba, size = hit[0]
            out = os.path.join(tmp, os.path.basename(v))
            with open(out, 'wb') as o:
                for i in range((size + 2047) // 2048):
                    o.write(psxiso.sector(f, lba + i))
            strs.append(out)
            print('extracted', v)
        work = os.path.join(tmp, 'out')
        os.makedirs(work)
        sys.argv = ['encode.py', work] + strs
        encode.main()
        for fn in os.listdir(work):
            dst = fn.replace('ct', name, 1)
            shutil.move(os.path.join(work, fn), os.path.join(here, dst))
            print('wrote', dst)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
