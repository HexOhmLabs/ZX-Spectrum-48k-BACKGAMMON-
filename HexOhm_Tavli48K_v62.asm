; v62 NO-BLEED build (based on v61): needs the matching data block (new board layout) from HexOhm_Tavli48K_NIRVANAP_v62_NoBleed.tap
; HexOhm ΤΑΒΛΙ / Tavli 48K — v44 (correct Greek title using standard Spectrum attributes)
; Based on verified user-tested v29 ROM keyboard and graphical blocks.
; Every CPU move requires its own SPACE press. CPU dice remain visible.
; Another SPACE acknowledges the finished CPU turn so last move stays on screen.
; All NIRVANA+ engine, original bitmap and ROM keyboard code unchanged. Rules patched.
; A compact ME / SPC / END sidebar prompt is drawn directly on the screen.
; v31 audited source variants: Portes, Plakoto, Fevga, Gioul, Euro Assodio.
; FIXED: reentry die only added once, forced bar priority, BAR one-key input,
; NO MOVE/SPACE, bar numerals, pin release, Gioul direction/setup,
; Assodio complement 1-2, redrawing of bonus dice, Assodio reentry priority,
; Fevga six-point initial blockade, Assodio bearing-off-only home rule.
; Not yet fully enforced: maximum number of usable dice and mandatory higher
; die when only one is playable, Fevga advanced-prime exception, full Gioul
; remainder-transfer strategy, opening toss. Fuse testing still required.
; CPU: Z80, ZX Spectrum 48K, NIRVANA+ raster engine
; ORG 43000 (game code only)
; This .ASM is the full game/menu/input/graphics-control source.
; Static screen data from approved NIRVANA+ v15 and raster engine binary
; are separate loaded blocks in the matching .TAP, not redefined here.
; v21: treat a different physical key as a new event even when no
; all-keys-up frame was observed. Distinguish raw input from legality.
; Original v15 game rules and NIRVANA+ engine remain unchanged.
; v28: invoke original ROM KEYBOARD at $02BF once per video interrupt;
; consume LAST_K at $5C08 and FLAGS bit 5 at $5C3B.
; Removed hand-built key-state/debounce and keyboard tables.
; Only board horizontal framing is compacted to provide a right black dice strip.
; This release has not been executed in Fuse.
; v23: preserve v21 keyboard edge routine; rewrite game input as a
; finite-state machine. Every two valid keys form a visible FROM-TO pair.
; On illegal moves show BAD, not a silent reset.
; v25: original v21 frame only cropped 4+4+3+4 px, no redrawn lines.
; Non-byte point x positions rendered by pre-shifted 24-bit circle masks.
; Right sidebar x240..255 keeps graphic dice & YOU/ME.
; Preserved v23 FROM/TO/BAD input state and keyboard edge handling.
; Loader and NIRVANA+ binary are unchanged.
;

        org 43000
entry:
        di
        ld sp,53248
        xor a
        ld (engine_on),a
        out (254),a
        ei
        ld a,(23672)
        xor 165
        ld (rng),a
menu:
        call 65012          ; restore Spectrum IM1 and stop NIRVANA+ before menu
        xor a
        ld (engine_on),a
        out (254),a         ; black border
        call clear_screen
        ; v39: 2x arcade title; TABLI uses a true Greek capital Lambda and
        ; each large letter has its own simple Spectrum ink colour.
        call draw_large_titles
        ld a,6
        ld (text_ink),a
        ld b,7
        ld c,3
        ld hl,s_menu1
        call text_at
        ld b,9
        ld c,3
        ld hl,s_menu2
        call text_at
        ld b,11
        ld c,3
        ld hl,s_menu3
        call text_at
        ld b,13
        ld c,3
        ld hl,s_menu4
        call text_at
        ld b,15
        ld c,3
        ld hl,s_menu5
        call text_at
        ld b,17
        ld c,3
        ld hl,s_menu6
        call text_at
        ld a,7
        ld (text_ink),a
        ld b,20
        ld c,7
        ld hl,s_select
        call text_at
        ld a,5
        ld (text_ink),a
        ld b,22
        ld c,1
        ld hl,s_controls
        call text_at
        ld a,7
        ld (text_ink),a
        ld b,23
        ld c,6
        ld hl,s_powered
        call text_at
; v19 diagnosis: echo the ASCII key in an unused menu position.
; This runs BEFORE NIRVANA+ and is independent of game legality.
; If A/Z cannot be echoed here, inspect the Fuse/host keyboard mapping.
menu_key:
        call wait_menu_blink
        push af
        ld b,19
        ld c,2
        call draw_char
        pop af
        cp '1'
        jr c,menu_key
        cp '7'
        jr nc,menu_key
        sub '1'
        ld (mode),a
        xor a
        ld (setflag),a
        ld (score0),a
        ld (score1),a
        ld a,(mode)
        cp 5
        jr nz,begin_game
        xor a
        ld (mode),a
        inc a
        ld (setflag),a
begin_game:
        di
        call 32772       ; original v15 static board setup 0x8004; now returns
        ld a,1
        ld (engine_on),a
        call init_game
round_start:
        ld a,(winner)
        cp 255
        jp nz,round_end
        call perform_turn
        ld a,(winner)
        cp 255
        jp nz,round_end
        ld a,(player)
        xor 1
        ld (player),a
        jp round_start
round_end:
        call calculate_score
        call paint_board
        ld b,13
        ld c,0
        ld hl,s_win_you
        ld a,(winner)
        or a
        jr z,round_message
        ld hl,s_win_cpu
        cp 1
        jr z,round_message
        ld hl,s_draw
round_message:
        call text_at
        call wait_key
        ld a,(setflag)
        or a
        jp z,menu
        ld a,(mode)
        cp 4
        jp z,menu
        inc a
        ld (mode),a
        jp begin_game

; Large static 2x monochrome arcade glyphs, shadow attributes only.
; x80..175 at y8, x88..167 at y32. The game menu starts at y56.
draw_large_titles:
        ld hl,big_hexohm_bitmap
        ld de,big_hexohm_rows
        ld a,12                ; six 16-pixel letters
        ld (big_line_bytes),a
        ld a,10                ; 80 pixels
        ld (big_column),a
        call draw_big_bitmap
        ld hl,big_tabli_bitmap
        ld de,big_tabli_rows
        ld a,10                ; five 16-pixel letters
        ld (big_line_bytes),a
        ld a,11                ; 88 pixels
        ld (big_column),a
        call draw_big_bitmap
        ld a,1
        ld (menu_flash_visible),a
        xor a
        ld (menu_flash_frames),a
        call menu_flash_attrs
        ret

; HL: glyph-row bytes, DE: 16 bitmap line addresses, stored as words.
draw_big_bitmap:
        ld (big_source),hl
        ld (big_lines),de
        ld b,16
big_bitmap_loop:
        push bc
        ld hl,(big_lines)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (big_lines),hl
        ld a,(big_column)
        ld l,a
        ld h,0
        add hl,de
        ex de,hl
        ld hl,(big_source)
        ld a,(big_line_bytes)
        ld c,a
        ld b,0
        ldir
        ld (big_source),hl
        pop bc
        djnz big_bitmap_loop
        ret

; Attribute blink, one tick per video frame. Only the Greek TABLI title
; is flashed; the keyboard remains active throughout the animation.
; v39: each 16x16 TABLI letter uses its own plain Spectrum ink colour.
menu_flash_attrs:
        ld a,(menu_flash_visible)
        or a
        jr z,menu_flash_hide
        ld hl,tabli_attr_colors
        ld de,22667           ; row4 / column11
        call menu_flash_copy_row
        ld hl,tabli_attr_colors
        ld de,22699           ; row5 / column11
        call menu_flash_copy_row
        ret
menu_flash_hide:
        xor a
        ld hl,22667           ; row4 / column11
        ld b,10
menu_flash_hide_row1:
        ld (hl),a
        inc hl
        djnz menu_flash_hide_row1
        ld hl,22699           ; row5 / column11
        ld b,10
menu_flash_hide_row2:
        ld (hl),a
        inc hl
        djnz menu_flash_hide_row2
        ret

menu_flash_copy_row:
        ld b,10
menu_flash_copy_loop:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz menu_flash_copy_loop
        ret

wait_menu_blink:
        ld iy,23610
        ld a,(23611)
        or 8                  ; standard Spectrum L-mode keyboard decoding
        ld (23611),a
menu_blink_loop:
        halt                  ; ROM IM1 updates keyboard at 50Hz
        ld a,(menu_flash_frames)
        inc a
        cp 20                 ; switch visibility every 0.4 seconds
        jr c,menu_flash_save_tick
        xor a
        ld (menu_flash_frames),a
        ld a,(menu_flash_visible)
        xor 1
        ld (menu_flash_visible),a
        call menu_flash_attrs
        jr menu_flash_check_key
menu_flash_save_tick:
        ld (menu_flash_frames),a
menu_flash_check_key:
        ld a,(23611)
        and 32
        jr z,menu_blink_loop
        ld a,(23560)
        push af
        ld a,(23611)
        and 223
        ld (23611),a
        pop af
        ret

tabli_attr_colors:
        db 2,2,6,6,4,4,5,5,3,3

big_source: dw 0
big_lines: dw 0
big_line_bytes: db 0
big_column: db 0
menu_flash_frames: db 0
menu_flash_visible: db 1
big_hexohm_rows:
        dw 16416
        dw 16672
        dw 16928
        dw 17184
        dw 17440
        dw 17696
        dw 17952
        dw 18208
        dw 16448
        dw 16704
        dw 16960
        dw 17216
        dw 17472
        dw 17728
        dw 17984
        dw 18240
big_tabli_rows:
        dw 16512
        dw 16768
        dw 17024
        dw 17280
        dw 17536
        dw 17792
        dw 18048
        dw 18304
        dw 16544
        dw 16800
        dw 17056
        dw 17312
        dw 17568
        dw 17824
        dw 18080
        dw 18336
big_hexohm_bitmap:
        db 60,60,63,252,60,60,15,240,60,60,60,15
        db 60,60,63,252,60,60,15,240,60,60,60,15
        db 60,60,60,0,60,60,60,60,60,60,63,63
        db 60,60,60,0,60,60,60,60,60,60,63,63
        db 60,60,60,0,15,240,60,60,60,60,63,255
        db 60,60,60,0,15,240,60,60,60,60,63,255
        db 63,252,63,240,3,192,60,60,63,252,60,207
        db 63,252,63,240,3,192,60,60,63,252,60,207
        db 60,60,60,0,15,240,60,60,60,60,60,15
        db 60,60,60,0,15,240,60,60,60,60,60,15
        db 60,60,60,0,60,60,60,60,60,60,60,15
        db 60,60,60,0,60,60,60,60,60,60,60,15
        db 60,60,63,252,60,60,15,240,60,60,60,15
        db 60,60,63,252,60,60,15,240,60,60,60,15
        db 0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0
big_tabli_bitmap:
        ; v43: Five true 16x16 Greek glyphs; 2x original 8x8 pixel pattern.
        db 63,252,3,192,63,240,3,192,63,252
        db 63,252,3,192,63,240,3,192,63,252
        db 3,192,12,48,48,12,12,48,3,192
        db 3,192,12,48,48,12,12,48,3,192
        db 3,192,48,12,48,12,48,12,3,192
        db 3,192,48,12,48,12,48,12,3,192
        db 3,192,48,12,63,240,48,12,3,192
        db 3,192,48,12,63,240,48,12,3,192
        db 3,192,63,252,48,12,192,3,3,192
        db 3,192,63,252,48,12,192,3,3,192
        db 3,192,48,12,48,12,192,3,3,192
        db 3,192,48,12,48,12,192,3,3,192
        db 3,192,48,12,48,12,192,3,3,192
        db 3,192,48,12,48,12,192,3,3,192
        db 3,192,48,12,63,240,192,3,63,252
        db 3,192,48,12,63,240,192,3,63,252

