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

mainloop:

    jsr $FFE4       // Kernal GETIN (Get character from keyboard)
    cmp #81         // This is Q => Quit
    beq quit

    // Yellow border
    lda #31        
    sta $900F      

    // Wait for line 70
raster_wait:
    lda $9004
    cmp #70    
    bcc raster_wait     // Wait the line to be over 70 

    // Red border
    lda #26        
    sta $900F      

    // Wait for line 90
raster_wait2:
    lda $9004
    cmp #90    
    bcc raster_wait2    // Wait for line to be over 90 

    // Blue border
    lda #30        
    sta $900F

    // Wait for wrap arround
raster_wait3:
    lda $9004
    cmp #20    // Wait anaything bellow 20 
    bcs raster_wait3

    jmp mainloop

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
