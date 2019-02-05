;*******************************************************
;*_____________________________________________________*
;*                      ASTRO ATTACK                   *
;*                   a Gameboy Game by                 *
;*                        FISCH03                      *
;*_____________________________________________________*
;*                                                     *
;*                                                     *
;*      NOTE: These files won't compile because the    *
;*              EasterEgg files are missing.           *
;* In that case, change the USEEASTEREGG Constant to 0 *
;*                                                     *
;*    Please consult the README for more Information   *
;*******************************************************


USEEASTEREGG EQU 1 ;Change this to 0 if you got these files without the EasterEgg files

;-----------------PRE HEADER IMPORTS-------------------
;------------------------------------------------------
INCLUDE "src/gbhw.inc" ;Hardware Definitions
INCLUDE "src/ibmpc1.inc" ;ibmpc1 ACII text

;-----------------CONSTANTS-----------------
;-------------------------------------------

;__Game Rules__
MaxHealth EQU $03 ;Maximum Health / Starting Health
PointSize EQU $06 ;Number of Digits in the Point Display

AsteroidLifetime EQU $40 ;How long an Asteroid should last

DashDistance EQU 6

TilesPerFrame EQU 16 ;How many Tiles we Update per Frame (See UpdateCycle Variable)

ShakeDuration EQU 10 ;How long a Screenshake should Last
ShakeIntensity EQU 2

StartTextSpeed EQU 50 ;How fast the "Press Start" Text should Blink (smaller=faster)

PMinX EQU	$28 ;Minimum X the Player can have
PMaxX EQU $80 ;Maximum X the Player can have
PMinY EQU	$10 ;Minimum Y the Player can have
PMaxY EQU $68 ;Maximum Y the Player can have

FramesPerBeat EQU 26 ;~140 BPM


;__Data__
;X Coordinates of all Squares
X1 EQU $28
X2 EQU $38
X3 EQU $48
X4 EQU $58
X5 EQU $68
X6 EQU $78
;Y Coordinates of all Squares
Y1 EQU $10
Y2 EQU $20
Y3 EQU $30
Y4 EQU $40
Y5 EQU $50
Y6 EQU $60

;X Coordinates of all Square Tiles
X1T EQU $04
X2T EQU $06
X3T EQU $08
X4T EQU $0A
X5T EQU $0C
X6T EQU $0E
;Y Coordinates of all Square Tiles
Y1T EQU SCRN_VY_B*0
Y2T EQU SCRN_VY_B*2
Y3T EQU SCRN_VY_B*4
Y4T EQU SCRN_VY_B*6
Y5T EQU SCRN_VY_B*8
Y6T EQU SCRN_VY_B*10

;OAM Location offsets
OAMY EQU 0
OAMX EQU 1
OAMPatt EQU 2
OAMFlag EQU 3

PlayerOAM EQU 0*4
RocketOAM EQU 1*4

;__Cheats__
Invincible EQU 1
NoSpeedUp EQU 1

;__Other__
CharsetSize EQU 16*96

;-----------------HEADER AND INTERRUPTS--------------------
;----------------------------------------------------------
;Interrupts
SECTION "Vblank", ROM0[$0040] ;Interrupt at VBlank
	jp $FF80
SECTION	"LCDC", ROM0[$0048]
	jp CRTScroll
SECTION	"Timer_Overflow", ROM0[$0050] ;Interrupt at Timer Overflow
	jp IncreaseTick ;Update the Tick Value
SECTION "Serial", ROM0[$0058]
	reti
SECTION "p1thru4", ROM0[$0060] ;Joypad Interrupt
	reti

;-----------------VARIABLES--------------------
;----------------------------------------------
SECTION "variables",WRAM0
Variables:
;__GAME__
;DMA
OamData: ds 40*4 ;Mirror of the OamData in Memory location $FE00-$FE9F, used for DMA transfers
VBlankF ;This is set when a DMA Transfer occurs, and when the Gameboy wakes up after a halt used to check if it was because of a VBlank Interrupt

;POINTS AND HEALTH
Points: ds PointSize ;1 Byte for each Digit of the Points Display
Health: ds 1

;PLAYER LOCATION AND MOVEMENT
PSI: ds 1 ;Index Number of the Square the Player is on
PSX: ds 1 ;X Coordinate of the Square the Player is on
PSY: ds 1	;Y Coordinate of the Square the Player is on
PlayerOnAsteroid: ds 1
MoveDistance: ds 1 ;Saves how many Steps the Player moves every Frame
AllowDash: ds 1

;RNG
LFSRSeed: ds 1 ;Seed for the RNG

;TIMING
TimerTicks: ds 1 ;Increases each Time the Timer Overflows
TimerTicksDiv: ds 1 ;Increases each Time, TimerTicks gets Reset
SpawnAsteroidF: ds 1 ;If this is set, the Main Loop should Spawn a new Asteroid
UpdateAsteroidF: ds 1 ;If this is set, the Main Loop should update the Asteroids Stage
DrawAsteroidF: ds 1 ;If this is set, the Main Loop should update the Asteroids on Screen
SpawnRocketF: ds 1 ;If this is set, the Main Loop should spawn a new Rocket

;SCREEN EFFECTS
ScreenShakeF: ds 1 ;If this is Higher than 0, we shake the Screen
RollingLine: ds 1

;MUSIC
BeatProgress: ds 1 ;Gets incremented every Frame, at 140bpm one Beat takes ~26 Frames
CurrentBeat: ds 1
Beatx2: ds 1
Beatx4: ds 1
CH1Note: ds 1
CH2Note: ds 1
CH3Note: ds 1

;ASTEROID AND ROCKET INFORMATION
UpdateCycle: ds 1 ;The Gameboy can't update all the Tiles at once, so we only Update a few every Frame. This Variable saves what Tile we are on
AsteroidLocations: ds 36 ;A list of all Squares and their Status
RocketInfo: ds 1 ;Status of the Rocket
RocketY: ds 1

;__MENU__
;TITLE
StartTextBlinkTime: ds 1 ;A simulated Timer to blink the "Press Start" Text on and off
StartTextStatus: ds 1 ;Whether the Text is on or off

;SPLASH
HeartDir: ds 1

;Pause Screen
Paused: ds 1
VariablesEnd:

SECTION "start", ROM0[$0100]
nop
jp Start ;Jump to begin flag

	ROM_HEADER	ROM_NOMBC, ROM_SIZE_32KBYTE, RAM_SIZE_0KBYTE ;Rom Header

TileData:
	chr_IBMPC1	2,4 ;Load Charset

;-----------------PRE INIT IMPORTS-------------------
;----------------------------------------------------
INCLUDE "src/memory.asm" ;Memory Operations

INCLUDE "src/Tiles.z80" ;Tileset
INCLUDE "src/Background.z80" ;Background Tilemap
INCLUDE "src/Title.z80" ;Same for Title Screen
INCLUDE "src/TitleBG.z80"

IF USEEASTEREGG
INCLUDE "src/EasterEggs.inc" ;The File containing all Code for Eastereggs, you wont find it on Github for obvious reasons ;D
ENDC

