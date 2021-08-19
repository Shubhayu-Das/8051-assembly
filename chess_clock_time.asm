; Program: Chess clock to show number of moves made by player and then a timing summary
; Author:  Shubhayu Das
; Date:	   14/11/2020

;-----------------------------REFERENCES-----------------------------------------;
; Reference for splitting 16 bit number into 5 digits:
; https://okashtein.wordpress.com/2013/04/15/binary16-bit-to-bcd/

;-----------------------------TIMING DECISIONS-----------------------------------------;
; This program finally combines the display driver with the overall timer
; The time resolution decided for this clock is 50ms
; The DPTR will be used to count up on every timer overflow
; Timer overflow interrupts will increment the timing counter
; Button press interrupts will lead to swap of active player
; I will use a 16 bit register to store the number of 50ms steps for each player

; RAM addresses:
; 0x30 and 0x31 will be used for P1 (High byte and low byte)
; 0x32 and 0x33 will be used for P2 (High byte and low byte)

; Register mapping:
; R0 will be used to count the number of moves for player 1
; R1 will be used to count the number of moves for player 2

;-----------------------------DISPLAY SECTION-----------------------------------------;
; Initially, "CHESS CLOCK" and "MAX 10 MOVES" will be shown on the display
; After this, the screen will display the number of moves made by each player on separate rows
; Once both players make ten moves, the display will show the average time taken by each player

; R2 will be used to check stateChange for player 1 moves
; R3 will be used to check stateChange for player 2 moves
; R4 will be used for calling display subroutine
; R7 will be used for timing delay loop

;-----------------------------MEMORY LOCATION MACROS-----------------------------------------;

IE0_ISR_ADDR			EQU	0003H
TF0_ISR_ADDR			EQU	000BH
IE1_ISR_ADDR			EQU	0013H
TF1_ISR_ADDR			EQU	001BH
TF0_EXT_ISR_ADDR		EQU	0031H
IE0_EXT_ISR_ADDR		EQU	TF0_EXT_ISR_ADDR	+ 1DH
TF1_EXT_ISR_ADDR		EQU	IE0_EXT_ISR_ADDR 	+ 1FH
IE1_EXT_ISR_ADDR		EQU	TF1_EXT_ISR_ADDR	+ 1DH
DELAY_SBR_ADDR			EQU	IE1_EXT_ISR_ADDR 	+ 32H
TOGGLE_EN_SBR_ADDR		EQU	DELAY_SBR_ADDR 		+ 10H
DISP_INIT_SBR_ADDR		EQU	TOGGLE_EN_SBR_ADDR 	+ 10H
WRITE_WORD_SBR_ADDR		EQU	DISP_INIT_SBR_ADDR 	+ 1BH
LOOKUP_SBR_ADDR			EQU	WRITE_WORD_SBR_ADDR 	+ 12H
UPDATE_COUNTER_DISP_SBR		EQU	LOOKUP_SBR_ADDR 	+ 12H
BYTES_TO_DIGITS_SBRADDR		EQU	UPDATE_COUNTER_DISP_SBR + 0ABH
FINAL_TIME_DISP_SBRADDR		EQU	BYTES_TO_DIGITS_SBRADDR + 60H
MEAN_P1_ADDR			EQU	FINAL_TIME_DISP_SBRADDR + 44H
MEAN_P2_ADDR			EQU	MEAN_P1_ADDR		+ 10H
MAIN_CODE_ADDR			EQU	MEAN_P2_ADDR		+ 10H
CHAR_LOOKUP_ADDR		EQU	MAIN_CODE_ADDR 		+ 1ADH

;-----------------------------REGISTER MACROS-----------------------------------------;

EN_PIN	EQU	P0.0
RS_PIN	EQU	P0.1

R0_DIV	EQU	08H
R1_DIV	EQU	09H
R2_DIV	EQU	0AH
R3_DIV	EQU	0BH
R4_DIV	EQU	0CH

;-----------------------------CONFIGURATION MACROS-----------------------------------------;

N_MOVES			EQU	8D

TIMER_UPPER_REG_VAL	EQU	003CH
TIMER_LOWER_REG_VAL	EQU	004CH

