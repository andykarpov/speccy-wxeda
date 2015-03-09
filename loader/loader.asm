 		DEVICE	ZXSPECTRUM48
; -----------------------------------------------------------------[09.08.2014]
; ReVerSE-U16 Loader Version 0.9.2 By MVV
; -----------------------------------------------------------------------------
; V0.1	 05.11.2011	первая версия
; V0.5	 09.11.2011	добавил SPI загрузчик и GS, VS1053
; V0.6	 14.01.2012	добавил расширение памяти KAY
; V0.7	 19.09.2012	по умолчанию режим память 4MB Profi, 96K ROM грузится из M25P40, wav 48kHz, FAT16 loader отключен
; V0.8	 19.03.2014	размер загрузчика 1К
; V0.9	 24.07.2014	одаптирован для U16 EP3C10
; V0.9.1 25.07.2014	одаптирован для U16 EP4CE22/EP3C25
; V0.9.2 09.08.2014	поддержка ENC424J600
; WXEDA	 03.03.2015	убрана поддержка RTC, CMOS, ENC424J600
; WXEDA	 09.03.2015	код загрузчика из W25Q32 вынесена в отдельный include


system_port	equ #0001	; bit2 = (0:Loader ON, 1:Loader OFF); bit1 = (NC); bit0 = (0:W25Q32, 1:NC)
mask_port	equ #0000	; Маска порта EXT_MEM_PORT по AND
ext_mem_port	equ #dffd	; Порт памяти
pr_param	equ #7f00	; 


	org #0000
