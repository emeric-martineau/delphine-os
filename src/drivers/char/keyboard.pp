{******************************************************************************
 *  keyboard.pp
 * 
 *  Keyboard management
 *
 *  CopyLeft 2002 GaLi & Edo
 *
 *  version 0.2 - 24/02/2003 - GaLi - Add keyboard_read (seems to work)
 *
 *  version 0.0 - ??/??/2001 - GaLi - Initial version
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit keyboard;


INTERFACE


{$I errno.inc}
{$I fs.inc}
{$I keyboard.inc}
{$I process.inc}
{$I tty.inc}


{DEFINE DEBUG}


{ External procedures and functions }

procedure change_tty (ontty : byte);external;
procedure dump_dev;external;
procedure dump_mem;external;
procedure dump_task;external;
procedure enable_IRQ (irq : byte); external;
function  inb(port : word) : byte; external;
procedure outb(port : word; val : byte); external;
procedure printk (format : string ; args : array of const);external;
procedure putchar (car : char); external;
procedure register_chrdev (nb : byte ; name : string[20] ; fops : pointer); external;
procedure reset_computer; external;
procedure set_intr_gate (n : dword ; addr : pointer); external;
procedure sleep_on (p : PP_wait_queue); external;
procedure update_cursor (ontty : byte); external;
procedure wake_up (p : PP_wait_queue); external;


{ Procedures and functions defined in this file }

procedure init_keyboard;
procedure keyboard_interrupt;
function  keyboard_ioctl (fichier : P_file_t ; req : dword ; argp : pointer) : dword;
function  keyboard_open (inode : P_inode_t ; fichier : P_file_t) : dword;
function  keyboard_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;


{ External variables }

var
   tty         : array[0..7] of tty_struct; external name  'U_TTY__TTY';
   current_tty : byte; external name  'U_TTY__CURRENT_TTY';


IMPLEMENTATION


var
   clavier       : array[0..127] of boolean;
   keyboard_fops : file_operations;
   keyboard_wq   : P_wait_queue;



{******************************************************************************
 * wait_keyboard
 *
 *****************************************************************************}
procedure wait_keyboard;

var
   tmp : byte;

begin
   tmp := inb($64);
   while ((tmp and 2) = 1) do
           tmp:= inb($64);
end;



{******************************************************************************
 * set_leds
 *
 * Entree : un octet representant l'etat des diodes
 *
 * Allume les diodes du clavier selon la valeur de leds (comprise entre 0 et 7)
 * Si le bit 0 de leds est a 1 : Scroll-lock on
 *       bit 1               1 : Num-lock on
 *       bit 2               1 : Caps-lock on
 * 
 * Ne marche pas sur un de mes claviers !!!
 *****************************************************************************}
procedure set_leds (leds : byte);

begin
   wait_keyboard;

   { On va dire au clavier qu'on veut changer l'etat des leds }
   outb($60, $ED);

   wait_keyboard;
   outb($60, leds and $7); { Seuls les bits 0, 1 et 2 doivent etre 
                             positionnes si l'on veut que la commande reste
				valide }

   wait_keyboard;
end;



{******************************************************************************
 * init_keyboard
 *
 *****************************************************************************}
procedure init_keyboard; [public, alias : 'INIT_KEYBOARD'];

var
   i, j : byte;

begin

   set_leds (0);
   set_intr_gate(33, @keyboard_interrupt);   { On installe le gestionnaire }
   enable_IRQ(1);

   for i := 0 to 127 do
       clavier[i]:=false;

   for i := 0 to 7 do   { Initialisation des buffers de chaque console }
       with tty[i] do
       begin
          next_c := 0 ;
          last_c := 0 ;
          depassement := false;
          for j := 0 to MAX_BUFF_CLAV do
              buffer_keyboard[j] := $0;
       end;

   keyboard_wq := NIL;

   keyboard_fops.read  :=  @keyboard_read;
   keyboard_fops.write :=  NIL;
   keyboard_fops.open  :=  @keyboard_open;
   keyboard_fops.seek  :=  NIL;
   keyboard_fops.ioctl :=  @keyboard_ioctl;
   { A FAIRe : rajouter la fonction close() }
   register_chrdev (1, 'keyb', @keyboard_fops);

end;



{******************************************************************************
 * keyboard_interrupt
 *
 * TODO : - Activate interrupts as soon as possible
 *        - Code optimization
 *****************************************************************************}
procedure keyboard_interrupt; interrupt; [ public, alias : 'KEYBOARD_INTERRUPT'];

var
   scan_code, key : byte;
   wkey           : word;

begin

   while ((inb($64) and 1) = 1) do
   begin
      scan_code := inb($60);
      key := scan_code and 127;

      {$IFDEF DEBUG}
         printk('Scan Code: %d  key: %d (%c)\n',[scan_code, key, Lettres[key]]);
      {$ENDIF}

      if scan_code and 128 <> 0 then     { BREAK code ? }
         clavier[key] := false
      else
         begin                           { MAKE code ? }
            clavier[key] := true;

         if clavier[kbesc] then
            begin
               printk('\n\nThe system is going to reboot NOW !!!', []);
               reset_computer;
            end;

         if clavier[kbF9] then
            dump_task;

         if clavier[kbF10] then
            dump_mem;

         if clavier[kbCtrl] then
            dump_dev;

         { Comment this so I can switch consoles with Bochs. GaLi. }
         {if clavier[kbalt] then}   { Alt enfonce ? }
            {begin}
               if (key >= kbF1) and (key <= kbF8) then    { changement de console }
                   change_tty(key-kbF1);
            {end;}
{printk(' %d ', [key]);}
         wkey := ord(Lettres[key]);   { recupere le caractere associe a la touche }
         if wkey <> 0 then
            begin
               with tty[current_tty] do
                    begin
                       if depassement then
                          printk('KEYB : buffer overflow\n',[])
                       else
                          begin
                             buffer_keyboard[next_c] := wkey;   { on rempli le buffer circulaire }
                             next_c += 1;
                             if (next_c > MAX_BUFF_CLAV) then next_c := 0;
                             if (next_c = last_c) then depassement := true;   { est ce que le buffer est rempli ? }
                          end;

                       {if (next_c <> last_c) then
                          begin
                             putchar(chr(lo(buffer_keyboard[last_c])));
                             depassement := false;
                             last_c += 1;
                             if (last_c > MAX_BUFF_CLAV) then last_c := 0 ;
                          end;}

		       if (echo) then
		           putchar(chr(wkey));

		       wake_up(@keyboard_wq);

                    end;
            end; { touche avec un caractere }
      end; { code MAKE }
   end; { while }

   outb($20, $20);

end;



{******************************************************************************
 * keyboard_read
 *
 *****************************************************************************}
function keyboard_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [public, alias : 'KEYBOARD_READ'];

var
   i   : dword;
   car : byte;

begin
{printk('Welcome in keyboard_read...(buf=%h, count=%d)\n', [buf, count]);}

   if (count = 0) then
       begin
          result := 0;
          exit;
       end;

   if (buf < pointer($FFC01000)) then
       begin
          result := -EINVAl;
	  exit;
       end;
 
   i := 0;
   with tty[current_tty] do
   begin
      while (count > 0) do
      begin
         {$IFDEF DEBUG}
	    printk('last_c=%d  next_c=%d\n', [last_c, next_c]);
	 {$ENDIF}
         while (next_c = last_c) do
	     sleep_on(@keyboard_wq);

         {$IFDEF DEBUG}
	    printk('%d ', [lo(buffer_keyboard[last_c])]);
	 {$ENDIF}
	 car := lo(buffer_keyboard[last_c]);
	 asm
	    mov   edi, buf
	    mov   al , car
	    mov   byte [edi], al
	 end;
	 buf    += 1;
	 last_c += 1;
         i      += 1;
         count  -= 1;
	 if (lo(buffer_keyboard[last_c - 1]) = 10) then   { Carriage return ??? }
	     break;
      end;
   end;

   {$IFDEF DEBUG}
      printk('keyboard_read: result=%d\n', [i]);
   {$ENDIF}

   result := i;

end;



{******************************************************************************
 * keyboard_open
 *
 * FIXME: keyboard_open ALWAYS succeed.
 *****************************************************************************}
function keyboard_open (inode : P_inode_t ; fichier : P_file_t) : dword;
begin
   result := 0;
end;



{******************************************************************************
 * keyboard_ioctl
 *
 * FIXME: keyboard_ioctl ALWAYS failed
 *****************************************************************************}
function keyboard_ioctl (fichier : P_file_t ; req : dword ; argp : pointer) : dword;
begin
   result := 0;
end;



begin
end.



