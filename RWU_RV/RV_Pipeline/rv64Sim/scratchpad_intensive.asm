# scratchpad_intensive.asm – Intensive Scratchpad Memory Test
#
# SP_BASE = 0x0000_0000, SP_DEPTH = 1024 (8 KiB: 0x0000..0x1FF8)
# GPIO base: x1 = 0x0000_0001_0000_0000
# GPIO data register: offset 0x10 from base
#
# Loop structure uses bne+countdown (consistent with filldmem.asm pattern).
#
# Checkpoint values written to GPIO:
#   0x01 – phases 1+2 pass (doubleword fill + verify, all 1024 words)
#   0x02 – phase  3  pass (byte   write/read, all 8 offsets + sign ext.)
#   0x03 – phase  4  pass (halfword write/read, all 4 offsets + sign ext.)
#   0x04 – phase  5  pass (word write/read, both offsets + negative pattern)
#   0x05 – phase  6  pass (isolated byte-write RMW isolation check)
#   0x55 – all phases passed → PASS
#   0xFF – any compare mismatch → FAIL

.global _start

_start:
    addi  x1,  x0, 0x100
    slli  x1,  x1, 24            # x1 = 0x0000_0001_0000_0000  (GPIO base)

    # ── Phase 1: fill all 1024 SP words ────────────────────────────
    # Pattern: mem[addr] = addr (64-bit doubleword)
    # Loop structure: count-down from 1024 to 0 using bne (proven pattern)
    addi  x10, x0, 0             # addr = 0
    addi  x11, x0, 1
    slli  x11, x11, 10           # x11 = 1024 (iteration counter)
fill_loop:
    sd    x10, 0(x10)
    addi  x10, x10, 8
    addi  x11, x11, -1
    bne   x11, x0, fill_loop    # continue while count > 0

    # ── Phase 2: read-back and verify all 1024 words ───────────────
    addi  x10, x0, 0
    addi  x11, x0, 1
    slli  x11, x11, 10           # x11 = 1024
verify_loop:
    ld    x5, 0(x10)
    bne   x5, x10, fail
    addi  x10, x10, 8
    addi  x11, x11, -1
    bne   x11, x0, verify_loop

    addi  x20, x0, 1
    sb    x20, 16(x1)            # checkpoint 1

    # ── Phase 3: byte write / read (all 8 offsets) ─────────────────
    addi  x12, x0, 0x100         # test DW at SP addr 0x100
    sd    x0, 0(x12)             # clear

    addi  x20, x0, 0xa5          # test value (165, bit7=1 → sign test)

    sb    x20, 0(x12)
    lbu   x5,  0(x12)
    bne   x5,  x20, fail

    sb    x20, 1(x12)
    lbu   x5,  1(x12)
    bne   x5,  x20, fail

    sb    x20, 2(x12)
    lbu   x5,  2(x12)
    bne   x5,  x20, fail

    sb    x20, 3(x12)
    lbu   x5,  3(x12)
    bne   x5,  x20, fail

    sb    x20, 4(x12)
    lbu   x5,  4(x12)
    bne   x5,  x20, fail

    sb    x20, 5(x12)
    lbu   x5,  5(x12)
    bne   x5,  x20, fail

    sb    x20, 6(x12)
    lbu   x5,  6(x12)
    bne   x5,  x20, fail

    sb    x20, 7(x12)
    lbu   x5,  7(x12)
    bne   x5,  x20, fail

    # lb sign-extension: 0xA5 → -91 = 0xFFFF_FFFF_FFFF_FFA5
    lb    x5,  0(x12)
    addi  x6,  x0, -91
    bne   x5,  x6, fail

    addi  x20, x0, 2
    sb    x20, 16(x1)            # checkpoint 2

    # ── Phase 4: halfword write / read (all 4 offsets) ─────────────
    addi  x12, x0, 0x200
    sd    x0, 0(x12)
    addi  x20, x0, 0x555         # 1365 (positive, bit15=0 → sign test safe)

    sh    x20, 0(x12)
    lhu   x5,  0(x12)
    bne   x5,  x20, fail

    sh    x20, 2(x12)
    lhu   x5,  2(x12)
    bne   x5,  x20, fail

    sh    x20, 4(x12)
    lhu   x5,  4(x12)
    bne   x5,  x20, fail

    sh    x20, 6(x12)
    lhu   x5,  6(x12)
    bne   x5,  x20, fail

    # lh sign-extension: 0x555 has bit15=0 → same value as lhu
    lh    x5,  0(x12)
    bne   x5,  x20, fail

    addi  x20, x0, 3
    sb    x20, 16(x1)            # checkpoint 3

    # ── Phase 5: word write / read ─────────────────────────────────
    addi  x12, x0, 0x300
    sd    x0, 0(x12)
    sd    x0, 8(x12)

    # positive pattern 0x1234_5678
    lui   x20, 0x12345           # x20 = 0x1234_5000
    addi  x20, x20, 0x678        # x20 = 0x1234_5678

    sw    x20, 0(x12)
    lwu   x5,  0(x12)
    bne   x5,  x20, fail

    sw    x20, 4(x12)
    lwu   x5,  4(x12)
    bne   x5,  x20, fail

    lw    x5,  0(x12)            # sign-extended; bit31=0 → same as lwu
    bne   x5,  x20, fail

    # negative pattern 0xDEAD_BEEF
    # lui 0xDEADC → 0xFFFF_FFFF_DEAD_C000  (bit31=1 → sign extend)
    # addi -0x111 → 0xFFFF_FFFF_DEAD_BEEF
    lui   x20, 0xDEADC
    addi  x20, x20, -0x111       # x20 = 0xFFFF_FFFF_DEAD_BEEF

    sw    x20, 8(x12)
    lw    x5,  8(x12)            # sign-extended → 0xFFFF_FFFF_DEAD_BEEF
    bne   x5,  x20, fail

    lwu   x6,  8(x12)            # zero-extended → 0x0000_0000_DEAD_BEEF
    slli  x7,  x20, 32
    srli  x7,  x7,  32           # x7 = 0x0000_0000_DEAD_BEEF
    bne   x6,  x7,  fail

    addi  x20, x0, 4
    sb    x20, 16(x1)            # checkpoint 4

    # ── Phase 6: RMW byte-isolation check ──────────────────────────
    # After clearing a DW, two isolated byte writes must not corrupt
    # the bytes in between.
    addi  x12, x0, 0x400
    sd    x0, 0(x12)             # all 8 bytes = 0x00

    addi  x6, x0, 0x5a
    sb    x6, 0(x12)             # byte 0 = 0x5A
    addi  x6, x0, 0xa5
    sb    x6, 7(x12)             # byte 7 = 0xA5

    lbu   x5, 0(x12)
    addi  x6, x0, 0x5a
    bne   x5, x6, fail

    lbu   x5, 7(x12)
    addi  x6, x0, 0xa5
    bne   x5, x6, fail

    lbu   x5, 1(x12)             # untouched → must be 0x00
    bne   x5, x0, fail

    lbu   x5, 6(x12)             # untouched → must be 0x00
    bne   x5, x0, fail

    addi  x20, x0, 5
    sb    x20, 16(x1)            # checkpoint 5

    # ── All phases passed ──────────────────────────────────────────
    addi  x20, x0, 0x55
    sb    x20, 16(x1)            # PASS marker

    jal   x0, done

fail:
    addi  x20, x0, -1            # low byte = 0xFF
    sb    x20, 16(x1)            # FAIL marker

done:
    beq   x0, x0, done
