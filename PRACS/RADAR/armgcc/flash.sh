#!/bin/sh
# Flash radar_sensor.elf onto the KL25Z via P&E OpenSDA (no Finder needed).
# Uses the GDB server bundled inside MCUXpressoIDE — no extra tools required.
#
# Usage:
#   ./flash.sh              → flashes release build
#   ./flash.sh debug        → flashes debug build

set -e

BUILD="${1:-release}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ELF="$SCRIPT_DIR/$BUILD/radar_sensor.elf"

PE_PLUGIN_DIR="/Applications/MCUXpressoIDE_25.6.136/ide/plugins/com.pemicro.debug.gdbjtag.pne_6.0.3.202506131845/osx"
PEGDB="$PE_PLUGIN_DIR/pegdbserver_console"
GDB="/Applications/MCUXpressoIDE_25.6.136/ide/plugins/com.pemicro.debug.gdbjtag.pne_6.0.3.202506131845/osx/gdb/arm-none-eabi-gdb"

if [ ! -f "$ELF" ]; then
    echo "ERROR: $ELF not found. Run ./build.sh $BUILD first."
    exit 1
fi

echo "==> Starting P&E GDB server…"
"$PEGDB" \
    -device=NXP_KL2x_KL25Z128M4 \
    -interface=OPENSDA \
    -startserver \
    -singlesession \
    -serverport=7224 \
    -speed=5000 &
PEGDB_PID=$!

# Give the server a moment to initialise
sleep 2

echo "==> Connecting GDB and flashing $BUILD/radar_sensor.elf…"
"$GDB" --batch \
    "$ELF" \
    -ex "set remotetimeout 30" \
    -ex "target remote :7224" \
    -ex "monitor reset halt" \
    -ex "load" \
    -ex "monitor reset run" \
    -ex "disconnect" \
    -ex "quit"

# Kill the server in case it didn't exit on its own
kill "$PEGDB_PID" 2>/dev/null || true

echo ""
echo "==> Flash complete. Board is running."
