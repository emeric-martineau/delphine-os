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

{$I errno.inc}
{$I fs.inc}
{$I major.inc}
{$I process.inc}
{$I termios.inc}
{$I tty.inc}


procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure print_byte (nb : byte); external;
procedure print_dec_dword (nb : dword); external;
procedure print_dword (nb : dword); external;
procedure print_port (nb : word); external;
procedure print_word (nb : word); external;


procedure change_tty (ontty : byte);
procedure csi_J (vpar : dword ; ontty : byte);
procedure csi_m (ontty : byte);
procedure get_vesa_info;
procedure init_tty;
procedure printk (format : string ; args : array of const);
procedure putc (car : char ; ontty : byte);
procedure putchar (car : char);
function  tty_close (fichier : P_file_t) : dword;
function  tty_ioctl (fichier : P_file_t ; req : dword ; argp : pointer) : dword;
function  tty_open (inode : P_inode_t ; filp : P_file_t) : dword;
function  tty_seek (fichier : P_file_t ; offset, whence : dword) : dword;
function  tty_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
procedure update_cursor (ontty : byte);


const
   screen_resolution = 80*25;
   screen_size = screen_resolution * 2;     { 4000 octets }
   video_ram_start = $B8000;


var
   tty         : array[0..7] of tty_struct;
   current_tty : byte;
   current     : P_task_struct; external name 'U_PROCESS_CURRENT';
   tty_fops    : file_operations;



IMPLEMENTATION



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

begin

   asm
      mov   byte y, dh
      mov   byte x, dl
   end;

   memset(@tty_fops, 0, sizeof(file_operations));
   tty_fops.open  := @tty_open;
   tty_fops.write := @tty_write;
   tty_fops.close := @tty_close;
   tty_fops.seek  := @tty_seek;
   tty_fops.ioctl := @tty_ioctl;

   {* REMARQUE: On ne peut pas appeler register_chrdev() ici car la table
    * chrdevs n'est pas encore initialisée. L'enregistrement du périphérique
    * 'tty' se fait donc dans init_vfs.pp *}

   memset(@tty, 0, sizeof(tty));
   tty[0].x    := x;
   tty[0].y    := y;
   tty[0].echo := TRUE;
   tty[0].attr := 07;

   for i := 1 to 7 do
   begin
      tty[i].echo := TRUE;
      tty[i].attr := 07;
   end;

   current_tty := 0;

   { Clear all consoles }

   asm
      cld
      mov   eax, $07200720        { L'erreur a la con venait d'ici !!! }
      mov   edi, video_ram_start
      add   edi, screen_size
      mov   ecx, 7000
      rep   stosd
   end;

   change_tty(0);

   get_vesa_info();

end;



{******************************************************************************
 * get_vesa_info
 *
 *****************************************************************************}
procedure get_vesa_info;

var
   vesa_info : P_vesa_info_t;
   oemstr    : ^char;

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
      printk('), %dKb\n', [vesa_info^.memory shl 6]);
   end;

end;



