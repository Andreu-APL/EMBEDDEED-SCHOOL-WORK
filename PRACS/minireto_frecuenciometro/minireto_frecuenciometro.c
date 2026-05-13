#include "MKL25Z4.h"
#include <stdio.h>

#define RS 0x04
#define RW 0x10
#define EN 0x20

volatile unsigned int pulsos = 0;
volatile unsigned int frecuencia = 0;
volatile unsigned int ventanas = 0;

char buffer[16];

void LCD_init(void);
void LCD_command(unsigned char command);
void LCD_data(unsigned char data);
void LCD_nibble(unsigned char nibble);
void LCD_sendstring(char *str);

void Signal_init(void);
void Timer_init(void);

void delayMs(int n);

int main(void)
{
    unsigned int temp;

    LCD_init();

    Signal_init();

    Timer_init();

    LCD_command(0x01);

    LCD_sendstring("Frecuencia:");

    while(1)
    {
        temp = frecuencia;

        LCD_command(0xC0);

        sprintf(buffer,"%u Hz      ", temp);

        LCD_sendstring(buffer);

        delayMs(200);
    }
}



void Signal_init(void)
{

    SIM->SCGC5 |= 0x0200; //iniciar PORTA

    PORTA->PCR[12] =0x100| 0x00090000; //inicializar el flanco PTA12

    PTA->PDDR &= ~(1 << 12); //entrada de PTA12

    NVIC_EnableIRQ(PORTA_IRQn); //habilitar interrupción
}

void PORTA_IRQHandler(void)
{
    PORTA->ISFR = (1 << 12); //limpiar bandera

    pulsos++; //contador con los pulso
}


void Timer_init(void)
{
    SIM->SCGC6 |= 0x02000000; //iniciar TPM1

    SIM->SOPT2 |= 0x01000000; //habilitar el timer

    TPM1->SC = 0;

    TPM1->CNT = 0;

    /* Se hizo una ventana de valores de 50ms para que cheque de manera más precisa los pulsos
     * se necesitaron 20 ventanas = 1 segundo
    */

    TPM1->MOD = 8192 - 1;

    /*
        Prescaler 128
        TOIE
        CMOD = 1
    */

    TPM1->SC =0x07| 0x40| 0x08;

    NVIC_EnableIRQ(TPM1_IRQn);
}



void TPM1_IRQHandler(void)
{
    TPM1->SC |= 0x80; //clean

    ventanas++;

    if(ventanas >= 20)
    {
        frecuencia = pulsos;

        pulsos = 0;

        ventanas = 0; //aquí se hace que 20 ventanas de 50ms son iguales a 1 segundo
    }
}

	void LCD_init(void)
	{

		SIM->SCGC5 |= 0x1000; //PORTD





		PORTD->PCR[0] = 0x100;
		PORTD->PCR[1] = 0x100;
		PORTD->PCR[2] = 0x100;
		PORTD->PCR[3] = 0x100; //PTD0-PTD3 GPIO

		PTD->PDDR |= 0x0F;

		SIM->SCGC5 |= 0x0200;//clock PortA

		/*
			PTA2 PTA4 PTA5 GPIO
		*/

		PORTA->PCR[2] = 0x100; //RS
		PORTA->PCR[4] = 0x100; //RW
		PORTA->PCR[5] = 0x100; //EN

		PTA->PDDR |= (RS | RW | EN);

		delayMs(30);

	   //iniciar 4 bits

		LCD_nibble(0x03);

		delayMs(10);

		LCD_nibble(0x03);

		delayMs(10);

		LCD_nibble(0x03);

		delayMs(10);

		LCD_nibble(0x02);

		delayMs(10);
		LCD_command(0x28);
		LCD_command(0x06);

		LCD_command(0x0C); //display ON - cursor off

		LCD_command(0x01); //clean LCD

		delayMs(10);
	}

	void LCD_command(unsigned char command)
	{
		PTA->PCOR = RS; //=0
		PTA->PCOR = RW; //=0

		LCD_nibble(command >> 4); //alto

		LCD_nibble(command & 0x0F); //bajo

		delayMs(2);
	}

	void LCD_data(unsigned char data)
	{

		PTA->PSOR = RS; //=1

		PTA->PCOR = RW;//=0


		LCD_nibble(data >> 4);

		/*
			nibble bajo
		*/

		LCD_nibble(data & 0x0F);

		delayMs(2);
	}

	void LCD_nibble(unsigned char nibble)
	{




		PTD->PDOR &= ~0x0F; //limpiar PTD0-PTD3

		PTD->PDOR |= (nibble & 0x0F); //enviar

		PTA->PSOR = EN;//pulso

		delayMs(1);

		PTA->PCOR = EN;

		delayMs(1);
	}

void LCD_sendstring(char *str)
{
    while(*str)
    {
        LCD_data(*str++);
    }
}



void delayMs(int n)
{
    volatile int i;
    volatile int j;

    for(i = 0; i < n; i++)
    {
        for(j = 0; j < 3000; j++)
        {
            __asm("nop");
        }
    }
}
