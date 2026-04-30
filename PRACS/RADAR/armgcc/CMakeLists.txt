INCLUDE(CMakeForceCompiler)

SET(CMAKE_SYSTEM_NAME Generic)
CMAKE_MINIMUM_REQUIRED(VERSION 3.13)
project(radar_sensor C CXX ASM)

SET(SDK_DIR "/Users/andre_apl/Coding/KL25Z/SDK_2_2_0_FRDM-KL25Z")

ENABLE_LANGUAGE(ASM)

SET(CMAKE_STATIC_LIBRARY_PREFIX)
SET(CMAKE_STATIC_LIBRARY_SUFFIX)
SET(CMAKE_EXECUTABLE_LIBRARY_PREFIX)
SET(CMAKE_EXECUTABLE_LIBRARY_SUFFIX)

SET(ProjDirPath ${CMAKE_CURRENT_SOURCE_DIR})

# ── Compiler flags ─────────────────────────────────────────────────────────────
SET(COMMON_FLAGS "-mcpu=cortex-m0plus -mthumb -mfloat-abi=soft -fno-common -ffunction-sections -fdata-sections -ffreestanding -fno-builtin -mapcs -Wall")

SET(CMAKE_ASM_FLAGS_DEBUG   "${CMAKE_ASM_FLAGS_DEBUG}   -DDEBUG -D__STARTUP_CLEAR_BSS -g -flto ${COMMON_FLAGS} -std=gnu99")
SET(CMAKE_ASM_FLAGS_RELEASE "${CMAKE_ASM_FLAGS_RELEASE} -D__STARTUP_CLEAR_BSS -flto ${COMMON_FLAGS} -std=gnu99")

SET(CMAKE_C_FLAGS_DEBUG   "${CMAKE_C_FLAGS_DEBUG}   -DDEBUG -DCPU_MKL25Z128VLK4 -DFRDM_KL25Z -DFREEDOM -DPRINTF_FLOAT_ENABLE=0 -DSCANF_FLOAT_ENABLE=0 -DPRINTF_ADVANCED_ENABLE=0 -DSCANF_ADVANCED_ENABLE=0 -g -O0 -flto -MMD -MP ${COMMON_FLAGS} -std=gnu99")
SET(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -DNDEBUG -DCPU_MKL25Z128VLK4 -DFRDM_KL25Z -DFREEDOM -DPRINTF_FLOAT_ENABLE=0 -DSCANF_FLOAT_ENABLE=0 -DPRINTF_ADVANCED_ENABLE=0 -DSCANF_ADVANCED_ENABLE=0 -Os -flto -MMD -MP ${COMMON_FLAGS} -std=gnu99")

SET(LINKER_FLAGS "-flto ${COMMON_FLAGS} --specs=nano.specs --specs=nosys.specs -Xlinker --gc-sections -Xlinker -static -Xlinker -z -Xlinker muldefs")
SET(CMAKE_EXE_LINKER_FLAGS_DEBUG   "${CMAKE_EXE_LINKER_FLAGS_DEBUG}   -g ${LINKER_FLAGS}")
SET(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} ${LINKER_FLAGS}")

# ── Include paths ──────────────────────────────────────────────────────────────
include_directories(${SDK_DIR}/CMSIS/Include)
include_directories(${SDK_DIR}/devices)
include_directories(${SDK_DIR}/devices/MKL25Z4)
include_directories(${SDK_DIR}/devices/MKL25Z4/drivers)
include_directories(${SDK_DIR}/devices/MKL25Z4/utilities)
include_directories(${ProjDirPath}/..)

# ── Sources ────────────────────────────────────────────────────────────────────
add_executable(radar_sensor.elf
    # Startup & system
    "${SDK_DIR}/devices/MKL25Z4/gcc/startup_MKL25Z4.S"
    "${SDK_DIR}/devices/MKL25Z4/system_MKL25Z4.c"
    "${SDK_DIR}/devices/MKL25Z4/system_MKL25Z4.h"
    # SDK drivers (needed by board/clock/pin_mux)
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_common.c"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_common.h"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_clock.c"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_clock.h"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_gpio.c"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_gpio.h"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_port.h"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_smc.c"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_smc.h"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_flash.c"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_flash.h"
    # Debug console (required by board.c even though we don't call it)
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_lpsci.c"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_lpsci.h"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_uart.c"
    "${SDK_DIR}/devices/MKL25Z4/drivers/fsl_uart.h"
    "${SDK_DIR}/devices/MKL25Z4/utilities/fsl_debug_console.c"
    "${SDK_DIR}/devices/MKL25Z4/utilities/fsl_debug_console.h"
    # Board support (copied from tpm_delay — pin_mux sets PTA1/2 = UART0)
    "${ProjDirPath}/../board.c"
    "${ProjDirPath}/../board.h"
    "${ProjDirPath}/../pin_mux.c"
    "${ProjDirPath}/../pin_mux.h"
    "${ProjDirPath}/../clock_config.c"
    "${ProjDirPath}/../clock_config.h"
    # Application
    "${ProjDirPath}/../radar_sensor.c"
)

# ── Linker script ──────────────────────────────────────────────────────────────
set(CMAKE_EXE_LINKER_FLAGS_DEBUG   "${CMAKE_EXE_LINKER_FLAGS_DEBUG}   -T${ProjDirPath}/MKL25Z128xxx4_flash.ld -static")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} -T${ProjDirPath}/MKL25Z128xxx4_flash.ld -static")

# ── Link libraries ─────────────────────────────────────────────────────────────
TARGET_LINK_LIBRARIES(radar_sensor.elf -Wl,--start-group)
target_link_libraries(radar_sensor.elf debug   m c gcc nosys)
target_link_libraries(radar_sensor.elf optimized m c gcc nosys)
TARGET_LINK_LIBRARIES(radar_sensor.elf -Wl,--end-group)

# ── Post-build: create .bin for drag-and-drop flashing onto KL25Z ─────────────
add_custom_command(TARGET radar_sensor.elf POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O binary
            $<TARGET_FILE:radar_sensor.elf>
            $<TARGET_FILE_DIR:radar_sensor.elf>/radar_sensor.bin
    COMMENT "Creating radar_sensor.bin for KL25Z drag-and-drop flash"
)
