{******************************************************************************
 *  debug.pp
 *
 *  This file contains debug functions
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.3 - ??/??/2002 - GaLi - gestion de l'affichage des chiffres
 *                                    négatifs
 *
 *  version 0.2 - ??/??/2001 - GaLi - initial version
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


unit debug;


INTERFACE


{$I fs.inc}
{$I process.inc}


procedure disable_IRQ (irq : byte); external;
function  get_free_mem : dword; external;
function  get_total_mem : dword; external;
procedure printk (format : string ; args : array of const); external;
procedure putc (car : char ; tty : byte); external;
procedure putchar (car : char); external;


var
   chrdevs     : array[0..MAX_NR_CHAR_DEV] of device_struct; external name 'U_VFS_CHRDEVS';
   blkdevs     : array[0..MAX_NR_BLOCK_DEV] of device_struct; external name 'U_VFS_BLKDEVS';
   current_tty : byte; external name 'U_TTY__CURRENT_TTY';
   first_task  : P_task_struct; external name 'U_PROCESS_FIRST_TASK';
   current     : P_task_struct; external name 'U_PROCESS_CURRENT';
   nr_tasks    : dword; external name 'U_PROCESS_NR_TASKS';
   nr_running  : dword; external name 'U_PROCESS_NR_RUNNING';



procedure delay;
procedure dump_dev;
procedure dump_mem;
procedure dump_task;
procedure panic (reason : string);
procedure print_byte (nb : byte);
procedure print_word (nb : word);
procedure print_dword (nb : dword);
procedure print_dec_byte (nb : byte);
procedure print_dec_word (nb : word);
procedure print_dec_dword (nb : dword);
procedure print_registers;



IMPLEMENTATION



const
   hex_char : array[0..15] of char = ('0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f');



{******************************************************************************
 * delay
 *
 * This procedure isn't used (well, I think so !!!)
 *****************************************************************************}
procedure delay; [public, alias : 'DELAY'];
begin
   asm
      mov   ecx, 600000
      @boucle:
         nop
	 nop
	 nop
	 nop
	 nop
	 nop
      loop @boucle
   end;
end;



{******************************************************************************
 * print_dword
 *
 * Print a dword in hexa
 *****************************************************************************}
procedure print_dword (nb : dword); [public, alias : 'PRINT_DWORD'];

var
   car : char;
   i, decalage, tmp : byte;

begin

   putchar('0');putchar('x');

   for i:=7 downto 0 do

   begin

      decalage := i*4;

      asm
         mov   eax, nb
         mov   cl , decalage
	 shr   eax, cl
	 and   al , 0Fh
	 mov   tmp, al
      end;

      car := hex_char[tmp];

      putc(car, current_tty);

   end;
end;



{******************************************************************************
 * print_word
 *
 * Print in word in hexa
 *****************************************************************************}
procedure print_word (nb : word); [public, alias : 'PRINT_WORD'];

var
   car : char;
   i, decalage, tmp : byte;

begin

   putchar('0');putchar('x');

   for i:=3 downto 0 do

   begin

      decalage := i*4;

      asm
         mov   ax , nb
         mov   cl , decalage
	 shr   ax , cl
	 and   al , 0Fh
	 mov   tmp, al
      end;

      car := hex_char[tmp];

      putc(car, current_tty);

   end;
end;



{******************************************************************************
 * print_byte
 *
 * Print a byte in hexa
 *****************************************************************************}
procedure print_byte (nb : byte); [public, alias : 'PRINT_BYTE'];

var
   car : char;
   i, decalage, tmp : byte;

begin

   putchar('0'); putchar('x');

   for i:=1 downto 0 do

   begin

      decalage := i*4;

      asm
         mov   al , nb
         mov   cl , decalage
	 shr   al , cl
	 and   al , 0Fh
	 mov   tmp, al
      end;

      car := hex_char[tmp];

      putc(car, current_tty);

   end;
end;



{******************************************************************************
 * print_dec_dword
 *
 * Print a dword in decimal
 *****************************************************************************}
procedure print_dec_dword (nb : dword); [public, alias : 'PRINT_DEC_DWORD'];

var
   i, compt : byte;
   dec_str  : string[10];

begin

   compt := 0;
   i     := 10;

   if (nb and $80000000) = $80000000 then
      begin
         asm
	    mov   eax, nb
	    not   eax
	    inc   eax
	    mov   nb , eax
	 end;
	 putchar('-');
      end;

   if (nb = 0) then
      begin
         putchar('0');
      end
   else
      begin

         while (nb <> 0) do
            begin
               dec_str[i]:=chr((nb mod 10) + $30);
               nb    := nb div 10;
               i     := i-1;
               compt := compt + 1;
            end;

         if (compt <> 10) then
            begin
               dec_str[0] := chr(compt);
               for i:=1 to compt do
	          begin
	             dec_str[i] := dec_str[11-compt];
	             compt := compt - 1;
	          end;
            end
         else
            begin
               dec_str[0] := chr(10);
            end;

         for i:=1 to ord(dec_str[0]) do
            begin
               putchar(dec_str[i]);
            end;
      end;
end;



{******************************************************************************
 * print_dec_word
 *
 * Print a word in decimal
 *****************************************************************************}
procedure print_dec_word (nb : word); [public, alias : 'PRINT_DEC_WORD'];

var
   i, compt : byte;
   dec_str  : string[5];

begin

   compt := 0;
   i     := 5;

   while (nb <> 0) do
      begin
         dec_str[i]:=chr((nb mod 10) + $30);
         nb    := nb div 10;
         i     := i-1;
         compt := compt + 1;
      end;

   if (compt <> 5) then
      begin
         dec_str[0] := chr(compt);
         for i:=1 to compt do
	    begin
	       dec_str[i] := dec_str[6-compt];
	       compt := compt - 1;
	    end;
      end
   else
      begin
         dec_str[0] := chr(5);
      end;

   for i:=1 to ord(dec_str[0]) do
      begin
         putchar(dec_str[i]);
      end;

end;



{******************************************************************************
 * print_dec_byte
 *
 * Print a byte in decimal
 *****************************************************************************}
procedure print_dec_byte (nb : byte); [public, alias : 'PRINT_DEC_BYTE'];

var
   i, compt : byte;
   dec_str  : string[3];

begin

   compt := 0;
   i     := 3;

   while (nb <> 0) do
      begin
         dec_str[i]:=chr((nb mod 10) + $30);
         nb    := nb div 10;
         i     := i-1;
         compt := compt + 1;
      end;

   if (compt <> 3) then
      begin
         dec_str[0] := chr(compt);
         for i:=1 to compt do
	    begin
	       dec_str[i] := dec_str[4-compt];
	       compt := compt - 1;
	    end;
      end
   else
      begin
         dec_str[0] := chr(3);
      end;

   for i:=1 to ord(dec_str[0]) do
      begin
         putchar(dec_str[i]);
      end;

end;



{******************************************************************************
 * print_registers
 *
 * Print some registers
 * NOTE : it only works in kernel mode
 *****************************************************************************}
procedure print_registers; [public, alias : 'PRINT_REGISTERS'];

var
   r_cr3, r_esp, r_ebp : dword;
   r_cs, r_ds, r_es, r_fs, r_gs, r_ss: word;

begin
   asm
      mov   r_esp, esp
      mov   r_ebp, ebp
      mov   eax  , cr3
      mov   r_cr3, eax
      mov    ax  , cs
      mov   r_cs , ax
      mov    ax  , ds
      mov   r_ds , ax
      mov    ax  , es
      mov   r_es , ax
      mov    ax  , fs
      mov   r_fs , ax
      mov    ax  , gs
      mov   r_gs , ax
      mov    ax  , ss
      mov   r_ss , ax
   end;

   printk('\nCR3: %h  ESP: %h  EBP: %h\n', [r_cr3, r_esp, r_ebp]);
   printk('CS : %h4  SS : %h4  DS : %h4  ES : %h4\n', [r_cs,r_ss,r_ds,r_es]);
   printk('FS : %h4  GS : %h4\n\n', [r_fs, r_gs]);

end;



{******************************************************************************
 * dump_task
 *
 * Print infos about tasks on the system. This procedure is called when
 * someone use the 'F9' key
 *****************************************************************************}
procedure dump_task; [public, alias : 'DUMP_TASK'];
var
   task, first : P_task_struct;

begin

   printk('Running tasks: %d/%d\n', [nr_running, nr_tasks]);

   printk('Current: TSS=%h4  PID=%d\n', [current^.tss_entry, current^.pid]);

   printk('\n  PID TSS   TTY   MEM  STATE  TIME\n',[]);

   task  := first_task;
   first := first_task;

   repeat
      printk('  %d   %h2   %d      %d', [task^.pid, task^.tss_entry, task^.tty, task^.size]);
      case (task^.state) of
         $1: printk('    R', []);
	 $2: printk('    S', []);
	 $3: printk('    S', []);
	 $4: printk('    s', []);
	 $5: printk('    Z', []);
      end;
      printk('    %d', [task^.ticks]);
      printk('\n', []);
      task := task^.next_task;
   until (task = first);

   printk('\n', []);

end;



{******************************************************************************
 * dump_mem
 *
 * Print infos about memory. This procedure is called when someone use the
 * 'F10' key.
 ******************************************************************************}
procedure dump_mem;  [public, alias : 'DUMP_MEM'];
begin
 printk('\nMemory: %dk/%dk\n',[get_free_mem div 1024, get_total_mem div 1024]);
end;



{******************************************************************************
 * dump_dev
 *
 * Print infos about detected devices. This procedure is called when someone
 * use the '²' key.
 *****************************************************************************}
procedure dump_dev;  [public, alias : 'DUMP_DEV'];
var
   i : dword;

begin
   printk('\n- Char Devices:\n',[]);
   for i := 0 to MAX_NR_CHAR_DEV do
      if chrdevs[i].name<>'' then
         begin
            printk('   %d : %s ( ',[i,chrdevs[i].name]);
            if chrdevs[i].fops^.open <> NIL then
               printk('Open ',[]);
            if chrdevs[i].fops^.read <> NIL then
               printk('Read ',[]);
            if chrdevs[i].fops^.write <> NIL then
               printk('Write ',[]);
            if chrdevs[i].fops^.seek <> NIL then
               printk('Seek ',[]);
            if chrdevs[i].fops^.ioctl <> NIL then
               printk('Ioctl ',[]);
            printk(')\n',[]);
         end;

   printk('\n- Block Devices :\n',[]);
   for i := 0 to MAX_NR_BLOCK_DEV do
      if blkdevs[i].name<>'' then
         begin
            printk('   %d : %s ( ',[i,blkdevs[i].name]);
            if blkdevs[i].fops^.open <> NIL then
               printk('Open ',[]);
            if blkdevs[i].fops^.read <> NIL then
               printk('Read ',[]);
            if blkdevs[i].fops^.write <> NIL then
               printk('Write ',[]);
            if blkdevs[i].fops^.seek <> NIL then
               printk('Seek ',[]);
            if blkdevs[i].fops^.ioctl <> NIL then
               printk('Ioctl ',[]);
            printk(')\n',[]);
         end;

   printk('\n', []);

end;



{******************************************************************************
 * panic
 *
 * Print a string and halt the kernel. Timer is stopped so that the scheduler
 * is not called. However, other IRQs are on.
 *****************************************************************************}
procedure panic (reason : string); [public, alias : 'PANIC'];
begin
   asm
      cli
   end;
   printk('\nSystem halted (%s)', [reason]);
   disable_IRQ(0);
   asm
      sti
      @stop:
         hlt
      jmp @stop
   end;
end;



begin
end.
