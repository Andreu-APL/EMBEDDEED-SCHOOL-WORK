/* radar_sensor.c — KL25Z Ultrasonic Radar Firmware
 *
 * Sweeps a servo 0°–179°, fires an HC-SR04 at every step, and sends
 * one ASCII line per measurement over UART0 (OpenSDA USB-CDC) at 9600 baud:
 *
 *     ANGLE,DISTANCE\n      e.g.  "90,45\n"
 *     ANGLE    : 0–179 degrees
 *     DISTANCE : centimetres (0 = no object / out of range)
 *
 * ─── Wiring ───────────────────────────────────────────────────────────────
 *
 *  Peripheral        KL25Z pin   Notes
 *  ─────────────     ─────────   ─────────────────────────────────────────
 *  Servo signal   →  PTC1        TPM0_CH0  (ALT4) — 3.3V signal is fine
 *  HC-SR04 TRIG   →  PTD2        GPIO output
 *  HC-SR04 ECHO   →  PTD3        GPIO input
 *                                !! ECHO is 5V — use a voltage divider !!
 *                                    ECHO ──┬── 2 kΩ ── PTD3
 *                                           1 kΩ
 *                                           GND
 *  UART0 TX       →  PTA2        ALT2, OpenSDA USB-CDC → PC
 *  UART0 RX       ←  PTA1        ALT2 (not used, configured for symmetry)
 *
 *  Servo VCC + HC-SR04 VCC → external 5 V rail (not 3.3 V board pin)
 *  All GNDs must share a common reference with the KL25Z GND.
 *
 * ─── SDK support files ────────────────────────────────────────────────────
 *  Copy board.c/h, pin_mux.c/h, clock_config.c/h from any other prac
 *  into this project directory — the MCUXpresso template files work as-is.
 * ──────────────────────────────────────────────────────────────────────────
 */

#include "MKL25Z4.h"
#include "board.h"
#include "pin_mux.h"
#include "clock_config.h"

/* ── Pin numbers ────────────────────────────────────────────────────────── */
#define SERVO_PIN   1U   /* PTC1  → TPM0_CH0 */
#define TRIG_PIN    2U   /* PTD2  → HC-SR04 trigger */
#define ECHO_PIN    3U   /* PTD3  → HC-SR04 echo    */

/* ── Servo PWM via TPM0_CH0 ─────────────────────────────────────────────── */
/* 48 MHz / prescaler-64 = 750 kHz tick                                      */
/* 20 ms period  → MOD  = 750 000 × 0.020 − 1 = 14 999                     */
/* 1 ms pulse    → CnV  = 750   (0°)                                         */
/* 2 ms pulse    → CnV  = 1500  (180°)                                       */
#define SERVO_MOD   14999U
#define SERVO_MIN    750U
#define SERVO_MAX   1500U

/* ── UART0 at 9600 baud (48 MHz clock source) ───────────────────────────── */
/* SBR  = 48 000 000 / (16 × 9600)       = 312 (integer part)               */
/* BRFA = round(0.5 × 32)                = 16  (fine-adjust, 5-bit field)   */
/* Actual baud = 48e6 / (16 × 312.5)     = 9600 exactly                     */
#define UART_SBR    312U
#define UART_BRFA    16U

/* ── Radar sweep parameters ─────────────────────────────────────────────── */
#define MAX_DIST_CM  200U   /* readings beyond this are treated as 0 */
#define STEP_DELAY_MS 20U   /* ms between servo steps (settle time)  */

/* ═══════════════════════════════════════════════════════════════════════════
 * SysTick helpers (48 MHz → 1 count = 20.83 ns)
 * ═══════════════════════════════════════════════════════════════════════════ */

static void delay_us(uint32_t us) {
    SysTick->LOAD = 48U * us - 1U;
    SysTick->VAL  = 0U;
    SysTick->CTRL = SysTick_CTRL_ENABLE_Msk | SysTick_CTRL_CLKSOURCE_Msk;
    while (!(SysTick->CTRL & SysTick_CTRL_COUNTFLAG_Msk)) {}
    SysTick->CTRL = 0U;
}

