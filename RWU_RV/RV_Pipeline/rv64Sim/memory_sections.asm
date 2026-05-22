# memory_sections.asm
#
# Demonstrates all six memory sections of the RWU-RV64I Harvard system:
#
#   .text    This code, fetched from Flash via I-Cache at PC=0.
#            The instruction bus is independent of the data bus.
#
#   .rodata  Constant table at Flash addr 0x2000 (D-Cache region).
#            Loaded read-only via ld; never stored to.
#
#   .data    Initialised variables at scratchpad VMA 0x0100.
#            The binary image lives at Flash LMA 0x3000; startup
#            copies it word-by-word into scratchpad via D-Cache ld.
#
#   .bss     Uninitialised array in scratchpad (follows .data).
#            Startup zeroes it before the test begins.
#
#   stack    LIFO area at the top of scratchpad (0x1FF8 downward).
#            Standard RISC-V ABI: sp decrements on entry, restores on exit.
#
#   heap     Dynamic area in scratchpad above .bss (_heap_start = _bss_end).
#            A simple bump-pointer allocator is demonstrated inline.
#
# GPIO checkpoints (base 0x1_0000_0000, checkpoint register at +16):
#   0x01  .data variables hold correct initialised values
#   0x02  .bss array is all-zero after startup zero-loop
#   0x03  .rodata constant table readable via D-Cache
#   0x04  stack push / computation / pop round-trip correct
#   0x05  heap write / read-back correct
#   0x55  PASS  /  0xFF  FAIL

.section .text
.global _start

# ─── Startup: copy .data from Flash and zero .bss ────────────────────────────
_start:
    # Stack pointer = scratchpad top (0x1FF8)
    li   x2,  0x1FF8

    # GPIO base = 0x1_0000_0000  (addi loads 0x100; slli shifts left 24)
    addi x1,  x0,  0x100
    slli x1,  x1,  24

    # Copy .data: src = _data_lma (Flash, D-Cache region, LMA 0x3000)
    #             dst = _data_start (scratchpad VMA 0x0100)
    la   x3,  _data_lma
    la   x4,  _data_start
    la   x5,  _data_end
    j    copy_check
copy_loop:
    ld   x6,  0(x3)        # load 8 bytes from Flash via D-Cache
    sd   x6,  0(x4)        # store to scratchpad
    addi x3,  x3,  8
    addi x4,  x4,  8
copy_check:
    bltu x4,  x5,  copy_loop

    # Zero .bss: from _bss_start to _bss_end (all in scratchpad)
    la   x4,  _bss_start
    la   x5,  _bss_end
    j    bss_check
bss_loop:
    sd   x0,  0(x4)
    addi x4,  x4,  8
bss_check:
    bltu x4,  x5,  bss_loop

# ─── Phase 1: verify .data was correctly initialised ─────────────────────────
# .data in scratchpad: my_var=0x42, my_count=10 (copied from Flash LMA 0x3000)
phase1:
    la   x10, my_var
    ld   x10, 0(x10)
    li   x11, 0x42
    bne  x10, x11, fail

    la   x10, my_count
    ld   x10, 0(x10)
    li   x11, 10
    bne  x10, x11, fail

    li   x20, 1
    sb   x20, 16(x1)       # checkpoint 0x01

# ─── Phase 2: verify .bss was zeroed by startup ───────────────────────────────
# .bss in scratchpad: my_array[4 × 8 bytes] must be all-zero
phase2:
    la   x10, my_array
    li   x12, 0
bss_verify:
    ld   x11, 0(x10)
    bne  x11, x0,  fail
    addi x10, x10, 8
    addi x12, x12, 1
    li   x13, 4
    blt  x12, x13, bss_verify

    li   x20, 2
    sb   x20, 16(x1)       # checkpoint 0x02

# ─── Phase 3: read .rodata via D-Cache ───────────────────────────────────────
# .rodata at Flash 0x2000: entries 0x11, 0x22, 0x33, 0x44
phase3:
    la   x10, const_table

    ld   x11, 0(x10)
    li   x12, 0x11
    bne  x11, x12, fail

    ld   x11, 8(x10)
    li   x12, 0x22
    bne  x11, x12, fail

    ld   x11, 16(x10)
    li   x12, 0x33
    bne  x11, x12, fail

    ld   x11, 24(x10)
    li   x12, 0x44
    bne  x11, x12, fail

    li   x20, 3
    sb   x20, 16(x1)       # checkpoint 0x03

# ─── Phase 4: stack — allocate frame, save/restore registers ─────────────────
# Demonstrate standard RISC-V prologue/epilogue; sp grows downward
phase4:
    addi x2,  x2,  -16    # allocate 16-byte frame
    sd   x1,  8(x2)       # save ra (holds GPIO base — used as canary)
    li   x30, 0xBEEF
    sd   x30, 0(x2)       # save arbitrary value on stack

    # work between push and pop
    li   x10, 300
    li   x11, 42
    sub  x10, x10, x11    # x10 = 258 (result not checked; stack integrity is the test)

    ld   x30, 0(x2)       # restore from stack
    ld   x1,  8(x2)       # restore ra = GPIO base
    addi x2,  x2,  16     # deallocate frame

    li   x11, 0xBEEF
    bne  x30, x11, fail   # canary must survive push/pop

    li   x20, 4
    sb   x20, 16(x1)      # checkpoint 0x04

# ─── Phase 5: heap — bump-allocate a slot and verify write/read-back ─────────
# _heap_start = _bss_end (linker-computed), points into scratchpad
phase5:
    la   x10, _heap_start  # first free heap byte
    li   x11, 0xCAFE
    sd   x11, 0(x10)       # write to heap slot 0
    ld   x12, 0(x10)       # read back
    bne  x12, x11, fail

    li   x20, 5
    sb   x20, 16(x1)       # checkpoint 0x05

# ─── Pass / Fail ──────────────────────────────────────────────────────────────
pass:
    li   x20, 0x55
    sb   x20, 16(x1)
pass_loop:
    j    pass_loop

fail:
    li   x20, 0xFF
    sb   x20, 16(x1)
fail_loop:
    j    fail_loop

# ─── .rodata: constant table in Flash D-Cache region (linker places at 0x2000)
.section .rodata
const_table:
    .quad 0x0000000000000011    # entry 0 — read in phase 3
    .quad 0x0000000000000022    # entry 1
    .quad 0x0000000000000033    # entry 2
    .quad 0x0000000000000044    # entry 3

# ─── .data: initialised variables (linker places image at Flash LMA 0x3000,
#            startup copies to scratchpad VMA 0x0100)
.section .data
my_var:
    .quad 0x42                  # test pattern; verified in phase 1
my_count:
    .quad 10                    # counter seed; verified in phase 1

# ─── .bss: uninitialised scratchpad storage (NOLOAD, zeroed by startup code)
.section .bss
my_array:
    .zero 32                    # 4 × 8 bytes — must be zero in phase 2
heap_ptr:
    .zero 8                     # illustrates .bss layout; not used by test logic
