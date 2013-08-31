format	binary
use16 

;The origin address which FASM will assume the program begins at when it is loaded into memory
org	7c00h 

jmp	start 
nop 

;File System Info
OEM:					db "CHRIS OS"
bpbBytesPerSector:		dw 512 
bpbSectorsPerCluster:	db 1 
bpbReservedSectors:		dw 2880 
bpbNumberOfFATs:		db 2 
bpbRootEntries: 		dw 224 
bpbTotalSectors:		dw 2880 
bpbMedia:				db 0F0h 
bpbSectorsPerFAT:		dw 9 
bpbSectorsPerTrack:		dw 18 
bpbHeadsPerCylinder:	dw 2 
bpbHiddenSectors:		dd 0 
bpbTotalSectorsBig:		dd 0 
bsDriveNumber:			db 0 
bsUnused:				db 0 
bsExtBootSignature:		db 29h 
bsSerialNumber: 		dd 0 
bsVolumeLabel:			db "chrisOS       "
bsFileSystem:			db "FAT12   " 

start:
	; Set up stack and segment registers
	; Stop interrupts
	cli
	xor	ax,ax  
	mov	ds,ax 
	mov	es,ax
	mov	fs,ax
	mov	gs,ax
	
	mov	ax,0fffh
	mov	ss,ax ;Segment where stack is located in memory
	mov	sp,0ffffh 
	mov	bp,sp 
	; Enable interrupts
	sti

	reset_floppy:
	mov	ah,00h 
	int	13h 
	jc	reset_floppy 
	
	; Load kernel from disk into memory     
	read_kernel:
	mov	ax,0000h  
	mov	es,ax 
	mov	bx,1000h 

	mov	ah,2
	mov	al,2
	mov	ch,0
	mov	cl,2
	mov	dh,0
	
	; Read 1 sector from drive into memory ES:BX
	int	13h
	jc	read_kernel
	; Jump to location where kernel starts in memory
	jmp	0000:1000h

; Pad out to 512 bytes
times	510 - ($-$$)	nop 
; Boot signature
dw	0aa55h