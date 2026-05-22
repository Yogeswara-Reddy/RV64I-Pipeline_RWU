# -------------------------------------------------
# collect_errors.cmake
# -------------------------------------------------

if(NOT DEFINED PROJECT_ROOT)
    message(FATAL_ERROR "PROJECT_ROOT not set")
endif()

if(NOT DEFINED BUILD_ROOT)
    message(FATAL_ERROR "BUILD_ROOT not set")
endif()

if(NOT DEFINED TESTS)
    message(FATAL_ERROR "TESTS not set")
endif()

set(OUT_FILE ${PROJECT_ROOT}/regression.txt)

file(WRITE ${OUT_FILE} "=== RV64I REGRESSION REPORT ===\n")

string(REPLACE " " ";" TEST_LIST "${TESTS}")

foreach(TEST ${TEST_LIST})
    set(ERR_FILE ${BUILD_ROOT}/${TEST}/sim/error.txt)
    message("xxx ${BUILD_ROOT}/${TEST}/sim/error.txt xxx")

    file(APPEND ${OUT_FILE} "\n--- ${TEST} ---\n")

    if(EXISTS ${ERR_FILE})
        file(READ ${ERR_FILE} CONTENTS)
        file(APPEND ${OUT_FILE} "${CONTENTS}")
    else()
        file(APPEND ${OUT_FILE} "(no errors)\n")
	message("xxx File not exists xxx")
    endif()
endforeach()
