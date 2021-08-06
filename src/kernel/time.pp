{******************************************************************************
 *  time.pp
 * 
 *  Gestion du timer en mode protégé
 *
 *  CopyLeft 2002 Bubule
 *
 *  version 0.1 - 25/04/2002 - Bubule
 *
 *  Remerciement à Cornelis Frank (EduOS) qui pète du code de ouf mais en
 *  restant simple et compréhensible. Dommage que ce soit en C !
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


unit time;


INTERFACE


{$I time.inc}


procedure outb (port : word ; val : byte); external;
procedure inb (port : word); external;
procedure enable_IRQ (irq : byte); external;
procedure set_intr_gate (n : dword ; addr : pointer); external;


var
   compteur : dword;



IMPLEMENTATION



{******************************************************************************
 * configurer_frequence_PIT
 *
 * Entrée : fréquence désirée en Hertz (pas les véhicule de location !)
 *
 * Configure le PIT. PIT = programmable interval timer (8253, 8254)
 ******************************************************************************} 
procedure configurer_frequence_PIT(frequence : word); [public, alias : 'CONFIGURER_FREQUENCE_PIT'];
begin
    {* Calcule le nombre à mettre dans le compteur en fonction de la fréquence
     * voulue. Le compteur tourne à 1,19318 MHz *}
    frequence := 1193180 div frequence ;

    asm
       pushfd
       cli
    end;

    outb(PIT_CONTROL_REG, (PIT_COMPTEUR0 or PIT_COMPTEUR_MODE_3 or PIT_CONTROL_MODE_LH or PIT_COMPTEUR_16BITS)) ;
    outb(PIT_COUNTER0_REG, (frequence and $FF));
    outb(PIT_COUNTER0_REG, (frequence shr 8));

    asm
       popfd
    end;

end ;



{******************************************************************************
 * mdelay
 *
 * Entrée : temps en miliseconde
 *
 * Attend un certain temps. ATTENTION cette version est une attente active !
 ******************************************************************************}
procedure mdelay(time : dword); [public, alias : 'MDELAY'];
var ancien_compteur : dword ;
begin
    ancien_compteur := compteur ;

    while ((compteur - ancien_compteur) < time) do ;
        { on se fait une belotte ?
          à modifier car attente active }
end ;



{******************************************************************************
 * get_value_counter
 *
 * Retour : valeur du compteur
 ******************************************************************************}
function get_value_counter : dword; [public, alias : 'GET_VALUE_COUNTER'];
begin
    Result := compteur ;
end ;



{******************************************************************************
 * initialise_compteur
 *
 * Retour : valeur du compteur
 ******************************************************************************}
procedure initialise_compteur; [public, alias : 'INITIALISE_COMPTEUR'];

begin
  compteur := 0;
  configurer_frequence_PIT(1000 div INTERVAL);
end ;



begin
end.
