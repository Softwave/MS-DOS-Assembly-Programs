; Trippy plasma toy for MS-DOS 
; Based on various examples 
; NASM plas.asm -o plas.com -f bin
; (c) S0ftwave, 2026 https://s0ftwave.net/

org 100h

start:
    mov ax, 0x0013          ; Enter mode 13
    int 0x10                ; Call BIOS thingy that changes screen mode

    ;; Palette
    mov dx, 0x3C8           ; Point at the VGA palette write index port
    xor al, al              ; 0 out al so we start writing at palette index 0
    out dx, al              
    inc dx                  ; Cheeky to inc here 
    xor bl, bl              ; BL is our loop counter so we 0 it out
.pal:
    mov al, bl              ; Red, closer to blue phase so it mixes more violet
    add al, 68
    test al, 0x80           ; We AND it with 0x80/128 to see if our colour value is past halfway
    jz .pr                  
    not al                  ; We invert the bits if we're in the 2nd half
.pr:
    shr al, 1
    out dx, al              ; Red out 

    mov al, bl
    add al, 176
    test al, 0x80           ; Same test
    jz .pg                      
    not al
.pg:
    shr al, 4
    out dx, al              ; We send green to VGA

    mov al, bl
    add al, 8
    test al, 0x80
    jz .pb              
    not al
.pb:
    shr al, 1
    out dx, al

    inc bl
    jnz .pal

    ;; We are going to use the FPU to calculate a sine table
    finit                   ; Zero out the FPU
    fldpi                   ; PI on the FPU 
    fadd st0                ; Floating point addition, how fancy! Now 2pi
    fild word [n256]        ; Put 256 on there. 
    fdivp st1               ; Step size 
    fldz                    

    mov di, sintab          ; Point DI at the start of our sine table in memory
    mov cx, 256             
.sg:
    fld st0                 ; 2x
    fsin                    ; Calc the sine of whatever is in st0 and replace it
    fcos
    fld1                   
    faddp st1               ; 0-2
    fild word [n127]        
    fmulp st1               ; Remap again
    fistp word [wtmp]       ; Store the integer value of that in wtmp and pop it from the stack 
    mov al, [wtmp]          
    mov [di], al            ; Move into our table in RAM
    inc di
    fadd st1                ; +step 
    loop .sg

    fstp st0                ; Clean shiz 
    fstp st0                ; Ditto

    
    mov ax, 0xA000          ; This is the start of VIDEO RAM for mode13h
    mov es, ax              ; Point ES there so we can write to vRAM using offsets from ES

;; Enabling vsync and getting rid of tears
.frame:
    mov dx, 0x3DA           ; Status port of the VGA card. We can test bit 3 to track where we are in screen draw times.
.vs1:in  al, dx             
    test al, 8              ; Is the monitor drawing?
    jnz .vs1                
.vs2:in  al, dx
    test al, 8              ; Is the monitor drawing?
    jz  .vs2                ; Now we move on when it IS because 3 is not set 


    xor ah, ah              
    int 0x1A                ; Timer interrupt. Returns time to CX:DX. This is our delta time.
    mov [t], dl             

    xor di, di              ; Start at the left of the screen (0)
    mov word [yv], 0        ; Y = 0
.yl:
    xor cx, cx              ; X = 0
.xl:

    ;; Horizontal, 1x speed
    ;; Sin(x/2+t)
    movzx si, byte [t]          ; SI = t
    mov ax, cx              
    shr ax, 1                   ; Shift right to divide by 2 -- X/2
    add si, ax                  ; t+X/2
    and si, 0x00FF              ; Keep within bounds
    movzx si, byte [sintab+si]  ; SI contains horizontal wave 

    ;; Vertical, 3x speed
    ;; Sin(Y/2+3t)
    movzx ax, byte [t]
    imul ax, ax, 3
    mov bx, [yv]
    shr bx, 1
    add ax, bx
    and ax, 0x00FF
    mov bx, ax                  
    movzx dx, byte [sintab+bx]
    add si, dx

    ;; Diagonal, 5x speed
    ;; Sin((X+Y)/4+5t)
    movzx ax, byte [t]
    imul ax, ax, 5
    mov bx, [yv]
    add bx, cx              
    shr bx, 0
    add ax, bx
    and ax, 0x00FF
    mov bx, ax
    movzx dx, byte [sintab+bx]
    add si, dx

    ;; Radial, 7x speed
    ;; Sin(sqrt((X-160)^2+(Y-100)^2)/4 
    ;; Very famous plasma wave, this 
    movzx ax, byte [t]
    imul ax, ax, 7
    mov bx, cx
    sub bx, 160
    jns .px
    neg bx

.px:
    mov [wtmp], bx            
    mov bx, [yv]
    sub bx, 100
    jns .py
    neg bx
.py:
    add bx, [wtmp]             
    shr bx, 1
    add ax, bx
    and ax, 0x00FF
    mov bx, ax
    movzx dx, byte [sintab+bx]
    add si, dx    ; Add to the rest

  
    mov ax, si                  
    stosb                       ; Trippy! Write AL to ES:DI 

    inc cx
    cmp cx, 320
    jl .xl

    inc word [yv]
    cmp word [yv], 200
    jl .yl

    ;; Check for keys
    mov ah, 0x01
    int 0x16
    jz .frame


    ;; Back to text mode
    mov ax, 0x0003
    int 0x10
    ret                         ; Quit

;; Vars and stuff
n127    dw 127
n256    dw 256
wtmp    dw 0
yv      dw 0
t       db 0

sintab: times 256 db 0 ; FPU filled table 
