*= $1001 "Basic Upstart"
BasicUpstart(start)    // 10 sys $1100

// Entry point
* = $1010 "Program Code"
start:
    // Make screen black and text white
    lda #31        // 8 => Yellow border / White background
    sta $900F       // 900F (36879) : Color of border and background 
    jsr $e55f       // ROM Clear screen

    jsr create_custom_characters

    // Add our own interrupt routine
    sei

    

    lda #<irq     // set the IRQ routine pointer
    sta $0314
    lda #>irq
    sta $0315

    // Set the timer to 0x5686 (0x5688 = 1 frame at 1.018MHz)
    // This modifies the speed of the jiffy clock
    // Do 2 inntterupts er frame: 100 Hz => 2B42
    lda #<$2B42
    sta $9124
    ldx #>$2B42

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

    jsr enable_custom_char

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

    lda $9004
    cmp #50    // Check where we are in the frame
    bcc top_of_the_frame 
    jmp middle_of_the_frame

top_of_the_frame:
    // Red border
    lda #26        
    sta $900F
    
    jsr disable_custom_char
    printBinary(162, $5D+22*6+5, '1', '0', 0)
    jsr la_capture_one_bit
    bit  $9124      // Read the low bytes of the counter to clear the interrupt flag
    jmp irq_rti

middle_of_the_frame:
    // Blue border
    lda #30        
    sta $900F

    jsr enable_custom_char
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
    cmp #85    // Wait for line 80 (somewhere in the middle)
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
    .byte %10000000

la_index_y:
    .byte 0

la_capture_one_bit:

   // Init with the msb
   lda #%10000000
   sta la_bit

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
loop_over_bits:
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
    // go to the next bit
    lsr la_bit
    beq end_loop_over_bits
    clc
    lda la_index_y
    adc #32
    sta la_index_y
    jmp loop_over_bits

end_loop_over_bits:

    // Update the display
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
    .word $0000 + 22*14
la_draw_line_color:
    .byte 0

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
    sta $FB             // Use FB to store index in the data
    sta $FC             // Use FB to store index on the screen

    ldx #8           // Count the 8 bits / lines

draw_char_loop:
    ldy $FB
    lda la_data, y
    
    ldy $FC
    sta ($FD),y
    
    clc
    lda #$78
    adc $FE
    sta $FE
    
    lda la_draw_line_color  // Choose a color
    sta ($FD),y     // Set the color of the charater on the screen (location 9600 + 5D)
    
    clc
    lda #(-$78)
    adc $FE
    sta $FE

    dex
    beq end_draw_char_loop

    clc
    lda #32
    adc $FB
    sta $FB

    clc
    lda #22     // 22 char per line
    adc $FC
    sta $FC

    jmp draw_char_loop

end_draw_char_loop:
    rts

enable_custom_char:         // $9005 => ????1101 (char @ $1400)
    lda #%11110000
    and $9005
    ora #%00001101
    sta $9005
    rts

disable_custom_char:    // $9005 => ????0000
    lda #%11110000
    and $9005
    //ora #%00001111
    sta $9005
    rts

custom_characters_addr:
    .word $1400

create_custom_characters:
    ldx #0                   // Character counter
    lda custom_characters_addr   // Base address
    sta $FD
    lda custom_characters_addr+1
    sta $FE
cc_char_loop:
    ldy #0
    lda #0          // First bit is 0
    sta ($FD),y
cc_bytes_loop:
    iny
    cpy #7
    beq cc_bytes_loop_end
    txa            // Bytes 1-6 are X
    sta ($FD),y    
    jmp cc_bytes_loop
cc_bytes_loop_end:
    lda #$FF       // Byte 7 is FF
    sta ($FD),y
    // Increment X
    inx
    beq cc_char_loop_end        // We are done
    // Increment the address
    clc
    lda $FD
    adc #8
    sta $FD
    lda $FE
    adc #0          // Just add the carry (could inc if c is set to save a couple if instructions)
    sta $FE
    jmp cc_char_loop
cc_char_loop_end:
    rts


#import "../_lib/PrintBinary.asm"