COUNTER_0_UPPER_BYTE	EQU	0040H
COUNTER_0_LOWER_BYTE	EQU	0041H
COUNTER_1_UPPER_BYTE	EQU	0042H
COUNTER_1_LOWER_BYTE	EQU	0043H

DIV_LOW_BYTE		EQU	0044H
DIV_HIGH_BYTE		EQU	0045H

;------------------------------CODE STARTS-----------------------------------------;

	ORG	0000
	AJMP	MAIN_CODE_ADDR	; Ignore all the SBRs and get to the code

;----------------------------External interrupt pin 3.2 ISR---------------------------------------;
	ORG	IE0_ISR_ADDR
	CLR	TR0		; Disable the timer immediately
	CLR	EX0		; Disable the interrupt for software debouncing
	ACALL	IE0_EXT_ISR_ADDR	; Run rest of less critical steps
	RETI

;----------------------------Timer 0 overflow ISR---------------------------------------;
	ORG	TF0_ISR_ADDR
	CLR	TR0
	ACALL	TF0_EXT_ISR_ADDR
	SETB	TR0
	RETI

;----------------------------External interrupt pin 3.3 ISR---------------------------------------;
	ORG	IE1_ISR_ADDR
	CLR	TR1		; Disable the timer immediately
	CLR	EX1		; Disable the interrupt for software debouncing
	ACALL	IE1_EXT_ISR_ADDR	; Run rest of less critical steps
	RETI

;----------------------------Timer 1 overflow ISR---------------------------------------;
	ORG	TF1_ISR_ADDR
	CLR	TR1
	ACALL	TF1_EXT_ISR_ADDR
	SETB	TR1
	RETI

;----------------------------Timer 0 overflow Extended ISR---------------------------------------;

	ORG	TF0_EXT_ISR_ADDR
	MOV	TH0, TIMER_UPPER_REG_VAL	; Reload timer high byte
	MOV	TL0, TIMER_LOWER_REG_VAL	; Reload timer low byte

	CLR	C
	MOV	A, COUNTER_0_LOWER_BYTE
	ADD	A, #1D
	MOV	COUNTER_0_LOWER_BYTE, A

	MOV	A, COUNTER_0_UPPER_BYTE
	ADDC	A, #0D
	MOV	COUNTER_0_UPPER_BYTE, A
	RET

;----------------------------External interrupt pin 3.2 Extended ISR---------------------------------------;
	ORG	IE0_EXT_ISR_ADDR
	SETB	EX1		; Enable other player's interrupt
	SETB	TR1		; Enable other player's timer
	INC	R0		; Increment number of moves made
	CPL	P3.0		; Toggle LED for player 1
	CPL	P3.1		; Toggle LED for player 2
	RET

;----------------------------Timer 1 overflow Extended ISR---------------------------------------;

	ORG	TF1_EXT_ISR_ADDR
	MOV	TH1, TIMER_UPPER_REG_VAL	; Reload timer high byte
	MOV	TL1, TIMER_LOWER_REG_VAL	; Reload timer low byte

	CLR	C
	MOV	A, COUNTER_1_LOWER_BYTE		; Low byte ++
	ADD	A, #1D
	MOV	COUNTER_1_LOWER_BYTE, A

	MOV	A, COUNTER_1_UPPER_BYTE		; High byte carry up
	ADDC	A, #0D
	MOV	COUNTER_1_UPPER_BYTE, A
	RET

;----------------------------External interrupt pin 3.3 Extended ISR---------------------------------------;
	ORG	IE1_EXT_ISR_ADDR
	SETB	EX0		; Enable other player's interrupt
	SETB	TR0		; Enable other player's timer
	INC	R1		; Increment number of moves made

	CPL	P3.0		; Toggle LED for player 1
	CPL	P3.1		; Toggle LED for player 2
	RET

;------------------------------Delay subroutine-----------------------------------------;
; Forces processor to stall until ready for next insrtuction

	ORG	DELAY_SBR_ADDR
DELAY:
	MOV	R7, #0D
LOOP:
	INC	R7
	NOP
	CJNE	R7, #255D, LOOP
	RET

;--------------------------Toggle enable pin subroutine-----------------------------------;
	ORG	TOGGLE_EN_SBR_ADDR
