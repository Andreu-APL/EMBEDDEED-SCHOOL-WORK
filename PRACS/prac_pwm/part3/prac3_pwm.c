#include <MKL25Z4.h>
#include <stdint.h>

#define RS 0x04
#define RW 0x10
#define EN 0x20

volatile uint8_t estado = 1;

unsigned char key;
unsigned char modo = 0;

/* PROTOTIPOS */
void LCD_init(void);
void LCD_command(unsigned char command);
void LCD_data(unsigned char data);
void LCD_nibble(unsigned char nibble);
void LCD_sendstring(char *str);

void keypad_init(void);
unsigned char keypad_getkey(void);

void PWM_init(void);
void set_duty(uint16_t duty);

void ADC_init(void);
uint16_t ADC_read(void);

void Init_Button(void);

void delayMs(int n);
void delayUs(int n);



int main(void)
{
    LCD_init();
    keypad_init();
    PWM_init();
    ADC_init();
    Init_Button();

    while(1)
    {
        if(estado)
        {
            LCD_command(0x01);
            LCD_sendstring("1:M 2:A");
            modo = 0;
            estado = 0;
        }

        key = keypad_getkey();

        if(key != 0)
        {
            if(modo == 0)
            {
                if(key == 1)
                {
                    modo = 1;
                    LCD_command(0x01);
                    LCD_sendstring("1L 2M 3MH 4H");
                }

                else if(key == 2)
                {
                    modo = 2;
                    LCD_command(0x01);
                    LCD_sendstring("Automatic");
                }
            }

            else if(modo == 1)
            {
                switch(key)
                {
                    case 1: set_duty(10925); break;
                    case 2: set_duty(21851); break;
                    case 3: set_duty(32776); break;
                    case 4: set_duty(43702); break;
                }
            }

            delayMs(250);
        }

        if(modo == 2)
        {
            uint16_t adc = ADC_read();

            if(adc < 930)
                set_duty(10925);

            else if(adc < 1860)
                set_duty(21851);

            else if(adc < 2790)
                set_duty(32776);

            else
                set_duty(43702);
        }
    }
}


void PWM_init(void)
{
    SIM->SCGC5 |= 0x400;
    SIM->SCGC6 |= 0x04000000;
    SIM->SOPT2 |= 0x01000000;

    PORTB->PCR[18] &= ~0x700;
    PORTB->PCR[18] |= 0x300;

    TPM2->SC = 0;
    TPM2->MOD = 43702;
    TPM2->CONTROLS[0].CnSC = 0x28;
    TPM2->SC = 0x0F;

    TPM2->CONTROLS[0].CnV = 0;
}

void set_duty(uint16_t duty)
{
    TPM2->CONTROLS[0].CnV = duty;
}


void ADC_init(void)
{
    SIM->SCGC5 |= SIM_SCGC5_PORTB_MASK;
    SIM->SCGC6 |= SIM_SCGC6_ADC0_MASK;

    PORTB->PCR[0] = 0;

    ADC0->CFG1 = 0x0C;
}

uint16_t ADC_read(void)
{
    ADC0->SC1[0] = 8;

    while(!(ADC0->SC1[0] & 0x80));

    return ADC0->R[0];
}


void Init_Button(void)
{
    SIM->SCGC5 |= SIM_SCGC5_PORTA_MASK;

    PORTA->PCR[1] = PORT_PCR_MUX(1) |
                    PORT_PCR_PE_MASK |
                    PORT_PCR_PS_MASK |
                    PORT_PCR_IRQC(0xA);

    PTA->PDDR &= ~(1 << 1);

    NVIC_EnableIRQ(PORTA_IRQn);
}

void PORTA_IRQHandler(void)
{
    if(PORTA->ISFR & (1 << 1))
    {
        PORTA->ISFR |= (1 << 1);

        for(volatile int i=0;i<50000;i++);

        estado = 1;
    }
}


void LCD_init(void)
{
    SIM->SCGC5 |= 0x1000;

    PORTD->PCR[0] = 0x100;
    PORTD->PCR[1] = 0x100;
    PORTD->PCR[2] = 0x100;
    PORTD->PCR[3] = 0x100;

    PTD->PDDR |= 0x0F;

    SIM->SCGC5 |= 0x0200;

    PORTA->PCR[2] = 0x100;
    PORTA->PCR[4] = 0x100;
    PORTA->PCR[5] = 0x100;

    PTA->PDDR |= (RS | RW | EN);

    delayMs(30);

    LCD_nibble(0x03);
    delayMs(10);
    LCD_nibble(0x03);
    delayMs(10);
    LCD_nibble(0x03);
    delayMs(10);
    LCD_nibble(0x02);

    LCD_command(0x28);
    LCD_command(0x06);
    LCD_command(0x0C);
    LCD_command(0x01);

    delayMs(10);
}

void LCD_command(unsigned char command)
{
    PTA->PCOR = RS;
    PTA->PCOR = RW;

    LCD_nibble(command >> 4);
    LCD_nibble(command & 0x0F);

    delayMs(2);
}

void LCD_data(unsigned char data)
{
    PTA->PSOR = RS;
    PTA->PCOR = RW;

    LCD_nibble(data >> 4);
    LCD_nibble(data & 0x0F);

    delayMs(2);
}

void LCD_nibble(unsigned char nibble)
{
    PTD->PDOR &= ~0x0F;
    PTD->PDOR |= (nibble & 0x0F);

    PTA->PSOR = EN;
    delayMs(1);

    PTA->PCOR = EN;
    delayMs(1);
}

void LCD_sendstring(char *str)
{
    while(*str)
        LCD_data(*str++);
}


void keypad_init(void)
{
    SIM->SCGC5 |= 0x0800;

    for(int i=0;i<8;i++)
        PORTC->PCR[i] = 0x103;

    PTC->PDDR = 0x0F;
}

unsigned char keypad_getkey(void)
{
    int row, col;
    const char row_select[] = {0x01,0x02,0x04,0x08};

    PTC->PDDR |= 0x0F;
    PTC->PCOR = 0x0F;

    delayUs(2);

    col = PTC->PDIR & 0xF0;
    PTC->PDDR = 0;

    if(col == 0xF0) return 0;

    for(row=0; row<4; row++)
    {
        PTC->PDDR = row_select[row];
        PTC->PCOR = row_select[row];

        delayUs(1);

        col = PTC->PDIR & 0xF0;

        if(col != 0xF0) break;
    }

    if(col == 0xE0) return row*4+1;
    if(col == 0xD0) return row*4+2;
    if(col == 0xB0) return row*4+3;
    if(col == 0x70) return row*4+4;

    return 0;
}


void delayUs(int n)
{
    volatile int i,j;
    for(i=0;i<n;i++)
        for(j=0;j<3;j++)
            __asm("nop");
}

void delayMs(int n)
{
    volatile int i,j;
    for(i=0;i<n;i++)
        for(j=0;j<5000;j++)
            __asm("nop");
}