static void delay_ms(uint32_t ms) {
    while (ms--) delay_us(1000U);
}

/* ═══════════════════════════════════════════════════════════════════════════
 * UART0 — raw register driver (bypasses debug console to avoid conflicts)
 * ═══════════════════════════════════════════════════════════════════════════ */

static void UART0_Init(void) {
    SIM->SCGC4 |= SIM_SCGC4_UART0_MASK;
    SIM->SCGC5 |= SIM_SCGC5_PORTA_MASK;

    /* UART0 clock source = MCGFLLCLK (48 MHz after BOARD_BootClockRUN) */
    SIM->SOPT2 &= ~SIM_SOPT2_UART0SRC_MASK;
    SIM->SOPT2 |=  SIM_SOPT2_UART0SRC(1);

    /* PTA1 = UART0_RX (ALT2), PTA2 = UART0_TX (ALT2) */
    PORTA->PCR[1] = PORT_PCR_MUX(2);
    PORTA->PCR[2] = PORT_PCR_MUX(2);

    UART0->C2 = 0U;                          /* disable during config */
    UART0->BDH = (uint8_t)((UART_SBR >> 8) & 0x1FU);
    UART0->BDL = (uint8_t)(UART_SBR & 0xFFU);
    UART0->C4  = (uint8_t)(UART_BRFA & 0x1FU);
    UART0->C1  = 0U;                         /* 8-N-1 */
    UART0->C2  = UART0_C2_TE_MASK | UART0_C2_RE_MASK;
}

static void UART0_SendChar(char c) {
    while (!(UART0->S1 & UART0_S1_TDRE_MASK)) {}
    UART0->D = (uint8_t)c;
}

static void UART0_SendUInt(uint32_t val) {
    if (val == 0U) { UART0_SendChar('0'); return; }
    char buf[10];
    int  i = 0;
    while (val > 0U) { buf[i++] = (char)('0' + (val % 10U)); val /= 10U; }
    while (i > 0)    { UART0_SendChar(buf[--i]); }
}

/* ═══════════════════════════════════════════════════════════════════════════
 * Servo — TPM0_CH0, edge-aligned PWM
 * ═══════════════════════════════════════════════════════════════════════════ */

static void Servo_Init(void) {
    SIM->SCGC5 |= SIM_SCGC5_PORTC_MASK;
    SIM->SCGC6 |= SIM_SCGC6_TPM0_MASK;

    /* TPM clock source = MCGFLLCLK (set once; UART0 init above also sets it) */
    SIM->SOPT2 &= ~SIM_SOPT2_TPMSRC_MASK;
    SIM->SOPT2 |=  SIM_SOPT2_TPMSRC(1);

    PORTC->PCR[SERVO_PIN] = PORT_PCR_MUX(4);   /* TPM0_CH0 */

    TPM0->SC  = 0U;                             /* stop timer */
    TPM0->CNT = 0U;
    TPM0->MOD = SERVO_MOD;

    /* Channel 0: edge-aligned PWM, high-true pulses */
    TPM0->CONTROLS[0].CnSC = TPM_CnSC_MSB_MASK | TPM_CnSC_ELSB_MASK;
    TPM0->CONTROLS[0].CnV  = SERVO_MIN;

    /* Start: CMOD=01 (internal clock), prescaler /64 */
    TPM0->SC = TPM_SC_CMOD(1) | TPM_SC_PS(6);
}

