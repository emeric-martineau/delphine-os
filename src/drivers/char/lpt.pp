{******************************************************************************
 *  lpt.pp
 * 
 *  Gestion des ports LPT
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0 - ??/??/2001 - GaLi
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


unit lpt_initialisation;


INTERFACE


procedure memcpy(src,dest : pointer; size : dword); external;
procedure printk (format : string ; args : array of const); external;


IMPLEMENTATION


var
   lpt_IO : array[1..2] of word;



{******************************************************************************
 * init_lpt
 *
 * Detecte les ports parallèles. Appelée uniquement lors de l'initialisation
 * de DelphineOS.
 *****************************************************************************}
procedure init_lpt; [public, alias : 'INIT_LPT'];

var
   i : byte;

begin

   memcpy($408,addr(lpt_IO),4);

   for i:=1 to 2 do
   begin
       if (lpt_IO[i] <> 0)
       then begin
           printk('lpt%d at %h4\n', [i, lpt_IO[i]]);
       end; { -> if }
   end; { -> for }
end; { -> procedure }



begin
end.