TOGGLE_EN:
	SETB	EN_PIN		; Turn the enable pin on
	ACALL	DELAY		; Wait for some time
	ACALL	DELAY

	CLR	EN_PIN		; Turn the enable pin off
	ACALL	DELAY		; Wait for some time
	ACALL	DELAY
	RET

;------------------------Display driver initialization subroutine----------------------------------;
	ORG	DISP_INIT_SBR_ADDR
DISPLAY_INIT:
	CLR	EN_PIN		; Clear the enable bit
	CLR	RS_PIN		; Clear the read/store bit

	MOV	P1, #00000001b	; Clear the entire display
	ACALL	TOGGLE_EN

	MOV	P1, #00111000b	; Set the display to 8-bit bus, 5x8 font and 2 lines
	ACALL	TOGGLE_EN

	MOV	P1, #00001100b	; Enable the display
	ACALL	TOGGLE_EN

	MOV	P1, #00000111b	; Set writing direction to rigthwards
	ACALL	TOGGLE_EN
	RET

;------------------------------CODE STARTS-----------------------------------------;
	ORG	WRITE_WORD_SBR_ADDR
WRITE_WORD:
	SETB	RS_PIN		; Pull the read/store pin high to store
	MOV	P1, R4		; Write the word to output port
	ACALL	TOGGLE_EN	; Toggle the enable pin to write to LCD driver
	CLR	RS_PIN		; Pull the read/store pin low to complete transaction
	ACALL	DELAY		; Buffer for safe write
	RET

;------------------------------SHOW A DIGIT FROM LOOKUP TABLE-----------------------------------------;
	ORG	LOOKUP_SBR_ADDR
LOOKUP:
	MOV	DPTR, #CHAR_LOOKUP_ADDR
	MOVC	A, @A+DPTR	; Load digit's binary display mapping from lookup table
	MOV	R4, A		; Write digit to display
	ACALL	WRITE_WORD
	RET

;------------------------------CODE TO UPDATE COUNTER DISPLAY-----------------------------------------;
; Subroutine to update the display which shows the number of moves made by each player

	ORG	UPDATE_COUNTER_DISP_SBR
UPDATE_COUNTER_DISP:
	ACALL	DISPLAY_INIT

	MOV	R4, #01010000b	; P
	ACALL	WRITE_WORD

	MOV	R4, #00110001b	; 1
	ACALL	WRITE_WORD
	ACALL	DELAY

	MOV	R4, #00111010b	; :
	ACALL	WRITE_WORD

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD

	MOV	DIV_HIGH_BYTE, #0D	; Split number of moves made into digits
	MOV	DIV_LOW_BYTE, R0
	ACALL	BYTES_TO_DIGITS

	MOV	A, 0AH		; 3rd digit among 5
	ACALL	LOOKUP

	MOV	A, 09H		; 2nd digit among 5
	ACALL	LOOKUP

	MOV	A, 08H		; LSB digit
	ACALL	LOOKUP

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD

	MOV	R4, #01101101b	; M
	ACALL	WRITE_WORD

	MOV	R4, #01101111b	; o
	ACALL	WRITE_WORD

	MOV	R4, #01110110b	; v
	ACALL	WRITE_WORD

	MOV	R4, #01100101b	; e
	ACALL	WRITE_WORD

	MOV	R4, #01110011b	; s
	ACALL	WRITE_WORD

	ACALL	DELAY
	MOV	P1, #11000000b	; Go to the next line on the display
	ACALL	TOGGLE_EN
	ACALL	DELAY

	MOV	R4, #01010000b	; P
	ACALL	WRITE_WORD

	MOV	R4, #00110010b	; 2
	ACALL	WRITE_WORD

	MOV	R4, #00111010b	; :
	ACALL	WRITE_WORD

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD

	MOV	DIV_HIGH_BYTE, #0D	; Split number of moves made into digits
	MOV	DIV_LOW_BYTE, R1
	ACALL	BYTES_TO_DIGITS

	MOV	A, R2_DIV	; 3rd digit among 5
	ACALL	LOOKUP

	MOV	A, R1_DIV	; 2nd digit among 5
	ACALL	LOOKUP

	MOV	A, R0_DIV	; LSB digit
	ACALL	LOOKUP

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD

	MOV	R4, #01101101b	; M
	ACALL	WRITE_WORD

	MOV	R4, #01101111b	; o
	ACALL	WRITE_WORD

	MOV	R4, #01110110b	; v
	ACALL	WRITE_WORD

	MOV	R4, #01100101b	; e
	ACALL	WRITE_WORD

	MOV	R4, #01110011b	; s
	ACALL	WRITE_WORD

	MOV	P1, #00000010b	; Return cursor and display to init position
	ACALL	TOGGLE_EN
	ACALL	DELAY
	RET