clear_screen:
        ld hl,16384
        ld de,16385
        ld bc,6911
        xor a
        ld (hl),a
        ldir
        ld hl,22528
        ld de,22529
        ld bc,767
        ld a,7
        ld (hl),a
        ldir
        ret

init_game:
        ld hl,board0
        ld de,board0+1
        ld bc,47
        xor a
        ld (hl),a
        ldir
        ld hl,pinTop
        ld de,pinTop+1
        ld bc,23
        ld a,2
        ld (hl),a
        ldir
        xor a
        ld (bar0),a
        ld (bar1),a
        ld (reserve0),a
        ld (reserve1),a
        ld (off0),a
        ld (off1),a
        ld (first0),a
        ld (first1),a
        ld (player),a
        ld a,255
        ld (winner),a
        ld a,(mode)
        or a
        jr z,setup_portes
        cp 1
        jr z,setup_plakoto
        cp 3
        jr z,setup_plakoto
        cp 4
        jr z,setup_assodio
        ; Fevga: both progress clockwise, start opposite
        ld a,15
        ld (board0),a          ; A
        ld (board1+12),a       ; M
        jr setup_end
setup_plakoto:
        ld a,15
        ld (board0),a
        ld (board1+23),a
        jr setup_end
setup_portes:
        ld a,2
        ld (board0),a
        ld (board1+23),a
        ld a,5
        ld (board0+11),a
        ld (board1+12),a
        ld (board0+18),a
        ld (board1+5),a
        ld a,3
        ld (board0+16),a
        ld (board1+7),a
        jr setup_end
setup_assodio:
        ld a,15
        ld (reserve0),a
        ld (reserve1),a
setup_end:
        call paint_board
        ret

; ------------------ Random/dice -------------------------
random_die:
        ld a,(rng)
        rrca
        jr nc,random_noxor
        xor 184
random_noxor:
        ld b,a
        ld a,(23672)
        xor b
        ld (rng),a
        and 31
random_reduce:
        cp 6
        jr c,random_ready
        sub 6
        jr random_reduce
random_ready:
        inc a
        ret

new_roll:
        call random_die
        ld (die1),a
        call random_die
        ld (die2),a
        call fill_roll
        call dice_throw_sound   ; v56: short 48K ULA beeper rattle
        ret

; v62: dice rattle on the 48K ULA speaker (port FE) - replaces the old single-tone buzz.
; Eight noise "clacks" (random-length clicks from an 8-bit LFSR seeded from R), each a bit
; shorter than the last, separated by silent gaps that grow 12,15,..,33 ms, so the rattle
; slows down like dice settling (about 0.2 s). Border stays black (bits 0..2 = 0).
; Interrupts stay enabled (no DI): NIRVANA+ keeps running; an interrupt only adds a click.
; Registers used: A,B,C,D,E - all saved. Position independent (relative jumps only).
dice_throw_sound:
        push af
        push bc
        push de
        ld a,r
        or 1
        ld d,a                  ; D = noise state (never 0)
        ld e,8                  ; eight clacks
snd_clack:
        ld a,e
        add a,a
        add a,a
        add a,12
        ld b,a                  ; 16..44 clicks per clack, fewer as the dice settle
snd_click:
        ld a,d
        srl a                   ; Galois LFSR, taps $B8 (period 255)
        jr nc,snd_nx
        xor 184
snd_nx:
        ld d,a
        and 31
        add a,6
        ld c,a                  ; half period 6..37 loops (about 0.07..0.22 ms)
        ld a,b
        and 1
        rlca
        rlca
        rlca
        rlca                    ; speaker bit (16) flips every click
        out (254),a
snd_half:
        dec c
        jr nz,snd_half
        djnz snd_click
        xor a
        out (254),a             ; speaker low between clacks
        ld a,12
        sub e
        ld c,a
        add a,a
        add a,c                 ; gap = 3*(12-E) ms
snd_wait:
        ld b,0
snd_ms:
        djnz snd_ms             ; about 0.95 ms
        dec a
        jr nz,snd_wait
        dec e
        jr nz,snd_clack
        pop de
        pop bc
        pop af
        ret
fill_roll:
        ld a,(die1)
        ld (dice0),a
        ld a,(die2)
        ld (dice1),a
        xor a
        ld (dice2),a
        ld (dice3),a
        ld a,(die1)
        ld b,a
        ld a,(die2)
        cp b
        ret nz
        ld a,b
        ld (dice2),a
        ld (dice3),a
        ret

; A = die face, expand to 4 slots
fill_four:
        ld (die1),a
        ld (die2),a
        ld (dice0),a
        ld (dice1),a
        ld (dice2),a
        ld (dice3),a
        ret

; One ordinary roll; optionally expanded European Assodio / Gioul.
perform_turn:
        ld a,(player)
        ld (original_player),a
roll_again:
        call new_roll
        call paint_board
        ; Computer dice must remain visible before its first move.
        ; Do not roll for human until CPU is explicitly finished.
        ld a,(player)
        or a
        jr z,roll_human_unpaused
        call cpu_hud_begin
roll_human_unpaused:
        call play_group
        ld a,(winner)
        cp 255
        jp nz,turn_done
        ld a,(mode)
        cp 3
        jr z,handle_gioul
        cp 4
        jr z,handle_assodio
        jp turn_done
handle_gioul:
        ld a,(die1)
        ld b,a
        ld a,(die2)
        cp b
        jp nz,turn_done
        xor a
        ld (gioul_transferred),a
        ld a,b
        ld (current_double),a
        call gioul_transfer_if_blocked
next_gioul_double:
        ld a,(current_double)
        cp 6
        jp nc,turn_done
        inc a
        ld (current_double),a
        call fill_four
        call paint_board
        call play_group
        ld a,(winner)
        cp 255
        jp nz,turn_done
        call gioul_transfer_if_blocked
        jp next_gioul_double
; In Gioul, the other side continues the unplayable part of
; the sequence of doubles (only one transfer per roll).
gioul_transfer_if_blocked:
        call all_slots_used
        or a
        ret nz
        ld a,(gioul_transferred)
        or a
        ret nz
        ld a,1
        ld (gioul_transferred),a
        ld a,(player)
        xor 1
        ld (player),a
        call paint_board
        ; Gioul can transfer a blocked sequence to the other player.
        ; If the recipient is the computer, show ME/SPC and pause as usual.
        ld a,(player)
        or a
        jr z,gioul_transfer_to_human
        call cpu_hud_begin
gioul_transfer_to_human:
        call play_group
        ret
handle_assodio:
        ; European: a double grants the complementary double and a reroll
        ; 1-2 also grants a chosen double and a reroll.
        call all_slots_used
        or a
        jp z,turn_done
        ld a,(die1)
        ld b,a
        ld a,(die2)
        cp b
        jp z,assodio_complement
        ld a,b
        cp 1
        jr z,check_one_two
        cp 2
        jp nz,turn_done
        ld a,(die2)
        cp 1
        jp nz,turn_done
        jp assodio_one_two
check_one_two:
        ld a,(die2)
        cp 2
        jp nz,turn_done
assodio_one_two:
        ld a,(player)
        or a
        jr nz,assodio_cpu_choice
        ld b,13
        ld c,0
        ld hl,s_choose_double
        call text_at
ask_double:
        call wait_key
        cp '1'
        jr c,ask_double
        cp '7'
        jr nc,ask_double
        sub '0'
        jr assodio_selected
assodio_cpu_choice:
        ld a,6
assodio_selected:
        ; For 1-2: chosen four-of-a-kind, then the complementary
        ; four-of-a-kind, then a fresh roll if all eight were playable.
        ld (current_double),a
        call fill_four
        call paint_board
        call assodio_cpu_redraw
        call play_group
        ld a,(winner)
        cp 255
        jp nz,turn_done
        call all_slots_used
        or a
        jp z,turn_done
        ld a,7
        ld b,a
        ld a,(current_double)
        ld c,a
        ld a,b
        sub c
        call fill_four
        call paint_board
        call assodio_cpu_redraw
        call play_group
        ld a,(winner)
        cp 255
        jp nz,turn_done
        call all_slots_used
        or a
        jp z,turn_done
        jp roll_again
assodio_complement:
        ld a,7
        sub b
        call fill_four
        call paint_board
        call assodio_cpu_redraw
        call play_group
        ld a,(winner)
        cp 255
        jp nz,turn_done
        call all_slots_used
        or a
        jp z,turn_done
        jp roll_again
assodio_cpu_redraw:
        ld a,(player)
        or a
        ret z
        jp cpu_hud_begin
turn_done:
        ld a,(original_player)
        ld (player),a
        ret

all_slots_used:
        ld a,(dice0)
        ld b,a
        ld a,(dice1)
        or b
        ld b,a
        ld a,(dice2)
        or b
        ld b,a
        ld a,(dice3)
        or b
        jr z,all_slots_yes
        xor a
        ret
all_slots_yes:
        ld a,1
        ret

; -------------------- Turn -------------------------------
; v20: IMPORTANT - Human keyboard first, before the automatic
; move search. The earlier dispatch called pick_legal() before entering
; player_select, which could prevent any input from being polled.
; CPU still uses the same pick_legal() algorithm as before.
play_group:
play_group_loop:
        ld a,(player)
        or a
        jr nz,cpu_group_loop
        ; After v29 ROM keyboard fix, preflight is safe and needed:
        ; if no legal move exists, never trap player at FROM.
        call all_slots_used
        or a
        ret nz
        call pick_legal
        or a
        jp nz,player_select
        call human_no_move
        ret

human_no_move:
        call paint_board
        ld hl,hud_no
        ld de,18686
        call draw_hud_mini
        ld hl,hud_move
        ld de,20574
        call draw_hud_mini
        ld hl,hud_spc_cpu
        ld de,20670
        call draw_hud_mini
        jp cpu_wait_space
cpu_group_loop:
        ; Select the next move with the ORIGINAL legal-move algorithm.
        ; The selection only calculates fields; it does not change the board.
        call pick_legal
        or a
        jr z,cpu_group_finished
        ; CPU dice and the current board have already been drawn.
        ; Keep them visible UNTIL one new SPACE event arrives.
        call cpu_wait_space
        ; Safety: recheck the chosen move against the CURRENT board.
        ; Never commit a stale or impossible entry from the bar.
        call check_move
        or a
        jr z,cpu_group_finished
        call cpu_remember_move
        call commit_move
        ld a,(winner)
        cp 255
        ret nz
        call paint_board
        call cpu_hud_wait
        call show_input_pair
        jp play_group_loop
cpu_group_finished:
        ; If dice remain, the CPU is blocked. Otherwise turn is done.
        call all_slots_used
        or a
        jr nz,cpu_finished_normally
        ld hl,hud_no
        ld de,18686
        call draw_hud_mini
        ld hl,hud_move
        ld de,20574
        call draw_hud_mini
        ld hl,hud_spc_cpu
        ld de,20670
        call draw_hud_mini
        jr cpu_finish_ack
cpu_finished_normally:
        call cpu_hud_done
cpu_finish_ack:
        call show_input_pair
        call cpu_wait_space
        ret

; ROM keyboard is the SAME wait_key as tested in v29. Do NOT scan FEh.
; Each accepted SPACE triggers exactly one move, not the entire CPU turn.
cpu_wait_space:
        call wait_key
        cp 'Z'
        jp z,menu
        cp ' '
        jr nz,cpu_wait_space
        ret

