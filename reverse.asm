; A little program that reads in a string from the user, reverses it, and then prints it back out
; NASM format 
; This is ridiculously commented because I've wanted to make sure I am there with the flow of logic of x86 ASM 

org 100h

INPUT_LENGTH  EQU  64           ; How many bytes to make the string
PrintInput:
    mov ah, 09h
    mov dx, InputString
    int 21h
ReadStuff:
    mov  ah, 3Fh                ; Telling DOS we are going to read from something (3fh means reading in)
    mov  bx, 0                  ; And 0 in BX along with that means we are reading from the keyboard (stdin)
    mov  cx, INPUT_LENGTH       ; How many bytes to read
    mov  dx, ForwardString
    int  21h
    and  ax, ax                 ; Check if AX is 0, which means the 0 flag is set. AX is 0 if the user didn't enter anything
    jz   Done                   ; If the user didn't enter anything, we just jumpt to the end and quit, otherwise we continue on to flip the string  
    mov  cx, ax                 ; AX keeps the number of bytes read after a read, so we move it to the CX to use it for counting 
    

TrimLoop:                       ; We need to take off any CR or LF chars at the end of the string, because they cause things to be improperly formatted
    mov si, ForwardString
    add si, cx                  
    dec si                      
    cmp byte [si], 13           ; CR?
    je  StripOne
    cmp byte [si], 10           ; LF?
    je  StripOne                ; If it's either of those chars, we strip it and then check the next in a loop 
    jmp LenGood                 ; If it's not either, or 0 (below), then we're golden and we can move on 
StripOne:                       
    dec cx
    jcxz Done                   ; If the user only entered return, then after stripping there's nothing left, so we'll quit just like above 
    jmp TrimLoop

LenGood:
    push cx                     ; Push it to the stack for later (as this tells us how long the string is, and this is before we will be decrementing it)
    mov  bx, ForwardString
    mov  si, BackwardString
    add  si, cx
    dec  si
ReverseLoop:                    ; CX will decrement around this little loop between the ReverseLoop label and the loop instruction until it is 0 
    mov  al, [bx]               ; Since be is our index, we move the byte that's at that index into AL to do stuff with it 
    mov  [si], al               ; And then we move that byte into its corresponding place in the backwards string 
    inc  bx                     ; Increment our counter for the normal string
    dec  si                     ; And correspondingly decrement our counter for the backwards one 
    loop ReverseLoop            ; Loop always decrements CX, so we just continue until we've hit 0, which means the whole string
    pop  cx                     ; CX became 0 after the loop, but we need it to show the length again, so we just pop it back from the stack where we'd put it
    push cx                     ; Keep the reversed length safe across the AH=09h call below
PrintOutput:                               
    mov  ah, 09h                ; 09h in AH means print a string, specifically it prints the string pointed to by DX, and it also needs to be ended explicitly (see $)
    mov  dx, OutputString
    int  21h
    pop  cx                     ; Restore byte count for AH=40h write
    mov  ah, 40h                ; 40h in AH means writing to something, as opposed to 3fh which was reading. 
    mov  bx, 1                  ; And whilst 0 means reading from stdin (the keyboard), 1 here means writing to stdout (the console) 
    mov  dx, BackwardString     ; Point now to the fully reversed string in memory 
    int  21h                    ; And then calls 21h which, I'm sure you'd have guessed by now, executes a write to the console 
NewLine:
    mov ah, 2h
    mov dl, 10
    int 21h
    mov dl, 13
    int 21h
Done:
    mov  ax, 4C00h              ; 4C00h in AX is an exit code. Think returning 0 in C, but here we just put this value in AX and call 21h to quit 
    int  21h                    ; And once again we call 21h, which executes an exit instruction 

ForwardString     times INPUT_LENGTH db 0
BackwardString    times INPUT_LENGTH db 0

InputString  db 'Enter a string to reverse: $' ; User prompt 
OutputString db 'The reversed string is: $'    ; Ditto 