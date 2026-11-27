#!/bin/sh
# Assemble AmiGameBoy with vasm (Devpac mode). Output: build/AmiGameBoy (menu build)
#   sh build.sh                 normal build
#   sh build.sh embed ROM       test build with ROM inside, no menu -> build/AmiGameBoy_embed + run/AmiGameBoy
#   sh build.sh hymenu [out]    hybrid engine behind Juan's menu -> build/AmiGameBoy_hy
#   sh build.sh rel [dir]       the release: dir/AGA, dir/AGA 030, dir/RTG (default build/rel)
# Extra assembler switches: VASMDEFS="-DAutoExit=600" sh build.sh embed roms/x.gb
cd "$(dirname "$0")" && mkdir -p build run
defs="$VASMDEFS"; out=build/AmiGameBoy
if [ "$1" = embed ]; then
  [ -f "$2" ] || { echo "no ROM: $2"; exit 1; }
  python tools/embed_rom.py "$2" build/embed.bin || exit 1
  echo '	INCBIN	"../build/embed.bin"' > src/embed.i
  defs="-DEMBED=1 $defs"; out=build/AmiGameBoy_embed
fi
if [ "$1" = spike ]; then   # stage 0 engine spike: sh build.sh spike ROM [out]
  [ -f "$2" ] || { echo "no ROM: $2"; exit 1; }
  cp "$2" build/spike_rom.bin; out=${3:-build/AmiGB_spike}
  cd src/engine && ../../tools/vasmm68k_mot.exe -devpac -m68020 -Fhunkexe -nosym -maxerrors=0 \
    $defs -o "../../$out" spike.asm > ../../build/spike.log 2>&1
  rc=$?; cd ../..
  grep -E "^(error|fatal)" build/spike.log | sort | uniq -c | head -40
  echo "vasm exit $rc ($out); $(grep -c '^warning' build/spike.log) warnings"
  exit $rc
fi
if [ "$1" = hybrid ]; then  # stage 1 hybrid, cartridge inside: sh build.sh hybrid ROM [out]
  [ -f "$2" ] || { echo "no ROM: $2"; exit 1; }
  cp "$2" build/hybrid_rom.bin; out=${3:-build/AmiGB_hybrid}
  cd src/hybrid && ../../tools/vasmm68k_mot.exe -devpac -m68020 -Fhunkexe -nosym -maxerrors=0 \
    -I../engine -I.. $defs -o "../../$out" hybrid.asm > ../../build/hybrid.log 2>&1
  rc=$?; cd ../..
  grep -E "^(error|fatal)" build/hybrid.log | sort | uniq -c | head -40
  echo "vasm exit $rc ($out); $(grep -c '^warning' build/hybrid.log) warnings"
  exit $rc
