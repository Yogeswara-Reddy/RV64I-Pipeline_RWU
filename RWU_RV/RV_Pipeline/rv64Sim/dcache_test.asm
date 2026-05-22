# dcache_test.asm
#
# D-Cache comprehensive test: cold miss, line fill, intra-line hits,
# sub-word sign/zero extension, 4-way PLRU eviction, independent sets.
#
# Cache geometry  (asDCache: 4-way SA, 32 sets, 32-byte lines):
#   tag  = addr[31:10]   index = addr[9:5]   offset = addr[4:0]
#   same-set stride = 0x400 (1 kB)
#
# Flash address layout  (D-Cache region: addr >= 0x2000):
#   0x2000  tag8 / set0   line [0x2000:0x201F]
#             dw0 = 0x42, dw1 = 0xA0, dw2 = 0xFF, dw3 = 0x1234
#   0x2020  tag8 / set1   dw0 = 0x99            (independent set)
#   0x2400  tag9 / set0   dw0 = 0x11
#   0x2800  tag10/ set0   dw0 = 0x22
#   0x2C00  tag11/ set0   dw0 = 0x33
#   0x3000  tag12/ set0   dw0 = 0x44  (5th same-set tag, PLRU evicts W0)
#
# GPIO  base = 0x1_0000_0000, checkpoint register at offset 16:
#   sb checkpoint, 16(gpio_base)
#   0x01 phase 1: cold miss + fill + intra-line hits
#   0x02 phase 2: sub-word lb/lbu/lh/lhu/lw/lwu
#   0x03 phase 3: all 4 ways of set0 filled (W0–W3)
#   0x04 phase 4: PLRU eviction of W0 (tag8 → tag12)
#   0x05 phase 5: tag8 reload after eviction + set1 cold miss
#   0x06 phase 6: warm-cache hits on set0 and set1
#   0x55 PASS  /  0xFF FAIL

.section .text
.global _start

_start:
    li   x2,  0x1FF8        # SP = top of scratchpad (addr 0x0000_1FF8)
    addi x1,  x0,  0x100
    slli x1,  x1,  24       # x1  = GPIO base 0x1_0000_0000
    lui  x5,  2             # x5  = 0x2000 (Flash / D-Cache region base for tag8/set0)

# ─── Phase 1: cold miss → cache line fill → intra-line hits ──────────────────
phase1:
    ld   x10, 0(x5)         # MISS: fills line [0x2000:0x201F] into W0; x10 = 0x42
    li   x11, 0x42
    bne  x10, x11, fail

    ld   x10, 8(x5)         # HIT:  intra-line, dw1; x10 = 0xA0
    li   x11, 0xA0
    bne  x10, x11, fail

    ld   x10, 16(x5)        # HIT:  intra-line, dw2; x10 = 0xFF
    li   x11, 0xFF
    bne  x10, x11, fail

    li   x20, 1
    sb   x20, 16(x1)        # checkpoint 0x01

# ─── Phase 2: sub-word access with sign / zero extension ─────────────────────
phase2:
    lb   x10, 16(x5)        # byte 0xFF  sign-extended  → -1
    li   x11, -1
    bne  x10, x11, fail

    lbu  x10, 16(x5)        # byte 0xFF  zero-extended  → 0xFF
    li   x11, 0xFF
    bne  x10, x11, fail

    lh   x10, 24(x5)        # half 0x1234 (positive)    → 0x1234
    li   x11, 0x1234
    bne  x10, x11, fail

    lhu  x10, 24(x5)        # half 0x1234 zero-extended → 0x1234
    li   x11, 0x1234
    bne  x10, x11, fail

    lw   x10, 24(x5)        # word 0x1234 sign-extended  → 0x1234
    li   x11, 0x1234
    bne  x10, x11, fail

    lwu  x10, 24(x5)        # word 0x1234 zero-extended  → 0x1234
    li   x11, 0x1234
    bne  x10, x11, fail

    li   x20, 2
    sb   x20, 16(x1)        # checkpoint 0x02

