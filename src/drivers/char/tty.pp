{******************************************************************************
 *  tty.pp
 * 
 *  Console management
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.7  - 22/12/2003  - GaLi - Correct a bug (line and column number).
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
 *  version 0.1  - ??/12/2001  - GaLi - Version initiale
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

{$I fs.inc}
{$I process.inc}
{$I tty.inc}


procedure update_cursor (ontty : byte);
procedure change_tty (ontty : byte);
procedure get_vesa_info;
procedure printk (format : string ; args : array of const);
function  tty_open (inode : P_inode_t ; filp : P_file_t) : dword;
function  tty_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function  tty_seek (fichier : P_file_t ; offset, whence : dword) : dword;

procedure print_dec_dword (nb : dword); external;
procedure print_word (nb : word); external;
procedure print_byte (nb : byte); external;
procedure print_dword (nb : dword); external;
procedure register_chrdev (nb : byte ; name : string[20] ; fops : pointer); external;{ src/fs/init_vfs.pp }


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
 * get_vesa_info
 *
 *****************************************************************************}
procedure get_vesa_info;
var
   vesa_info : P_vesa_info_t;
   oemstr    : ^char;

begin

   vesa_info := $10200;

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
 * init_tty
 *
 * Initialise les consoles. Cette procédure met le numéro de ligne et de
 * colonne à 0 pour toutes les consoles sauf la premièré dont la ligne et la
 * colonne ont été stockées dans DX par setup.S.
 *****************************************************************************}
procedure init_tty; [public, alias : 'INIT_TTY'];

var
   i, x, y : byte;

begin

   asm
      mov   byte y, dh
      mov   byte x, dl
   end;

   tty_fops.open  := @tty_open;
   tty_fops.read  := NIL;
   tty_fops.write := @tty_write;
   tty_fops.seek  := @tty_seek;

   {* REMARQUE: On ne peut pas appeler register_chrdev() ici car la table
    * chrdevs n'est pas encore initialisée. L'enregistrement du périphérique
    * 'tty' se fait donc dans init_vfs.pp *}

   tty[0].x := x;
   tty[0].y := y;
   tty[0].echo := TRUE;

   for i:=1 to 7 do
      begin
         tty[i].x := 0;
         tty[i].y := 0;
	 tty[i].echo := TRUE;
      end;

   current_tty := 0;

   { On va effacer toutes les consoles }

   asm
      cld
      mov   eax, $07200720        { L'erreur a la con venait d'ici !!! }
      mov   edi, video_ram_start
      add   edi, screen_size
      mov   ecx, 7000
      rep   stosd
   end;

   change_tty(0);

   get_vesa_info;

end;



{******************************************************************************
 * putc
 *
 * Entrée : caractère à écrire, numéro de la console
 *
 * Ecris un caractère sur la console spécifiée
 * NOTE : le caractère $0D (ou #13) est considéré comme un retour charriot
 *****************************************************************************}
procedure putc (car : char ; ontty : byte); [public,alias : 'PUTC'];

var
   ofs, dep       : dword;
   colonne, ligne : byte;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   ligne   :=  tty[ontty].y;
   colonne :=  tty[ontty].x;
   ofs     :=  (ligne * 160 + colonne * 2);
   dep     :=  (ontty * screen_size);

   if (car = #13) then   { Caractère = retour charriot ? }
      begin
         ligne += 1;
         ofs   := (ligne * 160);
      end
   else
      begin
         asm
            mov   edi, ofs
            add   edi, dep
            add   edi, video_ram_start
            mov   ah , 07
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

            mov   eax, $07200720
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
 *     - %h2 : affiche une variable en héxadécimal (2 chiffres affichés)
 *
 * Exemple : printk('Hello %d %h %s\n', [var1, var2, chaine]);
 *****************************************************************************}
procedure printk (format : string ; args : array of const); [public,alias:'PRINTK'];

var
   pos,tmp : byte;
   num_args   : dword;

begin

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
                                   tmp := 1;
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
                          putchar(#13);
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
end;



{******************************************************************************
 * sys_printf
 *
 * Appel système qui permet d'afficher une chaîne de caractères
 * REMARQUE : cet appel système est temporaire !!!
 *****************************************************************************}
procedure sys_printf (format : string ; args : array of const); cdecl; assembler; [public, alias : 'SYS_PRINTF'];
asm
   mov   edx, [ebp+16]
   mov   ecx, [ebp+12]
   mov   ebx, [ebp+8]
   push  edx
   push  ecx
   push  ebx
   call  PRINTK
end;



{******************************************************************************
 * change_tty
 *
 * Entrée : numéro de la console
 *
 * Change la console active. tty doit être compris entre 0 et 7 (pas de
 * vérification effectuée)
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
procedure update_cursor (ontty : byte);

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
 *****************************************************************************}
function tty_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [public, alias : 'TTY_WRITE'];

var
   i     : dword;
   ontty : byte;
   car   : ^char;

begin

   ontty := fichier^.inode^.rdev_min;

   if tty[ontty].echo then
   begin
      car := buf;
      for i := 1 to count do
         begin
            putc(car^, ontty);
	    inc(car); 
         end;

      asm
         pushfd
         cli
      end;

      fichier^.pos:=(tty[ontty].y * 160) + (tty[ontty].x * 2);

      i := fichier^.pos div 2;
      tty[ontty].y := i div 80;
      tty[ontty].x := i mod 80;
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

   offset *= 2;
   {$IFDEF DEBUG}
      printk('debut : %d\n',[fichier^.pos]);
   {$ENDIF}
   case whence of
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
	    result := -1;
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

begin
end.
