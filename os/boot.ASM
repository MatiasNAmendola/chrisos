format	binary
use16 
org	7c00h 
;The origin address which FASM will assume the program begins at when it is loaded into memory.
;ChrisOS bootsector


jmp	start 
nop 

;File System Info
OEM:			db "CHRIS OS"
bpbBytesPerSector:	dw 512 
bpbSectorsPerCluster:	db 1 
bpbReservedSectors:	dw 2880 
bpbNumberOfFATs:	db 2 
bpbRootEntries: 	dw 224 
bpbTotalSectors:	dw 2880 
bpbMedia:		db 0F0h 
bpbSectorsPerFAT:	dw 9 
bpbSectorsPerTrack:	dw 18 
bpbHeadsPerCylinder:	dw 2 
bpbHiddenSectors:	dd 0 
bpbTotalSectorsBig:	dd 0 
bsDriveNumber:		db 0 
bsUnused:		db 0 
bsExtBootSignature:	db 29h 
bsSerialNumber: 	dd 0 
bsVolumeLabel:		db "chrisOS       "
bsFileSystem:		db "FAT12   " 

start:
	cli	;Set up the segments and stack 
	xor	ax,ax  ;Clear ax
	mov	ds,ax  
	mov	es,ax
	mov	fs,ax
	mov	gs,ax
	
	;Instructions CS Code Segment All instruction fetches.


	mov	ax,0fffh
	mov	ss,ax
	mov	sp,0ffffh
	mov	bp,sp
	sti

  reset_floppy: ;Reset the drive, dl = drive
	mov	ah,00h 
	int	13h 
	jc	reset_floppy ;Try again if failed

  read_kernel: ;Load kernel from disk into memory
	mov	ax,0000h  
	mov	es,ax 
	mov	bx,1000h 
	;Buffer address pointer set to 0000h:1000h (PhysicalAddress = Segment * 16 + Offset)

	mov	ah,2 ;ah = 2
	mov	al,2 ;al = 2 Sectors To Read Count
	mov	ch,0 ;ch = 1 Track
	mov	cl,2 ;cl = 2 Sector
	mov	dh,0 ;dh = 0 Head

	int	13h	;Read 1 sector from drive into memory ES:BX     Buffer Address Pointer
	jc	read_kernel   ;If error, try again
	jmp	0000:1000h ;Jump to location where kernel starts in memory


times	510 - ($-$$)	nop 
	dw	0aa55h ;Boot sig