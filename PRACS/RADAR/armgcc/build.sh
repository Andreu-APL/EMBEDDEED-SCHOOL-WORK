#!/bin/sh
# Build the RADAR firmware for KL25Z.
# Usage:
#   ./build.sh           → release build (optimised)
#   ./build.sh debug     → debug build   (symbols, no optimisation)
#
# Output (inside armgcc/):
#   release/radar_sensor.elf  — ELF with debug info (GDB / J-Link)
#   release/radar_sensor.bin  — raw binary for drag-and-drop flashing
#
# To flash:
#   1. Connect KL25Z via the SDA (upper) USB port.
#   2. A drive called "FRDM-KL25Z" appears in Finder.
#   3. Drag radar_sensor.bin onto that drive — the board reboots automatically.

set -e

PRESET="${1:-release}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARMGCC_DIR="/Applications/MCUXpressoIDE_25.6.136/ide/tools"
NINJA="$ARMGCC_DIR/../../../plugins/com.nxp.mcuxpresso.tools.macosx_25.6.0.202501151204/tools/bin/ninja"

# Fall back to system ninja if the IDE bundled one isn't found
if [ ! -f "$NINJA" ]; then
    NINJA="$(command -v ninja 2>/dev/null || true)"
fi
if [ -z "$NINJA" ]; then
    echo "ERROR: ninja not found. Install via: brew install ninja"
    exit 1
fi

cd "$SCRIPT_DIR"

export ARMGCC_DIR

echo "==> Configuring (preset: $PRESET)…"
cmake --preset "$PRESET"

echo "==> Building…"
"$NINJA"

BIN_PATH="${PRESET}/radar_sensor.bin"
if [ -f "$BIN_PATH" ]; then
    SIZE=$(wc -c < "$BIN_PATH" | tr -d ' ')
    echo ""
    echo "==> Done! Binary size: ${SIZE} bytes"
    echo "    Flash: $SCRIPT_DIR/$BIN_PATH"
    echo ""
    echo "    To flash: copy that .bin to the FRDM-KL25Z USB drive in Finder."
else
    echo "Build finished but .bin not found — check CMakeLists post-build step."
    exit 1
fi