startprog:
	di		; disable int
	ld sp,#7ffe	; STACK - Bank1:(Exec code - Bank0):destination Memory-Bank3

	xor a
	out (#fe),a
	call cls	; очистка экрана
	ld hl,str1
	call print_str

; 0B0000 GS 	32K
; 0B8000 GLUK	16K	0
; 0BC000 TR-DOS	16K	1
; 0C0000 OS'86	16K	2
; 0C4000 OS'82	16K	3
; 0C8000 divMMC	 8K	4

	; todo
	;include "inc/fat32_loader.asm"
	;include "inc/fat_loader.asm"
	include "inc/spi_loader.asm"

	
;==============================================================================
	

;clear screen
cls
	ld hl,#4000
	ld de,#4001
	ld bc,#1800
	ld (hl),l
	ldir
	ld b,#03
	ld (hl),#07
	ldir
	ret

;print string i: hl - pointer to string zero-terminated
print_str
	ld a,(hl)
	cp 17
	jr z,print_color
	cp 23
	jr z,print_pos_xy
	cp 24
	jr z,print_pos_x
	cp 25
	jr z,print_pos_y
	or a
	ret z
	inc hl
	call print_char
	jr print_str
print_color
	inc hl
	ld a,(hl)
	ld (pr_param+2),a		;color
	inc hl
	jr print_str
print_pos_xy
	inc hl
	ld a,(hl)
	ld (pr_param),a			;x-coord
	inc hl
	ld a,(hl)
	ld (pr_param+1),a		;y-coord
	inc hl
	jr print_str
print_pos_x
	inc hl
	ld a,(hl)
	ld (pr_param),a			;x-coord
	inc hl
	jr print_str
print_pos_y
	inc hl
	ld a,(hl)
	ld (pr_param+1),a		;y-coord
	inc hl
	jr print_str

;print character i: a - ansi char
print_char
	push hl
	push de
	push bc
	cp 13
	jr z,pchar2
	sub 32
	ld c,a			; временно сохранить в с
	ld hl,(pr_param)	; hl=yx
	;координаты -> scr adr
	;in: H - Y координата, L - X координата
	;out:hl - screen adress
	ld a,h
	and 7
	rrca
	rrca
	rrca
	or l
	ld l,a
	ld a,h
        and 24
	or 64
	ld d,a
	;scr adr -> attr adr
	;in: hl - screen adress
	;out:hl - attr adress
	rrca
	rrca
	rrca
	and 3
	or #58
	ld h,a
	ld a,(pr_param+2)	; цвет
	ld (hl),a		; печать атрибута символа
	ld e,l
	ld l,c			; l= символ
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,font
	add hl,bc
	ld b,8
pchar3	ld a,(hl)
	ld (de),a
	inc d
	inc hl
	djnz pchar3
	ld a,(pr_param)		; x
	inc a
	cp 32
	jr nz,pchar1
pchar2
	ld a,(pr_param+1)	; y
	inc a
	cp 24
	jr nz,pchar0
	;сдвиг вверх на один символ
	ld de,#4000		;откуда
	ld hl,#4020		;куда
	ld b,#17		;кол-во строк
pchar4
	push bc
	call scroll
	call ll693e		;служебные процедуры (на стр. вверх)
;	call ll6949		;служебные процедуры (на стр. вниз)
	pop bc
	djnz pchar4
	jr pchar00
pchar0
	ld (pr_param+1),a
pchar00
	xor a
pchar1
	ld (pr_param),a
	pop bc
	pop de
	pop hl
	ret

;print hexadecimal i: a - 8 bit number
print_hex
	ld b,a
	and $f0
	rrca
	rrca
	rrca
	rrca
	call hex2
	ld a,b
	and $0f
hex2
	cp 10
	jr nc,hex1
	add 48
	jp print_char
hex1
	add 55
	jp print_char

;print decimal i: l,d,e - 24 bit number , e - low byte
print_dec
	ld ix,dectb_w
	ld b,8
	ld h,0
lp_pdw1
	ld c,"0"-1
lp_pdw2
	inc c
	ld a,e
	sub (ix+0)
	ld e,a
	ld a,d
	sbc (ix+1)
	ld d,a
	ld a,l
	sbc (ix+2)
	ld l,a
	jr nc,lp_pdw2
	ld a,e
	add (ix+0)
	ld e,a
	ld a,d
	adc (ix+1)
	ld d,a
	ld a,l
	adc (ix+2)
	ld l,a
	inc ix
	inc ix
	inc ix
	ld a,h
	or a
	jr nz,prd3
	ld a,c
	cp "0"
	ld a," "
	jr z,prd4
prd3
	ld a,c
	ld h,1
prd4
	call print_char
	djnz lp_pdw1
	ret
dectb_w
	db #80,#96,#98	;10000000 decimal
	db #40,#42,#0f	;1000000
	db #a0,#86,#01	;100000
	db #10,#27,0	;10000
	db #e8,#03,0	;1000
	db 100,0,0	;100
	db 10,0,0	;10
	db 1,0,0	;1



;scroll screen
;	push bc
;	call scroll		;вызов проц.сдвига
;	call ll693e		;служебные процедуры (на стр. вверх)
;	call ll6949		;служебные процедуры (на стр. вниз)
;	pop bc
;	djnz main
;	ret
scroll	
	push hl
	push de
	ld a,d
	rrca
	rrca
	rrca
	and #03
	or #58
	ld d,a
	ld a,h
	rrca
	rrca
	rrca
	and #03
	or #58
	ld h,a
	dup 32
	ldi
	edup
	pop de
	pop hl
	ld bc,#00f8
	jp loop2
loop1
	inc h
	inc d
loop2	
	dup 31
	ldi
	edup
	ld a,(hl)
	ld (de),a
	inc h
	inc d
	dup 31
	ldd
	edup
	ld a,(hl)
	ld (de),a
	jp pe,loop1
	ret
	;служебные процедуры
ll692a
	ld a,l
	sub #20
	ld l,a
	ret nc
	ld a,h
	sub #08
	ld h,a
	ret
ll6934
	ld a,e
	sub #20
	ld e,a
	ret nc
	ld a,d
	sub #08
	ld d,a
	ret
ll693e	
	inc h
	ld a,l
	sub #e0
	ld l,a
	ret nc
	ld a,h
	sub #08
	ld h,a
	ret
ll6949 	
	inc d
	ld a,e
	sub #e0
	ld e,a
	ret nc
	ld a,d
	sub #08
	ld d,a
	ret
	
;Ожидание клавиши
anykey
	xor a			;все биты сброшены
	in a,(#fe)		;опрашиваем все полуряды
	cpl			;почти эквивалентно комбинации:
	and 31 			;AND 31:CP 31,  но короче
	jr z,anykey 		;пока не нажмут ANY KEY
	ret
	
	
;управляющие коды
;13 (0x0d)		- след строка
;17 (0x11),color	- изменить цвет последующих символов
;23 (0x17),x,y		- изменить позицию на координаты x,y
;24 (0x18),x		- изменить позицию по x
;25 (0x19),y		- изменить позицию по y
;0			- конец строки
	
	
str1	
	db 23,0,0,17,#55,"ReVerSE-U16 By MVV, 2014",13,13,13
	db 17,7,"FPGA SoftCore - Speccy on WXEDA",13
	db 17,7,"(build 2015-03-09)",13,13,0
str2	
	db 17,7,"Copying data from FLASH...",0
str3
	db 17,4," done",17,7,13,0
str4	
	db 17,7,"Copying data from SD...",0
str5
	db 17,4," done",17,7,13,0
str6
	db 17,3," error",17,7,13,0
str0
	db 13,13,23,0,23,17,7,"Booting, please wait",0

font	
	INCBIN "font.bin"
	
	savebin "loader.bin",startprog, 8192
