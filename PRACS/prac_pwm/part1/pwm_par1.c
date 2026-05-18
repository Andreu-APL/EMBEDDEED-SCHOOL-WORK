#include "MKL25Z4.h"

void delayMs(int n);

int main(void)
{
    
    SIM->SCGC5 |= 0x400;//CLK PORTB

    
    SIM->SCGC6 |= 0x04000000; //TPM2

   
    SIM->SOPT2 |= 0x01000000; //TPM source

    /*
     * PTB18 = TPM2_CH0
     * Alternative function 3
     */
    PORTB->PCR[18] &= ~0x700;
    PORTB->PCR[18] |= 0x300;

  
    TPM2->SC = 0; //prescaler

    TPM2->MOD = 43702; //mod=43702

    /*
     * Edge-aligned PWM
     * High-true pulses (non-inverted)
     */
    TPM2->CONTROLS[0].CnSC = 0x28; 

   
    TPM2->CONTROLS[0].CnV = 0; //duty cycle 0%

   
    TPM2->SC = 0x0F; //prescaler 128

    while (1)
    {

        TPM2->CONTROLS[0].CnV = 0; //0%
        delayMs(3000);


        TPM2->CONTROLS[0].CnV = 10925;//25%
        delayMs(3000);


        TPM2->CONTROLS[0].CnV = 21851;//50%
        delayMs(3000);


        TPM2->CONTROLS[0].CnV = 32776;//75%
        delayMs(3000);


        TPM2->CONTROLS[0].CnV = 43702;//100%
        delayMs(3000);
    }
}

void delayMs(int n)
{
    int i;
    int j;

    for(i = 0; i < n; i++)
        for(j = 0; j < 7000; j++)
        {
        }
}
