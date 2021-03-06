*= $1001 "Basic Upstart"
BasicUpstart(start)    // 10 sys $1100

* = $1010 "Program"

// Hardware Registers Constants
.const VIC_RASTER_VALUE     = $9004
.const VIC_SCREEN_COLORS    = $900F

.const VIA1_DDR_A           = $9113
.const VIA1_PORT_A          = $9111
.const JOY_MASK_PORTA       = %00111100     // 1 for the bits of the joystick

.const VIA2_DDR_B           = $9122
.const VIA2_PORT_B          = $9120
.const JOY_MASK_PORTB       = %10000000     // 1 for the bits of the joystick

.const JOY_FIRE             = %00100000
.const JOY_UP               = %00000100
.const JOY_DOWN             = %00001000
.const JOY_LEFT             = %00010000
.const JOY_RIGHT            = %10000000

// Screen constants
.const SCREEN_COLS          = 22
.const SCREEN_ROWS          = 23
.const SCREEN_SIZE          = SCREEN_COLS * SCREEN_ROWS
.const SCREEN_MEMORY        = $1E00
.const SCREEN_MEMORY_256    = SCREEN_MEMORY + 256
.const COLOR_MEMORY         = $9600
.const COLOR_MEMORY_256     = COLOR_MEMORY + 256

// Program Variables
player_row:
    .byte 5
player_col:
    .byte 11

joystick:
    .byte $FF
joystick_prev:
    .byte $FF

ball_ypos:
    .word $0F00       // Top of the trajectory (15,00)
ball_vspeed:
    .word 0         // Speed is null
ball_direction:
    .byte 0         // Going down
.const BALL_GRAVITY         = 20


start:
    // ROM Clear screen
    jsr $e55f
    jsr init_screen

    // Init variables
    lda #0
    sta ball_vspeed
    sta ball_direction
    lda #$0F
    sta ball_ypos
    lda #$00
    sta ball_ypos+1


main_loop:

    // Read inputs
    jsr read_joystick
    jsr process_joystick_events
    jsr step_game

    // Wait for the screen to be fully updated
    raster_wait_after_screen:
    lda VIC_RASTER_VALUE
    cmp #105    
    bcc raster_wait_after_screen
 
    // Update the screen next frame
    jsr update_screen
    printBinary(ball_direction, 1, '1', '0', 6)
    printBinary(ball_vspeed, 22*1+1, '1', '0', 6)
    printBinary(ball_vspeed+1, 22*1+11, '1', '0', 6)

    printBinary(ball_ypos, 22*2+1, '1', '0', 6)
    printBinary(ball_ypos+1, 22*2+11, '1', '0', 6)

    // Wait for the rster line counter to wrap around
    raster_wait_wrap_around:
    lda VIC_RASTER_VALUE
    cmp #20
    bcs raster_wait_wrap_around

    jmp main_loop


step_game: {
    // animate the ball
    lda ball_direction
    beq going_down

going_up:
    // Decrease the speed
    sec
    lda ball_vspeed+1
    sbc #BALL_GRAVITY
    sta ball_vspeed+1
    lda ball_vspeed
    sbc #0
    sta ball_vspeed

    bcs still_going_up

    // lda ball_vspeed+1
    // eor #$FF
    // sta ball_vspeed+1
    // lda ball_vspeed
    // eor #$FF
    // sta ball_vspeed

    lda #0
    sta ball_vspeed+1
    sta ball_vspeed

    // reset speed and height


    // Reached the top, start to go down
    dec ball_direction      // Set the direction to 0 = DOWN

    // ball_ypos = ball_ypos - ball_vspeed
    sec
    lda ball_ypos+1
    sbc ball_vspeed+1
    sta ball_ypos+1
    lda ball_ypos
    sbc ball_vspeed
    sta ball_ypos
    jmp end_step

still_going_up:

    clc
    lda ball_ypos+1
    adc ball_vspeed+1
    sta ball_ypos+1
    lda ball_ypos
    adc ball_vspeed
    sta ball_ypos
    jmp end_step


going_down:
    // Increase the speed
    clc
    lda ball_vspeed+1
    adc #BALL_GRAVITY
    sta ball_vspeed+1
    lda ball_vspeed
    adc #0
    sta ball_vspeed
    
    // Calculate new position
sec
    lda ball_ypos+1
    sbc ball_vspeed+1
    sta ball_ypos+1
    lda ball_ypos
    sbc ball_vspeed
    sta ball_ypos

    // Bounce if needed
    bcs end_step            // We are done if the result is still positive


    lda ball_ypos+1
    eor #$FF
    sta ball_ypos+1
    lda ball_ypos
    eor #$FF
    sta ball_ypos
    
    inc ball_direction      // Set the direction to 1 = UP


end_step:

    // Update the ball column with the top byte of ball_ypos
    lda ball_ypos 
    sta player_row
    sec
    lda #SCREEN_ROWS-1
    sbc player_row
    sta player_row

    rts
}

