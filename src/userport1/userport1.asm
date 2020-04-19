*= $1001 "Basic Upstart"
BasicUpstart(start)    // 10 sys $1100
// SYS 4352

// 900F (36879) : Color of border and background 


// Entry point
* = $1100
start:
    // Make screen black and text white
    lda #$08        // 8 => Black border / Black background
    sta $900F       // 900F (36879) : Color of border and background 
    jsr $e55f       // ROM Clear screen
display:    
    
    jsr draw_text

    lda #81 // Just add some extra charaters on screen for fun
    sta $1E00
    sta $1E14

update_portb:
    jsr print_portb

 //   lda $C5         // Current key held down
    jsr $FFE4       // Kernal GETIN (Get character from keyboard)
    cmp #81         // This is Q
    beq quit

    jmp update_portb

quit:
    // Set colors back to normal
    lda #27        // 27 => Cyan border / White background
    sta $900F       // 900F (36879) : Color of border and background
    // Move the cursor to X=18 (row), Y=0 (column)
    ldx #18
    ldy #0
    clc
    jsr $FFF0       // Kernal PLOT (read or write cursor position)
    
    rts

title:
    .text "  port b controller   "
    
draw_text:
    ldx #$00
draw_loop:
    lda title,x
    sta $1E00,x
    lda #$5
    sta $9600,x
    inx
    cpx #$16
    bne draw_loop
    rts

print_portb:
    ldx #$08        // use X as loop counter init 8
    lda $9110       // Read port 9110 (37136) porb b address (9112 = DR register)
    sta $FB         // Local variable in zeropage page (FB to FE are not used by the OS)
    lda #$01        // First bit
    sta $FC         // Local variable. Current bit, init 0x00000001
bit_loop:
    lda $FB
    and $FC
    beq bit_not_set // AND will set Z if the result is 0
    
    lda #49         // bit is set = put character 1 in lda   (49 = "1") 
    jmp end_bit_loop
    
bit_not_set:
    lda #48         // bit is not set = put character 0 in lda   (48 = "0") 
    
end_bit_loop:

    sta $1E5D,x     // Write the character on the screen (location 1E00 + 5D)
    lda #$5         // Choose a color
    sta $965D,x     // Set the color of the charater on the screen (location 9600 + 5D)

    asl $FC         // Shift Left the $FC lacal variable to select the next bit

    dex             // Decrement X
    bne bit_loop    // Loop while X > 0
    rts
