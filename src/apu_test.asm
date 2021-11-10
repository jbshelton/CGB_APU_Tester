; CGB APU tester Copyright (C) 2021 Jackson Shelton <jacksonshelton8@gmail.com>
; MGBLIB Copyright (C) 2020 Matt Currie <me@mattcurrie.com>
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

IF (__RGBDS_MAJOR__ == 0 && (__RGBDS_MINOR__ < 4 || (__RGBDS_MINOR__ == 4 && __RGBDS_PATCH__ < 2)))
    FAIL "Requires RGBDS v0.4.2+"
ENDC

SECTION "lib", ROMX
INCLUDE "mgblib/src/hardware.inc"
INCLUDE "mgblib/src/macros.asm"
    enable_cgb_mode
INCLUDE "mgblib/src/old_skool_outline_thick.asm"
INCLUDE "mgblib/src/display.asm"
INCLUDE "mgblib/src/print.asm"
INCLUDE "mgblib/src/misc/delay.asm"


SECTION "boot", ROM0[$100]
    nop                                       
    jp main         

SECTION "header", ROM0[$104]
    ds $143-@, $0

SECTION "header-remainder", ROM0[$144]
    ds $150-@, $0

SECTION "main", ROM0[$150]

main::
    di
    ld sp, $cfff
    call ResetDisplay
    call ResetCursor
    call LoadFont

    print_string_literal "APU misc tests\n"

test_length_counter::
    ld hl, rNR52
    ld d, 63
    ld b, 4
    ld c, $80
    ld e, 0
    xor a
    ldh [rTAC], a
    ldh [rTIMA], a
.length_test_loop:
    ; reset APU
    xor a
    ldh [rTIMA], a
    ldh [rDIV], a
    ld [hl], a
    cpl
    ld [hl], a

    ; set sound length to value in D to test certain step of frame sequencer
    ld a, d
    ldh [rNR11], a

    ; trigger with length enabled
    ld a, $C0
    ldh [rNR12], a
    ldh [rNR14], a
    ld a, %00000101
    ldh [rTAC], a

.test_length_enable:
    ld a, [hl]
    cp $f0
    jr nz, .test_length_enable
    xor a
    ldh [rTAC], a
    ldh a, [rTIMA]
    ldh [c], a
    inc c
    ldh a, [rDIV]
    ldh [c], a
    inc c
    dec d
    dec b
    jr nz, .length_test_loop
    ; jp print_length

test_volume_envelope::
    xor a
    ld e, a
    ldh [rTMA], a
    ldh [rTIMA], a
    ldh [rDIV], a
    ld [hl], a
    cpl
    ld [hl], a

    ld a, $10
    ldh [rNR12], a
    
    ; trigger with length disabled
    ld a, $80
    ldh [rNR14], a

.wait_high:
    ldh a, [rPCM12]
    and $0f
    jr z, .wait_high

    ldh [rDIV], a

    ld a, $11
    ldh [rNR12], a
    ld a, $80
    ldh [rNR14], a
    ld a, %00000101
    ldh [rTAC], a

.test_env_enable:
    ldh a, [rPCM12]
    and $0f
    jr nz, .test_env_enable
    xor a
    ldh [rTAC], a
    ldh a, [rTIMA]
    ldh [c], a
    inc c
    ldh a, [rDIV]
    ldh [c], a
    inc c

test_frequency_sweep::
    ld d, 1
    ld b, 2
    ld e, 0
    xor a
    ldh [rTAC], a
.sweep_test_loop:
    xor a
    ldh [rTIMA], a
    ldh [rDIV], a
    ld [hl], a
    cpl
    ld [hl], a
    
    ; set frequency to max
    ld a, $ff
    ldh [rNR13], a
    and $f0
    ldh [rNR12], a

    ; configure sweep (addition, no sweep shift)
    ld a, d
    rla
    rla
    rla
    rla
    ldh [rNR10], a
    ld a, $87
    ldh [rNR14], a
    ld a, %00000101
    ldh [rTAC], a