;-----------------INIT--------------------
;-----------------------------------------
Start: ;Program Start
	nop

	di ;Disable Interrupts to prevent write errors

	call setup_dma ;Copy the DMA Routine into HRAM

	ld sp, $ffff ;Set Stack Pointer to last Memory Address

	ld a, %11100100 ;Load Color Palette (11 10 01 00)
	ld [rBGP], a ;Save it into $ff47

	;Set Sprite Palletes
	ldh [rOBP0], a
	ldh [rOBP1], a

	;Set Scroll registers to 0 (Right Corner)
	ld a, $00
	ld [rSCX], a
	ld [rSCY], a

	;Enable Sound
	ld a, $80
	ld [rAUDENA], a

	;Set the LCDC Interrupt to Trigger at HBLANK
	ld a, STATF_MODE00
	ld [rSTAT], a

	;Start the timer at the Highest speed possible
	ld a, TACF_START | TACF_262KHZ
	ld [rTAC], a

InitSound:
	;Load the Saw Waveform into the Wavetable RAm
	ld hl, SawWave
	ld de, _AUD3WAVERAM
	ld bc, 16
	call mem_Copy

InitVariables:
	;Clear Variables
	ld a, 0
	ld hl, Variables
	ld bc, VariablesEnd-Variables
	call mem_Set

	IF USEEASTEREGG
	call InitEE
	ENDC

	;Init Health
	ld a, MaxHealth
	ld [Health], a

	;Init MoveDistance
	ld a, $01
	ld [MoveDistance], a

InitVRAM: ;Load all Necessary Data from ROMto VRAM
	call TurnLCDOff ;Turn the LCD off to allow VRAM Modifications

	;Clear OAM
	ld a, 0
	ld hl, _OAMRAM
	ld bc, $9F
	call mem_Set

	;Clear Background
	ld a, $00
	ld hl, _SCRN0
	ld bc, SCRN_VX_B * SCRN_VY_B
	call mem_SetVRAM

	ld hl, TileData ;Load the Charset into VRAM
	ld de, _VRAM
	ld bc, 8*96 ;8 Bytes * 96 Chars
	call	mem_CopyMono

	;Load Game Tiles
	ld hl, Tiles
	ld de, _VRAM+CharsetSize ;Get VRAM Location
	ld bc, 16*51;16 Bytes per Tile
	call	mem_CopyVRAM ;Copy Tileset into VRAM

	;Load Title Tiles
	ld hl, Title ;Load the Title Tiles into VRAM
	ld de, _VRAM+CharsetSize+16*51 ;Load Tiles after the Charset and Game Tiles
	ld bc, TitletilesSize ;Size of Tiles
	call mem_CopyVRAM

	ld hl, MadewithText
	ld de, _SCRN0+(SCRN_VY_B*4)+5
	ld bc, MadewithTextEnd-MadewithText
	call mem_CopyVRAM

	ld hl, ByFisch03Text
	ld de, _SCRN0+(SCRN_VY_B*11)+5
	ld bc, ByFisch03TextEnd-ByFisch03Text
	call mem_CopyVRAM

	;Init Heart
	ld hl, Heart
	ld de, OamData
	ld bc, HeartEnd-Heart
	call mem_Copy

	;Copy the Playing Field into SCRN1, this is only used for the Pause Screen. Since SCRN1 is only used for this, we do it earlier to decrease Loading Time
	ld hl, Background
	ld de, _SCRN1
	ld bc, SCRN_VX_B * SCRN_VY_B
	call mem_CopyVRAM
	ld hl, PointsText
	ld de, _SCRN1+(SCRN_VY_B*14)+2
	ld bc, PointsTextEnd-PointsText
	call mem_CopyVRAM
	ld hl, HealthText
	ld de, _SCRN1+(SCRN_VY_B*15)+2
	ld bc, HealthTextEnd-HealthText
	call mem_CopyVRAM
	;Add a "Paused Text"
	ld hl, PauseText
	ld de, _SCRN1+(SCRN_VY_B*5)+7
	ld bc, PauseTextEnd-PauseText
	call mem_CopyVRAM

	;Turn Screen on again
	ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON
	ld [rLCDC], a

	ld a, IEF_VBLANK ;Enable the VBlank Interrupt
	ld [rIE], a
	ei

;-----------------SPLASH TEXT---------------------
;-------------------------------------------------
	ld a, $00
Splash:
	push af
	call WaitVblank
	pop af
	inc a
	cp 100
	jr nz, Splash

	ld a, $74
	ld [rNR10], a
	ld a, $7F
	ld [rNR11], a
	ld a, $F2
	ld [rNR12], a
	ld a, $11
	ld [rNR13],a
	ld a, $85
	ld [rNR14], a

Splash_up:
	call WaitVblank
	ld a, [OamData]
	sub a, $02
	ld [OamData], a
	cp $4A-$A
	jr nz, Splash_up
Splash_down:
	call WaitVblank
	ld a, [OamData]
	add a, $02
	ld [OamData], a
	cp $4A
	jr nz, Splash_down
	REPT 30
	call WaitVblank
	ENDR

;-----------------TITLE SCREEN--------------------
;-------------------------------------------------
InitTitle:

	call TurnLCDOff

	di

	ld a, $00
	ld [OamData], a

	ld hl, Titlebg ;Load the Title Background Map into VRAM
	ld de, _SCRN0
	ld bc, SCRN_VX_B * SCRN_VY_B
	call mem_CopyVRAM

	ld hl, StartText
	ld de, _SCRN0+(SCRN_VY_B*17)+4
	ld bc, StartTextEnd-StartText
	call mem_CopyVRAM

	;Turn Screen on again
	ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON
	ld [rLCDC], a

	;jp EasterEggStart

	;Start a Kick Drum on CH1
	ld hl, CH1Kick
	ld de, rNR10
	ld bc, $5
	call mem_Copy

	;Init CH2 and CH3
	ld a, $FF
	ld [rNR30], a
	ld a, $80
	ld [rNR21], a
	ld [rNR31], a
	ld a, $50
	ld [rNR22], a
	ld a, $40
	ld [rNR32], a

	;Play the first Notes on CH2
	ld a, [CH2NotesA]
	ld [rNR23], a
	ld a, [CH2NotesB]
	ld [rNR24], a
	ld a, [CH3NotesA]
	ld [rNR33], a
	ld a, [CH3NotesB]
	ld [rNR34], a

	ei

TitleScreen:
	call Music

	IF USEEASTEREGG
	call EasterEgg
	ENDC

	ld a, [StartTextBlinkTime]
	cp StartTextSpeed
	jr z, blinktext
	inc a
	ld [StartTextBlinkTime], a
blinktext_return:
	call WaitVblank
	ld a, [StartTextStatus]
	cp $00
	jr z, textoff

	ld hl, StartText
	ld de, _SCRN0+(SCRN_VY_B*17)+4
	ld bc, StartTextEnd-StartText
	call mem_CopyVRAM
textoff_return:

	ld a, P1F_4
	ld [rP1], a
	REPT 6
	ld a, [rP1] ;Read Keypresses, we are doing this multiple Times to reduce Noise
	ENDR
	and $08
	cp $08
	jr z, TitleScreen

.waitforrelease:
	call WaitVblank
	call Music
	ld a, P1F_4 ;Select Buttons
	ld [rP1], a
	REPT 6
	ld a, [rP1] ;Read Keypresses, we are doing this multiple Times to reduce Noise
	ENDR
	and $08
	cp $08
	jr nz, .waitforrelease
	jr Game_Init

blinktext:
	ld a, $00
	ld [StartTextBlinkTime], a
	ld a, [StartTextStatus]
	xor $01
	ld [StartTextStatus], a
	jr blinktext_return

