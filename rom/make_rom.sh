#!/bin/bash

# образ SPECCY.ROM для записи в корень FAT32 SD-карточки 

# 1 : 16384 hegluk_19.rom
# 2 : 16384 trdos_605e.rom
# 3 : 16384 86.rom
# 4 : 16384 82.rom
# 5 : 8192 esxmmc.rom
# 6 : 8192 test128k.rom

cat hegluk_19.rom > SPECCY.ROM
cat trdos_605e.rom >> SPECCY.ROM
cat 86.rom >> SPECCY.ROM
cat 82.rom >> SPECCY.ROM
cat esxmmc.rom >> SPECCY.ROM
cat test128k.rom >> SPECCY.ROM
