#PROJECT = allinstructions
#PROJECT = readgpioid
#PROJECT = instr02loadhalf
#PROJECT = instr01loadbyte
#PROJECT = instr03loadword
#PROJECT = instr04loadbyteu
#PROJECT = instr05loadhalfu
#PROJECT = instr99loadimem
#PROJECT = instr19add
PROJECT = add
#PROJECT = instr51csrrw
#PROJECT = rv64i

.SUFFIXES: .o .asm .c

# git clone https://github.com/riscv/riscv-gnu-toolchain
CC=/opt/riscv/bin/riscv64-unknown-linux-gnu-gcc
AS=/opt/riscv/bin/riscv64-unknown-linux-gnu-as
CP=/opt/riscv/bin/riscv64-unknown-linux-gnu-objcopy
LD=/opt/riscv/bin/riscv64-unknown-linux-gnu-ld

# sudo apt install gcc-riscv64-unknown-elf
#CC=/usr/bin/riscv64-unknown-elf-gcc
#AS=/usr/bin/riscv64-unknown-elf-as
#CP=/usr/bin/riscv64-unknown-elf-objcopy
#LD=/usr/bin/riscv64-unknown-elf-ld

CPFLAGS = -O verilog --verilog-data-width 4
LDFLAGS = -b elf64-littleriscv
ASFLAGS = -march=rv64i_zicsr -mlittle-endian -g

all: verilog

# sed: replace spaces with CR
# sed: delete ^M
# sed: delete first line
verilog: $(PROJECT)
	@echo "Doing: $(CP) $(PROJECT) $(CPFLAGS) $(PROJECT).v"
	$(CP) $(PROJECT) $(CPFLAGS) $(PROJECT).v
	sed -i 's/ /\n/g' $(PROJECT).v
	sed -i 's/\r//g' $(PROJECT).v
	sed -i '1d' $(PROJECT).v
	cp -rf $(PROJECT).v ../sim/riscvtest_tb_$(PROJECT).mem
	cp -rf $(PROJECT).v ../sim/riscvtest.mem

$(PROJECT): $(PROJECT).o
	@echo "Doing: $(LD) $(LDFLAGS) -o $(PROJECT) $(PROJECT).o"
	$(LD) $(LDFLAGS) -o $(PROJECT) $(PROJECT).o

.asm.o:
	@echo "Doing: $(AS) $(ASFLAGS) -o $*.o $*.asm -al=$*.lst"
	$(AS) $(ASFLAGS) -o $*.o $*.asm -al=$*.lst

.phony : clean
clean:
	@echo "Make clean"
	rm -f *.o
	rm -f *.s
	rm -f *.lst
	rm -f *.hex
	rm -f $(PROJECT)