textoff:
	ld a, $00
	ld hl, _SCRN0+(SCRN_VY_B*17)+4
	ld bc, StartTextEnd-StartText
	call mem_SetVRAM
	jr textoff_return

;-----------------GAME INIT--------------------
;----------------------------------------------
Game_Init:
	di ;Disable Interrupts again to prevent any Write errors

	call TurnLCDOff

	;Load Tiles
	ld hl, Tiles
	ld de, _VRAM+16*96 ;Get VRAM Location
	ld bc, 16*43;16 Bytes per Tile
	call	mem_CopyVRAM ;Copy Tileset into VRAM

	;Draw Background
	ld hl, Background
	ld de, _SCRN0
	ld bc, SCRN_VX_B * SCRN_VY_B
	call mem_CopyVRAM

	;Display the Points Text
	ld hl, PointsText
	ld de, _SCRN0+(SCRN_VY_B*14)+2
	ld bc, PointsTextEnd-PointsText
	call mem_CopyVRAM

	;Display the Health Text
	ld hl, HealthText
	ld de, _SCRN0+(SCRN_VY_B*15)+2
	ld bc, HealthTextEnd-HealthText
	call mem_CopyVRAM

	;Init Player
	ld hl, Player
	ld de, OamData
	ld bc, PlayerEnd-Player
	call mem_Copy

	ld a, OAMF_PAL0
	ld [OamData+ RocketOAM+ OAMFlag], a
	ld [OamData+ RocketOAM+4+ OAMFlag], a
	ld [OamData+ RocketOAM+8+ OAMFlag], a
	ld [OamData+ RocketOAM+12+ OAMFlag], a

	;Turn Screen on again
	ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON
	ld [rLCDC], a

	;Get the Time passed, and save it into the RNG Seed
	ld a, [rTIMA]
	ld [LFSRSeed], a

	;Start the Timer at a slower Frequency and Reset it
	ld a, TACF_START | TACF_4KHZ
	ld [rTAC], a
	ld a, $00
	ld [rTIMA], a

	;Enable Timer and VBlank Interrupts
	ld a, IEF_VBLANK | IEF_TIMER
	ld [rIE], a
	ei ;Turn Interrupts back on again

	call WaitVblank ;Wait for VBlank before starting the Main Loop to make sure the Background has been drawn

;-----------------MAIN GAME--------------------
;----------------------------------------------
MainLoop: ;Main Game Loop

	call Music ;Play the Music

	call CheckPauseScreen

	call GetPlayerSquare ;Get the Number of the Square the Player is standing on

	call UpdateAsteroids ;Update all Asteroids if requested
	call SpawnAsteroid ;Spawn a new Asteroid if requested

	call UpdateRocket
	call SpawnRocket

	call TakeDamage ;Take Damage if hit

	call ReadJoypad ;Read Joypad presses, calculate Collisions and Move the Player

	call FixPoints ;Fix the Point Bytes to keep them in Decimal Range

	call WaitVblank	;Wait for VBlank to allow VRAM Modifications

	call DisplayFX
	call DisplayAsteroids
	call DisplayHealth ;Update Healthbar
	call DisplayPoints ;Update Points

	jp MainLoop

PauseLoop:
	REPT 2
	call WaitVblank
	call Music
	call CheckMainLoop
	ENDR

	ld a, [RollingLine]
	inc a
	ld [RollingLine], a

	jp PauseLoop


;-----------------DATA FUNCTIONS--------------------
;---------------------------------------------------
CheckPauseScreen:
	ld a, P1F_4 ;Select Buttons
	ld [rP1], a
	REPT 6
	ld a, [rP1] ;Read Keypresses, we are doing this multiple Times to reduce Noise
	ENDR
	and $08
	cp $08
	jr z, .endfunction

.waitforrelease:
	call WaitVblank
	call Music
	ld a, P1F_4 ;Select Buttons
	ld [rP1], a
	REPT 6
	ld a, [rP1] ;Read Keypresses, we are doing this multiple Times to reduce Noise
	ENDR
	and $08
	cp $08
	jr nz, .waitforrelease

.preparepause:
	ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9C00|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON
	ld [rLCDC], a

	ld a, IEF_VBLANK | IEF_LCDC
	ld [rIE], a
	pop af

	ld a, $01
	ld [Paused], a

	jr PauseLoop

.endfunction:
	ret

CheckMainLoop:
	ld a, P1F_4 ;Select Buttons
	ld [rP1], a
	REPT 6
	ld a, [rP1] ;Read Keypresses, we are doing this multiple Times to reduce Noise
	ENDR
	and $08
	cp $08
	jr z, .endfunction

.waitforrelease:
	call WaitVblank
	call Music
	ld a, P1F_4 ;Select Buttons
	ld [rP1], a
	REPT 6
	ld a, [rP1] ;Read Keypresses, we are doing this multiple Times to reduce Noise
	ENDR
	and $08
	cp $08
	jr nz, .waitforrelease

.preparemain:
	pop af
	call WaitVblank
	ld a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_OBJ8|LCDCF_OBJON|LCDCF_BGON
	ld [rLCDC], a
	ld a, $00
	ld [rSCX], a

	ld a, IEF_VBLANK | IEF_TIMER
	ld [rIE], a

	ld a, $00
	ld [Paused], a

	jp MainLoop

.endfunction:
	ret

GetPlayerSquare:
.CheckY1:
	ld a, [OamData] ;Load the Player Y Coordinate
	add $04 ;Add 4 to look at the center of the player
	cp Y2 ;Compare it with the Y Coordinate of the Square below
	jr nc, .CheckY2 ;If it is Higher, jump to the next Check
	ld b, $01 ;If it is lower or Equal, save the Square number to b
	jp .CheckX1 ;Y Coordinate was found, Check for X Coordinate
.CheckY2: ;See CheckY1
	cp Y3
	jr nc, .CheckY3
	ld b, $02
	jp .CheckX1
.CheckY3: ;See CheckY1
	cp Y4
	jr nc, .CheckY4
	ld b, $03
	jp .CheckX1
.CheckY4: ;See CheckY1
	cp Y5
	jr nc, .CheckY5
	ld b, $04
	jp .CheckX1
.CheckY5: ;See CheckY1
	cp Y6
	jr nc, .CheckYEnd
	ld b, $05
	jp .CheckX1
.CheckYEnd: ;The remaining Y Coordinate can only be 6
	ld b, $06

.CheckX1: ;See CheckY1
	ld a, [OamData+1]
	add $04
	cp X2
	jr nc, .CheckX2
	ld c, $01
	jp .CheckEnd
.CheckX2: ;See CheckY1
	cp X3
	jr nc, .CheckX3
	ld c, $02
	jp .CheckEnd
.CheckX3: ;See CheckY1
	cp X4
	jr nc, .CheckX4
	ld c, $03
	jp .CheckEnd
.CheckX4: ;See CheckY1
	cp X5
	jr nc, .CheckX5
	ld c, $04
	jp .CheckEnd
.CheckX5: ;See CheckY1
	cp X6
	jr nc, .CheckXEnd
	ld c, $05
	jp .CheckEnd
.CheckXEnd: ;The remaining X Coordinate can only be 6
	ld c, $06

.CheckEnd:
	ld a, c ;Save the X Coordinate
	ld [PSX], a
	ld a, b ;Save the Y Coordinate
	ld [PSY], a
	;All done, now we give each Square its own Index Number by Calculating I=(Y*6)+X
	ld c, $00 ;Set c to Zero, it will be the result of our Multiplication
	dec a ;Decrease a, making it range from 0-5
	cp $00 ;Check if we need to Multiplicate
	jr z, .endSCheck
