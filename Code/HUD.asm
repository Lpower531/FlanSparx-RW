include "Code/constants.asm"
include "Code/hardware.inc"
include "Code/Charmap.inc"
include "Code/Macros.asm"

Section "error handler", ROM0
ErrorHandler:
    pop de
    push de
    ;Prepare Message
        ld hl, TextBuffer
        ld a, "e"
        ld [hl+], a
        ld a, "r"
        ld [hl+], a
        ld a, "r"
        ld [hl+], a
        ld a, " "
        ld [hl+], a
        ld a, "$"
        ld [hl+], a

        ;High D
            ld a, d
            swap a
            and $0F
            add $17
            ld [hl+], a

        ;Low D
            ld a, d
            and $0F
            add $17
            ld [hl+], a

        ;High E
            ld a, e
            swap a
            and $0F
            add $17
            ld [hl+], a

        ;Low E
            ld a, e
            and $0F
            add $17
            ld [hl+], a

    ld a, high(TextBuffer)
    ld [iErrorCode+0], a
    ld a, low(TextBuffer)
    ld [iErrorCode+1], a

    ChangeState MessageBox
    reti

Section "hard crash", ROM0[$38]
Error2:
    jp Start ; restart the game

Section "LYC Interrupt", ROM0[$48]
    jp LYChandler

Section "LYC handler", ROM0
LYChandler:
    push af
    push bc
    ldh a, [rLYC]
    ;HUD
        cp 8
        jr z, .line8disableWindow
        cp 144
        jr z, .line144enableWindow

    ;Message box
        ld c, a
        ldh a, [bMsgBoxAnimTimer]
        add 104
        ld b, a

        ld a, c
        cp b ; if message box
        jr z, .lineXshowMessageBox

    ;crash the game if this all fails
        call ErrorHandler

    .line8disableWindow
        waitForRightVRAMmode
        ;Disable window layer and enable sprite layer
            ldh a, [rLCDC]
            or LCDCF_OBJON
            and ~(LCDCF_BG8000);
            ldh [rLCDC], a
            ld a, 168
            ldh [rWX], a

        ;If message box state, set interrupt accordingly
            ldh a, [pCurrentState]
            cp STATE_MessageBox
            jr nz, .endIf
                ldh a, [bMsgBoxAnimTimer]
                add 104
                ldh [rLYC], a
                pop bc
                pop af
                reti
            .endIf

        ;Prepare next scanline interrupt
            ld a, 144
            ldh [rLYC], a
        pop bc
        pop af
        reti

    .line144enableWindow   
        waitForRightVRAMmode
        ;Enable window layer and disable sprites
        ldh a, [rLCDC]
        and ~LCDCF_OBJON
        or LCDCF_BG8000;
        ldh [rLCDC], a
        ld a, 7
        ldh [rWX], a

        ;Set window scroll
        ld a, 7
        ldh [rWX], a
        xor a ; ld a, 0
        ldh [rWY], a

        ;Prepare next scanline interrupt
        ld a, 8
        ldh [rLYC], a
        pop bc
        pop af
        reti

    .lineXshowMessageBox
        waitForRightVRAMmode
        ;Enable window layer and disable sprites
            ldh a, [rLCDC]
            and ~LCDCF_OBJON
            or LCDCF_BG8000;
            ldh [rLCDC], a
            ld a, 7
            ldh [rWX], a

        ;Set window scroll
            ldh a, [rLY]
            ldh [rWY], a

        ;Prepare next scanline interrupt
            ld a, 144
            ldh [rLYC], a

        pop bc
        pop af
        reti


