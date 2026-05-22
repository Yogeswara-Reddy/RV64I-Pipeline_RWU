cmake_minimum_required(VERSION 3.20)
project(rv64i_regression LANGUAGES NONE)

# -------------------------------------------------
# Globale Roots
# -------------------------------------------------
set(PROJECT_ROOT ${CMAKE_SOURCE_DIR})
set(IP_ROOT ${PROJECT_ROOT}/../../ CACHE PATH "Root directory for shared IPs")

# -------------------------------------------------
# Simulator-Auswahl
#   cmake -B build -DSIMULATOR=xsim       (Default)
#   cmake -B build -DSIMULATOR=verilator
# -------------------------------------------------
set(SIMULATOR "xsim" CACHE STRING "Simulator-Backend: xsim | verilator")
set_property(CACHE SIMULATOR PROPERTY STRINGS xsim verilator)

# -------------------------------------------------
# Waveform-GUI  (nur Einzeltest sinnvoll!)
#   cmake -B build -DWAVES=ON
#   cmake --build build --target sim_<test>
#
#   NICHT für --target regression verwenden!
# -------------------------------------------------
option(WAVES "Waveform-Viewer öffnen (nur Einzeltest, nicht für Regression)" OFF)

if(WAVES)
    set(SIM_TARGET "waves")
    message(STATUS "WAVES=ON: Waveform GUI aktiv — nicht mit 'regression' kombinieren!")
else()
    set(SIM_TARGET "simulate")
endif()

message(STATUS "SIMULATOR = ${SIMULATOR}")
message(STATUS "SIM_TARGET = ${SIM_TARGET}")

# -------------------------------------------------
# Test-Liste
# -------------------------------------------------
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
    # Fix: kein Copy in den Source-Tree — ASM_FILE wird direkt übergeben
    add_custom_command(
        OUTPUT ${TEST_BUILD_DIR}/asm/rv64i.mem
        COMMAND ${CMAKE_COMMAND} -E make_directory ${TEST_BUILD_DIR}/asm
        COMMAND ${CMAKE_COMMAND}
                -DASM_FILE=${PROJECT_ROOT}/rv64Sim/${TEST}.asm
                -S ${PROJECT_ROOT}/rv64Sim
                -B ${TEST_BUILD_DIR}/asm
        COMMAND ${CMAKE_COMMAND}
                --build ${TEST_BUILD_DIR}/asm --target mem
        DEPENDS ${PROJECT_ROOT}/rv64Sim/${TEST}.asm
        COMMENT "Assembling ${TEST}"
    )

    # ---------------- SIM ----------------
    # Fix: kein Copy von tb_rv64i_<test>.sv in den Source-Tree — TB_FILE wird übergeben
    # SIMULATOR und SIM_TARGET (simulate|waves) werden weitergereicht
    add_custom_target(sim_${TEST}
        COMMAND ${CMAKE_COMMAND}
                -DPROJECT_ROOT=${PROJECT_ROOT}
                -DIP_ROOT=${IP_ROOT}
                -DRV64_MEM=${TEST_BUILD_DIR}/asm/rv64i.mem
                -DTB_FILE=${PROJECT_ROOT}/tb/tb_rv64i_${TEST}.sv
                -DSIMULATOR=${SIMULATOR}
                -S ${PROJECT_ROOT}/sim
                -B ${TEST_BUILD_DIR}/sim
        COMMAND ${CMAKE_COMMAND} --build ${TEST_BUILD_DIR}/sim --target ${SIM_TARGET}
        DEPENDS ${TEST_BUILD_DIR}/asm/rv64i.mem
        COMMENT "Simulating ${TEST} [${SIMULATOR}]"
    )

    add_dependencies(regression sim_${TEST})

endforeach()

# -------------------------------------------------
# Regression-Fehler sammeln
# Semicolons in CMake lists werden von der Shell als Befehlstrenner
# interpretiert → kommagetrennte Liste verwenden
# -------------------------------------------------
list(JOIN ASM_TESTS "," TESTS_CSV)
add_custom_target(collect_errors
    COMMAND ${CMAKE_COMMAND}
        -DPROJECT_ROOT=${PROJECT_ROOT}
        -DBUILD_ROOT=${CMAKE_BINARY_DIR}
        -DTESTS=${TESTS_CSV}
        -P ${PROJECT_ROOT}/collect_errors.cmake
    COMMENT "Collecting regression error files"
)

add_dependencies(collect_errors regression)