.multloop:
	push af ;If yes, save our iteration count for later
	ld a, c ;Add 6 to c
	add $06
	ld c, a
	pop af ;Get the iteration count back
	dec a ;Decrease it by 1
	cp $00 ;Check if the Multiplication is done
	jr nz, .multloop
.endSCheck
	ld a, [PSX] ;If it is, get the X Coordinate and save it to b
	ld b, a
	ld a, c ;Get our multiplication Result
	add b ;Add our X Coordinate to it
	dec a ;Sub one to make the result Range from 0-35
	ld [PSI], a ;Save it into the PlayerSquareIndex
.getplayerstatus: ;Check if the Player is Currently standing on an asteroid
	ld b, $00
	ld c, a
	ld hl, AsteroidLocations
	add hl, bc
	ld a, [hl]
	cp $06
	jr nz, .noasteroid
	ld a, $01
	ld [PlayerOnAsteroid], a
	jr .endfunction
.noasteroid:
	ld a, $00
	ld [PlayerOnAsteroid], a
.endfunction:
	ret

SpawnAsteroid:
	ld a, [SpawnAsteroidF] ;Check if a new Asteroid is requested
	or a
	jr z, .endspawn ;If not, exit the Function

	call RandLFSR
	ld a, [LFSRSeed] ;Decide if the asteroid gets Spawned at the Player location, or a randowm one
	and $03
	or a
	jr z, .playerasteroid
.randomfinderloop:
	call RandLFSR ;Get a new Random Number
	ld a, [LFSRSeed]
	cp $24 ;Check if it is below $24 (36 in decimal)
	jr nc, .randomfinderloop ;If not, try again

	ld hl, AsteroidLocations ;Load the Memory Location of the array AsteroidLocations into hl
	ld b, $00 ;Save a into the 16-bit register pair bc
	ld c, a
	add hl, bc ;Add bc to hl
	ld a, [hl] ;Check if the asteroid is already set
	cp $00
	jr nz, .randomfinderloop ;If it is, find a new Location

	ld a, $01 ;If not, set it
	ld [hl], a
	jr .endspawn

.playerasteroid: ;Spawn an Asteroid at the Players location
	ld hl, AsteroidLocations ;Load the Memory Location of the array AsteroidLocations into hl
	ld a, [PSI] ;Get the Index of the Square the Player is standing on
	ld b, $00 ;Save a into the 16-bit register pair bc
	ld c, a
	add hl, bc ;Add bc to hl, hl now points to the Square the player is Standing on
	ld a, [hl]
	cp $00 ;Check if the asteroid is already set
	jr nz, .randomfinderloop ;If it is, place an asteroid a Random Location

	ld a, $01 ;If not, set it
	ld [hl], a

.endspawn: ;Finish off by telling the Main Loop that we are done
	ld a, $00 ;Reset the Asteroid Request
	ld [SpawnAsteroidF], a
	ret

UpdateAsteroids:
	ld a, [UpdateAsteroidF] ;Check if the Asteroids need to be Updated
	or a
	jr z, .endupdate ;If not, Quit the Function

  ld hl, AsteroidLocations
	ld b, $00
.updateloop:
	ld a, [hl] ;Get Asteroid Stage from AsteroidLocations Array
	cp $00 ;If it is 0, skip the Update
	jr z, .prepnextloop
	cp AsteroidLifetime ;If it is too high, remove the Asteroid
	jr z, .removeasteroid
	inc a ;If not, Increase the Stage
	ld [hl], a

	cp $05 ;If the Stage is now 5 (The Asteroid hits the Floor), give the Player Points
	jr nz, .prepnextloop
	ld a, [Points+5]
	add a, 25
	ld [Points+5], a

.prepnextloop:
	inc b ;Increase the Counter
	inc hl ;Increase the Pointer towards the Current AsteroidStage
	ld a, b ;Check if we are done with all Squares
	cp 36
	jr nz, .updateloop

	ld a, $01 ;Tell the Main Loop, that we want to draw the new Asteroids
	ld [DrawAsteroidF], a
	ld a, $00 ;Tell the Main Loop, that we are done with drawing the Asteroids
	ld [UpdateAsteroidF], a
.endupdate
	ret

.removeasteroid:
	ld a, $00
	ld [hl], a
	jr .prepnextloop

SpawnRocket:
	ld a, [SpawnRocketF]
	or a
	jr z, .endfunction
	ld a, [RocketInfo]
	or a
	jr nz, .endfunction

.tryspawn
	call RandLFSR
	ld a, [LFSRSeed]
	cp RocketStartsEnd-RocketStarts
	jr nc, .tryspawn
	ld [RocketY], a
	ld e, a
	ld a, $00
	ld d, a
	ld hl, RocketStarts
	add hl, de
	ld a, [hl]

	ld [OamData+ RocketOAM+ OAMY], a
	ld [OamData+ RocketOAM+8+ OAMY], a
	add a, $08
	ld [OamData+ RocketOAM+4+ OAMY], a
	ld [OamData+ RocketOAM+12+ OAMY], a

	ld a, X1
	ld [OamData+ RocketOAM+ OAMX], a
	ld [OamData+ RocketOAM+4+ OAMX], a
	add a, $08
	ld [OamData+ RocketOAM+8+ OAMX], a
	ld [OamData+ RocketOAM+12+ OAMX], a

	ld a, $8B
	ld [OamData+ RocketOAM+ OAMPatt], a
	inc a
	ld [OamData+ RocketOAM+4+ OAMPatt], a
	inc a
	ld [OamData+ RocketOAM+8+ OAMPatt], a
	inc a
	ld [OamData+ RocketOAM+12+ OAMPatt], a

	ld a, $01
	ld [RocketInfo], a

.endfunction:
	ld a, $00
	ld [SpawnRocketF], a
	ret

UpdateRocket:
	ld a, [RocketInfo]
	or a
	jr z, .endfunction
	cp $D0
	jr nc, .despawn
	inc a
	ld [RocketInfo], a

	cp $80
	jr c, .endfunction

	ld a, $8F
	ld [OamData+ RocketOAM+ OAMPatt], a
	inc a
	ld [OamData+ RocketOAM+4+ OAMPatt], a
	inc a
	ld [OamData+ RocketOAM+8+ OAMPatt], a
	inc a
	ld [OamData+ RocketOAM+12+ OAMPatt], a

	ld a, [OamData+ RocketOAM+ OAMX]
	inc a
	ld [OamData+ RocketOAM+ OAMX], a
	ld [OamData+ RocketOAM+4+ OAMX], a

	ld a, [OamData+ RocketOAM+8+ OAMX]
	inc a
	ld [OamData+ RocketOAM+8+ OAMX], a
	ld [OamData+ RocketOAM+12+ OAMX], a

	jr .endfunction

.despawn:
	ld a, $FF
	ld [OamData+ RocketOAM+ OAMX], a
	ld [OamData+ RocketOAM+4+ OAMX], a
	ld [OamData+ RocketOAM+8+ OAMX], a
	ld [OamData+ RocketOAM+12+ OAMX], a

.endfunction:
	ret

FixPoints:
	ld hl, Points+PointSize ;Load the Location of the Rightmost Digit
	ld d, h ;Copy hl...
	ld e, l ;...into de
	dec de ;Decrease de by 1
	ld b, PointSize ;Load the Number of Digits into b
