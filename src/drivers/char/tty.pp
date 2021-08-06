{******************************************************************************
 *  tty.pp
 * 
 *  Console management
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.7a - 09/05/2003  - GaLi - Begin "escape" code management.
 *
 *  version 0.7  - 22/12/2002  - GaLi - Correct a bug (line and column number).
 *
 *  version 0.6  - 29/06/2002  - Edo & GaLi - Habby perfday
 *                                          - printk prend en charge les
 *                                            chaînes passées en paramètre
 *                                          - Enregistrement de tty en tant que
 *                                            péripherique
 *
 *  version 0.5b - 08/03/2002  - GaLi - Ajout de nouvelles séquences de
 *                                      caractères speciaux
 * 
 *  version 0.5a - 22/02/2002  - GaLi - Correction d'un léger bug au niveau du
 *                                      scrolling
 *
 *  version 0.4  - 07/02/2002  - GaLi - Correction d'une 'erreur a la con' par
 *                                      Edo. Merci beaucoup :-)
 *
 *  version 0.1  - ??/12/2001  - GaLi - Initial version
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


unit tty_;


INTERFACE


{DEFINE DEBUG}
{DEFINE DEBUG_TTY_IOCTL}
{DEFINE DEBUG_TTY_OPEN}
{DEFINE DEBUG_TTY_READ}
{DEFINE DEBUG_TTY_WRITE}

{$I errno.inc}
{$I font_8x16.inc}
{$I fs.inc}
{$I major.inc}
{$I process.inc}
{$I termios.inc}
{$I tty.inc}


procedure dump_task; external;
function  get_free_page : pointer; external;
function  get_buffer_keyboard(tty : P_tty_struct ; idx : dword) : char; external;
procedure init_lock (rw : P_rwlock_t); external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure print_byte (nb : byte ; tty : P_tty_struct); external;
procedure print_dec_dword (nb : dword ; tty : P_tty_struct); external;
procedure print_dword (nb : dword ; tty : P_tty_struct); external;
procedure print_port (nb : word ; tty : P_tty_struct); external;
procedure print_word (nb : word ; tty : P_tty_struct); external;
procedure push_page (page_addr : pointer); external;
function  wait_for_keyboard (fichier : P_file_t ; tty : P_tty_struct ; idx : dword) : char; external;


function  alloc_tty : P_tty_struct;
procedure change_tty (tty_index : byte);
procedure csi_J (vpar : dword ; tty_index : byte);
procedure csi_m (tty_index : byte);
procedure free_tty (tty : P_tty_struct);
procedure get_vesa_info;
procedure init_tty;
procedure printk (format : string ; args : array of const);
procedure putc (car : char ; tty_index : byte);
procedure putchar (car : char);
procedure read_lock (rw : P_rwlock_t); external;
procedure read_unlock (rw : P_rwlock_t); external;
function  tty_close (fichier : P_file_t) : dword;
function  tty_ioctl (fichier : P_file_t ; req : dword ; argp : pointer) : dword;
function  tty_open (inode : P_inode_t ; filp : P_file_t) : dword;
function  tty_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function  tty_seek (fichier : P_file_t ; offset, whence : dword) : dword;
function  tty_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
procedure update_cursor (tty_index : byte);
procedure write_lock (rw : P_rwlock_t); external;
procedure write_unlock (rw : P_rwlock_t); external;


const
   screen_resolution = 80 * 25;
   screen_size = screen_resolution * 2;     { 4000 bytes }
   video_ram_start = $B8000;


var
   ttys        : array[1..MAX_TTY] of P_tty_struct;
	first_tty   : tty_struct;
   current_tty : byte;
   current     : P_task_struct; external name 'U_PROCESS_CURRENT';
   tty_fops    : file_operations;



IMPLEMENTATION


{$I inline.inc}



{******************************************************************************
 * init_tty
 *
 * Initialise les consoles. Cette procédure met le numéro de ligne et de
 * colonne à 0 pour toutes les consoles sauf la première dont la ligne et la
 * colonne ont été stockées dans DX par src/boot/setup.S.
 *****************************************************************************}
procedure init_tty; [public, alias : 'INIT_TTY'];

var
   i, x, y : byte;
	h : dword;
	fb_addr : ^word;

begin

