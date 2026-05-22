cmake_minimum_required(VERSION 3.20)
project(rv64i_asm LANGUAGES ASM)

# -------------------------------------------------
# Tools (ABSOLUT erlaubt)
# -------------------------------------------------
set(RISCV_PREFIX /opt/riscv/bin/riscv64-unknown-linux-gnu)
set(AS       ${RISCV_PREFIX}-as)
set(LD       ${RISCV_PREFIX}-ld)
set(OBJCOPY  ${RISCV_PREFIX}-objcopy)

# -------------------------------------------------
# Inputs / Outputs
# -------------------------------------------------
set(ASM_FILE ${CMAKE_CURRENT_SOURCE_DIR}/rv64i.asm)
set(OBJ      ${CMAKE_CURRENT_BINARY_DIR}/rv64i.o)
set(ELF      ${CMAKE_CURRENT_BINARY_DIR}/rv64i.elf)
set(MEM      ${CMAKE_CURRENT_BINARY_DIR}/rv64i.mem)

# -------------------------------------------------
# ASM → OBJ
# -------------------------------------------------
add_custom_command(
    OUTPUT ${OBJ}
    COMMAND ${AS}
            -march=rv64i_zicsr
            -mlittle-endian
            -g
            -o ${OBJ}
            ${ASM_FILE}
    DEPENDS ${ASM_FILE}
    COMMENT "Assembling ${ASM_FILE}"
)

# -------------------------------------------------
# OBJ → ELF
# -------------------------------------------------
add_custom_command(
    OUTPUT ${ELF}
    COMMAND ${LD}
            -b elf64-littleriscv
            -o ${ELF}
            ${OBJ}
    DEPENDS ${OBJ}
    COMMENT "Linking ELF"
)

# -------------------------------------------------
# ELF → MEM
# sed: replace spaces with CR
# sed: delete ^M
# sed: delete first line
# -------------------------------------------------
add_custom_command(
    OUTPUT ${MEM}
    COMMAND ${OBJCOPY}
            -O verilog
            --verilog-data-width 4
            ${ELF}
            ${MEM}
    COMMAND sed -i 's/ /\\n/g' ${MEM}
    COMMAND sed -i 's/\r//g' ${MEM}
    COMMAND sed -i '1d' ${MEM}
    DEPENDS ${ELF}
    COMMENT "Generating Verilog MEM"
)

add_custom_target(mem ALL DEPENDS ${MEM})

# Export für Simulation
set(RV64_MEM ${MEM} CACHE FILEPATH "RV64 memory image")