.test_sweep_enable:
    ld a, [hl]
    cp $f0
    jr nz, .test_sweep_enable
    xor a
    ldh [rTAC], a
    ldh a, [rTIMA]
    ldh [c], a
    inc c
    ldh a, [rDIV]
    ldh [c], a
    inc c
    inc d
    dec b
    jr nz, .sweep_test_loop

pulse_width_test::
    xor a
    ldh [$B0], a
    ld a, 4
    ldh [$B1], a
.pulse_test_loop:
    xor a
    ld e, a
    ld b, a
    ld d, a
    ld [hl], a
    cpl
    ld [hl], a
    
    ; wait takes 36 cycles to complete
    ; (4194304/36 = 116508.4444Hz)
    ; pulse needs to be 14563.5556Hz for read to work
    ; 4194304/288, 524288/36, 131072/9 (2048 - 2039) ($x7 $F7)
    ; max noise can tick is 524288Hz
    ; = 8 single speed cycles, 16 double speed cycles
    ; 13 ticks are required until noise first goes high in 7 bit mode
    ; = 104 single speed cycles, 208 double speed cycles

    ldh a, [$B0]
    rrca
    rrca
    and $C0
    ldh [rNR11], a
    ldh a, [$B0]
    inc a
    ldh [$B0], a

    ld a, $F7
    ldh [rNR13], a

    ld a, $F0
    ldh [rNR12], a
    
    ; trigger with length disabled
    ld a, $87
    ldh [rNR14], a

.wait_high:
    ldh a, [rPCM12]
    inc e
    and $0f
    jr z, .wait_high
    nop

.wait_low:
    ldh a, [rPCM12]
    inc b
    and $0f
    jr nz, .wait_low
    nop

.wait_high_end:
    ldh a, [rPCM12]
    inc d
    and $0f
    jr z, .wait_high_end

    ld a, e
    ldh [c], a
    inc c
   
    ld a, b
    ldh [c], a
    inc c
    
    ld a, d
    ldh [c], a
    inc c
    
    ldh a, [$B1]
    dec a
    ldh [$B1], a
    jp nz, .pulse_test_loop

noise_lfsr_test::
    xor a
    ld e, a
    ld [hl], a
    cpl
    ld [hl], a

    ; needs to be 65536Hz
    ; ratio: 1
    ; divider: 8
    ld b, $f0

    ld a, $f0
    ldh [rNR42], a
    ld a, $02 ;1048576/2^2+1 131072Hz 8 NOPs per tick
    ldh [rNR43], a
    ld a, $80
    ldh [rNR44], a

.lfsr_15_loop:
    ldh a, [rPCM34]
    inc e
    and b
    jr z, .lfsr_15_loop
    ;reads on the 3rd NOP

    ld a, e
    ldh [c], a
    inc c


    ld e, $00
    ld a, $0A
    ldh [rNR43], a
    ld a, $80
    ldh [rNR44], a

.lfsr_7_loop:
    ldh a, [rPCM34]
    inc e
    and b
    jr z, .lfsr_7_loop

    ld a, e
    ldh [c], a
    

    ; now print the results

print_length::
    print_string_literal "\nLength ticks:\n"
    ldh a, [$80]
    call PrintHexU8NoDollar
    ld a, " "
    call PrintCharacter
    ldh a, [$81]
    call PrintHexU8NoDollar
    ld a, ","
    call PrintCharacter
    ld a, " "
    call PrintCharacter
    ldh a, [$82]
    call PrintHexU8NoDollar
    ld a, " "
    call PrintCharacter
    ldh a, [$83]
    call PrintHexU8NoDollar
    ld a, ","
    call PrintCharacter
    ld a, " "
    call PrintCharacter
    ldh a, [$84]
    call PrintHexU8NoDollar
    ld a, " "
    call PrintCharacter
    ldh a, [$85]
    call PrintHexU8NoDollar
    ld a, "\n"
    call PrintCharacter
    ldh a, [$86]
    call PrintHexU8NoDollar
    ld a, " "
    call PrintCharacter
    ldh a, [$87]
    call PrintHexU8NoDollar
    print_string_literal "\n"
    ; jp done

