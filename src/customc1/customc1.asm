*= $1001 "Basic Upstart"
BasicUpstart(start)

// Entry point
* = $1010 "Program Code"
start:

    // ROM Clear screen
    jsr $e55f       
    
    jsr create_custom_characters
    jsr enable_custom_char
    jsr draw_text
    jsr draw_chars
    
main_loop:

    // Wait for line 70
    raster_wait:
    lda $9004
    cmp #50    
    bcc raster_wait     // Wait the line to be over 40 
    jsr enable_custom_char
        // Blue border
    lda #30        
    sta $900F

    raster_wait2:
    lda $9004
    cmp #105    
    bcc raster_wait2     // Wait the line to be over 100 
    jsr disable_custom_char
    // Normal border
    lda #27        
    sta $900F   

    jsr $FFE4       // Kernal GETIN (Get character from keyboard)
    cmp #81         // This is Q => Quit
    beq quit

    raster_wait3:
    lda $9004
    cmp #20    // Wait anaything bellow 20 (End of the frame)
    bcs raster_wait3

    jmp main_loop

quit:
    jsr disable_custom_char
    // Move the cursor to X=18 (row), Y=0 (column)
    lda #27        // 27 => Cyan border / White background
    sta $900F       // 900F (36879) : Color of border and background
    ldx #16
    ldy #0
    clc
    jsr $FFF0       // Kernal PLOT (read or write cursor position)
    rts 

title:
    .text "  custom characters:  "
colors:
    .byte 2,3,4,5,0,2,3,4,5,0,6,5,2,3,4,5,0,6,2,4,3,0
  
draw_text:
    ldx #$00
draw_loop:
    lda title,x
    sta $1E00+22*1,x    // Set the character on the screen
    lda colors,x
    sta $9600+22*1,x    // Set the color of the character
    inx
    cpx #$16
    bne draw_loop
    rts

draw_chars:
    ldx #$00
    draw_chars_loop:
    txa
    sta $1E00+22*4,x    // Set the character on the screen
    lda #0
    sta $9600+22*4,x    // Set the color of the character
    inx
    bne draw_chars_loop
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