{	h := 72*16;

	fb_addr := $e0000000;

	for i := 0 to 15 do
	begin
		for x := 0 to 7 do
		begin
			if (fonts[h+i] and ($80 shr x)) <> 0 then
				 fb_addr^ := $FFFF;
			fb_addr += 1;
		end;
		fb_addr += 800 - 8;
	end;
}

	asm
      mov   byte y, dh
      mov   byte x, dl
   end;

   memset(@tty_fops, 0, sizeof(file_operations));
   tty_fops.open  := @tty_open;
   tty_fops.read  := @tty_read;
   tty_fops.write := @tty_write;
   tty_fops.close := @tty_close;
   tty_fops.seek  := @tty_seek;
   tty_fops.ioctl := @tty_ioctl;

   {* REMARQUE: On ne peut pas appeler register_chrdev() ici car la table
    * chrdevs n'est pas encore initialisée. L'enregistrement du périphérique
    * 'tty' se fait donc dans init_vfs.pp *}

   memset(@ttys, 0, sizeof(ttys));

	{* first_tty initialization
	 *
	 * NOTE: we don't allocate first_tty.buffer_keyboard here. It's done in
	 *       src/kernel/main.pp because we cannot yet call get_free_page() *}

	memset(@first_tty, 0, sizeof(tty_struct));

	first_tty.x						:= x;
	first_tty.y						:= y;
	first_tty.attr   				:= 07;
	first_tty.keyboard_wq		:= NIL;
	first_tty.next_c 				:= 0;
	first_tty.last_c 				:= 0;
	first_tty.depassement		:= FALSE;
	first_tty.num_caps_scroll  := 0;
	first_tty.flags.c_iflag 	:= 0;
	first_tty.flags.c_oflag 	:= 0;
	first_tty.flags.c_cflag 	:= 0;
	first_tty.flags.c_lflag 	:= ECHO or ICANON;
	first_tty.count  				:= 1;

	init_lock(@first_tty.lock);

   current_tty 	   := 1;

	ttys[current_tty] := @first_tty;

   { Clear all consoles }

   asm
      cld
      mov   eax, $07200720        { L'erreur a la con venait d'ici !!! }
      mov   edi, video_ram_start
      add   edi, screen_size
      mov   ecx, 7000
      rep   stosd
   end;

   get_vesa_info();

end;



{******************************************************************************
 * alloc_tty
 *
 *****************************************************************************}
function alloc_tty : P_tty_struct;

var
	tty : P_tty_struct;

begin

	tty := kmalloc(sizeof(tty_struct));
	if (tty = NIL) then
	begin
		result := -ENOMEM;
		exit;
	end;

	memset(tty, 0, sizeof(tty_struct));   { Not necessary ??? }

	tty^.buffer_keyboard := get_free_page();
	if (tty^.buffer_keyboard = NIL) then
	begin
		printk('alloc_tty (%)d: cannot allocate keyboard buffer\n', [current^.pid]);
		kfree_s(tty, sizeof(tty_struct));
		result := -ENOMEM;
		exit;
	end;

	memset(tty^.buffer_keyboard, 0, 4096);   { Not necessary ??? }

	tty^.x					:= 0;
	tty^.y					:= 0;
	tty^.attr   			:= 07;
	tty^.keyboard_wq		:= NIL;
	tty^.next_c 			:= 0;
	tty^.last_c 			:= 0;
	tty^.depassement		:= FALSE;
	tty^.num_caps_scroll := 0;
	tty^.flags.c_iflag 	:= 0;
	tty^.flags.c_oflag 	:= 0;
	tty^.flags.c_cflag 	:= 0;
	tty^.flags.c_lflag 	:= ECHO or ICANON;
	tty^.count  			:= 1;

	init_lock(@tty^.lock);

	result := tty;

end;



{******************************************************************************
 * free_tty
 *
 *****************************************************************************}
procedure free_tty (tty : P_tty_struct);
begin

	tty^.count -= 1;
	if (tty^.count = 0) then
	begin
		if (tty^.last_c <> tty^.next_c) then
			 print_bochs('free_tty (%d): some characters in keyboard buffer\n', [current^.pid]);
		push_page(tty^.buffer_keyboard);
		kfree_s(tty, sizeof(tty_struct));
	end;

end;



{******************************************************************************
 * get_vesa_info
 *
 *****************************************************************************}
procedure get_vesa_info;

var
	vesa_mode_info : P_vesa_mode_info_t;
	vesa_pm_info	: P_vesa_pm_info_t;
   vesa_info    	: P_vesa_info_t;
	vesa_modes   	: ^word;
   oemstr       	: ^char;
	count 		 	: dword;

begin


	vesa_info := $10200;   { See boot/setup.S }

   if (vesa_info^.signature = $41534556) then
	{ VESA support is OK }
   begin
		print_bochs('\nVESA Info:', []);
		print_bochs('\n----------\n', []);
		print_bochs('capabilities=%h\nSupported modes:\n', [vesa_info^.capabilities]);

		vesa_mode_info := $10400;

		while (vesa_mode_info^.mode_attributes <> $FFFF) do
		begin

			print_bochs('%dx%dx%d',
			[vesa_mode_info^.x_resolution, vesa_mode_info^.y_resolution,
			 vesa_mode_info^.bits_per_pixel]);

			if (vesa_mode_info^.mode_attributes and $80) = $80 then
			begin
				print_bochs(' => Linear frame buffer@%h (%d bytes)\n',
				[vesa_mode_info^.phys_base_ptr, vesa_info^.memory shl 16]);
			end
			else
				print_bochs('\n', []);

			vesa_mode_info += 1;

		end;

		exit;

	end;

	exit;

   if (vesa_info^.signature = $41534556) then
   begin