print_volume::
    print_string_literal "Volume ticks:\n"
    ldh a, [$88]
    call PrintHexU8NoDollar
    ld a, " "
    call PrintCharacter
    ldh a, [$89]
    call PrintHexU8NoDollar
    print_string_literal "\n\n"
    ; jp done

print_sweep::
    print_string_literal "Sweep ticks:\n"
    ldh a, [$8A]
    call PrintHexU8NoDollar
    ld a, " "
    call PrintCharacter
    ldh a, [$8B]
    call PrintHexU8NoDollar
    ld a, ","
    call PrintCharacter
    ld a, " "
    call PrintCharacter
    ldh a, [$8C]
    call PrintHexU8NoDollar
    ld a, " "
    call PrintCharacter
    ldh a, [$8D]
    call PrintHexU8NoDollar
    print_string_literal "\n"
    ; jp done

print_pulse::
    print_string_literal "Pulse phase reads:\n"
    print_string_literal "12.5%: "
    ldh a, [$8E]
    call PrintDecimal
    ld a, " "
    call PrintCharacter
    ldh a, [$8F]
    call PrintDecimal
    ld a, " "
    call PrintCharacter
    ldh a, [$90]
    call PrintDecimal
    ld a, "\n"
    call PrintCharacter

    print_string_literal "25%  : "
    ldh a, [$91]
    call PrintDecimal
    ld a, " "
    call PrintCharacter
    ldh a, [$92]
    call PrintDecimal
    ld a, " "
    call PrintCharacter
    ldh a, [$93]
    call PrintDecimal
    ld a, "\n"
    call PrintCharacter

    print_string_literal "50%  : "
    ldh a, [$94]
    call PrintDecimal
    ld a, " "
    call PrintCharacter
    ldh a, [$95]
    call PrintDecimal
    ld a, " "
    call PrintCharacter
    ldh a, [$96]
    call PrintDecimal
    ld a, "\n"
    call PrintCharacter

    print_string_literal "75%  : "
    ldh a, [$97]
    call PrintDecimal
    ld a, " "
    call PrintCharacter
    ldh a, [$98]
    call PrintDecimal
    ld a, " "
    call PrintCharacter
    ldh a, [$99]
    call PrintDecimal
    ld a, "\n"
    call PrintCharacter

    ; pulse table from this test:
    ; 12.5%: n_______#  (1 stall tick, 7 ticks low, 1 tick high)
    ; 25%  : nn______## (2 stall ticks, 6 ticks low, 2 ticks high)
    ; 50%  : nn____#### (2 stall ticks, 4 ticks low, 4 ticks high)
    ; 75%  : __######   (0 stall ticks, 2 ticks low, 6 ticks high)

    ; pulse table, assume all widths are delayed by 2 ticks:
    ; 12.5%: nn______#_ (2 stall ticks, 6 ticks low, 1 tick high, 1 tick low)
    ; 25%  : nn______## (2 stall ticks, 6 ticks low, 2 ticks high)
    ; 50%  : nn____#### (2 stall ticks, 4 ticks low, 4 ticks high)
    ; 75%  : nn######__ (2 stall ticks, 6 ticks high, 2 ticks low)

print_noise::
    print_string_literal "Noise ticks 15/7:\n"
    ldh a, [$9A]
    call PrintDecimal
    ld a, " "
    call PrintCharacter
    ld a, "/"
    call PrintCharacter
    ld a, " "
    call PrintCharacter
    ldh a, [$9B]
    call PrintDecimal

done::
    lcd_on

.forever:
    jr .forever