; Show CPU status in the black sidebar, without moving any checker graphics.
cpu_hud_begin:
        ld a,'?'
        ld (input_from),a
        ld (input_to),a
        call cpu_hud_wait
        jp show_input_pair
cpu_hud_wait:
        ld hl,hud_me_cpu
        ld de,18686         ; x240 y120
        call draw_hud_mini
        ld hl,hud_spc_cpu
        ld de,20670         ; x240 y168
        jp draw_hud_mini
cpu_hud_done:
        ld hl,hud_end_cpu
        ld de,18686         ; x240 y120
        call draw_hud_mini
        ld hl,hud_spc_cpu
        ld de,20670         ; x240 y168
        jp draw_hud_mini

; Keep a visible FROM-TO pair showing the computer's LAST completed move.
; A-X are physical point labels; 0 represents bar or bear-off.
cpu_remember_move:
        ld a,(mvsrc)
        cp 24
        jr z,cpu_source_zero
        add a,'A'
        jr cpu_source_saved
cpu_source_zero:
        ld a,'0'
cpu_source_saved:
        ld (input_from),a
        ld a,(mvdest)
        cp 255
        jr z,cpu_dest_zero
        add a,'A'
        jr cpu_dest_saved
cpu_dest_zero:
        ld a,'0'
cpu_dest_saved:
        ld (input_to),a
        ret

; ------------------ v23 human input finite-state machine ------------------
; Previous v22 would silently jump back to the first source on an illegal
; move, so users could not distinguish a missing second key from a rejected
; move.  The extra third "?" was the old debug raw-key character.
;
; Here input_phase 0=FROM and 1=TO, independent of move validation.
; An accepted source always visibly changes ?? -> A?.  The NEXT letter
; always becomes destination AB before check_move is even called.
; Rejected pairs show "BAD" until another source key is entered.
;
; v26: v21 keyboard and input handling restored. Two physical keys are
; always accepted, source then destination, BEFORE any legal-move test.
; A bad move shows BAD (does not silently discard the 2nd key).
player_select:
        call paint_board
        ld a,'?'
        ld (input_from),a
        ld (input_to),a
        call show_input_pair
        call clear_move_status
        ; Automatic BAR/RESERVE selection: only ONE letter for entry.
        ; A bar checker must reenter before any other checker moves.
        ld a,(mode)
        cp 0
        jr z,check_human_bar
        cp 4
        jr nz,normal_human_from
check_human_bar:
        ld a,(bar0)
        or a
        jr nz,auto_entry_human
        ld a,(mode)
        cp 4
        jr nz,normal_human_from
        ld a,(reserve0)
        or a
        jr nz,auto_entry_human
normal_human_from:
        call prompt_from
        jr select_source

auto_entry_human:
        ld a,'0'
        ld (input_from),a
        ld a,24
        ld (mvsrc),a
        call show_input_pair
        call prompt_bar
        jr select_dest

select_source:
        call wait_key
        cp 'Z'
        jp z,menu
        cp '0'
        jr z,source_bar
        cp 'A'
        jr c,select_source
        cp 'Y'
        jr nc,select_source
        ld (input_from),a
        sub 'A'
        ld (mvsrc),a
        jr source_registered
source_bar:
        ld a,'0'
        ld (input_from),a
        ld a,24
        ld (mvsrc),a
source_registered:
        ld a,'?'
        ld (input_to),a
        call show_input_pair
        call clear_move_status
        ; v60: a legal bear-off is committed immediately after FROM,
        ; with the normal check_move rules for the selected die.
        ld a,(mvsrc)
        cp 24
        jr z,source_wait_dest
        xor a
        ld (mvslot),a
source_try_bear:
        ld a,(mvslot)
        call slot_value
        or a
        jr z,source_bear_next
        ld (mvdie),a
        call check_move
        or a
        jr z,source_bear_next
        ld a,(mvdest)
        cp 255
        jp z,player_commit
source_bear_next:
        ld a,(mvslot)
        inc a
        ld (mvslot),a
        cp 4
        jr c,source_try_bear
source_wait_dest:
        call prompt_to

select_dest:
        call wait_key
        cp 'Z'
        jp z,menu
        cp '0'
        jr z,dest_offboard
        cp 'A'
        jr c,select_dest
        cp 'Y'
        jr nc,select_dest
        ld (input_to),a
        sub 'A'
        jr dest_ready
dest_offboard:
        ld a,'0'
        ld (input_to),a
        ld a,255
dest_ready:
        ld (wanted_dest),a
        call show_input_pair
        xor a
        ld (mvslot),a
match_die_slot:
        ld a,(mvslot)
        call slot_value
        or a
        jr z,match_next
        ld (mvdie),a
        call check_move
        or a
        jr z,match_next
        ld a,(mvdest)
        ld b,a
        ld a,(wanted_dest)
        cp b
        jr z,player_commit
match_next:
        ld a,(mvslot)
        inc a
        ld (mvslot),a
        cp 4
        jr c,match_die_slot
        jr player_invalid
player_commit:
        call commit_move
        ld a,(winner)
        cp 255
        ret nz
        call paint_board
        jp play_group_loop
player_invalid:
        call show_bad_status
        ld a,'?'
        ld (input_from),a
        ld (input_to),a
        call show_input_pair
        ; Keep BAD visible; maintain mandatory bar/entry mode.
        ld a,(mode)
        cp 0
        jr z,invalid_bar_check
        cp 4
        jr nz,invalid_normal
invalid_bar_check:
        ld a,(bar0)
        or a
        jr nz,invalid_auto_entry
        ld a,(mode)
        cp 4
        jr nz,invalid_normal
        ld a,(reserve0)
        or a
        jr nz,invalid_auto_entry
invalid_normal:
        call prompt_from
        jp select_source
invalid_auto_entry:
        ld a,'0'
        ld (input_from),a
        ld a,24
        ld (mvsrc),a
        call show_input_pair
        call prompt_bar
        jp select_dest

prompt_bar:
        ld hl,hud_bar
        ld de,18686
        jp draw_hud_mini

prompt_from:
        ld hl,hud_from
        ld de,18686                ; x240 y120
        jp draw_hud_mini
prompt_to:
        ld hl,hud_to
        ld de,18686
        jp draw_hud_mini
clear_move_status:
        ld hl,hud_empty
        ld de,20670                ; x240 y168
        jp draw_hud_mini
show_bad_status:
        ld hl,hud_bad
        ld de,20670
        jp draw_hud_mini
; 8 bitmap rows x 2 bytes, addressed INSIDE 0x4000..0x57FF.
; The old prompt_to=23358 and BAD=23486 were writing above display!
; Valid x=240 positions: y120=18686 and y168=20670.
draw_hud_mini:
        push af
        push bc
        push de
        push hl
        ld b,8
hud_mini_loop:
        ld a,(hl)
        ld (de),a
        inc hl
        inc e
        ld a,(hl)
        ld (de),a
        inc hl
        dec e
        inc d
        djnz hud_mini_loop
        pop hl
        pop de
        pop bc
        pop af
        ret

show_input_pair:
        push af
        push bc
        ld a,7
        ld (text_ink),a
        ld a,(input_from)
        ld b,18
        ld c,30
        call draw_char
        ld a,(input_to)
        ld b,18
        ld c,31
        call draw_char
        pop bc
        pop af
        ret

; Pick any legal move, using the most advanced checker.
; Output: A=1 if found. Stores mvslot, mvsrc, mvdie and mvdest.
pick_legal:
        ld a,24
        ld (mvsrc),a
        call test_slots
        or a
        ret nz
        ld a,23
        ld (scanprogress),a
pick_points_loop:
        ld a,(scanprogress)
        ld b,a
        ld a,(player)
        ld c,a
        ld a,b
        ld b,c
        call to_physical
        ld (mvsrc),a
        call test_slots
        or a
        ret nz
        ld a,(scanprogress)
        or a
        jr z,pick_none
        dec a
        ld (scanprogress),a
        jr pick_points_loop
pick_none:
        xor a
        ret

test_slots:
        xor a
        ld (mvslot),a
test_slots_loop:
        call slot_value
        or a
        jr z,test_next
        ld (mvdie),a
        call check_move
        or a
        ret nz
test_next:
        ld a,(mvslot)
        inc a
        ld (mvslot),a
        cp 4
        jr c,test_slots_loop
        xor a
        ret

; A = slot 0..3, returns die value
slot_value:
        ld e,a
        ld d,0
        ld hl,dice0
        add hl,de
        ld a,(hl)
        ret

; Commit last validated move, consuming chosen die slot.
commit_move:
        ld a,(mvslot)
        ld e,a
        ld d,0
        ld hl,dice0
        add hl,de
        xor a
        ld (hl),a
        ld a,(mvsrc)
        cp 24
        jr z,commit_entry
        call own_pointer
        dec (hl)
        ; Plakoto: last covering checker leaves -> trapped man freed.
        ld a,(mode)
        cp 1
        jr nz,commit_place
        ld a,(mvsrc)
        call get_own_count
        or a
        jr nz,commit_place
        ld a,(mvsrc)
        call pin_pointer
        ld (hl),2
        jr commit_place
commit_entry:
        ld a,(mode)
        cp 4
        jr nz,commit_entry_bar
        ; Assodio: already hit checkers on bar have priority over reserve.
        ld a,(player)
        or a
        jr z,commit_assodio_bar0
        ld a,(bar1)
        jr commit_assodio_bar_check
commit_assodio_bar0:
        ld a,(bar0)
commit_assodio_bar_check:
        or a
        jr z,commit_reserve
commit_entry_bar:
        ld a,(player)
        or a
        jr z,commit_bar0
        ld hl,bar1
        dec (hl)
        jr commit_place
commit_bar0:
        ld hl,bar0
        dec (hl)
        jr commit_place
commit_reserve:
        ld a,(player)
        or a
        jr z,commit_res0
        ld hl,reserve1
        dec (hl)
        jr commit_place
commit_res0:
        ld hl,reserve0
        dec (hl)
commit_place:
        ld a,(mvdest)
        cp 255
        jr z,commit_bear
        call own_pointer
        inc (hl)
        ; Plakoto: entering an opponent singleton records who is on top.
        ld a,(mode)
        cp 1
        jr nz,commit_not_pin
        ld a,(mvdest)
        call get_enemy_count
        cp 1
        jr nz,commit_not_pin
        ld a,(mvdest)
        call get_own_count
        cp 1
        jr nz,commit_not_pin
        ld a,(mvdest)
        call pin_pointer
        ld a,(player)
        ld (hl),a
commit_not_pin:
        ; Fevga/Gioul: after the leading piece passes the other start,
        ; the remaining pieces are allowed to leave the initial point.
        ld a,(mode)
        cp 2
        jr nz,commit_not_first
        ld a,(mvprogress)
        ld b,a
        ld a,(mvdie)
        add a,b
        cp 13
        jr c,commit_not_first
        ld a,(player)
        or a
        jr z,commit_first0
        ld a,1
        ld (first1),a
        jr commit_not_first
commit_first0:
        ld a,1
        ld (first0),a
commit_not_first:
        ld a,(hitflag)
        or a
        jr z,commit_check
        ld a,(mvdest)
        call enemy_pointer
        dec (hl)
        ld a,(player)
        or a
        jr z,commit_hit_blue
        ld hl,bar0
        inc (hl)
        jr commit_check
commit_hit_blue:
        ld hl,bar1
        inc (hl)
        jr commit_check
