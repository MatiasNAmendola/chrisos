format	binary
use16
org 1000h

; Kernel loaded into conventional memory


;==============================
; chrisos kernel version 0.05
;==============================

; Carriage Return
crlf	equ	0dh,0ah

; Custom MOV instruction
macro	mov	p1,p2 { 
  if p2 eqtype '' 
    local ..string,..skip 
	jmp	..skip 
      ..string db p2,0 
      ..skip: 
	mov	p1,..string 
  else 
	mov	p1,p2 
  end if 
} 

start:
	mov	ax,0e43h
	xor	bx,bx
	; Get cursor position and shape, return dl with column, ax = 0
	int	10h

	; dword 32-bit integer
	; Address of a routine (interrupt memory location) to be called when the CPU receives an interrupt
	mov	dword [320],0000+interrupt
	mov	[boot_drive],dl

	; Set video mode 3 (text) 80 x 25
	mov	ax,0003h
	int	10h

	; +++Commandline Handling Routine+++
	
	; Put crlf into source index
	mov	si,line
	; Set print string
	mov	ah,01h
	; Call print_string (recursively puts contents of ds:si (newline) into AL and prints each character)
	int	50h

	; Put msg into source index
	mov	si,.msg
	; Set print string
	mov	ah,01h
	; Call to print_string (recursively puts contents of ds:si into AL and prints each chatacter)
	int	50h

	; Add input (register byte) as the di
	mov	di,.input
	mov	dx,19h 
	; Set get string
	mov	ah,03h
	;Call to get_string (es:di  0000:.input)
	int	50h

	; Put return keypress into source index
	mov	si,line
	; Set print string
	mov	ah,01h
	; Call to print_string (ds:si pointed string - prints blank line)
	int	50h

	;  Add input (register byte) as the si. input now contains what user inputted
	mov	si,.input
	; Set print string
	mov	ah,01h
	; Call to print_string (ds:si 0000:.input pointed string- prints string inputted)
	int	50h


    jmp next ;Archaic loop


.msg db 'Booted OK (Press Return)',0dh,0ah,'>',0
; Reserves 20h bytes of memory starting at address of label 'input'
; Using selector:offset can store user input here using es
.input rb 20h


 next:

	; Put crlf into source index
	mov	si,line
	; Set print string
	mov	ah,01h
	; Call print_string (recursively puts contents of ds:si (newline) into AL and prints each character)
	int	50h

	; Put msg into source index
	mov	si,.msg
	; Set print string
	mov	ah,01h
	; Call to print_string (recursively puts contents of ds:si into AL and prints each chatacter)
	int	50h

	; Add input (register byte) as the di
	mov	di,.input
	mov	dx,19h 
	; Set get string
	mov	ah,03h
	;Call to get_string (es:di  0000:.input)
	int	50h

	; Put return keypress into source index
	mov	si,line
	; Set print string
	mov	ah,01h
	; Call to print_string (ds:si pointed string - prints blank line)
	int	50h

	;  Add input (register byte) as the si. input now contains what user inputted
	mov	si,.input
	; Set print string
	mov	ah,01h
	; Call to print_string (ds:si 0000:.input pointed string- prints string inputted)
	int	50h

	
	jmp next
	cli
	hlt

.msg db 'chrisOS V0.05',0dh,0ah,'>',0
.input rb 20h

; Future error handling
error: 
	mov	si,.msg 
	mov	ah,01h 
	int	50h 
	cli 
	hlt 
.msg db 'Error',0

interrupt: 
; Our interrupt handler will be invoked any time a scan code is sent to the keyboard controller
	or	ah,ah 
	jz	shutdown_os 
	cmp	ah,01h 
	je	print_string 
	cmp	ah,02h 
	je	clear_screen 
	cmp	ah,03h 
	je	get_string 
	cmp	ah,04h 
	je	wait_enter 
	cmp	ah,05h 
	jmp	error
	cmp	ah,06h
	jmp	helpmsg
	cmp	ah,07h
	jmp	protected

shutdown_os: 
	cli
	xor	ax,ax 
	mov	ds,ax 
	mov	es,ax 
	mov	fs,ax 
	mov	gs,ax 

	mov	ax,0fffh 
	mov	ss,ax 
	mov	sp,0ffffh 
	mov	bp,sp 
	sti 

	; jmp to nowhere land
	jmp	2000h

