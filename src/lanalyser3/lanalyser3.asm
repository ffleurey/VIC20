*= $1001 "Basic Upstart"
BasicUpstart(start)    // 10 sys $1100

// Entry point
* = $100D "Program Code"
start:
    // Make screen black and text white
    lda #31        // 8 => Yellow border / White background
    sta $900F       // 900F (36879) : Color of border and background 
    jsr $e55f       // ROM Clear screen

    // Initialize
    jsr la_create_custom_characters
    jsr setup_timer_irq

    setCursor(2,1)
    printString(title)

    setCursor(4,6)
    printString(help)

    setCursor(8,4)
    jmp got_t


mainloop:

    setCursor(8,4)
    jsr $FFE4       // Kernal GETIN (Get character from keyboard)
    cmp #81         // This is Q => Quit
    beq got_q
    cmp #74
    beq got_j
    cmp #84
    beq got_t
    cmp #85
    beq got_u
    // cmp #75
    // beq got_k

    // // Yellow border
    // lda #31        
    // sta $900F      

    jmp mainloop


got_q:
    jmp $FED2       // Dirty jump to the Kernal BRK Handler to skip any cleanup and restore

got_u:
    setLogicAnalyserAddr($9110)
    printString(user_port)
    jmp mainloop

got_j:
    setLogicAnalyserAddr($9111)
    printString(joystick_str)
    jmp mainloop

got_t:
    setLogicAnalyserAddr(162)
    printString(timer_str)
    jmp mainloop

// got_k:
//     setLogicAnalyserAddr(197)
//      setCursor(6,2)
//     printString(keyboard_str)
//     jmp mainloop

help:
    .text "I: U,T,J"
    .byte 31 // BLUE
    .byte 0

user_port:
    .text "USERPORT $9110"
    .byte 0

timer_str:
    .text "TIMER    $00A2"
    .byte 0

joystick_str:
    .text "JOYSTICK $9111"
    .byte 0

// keyboard_str:
//     .byte 31 // BLUE
//     .text "KEYBOARD  ($00C5)"
//     .byte 0

title:
    .byte 28 // RED
//    .byte 18 // REVERSE ON
    .text "VIC20 LOGIC ANALYSER"
//    .byte 146 // REVERSE OFF
    .byte 0


.macro setCursor(line, column) {
    ldx #line
    ldy #column
    clc
    jsr $FFF0       // Kernal PLOT (read or write cursor position)
}

.macro printString(addr) {
    print_string:
        ldy #0
    print_loop:
        lda addr, y
        beq end_of_string
        jsr $E742       // Kernal output character to screen
        iny
        jmp print_loop
    end_of_string:
}


// ******************************************************************
//                      TIMER INTERRUPTS
// ******************************************************************

setup_timer_irq:
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
    rts


// This is an active wait on a specific raster line.    
raster_wait:
    lda $9004
    cmp #85    // Wait for line 85 (somewhere in the middle)
    bne raster_wait
    rts

// Handle the interrupts
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
    // lda #26        
    // sta $900F
    
    jsr la_disable_custom_char
    printBinaryPtr(la_addr, $5D+22*6+1, '1', '0', 6)
    // Update the display
    jsr la_draw_screen

    bit  $9124      // Read the low bytes of the counter to clear the interrupt flag
    jmp irq_rti

middle_of_the_frame:
    // Blue border
    // lda #30        
    // sta $900F

    jsr la_capture_one_bit
    jsr la_enable_custom_char
    jmp irq_kernal

// This is what to do to return from interrupt if not calling the kernal routine.
irq_rti:        // Restore cpu state and return from interrupt
    pla
    tay
    pla
    tax
    pla
    rti

#import "../_lib/LogicAnalyser.asm"
#import "../_lib/PrintBinary.asm"