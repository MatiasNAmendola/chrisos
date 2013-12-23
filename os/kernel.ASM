format	binary
use16
org 1000h

; Kernel loaded into conventional memory


;==============================
; chrisos kernel version 0.07
;==============================


; Task States
NULL_T equ (0)
FREE_T equ (1)
WAIT_T equ (2)
EXEC_T equ (3)

; Task Memory
TOTAL_T equ (10)
STACK_T equ (128)
TASK_T rw TOTAL_T


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
	; Move our custom interrupt routine into IVT
	mov	dword [320],0000+interrupt
	mov	[boot_drive],dl
	
	; Set video mode 3 (text) 80 x 25
	mov	ax,0003h
	int	10h
	
	push bx
	xor	bx,bx

; Open free task slots	
open_task_slots:
	mov [TASK_T+bx], FREE_T
	; Debug to notify added
	mov	si,added
	mov	ah,01h
	int	50h
	add bx, 2
	cmp bx, TOTAL_T
	jnz open_task_slots
	pop bx

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

.msg db 'chrisOS V0.07',0dh,0ah,'>',0
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
; Our interrupt handler routine, loaded into memory at IVT location 320 (int 50h)
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
	je	error
	cmp	ah,06h
	je	helpmsg
	cmp	ah,07h
	je	task_man
	cmp	ah,08h
	je	protected

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
	jmp	3000h

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
		
		; Check for 'm' key
		cmp	al,6dh
		; Print memory total
		je    checkmem
		
		; Check for 't' key
		cmp	al,74h
		; if found start task manager
		je    task_man
		
		; Check for 'p' key
		cmp	al,70h
		; If found jump to protected mode
		je    protected
		
		; Check for 's' key
		cmp	al,73h
		; Set first task slot to wait
		je    close_task_slot
		
		; Check for 'o' key
		cmp	al,6fh
		; Set first task slot to idle
		je    open_task_slot
		
		; Check for '1' key
		cmp	al,31h
		; Check task 1 status
		je    check_task
		
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
		; Signals end of string to be printed
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
		
; Display help message
helpmsg:
	push ax
	mov	si,help
	mov	ah,01h 
	int	50h
	pop	ax
	jmp next
	iret

; Checks current task value
check_task:
	push ax
	mov ax, [TASK_T+0]
	Call printregister
	pop ax
	iret
	
; Checks available memory above first mb
checkmem:
	mov	si,memfound
	mov	ah,01h
	int	50h
	push ax
	mov ah, 88h
	int 15h
	Call printregister
	pop ax
	iret

; Print contents of the AX register
printregister:
	pusha
	push 0
	mov bx, 10
		@@:
		xor dx, dx
		div bx
		add dx, '0'
		push dx
		or al,al
		jz @f
		jmp @b
		
		@@:
		pop ax
		or al, al
		jz @f
		mov ah, 0Eh
		int 10h
		jmp @b
	
		@@:
		popa
		jmp next
		iret

help db 'ChrisOS Help: task manager (<number> - task slot value, t - show slot status, s - close slot, o - make slot free), m - show free memory, q - halt, c - clear screen, h - help, p - enter 32-bit land', 0

; Puts first FREE task slot in WAIT state
close_task_slot:
	push ax bx
	xor ax, ax
	xor bx, bx
	startcheck:
	mov ax, [TASK_T+bx]
	cmp ax, WAIT_T
	je incnext
	mov [TASK_T+bx], WAIT_T
	mov	si,taskwait
	mov	ah,01h
	int	50h
	pop ax bx
	jmp next
	
	incnext:
	add bx, 2
	xor ax, ax
	cmp bx, TOTAL_T
	jnz startcheck
	pop ax bx
	jmp next

; Attempts to free up task slot, by adding FREE state
open_task_slot:
	push ax bx
	xor ax, ax
	xor bx, bx
	@@:
	mov ax, [TASK_T+bx]
	cmp ax, WAIT_T
	je open
	xor ax, ax
	add bx, 2
	cmp bx, TOTAL_T
	jnz @b
	pop ax bx
	jmp next
	
	open:
	mov [TASK_T+bx], FREE_T
	mov	si,added
	mov	ah,01h
	int	50h
	pop ax bx
	jmp next
		
; Attempts to set task slot to EXEC, locks kernel
lock_task_slot:
	push ax bx
	xor ax, ax
	xor bx, bx
	@@:
	mov ax, [TASK_T+bx]
	cmp ax, WAIT_T
	je lockt
	xor ax, ax
	add bx, 2
	cmp bx, TOTAL_T
	jnz @b
	pop ax bx
	jmp next
	
	lockt:
	mov [TASK_T+bx], EXEC_T
	mov [klock], 1
	mov	si,added
	mov	ah,01h
	int	50h
	pop ax bx
	jmp next


; Task slot manager
task_man:
	push ax bx
	xor ax, ax
	xor bx, bx
	
create_task:
	; Check if free task slot available
	mov ax, [TASK_T+bx]
	cmp ax, FREE_T
	je found_free
	
	; Cannot find free task slot
	mov si, notfound
	mov	ah,01h
	int	50h
	; Put crlf into source index
	mov	si,line
	mov	ah,01h
	int	50h
	jmp check_next

found_free:
	mov si, found
	mov	ah,01h
	int	50h
	; Put crlf into source index
	mov	si,line
	mov	ah,01h
	int	50h
	
check_next:
	; Check next slot
	xor ax, ax
	add bx, 2
	cmp bx, TOTAL_T
	jne create_task
	pop ax bx
	jmp next

; Prints current task id state
; This will be in the main loop eventually
	push es
	mov ax, 0h ; Es starts
	mov es, ax
	xor di, di
	mov si, TASK_T
	
	printstate:
		lodsw
		mov ah, 15
		add al, '0'
		stosw
		cmp si, TASK_T+TOTAL_T*2
		jnz printstate
		mov di, [tid]
		inc di
		mov al, 12
		stosb
		pop es

boot_drive db 0 
line db crlf,0	
taskwait db 'Set slot to WAIT', 0 
added db 'Made slot free', 0 
found db 'Found free slot', 0   
notfound db 'Slot not free', 0
memfound db 'Available Memory (KB): ', 0

; Kernel lock state
klock rw 1
; Current task id
tid rw 1


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
	mov	  fs,ax
	mov   gs,ax

	; Poll 0x60 port for keyboard input
	; in	al, 0x60
	; cmp	al, 70h

	; Print welcome message
	mov	esi,welcome
	mov	ecx,welcome_size
	call character_print

MainLoop:
	hlt
	jmp	MainLoop

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

welcome db '32-bit mode enabled',0
welcome_size = $ - welcome

;times   300h - ($-$$)   nop ; Pad out to 768 bytes long