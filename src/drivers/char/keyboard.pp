{******************************************************************************
 *  keyboard.pp
 * 
 *  Keyboard management
 *
 *  CopyLeft 2002 GaLi & Edo
 *
 *  version 0.4 - 04/06/2003 - GaLi - Rewrite keyboard_interrupt
 *
 *  version 0.3 - 23/04/2003 - GaLi - Add support for the BackSpace key (in
 *                                    keyboard_read)
 *
 *  version 0.2 - 24/02/2003 - GaLi - Add keyboard_read (seems to work)
 *
 *  version 0.0 - ??/??/2001 - GaLi, Edo - Initial version
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
{$I major.inc}
{$I process.inc}
{$I tty.inc}


{DEFINE DEBUG_KEYBOARD_READ}
{DEFINE DEBUG}
{$DEFINE BOCHS}


{ External procedures and functions }

procedure change_tty (ontty : byte);external;
procedure csi_J (vpar : dword ; ontty : byte); external;
procedure dump_dev;external;
procedure dump_mem;external;
procedure dump_task;external;
procedure enable_IRQ (irq : byte); external;
function  inb(port : word) : byte; external;
procedure interruptible_sleep_on (p : PP_wait_queue); external;
procedure interruptible_wake_up (p : PP_wait_queue); external;
procedure lock_inode (inode : P_inode_t); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure outb(port : word; val : byte); external;
procedure printk (format : string ; args : array of const);external;
procedure putchar (car : char); external;
procedure register_chrdev (nb : byte ; name : string[20] ; fops : pointer); external;
procedure reset_computer; external;
procedure set_intr_gate (n : dword ; addr : pointer); external;
procedure unlock_inode (inode : P_inode_t); external;
procedure update_cursor (ontty : byte); external;


{ Procedures and functions defined in this file }

type
   P_byte = ^byte;

procedure init_keyboard;
function  keyboard_close (fichier : P_file_t) : dword;
procedure keyboard_interrupt;
function  keyboard_ioctl (fichier : P_file_t ; req : dword ; argp : pointer) : dword;
function  keyboard_open (inode : P_inode_t ; fichier : P_file_t) : dword;
function  keyboard_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
procedure set_leds (leds : byte);
function  translate (scancode : byte ; keycode : P_byte) : dword;
procedure write_buffer (car : char);

function  do_alt   (keycode : byte ; up : boolean) : char;
function  do_altgr (keycode : byte ; up : boolean) : char;
function  do_ctrl  (keycode : byte ; up : boolean) : char;
function  do_clear (keycode : byte ; up : boolean) : char;
function  do_debug (keycode : byte ; up : boolean) : char;
function  do_func  (keycode : byte ; up : boolean) : char;
function  do_magic (keycode : byte ; up : boolean) : char;
function  do_maj   (keycode : byte ; up : boolean) : char;
function  do_num   (keycode : byte ; up : boolean) : char;
function  do_numlock (keycode : byte ; up : boolean) : char;
function  do_self  (keycode : byte ; up : boolean) : char;
function  do_shift (keycode : byte ; up : boolean) : char;
function  do_suppr (keycode : byte ; up : boolean) : char;
function  nop      (keycode : byte ; up : boolean) : char;


{ External variables }

var
   tty         : array[0..7] of tty_struct; external name  'U_TTY__TTY';
   current     : P_task_struct; external name 'U_PROCESS_CURRENT';
   current_tty : byte; external name  'U_TTY__CURRENT_TTY';


IMPLEMENTATION


var
   keyboard_fops : file_operations;
   prev_scancode : dword;
   shift, alt, altgr, ctrl, maj, num : boolean;
   leds : byte;


{$I keyboard.inc}



{******************************************************************************
 * init_keyboard
 *
 *****************************************************************************}
procedure init_keyboard; [public, alias : 'INIT_KEYBOARD'];

var
   i, j : byte;

begin

   leds := 0;
   set_leds(leds);
   set_intr_gate(33, @keyboard_interrupt);   { On installe le gestionnaire }
   enable_IRQ(1);

   for i := 0 to 7 do   { Initialisation des buffers de chaque console }
       with tty[i] do
       begin
          next_c := 0 ;
          last_c := 0 ;
          depassement := FALSE;
          for j := 0 to MAX_BUFF_CLAV do
              buffer_keyboard[j] := #0;
       end;

   prev_scancode := 0;
   shift         := FALSE;
   alt           := FALSE;
   altgr         := FALSE;
   ctrl          := FALSE;
   maj           := FALSE;
   num           := FALSE;

   memset(@keyboard_fops, 0, sizeof(file_operations));
   keyboard_fops.open  := @keyboard_open;
   keyboard_fops.read  := @keyboard_read;
   keyboard_fops.close := @keyboard_close;
   keyboard_fops.ioctl := @keyboard_ioctl;

   register_chrdev (KEYB_MAJOR, 'keyb', @keyboard_fops);

{	outb_p(inb_p(0x21)&0xfd,0x21);
	a=inb_p(0x61);
	outb_p(a|0x80,0x61);
	outb_p(a,0x61);   }

end;



{******************************************************************************
 * do_magic
 *
 *****************************************************************************}
function do_magic (keycode : byte ; up : boolean) : char;
begin

   if (not up) then
   begin
      printk('\nWelcome in DelphineOS kernel hacking mode !!!\n', []);
      printk('It does nothing for the moment, sorry...\n', []);
      result := #0;
   end;

end;



{******************************************************************************
 * nop
 *
 *****************************************************************************}
function nop (keycode : byte ; up : boolean) : char;
begin
   if (not up) then printk('%h2', [keycode]);
   result := #0;
end;



{******************************************************************************
 * do_self
 *
 *****************************************************************************}
function do_self (keycode : byte ; up : boolean) : char;
begin

   if (not up) then
   begin
      if (shift) xor (maj) then result := shift_map[keycode]
      else if (shift) and (maj) then result := normal_map[keycode]
      else if (alt) then result := alt_map[keycode]
      else if (altgr) then result := altgr_map[keycode]
      else result := normal_map[keycode];
   end;

end;



{******************************************************************************
 * do_suppr
 *
 *****************************************************************************}
function do_suppr (keycode : byte ; up : boolean) : char;
begin
   if (ctrl) and (alt) then reset_computer();
   result := #0;
end;



{******************************************************************************
 * do_func
 *
 *****************************************************************************}
function do_func (keycode : byte ; up : boolean) : char;
begin
   {$IFDEF BOCHS}
      if (not up) then change_tty(keycode - $3b);
   {$ELSE}
      if (not up) and (alt) then change_tty(keycode - $3b);
   {$ENDIF}

   result := #0;
end;



{******************************************************************************
 * do_ctrl
 *
 *****************************************************************************}
function do_ctrl (keycode : byte ; up : boolean) : char;
begin
   if (not up) then ctrl := TRUE
   else ctrl := FALSE;
   result := #0;
end;



{******************************************************************************
 * do_shift
 *
 *****************************************************************************}
function do_shift (keycode : byte ; up : boolean) : char;
begin
   if (not up) then shift := TRUE
   else shift := FALSE;
   result := #0;
end;



{******************************************************************************
 * do_alt
 *
 *****************************************************************************}
function do_alt (keycode : byte ; up : boolean) : char;
begin
   if (not up) then alt := TRUE
   else alt := FALSE;
   result := #0;
end;



{******************************************************************************
 * do_altgr
 *
 *****************************************************************************}
function do_altgr (keycode : byte ; up : boolean) : char;
begin
   if (not up) then altgr := TRUE
   else altgr := FALSE;
   result := #0;
end;



{******************************************************************************
 * do_maj
 *
 *****************************************************************************}
function do_maj (keycode : byte ; up : boolean) : char;
begin
   if (not up) then
   begin
      if (maj = TRUE) then
      begin
         maj := FALSE;
	 leds := leds and (not 4);
	 set_leds(leds);
      end
      else
      begin
         maj := TRUE;
	 leds := leds or 4;
	 set_leds(leds);
      end;
   end;
   result := #0;
end;



{******************************************************************************
 * do_numlock
 *
 *****************************************************************************}
function do_numlock (keycode : byte ; up : boolean) : char;
begin
   if (not up) then
   begin
      if (num = TRUE) then
      begin
         num := FALSE;
	 leds := leds and (not 2);
	 set_leds(leds);
      end
      else
      begin
         num := TRUE;
	 leds := leds or 2;
	 set_leds(leds);
      end;
   end;
   result := #0;
end;



{******************************************************************************
 * do_num
 *
 *****************************************************************************}
function do_num (keycode : byte ; up : boolean) : char;
begin
   if (not up) then
   begin
      if (num) then result := do_self(keycode, up)
      else result := #0;
   end;
end;



{******************************************************************************
 * do_debug
 *
 *****************************************************************************}
function do_debug (keycode : byte ; up : boolean) : char;
begin

   if (not up) then
   begin
      case (keycode) of
         kbF9 : dump_task;
         kbF10: dump_mem;
	 kbF11: dump_dev;
      end;
   end;
   result := #0;
end;



{******************************************************************************
 * do_clear
 *
 * FIXME: Only works on the first console
 *****************************************************************************}
function do_clear (keycode : byte ; up : boolean) : char;
begin

   if (up) then result := #0
   else if (ctrl) then
   begin
      asm
         pushfd
	 cli
      end;
      csi_J(2, current_tty);
      tty[current_tty].x := 0;
      tty[current_tty].y := -1;
      result := #10;
      asm
         popfd
      end;
   end
   else result := do_self(keycode, up);

end;



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
           tmp := inb($64);
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
 * FIXME: Ne marche pas sur un de mes claviers !!!
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
 * translate
 *
 * Convert scancode to keycode
 *
 * NOTE: code inspired from linux 2.4.20 drivers/char/pc_keyb.c
 *****************************************************************************}
function translate (scancode : byte ; keycode : P_byte) : dword;
begin

   { special prefix scancodes... }
   if (scancode = $E0) or (scancode = $E1) then
   begin
      prev_scancode := scancode;
      result := 0;
      exit;
   end;

   { 0xFF is sent by a few keyboards, ignore it. 0x00 is error }
   if (scancode = $00) or (scancode = $FF) then
   begin
      prev_scancode := 0;
      result := 0;
      exit;
   end;

   scancode := scancode and $7F;

   if (prev_scancode <> 0) then
   begin

      {* usually it will be 0xe0, but a Pause key generates
       * e1 1d 45 e1 9d c5 when pressed, and nothing when released *}

      if (prev_scancode <> $E0) then
          begin
             if (prev_scancode = $E1) and (scancode = $1D) then
	     begin
	        prev_scancode := $100;
	        result := 0;
	        exit;
	     end
	     else if (prev_scancode = $100) and (scancode = $45) then
	     begin
	        keycode^ := E1_PAUSE;
	        prev_scancode := 0;
	     end
	     else
	     begin
	        printk('WARNING translate: unknown e1 escape sequence\n', []);
	        prev_scancode := 0;
	        result := 0;
	        exit;
	     end;
          end   { (prev_scancode <> $E0) }
      else
          begin

	     prev_scancode := 0;

	     if (scancode = $2A) or (scancode = $36) then
	     begin
	        result := 0;
		exit;
	     end;

	     if (e0_keys[scancode] <> 0) then
	         keycode^ := e0_keys[scancode]
	     else
	     begin
	        printk('WARNING translate: unknown scancode e0 %h2\n', [scancode]);
		result := 0;
		exit;
	     end;
	     
          end;

   end   { (prev_scancode <> 0) }
   else if (scancode >= SC_LIM) and (scancode <> $7a) and (scancode <> $7e) then   { FIXME: what are those scancodes ? ($7a and $7e) }
   begin
      printk('WARNING translate: unknown scancode %h2\n', [scancode]);
      result := 0;
      exit;
   end
   else
      keycode^ := scancode;

   result := 1;

