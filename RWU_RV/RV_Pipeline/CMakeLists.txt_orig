cmake_minimum_required(VERSION 3.20)
project(rv64i_regression LANGUAGES NONE)

# -------------------------------------------------
# Globale Roots
# - PROJECT_ROOT = ./
# - IP_ROOT = ./../../
# - TEST_BUILD_DIR = ./build/readgpioid (Where does CMAKE_BINARY_DIR come from?)
# -------------------------------------------------
set(PROJECT_ROOT ${CMAKE_SOURCE_DIR}) # 
set(IP_ROOT ${PROJECT_ROOT}/../../ CACHE PATH "Root directory for shared IPs")

set(ASM_TESTS
    instr99scantest
    instr99loadimem
    readgpioid
    instr01loadbyte
    instr02loadhalf
    instr03loadword
    instr04loadbyteu
    instr05loadhalfu
    instr06addi
    instr19add
    instr07slli
    instr29lui
)

add_custom_target(regression)

foreach(TEST ${ASM_TESTS})

    set(TEST_BUILD_DIR ${CMAKE_BINARY_DIR}/${TEST})

    # ---------------- ASM ----------------
    add_custom_command(
        OUTPUT ${TEST_BUILD_DIR}/asm/rv64i.mem
        COMMAND ${CMAKE_COMMAND} -E make_directory ${TEST_BUILD_DIR}/asm
        COMMAND ${CMAKE_COMMAND} -E copy
                ${PROJECT_ROOT}/rv64Sim/${TEST}.asm
                ${PROJECT_ROOT}/rv64Sim/rv64i.asm
        COMMAND ${CMAKE_COMMAND}
                -S ${PROJECT_ROOT}/rv64Sim
                -B ${TEST_BUILD_DIR}/asm
        COMMAND ${CMAKE_COMMAND}
                --build ${TEST_BUILD_DIR}/asm --target mem
        DEPENDS ${PROJECT_ROOT}/rv64Sim/${TEST}.asm
        COMMENT "Assembling ${TEST}"
    )

    # ---------------- SIM ----------------
    add_custom_target(sim_${TEST}
        COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_ROOT}/tb/tb_rv64i_${TEST}.sv ${PROJECT_ROOT}/tb/tb_rv64i.sv
        COMMAND ${CMAKE_COMMAND}
                -DPROJECT_ROOT=${PROJECT_ROOT}
                -DIP_ROOT=${IP_ROOT}
                -DRV64_MEM=${TEST_BUILD_DIR}/asm/rv64i.mem
                -S ${PROJECT_ROOT}/sim
                -B ${TEST_BUILD_DIR}/sim
        COMMAND ${CMAKE_COMMAND} --build ${TEST_BUILD_DIR}/sim --target simulate
        #COMMAND ${CMAKE_COMMAND} --build ${TEST_BUILD_DIR}/sim --target waves
        DEPENDS ${TEST_BUILD_DIR}/asm/rv64i.mem
        COMMENT "Simulating ${TEST}"
    )

    add_dependencies(regression sim_${TEST})

endforeach()


# -------------------------------------------------
# Collect regression errors
# -------------------------------------------------
string(REPLACE " " ";" TESTS_LIST "${ASM_TESTS}")
add_custom_target(collect_errors
    COMMAND ${CMAKE_COMMAND}
        -DPROJECT_ROOT=${PROJECT_ROOT}
        -DBUILD_ROOT=${CMAKE_BINARY_DIR}
        -DTESTS="${TESTS_LIST}"
        -P ${PROJECT_ROOT}/collect_errors.cmake
    COMMENT "Collecting regression error files"
)

add_dependencies(collect_errors regression)