.fixpointloop:
 	ld a, [hl] ;Load the Digit at hl into a
	cp $0A ;Check if it is higher than $09
	jr c, .fix_done
	sub $0A ;If it is, decrease it by $0A (10 in Decimal)
	ld [hl], a ;Save that Digit
	ld a, [de] ;Load the digit 1 to the left into a
	inc a ;Increase it by 1
	ld [de], a ;Save that Digit
	jr .fixpointloop ;Jump back to the start of the loop
.fix_done:
	dec hl ;Jump to the next Digit
	dec de
	dec b
	ld a, b
	cp $00 ;Check if all Digits have been Fixed
	jr nz, .fixpointloop
	ret

TakeDamage:
	ld hl, AsteroidLocations
	ld a, [PSI] ;Check if the Player is standing on the Square that was just hit
	ld b, $00
	ld c, a
	add hl, bc
	ld a, [hl]

	cp $05 ;Check if the Square is Currently Hit
	jr nz, .checkrockets ;If not, end the Function
	call DecreaseLife
	ld a, $00
	ld [hl], a ;Reset the Asteroid

.checkrockets:
	ld a, [RocketInfo]
	cp $80
	jr c, .endfunction

	ld a, [PSY]
	ld b, a
	ld a, [RocketY]
	inc a
	cp b
	jr nz, .endfunction

	ld a, [OamData+ PlayerOAM+ OAMX]
	add $04
	ld b, a
	ld a, [OamData+ RocketOAM+ OAMX]
	cp b
	jr nc, .endfunction
	add $0F
	cp b
	jr c, .endfunction
	call DecreaseLife
	ld a, $FF
	ld [OamData+ RocketOAM+ OAMX], a
	ld [OamData+ RocketOAM+4+ OAMX], a
	ld [OamData+ RocketOAM+8+ OAMX], a
	ld [OamData+ RocketOAM+12+ OAMX], a
	ld [RocketInfo], a

.endfunction:
	ret

DecreaseLife:
	ld a, ShakeDuration ;Start a Screen Shake
	ld [ScreenShakeF], a
	ld a, [Health] ;Decrease the Lifes of the Player
	dec a
	cp $00 ;Check if the Health is at 0
	IF !Invincible
	jp z, Start ;CHANGE IN FUTURE!  If yes, restart the Game
	ENDC
	ld [Health], a
	ret

RandLFSR: ;Generate a new (Pseudo)Random Number
	ld a, [LFSRSeed] ;Load the seed into b
	ld b, a
.lfsrloop:
	ld c, a ;Load the Seed into c

	rr c ;Shift to the Right x4
	rr c
	rr c
	rr c
	xor c ;Tap at 3
	rr c ;Shift to the Right x1
	xor c ;Tap at 4
	rr c ;Shift to the Right x1
	xor c ;Tap at 6
	rr c ;Shift to the Right x2
	rr c
	xor c ;Tap at 8

	ld b, a
	ld a, [rDIV]
	xor b

	cp b ;Check if the Random Number is a new one
	jr z, .lfsrloop
	ld [LFSRSeed], a ;If it isn´t, save it as the new Seed

	ret

;-----------------VRAM FUNCTIONS--------------------
;---------------------------------------------------
DisplayFX:
	ld a, [ScreenShakeF] ;Check if the Screen needs to be shaked
	or a
	jr z, .endfunction ;If not, end this Function
	dec a ;If yes, Decrease a by 1. a contains the number of Frames the shake will be applied
	or a ;Check if a is now 0
	jr z, .resetx ;If yes, Reset the x Scroll
	ld [ScreenShakeF], a

	call RandLFSR ;Get a new Random Number
	ld a, [LFSRSeed]
	and $01 ;Decide whether the X Scroll will be increased or decrased
	or a
	jr z, .subx
.addx:
	call RandLFSR ;Get a new Random Number
	ld a, [rSCX] ;Load the Current X Scroll into a
	ld b, a ;Save it into b
	ld a, [LFSRSeed]
	and ShakeIntensity ;And the Random number with the Intensity. It now ranges from 0 to the ShakeIntensity Value
	add a, b ;Add the Scroll Register to it
	ld [rSCX], a ;Save the new Value
	jr .endfunction
.subx: ;Same as addx, but subtracts from the X Scroll register
	call RandLFSR
	ld a, [rSCX]
	ld b, a
	ld a, [LFSRSeed]
	and ShakeIntensity
	sub a, b
	ld [rSCX], a
	jr .endfunction
.resetx: ;If the shaking is done, we reset the Scroll Register
	ld a, $00
	ld [rSCX], a
	ld [ScreenShakeF], a
.endfunction:
	ret

DisplayHealth:
	ld hl, _SCRN0+(SCRN_VY_B*15)+10 ;Load the Healthbar Position into hl
	ld a, [Health]
	cp $00
	jr z, .endclear
.healthdrawloop
	ld [hl], $8A ;Draw a Heart at hl
	dec a
	inc hl ;Increase Health Location
	cp $00 ;Check if all Hearts are already drawn
	jr nz, .healthdrawloop
	;All done, now clear the rest of the Healthbar
	ld a, [Health] ;Get Current Health again
	cp $08 ;Check if there is Space to clear at the Healthbar
	jr z, .endclear
.healthclearloop
	ld [hl], $89 ;Load an empty Tile at hl
	inc hl ;Increase Space Location
	inc a
	cp $08 ;Check if there is Space to clear at the Healthbar
	jr nz, .healthclearloop
.endclear
	ret

DisplayPoints:
	ld hl, Points ;Load Points RAM Location into hl
	ld de, _SCRN0+(SCRN_VY_B*14)+10 ;Load Points Position into de
	ld b, PointSize
.pointShowLoop
	ld a, [hl+] ;Load the current Digit into a
	add $10 ;Add $10 to get the Tile Number
	ld [de], a ;Save Tile Number at Current Screen Location
	inc de ;Increase Location
	dec b
	ld a, b
	cp $00 ;Check if all Points are Drawn
	jr nz, .pointShowLoop
	ret

DisplayAsteroids:
	ld a, [DrawAsteroidF] ;Check if we need to Update the Asteroids
	or a
	jr z, .endfunction

	ld hl, AsteroidLocations
	ld b, $00
	ld a, [UpdateCycle]
	ld c, a
	add hl, bc
.displayloop:
	ld a, [hl+] ;Get Asteroid Stage from AsteroidLocations Array
	push hl ;Save hl for later
	cp $07 ;If the Stage Number is too high, we don´t have to update
	jr nc, .prepnextloop
	ld e, a ;Save Stage in e, to make it into a 16-bit value (Register de)
	ld d, $00

	ld hl, AsteroidStages ;Get the Location of the Array we use to get the Tile number
	add hl, de ;Add the Current Asteroid Stage to it
	ld a, [hl] ;Load the Tile Number we want into a
	push af ;Save it for later

	ld hl, IndexToRamLocA ;Load the location for table of higher bytes into hl
	add hl, bc ;Add the Index Number of the Tile we are modifying to it
	ld a, [hl] ;Get the higher byte and save it to d
	ld d, a
	ld hl, IndexToRamLocB ;Load the location for table of lower bytes into hl
	add hl, bc ;Add the Index Number of the Tile we are modifying to it
	ld a, [hl] ;Save it into l
	ld l, a
	ld a, d ;And d into h
	ld h, a ;hl now Points to the Memory location we want to write to

	;After Calculating everything, we now save all our Tiles to VRAM
	pop af ;Get the Tile Number we Calculated earlier
	ld [hl], a ;Save it to the Corresponding Screen location
	inc hl ;Go to the next Location (1 to the Right)
	add a, $02 ;The tile we want lies 2 locations after the last one in memory
	ld [hl], a ;Save the next Tile
	ld d, $00 ;Get our 16-Bit Register de to the Value $001F
	ld e, $1F
	add hl, de ;Go to the next location (1 under the first one)
	dec a ;The tile we want lies 1 location before the last one in Memory
	ld [hl], a ;Save the next Tile
	inc hl ;Go to the next Location (1 to the Right)
	add a, $02 ;The tile we want lies 2 locations after the last one in memory
	ld [hl], a ;Save the next Tile

