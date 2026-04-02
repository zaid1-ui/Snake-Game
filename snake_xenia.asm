[org 0x100]
jmp start
sanke dw 2000 dup(0)
score dw 0
snk_size:dw 1
temp:dw 0
apple_pos dw 0       ; Position of the apple
last_direction db 'R' ; R = right, L = left, U = up, D = down

; ────────────────────────────────────────────────
; Subroutine: making_board
; Description: Draws the initial game board with borders
making_board:
pushad
mov ax, 0xB800       
mov es, ax           
xor di, di    
mov di, 2
mov ah, 0x0F     ; white on black
mov al,'S'
mov [es:di], ax
add di, 2
mov al, 'C'
mov [es:di], ax
add di, 2
mov al, 'O'
mov [es:di], ax
add di, 2
mov al, 'R'
mov [es:di], ax
add di, 2
mov al, 'E'
mov [es:di], ax
add di, 2
mov al, ':'
mov [es:di], ax
add di, 2
       
mov ax,  0x0020        ; black background with space character
mov cx, 2000         
cld                   
rep stosw

mov ah, 0x0F     ; white on black
mov al, '|'
mov cx,80
mov di, -2
mb1:
add di,2
mov [es:di],ax
add di,158
mov [es:di],ax
loop mb1

mov ah, 0x0F     ; white on black
mov al, '-'
mov cx,78
mov di,162
mb2:
mov [es:di],ax
add di,2
loop mb2

mov ah, 0x0F     ; white on black
mov al, '-'
mov cx,78
mov di,3842
mb3:
mov [es:di],ax
add di,2
loop mb3
popad
ret

; ────────────────────────────────────────────────
; Subroutine: move_snake
; Description: Main loop to move the snake and read keyboard input
move_snake:
    pushad
    mov ax, 0xB800
    mov es, ax
    mov di, 1000        ; Initial snake position
    mov [sanke], di     ; Initialize snake head position

    mov byte [last_direction], 'R'

    main_loop:
        ; Check for keyboard input
        mov ah, 01h
        int 16h
        jz no_key_press

        ; Get the key
        mov ah, 00h
        int 16h
        
        ; Check which key was pressed
        cmp ah, 4Bh      ; Left arrow
        je set_left
        cmp ah, 4Dh      ; Right arrow
        je set_right
        cmp ah, 50h      ; Down arrow
        je set_down
        cmp ah, 48h      ; Up arrow
        je set_up
        jmp no_key_press

    set_left:
        cmp byte [last_direction], 'R'  ; Prevent 180-degree turn
        je no_key_press
        mov byte [last_direction], 'L'
        jmp no_key_press
    set_right:
        cmp byte [last_direction], 'L'  ; Prevent 180-degree turn
        je no_key_press
        mov byte [last_direction], 'R'
        jmp no_key_press
    set_down:
        cmp byte [last_direction], 'U'   ; Prevent 180-degree turn
        je no_key_press
        mov byte [last_direction], 'D'
        jmp no_key_press
    set_up:
        cmp byte [last_direction], 'D'   ; Prevent 180-degree turn
        je no_key_press
        mov byte [last_direction], 'U'
        jmp no_key_press

    no_key_press:
        ; Move according to last direction
        mov al, [last_direction]
        cmp al, 'R'
        je mov_right
        cmp al, 'L'
        je mov_left
        cmp al, 'U'
        je mov_up
        cmp al, 'D'
        je mov_down
        jmp main_loop

    mov_right:
        add di, 2
        call check
        call move_snake_direction
        jmp delay_and_continue

    mov_left:
        sub di, 2
        call check
        call move_snake_direction
        jmp delay_and_continue

    mov_up:
        sub di, 160
        call check
        call move_snake_direction
        jmp delay_and_continue

    mov_down:
        add di, 160
        call check
        call move_snake_direction
        jmp delay_and_continue

    delay_and_continue:
        call delay
        jmp main_loop
    
    popad
    ret

