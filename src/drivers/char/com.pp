{******************************************************************************
 *  com.pp
 * 
 *  Gestion des ports COM
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.7 - ??/??/2001 - GaLi
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


unit com_initialisation;


INTERFACE


{$I fs.inc}


procedure print_word (nb : word); external;
procedure memcpy (src, dest : pointer; size : dword); external;
procedure printk (format : string; args : array of const); external;
procedure outb (port : word ; val : byte); external;
procedure register_chrdev (nb : byte ; name : string[20] ; fops : pointer); external;
function  inb (port : word) : byte; external;

function com_open (inode : P_inode_t ; fichier : P_file_t) : dword;
function com_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function com_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword;


IMPLEMENTATION


const
   COM_DEV = 3;

var
   com_IO   : array[1..4] of word; {* Tableau contenant les adresses I/O des
                                    * ports COM *}
   com_fops : file_operations;



{******************************************************************************
 * init_com
 *
 * Initialise les ports comme. Appelée uniquement lors de l'initialisation de
 * DelphineOS.
 *****************************************************************************}
procedure init_com; [public, alias : 'INIT_COM'];

var
   i, tmp   : byte;
   register : boolean;

begin

    register := FALSE;
    memcpy($400,@com_IO,8); { On met les données du BIOS dans le tableau }

    for i := 1 to 4 do
    begin
        if (com_IO[i] <> 0) then
	    begin
	       register := TRUE;
               printk('com%d at %h4', [i, com_IO[i]]);

	       { On regarde si l'UART est de type 16550A }

               outb(com_IO[i] + 2, $CF);

	       asm
	          nop
	          nop
	          nop
	          nop
	          nop
	          nop
	       end;

	       tmp := inb(com_IO[i] + 2);
	       outb(com_IO[i] + 2, $00);

	       if (tmp and $C0 = $C0) then
	           printk(' is a 16550A', []);

	       printk('\n', []);

               {* Il faudrait tester si il y a un modem branché et mettre la 
	        * vitesse du port au maximum. *}
               { Prkoi fèr simple kan on peu fèr compliker ! }
            end;
    end;

    if (register) then
        begin
	   com_fops.open  := @com_open;
	   com_fops.read  := @com_read;
	   com_fops.write := @com_write;
	   com_fops.seek  := NIL;   { We cannot call seek() for a character device }
	   com_fops.ioctl := NIL;
           register_chrdev(COM_DEV, 'com', @com_fops);
	end;

end;



{******************************************************************************
 * com_open
 *
 *****************************************************************************}
function com_open (inode : P_inode_t ; fichier : P_file_t) : dword;

var
   minor : byte;

begin

   minor := inode^.rdev_min;
   if (com_IO[minor] <> 0) then
       result := 0
   else
       result := -1;

end;



{******************************************************************************
 * com_read
 *
 *****************************************************************************}
function com_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;

var
   port : word;
   i    : dword;

begin

   result := count;
   port   := fichier^.inode^.rdev_min;

   for i := 1 to count do
   begin
      byte(buf^) := inb(port);
      buf += 1;
   end;

end;



{******************************************************************************
 * com_write
 *
 *****************************************************************************}
function com_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword;

var
   port : word;
   i    : dword;

begin

   result := count;
   port   := fichier^.inode^.rdev_min;

   for i := 1 to count do
   begin
      outb(port, byte(buf^));
      buf += 1;
   end;

end;



{* Je profite de la petitesse de ce code source pour faire une remarque. Fran-
 * chement, GaLi il code peut-être (bien c'est une autre  chose  :-)  mais  il
 * faut avouer que le travail de mise en forme est quand même important. Je ne
 * dis pas ca parce que je me sens frustrer (quoi que...) mais je  veux  juste
 * inviter les codeurs à faire un peu plus d'effort en ce qui concerne la mise
 * en page. Et, oui, il n'y a rien de plus désagréable que de trouver un  code
 * source et se dépouiller les neuronnes non pas parce  qu'il  est  compliqué,
 * mais parce qui est écrit n'importe comment, alors pas de ces choses ci-des-
 * sous :
 *     Langage C :
 *     -----------
 *         if (truc == t) { machin } else { bidule }
 *         if (truc == t){
 *         machin
 *         }else{
 *         bidule }
 *
 *     En Pascal :
 *     -----------
 *         if (truc=t) then
 *         begin machine
 *         end else begin
 *         bidule end ;
 *
 * Merci.

 * Bubule
 *}



begin
end.