print_bochs('\nVESA Info: %d', [sizeof(vesa_mode_info_t)]);
print_bochs('\n----------\n', []);
print_bochs('capabilities=%h\nSupported modes:\n', [vesa_info^.capabilities]);

		vesa_modes := pointer((hi(longint(vesa_info^.modes)) shl 4) +
									  lo(longint(vesa_info^.modes)));

		count := 0;
		while (vesa_modes[count] <> $FFFF) do
		begin
			print_bochs('%h4\n', [vesa_modes[count]]);
			count += 1;
		end;

print_bochs('count=%d %h %h\n', [count, vesa_info^.modes, vesa_modes]);

      printk('VESA %d.%d BIOS found (', [hi(vesa_info^.version), lo(vesa_info^.version)]);
      oemstr := pointer(hi(longint(vesa_info^.oemstr)) shl 4 + lo(longint(vesa_info^.oemstr)));
      repeat
         printk('%c', [oemstr^]);
	 		oemstr += 1;
      until (oemstr^ = #0);
      printk('), %dKb\n', [vesa_info^.memory shl 6]);

		{* Try to get protected mode entry point *}

		vesa_pm_info := $C0000;
		repeat
			if (vesa_pm_info^.signature = $44494D50) then
			begin
				print_bochs('A protected mode entry point has been found at %h\n',
								[vesa_pm_info]);
				break;
			end;

			longint(vesa_pm_info) += 4;
		until (longint(vesa_pm_info) >= $EFFFF);

   end
	else
	begin

   	vesa_info := $10200;   { See boot/setup.S }

   	if (vesa_info^.signature = $41534556) then
   	begin
      	printk('VESA %d.%d BIOS found (', [hi(vesa_info^.version), lo(vesa_info^.version)]);
      	oemstr := pointer(hi(longint(vesa_info^.oemstr)) shl 4 + lo(longint(vesa_info^.oemstr)));
      	repeat
         	printk('%c', [oemstr^]);
	 			oemstr += 1;
      	until (oemstr^ = #0);
			printk(')\n', []);
   	end;
	end;

end;



{******************************************************************************
 * putc
 *
 * Entrée : caractère à écrire, numéro de la console
 *
 * Ecris un caractère sur la console spécifiée
 *
 * NOTE : le caractère 0x0a (ou #10) est considéré comme un retour charriot
 *        le caractère 0x08 (ou #08) est considéré comme un backspace
 *        le caractère 0x09 (ou #09) est considéré comme une tabulation
 *****************************************************************************}
procedure putc (car : char ; tty_index : byte); [public,alias : 'PUTC'];

var
   ofs, dep, i          : dword;
   colonne, ligne, attr : byte;

begin

	pushfd();
	cli();

	{ FIXME: do this test only when in "DEBUG mode" }
	if (ttys[tty_index] = NIL) then tty_index := 1;

  	attr    := ttys[tty_index]^.attr;
  	ligne   := ttys[tty_index]^.y;
  	colonne := ttys[tty_index]^.x;
  	ofs     := (ligne * 160 + colonne * 2);
  	dep     := ((tty_index - 1) * screen_size);

   if (car = #10) then   { Caractère = retour charriot ? }
   begin
      ligne += 1;
      ofs   := (ligne * 160);
   end
	else if (car = #09) then
	begin
		i := 8 - colonne;
		if (i = 0) then i := 8;

      asm
	 		mov   edi, ofs
	 		add   edi, dep
	 		add   edi, video_ram_start

			mov   ecx, i

			@tab:
	 			mov   ah , attr
	 			mov   al , $20
	 			mov   word [edi], ax
				add   edi, 2
			loop  @tab
      end;
		ofs += i * 2;
	end
   else if (car = #08) then   { Backspace ?? }
   begin
      asm
	 		mov   edi, ofs
	 		add   edi, dep
	 		add   edi, video_ram_start
	 		sub   edi, 2
	 		mov   ah , attr
	 		mov   al , $20
	 		mov   word [edi], ax
      end;
      ofs -= 2;
   end
   else
   begin
      asm
         mov   edi, ofs
         add   edi, dep
         add   edi, video_ram_start
         mov   ah , attr
         mov   al , car
         mov   word [edi], ax
      end;
      ofs += 2;
   end;

   if (ofs >= screen_size) then  { On est arrivé au bout de l'écran }
   begin

      ofs := 24 * 80 * 2;

      asm
         mov   esi, video_ram_start
         add   esi, dep
         mov   edi, esi
         add   esi, 160
         mov   ecx, 960
         rep   movsd

         {mov   eax, $07200720}
	 		mov   ah , attr
	 		mov   al , $20
	 		shl   eax, 16
	 		mov   ah , attr
	 		mov   al , $20
         mov   ecx, 40
         rep   stosd
      end;
   end;

   { On remet le numéro de ligne et de colonne dans le tableau tty_state }

   ofs := ofs div 2;
   ttys[tty_index]^.y := ofs div 80; { Ligne }
   ttys[tty_index]^.x := ofs mod 80; { Colonne }

   { On doit mettre à jour la position du curseur à l'écran }

   if (tty_index = current_tty) then update_cursor(tty_index);

	popfd();

end;



{******************************************************************************
 * putchar
 *
 * Entrée : caractère à écrire
 *
 * Ecris un caractère dans la console courante
 *****************************************************************************}
procedure putchar (car : char); [public, alias : 'PUTCHAR'];
begin
   putc(car, current_tty);
end;



{******************************************************************************
 * printk
 *
 * Entrée : format de la chaîne de caractères, paramètre(s)
 *
 * Ecris une chaîne de caractère sur la console active. Cette procédure
 * fonctionne un peu comme celle du C.
 * 
 * Syntaxe minimale :
 * 
 * printk('', []);
 * 
 * La chaîne de caractère à afficher doit être entre '' et non pas entre "",
 * les crochets sont OBLIGATOIRES, même s'il n'y a rien dedans. Les crochets
 * servent à indiquer les variables à afficher
 * 
 * Séquences de caractères spéciaux reconnus :
 *     - %s  : affiche une chaîne de caractères
 *     - %d  : affiche une variable en décimal
 *     - \n  : affiche un retour charriot
 *     - %h  : affiche une variable en héxadécimal (8 chiffres affichés)
 *     - %h4 : affiche une variable en héxadécimal (4 chiffres affichés)
 *     - %h3 : affiche une variable en héxadécimal (3 chiffres affichés)
 *     - %h2 : affiche une variable en héxadécimal (2 chiffres affichés)
 *
 * Exemple : printk('Hello %d %h %s\n', [var1, var2, chaine]);
 *****************************************************************************}
procedure printk (format : string ; args : array of const); [public,alias:'PRINTK'];

var
   pos,tmp  : byte;
   num_args : dword;
	tty      : P_tty_struct;

begin

	pushfd();
	cli();

	tty		:= @tty[current_tty];
   pos      := 1;
   num_args := 0;

   while (format[pos] <> #0) do
   begin
      case (format[pos]) of
      '%': begin
              pos += 1;
              case (format[pos]) of
	      	  'c' : begin
							  putchar(args[num_args].Vchar);
			   			  pos := pos + 1;
			   			  num_args += 1;
		         	  end;
              'd' : begin
                       print_dec_dword(args[num_args].Vinteger, tty);
                       pos := pos + 1;
                       num_args += 1;
                    end;
              'h' : begin
		         		  case (format[pos+1]) of
				   		  '2': begin
			             			 print_byte(args[num_args].Vinteger, tty);
				      	 			 pos += 1;
				   	 			 end;
							  '3': begin
			               		 print_port(args[num_args].Vinteger, tty);
				      				 pos += 1;
				   				 end;
			      		  '4': begin
			               		 print_word(args[num_args].Vinteger, tty);
				      				 pos += 1;
			            		 end;
			      		  else
                            print_dword(args[num_args].Vinteger, tty);
			   		     end;

                       pos += 1;
                       num_args += 1;
                    end;
              's' : begin
                       tmp := 0;
                       while (args[num_args].VString^[tmp] <> #0) do
                       begin
                          putchar(args[num_args].VString^[tmp]);
                          tmp += 1;
                       end;
                       pos += 1;
                       num_args += 1;
                    end;
              else
				   	  putchar('%');
              end;
           end;
      '\': begin
              pos += 1;
              if (format[pos] = 'n') then
              begin
                 putchar(#10);
                 pos += 1;
              end;
           end;
           else
           { On n'a pas à faire à un caractère spécial }
           begin
              putchar(format[pos]);
	           pos += 1;
           end;
      end;
   end;

	popfd();

end;



{******************************************************************************
 * change_tty
 *
 * Entry : Console number
 *
 * Change active console.
 *****************************************************************************}
procedure change_tty (tty_index : byte); [public, alias : 'CHANGE_TTY'];

var
   ofs : word;

begin

   ofs := (tty_index - 1) * screen_resolution;

   asm
      pushfd
      cli                    { Section critique }
      mov   bx , ofs
      mov   dx , $3D4
      mov   al , $0C
      out   dx , al
      inc   dx               { DX = 0x3D5 }
      mov   al , bh
      out   dx , al
      dec   dx               { DX = 0x3D4 }
      mov   al , $0D
      out   dx , al
      inc   dx               { DX = 0x3D5 }
      mov   al , bl
      out   dx , al
   end;

   current_tty := tty_index;

   update_cursor(tty_index);
   
	popfd();

end;



{******************************************************************************
 * update_cursor
 *
 * Entrée : numéro de la console
 *
 * Met à jour le curseur sur la console specifiée.
 *
 *****************************************************************************}
procedure update_cursor (tty_index : byte); [public, alias : 'UPDATE_CURSOR'];

var
   ofs : word;

begin

   ofs := (ttys[tty_index]^.y * 80 + ttys[tty_index]^.x) +
			 ((tty_index - 1) * screen_resolution);

   asm
      pushfd
      cli
      mov   bx , ofs
      mov   dx , $3D4
      mov   al , $0E
      out   dx , al
      inc   dx               { DX = 0x3D5 }
      mov   al , bh
      out   dx , al
      dec   dx               { DX = 0x3D4 }
      mov   al , $0F
      out   dx , al
      inc   dx               { DX = 0x3D5 }
      mov   al , bl
      out   dx , al
      popfd
   end;
end;




{******************************************************************************
 * tty_open
 *
 *****************************************************************************}
function tty_open (inode : P_inode_t ; filp : P_file_t) : dword;

var
	tty : P_tty_struct;
	tty_index : byte;

begin

	tty_index := inode^.rdev_min;
	if (tty_index > MAX_TTY) then
	begin
		result := -ENODEV;
		exit;
	end;

	{$IFDEF DEBUG_TTY_OPEN}
		printk('tty_open: %d\n', [tty_index]);
	{$ENDIF}

	tty := ttys[tty_index];

	{ Is tty already opened ? }
	if (tty <> NIL) then
	begin
		{$IFDEF DEBUG_TTY_OPEN}
			printk('tty_open: already opened\n', []);
		{$ENDIF}
		tty^.count += 1;
		filp^.pos  := (tty^.y * 160) + (tty^.x * 2);
		result := 0;
		exit;
	end;

	{ tty is not opened }

	filp^.pos := 0;
	tty := alloc_tty();
	if (tty = NIL) then
	begin
		printk('tty_open: not enough memory\n', []);
		result := -ENOMEM;
		exit;
	end;

	ttys[tty_index] := tty;

   result := 0;

end;



{******************************************************************************
 * tty_close
 *
 *****************************************************************************}
function tty_close (fichier : P_file_t) : dword;

var
   tty : P_tty_struct;


begin

	tty := ttys[fichier^.inode^.rdev_min];
	if (tty = NIL) then
	begin
		printk('tty_close (%d): tty%d not opened\n', [current^.pid, fichier^.inode^.rdev_min]);
		result := -EINVAL;   { FIXME: another error code ??? }
		exit;
	end;

	printk('tty_close (%d): %d\n', [current^.pid, fichier^.inode^.rdev_min]);

	free_tty(tty);

   result := 0;

end;



{******************************************************************************
 * tty_read
 *
 *****************************************************************************}
function tty_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [public, alias : 'TTY_READ'];

var
	car 				: char;
	tty 				: P_tty_struct;
	tty_index		: byte;
	read_cars, i	: dword;
	orig_last_c		: dword;

begin

	{$IFDEF DEBUG_TTY_READ}
		printk('tty_read (%d): buf=%h count=%d (%d:%d)\n',
				 [current^.pid, buf, count, fichier^.inode^.rdev_maj,
				  fichier^.inode^.rdev_min]);
	{$ENDIF}

	tty_index := fichier^.inode^.rdev_min;
	tty 		 := ttys[tty_index];

	write_lock(@tty^.lock);

	orig_last_c := tty^.last_c;	
	read_cars   := 0;

	if ((tty^.flags.c_lflag and ICANON) = ICANON) then
	begin
		{$IFDEF DEBUG_TTY_READ}
			printk('tty_read (%d): canonical mode\n', [current^.pid]);
		{$ENDIF}
		
		repeat
			car := get_buffer_keyboard(tty, (tty^.last_c + read_cars) mod MAX_BUFF_CLAV);
			if (car = #0) then
			begin
				car := wait_for_keyboard(fichier, tty, (tty^.last_c + read_cars) mod MAX_BUFF_CLAV);
				case car of
					#8  : begin   { BackSpace ? }
								if (read_cars <> 0) then
								begin
									read_cars -= 2;
									tty^.next_c := (tty^.next_c - 2) and MAX_BUFF_CLAV;
									if ((tty^.flags.c_lflag and ECHO) = ECHO) then
									begin
										 putc(car, tty_index);
										 if (tty^.buffer_keyboard[tty^.next_c] = #27) then
										 	  putc(car, tty_index);
									end;
								end
								else
								begin   { Just remove the backspace from buffer_keyboard }
									read_cars   -= 1;
									tty^.next_c := (tty^.next_c - 1) and MAX_BUFF_CLAV;
								end;
							end;

					#27 : begin   { Escape ? }
								if ((tty^.flags.c_lflag and ECHO) = ECHO) then
								begin
									putc('^', tty_index);
									putc('[', tty_index);
								end;
							end;

					else 	begin   { global case }
								if ((tty^.flags.c_lflag and ECHO) = ECHO) then
								  	  putc(car, tty_index);
							end;
				end;
			end;
			read_cars += 1;
		until (car = #10);
	
		{$IFDEF DEBUG_TTY_READ}
			printk('tty_read (%d): read_cars=%d count=%d\n', [current^.pid, read_cars,
			count]);
		{$ENDIF}
	
		if (read_cars < count) then
			 count := read_cars;
	
		{ copy buffer_keyboard into buf }
		for i := 1 to count do 
		begin
			char(buf^) := tty^.buffer_keyboard[orig_last_c];
			buf += 1;
			orig_last_c += 1;
			if (orig_last_c > MAX_BUFF_CLAV) then orig_last_c := 0;
		end;

		tty^.last_c := orig_last_c;
			
	end
	else
	begin
		{$IFDEF DEBUG_TTY_READ}
			printk('tty_read (%d): non-canonical mode\n', [current^.pid]);
		{$ENDIF}
		while (count > 0) do
		begin
		end;
	end;

	write_unlock(@tty^.lock);

	{$IFDEF DEBUG_TTY_READ}
		printk('tty_read (%d):END: count : %d\n', [current^.pid, count]);
	{$ENDIF}

	result := count;

end;



{******************************************************************************
 * tty_write
 *
 * Entrée : fichier, pointeur, nb d'octets à écrire
 *
 * Sortie : Nombre d'octets écris ou -1 en cas d'erreur
 *
 * Cette fonction est appelée quand un appel systeme 'write' vise une console
 *
 * NOTE: code inspired from linux 0.12 (kernel/chr_drv/console.c)
 *****************************************************************************}
function tty_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [public, alias : 'TTY_WRITE'];

var
   i, state   : dword;
   npar       : dword;
   tty_index  : byte;
	tty        : P_tty_struct;
   car        : char;

begin

   tty_index := fichier^.inode^.rdev_min;
	tty := ttys[tty_index];

	{$IFDEF DEBUG_TTY_WRITE}
		print_bochs('tty_write: fichier=%h  buf=%h  count=%d  tty=%h (%d)\n',
						[fichier, buf, count, tty, tty^.count]);
	{$ENDIF}

   if ((tty^.flags.c_lflag and ECHO) = ECHO) then
   begin
      state := ESnormal;
      for i := 1 to count do
      begin
	    	car := chr(byte(buf^));
	    	case (state) of

	      	ESnormal:	begin
		      			 	 	if ((car = #11) or (car = #12)) then
							 	 	{ I've done this because I saw it in Linux  :-) }
		          			 		car := #10

		      			 	 	else if ((car > #31) and (car < #127) or (car = #10)) then
									{ Printable character }
		          		 	 	 	putc(car, tty_index)

		      			 	 	else if (car = #27) then
									{ Escape code }
		          			 	 	state := ESesc

		      			 	 	else if (car = #7) then
		          		 	 	begin
			      		 	 	 	{* FIXME: this is the 'bell' character.
								       * We've got to make some noise  :-) *}
			   			 	 	end

		      			 	 	else if (car = #8) then
									{ Baskspace character }
									begin
										putc(car, tty_index);
									end

									else if (car = #9) then
									{ tab character }
									begin
										putc(car, tty_index);
									end;

								end;
	       	ESesc: 	begin
		      				case (car) of
		         				'[': state := ESsquare
		      					else
		         					state := ESnormal;
		      				end;
	          			end;

	       	ESsquare:	begin
		      					{putc(car, ontty);}
		      					buf -= 1;
		      					i   -= 1;
		      					for npar := 0 to NBPAR do
		         					 tty^.par[npar] := 0;
		      					tty^.npar := 0;
		      					npar  := 0;
		      					state := ESgetpars;
		   					end;

	       	ESgetpars:	begin
		   						{putc(car, ontty);}
		      					if ((car = ';') and (npar <= NBPAR)) then
		          				begin
		             				npar += 1;
			      					tty^.npar += 1;
			   					end
		      					else if ((car >= '0') and (car <= '9')) then
		          					tty^.par[npar] := (tty^.par[npar] * 10) + ord(car) - ord('0')
		      					else
		          				begin
		             				state := ESgotpars;
			      					buf   -= 1;
			      					i     -= 1;
			   					end;
		   					end;

	       	ESgotpars:	begin
		      					state := ESnormal;
		      					case (car) of
		         					'J': csi_J(tty^.par[0], tty_index);
										'H': begin
			         						  if (tty^.par[0] <> 0) then
												   	tty^.par[0] -= 1;
												  if (tty^.par[1] <> 0) then
												   	tty^.par[1] -= 1;
												  tty^.x := tty^.par[1];
												  tty^.y := tty^.par[0];
			      						  end;
										'm': csi_m(tty_index);
		      					end;
		   					end;

				ESfunckey:	begin
		   					end;

				ESsetterm:	begin
		   					end;

	       	ESsetgraph: begin
		   					end;
	    
			end;   { ...case(state) }

			buf += 1;

		end;   { ...for }

		pushfd();
		cli();

      fichier^.pos := (tty^.y * 160) + (tty^.x * 2);

      i := fichier^.pos div 2;
      tty^.y := i div 80;
      tty^.x := i mod 80;
      if (tty_index = current_tty) then
          update_cursor(tty_index);

		popfd();
      
      result := count;
   end
   else
      result := 0;

end;



{******************************************************************************
 * tty_seek
 * 
 *   offset : number of chars
 *
 *****************************************************************************}
function tty_seek (fichier : P_file_t ; offset, whence : dword) : dword;
begin

   {$IFDEF DEBUG}
      printk('debut : %d\n',[fichier^.pos]);
   {$ENDIF}

   offset *= 2;

   case (whence) of
      SEEK_SET: begin
                   if (offset >= screen_size) then
                   begin
		         		 printk('tty_seek: offset > %d\n', [screen_size]);
			 				 result := -1;
			 				 exit;
		      		 end;
                   fichier^.pos := offset;
					 end;
      SEEK_CUR: begin
                   if (fichier^.pos + offset >= screen_size) then
		      		 begin
		         		 printk('tty_seek: current ofs + ofs > %d\n', [screen_size]);
			 				 result := -1;
			 				 exit;
		      		 end;
		   			 fichier^.pos += offset;
					 end;
      SEEK_END: begin
                   printk('tty_seek: seek beyond the end is impossible on TTY\n',[]);
		   			 result := -1;
		   			 exit;
                end;
      else
      begin
	   	printk('tty_seek: whence parameter has a bad value (%d)\n', [whence]);
	    	result := -EINVAL;
	    	exit;
	 	end;
   end;
  
   asm
      pushfd
      cli
   end;

printk('tty_seek: FIXME\n', []);
{   tty[current^.tty].y := fichier^.pos div 160;
   tty[current^.tty].x := (fichier^.pos div 2) mod 80;}

{   if (current^.tty = current_tty) then
       update_cursor(current_tty);}

   asm 
      popfd
   end;

   {$IFDEF DEBUG}
      printk('fin : %d\n',[fichier^.pos]);
   {$ENDIF}

   result := fichier^.pos;

end;



{******************************************************************************
 * tty_ioctl
 * 
 *
 *****************************************************************************}
function tty_ioctl (fichier : P_file_t ; req : dword ; argp : pointer) : dword;

var
   i              : dword;
	tty_index		: byte;
	tty_termios 	: P_termios;
	tmp_TCGETS     : P_termios;
	tmp_TCSETS     : P_termios;
   tmp_TIOCGWINSZ : P_winsize;

begin

   {$IFDEF DEBUG_TTY_IOCTL}
      printk('Welcome in tty_ioctl... (%h, %h4, %h)\n', [fichier, req, argp]);
   {$ENDIF}

   result := 0;

	tty_index   := fichier^.inode^.rdev_min;
	tty_termios := @ttys[tty_index]^.flags;

   case (req) of
      TCGETS:  	begin
                  	if (argp = NIL) then
		      	   	begin
		         	   	printk('tty_ioctl (TCGETS): argp=NIL\n', []);
		         	   	result := -EINVAL;
		      	   	end
		 			   	else
		      	   	begin
		         	   	tmp_TCGETS  := argp;
		         	   	tmp_TCGETS^.c_iflag := tty_termios^.c_iflag;
						   	tmp_TCGETS^.c_oflag := tty_termios^.c_oflag;
						   	tmp_TCGETS^.c_cflag := tty_termios^.c_cflag;
						   	tmp_TCGETS^.c_lflag := tty_termios^.c_lflag;

						   	{ FIXME: not implemented }
						   	tmp_TCGETS^.c_line  := 0;
						   	for i := 0 to (NCCS - 1) do
			    					 tmp_TCGETS^.c_cc[i] := 0;

						   	{printk('tty_ioctl (%d): TCGETS request\n', [current^.pid]);}
		      	   	end;
               	end;

      TCSETS:  	begin
                  	if (argp = NIL) then
		      	   	begin
		         	   	printk('tty_ioctl (TCSETS): argp=NIL\n', []);
		         	   	result := -EINVAL;
		      	   	end
		 			   	else
		      	   	begin
								tmp_TCSETS  := argp;
								tty_termios^.c_iflag := tmp_TCSETS^.c_iflag;
								tty_termios^.c_oflag := tmp_TCSETS^.c_oflag;
								tty_termios^.c_cflag := tmp_TCSETS^.c_cflag;
								tty_termios^.c_lflag := tmp_TCSETS^.c_lflag;
							end;
      	       	end;

      TCSETSW: 	begin
							{* FIXME: Same as TCSETS but wait before *}
      	       	end;

      TIOCGWINSZ: begin
                     tmp_TIOCGWINSZ := argp;   { FIXME: don't know what values should I return }
		      			tmp_TIOCGWINSZ^.ws_row := 25;
		      			tmp_TIOCGWINSZ^.ws_col := 80;
		      			tmp_TIOCGWINSZ^.ws_xpixel := 0;
		      			tmp_TIOCGWINSZ^.ws_ypixel := 0;
                  end;

      else
			begin
				printk('tty_ioctl (%d): unknown request (%h4)\n', [current^.pid, req]);
				result := -1;
			end;
   end;
end;



{******************************************************************************
 * csi_J
 *
 * NOTE: code inspired from linux 0.12 (kernel/chr_drv/console.c)
 *****************************************************************************}
procedure csi_J (vpar : dword ; tty_index : byte); [public, alias : 'CSI_J'];

var
   dep, count, start : dword;
   attr : byte;
	tty  : P_tty_struct;

begin

	tty  := ttys[tty_index];
   attr := tty^.attr;

   case (vpar) of
   0: begin   { erase from cursor to end of display }   { FIXME: need more tests (but should be ok) }
         dep   := ((tty_index - 1) * screen_size);
	 		start := tty^.y * 80 + tty^.x;
	 		count := screen_resolution - start;
      end;
   1: begin   { erase from start to cursor }   { FIXME: not tested (but should be ok) }
         dep   := ((tty_index - 1) * screen_size);
	 		start := 0;
	 		count := tty^.y * 80 + tty^.x;
      end;
   2: begin   { erase whole display }
	 		dep   := ((tty_index - 1) * screen_size);
	 		start := 0;
	 		count := screen_resolution;
      end;
   end;

   asm
      mov   edi, video_ram_start
      add   edi, dep
      add   edi, start
      mov   ecx, count
      mov   ah , attr
      mov   al , $20
      cld
      rep   stosw
   end;

end;


{******************************************************************************
 * csi_m
 *
 * NOTE: code inspired from linux 0.12 (kernel/chr_drv/console.c)
 *****************************************************************************}
procedure csi_m (tty_index : byte);

var
   i   : dword;
	tty : P_tty_struct;

begin

	tty := ttys[tty_index];

   for i := 0 to tty^.npar do
   begin
      case (tty^.par[i]) of
         00: tty^.attr := 07;   { Default }
         01: tty^.attr := tty^.attr or $08;    { Bold }
	 05: tty^.attr := tty^.attr or $80;    { Blinking }
	 07: tty^.attr := (tty^.attr shl 4) or (tty^.attr shr 4);   { Negative }
	 22: tty^.attr := tty^.attr and $F7;   { Not bold }
	 25: tty^.attr := tty^.attr and $7F;   { Not blinking }
	 27: tty^.attr := 07;   { Positive image (FIXME: don't know if it's correct to set 'attr' to 07) }
	 30: tty^.attr := (tty^.attr and $F8) or 0;   { Black foreground }
	 31: tty^.attr := (tty^.attr and $F8) or 4;   { Red foreground }
	 32: tty^.attr := (tty^.attr and $F8) or 2;   { Green foreground }
	 33: tty^.attr := (tty^.attr and $F8) or 6;   { Brown foreground }
	 34: tty^.attr := (tty^.attr and $F8) or 1;   { Blue foreground }
	 35: tty^.attr := (tty^.attr and $F8) or 5;   { Magenta (purple) foreground }
	 36: tty^.attr := (tty^.attr and $F8) or 3;   { Cyan (light blue) foreground }
	 37: tty^.attr := (tty^.attr and $F8) or 7;   { Gray foreground }
	 40: tty^.attr := (tty^.attr and $F8) or 0;   { Black background }
	 41: tty^.attr := (tty^.attr and $F8) or (4 shl 4);   { Red background }
	 42: tty^.attr := (tty^.attr and $F8) or (2 shl 4);   { Green background }
	 43: tty^.attr := (tty^.attr and $F8) or (6 shl 4);   { Brown background }
	 44: tty^.attr := (tty^.attr and $F8) or (1 shl 4);   { Blue background }
	 45: tty^.attr := (tty^.attr and $F8) or (5 shl 4);   { Magenta (purple) background }
	 46: tty^.attr := (tty^.attr and $F8) or (3 shl 4);   { Cyan (light blue) background }
	 47: tty^.attr := (tty^.attr and $F8) or (7 shl 4);   { White background }
      end;
   end;

end;



begin
end.