commit_bear:
        ld a,(player)
        or a
        jr z,commit_bear0
        ld hl,off1
        inc (hl)
        jr commit_check
commit_bear0:
        ld hl,off0
        inc (hl)
commit_check:
        call check_winner
        ret

; --------------------- Legality ---------------------------
; Inputs: mvsrc = physical A..X (0..23) or 24 for bar / reserve
;         mvdie = 1..6, player = 0 human or 1 CPU
; Output: A=1 legal, mvdest set to physical 0..23 or 255 bear,
;         hitflag true only in Portes and Assodio. No state mutated.
check_move:
        xor a
        ld (hitflag),a
        ld a,(mode)
        cp 4
        jr z,check_assodio_bar_first
        cp 0
        jr nz,check_normal_src
        ld a,(player)
        or a
        jr z,check_bar_human
        ld a,(bar1)
        jr check_priority
check_bar_human:
        ld a,(bar0)
        jr check_priority
check_assodio_bar_first:
        ld a,(player)
        or a
        jr z,assodio_read_bar0
        ld a,(bar1)
        jr assodio_bar_ready
assodio_read_bar0:
        ld a,(bar0)
assodio_bar_ready:
        or a
        jp nz,check_priority
check_reserve_priority:
        ld a,(player)
        or a
        jr z,check_res_human
        ld a,(reserve1)
        jr check_priority
check_res_human:
        ld a,(reserve0)
check_priority:
        or a
        jr z,check_normal_src
        ld a,(mvsrc)
        cp 24
        jp nz,check_illegal
        ; BAR / RESERVE is one step BEFORE point zero.
        ; check_destination adds the die ONCE. v30 added it twice,
        ; turning a bar 6 into point M (0M) instead of S.
        ld a,255
        ld (mvprogress),a
        jp check_destination
check_normal_src:
        ld a,(mvsrc)
        cp 24
        jp nc,check_illegal
        call get_own_count
        or a
        jp z,check_illegal
        ld a,(mode)
        cp 1
        jr nz,check_start_feuga
        ld a,(mvsrc)
        call pin_pointer
        ld a,(hl)
        cp 2
        jr z,check_start_feuga
        ld b,a
        ld a,(player)
        cp b
        jp nz,check_illegal ; captive, not top covering checker
check_start_feuga:
        ld a,(mvsrc)
        call from_physical
        ld (mvprogress),a
        ld a,(mode)
        cp 2
        jr nz,check_destination
        ; Fevga only: until the first checker passes opposition,
        ; no second checker may leave the mother position.
        ld a,(mvprogress)
        or a
        jr nz,check_destination
        ld a,(player)
        or a
        jr z,check_first_human
        ld a,(first1)
        jr check_first_status
check_first_human:
        ld a,(first0)
check_first_status:
        or a
        jr nz,check_destination
        ld a,(mvsrc)
        call get_own_count
        cp 15
        jp nz,check_illegal
check_destination:
        ; European Acey-Deucey: once all own men are in the last
        ; six points, moving forward is forbidden; only bear off.
        ld a,(mode)
        cp 4
        jr nz,check_destination_regular
        ld a,(mvsrc)
        cp 24
        jr z,check_destination_regular
        ld a,(mvprogress)
        ld b,a
        ld a,(mvdie)
        add a,b
        cp 24
        jr nc,check_destination_regular
        xor a
        ld (scanp),a
assodio_home_loop:
        ld a,(scanp)
        ld b,a
        ld a,(player)
        ld c,a
        ld a,b
        ld b,c
        call to_physical
        call get_own_count
        or a
        jr nz,check_destination_regular
        ld a,(scanp)
        inc a
        ld (scanp),a
        cp 18
        jr c,assodio_home_loop
        jp check_illegal
check_destination_regular:
        ld a,(mvprogress)
        ld b,a
        ld a,(mvdie)
        add a,b
        cp 24
        jp nc,check_bear
        ld b,a
        ld a,(player)
        ld c,a
        ld a,b
        ld b,c
        call to_physical
        ld (mvdest),a
        call get_enemy_count
        ld b,a
        ld a,(mode)
        cp 2
        jr c,check_may_contact
        cp 4
        jr nc,check_may_contact
        ld a,b
        or a
        jp nz,check_illegal
        ld a,(mode)
        cp 2
        jp nz,check_legal
        jp fevga_six_guard

; Fevga: never create a six-point wall across the entire starting
; quadrant. Starting table = own progress 0..5.
fevga_six_guard:
        ld a,(mvdest)
        call from_physical
        cp 6
        jp nc,check_legal
        ld a,(mvdest)
        call get_own_count
        or a
        jp nz,check_legal       ; destination already occupied
        ld a,(mvprogress)
        cp 6
        jr nc,fevga_six_scan
        ld a,(mvsrc)
        call get_own_count
        cp 1
        jp z,check_legal        ; source position becomes empty
fevga_six_scan:
        xor a
        ld (scanp),a
fevga_six_loop:
        ld a,(scanp)
        ld b,a
        ld a,(mvdest)
        call from_physical
        cp b
        jr z,fevga_six_next
        ld a,(player)
        ld b,a
        ld a,(scanp)
        call to_physical
        call get_own_count
        or a
        jp z,check_legal
fevga_six_next:
        ld a,(scanp)
        inc a
        ld (scanp),a
        cp 6
        jr c,fevga_six_loop
        jp check_illegal
check_may_contact:
        ld a,b
        cp 2
        jp nc,check_illegal
        or a
        jp z,check_legal
        ld a,(mode)
        cp 1
        jr nz,check_hit_regular
        ld a,(mvdest)
        call pin_pointer
        ld a,(hl)
        cp 2
        jp z,check_legal
        ld b,a
        ld a,(player)
        cp b
        jp nz,check_illegal
        jp check_legal
check_hit_regular:
        ld a,1
        ld (hitflag),a
        jp check_legal
check_bear:
        ld a,(mvsrc)
        cp 24
        jp nc,check_illegal
        ld a,(mode)
        cp 4
        jr nz,check_bear_nres
        ld a,(player)
        or a
        jr z,check_bear_res0
        ld a,(reserve1)
        jp check_bear_held
check_bear_res0:
        ld a,(reserve0)
check_bear_held:
        or a
        jp nz,check_illegal
check_bear_nres:
        ld a,(player)
        or a
        jr z,check_bear_bar0
        ld a,(bar1)
        jr check_bear_bars
check_bear_bar0:
        ld a,(bar0)
check_bear_bars:
        or a
        jp nz,check_illegal
        ; Exact only for Assodio. Others may overshoot if nothing farther away.
        ld a,(mvprogress)
        ld b,a
        ld a,(mvdie)
        add a,b
        cp 24
        jr z,check_all_home
        ld a,(mode)
        cp 4
        jp z,check_illegal
check_all_home:
        ld a,0
        ld (scanp),a
check_home_loop:
        ld a,(scanp)
        ld b,a
        ld a,(player)
        ld c,a
        ld a,b
        ld b,c
        call to_physical
        call get_own_count
        or a
        jr z,check_home_next
        ld a,(scanp)
        cp 18
        jp c,check_illegal
        ld b,a
        ld a,(mvprogress)
        cp b
        jr z,check_home_next
        jr c,check_home_next
        ; another checker farther from the exit than this one
        ld a,(mvprogress)
        ld b,a
        ld a,(mvdie)
        add a,b
        cp 24
        jp nz,check_illegal
check_home_next:
        ld a,(scanp)
        inc a
        ld (scanp),a
        cp 24
        jr c,check_home_loop
        ld a,255
        ld (mvdest),a
check_legal:
        ld a,1
        ret
check_illegal:
        xor a
        ret

; A=physical, output A=progress owned by current player.
from_physical:
        ld b,a
        ld a,(player)
        or a
        jr z,from_human
        ld a,(mode)
        cp 2
        jr nz,from_counter
        ld a,b
        add a,12
        cp 24
        jr c,from_done
        sub 24
from_done:
        ret
from_counter:
        ld a,23
        sub b
        ret
from_human:
        ld a,b
        ret

; A=progress, B=player (0 or 1) => A physical index.
to_physical:
        ld c,a
        ld a,b
        or a
        jr z,to_human
        ld a,(mode)
        cp 2
        jr nz,to_counter
        ld a,c
        add a,12
        cp 24
        ret c
        sub 24
        ret
to_counter:
        ld a,23
        sub c
        ret
to_human:
        ld a,c
        ret

; A=physical index -> HL owns board point; destroys D/E.
own_pointer:
        ld e,a
        ld d,0
        ld a,(player)
        or a
        jr z,own_point_green
        ld hl,board1
        jr own_point_add
own_point_green:
        ld hl,board0
own_point_add:
        add hl,de
        ret

enemy_pointer:
        ld e,a
        ld d,0
        ld a,(player)
        or a
        jr z,enemy_is_blue
        ld hl,board0
        jr enemy_add
enemy_is_blue:
        ld hl,board1
enemy_add:
        add hl,de
        ret

pin_pointer:
        ld e,a
        ld d,0
        ld hl,pinTop
        add hl,de
        ret

get_own_count:
        push hl
        push de
        call own_pointer
        ld a,(hl)
        pop de
        pop hl
        ret
get_enemy_count:
        push hl
        push de
        call enemy_pointer
        ld a,(hl)
        pop de
        pop hl
        ret

; ----------------------- Winner & score --------------------------
check_winner:
        ld a,(off0)
        cp 15
        jr nz,win_check_blue
        xor a
        ld (winner),a
        ret
win_check_blue:
        ld a,(off1)
        cp 15
        jr nz,win_check_mother
        ld a,1
        ld (winner),a
        ret
win_check_mother:
        ld a,(mode)
        cp 1
        ret nz
        ; Plakoto: singleton mother pinned and opponent mother gone.
        ld a,(board0)
        cp 1
        jr nz,mother_check_blue
        ld a,(board1)
        or a
        jr z,mother_check_blue
        ld a,(pinTop)
        cp 1
        jr nz,mother_check_blue
        ld a,(board1+23)
        or a
        jr nz,mother_check_blue
        ld a,1
        ld (winner),a
        ret
mother_check_blue:
        ld a,(board1+23)
        cp 1
        ret nz
        ld a,(board0+23)
        or a
        ret z
        ld a,(pinTop+23)
        or a
        ret nz
        ld a,(board0)
        or a
        ret nz
        xor a
        ld (winner),a
        ret

calculate_score:
        ld a,(winner)
        or a
        jr nz,score_cpu
        ld hl,score0
        ld a,(off1)
        jr score_amount
score_cpu:
        cp 1
        ret nz
        ld hl,score1
        ld a,(off0)
score_amount:
        ld b,a
        ld a,(mode)
        cp 4                 ; European Assodio: all wins single
        jr z,score_single
        ld a,b
        or a
        jr z,score_double
score_single:
        inc (hl)
        ret
score_double:
        inc (hl)
        inc (hl)
        ret



paint_board:
        di
        ld hl,32874        ; original board bitmap from approved v15, cleaned of pieces
        ld de,16384
        ld bc,6912
        ldir
        ld hl,39858        ; original 8x2 multicolor attr source
        ld de,26000        ; stable shadow attrs in unused lower RAM
        ld bc,2944
        ldir
        call render_all
        call set_dice_attrs
        call dice_counter_attrs
        call restore_case_pixels
        call restore_case_attrs
        call render_bar_counters
        call paint_raster
        call repair_fs_inner_frame
        call update_wide
        call show_dice
        ei
        ret

