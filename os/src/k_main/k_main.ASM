format binary
use32

org 1800h

; Main chrisos 32-bit kernel

start:
	mov esi,welcome
	mov ecx,welcome_size
	call character_print
	
	; Initialise a chunk of memory
	mov eax, dword [1]
	mov [0x180000], eax 
	mov eax, [0x180000]
	cmp eax, dword [1]
	jne start ; Check it worked

MainLoop:
	; Temp check if we got here
	mov esi, welcome 
	call character_print
	jmp $	

character_print:
	; Global text printer
	pusha

	mov	ax,0x0F0E 
	mov	dx,0x03D4 
	out	dx,al 
	inc	dx 
	in	al,dx 
	xchg	ah,al 
	dec	dx 
	out	dx,al 
	inc	dx 
	in	al,dx 
	movzx	ebx,ax

	; Set screen colours
	mov	ah,0x0F

		.character_printLoop:
		; Print each character
		lodsb 
		cmp	al,10
		je	.nextChar 
		cmp	al,13
		je	.handleCR
		mov	[es:(ebx*2+0xB8000)],ax

		inc	bx 
		jmp	.nextChar 

		.handleCR: 
		; Carriage return handling

		.nextChar: 
		; Loop through buffer
		loop	.character_printLoop

		mov	al,0x0E 
		mov	ah,bh 
		mov	dx,0x03D4 
		out	dx,ax 
		inc	ax 
		mov	ah,bl 
		out	dx,ax

		popa 
		ret

welcome db 'Into main kernel',0
welcome_size = $ - welcome

MBH_MAGIC equ 0x1BADB002
MBH_FLAGS equ 0x100000

org 0x100000

load_addr:
header_addr:
dd MBH_MAGIC
dd MBH_FLAGS
dd -MBH_MAGIC-MBH_FLAGS
dd header_addr
dd load_addr
dd load_end_addr
dd bss_end_addr
dd entry_addr

entry_addr:
	hlt

load_end_addr:
; align 4
; rb STACK_SIZE
bss_end_addr:

