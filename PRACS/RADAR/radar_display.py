"""
Radar Display — reads UART data from KL25Z and renders a live 2D radar.

Expected serial protocol (one line per measurement):
    ANGLE,DISTANCE\n
    - ANGLE    : integer, 0–179 degrees (servo sweep)
    - DISTANCE : integer, centimeters (ultrasonic sensor reading)
    - Example  : "90,45\n"

Special values:
    - DISTANCE == 0 or DISTANCE > MAX_RANGE_CM  →  no object detected
"""

import sys
import math
import collections
import threading
import serial
import serial.tools.list_ports
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.animation import FuncAnimation

# ── Configuration ─────────────────────────────────────────────────────────────
BAUD_RATE    = 9600
MAX_RANGE_CM = 200       # radar display radius in cm
SWEEP_TRAIL  = 5         # degrees of fading green sweep trail behind the beam
FADE_STEPS   = 60        # how many frames an echo dot stays before fading out
DEMO_MODE    = False     # set True to run without hardware (simulated data)
# ──────────────────────────────────────────────────────────────────────────────


def pick_serial_port() -> str:
    """Return the first available serial port, or ask the user to choose."""
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("No serial ports found. Running in DEMO_MODE.")
        return None
    if len(ports) == 1:
        print(f"Using port: {ports[0].device}")
        return ports[0].device
    print("Available serial ports:")
    for i, p in enumerate(ports):
        print(f"  [{i}] {p.device}  —  {p.description}")
    while True:
        try:
            idx = int(input("Select port number: "))
            return ports[idx].device
        except (ValueError, IndexError):
            print("Invalid selection, try again.")


class RadarData:
    """Thread-safe store for the latest measurement from the serial reader."""

    def __init__(self):
        self._lock = threading.Lock()
        self.current_angle = 0
        # dict: angle (int) → (distance_cm, frame_added)
        self.echoes: dict[int, tuple[float, int]] = {}
        self.frame = 0

    def update(self, angle: int, distance: float):
        with self._lock:
            self.current_angle = angle
            if 0 < distance <= MAX_RANGE_CM:
                self.echoes[angle] = (distance, self.frame)

    def tick(self):
        """Advance frame counter and expire old echoes."""
        with self._lock:
            self.frame += 1
            expired = [a for a, (_, f) in self.echoes.items()
                       if self.frame - f > FADE_STEPS]
            for a in expired:
                del self.echoes[a]

    def snapshot(self):
        with self._lock:
            return self.current_angle, dict(self.echoes), self.frame


def serial_reader(port: str, baud: int, data: RadarData):
    """Runs in a background thread — reads lines and feeds RadarData."""
    try:
        with serial.Serial(port, baud, timeout=1) as ser:
            print(f"Serial open on {port} @ {baud}")
            while True:
                raw = ser.readline().decode("ascii", errors="ignore").strip()
                if "," not in raw:
                    continue
                parts = raw.split(",")
                if len(parts) != 2:
                    continue
                try:
                    angle    = int(parts[0])
                    distance = float(parts[1])
                    if 0 <= angle <= 179:
                        data.update(angle, distance)
                except ValueError:
                    continue
    except serial.SerialException as e:
        print(f"Serial error: {e}")


def demo_reader(data: RadarData):
    """Simulates a servo sweep for testing without hardware."""
    import time
    angle = 0
    direction = 1
    while True:
        # fake object cluster around 60° and 120°
        if 55 <= angle <= 65:
            dist = 80 + 10 * math.sin(math.radians(angle * 4))
        elif 115 <= angle <= 130:
            dist = 130 + 15 * math.cos(math.radians(angle * 3))
        else:
            dist = 0
        data.update(angle, dist)
        angle += direction
        if angle >= 179:
            direction = -1
        elif angle <= 0:
            direction = 1
        time.sleep(0.02)


def build_radar_figure():
    """Create and style the matplotlib polar figure."""
    matplotlib.rcParams["toolbar"] = "None"
    fig = plt.figure(figsize=(8, 6), facecolor="#0a0a0a")
    fig.canvas.manager.set_window_title("KL25Z Ultrasonic Radar")

    ax = fig.add_subplot(111, polar=True)
    ax.set_facecolor("#0a0a0a")

    # Half-circle: 0° (right/east) → π (left/west), displayed on top half
    ax.set_thetamin(0)
    ax.set_thetamax(180)
    ax.set_theta_direction(-1)       # sweep left-to-right like a real radar
    ax.set_theta_offset(0)

    ax.set_ylim(0, MAX_RANGE_CM)
    ax.set_rorigin(-MAX_RANGE_CM * 0.05)

    # Range rings
    ring_vals = np.linspace(0, MAX_RANGE_CM, 5)[1:]
    ax.set_yticks(ring_vals)
    ax.set_yticklabels([f"{int(r)}cm" for r in ring_vals],
                       color="#00aa44", fontsize=7)
    ax.yaxis.set_tick_params(pad=2)

    # Angle grid lines every 30°
    ax.set_xticks(np.radians(np.arange(0, 181, 30)))
    ax.set_xticklabels(
        [f"{a}°" for a in range(0, 181, 30)],
        color="#00aa44", fontsize=8
    )

    ax.grid(color="#003a18", linewidth=0.5, linestyle="--")
    ax.spines["polar"].set_color("#003a18")

    return fig, ax


