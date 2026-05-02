#include <MKL25Z4.H>
#include <stdio.h>

void UART0_init(void);
void UART0_putchar(char c);
void UART0_puts(char *s);
void delayMs(int n);

int main(void) {
    int angulo = 0;
    int distancia = 0;
    int direccion = 1;
    char buffer[40];

    UART0_init();

    while (1) {
        if (angulo >= 50 && angulo <= 80) {
            distancia = 60;
        }
        else if (angulo >= 110 && angulo <= 140) {
            distancia = 120;
        }
        else {
            distancia = 0;
        }

        sprintf(buffer, "%d,%d\r\n", angulo, distancia);
        UART0_puts(buffer);

        angulo += direccion;

        if (angulo >= 179) {
            angulo = 179;
            direccion = -1;
        }

        if (angulo <= 0) {
            angulo = 0;
            direccion = 1;
        }

        delayMs(30);
    }
}

void UART0_init(void) {
    SIM->SCGC4 |= 0x0400;
    SIM->SCGC5 |= 0x0200;

    UART0->C2 = 0x00;

    SIM->SOPT2 &= ~0x0C000000;
    SIM->SOPT2 |= 0x04000000;

    UART0->BDH = 0x00;
    UART0->BDL = 0x17;
    UART0->C4  = 0x0F;

    UART0->C1 = 0x00;

    PORTA->PCR[1] = 0x0200;
    PORTA->PCR[2] = 0x0200;

    UART0->C2 = 0x0C;
}

void UART0_putchar(char c) {
    while (!(UART0->S1 & 0x80)) {
    }

    UART0->D = c;
}

void UART0_puts(char *s) {
    while (*s) {
        UART0_putchar(*s++);
    }
}

void delayMs(int n) {
    int i;
    int j;

    for (i = 0; i < n; i++) {
        for (j = 0; j < 7000; j++) {
        }
    }
}