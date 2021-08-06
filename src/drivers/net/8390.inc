{$IFNDEF __8390__}
{$DEFINE __8390__}


const

ETHER_ADDR_LEN  = 6;

E8390_CMD	= $00;	{* The command register (for all pages) *}

{* Some generic ethernet register configurations. *}
E8390_TX_IRQ_MASK	= $a;	{* For register EN0_ISR *}
E8390_RX_IRQ_MASK	= $5;
E8390_RXCONFIG		= $4;	{* EN0_RXCR: broadcasts, no multicast,errors *}
E8390_RXOFF		= $20;	{* EN0_RXCR: Accept no packets *}
E8390_TXCONFIG		= $00;	{* EN0_TXCR: Normal transmit mode *}
E8390_TXOFF		= $02;	{* EN0_TXCR: Transmitter off *}


{*  Register accessed at EN_CMD, the 8390 base addr.  *}
E8390_STOP	= $01;	{* Stop and reset the chip *}
E8390_START	= $02;	{* Start the chip, clear reset *}
E8390_TRANS	= $04;	{* Transmit a frame *}
E8390_RREAD	= $08;	{* Remote read *}
E8390_RWRITE	= $10;	{* Remote write  *}
E8390_NODMA	= $20;	{* Remote DMA *}
E8390_PAGE0	= $00;	{* Select page chip registers *}
E8390_PAGE1	= $40;	{* using the two high-order bits *}
E8390_PAGE2	= $80;	{* Page 3 is invalid. *}


{* Page 0 register offsets. *}
EN0_CLDALO	= $01;	{* Low byte of current local dma addr  RD *}
EN0_STARTPG	= $01;	{* Starting page of ring bfr WR *}
EN0_CLDAHI	= $02;	{* High byte of current local dma addr  RD *}
EN0_STOPPG	= $02;	{* Ending page +1 of ring bfr WR *}
EN0_BOUNDARY	= $03;	{* Boundary page of ring bfr RD WR *}
EN0_TSR		= $04;	{* Transmit status reg RD *}
EN0_TPSR	= $04;	{* Transmit starting page WR *}
EN0_NCR		= $05;	{* Number of collision reg RD *}
EN0_TCNTLO	= $05;	{* Low  byte of tx byte count WR *}
EN0_FIFO	= $06;	{* FIFO RD *}
EN0_TCNTHI	= $06;	{* High byte of tx byte count WR *}
EN0_ISR		= $07;	{* Interrupt status reg RD WR *}
EN0_CRDALO	= $08;	{* low byte of current remote dma address RD *}
EN0_RSARLO	= $08;	{* Remote start address reg 0 *}
EN0_CRDAHI	= $09;	{* high byte, current remote dma address RD *}
EN0_RSARHI	= $09;	{* Remote start address reg 1 *}
EN0_RCNTLO	= $0a;	{* Remote byte count reg WR *}
EN0_RCNTHI	= $0b;	{* Remote byte count reg WR *}
EN0_RSR		= $0c;	{* rx status reg RD *}
EN0_RXCR	= $0c;	{* RX configuration reg WR *}
EN0_TXCR	= $0d;	{* TX configuration reg WR *}
EN0_COUNTER0	= $0d;	{* Rcv alignment error counter RD *}
EN0_DCFG	= $0e;	{* Data configuration reg WR *}
EN0_COUNTER1	= $0e;	{* Rcv CRC error counter RD *}
EN0_IMR		= $0f;	{* Interrupt mask reg WR *}
EN0_COUNTER2	= $0f;	{* Rcv missed frame error counter RD *}


{* Bits in EN0_ISR - Interrupt status register *}
ENISR_RX	= $01;	{* Receiver, no error *}
ENISR_TX	= $02;	{* Transmitter, no error *}
ENISR_RX_ERR	= $04;	{* Receiver, with error *}
ENISR_TX_ERR	= $08;	{* Transmitter, with error *}
ENISR_OVER	= $10;	{* Receiver overwrote the ring *}
ENISR_COUNTERS	= $20;	{* Counters need emptying *}
ENISR_RDC	= $40;	{* remote dma complete *}
ENISR_RESET	= $80;	{* Reset completed *}
ENISR_ALL	= $3f;	{* Interrupts we will enable *}

{$ENDIF}
