*= $1001 "Basic Upstart"
BasicUpstart(start)    // 10 sys $1100

// Some good info in https://www.atarimagazines.com/compute/issue43/237_1_VIC_64_Clock.php


// Entry point
* = $1100
start:
    // Make screen black and text white
    lda #$08        // 8 => Black border / Black background
    sta $900F       // 900F (36879) : Color of border and background 
    jsr $e55f       // ROM Clear screen

display:    
    
    jsr draw_text

main_loop:

    //printBinary(160, $5D+22*4-9, '1', '0', 5)
    printBinary(161, $5D+22*4-4, '1', '0', 7)
    printBinary(162, $5D+22*4+5, '1', '0', 7)

 //   lda $C5         // Current key held down
    jsr $FFE4       // Kernal GETIN (Get character from keyboard)
    cmp #81         // This is Q => Quit
    beq quit
    jmp main_loop

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
    .text " jiffy clock monitor  "

draw_text:
    ldx #$00
draw_loop:
    lda title,x
    sta $1E00,x
    lda #$5
    sta $9600,x
    inx
    cpx #22
    bne draw_loop
    rts


binprint_addr:
    .word $9110         // Read port 9110 (37136) porb b address (9112 = DR register)
binprint_pos:
    .word $005D
binprint_h:
    .byte '1'
binprint_l:
    .byte '0'
binprint_c:
    .byte $5

binprint:

    lda binprint_addr   // Put the adress of the regiter to zero page FD and FE
    sta $FD
    lda binprint_addr+1
    sta $FE
    ldy #$0
    lda ($FD),y         // Load from address requested in binprint_addr
    sta $FB             // Local variable in zeropage page (FB to FE are not used by the OS)
    lda #$01            // First bit
    sta $FC             // Local variable. Current bit, init 0x00000001
    ldy #$08            // use Y as loop counter init 8

    clc
    lda #$00            // Set the position of where to write on screen in FD FE
    adc binprint_pos
    sta $FD
    lda #$1E
    adc binprint_pos+1
    sta $FE

bit_loop:
    lda $FB
    and $FC
    beq bit_not_set // AND will set Z if the result is 0
    
    lda binprint_h  // bit is set = put character 1 in lda   (49 = "1") 
    jmp end_bit_loop
    
bit_not_set:
    lda binprint_l  // bit is not set = put character 0 in lda   (48 = "0") 
    
end_bit_loop:

    sta ($FD),y     // Write the character on the screen (location 1E00 + 5D)
    
    clc
    lda #$78
    adc $FE
    sta $FE

    lda binprint_c  // Choose a color
    sta ($FD),y     // Set the color of the charater on the screen (location 9600 + 5D)

    clc
    lda #(-$78)
    adc $FE
    sta $FE

    asl $FC         // Shift Left the $FC lacal variable to select the next bit

    dey             // Decrement Y
    bne bit_loop    // Loop while Y > 0
    rts

.function _16bitnextArgument(arg) {
    .if (arg.getType()==AT_IMMEDIATE)
    .return CmdArgument(arg.getType(),>arg.getValue())
    .return CmdArgument(arg.getType(),arg.getValue()+1)
}

.pseudocommand mov16 src:tar {
 lda src
 sta tar
 lda _16bitnextArgument(src)
 sta _16bitnextArgument(tar)
}

.pseudocommand mov src:tar {
 lda src
 sta tar
}

.macro printBinary(addr, scrOffset, charH, charL, color) {
    mov16   #addr       : binprint_addr
    mov16   #scrOffset  : binprint_pos
    mov     #charH      : binprint_h
    mov     #charL      : binprint_l
    mov     #color      : binprint_c
    jsr     binprint
}