; v36: Doubles start by showing both dice normally. After the first move,
; one die remains and the consumed die area shows X3, X2 or X1 locally.
; v35: Used dice now become black instead of leaving a white square.
; Centre-bar marker colours are refreshed every paint.
; F and S stack x positions are nudged for better vertical alignment.
; v34: Display only unspent dice; doubles appear as one die with X4..X1.
; Board, bar checker artwork, rules and input remain based on v32.
; v32: Rounded 14x14 numbered checkers in the centre bar.
; Each is an actual checker silhouette (not an 8x8 text symbol).
; The 16x16 two-column tile is wholly contained in the bar,
; x112..127. Colours share BLACK background with black numerals.
; Two independent icons: YOU green at y64, ME blue at y112.
; Use the existing NIRVANA+ 8x2 shadow/painting, not new engine code.
render_bar_counters:
        ld a,(bar0)
        ld b,4
        ld hl,pixel_row_ptrs+96   ; y64 = row pointer y16+48
        ld de,26952              ; shadow y64, col14 (x112)
        call draw_bar_marker
        ld a,(bar1)
        ld b,1
        ld hl,pixel_row_ptrs+192  ; y112
        ld de,27720              ; shadow y112, col14
        call draw_bar_marker
        ; v60: collected pieces have their own centre-bar counters.
        ; These positions do not overlap the two captured-piece counters.
        ld a,(off0)
        ld b,4
        ld hl,pixel_row_ptrs+32   ; y32
        ld de,26440              ; shadow y32, col14
        call draw_bar_marker
        ld a,(off1)
        ld b,1
        ld hl,pixel_row_ptrs+256  ; y144
        ld de,28232              ; shadow y144, col14
        call draw_bar_marker
        ret

; A = count 1..15, B=checker ink (green 4 / blue 1)
; HL = 16 ZX bitmap row pointers; DE=first of 16 raster attrs.
; 16x16 checker occupies precisely x112..127, 14px round disc.
; v62: marker attribute addresses were one 8-pixel cell row too high (rows y56/y104/y24/y136 instead of
; y64/y112/y32/y144), so the disc got the board colours. Fixed in render_bar_counters above (+128).
draw_bar_marker:
        or a
        ret z
        cp 16
        jr c,bar_marker_count_ok
        ld a,15
bar_marker_count_ok:
        ld (bar_pixel_ptr),hl
        push af                 ; preserve checker count for sprite selection
        ex de,hl               ; HL = first shadow colour attribute
        ld a,b                 ; checker INK (4 green, 1 blue)
        ld b,8                 ; 8 raster attributes = 16px of width
bar_marker_attr_first:
        ld (hl),a
        inc hl
        djnz bar_marker_attr_first
        ld de,120              ; advance to next 8px raster strip
        add hl,de
        ld b,8
bar_marker_attr_second:
        ld (hl),a
        inc hl
        djnz bar_marker_attr_second
        pop af                 ; original checker count
        ; Locate precomputed 16x16 sprite, 32 bytes per checker.
        dec a
        ld e,a
        ld d,0
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,bar_checker_images
        add hl,de
        ex de,hl                 ; DE = bitmap data
        ; The screen row pointer table was saved before template lookup.
        ; Retrieve it from the pointer temporary assigned by caller.
        ld hl,(bar_pixel_ptr)
        ld b,16
bar_marker_pixels:
        push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld h,b
        ld l,c
        ld bc,14                 ; x=112 (14*8 pixels)
        add hl,bc
        ld a,(de)
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        ld (hl),a
        inc de
        pop hl
        pop bc
        djnz bar_marker_pixels
        ret

; v40: F and S are re-centred by shifting them 3 pixels left again.
; That makes the 14-pixel checker mask touch the inner left frame byte of the
; right half. Restore that single bitmap byte column from the clean board copy
; after rendering, so the frame remains continuous.
; v42: Preserve the two actual left-frame bits (x128,129) but do not
; overwrite the six remaining bitmap pixels (x130..135), which include
; the left edge of checker stacks F and S. This avoids a vertical cut.
; The cell x128..135 cannot have two independent Spectrum INK colours.
; Give that cell RED ink on BLACK paper: the case stays red without
; coloured attribute spill. The tiny checker edge in this cell shares
; that ink as an unavoidable 8-pixel attribute-clash compromise.
; v43: Protect the two edges of the right-hand wooden case.
; The left inside frame at x128,129 shares an 8px Spectrum colour cell
; with correctly centred F/S checker pixels x133..135. One INK colour
; cannot represent both. Shift only this inner frame stroke to x127,
; inside the existing RED frame cell x120..127. Never erase the checkers.
; Restore the right frame byte x232..239 directly from the static bitmap.
; v54: keep inner frame entirely in red attribute cell; do not paint frame bits in checker cell.
; v52: shift the original 2-pixel inner frame one pixel left exactly, preserving the source shape beside F/S.
; v49: force the inner-frame join rows at the top and bottom beside F/S.
; v48: use a source address derived from the destination scanline address,
; never from the modified A register after calculating a screen pointer.
repair_fs_inner_frame:
        ret                       ; v62: disabled - it cleared x128,129 (cut the case near F/S); not needed with grid-aligned lanes
        ld a,9
frame_fix_next_y:
        push af
        call calc_screen_addr_col16
        push hl
        ld bc,16490               ; source image - destination image
        add hl,bc
        ld a,(hl)
        and 128                   ; original frame x128 -> x127 only
        ld b,a
        pop hl
        ld a,(hl)
        and 63                    ; clear x128..129, keep checker x130..135
        ld (hl),a                 ; no red frame pixel in F/S colour cell
        ld a,b
        or a
        jr z,frame_fix_done_y
        dec hl
        ld a,(hl)
        or 1                      ; restore shifted frame pixel at x127
        ld (hl),a
frame_fix_done_y:
        pop af
        inc a
        cp 183
        jr c,frame_fix_next_y
        ret

; v54: preserve checker bitmap and attributes at x224..231.
; v48: restore right case at x224..239 with correctly paired source/target
; pixels from the SAME y row. Never interpret bitmap data as y.
restore_case_pixels:
        ld a,9
restore_case_pixels_next:
        push af
        call calc_screen_addr_col16
        ld bc,13
        add hl,bc                 ; destination x232..239: case only
        push hl
        ld bc,16490
        add hl,bc                 ; source x232..239, same scanline
        ld a,(hl)
        pop de
        ld (de),a                 ; restore only the true outer frame
        pop af
        inc a
        cp 183
        jr c,restore_case_pixels_next
        ret

; The attr shadow must be repaired BEFORE paint_raster copies it into
; the NIRVANA+ engine: retain the static case colour at columns 15,29.
; Column 16 is left untouched for the green/blue F/S pieces.
restore_case_attrs:
        ld hl,39918          ; static shadow, x120 column 15
        ld de,26060
        call restore_attr_column
        ld hl,39974          ; static shadow, x232 column 29
        ld de,26116
        call restore_attr_column
        ret
restore_attr_column:
        ld a,23              ; 23 strips, 8 raster lines per strip
restore_attr_next:
        push af
        ld bc,4
        ldir
        ld bc,124             ; 128 bytes per strip - 4 copied
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        pop af
        dec a
        jr nz,restore_attr_next
        ret

 ; v45: NO right-case pixel complement and NO INK/PAPER inversion.
 ; The right case x232..239 is already restored from the original static
 ; source by repair_fs_inner_frame (y9..182), and its raster attributes
 ; from the clean image are copied by restore_case_attrs prior to paint_raster.
 ; This is the same source-and-attribute strategy used for the left case.

; Input A = y pixel row 0..191. Output HL = screen addr for byte column 16.
calc_screen_addr_col16:
        ld d,a                 ; preserve y
        and 7
        ld h,a
        ld l,16                ; target byte column x128..135
        ld a,d
        and 56
        rlca
        rlca                   ; (y&56)<<2
        add a,l
        ld l,a
        ld a,d
        and 192
        rrca
        rrca
        rrca                   ; (y&192)>>3 gives 0,8,16,24
        add a,h
        add a,64               ; base screen page 0x4000
        ld h,a
        ret

; Input A = y pixel row 0..191. Output HL = clean-board source addr col 16.
calc_source_addr_col16:
        call calc_screen_addr_col16
        ld bc,16490            ; 32874 - 16384
        add hl,bc
        ret


render_all:
        xor a
        ld (point_id),a
next_point:
        ld a,(point_id)
        ld e,a
        ld d,0
        ld hl,board0
        add hl,de
        ld a,(hl)
        or a
        jr z,render_blue
        ld (drawcount),a
        ld a,4
        ld (paint_ink),a
        call render_stack
render_blue:
        ld a,(point_id)
        ld e,a
        ld d,0
        ld hl,board1
        add hl,de
        ld a,(hl)
        or a
        jr z,point_done_render
        ld (drawcount),a
        ld a,1
        ld (paint_ink),a
        call render_stack
point_done_render:
        ld a,(point_id)
        inc a
        ld (point_id),a
        cp 24
        jr c,next_point
        ret

render_stack:
        ld hl,maskbuf
        ld de,maskbuf+1
        ld bc,479
        xor a
        ld (hl),a
        ldir
        ; v24: pixel-accurate x position, split into 8-pixel cell + phase.
        ld a,(point_id)
        ld e,a
        ld d,0
        ld hl,point_pixel_x
        add hl,de
        ld a,(hl)
        ld b,a
        and 7
        ld (circle_shift),a
        ld a,b
        srl a
        srl a
        srl a
        ld (xbyte),a
        ; background colors (one row byte for two 8-pixel cells)
        ld a,(point_id)
        add a,a
        ld e,a
        ld d,0
        ld hl,paper_ptrs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (paper_cursor),de
        ; row start top or bottom and per-checker pitch
        ld a,(point_id)
        cp 12
        jr c,draw_top
        ld a,148            ; v62: 12-line checker flush with the bottom (160-12)
        ld (disc_y),a
        jr draw_step

draw_top:
        xor a
        ld (disc_y),a
draw_step:
        ld a,(drawcount)
        cp 16
        jr c,step_inrange
        ld a,15
step_inrange:
        ld e,a
        ld d,0
        ld hl,step_table
        add hl,de
        ld a,(hl)
        ld (disc_step),a
        ld a,(drawcount)
        ld (pieces_left),a
piece_loop:
        call stamp_circle
        ld a,(disc_y)
        ld b,a
        ld a,(disc_step)
        ld c,a
        ld a,(point_id)
        cp 12
        jr c,piece_advance_top
        ld a,b
        sub c
        jr piece_advance_done
piece_advance_top:
        ld a,b
        add a,c
piece_advance_done:
        ld (disc_y),a
        ld a,(pieces_left)
        dec a
        ld (pieces_left),a
        jr nz,piece_loop
        jp apply_mask

stamp_circle:
        ld a,(disc_y)
        ld e,a
        ld d,0
        ld l,a
        ld h,0
        add hl,hl
        add hl,de                 ; line*3 bytes
        ld de,maskbuf
        add hl,de
        push hl
        ld a,(circle_shift)
        add a,a
        ld e,a
        ld d,0
        ld hl,circle_shift_ptrs
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)                ; DE -> 14x3-byte phase bitmap
        pop hl                   ; HL -> point mask buffer row
        ld b,36             ; v62: 12 rows x 3 bytes
stamp_one_byte:
        ld a,(de)
        or (hl)
        ld (hl),a
        inc hl
        inc de
        djnz stamp_one_byte
        ret

apply_mask:
        ld hl,maskbuf
        ld (mask_cursor),hl
        ld hl,pixel_row_ptrs
        ld (pixel_cursor),hl
        ld hl,attr_row_ptrs
        ld (attr_cursor),hl
        ld a,80
        ld (lines_left),a
