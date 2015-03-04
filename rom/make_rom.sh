#!/bin/bash

dd if=/dev/zero of=output.rom bs=720896 count=1
cat gs105a.rom >> output.rom 
cat hegluk_19.rom >> output.rom 
cat trdos_605e.rom >> output.rom 
cat 86.rom >> output.rom 
cat 82.rom >> output.rom 
cat esxmmc.rom >> output.rom 
echo "\nRom file is ready to flash into SPI flash device. Well done, commander!\n"