fi
if [ "$1" = rel ]; then  # the 2.0 release programs: sh build.sh rel [dir] -> dir/AGA, dir/AGA 030, dir/RTG
  d=${2:-build/rel}; mkdir -p "$d"
  r251=${FIX-"-DHY_REL251"}   # 2.5.1 version text (FIX= : the 2.5 release)
  mfix=${FIX-"-DHY_FIX251B"}   # after 2.5, all three programs: Insert with a file name of 65+ characters (FIX= : none)
  com="$mfix -DHY_REL20 -DHY_REL21 -DHY_REL22 -DHY_REL23 -DHY_REL24 -DHY_REL25 $r251 -DHY_ASLWIDE -DGBC_ADCZ -DHY_LUPA -DHY_CD32KIT -DHY_SAVE128 -DHY_CD32LATCH=200 -DHY_IDLEC -DHY_JRPOLL -DHY_VOLPCT=50 -DHY_CREDZ -DHY_CREDVH -DWZ_DAA -DWZ_HFLAGS -DWZ_SPFLAGS -DWZ_EIDELAY -DHY_WYLINE -DHY_JOYPAD2 $defs"
  # 2.6: the Wzonka-Lad 1.12 fixes, sound included (docs/wz112-log.md, 26 Nov 2026); the AGA 030
  # program without WZ112_TIMER (its cost on the 68030). WZ= : without them (FIX= WZ= : the 2.5 release,
  # WZ= alone: 2.5.1)
  wz=${WZ-"-DWZ_SYNC112"}
  wz030=${WZ030-${WZ-"-DWZ_SYNC112 -DWZ112_NOTIMER"}}
  # 2.6 (27 Nov 2026): Pacing = the menu's Screen setting, 60 Hz by default, 50 Hz and Smooth to pick
  # (HY_PACEOPT, docs/pacing-26.md), the 2.6 version text, and the Super Game Boy on the AGA program
  # only (SGB_AGA, docs/sgb-aga-log.md; AGA 030 and RTG without it), and zero-length SGB packets
  # dropped (SGB_LEN0, the Castlevania Legends black screen). P26= : none of the 2.6 changes;
  # SGBAGA= : no SGB on AGA; WZ= (the 2.5.x releases) leaves all of them out
  p26=${P26-"-DHY_PACEOPT -DHY_REL26 -DSGB_LEN0"}
  sgbaga="-DSGB_AGA -DSGB_P2 -DHY_FIX251"; [ "${SGBAGA-1}" = "" ] && sgbaga=""
  if [ "${WZ-x}" = "" ]; then p26=""; sgbaga=""; fi
  com="$com $p26"
  VASMDEFS="$com $wz $sgbaga -DHY_GBC -DGBC_RENDER -DGBC_AGA -DHY_WAVERST -DGBC_STATWR -DGBC_APEN0=0 -DHY_DIWFRAC=2 -DGBC_CCOPT -DGBC_CCDEF -DGBC_CCMENU" sh build.sh hymenu "$d/AGA" || exit 1
  VASMDEFS="$com $wz030 -DHY_DIWFRAC=2" sh build.sh hymenu "$d/AGA 030" || exit 1
  # 2.5: the RTG big menu (1920x1080, else 1280x720, else the classic menu)
  big="-DGBC_BIGMENU -DGBC_BIG43 -DGBC_BIGFONT=1 -DGBC_BIGSIZE=1080 -DGBC_BIGLAYOUT -DGBC_BIGHIRES"
  joy="-DGBC_JOYCFG"   # Joy type kept in AmiGameBoy.config; joy="" leaves it out (Juan's prefs only)
  fix=${FIX-"-DHY_FIX251"}   # after 2.5: SGB VRAM transfers per tile row (Arcade Classic No. 1); FIX= sh build.sh rel = the 2.5 release
  # 2.6: Arnold's seven scanline settings on the RTG screen (src/hybrid/scanlines.s, 27 Nov 2026).
  # SCAN= leaves them out; WZ= does too (so WZ= is still 2.5.1 and FIX= WZ= still 2.5)
  scan=${SCAN-${WZ-"-DGBC_RSTYLE"}}
  VASMDEFS="$com -DHY_GBC -DGBC_RENDER -DGBC_RTG -DGBC_RTGMENU -DGBC_RPTR -DGBC_BLEND -DGBC_RBEZ -DGBC_RSCAN     -DGBC_RBEZON -DHY_WAVERST -DGBC_STATWR -DGBC_RMENU -DGBC_CCOPT -DGBC_CCDEF -DGBC_CCMENU -DSGB -DSGB_P2 $big $joy $fix $wz $scan" sh build.sh hymenu "$d/RTG" || exit 1
  exit 0
fi
if [ "$1" = hymenu ]; then  # hybrid with Juan's menu, no cartridge inside: sh build.sh hymenu [out]
  out=${2:-build/AmiGameBoy_hy}
  cd src/hybrid && ../../tools/vasmm68k_mot.exe -devpac -m68020 -Fhunkexe -nosym -maxerrors=0 \
    -I../engine -I.. -DHY_MENU $defs -o "../../$out" hybrid.asm > ../../build/hymenu.log 2>&1
  rc=$?; cd ../..
  grep -E "^(error|fatal)" build/hymenu.log | sort | uniq -c | head -60
  echo "vasm exit $rc ($out); $(grep -c '^warning' build/hymenu.log) warnings"
  exit $rc
fi
cd src && ../tools/vasmm68k_mot.exe -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 \
  $defs -o "../$out" AmiGameBoy_Main.asm > ../build/build.log 2>&1
rc=$?; cd ..
grep -E "^(error|fatal)" build/build.log | head -20
[ $rc = 0 ] && [ "$1" = embed ] && cp "$out" run/AmiGameBoy
echo "vasm exit $rc ($out); $(grep -c '^warning' build/build.log) warnings"
exit $rc
