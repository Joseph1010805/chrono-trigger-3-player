#!/bin/bash
# Rebuilds the patches from source.  Needs (not included - bring your own):
#   asar 1.91          -> tools/asar/asar.exe   (https://github.com/RPGHacker/asar)
#   rom/ct_plain.sfc   Chrono Trigger (USA), headerless, CRC32 2D206BF7
#   rom/ct_msu.sfc     the same ROM with the MSU-1 patch applied (the build base)
#   rom/ctplus.sfc     Chrono Trigger Plus (CTSE 3.0), CRC32 DB9AB142  (optional)
cd "$(dirname "$0")/.."
ASAR=tools/asar/asar.exe
mkdir -p out "patches/CT+"
for v in 3p fmv both; do
  cp rom/ct_msu.sfc out/b_$v.sfc
  $ASAR --no-title-check src/build_$v.asm out/b_$v.sfc || { echo "build $v FAILED"; exit 1; }
done
python tools/mkbps.py rom/ct_plain.sfc out/b_3p.sfc   "patches/Chrono Trigger - 3 Player.bps"
python tools/mkbps.py rom/ct_plain.sfc out/b_fmv.sfc  "patches/Chrono Trigger - FMV.bps"
python tools/mkbps.py rom/ct_plain.sfc out/b_both.sfc "patches/Chrono Trigger - 3 Player + FMV.bps"
if [ -f rom/ctplus.sfc ]; then
  for v in 3p fmv both; do
    cp rom/ctplus.sfc out/c_$v.sfc
    $ASAR --no-title-check src/build_ctp_$v.asm out/c_$v.sfc || { echo "CT+ build $v FAILED"; exit 1; }
  done
  python tools/mkbps.py rom/ctplus.sfc out/c_3p.sfc   "patches/CT+/Chrono Trigger Plus - 3 Player.bps"
  python tools/mkbps.py rom/ctplus.sfc out/c_fmv.sfc  "patches/CT+/Chrono Trigger Plus - FMV.bps"
  python tools/mkbps.py rom/ctplus.sfc out/c_both.sfc "patches/CT+/Chrono Trigger Plus - 3 Player + FMV.bps"
fi
echo "done - patches in patches/"