.prepnextloop:
	pop hl ;Get hl back
	inc c ;Increase our Counter
	ld a, [UpdateCycle] ;Get the current Cycle we are in
	add TilesPerFrame/4 ;Add the Number of Tiles we Update each Frame to it (We divide by 4 because every Square takes 4 Tiles to draw)
	cp c ;Check if we have already updated all Tiles we wanted this Frame
	jr nz, .displayloop
.newcycle:
	cp 36 ;If our UpdateCycle is bigger than 36, we are done with updating all Squares
	jr nc, .resetcycle ;If it is, we reset it
	ld [UpdateCycle], a ;If not, we update it
	jr .endfunction
.resetcycle
	ld a, $00
	ld [UpdateCycle], a
	ld [DrawAsteroidF], a ;We are done Updating our Squares, so we can unset the DrawAsteroidF Variable
.endfunction:
	ret

;-----------------TIMING--------------------
;-------------------------------------------
IncreaseTick:
	push af ;Save af to make sure it is the same when returning from Interrupt
	push bc

	ld a, [TimerTicks] ;Check if we have to reset the Ticks
	cp 3
	jr z, .tickreset ;If yes, reset them
	inc a ;If not, increase them
	ld [TimerTicks], a
	jr .tickincreaseend

.tickreset:
	ld a, $00 ;Reset the Ticks
	ld [TimerTicks], a
	ld a, $01 ;Tell the Main Loop that we want to Update the Asteroids
	ld [UpdateAsteroidF], a

	ld a, [TimerTicksDiv] ;Check if we have to reset the TicksDiv
	cp 3
	jr z, .tickresetdiv ;If yes, reset them
	inc a ;If not, Increase them
	ld [TimerTicksDiv], a

	jr .tickincreaseend

.tickresetdiv:

	IF !NoSpeedUp
	;CHANGE IN FUTURE! Increase the timer Modulo to make the timer Reset fasters
	ld a, [rTMA]
	inc a
	ld [rTMA], a
	ENDC

	ld a, $00 ;Reset the TicksDiv
	ld [TimerTicksDiv], a

	ld a, $01
	ld [SpawnAsteroidF], a ;Tell the Main Loop that we want to Spawn a new Asteroid

	call RandLFSR
	ld a, [LFSRSeed]
	cp 75
	jr nc, .tickincreaseend

	ld a, $01
	ld [SpawnRocketF], a

.tickincreaseend:
	pop bc
	pop af

	reti

;-----------------JOYPAD--------------------
;-------------------------------------------
ReadJoypad:
	ld a, [MoveDistance] ;Decrease the MoveDistance if it is higher than 1
	cp $01
	jr nz, UpdateMovDist ;If it is, we arent finished Dashing, so skip it

CheckDash:
	ld a, P1F_4 ;Select Buttons
	ld [rP1], a
	REPT 6
	ld a, [rP1] ;Read Keypresses, we are doing this multiple Times to reduce Noise
	ENDR
	cpl ;Invert everything

	and $01 ;Filter out everything except the A Button
	cp $01
	jr nz, UpdateAllowDash

	ld a, [AllowDash]
	cp $01
	jr nz, MovePlayer

	ld a, $00
	ld [AllowDash], a

	ld a, DashDistance
	ld [MoveDistance], a

	jr MovePlayer

UpdateAllowDash:
	ld a, $01
	ld [AllowDash], a
	jr MovePlayer

UpdateMovDist:
	dec a
	ld [MoveDistance], a

MovePlayer:
	ld a, P1F_5	;Select Direction Keys
	ld [rP1], a
	REPT 6
	ld a, [rP1]	;Read Keypresses, we are doing this multiple Times to reduce Noise
	ENDR
	cpl	;Invert Bits
	ld d, a	;Backup the Value

	;Right Key
	and $01	;Filter out Uneccesary Keys
	cp $01 ;Check for Right one
	jr z, ReadJoypadRight	;Jump if Key Pressed
	;Left Key
	ld a, d
	and $02
	cp $02
	jr z, ReadJoypadLeft
ReadJoypadX_return:
	;Up Key
	ld a, d
	and $04
	cp $04
	jr z, ReadJoypadUp
	;Down Key
	ld a, d
	and $08
	cp $08
	jr z, ReadJoypadDown
ReadJoypadY_return:
	ret

ReadJoypadUp:
		ld a, [OamData] ;Decrease the Players Y Coordinate if it is within the Playing area
		cp PMinY+1
		jr c, FixYLow
		ld hl, MoveDistance
		sub [hl]
		ld e, a
		call PredictPlayerSquareY
		or a
		jr nz, ReadJoypadY_return
		ld a, e
		ld [OamData], a
		jp ReadJoypadY_return
ReadJoypadRight: ;Increase the Players X Coordinate if it is within the Playing area
		ld a, [OamData+1]
		cp PMaxX-1
		jr nc, FixXHigh
		ld hl, MoveDistance
		add [hl]
		ld e, a
		call PredictPlayerSquareX
		or a
		jr nz, ReadJoypadX_return
		ld a, e
		ld [OamData+1], a
		jp ReadJoypadX_return
ReadJoypadDown: ;Increase the Players Y Coordinate if it is within the Playing area
		ld a, [OamData]
		cp PMaxY-1
		jr nc, FixYHigh
		ld hl, MoveDistance
		add [hl]
		ld e, a
		call PredictPlayerSquareY
		or a
		jr nz, ReadJoypadY_return
		ld a, e
		ld [OamData], a
		jp ReadJoypadY_return
ReadJoypadLeft: ;Decrease the Players X Coordinate if it is within the Playing area
		ld a, [OamData+1]
		cp PMinX+1
		jr c, FixXLow
		ld hl, MoveDistance
		sub [hl]
		ld e, a
		call PredictPlayerSquareX
		or a
		jr nz, ReadJoypadX_return
		ld a, e
		ld [OamData+1], a
		jp ReadJoypadX_return

FixXLow:
	ld a, PMinX
	ld [OamData+1], a
	jr ReadJoypadX_return
FixXHigh:
	ld a, PMaxX
	ld [OamData+1], a
	jp ReadJoypadX_return
FixYLow:
	ld a, PMinY
	ld [OamData], a
	jr ReadJoypadY_return
FixYHigh:
	ld a, PMaxY
	ld [OamData], a
	jp ReadJoypadY_return

