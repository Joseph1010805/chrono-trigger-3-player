# Chrono Trigger — 3 Player (+ FMV)

A fan patch for the SNES **Chrono Trigger** that lets three people play the
party at once, plus the PlayStation anime cutscenes played in-game over MSU-1.
Editions for the plain US game and for **Chrono Trigger Plus** (CTSE 3.0).

**No ROMs, music or videos are included.** You patch your own copy of the game.

## The patches

| File | What it does |
|---|---|
| `patches/Chrono Trigger - 3 Player.bps` | 3-player co-op |
| `patches/Chrono Trigger - FMV.bps` | the anime cutscenes + a video gallery |
| `patches/Chrono Trigger - 3 Player + FMV.bps` | both |
| `patches/CT+/Chrono Trigger Plus - …` | the same three, for Chrono Trigger Plus |

Every patch includes MSU-1 support (CD-quality music and the video player).
Without the MSU-1 files the game just plays its normal music.

## What you need

- **Plain editions:** Chrono Trigger (USA) SNES ROM, no copier header —
  4,194,304 bytes, CRC32 `2D206BF7`. (A 4,194,816-byte file has a 512-byte
  header; remove it first.)
- **CT+ editions:** your Chrono Trigger Plus (CTSE 3.0) ROM — 6,291,456 bytes,
  CRC32 `DB9AB142`. Patch the CT+ ROM, not the plain game.
- A BPS patcher: [Floating IPS (flips)](https://github.com/Alcaro/Flips), beat,
  or [Rom Patcher JS](https://www.marcrobledo.com/RomPatcher.js/) in a browser.
- An emulator with MSU-1: tested in **Mesen 2** and **RetroArch (Snes9x core)**,
  including RetroArch on Android handhelds.

Patch a **copy** of the ROM, e.g. `Chrono Trigger 3P.sfc`.

## 3 Player

**Controllers.** Up to five controllers: port 1, plus a multitap in port 2
(RetroArch players 2–5). Any controller joins the first time you press a
button on it. Played alone, the game is unchanged.

**Battle.** Every player drives their own character at the same time — three
command boxes with HP / MP / time gauge, private Tech and Item lists, and
coloured target pointers (P1 white, P2 light blue, P3 red). Hold X in a list
for the description. Dual and triple techs: whoever picks one proposes it and
partners join from the top of their Tech list (or decline).

**Swapping controllers mid-battle.** **Start** on *any* controller pauses. The
pause panel shows each character and the controller playing them (P1–P5).
**Left/right** on any controller moves the arrow between characters; **Select**
gives the highlighted character to the controller that pressed it (swapping
with whoever had them). **Start** resumes. While paused, buttons never reach
the battle menus underneath.

**Field and world map.** Players 2 and 3 walk freely, talk, open chests and
start events with A. On the world map all players must stand on the same
place and press A to enter it. **X** opens the menu on the character of whoever pressed it
(any controller, ports 4 and 5 included).

**In the X menu.** **Select** claims the highlighted character for your
controller; **Y** cycles that player between Ready / Follow / Idle. The
battle pause panel and the X menu change the same assignments, so a swap in
one shows up in the other.

> RetroArch tip: RetroArch uses **Select** as its hotkey button and
> Select + Start can quit the emulator. Turn on *Settings → Input → Hotkeys →
> Confirm Quit* (or change the hotkey) before playing.

## FMV

The anime cutscenes from the PlayStation release play at their story moments
(the opening on the title screen). The video files can't be shared — make them
from your own copy of the PlayStation disc (*Final Fantasy Chronicles*, USA)
with the FMV kit:

1. Install Python 3, then `pip install numpy pillow`, and
   [ffmpeg](https://ffmpeg.org) so `ffmpeg` runs from a prompt.
2. In `fmv_kit/`:
   ```
   python make_videos.py "path\to\Final Fantasy Chronicles - Chrono Trigger (USA).bin" "Chrono Trigger 3P"
   ```
   (the second argument is your ROM's file name without `.sfc`)
3. Copy `Chrono Trigger 3P.msu` and `Chrono Trigger 3P-100.pcm` … `-109.pcm`
   next to the ROM (~500 MB).

**Video gallery:** on the save screen the New Game line reads
"New Game (Y:FMV)" — press Y to watch every video (Start or B skips one).

**CT+:** CT+ carries the video player but never used it; the FMV patches add
the 7 story videos to CT+'s own versions of those scenes, plus the gallery.
Make the videos with your CT+ ROM's name (e.g. `"CT+"`). Keep using CT+'s own
music tracks; the videos use tracks 100–109.

### MSU-1 music (optional)

Put a Chrono Trigger MSU-1 music pack next to the ROM, renamed to match it:
`Chrono Trigger 3P-1.pcm`, `-2.pcm`, … Some emulators also want a
`Chrono Trigger 3P.msu` file to switch MSU-1 on; an empty one is fine for
music only (the FMV kit makes the real one).

## Building from source

The patches are built from `src/` with [asar](https://github.com/RPGHacker/asar)
1.91. See `tools/build.sh` for the base ROMs it expects (you supply them).
The build is reproducible: it produces byte-identical patches to the ones here.

## Credits

- MSU-1 audio patch: **DarkShock**.
- MSU-1 video player and in-game video triggers: **qwertymodo** (from his
  unreleased all-FMV beta, which the ROM base contains; the video file format
  was worked out from it).
- Anime intro research: **smkdan**, **ManuLowe**.
- Chrono Trigger Plus: its own authors — get it from its official release.
- 3-player mod, video gallery and FMV kit: Joseph, built with Claude.

Chrono Trigger © Square Enix. This is an unofficial fan patch, not affiliated
with or endorsed by Square Enix. The FMV kit only converts a disc you own.