{******************************************************************************
 * putc
 *
 * Entrée : caractère à écrire, numéro de la console
 *
 * Ecris un caractère sur la console spécifiée
 *
 * NOTE : le caractère $0A (ou #10) est considéré comme un retour charriot
 *        le caractère $08 (ou #08) est considéré comme un backspace
 *****************************************************************************}
procedure putc (car : char ; ontty : byte); [public,alias : 'PUTC'];

var
   ofs, dep             : dword;
   colonne, ligne, attr : byte;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   attr    := tty[ontty].attr;
   ligne   := tty[ontty].y;
   colonne := tty[ontty].x;
   ofs     := (ligne * 160 + colonne * 2);
   dep     := (ontty * screen_size);

   if (car = #10) then   { Caractère = retour charriot ? }
   begin
      ligne += 1;
      ofs   := (ligne * 160);
   end
   else if (car = #08) then
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
   tty[ontty].y := ofs div 80; { Ligne }
   tty[ontty].x := ofs mod 80; { Colonne }

   { On doit mettre à jour la position du curseur à l'écran }

   if (ontty = current_tty) then update_cursor(ontty);

   asm
      popfd   { Fin section critique }
   end;

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
   pos,tmp : byte;
   num_args   : dword;

begin

   asm
      pushfd
      cli
   end;

   pos      := 1;
   num_args := 0;

   while (format[pos]<>#0) do
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
                                   print_dec_dword(args[num_args].Vinteger);
                                   pos := pos + 1;
                                   num_args += 1;
                                end;
                          'h' : begin
			           case (format[pos+1]) of
				      '2': begin
				              print_byte(args[num_args].Vinteger);
					      pos += 1;
					   end;
				      '3': begin
				              print_port(args[num_args].Vinteger);
					      pos += 1;
					   end;
				      '4': begin
				              print_word(args[num_args].Vinteger);
					      pos += 1;
				           end;
				      else
				           begin
                                              print_dword(args[num_args].Vinteger);
					   end;
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
                          else putchar('%');
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

   asm
      popfd
   end;

end;



{******************************************************************************
 * change_tty
 *
 * Entry : Console number
 *
 * Change active console. 'ontty' must be between 0 and 7 (no checks)
 *****************************************************************************}
procedure change_tty (ontty : byte); [public, alias : 'CHANGE_TTY'];

var
   ofs : word;

begin

   ofs := ontty * screen_resolution;

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

   current_tty := ontty;

   update_cursor(ontty);
   
   asm
     popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * update_cursor
 *
 * Entrée : numéro de la console
 *
 * Met à jour le curseur sur la console specifiée.
 *
 *****************************************************************************}
procedure update_cursor (ontty : byte); [public, alias : 'UPDATE_CURSOR'];

var
   ofs : word;

begin

   ofs := (tty[ontty].y * 80 + tty[ontty].x) + (ontty * screen_resolution);

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
begin

   asm 
      pushfd
      cli
   end;

   filp^.pos := (tty[current^.tty].y * 160) + (tty[current^.tty].x * 2);

   asm 
      popfd
   end;

   result := 0;

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
   ontty      : byte;
   car        : char;

begin

   ontty := fichier^.inode^.rdev_min;

   if (tty[ontty].echo) then
   begin
      state := ESnormal;
      for i := 1 to count do
         begin
	    car := chr(byte(buf^));
	    case (state) of
	       ESnormal:
	          begin
		     if ((car = #11) or (car = #12)) then   { I've done this because I saw it in Linux  :-) }
		          car := #10
		     else if ((car > #31) and (car < #127) or (car = #10)) then   { Printable character }
		          putc(car, ontty)
		     else if (car = #27) then   { Escape code }
		          state := ESesc
		     else if (car = #7) then
		          begin
			     {FIXME: this is the 'bell' character. We've got to make some noise  :-) }
			  end
		     else if (car = #8) then   { Baskspace character }
		          begin
			     putc(car, ontty);
			  end;
	          end;
	       ESesc:
	          begin
		     case (car) of
		        '[': state := ESsquare
		     else
		        state := ESnormal;
		     end;
	          end;
	       ESsquare:
	          begin
		     {putc(car, ontty);}
		     buf -= 1;
		     i   -= 1;
		     for npar := 0 to NBPAR do
		         tty[ontty].par[npar] := 0;
		     tty[ontty].npar := 0;
		     npar  := 0;
		     state := ESgetpars;
		  end;
	       ESgetpars:
	          begin
		  {putc(car, ontty);}
		     if ((car = ';') and (npar <= NBPAR)) then
		          begin
		             npar += 1;
			     tty[ontty].npar += 1;
			  end
		     else if ((car >= '0') and (car <= '9')) then
		          tty[ontty].par[npar] := (tty[ontty].par[npar] * 10) + ord(car) - ord('0')
		     else
		          begin
		             state := ESgotpars;
			     buf -= 1;
			     i   -= 1;
			  end;
		  end;
	       ESgotpars:
	          begin
		     state := ESnormal;
		     case (car) of
		        'J': csi_J(tty[ontty].par[0], ontty);
			'H': begin
			        if (tty[ontty].par[0] <> 0) then tty[ontty].par[0] -= 1;
				if (tty[ontty].par[1] <> 0) then tty[ontty].par[1] -= 1;
				tty[ontty].x := tty[ontty].par[1];
				tty[ontty].y := tty[ontty].par[0];
			     end;
			'm': csi_m(ontty);
		     end;
		  end;
	       ESfunckey:
	          begin
		  end;
	       ESsetterm:
	          begin
		  end;
	       ESsetgraph:
	          begin
		  end;
	    
	    end;   { ...case(state) }

	    buf += 1;

         end;   { ...for }

      asm
         pushfd
         cli
      end;

      fichier^.pos := (tty[ontty].y * 160) + (tty[ontty].x * 2);

      i := fichier^.pos div 2;
      tty[ontty].y := i div 80;
      tty[ontty].x := i mod 80;
      if (ontty = current_tty) then
          update_cursor(ontty);
      asm 
         popfd
      end;
      
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

   tty[current^.tty].y := fichier^.pos div 160;
   tty[current^.tty].x := (fichier^.pos div 2) mod 80;

   if (current^.tty = current_tty) then
       update_cursor(current_tty);

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
   tmp_TCGETS     : P_termios;
   tmp_TIOCGWINSZ : P_winsize;

begin

   {$IFDEF DEBUG_TTY_IOCTL}
      printk('Welcome in tty_ioctl... (%h, %h4, %h)\n', [fichier, req, argp]);
   {$ENDIF}

   result := 0;

   case (req) of
      TCGETS: begin   { FIXME: it returns a zero filled structure }
                 if (argp = NIL) then
		     begin
		        printk('tty_ioctl (TCGETS): argp=NIL\n', []);
		        result := -EINVAL;
		     end
		 else
		     begin
		        tmp_TCGETS := argp;
		        tmp_TCGETS^.c_iflag := 0;
			tmp_TCGETS^.c_oflag := 0;
			tmp_TCGETS^.c_cflag := 0;
			tmp_TCGETS^.c_lflag := 0;
			tmp_TCGETS^.c_line  := 0;
			for i := 0 to (NCCS - 1) do
			    tmp_TCGETS^.c_cc[i] := 0;
			{printk('WARNING (tty_ioctl): TCGETS request\n', []);}
		     end;
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
 * tty_close
 *
 * FIXME: do more checks (is the file really opened, ...)
 *****************************************************************************}
function tty_close (fichier : P_file_t) : dword;

var
   ontty : byte;


begin

   ontty := fichier^.inode^.rdev_min;

   tty[ontty].next_c := 0;
   tty[ontty].last_c := 0;

   result := 0;

end;



{******************************************************************************
 * csi_J
 *
 * NOTE: code inspired from linux 0.12 (kernel/chr_drv/console.c)
 *****************************************************************************}
procedure csi_J (vpar : dword ; ontty : byte); [public, alias : 'CSI_J'];

var
   dep, count, start : dword;
   attr : byte;

begin

   attr := tty[ontty].attr;

   case (vpar) of
   0: begin   { erase from cursor to end of display }   { FIXME: need more tests (but should be ok) }
         dep   := (ontty * screen_size);
	 start := tty[ontty].y * 80 + tty[ontty].x;
	 count := screen_resolution - start;
      end;
   1: begin   { erase from start to cursor }   { FIXME: not tested (but should be ok) }
         dep   := (ontty * screen_size);
	 start := 0;
	 count := tty[ontty].y * 80 + tty[ontty].x;
      end;
   2: begin   { erase whole display }
	 dep   := (ontty * screen_size);
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
procedure csi_m (ontty : byte);

var
   i : dword;

begin

   for i := 0 to tty[ontty].npar do
   begin
      case (tty[ontty].par[i]) of
         00: tty[ontty].attr := 07;   { Default }
         01: tty[ontty].attr := tty[ontty].attr or $08;    { Bold }
	 05: tty[ontty].attr := tty[ontty].attr or $80;    { Blinking }
	 07: tty[ontty].attr := (tty[ontty].attr shl 4) or (tty[ontty].attr shr 4);   { Negative }
	 22: tty[ontty].attr := tty[ontty].attr and $F7;   { Not bold }
	 25: tty[ontty].attr := tty[ontty].attr and $7F;   { Not blinking }
	 27: tty[ontty].attr := 07;   { Positive image (FIXME: don't know if it's correct to set 'attr' to 07) }
	 30: tty[ontty].attr := (tty[ontty].attr and $F8) or 0;   { Black foreground }
	 31: tty[ontty].attr := (tty[ontty].attr and $F8) or 4;   { Red foreground }
	 32: tty[ontty].attr := (tty[ontty].attr and $F8) or 2;   { Green foreground }
	 33: tty[ontty].attr := (tty[ontty].attr and $F8) or 6;   { Brown foreground }
	 34: tty[ontty].attr := (tty[ontty].attr and $F8) or 1;   { Blue foreground }
	 35: tty[ontty].attr := (tty[ontty].attr and $F8) or 5;   { Magenta (purple) foreground }
	 36: tty[ontty].attr := (tty[ontty].attr and $F8) or 3;   { Cyan (light blue) foreground }
	 37: tty[ontty].attr := (tty[ontty].attr and $F8) or 7;   { Gray foreground }
	 40: tty[ontty].attr := (tty[ontty].attr and $F8) or 0;   { Black background }
	 41: tty[ontty].attr := (tty[ontty].attr and $F8) or (4 shl 4);   { Red background }
	 42: tty[ontty].attr := (tty[ontty].attr and $F8) or (2 shl 4);   { Green background }
	 43: tty[ontty].attr := (tty[ontty].attr and $F8) or (6 shl 4);   { Brown background }
	 44: tty[ontty].attr := (tty[ontty].attr and $F8) or (1 shl 4);   { Blue background }
	 45: tty[ontty].attr := (tty[ontty].attr and $F8) or (5 shl 4);   { Magenta (purple) background }
	 46: tty[ontty].attr := (tty[ontty].attr and $F8) or (3 shl 4);   { Cyan (light blue) background }
	 47: tty[ontty].attr := (tty[ontty].attr and $F8) or (7 shl 4);   { White background }
      end;
   end;

end;



begin
end.