def make_artists(ax):
    """Create and return all mutable plot artists."""
    # Sweep beam — a wedge-shaped line collection (drawn as filled polygon)
    sweep_line, = ax.plot([], [], color="#00ff55", linewidth=2, zorder=5)

    # Sweep trail — fading sector patch (redrawn each frame)
    trail_patch = [None]

    # Echo scatter plot
    echo_scatter = ax.scatter([], [], s=30, c=[], cmap="Greens",
                              vmin=0, vmax=1, zorder=6)

    # Status text
    status_text = ax.text(
        0.5, -0.08, "Waiting for data…",
        transform=ax.transAxes,
        ha="center", va="top",
        color="#00ff55", fontsize=9,
        fontfamily="monospace"
    )

    return sweep_line, trail_patch, echo_scatter, status_text


def update_frame(_, ax, data: RadarData,
                 sweep_line, trail_patch, echo_scatter, status_text):
    """FuncAnimation callback — redraws artists from latest RadarData."""
    data.tick()
    current_angle, echoes, frame = data.snapshot()

    angle_rad = math.radians(current_angle)

    # ── Sweep beam ────────────────────────────────────────────────────────────
    sweep_line.set_data([angle_rad, angle_rad], [0, MAX_RANGE_CM])

    # ── Fading trail (sector behind beam) ────────────────────────────────────
    if trail_patch[0] is not None:
        trail_patch[0].remove()
        trail_patch[0] = None

    trail_start = math.radians(max(0, current_angle - SWEEP_TRAIL))
    trail_end   = angle_rad
    if trail_end > trail_start:
        theta = np.linspace(trail_start, trail_end, 30)
        xs = np.concatenate([[0], MAX_RANGE_CM * np.cos(theta), [0]])
        ys = np.concatenate([[0], MAX_RANGE_CM * np.sin(theta), [0]])
        patch = mpatches.Polygon(
            np.column_stack([xs, ys]),
            closed=True,
            facecolor="#00ff55", alpha=0.08,
            transform=ax.transData, zorder=4
        )
        # Convert polar to cartesian manually for the patch
        theta_arr = np.linspace(trail_start, trail_end, 30)
        r_arr     = np.full_like(theta_arr, MAX_RANGE_CM)
        verts_theta = np.concatenate([[angle_rad], theta_arr[::-1]])
        verts_r     = np.concatenate([[0], r_arr[::-1]])
        trail_patch[0] = ax.fill(verts_theta, verts_r,
                                 color="#00ff55", alpha=0.10, zorder=4)[0]

    # ── Echo dots ─────────────────────────────────────────────────────────────
    if echoes:
        angles    = [math.radians(a) for a in echoes]
        distances = [d for d, _ in echoes.values()]
        ages      = [frame - f for _, f in echoes.values()]
        alphas    = [max(0.0, 1.0 - age / FADE_STEPS) for age in ages]

        echo_scatter.set_offsets(np.column_stack([angles, distances]))
        echo_scatter.set_array(np.array(alphas))
        echo_scatter.set_sizes([40] * len(angles))
    else:
        echo_scatter.set_offsets(np.empty((0, 2)))

    # ── Status line ───────────────────────────────────────────────────────────
    obj_count = len(echoes)
    status_text.set_text(
        f"Angle: {current_angle:>3}°   Objects: {obj_count}   "
        f"Range: {MAX_RANGE_CM} cm"
    )

    return sweep_line, echo_scatter, status_text


def main():
    global DEMO_MODE

    port = None
    if not DEMO_MODE:
        port = pick_serial_port()
        if port is None:
            DEMO_MODE = True

    data = RadarData()

    # Start background data thread
    if DEMO_MODE:
        print("Running in DEMO MODE (no hardware required).")
        t = threading.Thread(target=demo_reader, args=(data,), daemon=True)
    else:
        t = threading.Thread(target=serial_reader,
                             args=(port, BAUD_RATE, data), daemon=True)
    t.start()

    # Build figure
    fig, ax = build_radar_figure()
    sweep_line, trail_patch, echo_scatter, status_text = make_artists(ax)

    ani = FuncAnimation(
        fig, update_frame,
        fargs=(ax, data, sweep_line, trail_patch, echo_scatter, status_text),
        interval=30,       # ~33 fps
        blit=False,
        cache_frame_data=False,
    )

    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    main()
