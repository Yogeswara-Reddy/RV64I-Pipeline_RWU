# RISC-V Assembly              Description
.global _start

_start: addi x2, x0, 0x100     # GPIO ID registers address
	slli x2, x2, 24        # load GPIO base address (shift it one byte left)
        # add 2 positives without overflow
	addi x5, x0, 4         # load x5 with 4
	addi x6, x5, 2         # Test: addi - 4+2=6
	# prepare print
	addi x10, x6, 0        # mov x10, x6 - functions argument -> GPIO
        # print
	sb   x10, 16(x2)        # write LSB of GPIO ID to GPIO
	### done
        jal  x0, done          # jump to end
done:   beq  x2, x2, done      # 50 infinite loop
