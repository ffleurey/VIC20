*= $1001 "Basic Upstart"
BasicUpstart(start)    // 10 sys $1100
// SYS 4352

// 900F (36879) : Color of border and background 

// Entry point
* = $1100
start:
    // Make screen black and text white
    lda #31        // 8 => Yellow border / White background
    sta $900F       // 900F (36879) : Color of border and background 
    jsr $e55f       // ROM Clear screen

    // Add our own interrupt routine
    sei

    lda #<irq     // set the IRQ routine pointer
    sta $0314
    lda #>irq
    sta $0315

    // Set the timer to 0x5686 (ie 1 frame at 1.018MHz)
    // This modifies the speed of the jiffy clock
    lda #<$5686
    sta $9124
    lda #>$5686
    sta $9125

    // Enable Timer 1/A free run on VIA 1
    lda $912b
    and #%01111111
    ora #%01000000
    sta $912b

    // enable Timer A underflow interrupts
    lda #%11000000
    sta $912e

    cli

mainloop:

    jsr $FFE4       // Kernal GETIN (Get character from keyboard)
    cmp #81         // This is Q => Quit
    beq quit

    // Yellow border
    lda #31        
    sta $900F      


    printBinary(161, $5D+22*4-4, '1', '0', 0)
    printBinary(162, $5D+22*4+5, '1', '0', 0)


    jmp mainloop

quit:
    // set the IRQ routine pointer back to normal
    sei
    lda #<$EABF
    sta $0314
    lda #>$EABF
    sta $0315
    cli
    // Set colors back to normal
    lda #27        // 27 => Cyan border / White background
    sta $900F       // 900F (36879) : Color of border and background
    // Move the cursor to X=18 (row), Y=0 (column)
    ldx #18
    ldy #0
    clc
    jsr $FFF0       // Kernal PLOT (read or write cursor position)
    rts



irq:        // The cpu state has been saved by the kernal

    // Check if it is a via 2 interrupt
    bit $912d
    bmi irq_via2
    //jmp irq_rti
    // Let the kernal handle other interrupts
irq_kernal:
    jmp $eabf     // jump to normal IRQ

irq_via2:
    // Read the low bytes of the counter to clear the interrupt flag
    //bit  $9124  

    // Red border
    lda #26        
    sta $900F
    jmp irq_kernal


// This is what to do to return from interrupt if not calling the kernal routine.
irq_rti:        // Restore cpu state and return from interrupt
    pla
    tay
    pla
    tax
    pla
    rti



// This is an active wait on a specific raster line.    
raster_wait:
    lda $9004
    cmp #80    // Wait for line 80 (somewhere in the middle)
    bne raster_wait
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