format binary
use32

org 1800h

start:
	mov esi, welcome
	mov ecx, welcome_size
	call character_print

MainLoop:
	hlt

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

;*******
; GDT
;*******

gdt:	    dw	  0x0000, 0x0000, 0x0000, 0x0000 
sys_data:   dw	  0xFFFF, 0x0000, 0x9200, 0x00CF 
sys_code:   dw	  0xFFFF, 0x0000, 0x9a00, 0x00CF 
gdt_end: 

gdtr:	    dw gdt_end - gdt - 1					   
			dd gdt

welcome db 'Loaded main 32-bit kernel',0
welcome_size = $ - welcome