process_joystick_events:
    lda joystick
    eor #$FF
    and joystick_prev
    tax
    and #JOY_UP
    beq joy_not_up
    jsr joystick_up
joy_not_up:
    txa
    and #JOY_DOWN
    beq joy_not_down
    jsr joystick_down
joy_not_down:
    txa
    and #JOY_LEFT
    beq joy_not_left
    jsr joystick_left
joy_not_left:
    txa
    and #JOY_RIGHT
    beq joy_not_right
    jsr joystick_right
joy_not_right:
    txa
    and #JOY_FIRE
    beq joy_not_fire
    jsr joystick_fire
joy_not_fire:
    rts

joystick_up: {
    rts
}

joystick_down: {
    rts
}

joystick_left: {
    dec player_col
    bpl after_reset
    lda #SCREEN_COLS-1
    sta player_col
after_reset:
    rts
}

joystick_right: {
    inc player_col
    lda player_col
    cmp #SCREEN_COLS
    bne after_reset
    lda #0
    sta player_col
    after_reset:
    rts
}

joystick_fire:
    rts


read_joystick:
    // Save previous Joystick position
    lda joystick
    sta joystick_prev
    
    // Save and set DDR
    lda VIA1_DDR_A
    pha
    
    lda VIA2_DDR_B
    pha
    
    lda # ~JOY_MASK_PORTA
    and VIA1_DDR_A
    sta VIA1_DDR_A

    lda # ~JOY_MASK_PORTB
    and VIA2_DDR_B
    sta VIA2_DDR_B
    
    // Read the Port A
    lda #JOY_MASK_PORTA
    and VIA1_PORT_A
    sta joystick
    
    // Read Port B
    lda #JOY_MASK_PORTB
    and VIA2_PORT_B
    ora joystick
    sta joystick
    
    // Restore DDR
    pla
    sta VIA2_DDR_B
    
    pla
    sta VIA1_DDR_A
    
    rts

init_screen:
    // Make the screen black
    lda #9
    sta VIC_SCREEN_COLORS

    // Make all character white
    ldy #0
    lda #1
init_screen_loop1:
    sta COLOR_MEMORY, y
    iny
    bne init_screen_loop1
init_screen_loop2:
    sta COLOR_MEMORY_256, y
    iny
    cpy SCREEN_SIZE-256
    bne init_screen_loop2
    rts


clear_screen:
    // Make all character spaces (32)
    ldy #0
    lda #32
clear_screen_loop1:
    sta SCREEN_MEMORY, y
    iny
    bne clear_screen_loop1
clear_screen_loop2:
    sta SCREEN_MEMORY_256, y
    iny
    cpy SCREEN_SIZE-256
    bne clear_screen_loop2
    rts

draw_player:
    // Compute the position of the player on the screen from (player_row, player_col)
    lda #0
    ldx #0
    ldy player_row
    iny
loop_set_row:    
    dey
    beq end_loop_set_row
    clc
    adc #SCREEN_COLS
    bcs wrap_around
    jmp loop_set_row
wrap_around:
    ldx #1
    jmp loop_set_row
end_loop_set_row:
    clc
    adc player_col
    tay                             // Y = player_row x SCREEN_COLS + player_col
    lda #87
    bcs write_to_bottom_of_screen   // Carry is set if Y wrapped around ( > 256)
    cpx #0
    bne write_to_bottom_of_screen
    sta SCREEN_MEMORY, y
    jmp done_draw_player
write_to_bottom_of_screen:
    sta SCREEN_MEMORY_256, y
done_draw_player:
    rts

// Update the screen. Runs after each frame has been rendered.
update_screen:
    jsr clear_screen
    jsr draw_player
    rts

#import "../_lib/PrintBinary.asm"