PredictPlayerSquareY: ;The same as GetPlayerSquare, but only for Y, and the Result doesnt get saved into a Variable
.CheckY1:
	add $04 ;Add 4 to look at the center of the player
	cp Y2 ;Compare it with the Y Coordinate of the Square below
	jr nc, .CheckY2 ;If it is Higher, jump to the next Check
	ld b, $01 ;If it is lower or Equal, save the Square number to b
	jp .CheckEnd ;Y Coordinate was found, Check for X Coordinate
.CheckY2: ;See CheckY1
	cp Y3
	jr nc, .CheckY3
	ld b, $02
	jp .CheckEnd
.CheckY3: ;See CheckY1
	cp Y4
	jr nc, .CheckY4
	ld b, $03
	jp .CheckEnd
.CheckY4: ;See CheckY1
	cp Y5
	jr nc, .CheckY5
	ld b, $04
	jp .CheckEnd
.CheckY5: ;See CheckY1
	cp Y6
	jr nc, .CheckYEnd
	ld b, $05
	jp .CheckEnd
.CheckYEnd: ;The remaining Y Coordinate can only be 6
	ld b, $06

.CheckEnd:
	ld a, b ;Save the Y Coordinate
	;All done, now we give each Square its own Index Number by Calculating I=(Y*6)+X
	ld c, $00 ;Set c to Zero, it will be the result of our Multiplication
	dec a ;Decrease a, making it range from 0-5
	cp $00 ;Check if we need to Multiplicate
	jr z, .endSCheck
.multloop:
	push af ;If yes, save our iteration count for later
	ld a, c ;Add 6 to c
	add $06
	ld c, a
	pop af ;Get the iteration count back
	dec a ;Decrease it by 1
	cp $00 ;Check if the Multiplication is done
	jr nz, .multloop
.endSCheck
	ld a, [PSX] ;If it is, get the X Coordinate and save it to b
	ld b, a
	ld a, c ;Get our multiplication Result
	add b ;Add our X Coordinate to it
	dec a ;Sub one to make the result Range from 0-35
.getplayerstatus: ;Check if the Player is Currently standing on an asteroid
	ld b, $00
	ld c, a
	ld hl, AsteroidLocations
	add hl, bc
	ld a, [hl]
	cp $06
	jr c, .noasteroid
	ld a, $01
	jr .endfunction
.noasteroid:
	ld a, $00
.endfunction:
	ret

PredictPlayerSquareX:
.CheckX1: ;See CheckY1
	add $04
	cp X2
	jr nc, .CheckX2
	ld b, $01
	jp .CheckEnd
.CheckX2: ;See CheckY1
	cp X3
	jr nc, .CheckX3
	ld b, $02
	jp .CheckEnd
.CheckX3: ;See CheckY1
	cp X4
	jr nc, .CheckX4
	ld b, $03
	jp .CheckEnd
.CheckX4: ;See CheckY1
	cp X5
	jr nc, .CheckX5
	ld b, $04
	jp .CheckEnd
.CheckX5: ;See CheckY1
	cp X6
	jr nc, .CheckXEnd
	ld b, $05
	jp .CheckEnd
.CheckXEnd: ;The remaining X Coordinate can only be 6
	ld b, $06

.CheckEnd:
	ld a, [PSY]
	;All done, now we give each Square its own Index Number by Calculating I=(Y*6)+X
	ld c, $00 ;Set c to Zero, it will be the result of our Multiplication
	dec a ;Decrease a, making it range from 0-5
	cp $00 ;Check if we need to Multiplicate
	jr z, .endSCheck
.multloop:
	push af ;If yes, save our iteration count for later
	ld a, c ;Add 6 to c
	add $06
	ld c, a
	pop af ;Get the iteration count back
	dec a ;Decrease it by 1
	cp $00 ;Check if the Multiplication is done
	jr nz, .multloop
.endSCheck
	ld a, b ;If it is, get the X Coordinate and save it to b
	ld b, a
	ld a, c ;Get our multiplication Result
	add b ;Add our X Coordinate to it
	dec a ;Sub one to make the result Range from 0-35
.getplayerstatus: ;Check if the Player is Currently standing on an asteroid
	ld b, $00
	ld c, a
	ld hl, AsteroidLocations
	add hl, bc
	ld a, [hl]
	cp $06
	jr c, .noasteroid
	ld a, $01
	jr .endfunction
.noasteroid:
	ld a, $00
.endfunction:
	ret

;-----------------MUSIC---------------------
;-------------------------------------------
Music:
	;Check if we are allowed to play the next Beat
	ld a, [BeatProgress]
	inc a
	ld [BeatProgress], a
	cp 26
	jr nz, .endfunction
	ld a, $00
	ld [BeatProgress], a

.incbeat:
	ld a, [CurrentBeat]
	inc a
	ld [CurrentBeat], a
	cp 4
	jr nz, .incbeat_finish
	ld a, $00
	ld [CurrentBeat], a
.incbeat_finish:

	;Update all Flags Accordingly
	ld a, [Beatx2]
	inc a
	ld [Beatx2], a
	cp 2
	jr nz, .endx2
	ld a, $00
	ld [Beatx2], a
.endx2:
	ld a, [CurrentBeat]
	or a
	jr nz, .resetx4
	ld a, $01
	jr .endx4
.resetx4
	ld a, $00
.endx4
	ld [Beatx4], a

	;Play all channels that get Played every Beat
	jr .playch2
.playch2_return:
	jr .playch3
.playch3_return:

	;Play all channels that get Played every 4. Beat
	ld a, [CurrentBeat]
	cp $02
	jp z, .playch1
.playch1_return:

	;Play Percussion
	ld a, [CurrentBeat]
	cp $00
	jp z, .playkick
	cp $02
	jp z, .playsnare
	jp .playhat
.perc_return:

.endfunction:
	ret

.playch1:
	ld a, $00
	ld [rNR10], a
	ld a, $80
	ld [rNR11], a
	ld a, $50
	ld [rNR12], a

	ld a, [CH1Note]
	inc a
	ld [CH1Note], a
	cp CH1NotesB-CH1NotesA
	jr nz, .ch1skipreset
	ld a, $00
	ld [CH1Note], a
.ch1skipreset:
	ld b, $00
	ld c, a
	ld hl, CH1NotesA
	add hl, bc
	ld a, [hl]
	ld [rNR13], a
	ld hl, CH1NotesB
	add hl, bc
	ld a, [hl]
	ld [rNR14], a
	jr .playch1_return

.playch2:
	ld a, [CH2Note]
	inc a
	ld [CH2Note], a
	cp CH2NotesB-CH2NotesA
	jr nz, .ch2skipreset
	ld a, $00
	ld [CH2Note], a
.ch2skipreset:
	ld b, $00
	ld c, a
	ld hl, CH2NotesA
	add hl, bc
	ld a, [hl]
	ld [rNR23], a
	ld hl, CH2NotesB
	add hl, bc
	ld a, [hl]
	ld [rNR24], a
	jr .playch2_return

.playch3:
	ld a, [CH3Note]
	inc a
	ld [CH3Note], a
	cp CH3NotesB-CH3NotesA
	jp nz, .ch3skipreset
	ld a, $00
	ld [CH3Note], a
.ch3skipreset:
	ld b, $00
	ld c, a
	ld hl, CH3NotesA
	add hl, bc
	ld a, [hl]
	ld [rNR33], a
	ld hl, CH3NotesB
	add hl, bc
	ld a, [hl]
	ld [rNR34], a
	jp .playch3_return

