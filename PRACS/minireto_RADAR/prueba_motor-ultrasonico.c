#include "MKL25Z4.h"
#include <stdio.h>



// ultrasonico
#define TRIG 0x01
#define ECHO 0x02

volatile float distancia;
volatile int angulo = 0;

void ultrasonic_init(void);
float medir_distancia(void);

void motor_init(void);
void stepper_step(void);

void Init_Clock_Input(void);

void delayUs(int n);



int main(void)
{
    __disable_irq();

    ultrasonic_init();
    motor_init();
    Init_Clock_Input();

    __enable_irq();

    while(1)
    {
        // Todo ocurre por interrupción
    }
}



void Init_Clock_Input(void)
{
    SIM->SCGC5 |= 0x0200;

    PORTA->PCR[1] = PORT_PCR_MUX(1) | PORT_PCR_IRQC(0x09);

    PTA->PDDR &= ~(1<<1);

    NVIC_EnableIRQ(PORTA_IRQn);
}

void PORTA_IRQHandler(void)
{
    if(PORTA->ISFR & (1<<1))
    {
        stepper_step();

        distancia = medir_distancia();

        PORTA->ISFR = (1<<1);
    }
}


void motor_init(void)
{
    SIM->SCGC5 |= 0x1000;

    PORTD->PCR[0] = 0x100;
    PORTD->PCR[1] = 0x100;
    PORTD->PCR[2] = 0x100;
    PORTD->PCR[3] = 0x100;

    PTD->PDDR |= 0x0F;
}

void stepper_step(void)
{
    static int paso = 0;
    static int pasos_totales = 0;
    static int dir = 1;

    const uint8_t seq[4] =
    {
        0x01,
        0x02,
        0x04,
        0x08
    };

    PTD->PDOR = seq[paso];

    paso += dir;

    if(paso > 3) paso = 0;
    if(paso < 0) paso = 3;

    pasos_totales += dir;

    if(pasos_totales >= 1024) //pasos para el movimiento del radar
        dir = -1;

    if(pasos_totales <= 0)
        dir = 1;

    angulo = (pasos_totales * 180) / 1024; //formula para calcular el ángulo
}


void ultrasonic_init(void)
{
    SIM->SCGC5 |= 0x0400;

    PORTB->PCR[0] = 0x100;
    PORTB->PCR[1] = 0x100;

    PTB->PDDR |= TRIG;
    PTB->PDDR &= ~ECHO;
}

float medir_distancia(void)
{
    uint32_t tiempo = 0;

    PTB->PCOR = TRIG;
    delayUs(2);

    PTB->PSOR = TRIG;
    delayUs(10);
    PTB->PCOR = TRIG;

    while(!(PTB->PDIR & ECHO));

    while(PTB->PDIR & ECHO)
    {
        tiempo++;
        delayUs(1);
    }

    return (tiempo * 0.0343)/2;
}

void delayUs(int n)
{
    for(int i=0;i<n*50;i++)
        __asm("nop");
}