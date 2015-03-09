#!/bin/bash

# образ W25Q32.ROM для записи в конфигурационную флешку W25Q32 с помощью программатора
dd if=/dev/zero of=W25Q32.ROM bs=720896 count=1
cat gs105a.rom >> W25Q32.ROM
cat hegluk_19.rom >> W25Q32.ROM 
cat trdos_605e.rom >> W25Q32.ROM 
cat 86.rom >> W25Q32.ROM 
cat 82.rom >> W25Q32.ROM 
cat esxmmc.rom >> W25Q32.ROM 
# todo: дописать до полного объема нулями


# образ SPECCY.ROM для записи на FAT32 карточку в ROM/SPECCY.ROM
#cat gs105a.rom > SPECCY.ROM
cat hegluk_19.rom >> SPECCY.ROM  #32k
cat trdos_605e.rom >> SPECCY.ROM #16k
cat 86.rom >> SPECCY.ROM #16k
cat 82.rom >> SPECCY.ROM #16k
cat esxmmc.rom >> SPECCY.ROM #8k
cat test128k.rom >> SPECCY.ROM #8k
