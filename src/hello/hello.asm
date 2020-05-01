*= $1001 "Basic Upstart"
BasicUpstart(start)    // 10 sys $1100
// SYS 4352

// 900F (36879) : Color of border and background 

// Entry point
* = $1100
start:

    // ROM Clear screen
    jsr $e55f       
    jsr draw_text
    
    // Move the cursor to X=18 (row), Y=0 (column)
    ldx #16
    ldy #0
    clc
    jsr $FFF0       // Kernal PLOT (read or write cursor position)
    rts 

title:
    .text "    hello vic-20 !    "
colors:
    .byte 0,0,0,0,0,2,3,4,5,0,6,7,2,3,4,5,0,6,0,0,0,0
    
draw_text:
    ldx #$00
draw_loop:
    lda title,x
    sta $1E00+22*6,x    // Set the character on the screen
    lda colors,x
    sta $9600+22*6,x    // Set the color of the character
    inx
    cpx #$16
    bne draw_loop
    rts