;------------------------------CONVERT 16 BIT NUMBER TO 5 DIGITS-----------------------------------------;
; Uaes R0, R1, R2, R3, R5 to store 5 digits, from left to right
	ORG	BYTES_TO_DIGITS_SBRADDR
BYTES_TO_DIGITS:
	MOV	R0_DIV, #0D
	MOV	R1_DIV, #0D
	MOV	R2_DIV, #0D
	MOV	R3_DIV, #0D
	MOV	R4_DIV, #0D

	MOV	B, #10D
	MOV	A, DIV_LOW_BYTE
	DIV	AB
	MOV	R0_DIV, B

	MOV	B, #10D
	DIV	AB
	MOV	R1_DIV, B
	MOV	R2_DIV, A

	MOV	A, DIV_HIGH_BYTE
	CJNE	A, #0H, NEXT
	RET
NEXT:
	MOV	A, #6D
	ADD	A, R0_DIV
	MOV	B, #10D
	DIV	AB
	MOV	R0_DIV, B

	ADD	A, #5D
	ADD	A, R1_DIV
	MOV	B, #10D
	DIV	AB
	MOV	R1_DIV, B

	ADD	A, #2D
	ADD	A, R2_DIV
	MOV	B, #10D
	DIV	AB
	MOV	R2_DIV, B

	ADD	A, R3_DIV
	MOV	R3_DIV, A

	DJNZ	DIV_HIGH_BYTE, NEXT
	MOV	B, #10D
	MOV	A, R3_DIV
	DIV	AB
	MOV	R3_DIV, B
	MOV	R4_DIV, A
	RET

	ORG	FINAL_TIME_DISP_SBRADDR
DISP_FINAL_TIME:
	MOV	R4, #01010000b	; P
	ACALL	WRITE_WORD

	MOV	A, R6		; Player number
	ACALL	LOOKUP

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD

;	MOV	R4, #01000001b	; A
;	ACALL	WRITE_WORD

;	MOV	R4, #01010110b	; V
;	ACALL	WRITE_WORD

;	MOV	R4, #01000111b	; G
;	ACALL	WRITE_WORD

	MOV	R4, #00111010b	; ":"
	ACALL	WRITE_WORD

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD

	MOV	A, R4_DIV		; Display MSB
	ACALL	LOOKUP

	MOV	A, R3_DIV
	ACALL	LOOKUP

	MOV	A, R2_DIV
	ACALL	LOOKUP

	MOV	A, R1_DIV
	ACALL	LOOKUP

	MOV	A, R0_DIV
	ACALL	LOOKUP

	MOV	R4, #01111000b	; x
	ACALL	WRITE_WORD

	MOV	R4, #00110100b	; 4
	ACALL	WRITE_WORD

	MOV	R4, #00110110b	; 6
	ACALL	WRITE_WORD

	MOV	R4, #01101101b	; s
	ACALL	WRITE_WORD

	MOV	R4, #01110011b	; s
	ACALL	WRITE_WORD

	ACALL	DELAY
	RET

;------------------------------FIND average time for P1-----------------------------------------;
	ORG	MEAN_P1_ADDR
P1_MEAN:
	CLR	C
	MOV	A, COUNTER_0_UPPER_BYTE
	RRC	A
	MOV	COUNTER_0_UPPER_BYTE, A

	MOV	A, COUNTER_0_LOWER_BYTE
	RRC	A
	MOV	COUNTER_0_LOWER_BYTE, A
	RET

;------------------------------FIND average time for P2-----------------------------------------;
	ORG	MEAN_P2_ADDR
P2_MEAN:
	CLR	C
	MOV	A, COUNTER_1_UPPER_BYTE
	RRC	A
	MOV	COUNTER_1_UPPER_BYTE, A

	MOV	A, COUNTER_1_LOWER_BYTE
	RRC	A
	MOV	COUNTER_1_LOWER_BYTE, A
	RET