apply_pair:
        ld hl,(mask_cursor)
        ld a,(hl)
        ld (mask_a),a
        inc hl
        ld a,(hl)
        ld (mask_b),a
        inc hl
        ld a,(hl)
        ld (mask_c),a
        inc hl
        ld a,(hl)
        ld (mask_d),a
        inc hl
        ld a,(hl)
        ld (mask_e),a
        inc hl
        ld a,(hl)
        ld (mask_f),a
        inc hl
        ld (mask_cursor),hl
        ld hl,(paper_cursor)
        ld a,(hl)
        ld (current_paper),a
        inc hl
        ld (paper_cursor),hl
        xor a
        ld (cell_half),a
        ld a,(mask_a)
        ld (mask_top),a
        ld a,(mask_d)
        ld (mask_bottom),a
        call apply_cell
        ld a,1
        ld (cell_half),a
        ld a,(mask_b)
        ld (mask_top),a
        ld a,(mask_e)
        ld (mask_bottom),a
        call apply_cell
        ld a,2
        ld (cell_half),a
        ld a,(mask_c)
        ld (mask_top),a
        ld a,(mask_f)
        ld (mask_bottom),a
        call apply_cell
        ld hl,(pixel_cursor)
        ld de,4
        add hl,de
        ld (pixel_cursor),hl
        ld hl,(attr_cursor)
        ld de,2
        add hl,de
        ld (attr_cursor),hl
        ld a,(lines_left)
        dec a
        ld (lines_left),a
        jp nz,apply_pair
        ret

apply_cell:
        ld a,(mask_top)
        ld b,a
        ld a,(mask_bottom)
        or b
        ret z
        ld hl,(pixel_cursor)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        call add_cell_col
        ld a,(mask_top)
        ld (de),a
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        call add_cell_col
        ld a,(mask_bottom)
        ld (de),a
        ld hl,(attr_cursor)
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld a,(xbyte)
        ld b,a
        ld a,(cell_half)
        add a,b
        add a,a
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(current_paper)
        ld b,a
        ld a,(cell_half)
        or a
        jr z,select_paper_left
        cp 1
        jr z,select_paper_middle
        ld a,b
        and 4
        jr select_paper_checked
select_paper_middle:
        ld a,b
        and 2
        jr select_paper_checked
select_paper_left:
        ld a,b
        and 1
select_paper_checked:
        push af                    ; selected paper bit, including zero flag
        ld a,(point_id)
        cp 255                     ; v62: forced-red rule off, paper_bits decide for every point
        jr nc,point_red_paper
        pop af
        jr z,paper_black
        jr point_red_paper_done
point_red_paper:
        pop af
point_red_paper_done:
        ld a,16                   ; uniform RED paper on bottom-right stacks
        jr put_attr
paper_black:
        xor a               ; black PAPER for checker on point
put_attr:
        ld b,a
        ld a,(paint_ink)
        or b
        ld (hl),a
        ret

add_cell_col:
        ld a,(xbyte)
        ld b,a
        ld a,(cell_half)
        add a,b
        add a,e
        ld e,a
        ret

; Repaint the 8x2 attributes using exactly the approved NIRVANA+ paintC.
paint_raster:
        ld hl,26000
        ld (raster_ptr),hl
        ld a,16
        ld (raster_line),a
raster_next_row:
        xor a
        ld (raster_col),a
raster_next_cell:
        ld a,(raster_line)
        ld d,a
        ld a,(raster_col)
        ld e,a
        ld bc,(raster_ptr)
        call 56418
        ld hl,(raster_ptr)
        ld de,4
        add hl,de
        ld (raster_ptr),hl
        ld a,(raster_col)
        inc a
        ld (raster_col),a
        cp 32
        jr c,raster_next_cell
        ld a,(raster_line)
        add a,8
        ld (raster_line),a
        cp 200
        jr c,raster_next_row
        ret

; v24 white 16x16 pip dice in x240..255 sidebar.
; Columns 30/31, lines 64..79 and 88..103.
; NIRVANA+ 8x2 attribute scratch: 8 bytes per 8-line character row.
set_dice_attrs:
        ; v35: default every die cell to BLACK so a spent die disappears
        ; into the sidebar instead of leaving a white square.
        xor a
        ld hl,27016   ; y64 x240
        call dice_fill8
        ld hl,27144   ; y72
        call dice_fill8
        ld hl,27400   ; y88
        call dice_fill8
        ld hl,27528   ; y96
        call dice_fill8
        ; decide which dice are still active and paint only those WHITE
        ld a,(die1)
        ld b,a
        ld a,(die2)
        cp b
        jr nz,set_attrs_separate
        ld a,(dice0)
        ld b,a
        ld a,(dice1)
        or b
        ld b,a
        ld a,(dice2)
        or b
        ld b,a
        ld a,(dice3)
        or b
        ret z
        ld a,56
        ld hl,27016
        call dice_fill8
        ld hl,27144
        call dice_fill8
        ; Doubles: before the first move, both dice must be WHITE.
        ; After that, the lower box is BLACK for the X3/X2/X1 counter.
        call double_remaining_count
        cp 4
        ret nz
        ld a,56
        ld hl,27400
        call dice_fill8
        ld hl,27528
        jp dice_fill8
set_attrs_separate:
        ld a,(dice0)
        or a
        jr z,set_attrs_second
        ld a,56
        ld hl,27016
        call dice_fill8
        ld hl,27144
        call dice_fill8
set_attrs_second:
        ld a,(dice1)
        or a
        ret z
        ld a,56
        ld hl,27400
        call dice_fill8
        ld hl,27528
        jp dice_fill8

dice_fill8:
        ld b,8
dice_fill_loop:
        ld (hl),a
        inc hl
        djnz dice_fill_loop
        ret

; v34: The active slots are the authoritative record of spent dice.
; Different faces: erase each die as soon as its slot is consumed.
; Doubles: show one die only, with X4..X1 to the immediate left.
dice_counter_attrs:
        ld a,(die1)
        ld b,a
        ld a,(die2)
        cp b
        ret nz
        call double_remaining_count
        cp 4
        ret z
        or a
        ret z
        ld a,7               ; black paper, white ink for Xn counter
        ld hl,27400          ; lower die box y88 x240..247
        call dice_fill8
        ld hl,27528          ; lower die box y96 x240..247
        jp dice_fill8

show_dice:
        ld a,(die1)
        ld b,a
        ld a,(die2)
        cp b
        jr nz,show_separate_dice
        ; Doubles: 4 remaining = show both dice normally.
        ; After the first move show one die + local X3/X2/X1 in the second die box.
        call double_remaining_count
        or a
        ret z
        cp 4
        jr z,show_double_pair
        ld b,a
        ld a,(die1)
        ld hl,pixel_row_ptrs+96
        call draw_one_die
        ld a,b
        call draw_double_count
        ret
show_double_pair:
        ld a,(die1)
        ld hl,pixel_row_ptrs+96
        call draw_one_die
        ld a,(die1)
        ld hl,pixel_row_ptrs+144
        call draw_one_die
        ret
show_separate_dice:
        ld a,(dice0)
        or a
        jr z,show_second_die
        ld a,(die1)
        ld hl,pixel_row_ptrs+96
        call draw_one_die
show_second_die:
        ld a,(dice1)
        or a
        ret z
        ld a,(die2)
        ld hl,pixel_row_ptrs+144
        call draw_one_die
        ret

double_remaining_count:
        xor a
        ld b,a
        ld a,(dice0)
        or a
        jr z,double_count_1
        inc b
double_count_1:
        ld a,(dice1)
        or a
        jr z,double_count_2
        inc b
double_count_2:
        ld a,(dice2)
        or a
        jr z,double_count_3
        inc b
double_count_3:
        ld a,(dice3)
        or a
        jr z,double_count_done
        inc b
double_count_done:
        ld a,b
        ret

; Pixel-perfect 8x8 X and numeral inside the blacked second-die area.
; Input A = remaining count 1..3. Render the glyph in the lower die box.
draw_double_count:
        dec a
        add a,a
        add a,a
        add a,a            ; eight bytes per numeral
        ld e,a
        ld d,0
        ld hl,double_count_glyphs
        add hl,de
        ld (double_digit_ptr),hl
        ld hl,pixel_row_ptrs+144     ; lower die box y88..95 / y96..103
        ld de,double_x_glyph
        ld c,30                      ; x240 inside the former second die area
        call draw_count_glyph
        ld hl,pixel_row_ptrs+144
        ld de,(double_digit_ptr)
        ld c,31                      ; x248
        jp draw_count_glyph


; HL = pointer to 8 consecutive bitmap row pointers
; DE = glyph data, C = screen byte column.
draw_count_glyph:
        ld (count_glyph_ptr),de
        ld (count_row_ptr),hl
        ld a,c
        ld (count_column),a
        ld b,8
count_glyph_row:
        push bc
        ld hl,(count_row_ptr)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (count_row_ptr),hl
        ld a,(count_column)
        ld l,a
        ld h,0
        add hl,de
        ex de,hl
        ld hl,(count_glyph_ptr)
        ld a,(hl)
        inc hl
        ld (count_glyph_ptr),hl
        ld (de),a
        pop bc
        djnz count_glyph_row
        ret
count_glyph_ptr: dw 0
count_row_ptr: dw 0
count_column: db 0

double_x_glyph:
        db 0,66,36,24,24,36,66,0
double_count_glyphs:
        db 24,56,24,24,24,24,126,0       ; 1
        db 60,66,2,12,48,64,126,0       ; 2
        db 60,66,2,28,2,66,60,0         ; 3
        db 12,20,36,68,126,4,4,0        ; 4
double_digit_ptr: dw 0

; A=face 1..6, HL points to 16 successive screen line pointers.
; 16 lines of 2 bytes each; preserve register state for caller.
draw_one_die:
        ; Before the first roll both die values are zero; avoid using
        ; an invalid sprite index and accidentally reading past the table.
        or a
        ret z
        push af
        push bc
        push de
        push hl
        dec a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a     ; 32 bytes per face
        ld e,a
        ld d,0
        push hl
        ld hl,die_face_bitmaps
        add hl,de
        ex de,hl                 ; DE -> 32B dice bitmap
        pop hl                   ; HL -> screen-line pointers
        ld b,16
draw_die_line:
        push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld h,b
        ld l,c
        ld bc,30
        add hl,bc                ; screen x240 (column 30)
        ld a,(de)
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        ld (hl),a
        inc de
        pop hl
        pop bc
        djnz draw_die_line
        pop hl
        pop de
        pop bc
        pop af
        ret

