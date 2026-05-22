# RISC-V Assembly              Description
.global _start


	# GPIO is at address 64'h00000001_00000000 - 64'h00000001_0000005F
	# Our debug output is at 0x0000_0001_0000_0010
_start: lui  x2, 0x10000       # set GPIO address
	slli x2, x2, 4         # generate GPIO base address
	# set data
	addi x10, x0, 0x1D     # data is 29
	csrrw x20, 0x305, x21
	# print
	sb   x10, 16(x2)
	### done
        jal  x0, done          # jump to end
done:   beq  x2, x2, done      # 50 infinite loop
