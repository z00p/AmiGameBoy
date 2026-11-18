#!/bin/sh
# Assemble AmiGameBoy with vasm (Devpac mode). Output: build/AmiGameBoy (menu build)
#   sh build.sh                 normal build
#   sh build.sh embed ROM       test build with ROM inside, no menu -> build/AmiGameBoy_embed + run/AmiGameBoy
#   sh build.sh hymenu [out]    hybrid engine behind Juan's menu -> build/AmiGameBoy_hy
#   sh build.sh rel [dir]       the 2.0 release: dir/AGA, dir/AGA 030, dir/RTG (default build/rel)
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
  com="-DHY_REL20 -DHY_REL21 -DHY_ASLWIDE -DGBC_ADCZ -DHY_LUPA -DHY_CD32KIT -DHY_SAVE128 -DHY_CD32LATCH=200 -DHY_IDLEC -DHY_JRPOLL -DHY_VOLPCT=50 -DHY_CREDZ -DHY_CREDVH $defs"
  VASMDEFS="$com -DHY_GBC -DGBC_RENDER -DGBC_AGA -DHY_WAVERST -DGBC_STATWR -DGBC_APEN0=0 -DHY_DIWFRAC=2 -DGBC_CCOPT -DGBC_CCDEF -DGBC_CCMENU" sh build.sh hymenu "$d/AGA" || exit 1
  VASMDEFS="$com -DHY_DIWFRAC=2" sh build.sh hymenu "$d/AGA 030" || exit 1
  VASMDEFS="$com -DHY_GBC -DGBC_RENDER -DGBC_RTG -DGBC_RTGMENU -DGBC_RPTR -DGBC_BLEND -DGBC_RBEZ -DGBC_RSCAN     -DGBC_RBEZON -DHY_WAVERST -DGBC_STATWR -DGBC_RMENU -DGBC_CCOPT -DGBC_CCDEF -DGBC_CCMENU" sh build.sh hymenu "$d/RTG" || exit 1
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