; NIRVANA+ auto-draws a 24x16 tile at screen x232..255 y8..23.
; Keep the tile an exact copy of live bitmap + raster attrs.
update_wide:
        ld a,(16445)
        ld (54000),a
        ld a,(16446)
        ld (54001),a
        ld a,(16447)
        ld (54002),a
        ld a,(16701)
        ld (54003),a
        ld a,(16702)
        ld (54004),a
        ld a,(16703)
        ld (54005),a
        ld a,(16957)
        ld (54006),a
        ld a,(16958)
        ld (54007),a
        ld a,(16959)
        ld (54008),a
        ld a,(17213)
        ld (54009),a
        ld a,(17214)
        ld (54010),a
        ld a,(17215)
        ld (54011),a
        ld a,(17469)
        ld (54012),a
        ld a,(17470)
        ld (54013),a
        ld a,(17471)
        ld (54014),a
        ld a,(17725)
        ld (54015),a
        ld a,(17726)
        ld (54016),a
        ld a,(17727)
        ld (54017),a
        ld a,(17981)
        ld (54018),a
        ld a,(17982)
        ld (54019),a
        ld a,(17983)
        ld (54020),a
        ld a,(18237)
        ld (54021),a
        ld a,(18238)
        ld (54022),a
        ld a,(18239)
        ld (54023),a
        ld a,(16477)
        ld (54024),a
        ld a,(16478)
        ld (54025),a
        ld a,(16479)
        ld (54026),a
        ld a,(16733)
        ld (54027),a
        ld a,(16734)
        ld (54028),a
        ld a,(16735)
        ld (54029),a
        ld a,(16989)
        ld (54030),a
        ld a,(16990)
        ld (54031),a
        ld a,(16991)
        ld (54032),a
        ld a,(17245)
        ld (54033),a
        ld a,(17246)
        ld (54034),a
        ld a,(17247)
        ld (54035),a
        ld a,(17501)
        ld (54036),a
        ld a,(17502)
        ld (54037),a
        ld a,(17503)
        ld (54038),a
        ld a,(17757)
        ld (54039),a
        ld a,(17758)
        ld (54040),a
        ld a,(17759)
        ld (54041),a
        ld a,(18013)
        ld (54042),a
        ld a,(18014)
        ld (54043),a
        ld a,(18015)
        ld (54044),a
        ld a,(18269)
        ld (54045),a
        ld a,(18270)
        ld (54046),a
        ld a,(18271)
        ld (54047),a
        ld a,(26116)
        ld (54048),a
        ld a,(26120)
        ld (54049),a
        ld a,(26124)
        ld (54050),a
        ld a,(26117)
        ld (54051),a
        ld a,(26121)
        ld (54052),a
        ld a,(26125)
        ld (54053),a
        ld a,(26118)
        ld (54054),a
        ld a,(26122)
        ld (54055),a
        ld a,(26126)
        ld (54056),a
        ld a,(26119)
        ld (54057),a
        ld a,(26123)
        ld (54058),a
        ld a,(26127)
        ld (54059),a
        ld a,(26244)
        ld (54060),a
        ld a,(26248)
        ld (54061),a
        ld a,(26252)
        ld (54062),a
        ld a,(26245)
        ld (54063),a
        ld a,(26249)
        ld (54064),a
        ld a,(26253)
        ld (54065),a
        ld a,(26246)
        ld (54066),a
        ld a,(26250)
        ld (54067),a
        ld a,(26254)
        ld (54068),a
        ld a,(26247)
        ld (54069),a
        ld a,(26251)
        ld (54070),a
        ld a,(26255)
        ld (54071),a
        ret

; Greek menu glyphs, regular ZX Spectrum 8x8 monochrome attributes.
greek_menu_glyphs:
        db 0,126,66,66,66,66,66,0   ; 130 Π
        db 0,24,36,66,66,66,66,0   ; 131 Λ
        db 0,60,66,66,66,90,36,0   ; 132 Ω
        db 0,24,126,153,153,126,24,0 ; 133 Φ
        db 0,126,64,64,64,64,64,0   ; 134 Γ
        db 0,126,64,32,16,32,126,0  ; 135 Σ
        db 0,24,36,66,66,66,126,0   ; 136 Δ
        db 0,126,0,126,0,126,0,0   ; 137 Ξ

text_at:
text_loop:
        ld a,(hl)
        or a
        ret z
        push hl
        push bc
        call draw_char
        pop bc
        pop hl
        inc hl
        inc c
        jr text_loop

; Draw 8x8 ROM font character (ASCII 32+), or 128=green/129=blue
; using classic ZX Spectrum 8x8 bitmap layout.
; Checker glyph uses bright green/blue ink on black with lower-right dither.
; Real 48K: 2 colours per 8x8 cell; no multicolour raster tricks.
draw_char:
        push af
        push bc
        push de
        push hl
        ld (txtchar),a
        ld a,b
        ld (txtrow),a
        ld a,c
        ld (txtcol),a
        ld a,(txtchar)
        cp 128
        jr z,glyph_check
        cp 129
        jr z,glyph_check
        cp 130
        jr c,menu_rom_glyph
        cp 138
        jr nc,menu_rom_glyph
        sub 130
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,greek_menu_glyphs
        add hl,de
        jr glyph_ready
menu_rom_glyph:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,15360     ; ROM CHARS base; character 'space' at 15616
        add hl,de
        jr glyph_ready
glyph_check:
        ld hl,checker_glyph
glyph_ready:
        ; E = (row mod 8) * 32 + column
        ld a,(txtrow)
        and 7
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(txtcol)
        add a,e
        ld e,a
        ld a,(txtrow)
        and 24
        add a,64
        ld d,a
        ld b,8
glyph_copy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc d
        djnz glyph_copy
        ; Attribute D=0x58 + floor(row / 8), E as above.
        ld a,(txtrow)
        srl a
        srl a
        srl a
        add a,88
        ld d,a
        ld a,(txtchar)
        cp 128
        jr z,glyph_green
        cp 129
        jr z,glyph_blue
        ld a,(text_ink)
        jr glyph_attr
glyph_green:
        ld a,68     ; bright green ink on black paper: dithered disc
        jr glyph_attr
glyph_blue:
        ld a,65     ; bright blue ink on black paper: dithered disc
glyph_attr:
        ld (de),a
        ld a,(engine_on)
        or a
        jr z,no_nirv_char
        ld a,(txtrow)
        add a,a
        add a,a
        add a,a
        add a,8
        ld d,a
        ld a,(txtcol)
        ld e,a
        ld bc,text_attr4
        call 56418       ; NIRVANA+ paintC
no_nirv_char:
        pop hl
        pop de
        pop bc
        pop af
        ret


; v29: Only the official ZX Spectrum 48K ROM keyboard system.
; IM1 (menu): The standard ROM interrupt has already called KEYBOARD.
;              NEVER call KEYBOARD twice: read LAST_K when FLAGS.5 is set.
; IM2 (game): NIRVANA+ replaces the IM1 service. After each IM2 frame,
;              call the existing ROM routine KEYBOARD ($02BF) just once.
; Both modes use the ROM's key state, debounce, scan matrix, and decoding.
; FLAGS.5 is acknowledged ONLY AFTER a character has been read.
wait_key:
keyboard_wait_rom:
        ld iy,23610              ; standard ROM ERR_NR / IY base
        ld a,(23611)
        or 8                     ; ROM L-mode: return ASCII letters, not BASIC tokens
        ld (23611),a             ; do NOT clear new-key bit here
        halt                     ; IM1 updates keyboard; IM2 is frame clock
        ld a,(engine_on)
        or a
        jr z,keyboard_test_flag  ; in menu, IM1 has ALREADY done the scan
        call 703                 ; $02BF: official 48K ROM KEYBOARD in IM2
keyboard_test_flag:
        ld a,(23611)            ; FLAGS
        and 32                  ; new-character bit set by ROM
        jr z,keyboard_wait_rom
        ld a,(23560)            ; LAST_K: ROM-decoded character
        push af
        ld a,(23611)
        and 223                 ; acknowledge this key only after taking it
        ld (23611),a
        pop af
        ret


; Pictorial 16x16 dice faces, 2 bitmap bytes per scanline, black pip=1
die_face_bitmaps:
        ; face 1
        db 255,255,128,1,128,1,128,1,128,1,128,1,128,1,129,129
        db 129,129,128,1,128,1,128,1,128,1,128,1,128,1,255,255
        ; face 2
        db 255,255,128,1,128,1,152,1,152,1,128,1,128,1,128,1
        db 128,1,128,1,128,49,128,49,128,1,128,1,128,1,255,255
        ; face 3
        db 255,255,128,1,128,1,152,1,152,1,128,1,128,1,129,129
        db 129,129,128,1,128,49,128,49,128,1,128,1,128,1,255,255
        ; face 4
        db 255,255,128,1,128,1,152,49,152,49,128,1,128,1,128,1
        db 128,1,128,1,152,49,152,49,128,1,128,1,128,1,255,255
        ; face 5
        db 255,255,128,1,128,1,152,49,152,49,128,1,128,1,129,129
        db 129,129,128,1,152,49,152,49,128,1,128,1,128,1,255,255
        ; face 6
        db 255,255,128,1,128,1,152,49,152,49,128,1,128,1,152,49
        db 152,49,128,1,128,1,152,49,152,49,128,1,128,1,255,255

s_menu1:          db "1. ",130,"OPTE",135," (BACKGAMMON)",0
s_menu2:          db "2. ",130,131,"AK",132,"TO",0
s_menu3:          db "3. ",133,"EY",134,"A",0
s_menu4:          db "4. ",134,"KIOY",131,0
s_menu5:          db "5. A",135,135,"O",136,"YO (ACEY-DEUCEY)",0
s_menu6:          db "6. O",131,"A (1-5)",0
s_select:         db "E",130,"E",131,"E",137,"E 1 E",132,135," 6",0
s_mode1:          db "PORTES",0
s_mode2:          db "PLAKOTO",0
s_mode3:          db "FEVGA",0
s_mode4:          db "GIOUL",0
s_mode5:          db "ASSODIO",0

; Right sidebar 3x5 pixel prompts, 16x8 bitmaps.
hud_from:
        db 236,234,138,174,204,174,138,170,138,234,0,0,0,0,0,0
hud_to:
        db 238,0,74,0,74,0,74,0,78,0,0,0,0,0,0,0
hud_bad:
        db 196,192,170,160,206,160,170,160,202,192,0,0,0,0,0,0
hud_empty:
        ds 16,0
hud_bar:
        db 232,0,170,0,232,0,170,0,234,0,0,0,0,0,0,0
hud_no:
        db 170,160,234,160,234,160,186,160,170,160,0,0,0,0,0,0
hud_move:
        db 174,174,234,168,234,172,170,168,174,78,0,0,0,0,0,0

; Small 3x5 messages for CPU turn in the pre-existing black sidebar.
; They are screen graphics, NOT an additional keyboard driver.
hud_me_cpu:
        db 174,0,232,0,236,0,168,0,174,0,0,0,0,0,0,0
hud_spc_cpu:
        db 236,224,138,128,236,128,40,128,232,224,0,0,0,0,0,0
hud_end_cpu:
        db 234,192,142,160,206,160,142,160,234,192,0,0,0,0,0,0

s_controls:       db "A",130,"O A-X/0 E",132,135," A-X/0 Z=MENOY",0
s_choose_double:  db "CHOOSE DOUBLE 1..6            ",0
s_win_you:        db "YOU WIN! PRESS ANY KEY       ",0
s_win_cpu:        db "CPU WINS. PRESS ANY KEY      ",0
s_draw:           db "DRAW. PRESS ANY KEY          ",0
columns:          db 2,4,6,8,10,12,19,21,23,25,27,29


s_powered: db "Powered by Nirvana+",0
step_table: db 14,14,14,14,14,14,12,10,8,6,6,6,4,4,4,4   ; even pitch: discs stay on whole 8x2 attribute pairs
text_attr4: db 7,7,7,7
 ; v38: F and S must share the exact same x position, but MUST NOT
 ; overlap the left frame's raster-attribute cell at x128..135.
 ; 136 is the nearest safe cell boundary, protecting the case border.
; v62 no-bleed: every lane starts on an 8-pixel cell boundary (shift 0), so no cell is shared
 ; between neighbouring stacks. Board art in the matching data block is laid out for these x.
point_pixel_x: db 216,200,184,168,152,136,88,72,56,40,24,8,8,24,40,56,72,88,136,152,168,184,200,216
circle_shift_ptrs:
        dw circle_shift_0
        dw circle_shift_1
        dw circle_shift_2
        dw circle_shift_3
        dw circle_shift_4
        dw circle_shift_5
        dw circle_shift_6
        dw circle_shift_7
