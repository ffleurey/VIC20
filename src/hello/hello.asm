*= $1001 "Basic Upstart"
BasicUpstart(start)    // 10 sys $1100
// SYS 4352

// 900F (36879) : Color of border and background 

// Entry point
* = $1100
start:

    // ROM Clear screen
    jsr $e55f       

    // Move the cursor to X=18 (row), Y=0 (column)
    ldx #2
    ldy #6
    clc
    jsr $FFF0       // Kernal PLOT (read or write cursor position)

    jsr print_string
    
    // Move the cursor to X=18 (row), Y=0 (column)
    ldx #16
    ldy #0
    clc
    jsr $FFF0       // Kernal PLOT (read or write cursor position)
    rts 

message:
    .byte 28 // RED
    .byte 18 // REVERSE ON
    .text "HELLO:VIC"
    .byte 146 // REVERSE OFF
    .byte 31 // BLUE
    .byte 0
    
print_string:
    ldx #0
print_loop:
    lda message, x
    beq end_of_string
    jsr $E742       // Kernal output character to screen
    inx
    jmp print_loop
end_of_string:
    rts