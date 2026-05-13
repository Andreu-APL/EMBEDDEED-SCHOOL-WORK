# Practical: PWM with TPM2 on KL25Z

## Overview

This program generates a **PWM (Pulse Width Modulation)** signal on pin **PTB18** of the FRDM-KL25Z board using the **TPM2 (Timer/PWM Module 2), Channel 0**. The duty cycle steps through 0%, 25%, 50%, 75%, and 100% every 3 seconds in an infinite loop.

## Hardware

| Item | Detail |
|------|--------|
| Board | FRDM-KL25Z |
| Output Pin | PTB18 (TPM2_CH0, Alt Function 3) |
| Signal | Edge-aligned PWM, non-inverted |

## PWM Configuration

| Parameter | Value | Notes |
|-----------|-------|-------|
| TPM Clock Source | MCGFLLCLK (~20.97 MHz) | Set via `SIM->SOPT2` |
| Prescaler | 128 | `SC = 0x0F` → PS bits = `111` |
| TPM Counter Clock | ~163.8 kHz | 20.97 MHz / 128 |
| MOD Register | 43702 | Period = MOD + 1 counts |
| PWM Frequency | ~3.75 Hz | 163,840 / 43,703 |

## Duty Cycle Steps

| Step | `CnV` Value | Duty Cycle | Duration |
|------|------------|------------|----------|
| 1 | 0 | 0% | 3 s |
| 2 | 10925 | 25% | 3 s |
| 3 | 21851 | 50% | 3 s |
| 4 | 32776 | 75% | 3 s |
| 5 | 43702 | 100% | 3 s |

> Duty cycle = `CnV / (MOD + 1)`. At 100%, `CnV == MOD`, output stays high.

## Register Summary

| Register | Value | Purpose |
|----------|-------|---------|
| `SIM->SCGC5` | `\|= 0x400` | Enable clock gate for Port B |
| `SIM->SCGC6` | `\|= 0x04000000` | Enable clock gate for TPM2 |
| `SIM->SOPT2` | `\|= 0x01000000` | Select MCGFLLCLK as TPM clock source |
| `PORTB->PCR[18]` | MUX = `011` | Set PTB18 to Alt3 (TPM2_CH0) |
| `TPM2->SC` | `0x00` → `0x0F` | Prescaler /128, TOIE off, CPWMS=0 |
| `TPM2->MOD` | `43702` | PWM period |
| `TPM2->CONTROLS[0].CnSC` | `0x28` | Edge-aligned PWM, high-true (MSnB=1, ELSnB=1) |
| `TPM2->CONTROLS[0].CnV` | variable | Duty cycle compare value |

## File Structure

```
prac_pwm/
└── pwm_par1.c      — main source file
```
