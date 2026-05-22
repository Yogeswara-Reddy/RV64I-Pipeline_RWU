# RISC-V Assembly              Description
.global _start

	# GPIO is at address 64'h00000001_00000000 - 64'h00000001_0000005F
	# Our debug output is at 0x0000_0001_0000_0010
_start: addi x2, x0, 0x100     # GPIO ID registers address, x2=0x100
	slli x2, x2, 24        # generate GPIO base address, x2=0x00000001_00000000
	# set GPIO direction
	addi x4, x0, 0x80      # bit 7 is input, rest is output
	sd   x4, 8(x2)         # write content of x4 to GPIO-direction-register
	# get GPIO peripheral ID
	ld   x3, 0(x2)         # load GPIO ID to x3 (ID-Reg-Addr=0x00000001_00000000)
	# CSR Zeugs
	addi x21, x0, -1       # all '1' to x21
	csrrw x20, mie, x21
	# delay
	addi x22, x0, 1
	addi x22, x22, 1
	addi x22, x22, 1
	addi x22, x22, 1
	addi x22, x22, 1
	addi x22, x22, 1
	addi x22, x22, 1
	addi x22, x22, 1
	addi x22, x22, 1
	addi x22, x22, 1
	# print
	sd   x3, 16(x2)        # write LSB of GPIO ID to GPIO (Data reg) - print it
	# done
        jal  x0, done          # jump to end
done:   beq  x2, x2, done      # 50 infinite loop
# -----------------------------
# Interrupt Service Routine
# -----------------------------
	.section .text
	.org 0x7F00
isr:
	sd x21, 40(x2) # clear IRQ, IRQSC
	sd x0, 40(x2)  # clear IRQ, IRQSC
	mret
