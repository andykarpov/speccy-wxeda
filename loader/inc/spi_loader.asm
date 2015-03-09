; ---------------------------------------------------------------
spi_loader	
	xor a
	out (#fe),a

	ld hl,str2	; Copying data from FLASH...
	call print_str

	;xor a		;bit2 = (0:Loader ON, 1:Loader OFF); bit1 = (NC); bit0 = (0:W25Q32, 1:NC)
	ld a,%00000000	; бит чтения с FLASH
	ld bc,system_port
	out (c),a

; -----------------------------------------------------------------------------
; SPI autoloader
; -----------------------------------------------------------------------------
	call spi_start
	ld d,%00000011	; command = read
	call spi_w

	ld d,#0b	; address = #0b0000 (смещение адреса в W25Q32 или в EPCS флешке, ибо 704кб зарезервировано под конфигурацию циклона)
	call spi_w
	ld d,#00
	call spi_w
	ld d,#00
	call spi_w
		
	ld hl,#8000	; gs rom 32k (смещение адреса, чтобы пропустить копирование 32кб gs rom)

spi_loader1
	call spi_r
;	ld (hl),a
	inc hl
	ld a,l
	or h
	jr nz,spi_loader1
	
	ld bc,mask_port
	ld a,%11111111	; маска порта по and
	out (c),a
	ld a,%10000100
	ld bc,ext_mem_port
	out (c),a

	xor a		; открываем страницу озу
spi_loader3
	ld bc,#7ffd
	out (c),a
	ld hl,#c000
	ld e,a
spi_loader2
	call spi_r
	ld (hl),a
	out (#fe),a
	inc hl
	ld a,l
	or h
	jr nz,spi_loader2
	ld a,e
	inc a
	cp 5
	jr c,spi_loader3

	call spi_end
	xor a
	ld bc,#7ffd
	out (c),a
	ld bc,ext_mem_port
	out (c),a
	ld a,%00011111	; маска порта (разрешаем 4mb)
	ld bc,mask_port
	out (c),a

	xor a
	out (#fe),a

	ld hl,str3	;завершено
	call print_str

	ld hl,str0	;any key
	call print_str

;	call anykey

	ld a,%00000100	; bit2 = (0:Loader ON, 1:Loader OFF); bit1 = (NC); bit0 = (0:W25Q32, 1:NC)
	ld bc,system_port
	out (c),a

	ld sp,#ffff
	jp #0000	; запуск системы




; -----------------------------------------------------------------------------	
; SPI -- V0.2.1	(20130901)
; -----------------------------------------------------------------------------
; Ports:
; #02: Data Buffer (write/read)
;	bit 7-0	= Stores SPI read/write data
; #03: Command/Status Register (write)
;	bit 7-1	= Reserved
;	bit 0	= 1:END   	(Deselect device after transfer/or immediately if START = '0')
; #03: Command/Status Register (read):
; 	bit 7	= 1:BUSY	(Currently transmitting data)
;	bit 6-0	= Reserved

spi_end
	ld a,%00000001	; config = end
	out (#03),a
	ret
spi_start
	xor a
	out (#03),a
	ret
spi_w
	in a,(#03)
	rlca
	jr c,spi_w
	ld a,d
	out (#02),a
	ret
spi_r
	ld d,#ff
	call spi_w
spi_r1	
	in a,(#03)
	rlca
	jr c,spi_r1
	in a,(#02)
	ret
