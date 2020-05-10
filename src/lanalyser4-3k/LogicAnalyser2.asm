#importonce

#import "../_lib/utils.asm"

.macro setLogicAnalyserAddr(addr) {
    mov16 #addr : la_addr
}

.const c_bufferwidth=22
.const c_bufferheight=8
/*****************************************************************************/
/*               Procedure to capture data in the buffer
/*****************************************************************************/

// Data for the logic analyser. 32 bytes (256 bits) for each channel
// x 8 chanels = 256 bytes of data
la_data:
    .fill  c_bufferwidth*c_bufferheight, $0 // c_bufferwidth*c_bufferheight, 0
la_index:
    .byte 0
la_addr:
    .word 162
la_bit:
    .byte %10000000
la_index_y:
    .byte 0

la_capture_one_bit:
// Increment the index
    inc la_index
    lda #c_bufferwidth
    asl
    asl
    asl
    cmp la_index
    bne done_incrementing
    lda #0
    sta la_index
done_incrementing:

   // Init with the msb
   lda #%10000000
   sta la_bit

// Set the array index in Y 
    lda la_index    
    lsr             // Shift Right 3 times to keep the index betwwen 0 and ( la_wrap-1 = 21)
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
    adc #c_bufferwidth
    sta la_index_y
    jmp loop_over_bits
end_loop_over_bits:
    rts


// Routine to clear the buffer
la_clear_buffer:
    lda #c_bufferwidth*c_bufferheight-1 // The last index of the buffer (so that we start on the first)
    sta la_index
    lda #$0
    ldy #$0
la_clear_buffer_loop:
    sta la_data, y
    iny
    cpy #c_bufferwidth*c_bufferheight
    bne la_clear_buffer_loop
    rts

/*****************************************************************************/
/*                Procedure to draw the buffer on screen
/*****************************************************************************/

la_screen_addr:
    .word $1E00 
la_draw_line_pos:
    .word 22*14         // Draw on line 14
la_draw_line_color:
    .byte 0
la_draw_screen:
    clc
    lda la_screen_addr            // Set the position of where to write on screen in FD FE
    adc la_draw_line_pos
    sta $FD
    lda la_screen_addr+1
    adc la_draw_line_pos+1
    sta $FE
    // Set the array index in Y 
    lda la_index    
    lsr             // Shift Right 3 times to keep the index betwwen 0 and 31
    lsr
    lsr
    tay                 // Use Y to store index on the data and screen

    ldx #c_bufferheight     // Count the 8 bits / lines

draw_char_loop:
    // Copy the data to the screen
    lda la_data, y
    sta ($FD),y
    // add #c_bufferwidth to y
    clc
    tya
    adc #c_bufferwidth
    tay
    dex
    beq end_draw_char_loop
    jmp draw_char_loop

end_draw_char_loop:

// Draw a cursor on the next line 
    // Set the right bit
    lda #%00000111
    and la_index
    tax
    lda #%10000000
bitsetloop_2:
    cpx #0
    beq bitsetloop_end_2
    dex
    lsr
    jmp bitsetloop_2
bitsetloop_end_2:
    sta ($FD),y
   
    lda la_index    
    lsr             // Shift Right 3 times to keep the index betwwen 0 and c_bufferwidth
    lsr
    lsr
    bne erase_previous_cursor
    // add #c_bufferwidth to y
    clc
    tya
    adc #c_bufferwidth
    tay
erase_previous_cursor:
    dey
    lda #0
    sta ($FD),y

not_first_line:
    rts

/*****************************************************************************/
/*                   Initialize the color of the traces
/*****************************************************************************/
color_ram_addr:
    .word $9600

inialize_colors:
    clc
    lda color_ram_addr  // Set the position of where to write on color memory in FD FE
    adc la_draw_line_pos
    sta $FD
    lda color_ram_addr+1
    adc la_draw_line_pos+1
    sta $FE
    ldy #0
    lda #0
inialize_colors_loop:
    sta ($FD),y         // Set the color of the character on the screen (location 9600 + y)
    iny
    cpy #c_bufferwidth*(c_bufferheight + 1)
    bne inialize_colors_loop
    rts

initialize_screen:
    clc
    lda la_screen_addr  // Set the position of where to write on color memory in FD FE
    adc la_draw_line_pos
    sta $FD
    lda la_screen_addr+1
    adc la_draw_line_pos+1
    sta $FE
    ldy #0
    lda #0
initialize_screen_loop:
    sta ($FD),y         // Set the charater on the screen
    iny
    cpy #c_bufferwidth*(c_bufferheight + 1)
    bne initialize_screen_loop
    rts




/*****************************************************************************/
/*                Create and enable custom characters
/*****************************************************************************/
custom_characters_addr:
    .word $1400

la_enable_custom_char:         // $9005 => ????1101 (char @ $1400)
    lda #%11110000
    and $9005
    ora #%00001101
    sta $9005
    rts

la_disable_custom_char:    // $9005 => ????0000
    lda #%11110000
    and $9005
    //ora #%00001111
    sta $9005
    rts

la_create_custom_characters:
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