# ─── Phase 3: fill remaining ways (W1, W2, W3) of set0 ───────────────────────
# PLRU trace: start=3'b011(W0 MRU)
phase3:
    li   x6,  0x2400        # tag9  / set0
    ld   x10, 0(x6)         # MISS: fill W1 (next invalid); x10 = 0x11
    li   x11, 0x11
    bne  x10, x11, fail

    li   x7,  0x2800        # tag10 / set0
    ld   x10, 0(x7)         # MISS: fill W2; x10 = 0x22
    li   x11, 0x22
    bne  x10, x11, fail

    li   x8,  0x2C00        # tag11 / set0
    ld   x10, 0(x8)         # MISS: fill W3; PLRU→3'b000; x10 = 0x33
    li   x11, 0x33
    bne  x10, x11, fail

    li   x20, 3
    sb   x20, 16(x1)        # checkpoint 0x03 (all 4 ways valid, PLRU[0]=3'b000)

# ─── Phase 4: 5th tag in set0 → PLRU eviction ────────────────────────────────
# PLRU=3'b000: p[0]=0 → left pair LRU; p[1]=0 → victim=W0 (tag8)
phase4:
    li   x9,  0x3000        # tag12 / set0
    ld   x10, 0(x9)         # MISS: PLRU evicts W0 (tag8→tag12); x10 = 0x44
    li   x11, 0x44
    bne  x10, x11, fail

    li   x20, 4
    sb   x20, 16(x1)        # checkpoint 0x04 (W0 evicted, PLRU[0]=3'b011)

# ─── Phase 5: reload evicted tag8 + cold miss on independent set1 ─────────────
phase5:
    ld   x10, 0(x5)         # MISS: tag8 was evicted from W0; refill from Flash; x10 = 0x42
    li   x11, 0x42
    bne  x10, x11, fail

    li   x12, 0x2020        # tag8 / set1 (index=1, independent of set0)
    ld   x10, 0(x12)        # MISS: set1 cold; x10 = 0x99
    li   x11, 0x99
    bne  x10, x11, fail

    li   x20, 5
    sb   x20, 16(x1)        # checkpoint 0x05

# ─── Phase 6: warm-cache hits (no refill, verify still cached) ───────────────
phase6:
    ld   x10, 0(x12)        # HIT: set1/tag8 still in cache; x10 = 0x99
    li   x11, 0x99
    bne  x10, x11, fail

    ld   x10, 0(x6)         # HIT: set0/tag9 (W1) still valid; x10 = 0x11
    li   x11, 0x11
    bne  x10, x11, fail

    ld   x10, 0(x8)         # HIT: set0/tag11 (W3) still valid; x10 = 0x33
    li   x11, 0x33
    bne  x10, x11, fail

    li   x20, 6
    sb   x20, 16(x1)        # checkpoint 0x06

pass:
    li   x20, 0x55
    sb   x20, 16(x1)        # PASS
pass_loop:
    j    pass_loop

fail:
    li   x20, 0xFF
    sb   x20, 16(x1)        # FAIL
fail_loop:
    j    fail_loop

# ─── Flash data (D-Cache region: byte offset >= 0x2000) ──────────────────────
.org 0x2000
# set0 / tag8  –  cache line [0x2000:0x201F]
.quad 0x0000000000000042    # dw0: ld  → 0x42
.quad 0x00000000000000A0    # dw1: ld  → 0xA0 (intra-line hit)
.quad 0x00000000000000FF    # dw2: lb  → -1, lbu → 0xFF
.quad 0x0000000000001234    # dw3: lh/lhu/lw/lwu → 0x1234

.org 0x2020
# set1 / tag8  –  independent of set0 (index=1, same tag)
.quad 0x0000000000000099    # dw0: ld  → 0x99

.org 0x2400
# set0 / tag9
.quad 0x0000000000000011    # dw0: ld  → 0x11

.org 0x2800
# set0 / tag10
.quad 0x0000000000000022    # dw0: ld  → 0x22

.org 0x2C00
# set0 / tag11
.quad 0x0000000000000033    # dw0: ld  → 0x33

.org 0x3000
# set0 / tag12  –  5th access to set0 → PLRU victim = W0
.quad 0x0000000000000044    # dw0: ld  → 0x44
