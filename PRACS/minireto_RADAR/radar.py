"""
Radar Display — lee datos UART de la KL25Z y dibuja un radar 2D en vivo.

Formato esperado desde la KL25Z:
    ANGULO,DISTANCIA

Ejemplo:
    90,45
"""

import math
import threading
import serial
import serial.tools.list_ports
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation

# ── Configuración ─────────────────────────────────────────────────────────────
BAUD_RATE    = 57600
MAX_RANGE_CM = 200
SWEEP_TRAIL  = 5
FADE_STEPS   = 60
DEMO_MODE    = False
# ──────────────────────────────────────────────────────────────────────────────


def pick_serial_port():
    ports = serial.tools.list_ports.comports()

    if not ports:
        print("No se encontraron puertos seriales.")
        return None

    print("Puertos disponibles:")
    for i, p in enumerate(ports):
        print(f"[{i}] {p.device} - {p.description}")

    while True:
        try:
            idx = int(input("Selecciona el puerto de la KL25Z: "))
            return ports[idx].device
        except (ValueError, IndexError):
            print("Selección inválida, intenta otra vez.")


class RadarData:
    def __init__(self):
        self._lock = threading.Lock()
        self.current_angle = 0
        self.echoes = {}
        self.frame = 0

    def update(self, angle, distance):
        with self._lock:
            self.current_angle = angle

            if 0 < distance <= MAX_RANGE_CM:
                self.echoes[angle] = (distance, self.frame)

    def tick(self):
        with self._lock:
            self.frame += 1

            expired = [
                angle for angle, (_, frame_added) in self.echoes.items()
                if self.frame - frame_added > FADE_STEPS
            ]

            for angle in expired:
                del self.echoes[angle]

    def snapshot(self):
        with self._lock:
            return self.current_angle, dict(self.echoes), self.frame


def serial_reader(port, baud, data):
    try:
        with serial.Serial(port, baud, timeout=1) as ser:
            print(f"Serial abierto en {port} @ {baud}")

            while True:
                raw = ser.readline().decode(errors="ignore").strip()

                if raw:
                    print("RX:", raw)

                if "," not in raw:
                    continue

                parts = raw.split(",")

                if len(parts) != 2:
                    continue

                try:
                    angle = int(parts[0])
                    distance = float(parts[1])

                    if 0 <= angle <= 179:
                        data.update(angle, distance)

                except ValueError:
                    continue

    except serial.SerialException as e:
        print(f"Error serial: {e}")


def demo_reader(data):
    import time

    angle = 0
    direction = 1

    while True:
        if 55 <= angle <= 65:
            distance = 80
        elif 115 <= angle <= 130:
            distance = 130
        else:
            distance = 0

        data.update(angle, distance)

        angle += direction

        if angle >= 179:
            angle = 179
            direction = -1
        elif angle <= 0:
            angle = 0
            direction = 1

        time.sleep(0.02)


def build_radar_figure():
    matplotlib.rcParams["toolbar"] = "None"

    fig = plt.figure(figsize=(8, 6), facecolor="#0a0a0a")
    fig.canvas.manager.set_window_title("KL25Z Ultrasonic Radar")

    ax = fig.add_subplot(111, polar=True)
    ax.set_facecolor("#0a0a0a")

    ax.set_thetamin(0)
    ax.set_thetamax(180)

    ax.set_theta_direction(-1)
    ax.set_theta_offset(0)

    ax.set_ylim(0, MAX_RANGE_CM)

    ring_vals = np.linspace(0, MAX_RANGE_CM, 5)[1:]

    ax.set_yticks(ring_vals)
    ax.set_yticklabels(
        [f"{int(r)} cm" for r in ring_vals],
        color="white",
        fontsize=8
    )

    ax.set_xticks(np.radians(np.arange(0, 181, 30)))
    ax.set_xticklabels(
        [f"{a}°" for a in range(0, 181, 30)],
        color="white",
        fontsize=10
    )

    ax.grid(color="#00aa44", linewidth=0.6, linestyle="--")
    ax.spines["polar"].set_color("#00aa44")

    return fig, ax


def make_artists(ax):
    sweep_line, = ax.plot(
        [],
        [],
        color="#00ff55",
        linewidth=2,
        zorder=5
    )

    echo_scatter = ax.scatter(
        [],
        [],
        s=45,
        c=[],
        cmap="Greens",
        vmin=0,
        vmax=1,
        zorder=6
    )

    status_text = ax.text(
        0.5,
        -0.08,
        "Esperando datos...",
        transform=ax.transAxes,
        ha="center",
        va="top",
        color="white",
        fontsize=12,
        fontfamily="monospace"
    )

    trail_patch = [None]

    return sweep_line, trail_patch, echo_scatter, status_text


def update_frame(_, ax, data, sweep_line, trail_patch, echo_scatter, status_text):
    data.tick()

    current_angle, echoes, frame = data.snapshot()
    angle_rad = math.radians(current_angle)

    sweep_line.set_data(
        [angle_rad, angle_rad],
        [0, MAX_RANGE_CM]
    )

    if trail_patch[0] is not None:
        trail_patch[0].remove()
        trail_patch[0] = None

    trail_start = math.radians(max(0, current_angle - SWEEP_TRAIL))
    trail_end = angle_rad

    if trail_end > trail_start:
        theta_arr = np.linspace(trail_start, trail_end, 30)
        r_arr = np.full_like(theta_arr, MAX_RANGE_CM)

        verts_theta = np.concatenate([[angle_rad], theta_arr[::-1]])
        verts_r = np.concatenate([[0], r_arr[::-1]])

        trail_patch[0] = ax.fill(
            verts_theta,
            verts_r,
            color="#00ff55",
            alpha=0.10,
            zorder=4
        )[0]

    if echoes:
        angles = [math.radians(a) for a in echoes.keys()]
        distances = [d for d, _ in echoes.values()]
        ages = [frame - f for _, f in echoes.values()]
        alphas = [max(0.0, 1.0 - age / FADE_STEPS) for age in ages]

        echo_scatter.set_offsets(
            np.column_stack([angles, distances])
        )
        echo_scatter.set_array(np.array(alphas))
        echo_scatter.set_sizes([45] * len(angles))
    else:
        echo_scatter.set_offsets(np.empty((0, 2)))

    status_text.set_text(
        f"Ángulo: {current_angle:>3}°   "
        f"Objetos: {len(echoes)}   "
        f"Rango: {MAX_RANGE_CM} cm"
    )

    return sweep_line, echo_scatter, status_text


def main():
    port = None

    if not DEMO_MODE:
        port = pick_serial_port()

        if port is None:
            print("No hay puerto serial disponible.")
            return

    data = RadarData()

    if DEMO_MODE:
        print("Corriendo en DEMO_MODE.")
        thread = threading.Thread(
            target=demo_reader,
            args=(data,),
            daemon=True
        )
    else:
        thread = threading.Thread(
            target=serial_reader,
            args=(port, BAUD_RATE, data),
            daemon=True
        )

    thread.start()

    fig, ax = build_radar_figure()
    sweep_line, trail_patch, echo_scatter, status_text = make_artists(ax)

    ani = FuncAnimation(
        fig,
        update_frame,
        fargs=(ax, data, sweep_line, trail_patch, echo_scatter, status_text),
        interval=30,
        blit=False,
        cache_frame_data=False
    )

    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    main()