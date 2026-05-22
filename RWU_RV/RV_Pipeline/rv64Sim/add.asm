.section .text
.global _start

_start:

    li x1, 5
    li x2, 7
    add x3, x1, x2

    li x4, 12
    bne x3, x4, fail

pass:
    li x5, 0x1000
    li x6, 1
    sd x6, 0(x5)

loop:
    j loop

fail:
    li x5, 0x1008
    li x6, 0
    sd x6, 0(x5)

    j fail
