{******************************************************************************
 *  speaker.pp
 * 
 *  Gestion du PC-Speaker
 *
 *  CopyLeft 2002 Bubule
 *
 *  version 0.1 - 26/04/2002 - Bubule
 *
 *  Remerciement � Cornelis Frank (EduOS) qui p�te du code de ouf mais en
 *  restant simple et compr�hensible. Dommage que ce soit en C !
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
 ******************************************************************************}

unit speaker;


INTERFACE 


{$I time.inc}


procedure outb (port : word ; val : byte); external;
function  inb (port : word) : byte; external;


IMPLEMENTATION



{******************************************************************************
 * sound
 *
 * Entr�e : fr�quence d�sir�e en Hertz (pas les v�hicules de location !)
 *
 * Emet un son en continu sur le PC-Speaker
 *****************************************************************************}
procedure sound(frequence : word); [public, alias : 'SOUND'];
var 
    temp : byte ;

begin
    frequence := 1193180 div frequence ;
 
    outb (PIT_CONTROL_REG, PIT_COMPTEUR2 or PIT_CONTROL_MODE_LH or
	                       PIT_CONTROL_MODE_LH or PIT_COMPTEUR_16BITS) ;

    outb(PIT_COUNTER2_REG, frequence and $FF) ;
    outb(PIT_COUNTER2_REG, (frequence and $FF00)shr 8) ;

    {* Seulement en sortie. Si le bit n'est pas correctement mis � 1
     * 0x61 Port B du clavier, compatibilit� avec le 8255 *}
    outb($61, inb($61) or 3) ;
end ;



{******************************************************************************
 * nosound
 *
 * Arr�te le son
 ******************************************************************************} 
procedure nosound; [public, alias : 'NOSOUND'];
begin
   outb($61, inb($61) and $FC) ;
end ;



begin
end.