.playhat:
	ld hl, CH4Hat
	ld de, rNR41
	ld bc, $4
	call mem_Copy
	jp .perc_return

.playsnare:
	ld hl, CH4Snare
	ld de, rNR41
	ld bc, $4
	call mem_Copy
	jp .perc_return

.playkick:
	ld hl, CH1Kick
	ld de, rNR10
	ld bc, $5
	call mem_Copy
	jp .perc_return

;-----------------CONSTANT DATA-------------
;-------------------------------------------

INCLUDE "src/charmap.inc" ;Map each Character to its corresponding Tile number

Player: ;Player starting OEM entry
	db PMinY,PMinX,$88,OAMF_PAL0 ;Top Left Corner
PlayerEnd:

PointsText: ;Hex Values for Points Text
	;db	$30,$4F,$49,$4E,$54,$53,$1A
	db "Points"
PointsTextEnd:

HealthText: ;Hex Values for Health Text
	db	"Health"
HealthTextEnd:

StartText:
	db "PRESS START"
StartTextEnd:

PauseText:
	db "PAUSED"
PauseTextEnd:

;__SPLASH TEXT__
MadewithText:
	db "MADE WITH"
MadewithTextEnd:
ByFisch03Text:
	db "BY FISCH03"
ByFisch03TextEnd:
Heart:
	db $4A,$53,$8A,OAMF_PAL0
HeartEnd:

IndexToRamLocA: ;Table to Convert the Square Index to a Screen Memory Location. This could be done by Multiplicating, but we save CPU power by precalculating the results
	db $98, $98, $98, $98, $98, $98
	db $98, $98, $98, $98, $98, $98
	db $98, $98, $98, $98, $98, $98
	db $98, $98, $98, $98, $98, $98
	db $99, $99, $99, $99, $99, $99
	db $99, $99, $99, $99, $99, $99
IndexToRamLocB: ;Table to Convert the Square Index to a Screen Memory Location. This could be done by Multiplicating, but we save CPU power by precalculating the results
	db $04, $06, $08, $0A, $0C, $0E
	db $44, $46, $48, $4A, $4C, $4E
	db $84, $86, $88, $8A, $8C, $8E
	db $C4, $C6, $C8, $CA, $CC, $CE
	db $04, $06, $08, $0A, $0C, $0E
	db $44, $46, $48, $4A, $4C, $4E

RocketStarts:
	db Y1,Y2,Y3,Y4,Y5,Y6
RocketStartsEnd:

AsteroidStages: ;Tile Number for each Asteroid Stage
	db $60,$64,$68,$6C,$70,$74,$78

TriWave: ;Wavetable Data for a Triangle Wave (16 Bytes)
	db $01,$23,$45,$67,$89,$AB,$CD,$EF,$FE,$DC,$BA,$98,$76,$54,$32,$10
SawWave: ;Wavetable Data for a Saw Wave (16 Bytes)
	db $00,$11,$22,$33,$44,$55,$66,$77,$88,$99,$AA,$BB,$CC,$DD,$EE,$FF


CH1NotesA:
     ;F3 ,F3 ,F3 ,G#3,F3 ,F3 ,G#3,G#3   (All shifted 1 to the right)
	db $23,$23,$23,$12,$23,$23,$12,$12
CH1NotesB:
	db $82,$82,$82,$83,$82,$82,$83,$83

CH2NotesA:
     ;C4, C4, C4, C4, F4, F4, G4, G4,D#4,D#4,D#4,D#4, C4, C4, C4, C4
	db $16,$16,$16,$16,$11,$11,$63,$63,$B5,$B5,$B5,$B5,$16,$16,$16,$16
     ;C4, F4, G4, F4,D#4,D#4, G4, F4,D#4,D#4,D#4, G4, C4, C4, C4, C4
	db $16,$11,$63,$11,$B5,$B5,$63,$11,$B5,$B5,$B5,$63,$16,$16,$16,$16
CH2NotesB:
	db $84,$84,$84,$84,$85,$85,$85,$85,$84,$84,$84,$84,$84,$84,$84,$84
	db $84,$85,$85,$85,$84,$84,$85,$85,$84,$84,$84,$85,$84,$84,$84,$84

CH3NotesA:
		 ;F4,G#4, C5,D#5, F5, G5, G5, G5, F5,D#5, C5,G#4, F4, F4, F4, F4
	db $11,$89,$0A,$5B,$89,$B2,$B2,$B2,$89,$5B,$0A,$89,$11,$11,$11,$11
		 ;F4,G#4, C5,D#5, G5, F5,D#5, G5, G5, F5,D#5, G5, F4, F4, F4, F4
	db $11,$89,$0A,$5B,$B2,$89,$5B,$B2,$B2,$89,$5B,$B2,$11,$11,$11,$11
CH3NotesB:
	db $85,$85,$86,$86,$86,$86,$86,$86,$86,$86,$86,$85,$85,$85,$85,$85
	db $85,$85,$86,$86,$86,$86,$86,$86,$86,$86,$86,$86,$85,$85,$85,$85

CH1Kick:
	db $2B,$80,$A2,$78,$85
CH4Hat:
	db $00,$71,$31,$C0
CH4Snare:
 	db $20,$D1,$33,$C0

;-----------------SCREEN--------------------
;-------------------------------------------
TurnLCDOff:
	;Wait for VBlank to safely turn off
	ld   a, [rLY] ;Get the current Line the Screen is on
	cp   145 ;Vblank is at 144, but we wait one more to make sure we don't interfere with the Vblank Interrupt
	jr   nz, TurnLCDOff ;If not, Jump Back and try again
	; Turn off the LCD
	ld a, [rLCDC]
  res 7,a
  ld [rLCDC], a
	ret

WaitVblank:
	ld hl, VBlankF ;Make Hl point to the VBlankF Variable
	ld a, $00 ;Set a to zero
.wait:
	halt ;Stop the CPU until an Interrupt Occurs
	nop ;Prevent a bug in the Gameboy, where the Command after the halt will be skipped
	cp a, [hl] ;Check if VBlankF is 1
	jr z, .wait ;If it isn't Suspend the CPU again
	ld [hl], a ;If it is, we are in VBlank
	ret

WaitVblankOld:
	ld   a, [rLY] ;Get the current Line the Screen is on
	cp   145 ;Vblank is at 144, but we wait one more to make sure we don't interfere with the Vblank Interrupt
	jr   nz, WaitVblankOld ;If not, Jump Back and try again
	ret

CRTScroll:
	push af
	push bc

	ld a, [RollingLine]
	ld b, a
	ld a, [rLY]
	cp b
	jr z, .setscroll
	REPT 8
	inc a
	cp b
	jr z, .setscroll
	ENDR

.resetscroll:
	ld a, $00
	ld [rSCX], a
	jr .endscroll

.setscroll:
	ld a, -2
	ld [rSCX], a

.endscroll:
	pop bc
	pop af
	reti

;-----------------DMA-----------------------
;-------------------------------------------

setup_dma: ;Copy the DMA-Code into HRAM
	ld hl, dma_copy
	ld de, $FF80
	ld bc, dma_copy_end-dma_copy
	call mem_CopyVRAM
	ret

dma_copy: ;Actual DMA Code, we also set VBlankF here
	push af
	ld a, $01
	ld [VBlankF], a
	ld a, $C0
	ldh [rDMA], a
	ld a, $28
dma_copy_wait:
	dec a
	jr nz, dma_copy_wait
	pop af
	reti
dma_copy_end:
