{******************************************************************************
 *  keyboard.pp
 * 
 *  Gestion du clavier
 *
 *  CopyLeft 2002 GaLi & Edo
 *
 *  version 0.0 - ??? - GaLi
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

interface

{$I tty.inc}
{$I process.inc}
{$I fs.inc}
{$I keyboard.inc}


procedure keyboard_interrupt;
procedure init_keyboard;
function  keyboard_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;


procedure reset_computer; external;
function  inb(port : word) : byte; external; { src/debug/debug.pp }
procedure outb(port : word; val : byte); external; { src/debug/debug.pp }
procedure change_tty (ontty : byte);external; { src/drivers/char/tty.pp }
procedure printk (format : string ; args : array of const);external; { src/drivers/char/tty.pp }
procedure dump_mem;external;    { src/debug/debug.pp }
procedure dump_task;external;    { src/debug/debug.pp }
procedure dump_dev;external;    { src/debug/debug.pp }
procedure putchar (car : char); external; { src/drivers/char/tty.pp }
procedure register_chrdev (nb : byte ; name : string[20] ; fops : pointer); external;{ src/fs/init_vfs.pp }

procedure set_intr_gate (n : dword ; addr : pointer); external;
procedure enable_IRQ (irq : byte); external;
procedure IO_delay; external;


var
   tty         : array[0..7] of tty_struct; external name  'U_TTY__TTY';
   current_tty : byte; external name  'U_TTY__CURRENT_TTY';



implementation



var
   clavier       : array[0..127] of boolean;
   keyboard_fops : file_operations;



{******************************************************************************
 * wait_keyboard
 *
 *****************************************************************************}
procedure wait_keyboard;

var
   tmp : byte;

begin
   repeat 
      tmp := inb($64);
   until ((tmp and 2) = 0);
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
   set_intr_gate(33, @keyboard_interrupt); { On installe le gestionnaire }
   enable_IRQ(1);

   for i := 0 to 127 do
       clavier[i]:=false;

   for i := 0 to 7 do                      { Initialisation des buffers de chaque console }
       with tty[i] do
       begin
          next_c := 0 ;
          last_c := 0 ;
          depassement := false;
          for j := 0 to MAX_BUFF_CLAV do
              buffer_keyboard[j] := $0;
       end;

   keyboard_fops.read  :=  @keyboard_read;
   keyboard_fops.write :=  nil;
   keyboard_fops.open  :=  nil;
   keyboard_fops.seek  :=  nil;
   { A FAIRe : rajouter la fonction close() }
   register_chrdev (1, 'Keyboard', @keyboard_fops);
end;



{******************************************************************************
 * keyboard_interrupt
 *
 *****************************************************************************}
procedure keyboard_interrupt; interrupt; [ public, alias : 'KEYBOARD_INTERRUPT'];

var
   scan_code, key : byte;
   wkey, i        : word;

begin

   while ((inb($64) and 1) = 1) do
   begin
      scan_code := inb($60);
      key := scan_code and 127;
  {   printk('Scan Code : %d - %c',[key,Lettres[key]]); }

      if scan_code and 128 <> 0 then     { BREAK on relache la touche }
         clavier[key]:= false
      else
         begin                           { MAKE on appuie sur une touche }
            clavier[key]:= true;


      if clavier[kbesc] then
         begin
            printk('\n\nThe system is going to reboot NOW !!!', []);
            reset_computer;
         end;


      if clavier[kbF9] then
         begin
            dump_task;
         end;

      if clavier[kbF10] then
         begin
            dump_mem;
         end;


      if clavier[29] then
         begin
            dump_dev;
         end;

      if clavier[kbalt] then   { Alt enfonce ? }
         begin
            if (key >= kbF1) and (key <= kbF8) then    { changement de console }
                change_tty(key-kbF1);
            
          {     printk('Alt!',[]); }
         end;


      wkey := ord(Lettres[key]);                       { recupere le caractere associe a la touche }
      if wkey <> 0 then
         begin
            with tty[current_tty] do
               begin
                  if depassement then
                     begin
                        printk('KEY : Depassement de buffer',[]);
                     end
                  else
                     begin
                        buffer_keyboard[next_c] := wkey;              { on rempli le buffer circulaire }
                        next_c += 1;
                        if next_c > MAX_BUFF_CLAV then next_c := 0;
                        if next_c = last_c then depassement := true;                { est ce que le buffer est rempli ? }
                     end;

                  if next_c <> last_c then
                     begin
                        putchar(chr(lo(buffer_keyboard[last_c])));
                        depassement := false;
                        last_c +=1;
                        if last_c >MAX_BUFF_CLAV then last_c:=0 ;
                     end;
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
var i :dword;
begin

 if (count = 0) then
 begin
    result := 0;
    exit;
 end;

 { A FAIRE : }
 { il faut verifier si on a les droits de lire le clavier  sinon renvoyer -1 }
 { verifier que le buffer appartient bien au processus }

 
 i:=0;
 with tty[current_tty] do
 begin
   while ( ( count >0) and (next_c <> last_c) ) do
   begin
      i+=1;
      count -=1;
   end;
 end;



{
          if next_c <> last_c then
          begin
             putchar(chr(lo(buffer_keyboard[last_c])));
             depassement := false;
             last_c +=1;
             if last_c >MAX_BUFF_CLAV then last_c:=0 ;
          end;
}
end;


begin
end.



