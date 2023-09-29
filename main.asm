	.inesprg 1   ; 1x 16KB PRG code
	.ineschr 1   ; 1x  8KB CHR data
	.inesmap 0   ; mapper 0 = NROM, no bank swapping
	.inesmir 1   ; background mirroring


; Variables
	.rsset $0000
ballx				.rs 1
bally				.rs 1
ballup			.rs 1
balldown		.rs 1
ballleft		.rs 1
ballright		.rs 1
smo					.rs 1
con1				.rs 1


; Constants
SPEEDB		= $01 ; Ball
SPEEDP    = $02 ; Paddle
RIGHTWALL = $F4
LEFTWALL  = $04
TOPWALL   = $02
BOTWALL   = $E0
PADDLEL		= $020C
  

	.bank 0
	.org $C000
RESET
	SEI
	CLD
	LDX #$40
	STX $4017
	LDX #$FF
	TXS
	INX				; X is now 0
	STX $2000 ; Disable NMI
	STX $2001 ; Disable rendering
	STX $4010 ; Disable DMC IRQs

	JSR VblankWait

clrmem:
	LDA #$00
	STA $0000, x
	STA $0100, x
	STA $0200, x
	STA $0400, x
	STA $0500, x
	STA $0600, x
	STA $0700, x
	LDA #$FE
	STA $0300, x
	INX
	BNE clrmem

	JSR VblankWait


LoadPalettes:
	LDA $2002
	LDA #$3F
	STA $2006
	LDA #$00
	STA $2006
	LDX #$00
LoadPalettesLoop:
	LDA palette, x
	STA $2007
	INX
	; TODO: Optimize this so we use DEX and BNE instead of CPX
	; since that will save us some cycles.
	CPX #$20 ; Check if x = 32 (16 background palette entries + 16 sprite palette entries)
	BNE LoadPalettesLoop


LoadSprites:
	LDX #$00
LoadSpritesLoop:
	LDA sprites, x
	STA $0200, x
	INX
	CPX #$50
	BNE LoadSpritesLoop

	LDA #$01	
	STA ballright
	STA balldown

	LDA #%10000000
	STA $2000
	LDA #%00010110
	STA $2001


Forever:
	JMP Forever


NMI:
	LDA #$00
	STA $2003
	LDA #$02
	STA $4014

	JSR ReadController1	

	JSR PpuCleanup
	; Set no background scroll
	LDA #$00
	STA $2005
	STA $2005

	JSR MoveBall
	JSR UpdateBall
	JSR UpdatePaddles

	RTI


VblankWait:
	BIT $2002
	BPL VblankWait
	RTS


ReadController1:
	; Latch controller
	; Write $01, then $00 to tell the controller to latch current button positions.
	LDA #$01
	STA $4016
	LDA #$00
	STA $4016
	LDX #$08

read_controller_1_loop:
	LDA $4016 
	LSR A
	ROL con1
	DEX
	BNE read_controller_1_loop
	RTS


MoveBall:

move_ball_right:
	LDA ballright
	BEQ move_ball_right_done

	LDA ballx
	CLC
	ADC #SPEEDB
	STA ballx

	CMP #RIGHTWALL
	BCC move_ball_right_done

	LDA #$00
	STA ballright
	LDA #$01
	STA ballleft
move_ball_right_done:

move_ball_left:
	LDA ballleft
	BEQ move_ball_left_done

	LDA ballx
	SEC
	SBC #SPEEDB
	STA ballx

	CMP #LEFTWALL
	BCS move_ball_left_done

	LDA #$00
	STA ballleft
	LDA #$01
	STA ballright
move_ball_left_done:

move_ball_up:
	LDA ballup
	BEQ move_ball_up_done

	LDA bally
	SEC
	SBC #SPEEDB
	STA bally

	CMP #TOPWALL
	BCS move_ball_up_done

	LDA #$00	
	STA ballup
	LDA #$01
	STA balldown
move_ball_up_done:

move_ball_down:
	LDA balldown
	BEQ move_ball_down_done

	LDA bally
	CLC
	ADC #SPEEDB
	STA bally

	CMP #BOTWALL
	BCC move_ball_down_done

	LDA #$00
	STA balldown
	LDA #$01
	STA ballup
move_ball_down_done:
	RTS


UpdateBall:
	LDX #$00
	LDA #%11100100
	STA smo

update_sprites_loop:
	LDA smo
	LSR A
	STA smo
	BCS place_sprite_right

	LDA ballx
	SEC
	SBC #$04
	STA $0203, x
	JMP place_sprite_right_done

place_sprite_right:
	LDA ballx
	CLC
	ADC #$04
	STA $0203, x
place_sprite_right_done:
	
	LDA smo
	LSR A
	STA smo
	BCS place_sprite_down

	LDA bally
	SEC
	SBC #$04
	STA $0200, x
	JMP place_sprite_down_done

place_sprite_down:
	LDA bally
	CLC
	ADC #$04
	STA $0200, x
place_sprite_down_done:

	TXA
	CLC
	ADC #$04
	TAX
	CPX #$10
	BNE update_sprites_loop
	RTS


UpdatePaddles:
	LDA #%00001000
	BIT con1
	BNE up_pressed

	LDA #%00000100
	BIT con1
	BNE down_pressed

	; No buttons have been pressed if we arrived here
	RTS

up_pressed:
	LDY #$01
	JMP move_paddles_start

down_pressed:
	LDY #$00

move_paddles_start:
	LDX #$30
move_paddles_loop:
	LDA PADDLEL, x
	CPY #$01
	BEQ dec_paddle

inc_paddle:
	CLC
	ADC #SPEEDP
	JMP paddle_modify_done

dec_paddle:
	SEC
	SBC #SPEEDP

paddle_modify_done:
	STA PADDLEL, x
	TXA
	SEC
	SBC #$04
	TAX
	CPX #$00
	BNE move_paddles_loop
	RTS


PpuCleanup:
	LDA #%10000000
	STA $2000
	LDA #%00010110
	STA $2001
	RTS


	.bank 1
	.org $E000
palette:
  .db $22,$29,$1A,$0F,$22,$36,$17,$0F,$22,$30,$21,$0F,$22,$27,$17,$0F
  .db $22,$16,$28,$18,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C

sprites:
	; Ball
	.db $80, $32, $00, $80
	.db $80, $33, $00, $88
	.db $88, $34, $00, $80
	.db $88, $35, $00, $88

	; Left paddle
	.db $68, $36, $00, $08
	.db $70, $36, $00, $08
	.db $78, $36, $00, $08
	.db $80, $36, $00, $08
	.db $88, $36, $00, $08
	.db $90, $36, $00, $08

	; Right paddle
	.db $68, $36, $00, $EC
	.db $70, $36, $00, $EC
	.db $78, $36, $00, $EC
	.db $80, $36, $00, $EC
	.db $88, $36, $00, $EC
	.db $90, $36, $00, $EC


	.org $FFFA
	.dw NMI

	.dw RESET

	.dw 0


	.bank 2
	.org $0000
	.incbin "mario.chr"