;------------------------------MAIN CODE-----------------------------------------;
	ORG	MAIN_CODE_ADDR

;------------------------------CONFIGURATION OF REGISTERS-----------------------------------------;
; Configure the timers and their modes
	MOV	SP, #10H
	MOV	TMOD, #10011001b	; both timers on 16 bit mode, runs only when interrupt has not occured
	MOV	TCON, #00000000b	; Reset all timer run flags and interrupts

; Initialize all the timer registers with proper values
	MOV	TH0, #TIMER_UPPER_REG_VAL
	MOV	TL0, #TIMER_LOWER_REG_VAL

	MOV	TH1, #TIMER_UPPER_REG_VAL
	MOV	TL1, #TIMER_LOWER_REG_VAL

; Reset all the counter registers
	MOV	COUNTER_0_UPPER_BYTE, #0D
	MOV	COUNTER_0_LOWER_BYTE, #0D
	MOV	COUNTER_1_UPPER_BYTE, #0D
	MOV	COUNTER_1_LOWER_BYTE, #0D

; Initialize move count registers
	MOV	R0, #0D		; Keeps track of number of moves made by player 1
	MOV	R1, #0D		; Keeps track of number of moves made by player 2
	MOV	R2, #1D		; Copy of R0, for updating display. Prevents excessive display rewrites
	MOV	R3, #1D		; Copy of R1, for updating display.

;------------------------------SHOW INITIAL MESSAGE-----------------------------------------;
; "  CHESS  CLOCK  "
; " MAX. MOVES: 010"

	ACALL	DISPLAY_INIT	; Initialize the Hitachi HD44780 LCD driver

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD
	ACALL	DELAY

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD
	ACALL	DELAY

	MOV	R4, #01000011b	; C
	ACALL	WRITE_WORD

	MOV	R4, #01001000b	; H
	ACALL	WRITE_WORD

	MOV	R4, #01000101b	; E
	ACALL	WRITE_WORD

	MOV	R4, #01010011b	; S
	ACALL	WRITE_WORD

	MOV	R4, #01010011b	; S
	ACALL	WRITE_WORD

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD

	MOV	R4, #01000011b	; C
	ACALL	WRITE_WORD

	MOV	R4, #01001100b	; L
	ACALL	WRITE_WORD

	MOV	R4, #01001111b	; O
	ACALL	WRITE_WORD

	MOV	R4, #01000011b	; C
	ACALL	WRITE_WORD

	MOV	R4, #01001011b	; K
	ACALL	WRITE_WORD

; Tell the LCD driver to move to the second line
	MOV	P1, #11000000b
	ACALL	TOGGLE_EN
	ACALL	DELAY

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD
	ACALL	DELAY

	MOV	R4, #01001101b	; M
	ACALL	WRITE_WORD

	MOV	R4, #01000001b	; A
	ACALL	WRITE_WORD

	MOV	R4, #01011000b	; X
	ACALL	WRITE_WORD

	MOV	R4, #00101110b	; "."
	ACALL	WRITE_WORD

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD
	ACALL	DELAY

	MOV	R4, #01001101b	; M
	ACALL	WRITE_WORD

	MOV	R4, #01001111b	; O
	ACALL	WRITE_WORD

	MOV	R4, #01010110b	; V
	ACALL	WRITE_WORD

	MOV	R4, #01000101b	; E
	ACALL	WRITE_WORD

	MOV	R4, #01010011b	; S
	ACALL	WRITE_WORD

	MOV	R4, #00111010b	; :
	ACALL	WRITE_WORD

	MOV	R4, #00010000b	; <space>
	ACALL	WRITE_WORD
	ACALL	DELAY

	MOV	DIV_HIGH_BYTE, #0D
	MOV	DIV_LOW_BYTE, #N_MOVES	; Split into digits
	ACALL	BYTES_TO_DIGITS

	MOV	A, R2_DIV		; MSB
	ACALL	LOOKUP

	MOV	A, R1_DIV		; middle digit
	ACALL	LOOKUP

	MOV	A, R0_DIV		; LSB
	ACALL	LOOKUP

	MOV	P1, #00000010b	; Return cursor and display to home
	ACALL	TOGGLE_EN
	ACALL	DELAY