SECTION "User Interface", ROM0
;Update the tiles on the window layer for the gem count and health bar
UpdateHUD:
    ;If we're not in Vblank, don't even bother
        ld a, [rLY]
        cp $90
        ret c

    ;Aight, we're in vblank, do the thing
        push hl

    ;Display gem icon
        ld hl, _SCRN1 + 2 ; Window tile data + 2

    ;Update gem count
    ;Left digit
        ldh a, [bCurrGemDec1]
        add $74
        ld [hl+], a

    ;Middle digit
        ldh a, [bCurrGemDec2]
        swap a
        and $0F ; Get the high nibble
        add $74
        ld [hl+], a

    ;Right digit
        ldh a, [bCurrGemDec2]
        and $0F ; Get the low nibble
        add $74 ; that's where the number tiles start
        ld [hl+], a

    ;Display health icon
        ld l, $0F

    ;Display health bar

    ;first tile
        ldh a, [bPlayerHealth]

        .tile1
            ;if bPlayerHealth == 0, all tiles are empty, return
            or a
            jr nz, .notEmpty1
                ld a, $72
                ld [hl+], a
                ld [hl+], a
                ld [hl+], a
                pop hl
                ret
            .notEmpty1

            ;if bPlayerHealth == 1, tile1 = half
            dec a
            jr nz, .notHalf1
                ld a, $71
                ld [hl+], a
                inc a
                ld [hl+], a
                ld [hl+], a
                pop hl
                ret
            .notHalf1

            ;otherwise, tile1 = full
            ld [hl], $70
            inc l

        .tile2
            ;if bPlayerHealth == 2, tile2 and tile3 are empty
            dec a
            jr nz, .notEmpty2
                ld [hl], $72
                inc l
                ld [hl], $72
                pop hl
                ret
            .notEmpty2

            ;if bPlayerHealth == 3, tile2 = half, tile3 is empty
            dec a
            jr nz, .notHalf2
                ld [hl], $71
                inc l
                ld [hl], $72
                pop hl
                ret
            .notHalf2

            ;otherwise, tile2 = full

            ld [hl], $70
            inc l

        .tile3
        ;if bPlayerHealth == 4, tile3 is empty
        dec a
        jr nz, .notEmpty3
            ld [hl], $72
            pop hl
            ret
        .notEmpty3

        ;if bPlayerHealth == 5, tile3 is half
        dec a
        jr nz, .notHalf3
            ld [hl], $71
            pop hl
            ret
        .notHalf3

        ;otherwise, tile3 is full
        ld [hl], $70
        pop hl
        ret

ClearWindowLayer:
    ;Tiles
    ld hl, $9E33
    ld a, $7F
    .loop1
        ld [hl-], a
        bit 2, h
        jr nz, .loop1

    ;Colour palette
    ldh a, [bGameboyType]
    cp GAMEBOY_COLOR ; if bGameboyType == GAMEBOY_COLOR
    ret nz
        ;Switch to attributes bank
        ld a, 1
        ldh [rVBK], a

        ;Write palette
        ld hl, $9E33
        ld a, $02
        .loop2
            ld [hl-], a
            bit 2, h
            jr nz, .loop2

        ;Switch back to tile bank
        xor a ; ld a, 0
        ldh [rVBK], a
    ret

InitWindowLayer:
    ;Initialize the pointer at the top left
    ld hl, $9C20

    ;Put corner piece
    ld a, $6A
    ld [hl+], a

    ;Then put exactly 18 horizontal pieces
    inc a
    ld b, 9
    .loopHor1
        ld [hl+], a
        ld [hl+], a
        dec b
        jr nz, .loopHor1

    ;Put corner piece
    inc a
    ld [hl+], a

    ;Put vertical pieces
    inc a
    ld hl, $9C40
    ld [hl+], a

    ld a, $46
    ld b, 18
    .loopTextRow1
        ld [hl+], a
        inc a
        dec b
        jr nz, .loopTextRow1

    ld a, $6D
    ld [hl], a

    ld l, $60
    ld [hl], a

    ld l, $73
    ld [hl], a

    ld l, $80
    ld [hl+], a
    
    ld a, $58
    ld b, 18
    .loopTextRow2
        ld [hl+], a
        inc a
        dec b
        jr nz, .loopTextRow2

    ld a, $6D
    ld [hl], a

    ;Put corner piece
    ld l, $A0
    inc a
    ld [hl+], a

    ;Then put exactly 18 horizontal pieces
    ld a, $6B
    ld b, 9
    .loopHor2
        ld [hl+], a
        ld [hl+], a
        dec b
        jr nz, .loopHor2

    ;Put corner piece
    ld a, $6F
    ld [hl+], a

    ;Put gem icon
    ld l, $01
    ld [hl], $7E

    ;Put HP icon
    ld l, $0E
    ld [hl], $73

    ret