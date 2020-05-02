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

    // Init variables
    lda #1
    sta border_color

    // Add our own interrupt routine
    sei

    lda #<irq     // set the IRQ routine pointer
    sta $0314
    lda #>irq
    sta $0315

    // 0x5688 is 1 PAL frame at 1.018MHz
    // 0x5688 / 8 = 0x0AD1
    // We remove 2 cycles to allow for the counting to restart 
    // So to have 8 interrupts by frame we need to count from 0x0ACF
    lda #<$0ACF
    sta $9124
    ldy #>$0ACF

    // Sync the timer with the raster counter
    jsr raster_wait     // Wait until a specific line

    ldx #12             
delay_loop:             // Wait for the end of the line ish
    dex                 // to hide the jitter between 2 lines (h blank)
    bne delay_loop      // 12 iteration seem to do the trick (PAL)

    sty $9125           // Start counting

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

    cmp #78         // This is N => Cycle colors
    beq inc_color

    cmp #73         // This is I => Invert colors
    beq invert_color

    cmp #74         // This is J => Cycle bk
    beq bk_color

    printBinary(161, $5D+22*4-4, '1', '0', 0)
    printBinary(162, $5D+22*4+5, '1', '0', 0)

    jmp mainloop

inc_color:
    inc border_color
    jmp mainloop

invert_color:
    lda #%00001000
    eor screen_color
    sta screen_color
    jmp mainloop

bk_color:
    clc
    lda #%00010000
    adc screen_color
    sta screen_color
    jmp mainloop

quit:
    jmp $FED2       // Dirty jump to the Kernal BRK Handler to skip any cleanup and restore


screen_color:
    .byte 24    // White screen
border_color:
    .byte 0 

irq:        // The cpu state has been saved by the kernal

    // Check if it is a via 2 interrupt
    bit $912d
    bmi irq_via2
    //jmp irq_rti
    // Let the kernal handle other interrupts
irq_kernal:
    jmp $eabf     // jump to normal IRQ

irq_via2:
    // Check if this is a timer interrupt
    // TODO just to avoid hijacking other VIA2 interrupts if any

    // Calculate new border/screen color
    inc border_color

    // Code to also cycle the background
    // clc
    // lda #%00010000
    // adc screen_color
    // sta screen_color

    lda #%00000111
    and border_color
    ora screen_color
    //ora #%10000000

    // set the border/screen color
    sta $900F

    // If the border color is 0 (1 every 8th interrupt) we call the kernal interrupt
    lda #%00000111
    and border_color
    beq irq_kernal

    // Otherwise clear the interrupt and return from interrupt
    bit  $9124      // Read the low bytes of the counter to clear the interrupt flag
    jmp irq_rti

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
    cmp #5    // Wait for line 0 (somewhere in the middle)
    bne raster_wait
    rts


#import "../_lib/PrintBinary.asm"