;------------------------------SWITCH TO MOVE COUNT DISPLAY MODE-----------------------------------------;

; Cause a small standby delay here
	MOV	B, #1FH
START_PAUSE:
	MOV	R6,#0FFH
INNER:
	ACALL	DELAY
	DJNZ	R6, INNER
	DJNZ	B, START_PAUSE

; Enable all the relevant interrupts
	MOV	IE, #10001011b
	SETB	P3.1		; Show which player needs to make a move
	CLR	P3.0
	SETB	TR0

DO_WHILE:

CHECK_P1_STATE:
	MOV	A, R0		; Compare old state with possibly new state of n_moves_made
	MOV	B, R2
	CJNE	A, B, UPDATE_P1	; If displayed value is outdated, update it
	AJMP	CHECK_P2_STATE	; Else check state for second player

UPDATE_P1:
	MOV	0x02, R0	; Update the state
	ACALL	UPDATE_COUNTER_DISP	; Call SBR for updating display

CHECK_P2_STATE:
	MOV	A, R1		; Compare states for player 2
	MOV	B, R3
	CJNE	A, B, UPDATE_P2	; If displayed value is outdated, update it
	AJMP	NO_CHANGE	; Else just wait around

UPDATE_P2:
	MOV	0x03, R1	; Update the state
	ACALL	UPDATE_COUNTER_DISP	; Call SBR for updating display

NO_CHANGE:
	ACALL	DELAY		; Buffer for fun
	CJNE	R2, #N_MOVES, DO_WHILE	; Check if all moves are made by player 1
	CJNE	R3, #N_MOVES, DO_WHILE	; Check if all moves are made by player 2


;------------------------------CALC AND DISP THE AVERAGE TIMES-----------------------------------------;

	MOV	IE, #00H	; Disable all interrupts
	MOV	TMOD, #00H	; Disable all timer configurations
	MOV	TCON, #00H	; Reset all timer controls

	; Delay for a little time
	MOV	R6,#0FFH
PAUSE:
	ACALL	DELAY
	DJNZ	R6, PAUSE


	ACALL	DELAY
	CLR	P3.0		; Indicate that game is over
	CLR	P3.1
	ACALL	DELAY

	; Divide total counts by 2 to get number of 100ms counts
	ACALL	P1_MEAN
	ACALL	P1_MEAN
	ACALL	P1_MEAN
	ACALL	P1_MEAN

	ACALL	P2_MEAN
	ACALL	P2_MEAN
	ACALL	P2_MEAN
	ACALL	P2_MEAN

	MOV	DIV_HIGH_BYTE, COUNTER_0_UPPER_BYTE	; Prepare to display score of player 1
	MOV	DIV_LOW_BYTE, COUNTER_0_LOWER_BYTE
	MOV	R6, #1D

	ACALL	BYTES_TO_DIGITS	; Split 16 bit number into 5 digits

	ACALL	DISPLAY_INIT
	ACALL	DISP_FINAL_TIME	; Display the final time for player 1

	ACALL	DELAY
	MOV	P1, #11000000b	; Go to next line
	ACALL	TOGGLE_EN
	ACALL	DELAY

	MOV	DIV_HIGH_BYTE, COUNTER_1_UPPER_BYTE	; Prepare to display score of player 2
	MOV	DIV_LOW_BYTE, COUNTER_1_LOWER_BYTE
	MOV	R6, #2D

	ACALL	BYTES_TO_DIGITS	; Split 16 bit number into 5 digits

	ACALL	DISP_FINAL_TIME	; Display player 2's time

	MOV	P1, #00000010b	; Return cursor and display to home
	ACALL	TOGGLE_EN

	SJMP	$		; Purpose over. Stall forever

;------------------------------CHARACTER CODE LOOKUP TABLE-----------------------------------------;
	ORG	CHAR_LOOKUP_ADDR
	DB	00110000b	; 0
	DB	00110001b	; 1
	DB	00110010b	; 2
	DB	00110011b	; 3
	DB	00110100b	; 4
	DB	00110101b	; 5
	DB	00110110b	; 6
	DB	00110111b	; 7
	DB	00111000b	; 8
	DB	00111001b	; 9
	END