end;



{******************************************************************************
 * write_buffer
 *
 * This procedure write a character in the current tty buffer
 *****************************************************************************}
procedure write_buffer (car : char);
begin

   with tty[current_tty] do
   begin
      if (depassement) then printk('keyb: buffer overflow for tty%d \n',[current_tty])
      else
      begin
         buffer_keyboard[next_c] := car;   { on rempli le buffer circulaire }
	 next_c += 1;
	 if (next_c > MAX_BUFF_CLAV) then next_c := 0;
	 if (next_c = last_c) then depassement := TRUE;   { est ce que le buffer est rempli ? }
      end;

      {$IFDEF DEBUG_KEYBOARD_READ}
         if (keyboard_wq^.task <> NIL) then
             printk('write_buffer: waking up process %h\n', [keyboard_wq^.task]);
      {$ENDIF}
      interruptible_wake_up(@keyboard_wq);   { Réveille les processus qui attendaient des caractères }

   end;

end;



{******************************************************************************
 * keyboard_interrupt
 *
 *****************************************************************************}
procedure keyboard_interrupt; interrupt; [ public, alias : 'KEYBOARD_INTERRUPT'];

var
   scancode, status, keycode : byte;
   car  : char;
   wkey : word;
   work : dword;
   up   : boolean;

label out;

