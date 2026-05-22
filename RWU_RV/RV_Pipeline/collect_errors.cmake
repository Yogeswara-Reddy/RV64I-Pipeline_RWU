# -------------------------------------------------
# collect_errors.cmake
# -------------------------------------------------

foreach(var PROJECT_ROOT BUILD_ROOT TESTS)
    if(NOT DEFINED ${var})
        message(FATAL_ERROR "${var} not set")
    endif()
endforeach()

set(OUT_FILE ${PROJECT_ROOT}/regression.txt)

file(WRITE ${OUT_FILE} "=== RV64I REGRESSION REPORT ===\n")

# TESTS kommt als kommagetrennte Liste (Semikolons würden die Shell als
# Befehlstrenner interpretieren). Hier in eine CMake-Liste umwandeln.
string(REPLACE "," ";" TEST_LIST "${TESTS}")
foreach(TEST ${TEST_LIST})
    set(ERR_FILE ${BUILD_ROOT}/${TEST}/sim/error.txt)

    file(APPEND ${OUT_FILE} "\n--- ${TEST} ---\n")

    if(EXISTS ${ERR_FILE})
        file(READ ${ERR_FILE} CONTENTS)
        file(APPEND ${OUT_FILE} "${CONTENTS}")
    else()
        file(APPEND ${OUT_FILE} "(no errors)\n")
    endif()
endforeach()

message(STATUS "Regression report: ${OUT_FILE}")
