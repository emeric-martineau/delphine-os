{******************************************************************************
 *  ne.pp
 *
 *  Support for NE2000 ethernet cards
 *
 *  NOTE: this code is inspired from drivers/net/ne.c from Linux 2.4.22
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 10/10/2003 - GaLi - Initial version
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit ne;


INTERFACE


{* Headers *}

{$I 8390.inc}

{* Local macros *}


{* External procedure and functions *}

function  inb (port : word) : byte; external;
procedure outb (port : word ; val : byte); external;
procedure print_byte_s (nb : byte); external;
procedure printk (format : string ; args : array of const); external;
procedure putchar (car : char); external;


{* External variables *}


{* Exported variables *}


procedure init_ne_isa;
function  ne_probe1 (ioaddr : word) : boolean;



IMPLEMENTATION



{* Types only used in THIS file *}

type
   val_ofs_struct = record
      value, offset : byte;
   end;


{* Constants only used in THIS file *}

const
   {* ---- No user-serviceable parts below ---- *}

   NE_CMD		= $00;
   NE_DATAPORT		= $10;	{* NatSemi-defined port window offset. *}
   NE_RESET		= $1f;	{* Issue a read to reset, a write to clear. *}
   NE_IO_EXTENT		= $20;

   NE1SM_START_PG	= $20;	{* First page of TX buffer *}
   NE1SM_STOP_PG 	= $40;	{* Last page +1 of RX ring *}
   NESM_START_PG	= $40;	{* First page of TX buffer *}
   NESM_STOP_PG		= $80;	{* Last page +1 of RX ring *}

   netcard_portlist : array[0..6] of word = ($300, $280, $320, $340, $360, $380, 0);
   program_seq : array[0..12] of val_ofs_struct =
   ((value: E8390_NODMA+E8390_PAGE0+E8390_STOP ; offset: E8390_CMD),	{* Select page 0 *}
    (value: $48 ; offset: EN0_DCFG),					{* Set byte-wide (0x48) access. *}
    (value: $00 ; offset: EN0_RCNTLO),					{* Clear the count regs. *}
    (value: $00 ; offset: EN0_RCNTHI),
    (value: $00 ; offset: EN0_IMR),					{* Mask completion irq. *}
    (value: $00 ; offset: EN0_ISR),
    (value: E8390_RXOFF ; offset: EN0_RXCR),				{* 0x20  Set to monitor *}
    (value: E8390_TXOFF ; offset: EN0_TXCR),				{* 0x02  and loopback mode. *}
    (value: 32 ; offset: EN0_RCNTLO),
    (value: $00 ; offset: EN0_RCNTHI),
    (value: $00 ; offset: EN0_RSARLO),					{* DMA starting at 0x0000. *}
    (value: $00 ; offset: EN0_RSARHI),
    (value: E8390_RREAD+E8390_START ; offset: E8390_CMD));



{* Variables only used in THIS file *}



{******************************************************************************
 * init_ne_isa
 *
 *****************************************************************************}
procedure init_ne_isa; [public, alias : 'INIT_NE_ISA'];

var
   base_addr : word;

begin

   base_addr := 0;
   while (netcard_portlist[base_addr] <> 0) do
   begin
      if (ne_probe1(netcard_portlist[base_addr])) then break;
      base_addr += 1;
   end;

end;



{******************************************************************************
 * ne_probe1
 *
 *****************************************************************************}
function ne_probe1 (ioaddr : word) : boolean;

var
   reg0, regd, wordlength : byte;
   timeout, i : dword;
   SA_prom    : array[0..31] of byte;
   start_page, stop_page : dword;
   neX000, ctron, copam : boolean;

begin

   wordlength := 2;
   result := FALSE;

   reg0 := inb(ioaddr);
   if (reg0 = $FF) then exit;

   {* Do a preliminary verification that we have a 8390. *}

   outb(ioaddr + E8390_CMD, E8390_NODMA+E8390_PAGE1+E8390_STOP);
   regd := inb(ioaddr + $0D);
   outb(ioaddr + $0D, $FF);
   outb(ioaddr + E8390_CMD, E8390_NODMA+E8390_PAGE0);
   inb(ioaddr + EN0_COUNTER0);   {* Clear the counter by reading. *}
   if (inb(ioaddr + EN0_COUNTER0) <> 0) then
   begin
      outb(ioaddr, reg0);
      outb(ioaddr + $0D, regd);   {* Restore the old values. *}
      exit;
   end;

{   printk('NE*000 ethercard probe at %h3:', [ioaddr]);}

   {* Reset card. Who knows what dain-bramaged state it was left in. *}

   outb(ioaddr + NE_RESET, inb(ioaddr + NE_RESET));

   timeout := 0;
   while ((inb(ioaddr + EN0_ISR) and ENISR_RESET) = 0) do
   begin
      timeout += 1;
      if (timeout > 500) then
      begin
         printk(' not found (no reset ack).\n', []);
	 exit;
      end;
   end;

   outb(ioaddr + EN0_ISR, $FF);   {* Ack all intr. *}

   {* Read the 16 bytes of station address PROM.
    * We must first initialize registers, similar to NS8390_init(eifdev, 0).
    * We can't reliably read the SAPROM address without this. *}

   i := 0;
   while (i < (sizeof(program_seq) div sizeof(program_seq[0]))) do
   begin
      outb(ioaddr + program_seq[i].offset, program_seq[i].value);
      i += 1;
   end;

   for i := 0 to 31 {*sizeof(SA_prom)*} do
   begin
      SA_prom[i]   := inb(ioaddr + NE_DATAPORT);
      SA_prom[i+1] := inb(ioaddr + NE_DATAPORT);
      if (SA_prom[i] <> SA_prom[i+1]) then
          wordlength := 1;
      i += 1;
   end;

   if (wordlength = 2) then
   begin
      for i := 0 to 15 do
          SA_prom[i] := SA_prom[i+i];
      {* We must set the 8390 for word mode. *}
      outb(ioaddr + EN0_DCFG, $49);
      start_page := NESM_START_PG;
      stop_page  := NESM_STOP_PG;
   end
   else
   begin
      start_page := NE1SM_START_PG;
      stop_page  := NE1SM_STOP_PG;
   end;

   neX000 := ((SA_prom[14] = $57)  and  (SA_prom[15] = $57));
   ctron  := ((SA_prom[0]  = $00) and (SA_prom[1] = $00) and (SA_prom[2] = $1d));
   copam  := ((SA_prom[14] = $49) and (SA_prom[15] = $00));

   {* Set up the rest of the parameters. *}
   if (neX000 or copam) then
   begin
      if (wordlength = 2) then
          printk('NE2000: ', [])
      else
          printk('NE1000: ', []);
   end
   else if (ctron) then
   begin
      if (wordlength = 2) then
          printk('Ctron-16: ', [])
      else
          printk('Ctron-8: ', []);
      start_page := $01;
      if (wordlength = 2) then
          stop_page := $40
      else
          stop_page := $20;
   end
   else
      printk(' not found\n', []);

{ FIXME: Care about IRQ }

   printk('hw_addr ', []);
   for i := 0 to (ETHER_ADDR_LEN - 1) do
   begin
      print_byte_s(SA_prom[i]);
      printk(':', []);
   end;
   putchar(#8);
   putchar(#10);

   result := TRUE;

end;



begin
end.