begin

   outb($20, $20);   { FIXME: I don't know where to put this exactly }

   work   := 10000;
   status := inb($64);

   while ((work > 0) and ((status and 1) = 1)) do
   begin

      scancode := inb($60);
      if (scancode and $80) = $80 then
          up := TRUE
      else
          up := FALSE;

      if (status and ($40 or $80)) = 0 then   { See Linux 2.4.20 drivers/char/pc_keyb.c }
      begin
	 if (translate(scancode, @keycode) = 0) then goto out;
{printk('(%h2, %h2)', [scancode, keycode]);}
	 car := func_map[keycode](keycode, up);
	 if (car <> #0) then write_buffer(car);
      end;

      work -= 1;
      status := inb($64);

   end;

   if (work = 0) then
      printk('WARNING keyboard_interrupt: status=%h2\n', [status]);

out:

end;



{******************************************************************************
 * keyboard_read
 *
 *****************************************************************************}
function keyboard_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [public, alias : 'KEYBOARD_READ'];

var
   i   : dword;
   orig_x, orig_y, ontty : byte;
   car : char;

begin

   unlock_inode(fichier^.inode);

   {$IFDEF DEBUG_KEYBOARD_READ}
      printk('Welcome in keyboard_read...(buf=%h, count=%d) PID=%d\n', [buf, count, current^.pid]);
   {$ENDIF}

   if (count = 0) then
       begin
          result := 0;
	  lock_inode(fichier^.inode);
          exit;
       end;

   if (buf < pointer($FFC00000)) then
       begin
          result := -EINVAl;
	  lock_inode(fichier^.inode);
	  exit;
       end;
 
   ontty := current^.tty;
   if (ontty = $FF) then
   begin
      printk('keyboard_read: process has no tty\n', []);
      result := -1;   { FIXME: another error code ??? }
      lock_inode(fichier^.inode);
      exit;
   end;
 
   i := 0;
   orig_x := tty[ontty].x;
   orig_y := tty[ontty].y;

   with tty[ontty] do
   begin
      while (count > 0) do
      begin
	 {$IFDEF DEBUG_KEYBOARD_READ}
	    printk(' count=%d, i=%d\n', [count, i]);
	 {$ENDIF}
        
         while (next_c = last_c) do
	 begin
	    {$IFDEF DEBUG_KEYBOARD_READ}
	       printk('keyboard_read: make %d sleep (count=%d)\n', [current^.pid, count]);
	    {$ENDIF}
	    interruptible_sleep_on(@keyboard_wq);
	 end;

         {$IFDEF DEBUG_KEYBOARD_READ}
	    printk('%c ', [buffer_keyboard[last_c]]);
	 {$ENDIF}

	 car := buffer_keyboard[last_c];
	 
	 if (car = #08) then   { BackSpace ??? }
	     begin
	        asm
		   mov   edi, buf
		   mov   al , car
		   mov   byte [edi], al
		end;
	        last_c += 1;
	        if (last_c > MAX_BUFF_CLAV) then last_c := 0;

                {$IFDEF DEBUG_KEYBOARD_READ}
	           printk('keyboard_read: last_c=%d  next_c=%d ', [last_c, next_c]);
	        {$ENDIF}

		if ((y > orig_y) or ((x > orig_x) and (y >= orig_y))) then
		     begin
	                putchar(#08);
			{count += 1;}
			buf   -= 1;
			i     -= 1;
		     end;

	     end   { (car = #08) }
	 else
	     begin
	        asm
	           mov   edi, buf
	           mov   al , car
	           mov   byte [edi], al
	        end;
	        buf    += 1;
	        last_c += 1;
		if (echo) then putchar(car);
	        if (last_c > MAX_BUFF_CLAV) then last_c := 0;

                {$IFDEF DEBUG_KEYBOARD_READ}
	           printk('keyboard_read: last_c=%d  next_c=%d ', [last_c, next_c]);
	        {$ENDIF}

                i      += 1;
                count  -= 1;

		if (last_c <> 0) then
		begin
	           if (buffer_keyboard[last_c - 1] = #10) then   { Carriage return ??? }
	               break;
		end
		else
		begin
		   if (buffer_keyboard[last_c] = #10) then   { Carriage return ??? }
		       break;
		end;

	     end;   { (car <> #08) }
	     
      end;   { while (count > 0) }
   end;   { with tty[ontty] }

   {$IFDEF DEBUG_KEYBOARD_READ}
      printk('keyboard_read: result=%d\n', [i]);
   {$ENDIF}

   lock_inode(fichier^.inode);

   result := i;

end;



{******************************************************************************
 * keyboard_open
 *
 *****************************************************************************}
function keyboard_open (inode : P_inode_t ; fichier : P_file_t) : dword;
begin

   if (current^.tty = $FF) then
   begin
      printk('keyboard_open: process has no tty\n', []);
      result := -1;
   end
   else
      result := 0;
end;



{******************************************************************************
 * keyboard_close
 *
 * FIXME: this function does nothing
 *****************************************************************************}
function keyboard_close (fichier : P_file_t) : dword;
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



