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

    // Set the timer to 0x5686 (0x5688 = 1 frame at 1.018MHz)
    // This modifies the speed of the jiffy clock
    lda #<$5686
    sta $9124
    ldx #>$5686

    // Sync after drawing the character screen
    jsr raster_wait     // Wait until a specific line

    stx $9125 // Start counting

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

    jmp mainloop

quit:
    jmp $FED2       // Dirty jump to the Kernal BRK Handler to skip any cleanup and restore


irq:            // The cpu state has been saved by the kernal
    bit $912d   // Check if it is a via 2 interrupt
    bmi irq_via2
irq_kernal:
    jmp $eabf     // jump to normal IRQ

irq_via2:
    // Red border
    lda #26        
    sta $900F

    printBinary(161, $5D+22*4-4, '1', '0', 0)
    printBinary(162, $5D+22*4+5, '1', '0', 0)

    jsr la_capture_one_bit

    jmp irq_kernal

// This is an active wait on a specific raster line.    
raster_wait:
    lda $9004
    cmp #131    // Wait for line 80 (somewhere in the middle)
    bne raster_wait
    rts



// Data for the logic analyser. 32 bytes (256 bits) for each channel
// x 8 chanels = 256 bytes of data
la_data:
    .fill 256, 0 // Generates byte 0,0,0,0,0
la_index:
    .byte 0
la_wrap:
    .byte 22
la_addr:
    .word 162
la_bit:
    .byte %00100000

la_index_y:
    .byte 0

la_capture_one_bit:

   
// Set the array index in Y 
    lda la_index    
    lsr             // Shift Right 3 times to keep the index betwwen 0 and 31
    lsr
    lsr
    tay             // Put it in Y
    sty la_index_y

// Set the right bit in X
    lda #%00000111
    and la_index
    tax
    lda #%10000000
bitsetloop:
    cpx #0
    beq bitsetloop_end
    dex
    lsr
    jmp bitsetloop
bitsetloop_end:
    tax

// Read the bit we are intereted in an store it
    lda la_addr
    sta $FD
    lda la_addr+1
    sta $FE
    ldy #0
    lda ($FD),y
    and la_bit
    bne bit_is_1

bit_is_0:
    txa
    eor #$FF
    ldy la_index_y
    and la_data, y
    sta la_data, y
    jmp end_if_set_bit
bit_is_1:
    txa
    ldy la_index_y
    ora la_data, y
    sta la_data, y

end_if_set_bit:

    jsr la_draw_line

// Increment the index
    inc la_index
    lda la_wrap
    asl
    asl
    asl
    cmp la_index
    bne done_incrementing
    lda #0
    sta la_index

done_incrementing:

    rts

la_draw_line_pos:
    .word $0000+22*12
la_draw_line_color:
    .byte 2

la_draw_line:
    clc
    lda #$00            // Set the position of where to write on screen in FD FE
    adc la_draw_line_pos
    sta $FD
    lda #$1E
    adc la_draw_line_pos+1
    sta $FE
    // Set the array index in Y 
    lda la_index    
    lsr             // Shift Right 3 times to keep the index betwwen 0 and 31
    lsr
    lsr
    tay             // Put it in Y
draw_current_char:
    lda la_data, y
    beq draw_0
    cmp #$FF
    beq draw_1
    lda #102        // Mixed
    jmp draw_char
draw_0:
    lda #100        // Down
    jmp draw_char
draw_1:
    lda #128+100         // Up
    jmp draw_char
draw_char:

    sta ($FD),y
    
    clc
    lda #$78
    adc $FE
    sta $FE

    lda la_draw_line_color  // Choose a color
    sta ($FD),y     // Set the color of the charater on the screen (location 9600 + 5D)
    
done_update_prev_color:
    clc
    lda #(-$78)
    adc $FE
    sta $FE

    rts

#import "../_lib/PrintBinary.asm"