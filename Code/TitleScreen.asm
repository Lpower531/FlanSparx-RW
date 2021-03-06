include "Code/constants.asm"
include "Code/hardware.inc"
include "Code/Charmap.inc"
include "Code/Macros.asm"

Section "Title Screen", ROM0
StateStart_TitleScreen:
    ;Wait for the current frame to finish and then turn off the display
    call waitVBlank
    di
    LCDoffHL

    ;Load the scene
    Copy tileset_title_tiles, $8000
    LoadFont $8800
    LoadScreen screen_title

    ;Write text
    DisplayText Text_Title_PressStart, 4, 15

    ;Palette - GB
    ld a, %00011011
    ldh [rBGP], a
    ldh [rOBP0], a

    ;Palettes - GBC
    LoadPalettes tileset_crawdad_palette

    ;Turn the screen back on
    LCDonHL
    ei
    ret

StateUpdate_TitleScreen:
    ;Get input
    call GetJoypadStatus

    ;Check if start button pressed
    ld hl, bJoypadPressed
    bit J_START, [hl]
    jr nz, .startPressed

    ;If not pressed, return
    reti

    .startPressed
    ;Change state if start button was pressed
    ChangeState GameLoop
    reti