; ────────────────────────────────────────────────
; Subroutine: move_snake_direction
; Description: Updates snake body positions and draws them
move_snake_direction:
push ax
push bx
push cx
push dx
push si
push di

mov bx, di
mov cx, [snk_size]
shl cx, 1
mov si, 0
.erase_loop:
mov di, [sanke + si]
mov ax,  0x0020 ; black background with space
mov [es:di], ax
add si, 2
cmp si, cx
jl .erase_loop

mov cx, [snk_size]
dec cx
shl cx, 1
mov si, cx
.shift_loop:
cmp si, 0
je .done_shift
mov ax, [sanke + si - 2]
mov [sanke + si], ax
sub si, 2
jmp .shift_loop

.done_shift:
mov [sanke], bx

mov cx, [snk_size]
shl cx, 1
mov si, 0
.draw_loop:
mov di, [sanke + si]
cmp si, 0
jne .not_head
 mov ax,  0x0E4F  ; yellow 'O' on black (head)
jmp .write_char

.not_head:
mov ax, 0x0A4F    ; green 'O' on black (body)

.write_char:
mov [es:di], ax
add si, 2
cmp si, cx
jl .draw_loop

pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

; ────────────────────────────────────────────────
; Subroutine: apple
; Description: Generates an apple in a valid random position
apple:
    pushad

ap1:
    mov ah, 00h            ; Get system time
    int 1Ah
    mov ax, dx
    xor dx, dx
    mov cx, 3677           ; Randomize with divisor
    div cx
    add dx, 162            ; Offset to the screen
    and dx, 0xFFFE         ; Ensure the address is even
    mov si, dx

    ; Check if the apple is in the first two rows
    mov ax, si
    cmp ax, 0x200
    jb ap1

    ; Check if the apple is in the first or last column
    mov ax, si
    mov bx, 160
    xor dx, dx
    div bx
    cmp dx, 0
    je ap1
    cmp dx, 158
    je ap1

    ; Check if apple overlaps with snake
    mov cx, [snk_size]
    mov di, 0
.check_snake:
    cmp si, [sanke + di]
    je ap1                ; If overlapping, try again
    add di, 2
    loop .check_snake

    mov [apple_pos], si

    ; Display the apple on the screen
    mov di, si
    mov ax, 0xB800
    mov es, ax

    ; Set red '*' on black background
    mov al, '*'
    mov ah, 0x0C
    mov [es:di], ax

    popad
    ret

; ────────────────────────────────────────────────
; Subroutine: update_score
; Description: Increments and displays the score at top-left
update_score:
push ax
push bx
push cx
push dx
push si
push di

mov ax, [score]
add ax, 10
mov [score], ax

; Convert score to decimal ASCII
mov bx, 10
mov cx, 0
mov si, 0
mov dx, 0

.store_digits:
xor dx, dx
div bx
push dx
inc cx
cmp ax, 0
jne .store_digits

; Display digits at DI = 2 + 14 (after "SCORE: ")
mov ax, 0xB800
mov es, ax
mov di, 2
add di, 14

.print_digits:
pop dx
add dl, '0'
mov ah, 0x0F     ; white on black
mov al, dl
mov [es:di], ax
add di, 2
loop .print_digits

pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

; ────────────────────────────────────────────────
; Subroutine: delay
; Description: Slows down the snake movement
delay:
push cx
push dx
mov cx, 0AAAh
mov dx, 05h
delay_outer:
push dx
delay_loop:
nop
loop delay_loop
pop dx
dec dx
jnz delay_outer
pop dx
pop cx
ret

; ────────────────────────────────────────────────
; Subroutine: check
; Description: Detects collision and apple consumption
check:
push ax
push bx
push dx
push cx
push si
push di

; Check wall collisions
cmp di, 160            ; Top border
jl end_game
cmp di, 3840           ; Bottom border
jge end_game

mov ax, di
mov bx, 160
xor dx, dx
div bx
cmp dx, 0              ; Left border
je end_game
cmp dx, 158            ; Right border
je end_game

; Check self-collision
mov cx, [snk_size]
mov si, 2              ; Start from second segment
.self_check:
cmp di, [sanke + si]
je end_game
add si, 2
loop .self_check

; Check apple collision
cmp di, [apple_pos]
je growt
jmp skip

growt:
mov cx, [snk_size]
inc cx
mov [snk_size], cx

; Shift snake body
mov cx, [snk_size]
dec cx
shl cx, 1
mov si, cx
.grow_shift_loop:
cmp si, 0
je .done_shift
mov ax, [sanke + si - 2]
mov [sanke + si], ax
sub si, 2
jmp .grow_shift_loop

.done_shift:
mov [sanke], di

; Redraw snake
mov cx, [snk_size]
shl cx, 1
mov si, 0
.draw_loop:
mov di, [sanke + si]
cmp si, 0
jne .not_head
mov ax, 0x0E4F
jmp .write_char

.not_head:
mov ax, 0x0A4F

.write_char:
mov [es:di], ax
add si, 2
cmp si, cx
jl .draw_loop

call apple
call update_score
skip:
pop di
pop si
pop cx
pop dx
pop bx
pop ax
ret

; ────────────────────────────────────────────────
; Subroutine: end_game
; Description: Ends the game and asks for restart
end_game:
    mov ax, 0xB800
    mov es, ax
    mov di, 80
    mov ah, 0x0F            ; white on black
    mov al, 'G'
    mov [es:di], ax
    add di, 2
    mov al, 'A'
    mov [es:di], ax
    add di, 2
    mov al, 'M'
    mov [es:di], ax
    add di, 2
    mov al, 'E'
    mov [es:di], ax
    add di, 2
    mov al, ' '
    mov [es:di], ax
    add di, 2
    mov al, 'O'
    mov [es:di], ax
    add di, 2
    mov al, 'V'
    mov [es:di], ax
    add di, 2
    mov al, 'E'
    mov [es:di], ax
    add di, 2
    mov al, 'R'
    mov [es:di], ax
    add di, 2

    ; "Restart? (Y/N)"
    mov di, 160
    mov al, 'R'
    mov [es:di], ax
    add di, 2
    mov al, 'e'
    mov [es:di], ax
    add di, 2
    mov al, 's'
    mov [es:di], ax
    add di, 2
    mov al, 't'
    mov [es:di], ax
    add di, 2
    mov al, 'a'
    mov [es:di], ax
    add di, 2
    mov al, 'r'
    mov [es:di], ax
    add di, 2
    mov al, 't'
    mov [es:di], ax
    add di, 2
    mov al, '?'
    mov [es:di], ax
    add di, 2
    mov al, ' '
    mov [es:di], ax
    add di, 2
    mov al, '('
    mov [es:di], ax
    add di, 2
    mov al, 'Y'
    mov [es:di], ax
    add di, 2
    mov al, '/'
    mov [es:di], ax
    add di, 2
    mov al, 'N'
    mov [es:di], ax
    add di, 2
    mov al, ')'
    mov [es:di], ax
    add di, 2

.wait_key:
    mov ah, 00h
    int 16h
    cmp al, 'Y'
    je restart_game
    cmp al, 'y'
    je restart_game
    cmp al, 'N'
    je exit_game
    cmp al, 'n'
    je exit_game
    jmp .wait_key

restart_game:
    mov word [score], 0
    mov word [snk_size], 1
    mov word [apple_pos], 0
    call making_board
    call apple
    call move_snake
    ret

exit_game:
    mov ax, 0x4C00
    int 21h

; ────────────────────────────────────────────────
; Program entry point
start:
call making_board
call apple
call move_snake

mov ax, 0x4C00
int 0x21