; Prints a zero-terminated, ds:si pointed string 
; SI is the memory address of a data section in the kernel, DS is 00000. So DS:SI contains physical address
print_string: 
	; Pushes contents of ax to top of stack
	push	ax
	;Decrements the stack pointer and then stores AX on the top of the stack
	
		@@: 
		; Loads byte from ds:si into AL  
		lodsb
		; Check if AL is 0
		or	al,al
		jz	.ret 
		mov	ah,0eh

		; Teletext output, AL = character to write
		int	10h
		jmp	@b 

		.ret: 
		; Loads the value from the top of the stack to AX, increment pointer
		pop	ax
		iret



; Clears the screen and returns to user input loop
clear_screen: 
	push	ax di es dx 
	
	mov	ax,0b800h 
	mov	es,ax 
	xor	di,di

		@@: 
		mov	byte [es:di],0 
		add	di,2 
		cmp	di,4000 ;loop until di = 4000, clear all data registers in memory
		jne	@b 

		mov	ah,02h ;Set cursor position
		mov	dx,0000h ;row/colum = 0
		int	10h ;Call set cursor position, BH = Page Number, DH = Row, DL = Column

		.ret: 
		pop	dx es di ax 
		jmp next
		iret 


; Gets a string from the keyboard, es:di points to the reserved memory, DX holds maximum characters to collect 
; Returns: ES:DI string, dx = 0 or bytes of memory not used.
get_string: 
	; Decrements the stack pointer and then stores AX on the top of the stack
	push	ax
	; Decrement DX by 1, initially set to 19h
	dec	dx
	;DS:SI points to register byte (input)
	
		@@: 
		; Reads each keypress, outputs to screen and stores in ES:DI (input)
		xor	ah,ah
		; Read character from keyboard, AL = ASCII character
		int	16h
		; Check if value in AL is 0
		or	al,al
		; If AL is 0 jump to .extended
		jz	.extended
		; Return keypress handling
		cmp	al,0ah ; AL = 10 (dec)
		je	.ret ; Jump to .ret if AL = 10
		cmp	al,0dh ; AL = 13 (dec)
		je	.ret ; Jump to .ret if AL = 13
		
		; Checks whether Al contains certain ASCII chars
		; Needs to be changed to check after user enters return key
		
		; Check for 'q' key
		cmp	al,71h
		; If found jump to nowhere
		je	 shutdown_os
		
		; Check for 'c' key
		cmp	al,63h
		; If found clear the screen
		je    clear_screen
		
		; Check for 'h' key
		cmp	al,68h
		; If found display help
		je    helpmsg
		
		; Check for 'p' key
		cmp	al,70h
		; If found jump to protected mode
		je    protected
		
		; Set Teletype output
		mov	ah,0eh
		; Teletype output, AL = character, BH = page number
		int	10h

		.store: 
		; Stores the byte in AL at [ES:DI]
		stosb

		; Decrement dx by 1
		dec	dx
		; Check if value in dx is 0
		or	dx,dx
		jz	.ret 

		; Jump to first label
		jmp	@b

		.extended: 
		; Shift 8 bits right
		shr	ax,8
		jmp	.store 

		.ret:
		mov	al,0
		; STOSB stores the byte in AL at [ES:DI]
		stosb

		; Pop AX from the stack
		pop	ax
		iret


; Waits until return key is pressed
wait_enter: 
	push	ax
		@@: 
		xor	ah,ah
		; Read character from keyboard
		int	16h
		; Jump to start of @@ if not return key
		cmp	ah,0ah
		jne	@b 

		.ret: 
		pop	ax 
		iret

helpmsg:
	push ax
	mov	si,help
	mov	ah,01h 
	int	50h
	pop	ax
	jmp next
	iret

help db 'ChrisOS Help: q - halt, c - clear screen, h - help, p - enter 32-bit land', 0

boot_drive db 0 
line db crlf,0	   

protected:
	; Clear interrupts
	cli
	; Fast A20 gate
	in al, 0x92
	or al, 2
	out 0x92, al

	; Load GDT
	lgdt  [gdtr]
	 
	mov   eax, cr0 
	or    al,0x1  
	mov   cr0,eax 
  
	jmp   0x10:intop

;***************************
; 32-bit Kernel Entry Point
;***************************
use32
intop:
	mov   ax,0x8
	mov   ds,ax
	mov   es,ax
	mov   ss,ax

	; Print welcome message
	mov	esi,welcome
	mov	ecx,welcome_size
	call chatacter_print

MainLoop:
	hlt
	jmp	MainLoop

chatacter_print:
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

		.chatacter_printLoop:
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
		loop	.chatacter_printLoop

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

welcome db '32-bit mode enabled',0
welcome_size = $ - welcome

;times   300h - ($-$$)   nop ; Pad out to 768 bytes long