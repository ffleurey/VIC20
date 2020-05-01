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

    lda #$01
    sta cursor

display:    
    
    jsr draw_text
    jsr draw_instr

update_portb:

    printBinary($9110, $005F, 'h', 'l', 5)
    printBinary(cursor, $005F-22, 113, ' ', 5)
    printBinary(cursor, $005F+22*3, 114, ' ', 5)
    printBinary($9112, $005F+22*2, 'o', 'i', 5)

    printBinary(161, $5D+22*12-4, '1', '0', 5)
    printBinary(162, $5D+22*12+5, '1', '0', 5)

 //   lda $C5         // Current key held down
    jsr $FFE4       // Kernal GETIN (Get character from keyboard)
    cmp #81         // This is Q => Quit
    beq quit
    cmp #66         // This is B => Move Cursor LEFT
    bne nxt1
    lda cursor
    asl
    bne nxt01
    lda #$01
nxt01:
    sta cursor
    jmp nxtdone
nxt1:
    cmp #78         // This is N => Move Cursor RIGHT
    bne nxt2
    lda cursor
    lsr
    bne nxt11
    lda #$80
nxt11:
    sta cursor
    jmp nxtdone
nxt2:
    cmp #73         // I => Set the selected as input
    bne nxt3
    lda cursor
    eor #$FF        // Invert the bits
    and $9112
    sta $9112
    jmp nxtdone
nxt3:
    cmp #79         // O => Set the selected as output
    bne nxt4
    lda cursor
    ora $9112
    sta $9112
    jmp nxtdone
nxt4:
    cmp #72         // H => Set the selected as high
    bne nxt5
    lda cursor
    ora $9110
    sta $9110
    jmp nxtdone
nxt5:
    cmp #76         // L => Set the selected as low
    bne nxt6
    lda cursor
    eor #$FF        // Invert the bits
    and $9110
    sta $9110
    jmp nxtdone
nxt6:
nxtdone:
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
    .text "  user port monitor   "

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

instr:
    .text "        bit  ddr  val  keys:  b/n  i/o  h/l                        exit:  q            "
draw_instr:
    ldx #$00
instr_loop:
    lda instr,x
    sta $1E00+10*22,x
    lda #$7
    sta $9600+10*22,x
    inx
    cpx #78
    bne instr_loop
    rts

cursor:
    .byte $01

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