circle_shift_0:   ; v62: 12-line disc (10,14x10,10 wide), 2 empty rows of padding
        db 31,248,0,127,254,0,127,254,0,127,254,0,127,254,0,127,254,0,127,254,0
        db 127,254,0,127,254,0,127,254,0,127,254,0,31,248,0,0,0,0,0,0,0
circle_shift_1:
        db 3,240,0,7,248,0,15,252,0,31,254,0,63,255,0,63,255,0,63,255,0
        db 63,255,0,63,255,0,63,255,0,31,254,0,15,252,0,7,248,0,3,240,0
circle_shift_2:
        db 1,248,0,3,252,0,7,254,0,15,255,0,31,255,128,31,255,128,31,255,128
        db 31,255,128,31,255,128,31,255,128,15,255,0,7,254,0,3,252,0,1,248,0
circle_shift_3:
        db 0,252,0,1,254,0,3,255,0,7,255,128,15,255,192,15,255,192,15,255,192
        db 15,255,192,15,255,192,15,255,192,7,255,128,3,255,0,1,254,0,0,252,0
circle_shift_4:
        db 0,126,0,0,255,0,1,255,128,3,255,192,7,255,224,7,255,224,7,255,224
        db 7,255,224,7,255,224,7,255,224,3,255,192,1,255,128,0,255,0,0,126,0
circle_shift_5:
        db 0,63,0,0,127,128,0,255,192,1,255,224,3,255,240,3,255,240,3,255,240
        db 3,255,240,3,255,240,3,255,240,1,255,224,0,255,192,0,127,128,0,63,0
circle_shift_6:
        db 0,31,128,0,63,192,0,127,224,0,255,240,1,255,248,1,255,248,1,255,248
        db 1,255,248,1,255,248,1,255,248,0,255,240,0,127,224,0,63,192,0,31,128
circle_shift_7:
        db 0,15,192,0,31,224,0,63,240,0,127,248,0,255,252,0,255,252,0,255,252
        db 0,255,252,0,255,252,0,255,252,0,127,248,0,63,240,0,31,224,0,15,192

pixel_row_ptrs:
        dw 16448,16704
        dw 16960,17216
        dw 17472,17728
        dw 17984,18240
        dw 16480,16736
        dw 16992,17248
        dw 17504,17760
        dw 18016,18272
        dw 16512,16768
        dw 17024,17280
        dw 17536,17792
        dw 18048,18304
        dw 16544,16800
        dw 17056,17312
        dw 17568,17824
        dw 18080,18336
        dw 16576,16832
        dw 17088,17344
        dw 17600,17856
        dw 18112,18368
        dw 16608,16864
        dw 17120,17376
        dw 17632,17888
        dw 18144,18400
        dw 18432,18688
        dw 18944,19200
        dw 19456,19712
        dw 19968,20224
        dw 18464,18720
        dw 18976,19232
        dw 19488,19744
        dw 20000,20256
        dw 18496,18752
        dw 19008,19264
        dw 19520,19776
        dw 20032,20288
        dw 18528,18784
        dw 19040,19296
        dw 19552,19808
        dw 20064,20320
        dw 18560,18816
        dw 19072,19328
        dw 19584,19840
        dw 20096,20352
        dw 18592,18848
        dw 19104,19360
        dw 19616,19872
        dw 20128,20384
        dw 18624,18880
        dw 19136,19392
        dw 19648,19904
        dw 20160,20416
        dw 18656,18912
        dw 19168,19424
        dw 19680,19936
        dw 20192,20448
        dw 20480,20736
        dw 20992,21248
        dw 21504,21760
        dw 22016,22272
        dw 20512,20768
        dw 21024,21280
        dw 21536,21792
        dw 22048,22304
        dw 20544,20800
        dw 21056,21312
        dw 21568,21824
        dw 22080,22336
        dw 20576,20832
        dw 21088,21344
        dw 21600,21856
        dw 22112,22368
        dw 20608,20864
        dw 21120,21376
        dw 21632,21888
        dw 22144,22400
        dw 20640,20896
        dw 21152,21408
        dw 21664,21920
        dw 22176,22432
attr_row_ptrs:
        dw 26128
        dw 26129
        dw 26130
        dw 26131
        dw 26256
        dw 26257
        dw 26258
        dw 26259
        dw 26384
        dw 26385
        dw 26386
        dw 26387
        dw 26512
        dw 26513
        dw 26514
        dw 26515
        dw 26640
        dw 26641
        dw 26642
        dw 26643
        dw 26768
        dw 26769
        dw 26770
        dw 26771
        dw 26896
        dw 26897
        dw 26898
        dw 26899
        dw 27024
        dw 27025
        dw 27026
        dw 27027
        dw 27152
        dw 27153
        dw 27154
        dw 27155
        dw 27280
        dw 27281
        dw 27282
        dw 27283
        dw 27408
        dw 27409
        dw 27410
        dw 27411
        dw 27536
        dw 27537
        dw 27538
        dw 27539
        dw 27664
        dw 27665
        dw 27666
        dw 27667
        dw 27792
        dw 27793
        dw 27794
        dw 27795
        dw 27920
        dw 27921
        dw 27922
        dw 27923
        dw 28048
        dw 28049
        dw 28050
        dw 28051
        dw 28176
        dw 28177
        dw 28178
        dw 28179
        dw 28304
        dw 28305
        dw 28306
        dw 28307
        dw 28432
        dw 28433
        dw 28434
        dw 28435
        dw 28560
        dw 28561
        dw 28562
        dw 28563
paper_ptrs:
        dw paper_bits+0
        dw paper_bits+80
        dw paper_bits+160
        dw paper_bits+240
        dw paper_bits+320
        dw paper_bits+400
        dw paper_bits+480
        dw paper_bits+560
        dw paper_bits+640
        dw paper_bits+720
        dw paper_bits+800
        dw paper_bits+880
        dw paper_bits+960
        dw paper_bits+1040
        dw paper_bits+1120
        dw paper_bits+1200
        dw paper_bits+1280
        dw paper_bits+1360
        dw paper_bits+1440
        dw paper_bits+1520
        dw paper_bits+1600
        dw paper_bits+1680
        dw paper_bits+1760
        dw paper_bits+1840
paper_bits:
        ; point 0
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 1
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 2
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 3
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 4
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 5
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 6
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 7
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 8
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 9
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 10
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 11
        db 0,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ; point 12
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 13
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 14
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 15
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 16
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 17
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 18
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 19
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 20
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 21
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 22
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
        ; point 23
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
        db 3,3,3,3,3,3,3,3,3,3,3,3,3,2,2,0
checker_glyph: db 60,126,255,255,253,122,52,0

bar_checker_images:
        db 0,0,7,224,31,248,63,252,127,254,126,254,124,254,126,254 ; count 1, lines 0..7
        db 126,254,124,126,127,254,127,254,63,252,31,248,7,224,0,0 ; count 1, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,124,126,127,126,124,126 ; count 2, lines 0..7
        db 125,254,124,126,127,254,127,254,63,252,31,248,7,224,0,0 ; count 2, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,124,126,127,126,124,126 ; count 3, lines 0..7
        db 127,126,124,126,127,254,127,254,63,252,31,248,7,224,0,0 ; count 3, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,125,126,125,126,124,126 ; count 4, lines 0..7
        db 127,126,127,126,127,254,127,254,63,252,31,248,7,224,0,0 ; count 4, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,124,126,125,254,124,126 ; count 5, lines 0..7
        db 127,126,124,126,127,254,127,254,63,252,31,248,7,224,0,0 ; count 5, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,124,126,125,254,124,126 ; count 6, lines 0..7
        db 125,126,124,126,127,254,127,254,63,252,31,248,7,224,0,0 ; count 6, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,124,126,127,126,126,254 ; count 7, lines 0..7
        db 126,254,126,254,127,254,127,254,63,252,31,248,7,224,0,0 ; count 7, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,124,126,125,126,124,126 ; count 8, lines 0..7
        db 125,126,124,126,127,254,127,254,63,252,31,248,7,224,0,0 ; count 8, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,124,126,125,126,124,126 ; count 9, lines 0..7
        db 127,126,124,126,127,254,127,254,63,252,31,248,7,224,0,0 ; count 9, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,123,30,115,94,123,94 ; count 10, lines 0..7
        db 123,94,113,30,127,254,127,254,63,252,31,248,7,224,0,0 ; count 10, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,123,190,115,62,123,190 ; count 11, lines 0..7
        db 123,190,113,30,127,254,127,254,63,252,31,248,7,224,0,0 ; count 11, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,123,30,115,222,123,30 ; count 12, lines 0..7
        db 123,126,113,30,127,254,127,254,63,252,31,248,7,224,0,0 ; count 12, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,123,30,115,222,123,30 ; count 13, lines 0..7
        db 123,222,113,30,127,254,127,254,63,252,31,248,7,224,0,0 ; count 13, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,123,94,115,94,123,30 ; count 14, lines 0..7
        db 123,222,113,222,127,254,127,254,63,252,31,248,7,224,0,0 ; count 14, lines 8..15
        db 0,0,7,224,31,248,63,252,127,254,123,30,115,126,123,30 ; count 15, lines 0..7
        db 123,222,113,30,127,254,127,254,63,252,31,248,7,224,0,0 ; count 15, lines 8..15

bar_pixel_ptr:   dw 0
bar_marker_count: db 0
mode:            db 0
setflag:         db 0
score0:          db 0
score1:          db 0
player:          db 0
original_player: db 0
winner:          db 255
rng:             db 1
die1:            db 0
die2:            db 0
current_double:  db 0
gioul_transferred: db 0
dice0:           db 0
dice1:           db 0
dice2:           db 0
dice3:           db 0
mvslot:          db 0
mvsrc:           db 0
mvdie:           db 0
mvdest:          db 0
wanted_dest:     db 0
mvprogress:      db 0
hitflag:         db 0
scanprogress:    db 0
scanp:           db 0
board0:          ds 24,0
board1:          ds 24,0
pinTop:          ds 24,2
bar0:            db 0
bar1:            db 0
reserve0:        db 0
reserve1:        db 0
off0:            db 0
off1:            db 0
first0:          db 0
first1:          db 0
labelindex:      db 0
drawpoint:       db 0
drawcolidx:      db 0
drawtop:         db 0
piececol:        db 0
countgreen:      db 0
countblue:       db 0
drawcount:       db 0
drawglyph:       db 0
drawoffset:      db 0
drawn_left:      db 0
counttype:       db 0
hudslot:         db 0
digitunit:       db 0
txtrow:          db 0
txtcol:          db 0
txtchar:         db 0



engine_on: db 0
input_from: db 63
input_to: db 63
input_phase: db 0
text_ink: db 7
title_left: db 0
point_id: db 0
paint_ink: db 0
xbyte: db 0
disc_y: db 0
disc_step: db 0
pieces_left: db 0
mask_cursor: dw maskbuf
pixel_cursor: dw pixel_row_ptrs
attr_cursor: dw attr_row_ptrs
paper_cursor: dw paper_bits
lines_left: db 0
mask_a: db 0
mask_b: db 0
mask_c: db 0
mask_d: db 0
mask_e: db 0
mask_f: db 0
circle_shift: db 0
mask_top: db 0
mask_bottom: db 0
cell_half: db 0
current_paper: db 0
raster_ptr: dw 26000
raster_line: db 16
raster_col: db 0
maskbuf: ds 480,0

        end