static void Servo_SetAngle(uint8_t deg) {
    uint32_t cnv = SERVO_MIN + ((uint32_t)deg * (SERVO_MAX - SERVO_MIN)) / 180U;
    TPM0->CONTROLS[0].CnV = cnv;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * HC-SR04 — SysTick used as a free-running counter for echo timing
 *
 * SysTick counts DOWN from 0xFFFFFF at 48 MHz (max range ≈ 350 ms).
 * The longest valid echo for 200 cm is ~11 600 µs — well within range.
 * ═══════════════════════════════════════════════════════════════════════════ */

static void Ultrasonic_Init(void) {
    SIM->SCGC5 |= SIM_SCGC5_PORTD_MASK;
    PORTD->PCR[TRIG_PIN] = PORT_PCR_MUX(1);    /* GPIO */
    PORTD->PCR[ECHO_PIN] = PORT_PCR_MUX(1);    /* GPIO */
    PTD->PDDR |=  (1U << TRIG_PIN);            /* TRIG = output */
    PTD->PDDR &= ~(1U << ECHO_PIN);            /* ECHO = input  */
    PTD->PCOR  =  (1U << TRIG_PIN);            /* TRIG idle low */
}

/* Returns distance in cm, or 0 if no echo / out of range */
static uint32_t Measure_DistanceCm(void) {
    /* 10 µs trigger pulse */
    PTD->PSOR = (1U << TRIG_PIN);
    delay_us(10U);
    PTD->PCOR = (1U << TRIG_PIN);

    /* Start free-running SysTick (counts down from 0xFFFFFF) */
    SysTick->LOAD = 0xFFFFFFU;
    SysTick->VAL  = 0U;
    SysTick->CTRL = SysTick_CTRL_ENABLE_Msk | SysTick_CTRL_CLKSOURCE_Msk;

    /* Wait for ECHO to go HIGH — timeout 10 ms (480 000 cycles) */
    while (!(PTD->PDIR & (1U << ECHO_PIN))) {
        if ((0xFFFFFFU - SysTick->VAL) > 480000U) {
            SysTick->CTRL = 0U;
            return 0U;
        }
    }
    uint32_t t_rise = SysTick->VAL;    /* capture rising edge (counts down) */

    /* Wait for ECHO to go LOW — timeout 25 ms (1 200 000 cycles) */
    while (PTD->PDIR & (1U << ECHO_PIN)) {
        /* elapsed = t_rise − current (SysTick counts down, no wrap needed) */
        if ((t_rise - SysTick->VAL) > 1200000U) {
            SysTick->CTRL = 0U;
            return 0U;
        }
    }
    uint32_t t_fall = SysTick->VAL;
    SysTick->CTRL = 0U;

    /* pulse width in µs then convert: distance_cm = pulse_µs / 58 */
    uint32_t pulse_us = (t_rise - t_fall) / 48U;
    uint32_t dist_cm  = pulse_us / 58U;

    return (dist_cm > MAX_DIST_CM) ? 0U : dist_cm;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * Main
 * ═══════════════════════════════════════════════════════════════════════════ */

int main(void) {
    BOARD_InitPins();       /* default pin mux from SDK template */
    BOARD_BootClockRUN();   /* 48 MHz FLL */
    /* Note: do NOT call BOARD_InitDebugConsole() — we drive UART0 directly */

    UART0_Init();
    Servo_Init();
    Ultrasonic_Init();

    /* Move servo to 0° and let it settle before the first sweep */
    Servo_SetAngle(0);
    delay_ms(500U);

    uint8_t angle     = 0U;
    int8_t  direction = 1;    /* +1 sweeping forward, −1 sweeping back */

    while (1) {
        Servo_SetAngle(angle);
        delay_ms(STEP_DELAY_MS);       /* let servo reach position */

        uint32_t dist = Measure_DistanceCm();

        /* Transmit "ANGLE,DISTANCE\n" */
        UART0_SendUInt(angle);
        UART0_SendChar(',');
        UART0_SendUInt(dist);
        UART0_SendChar('\n');

        /* Advance angle, reverse at limits */
        if (direction == 1) {
            if (angle >= 179U) { direction = -1; angle--; }
            else               { angle++;                 }
        } else {
            if (angle == 0U)   { direction =  1; angle++; }
            else               { angle--;                 }
        }
    }
}
