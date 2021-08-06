{******************************************************************************
 *  time.pp
 * 
 *  Time/timer management
 *
 *  CopyLeft 2002 Bubule
 *
 *  version 0.1 - 25/04/2002 - Bubule - Initial version
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

{$I errno.inc}
{$I process.inc}
{$I time.inc}


procedure enable_IRQ (irq : byte); external;
function  inb (port : word) : byte; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure outb (port : word ; val : byte); external;
procedure printk (format : string ; args : array of const);external;
procedure set_intr_gate (n : dword ; addr : pointer); external;


procedure BCD_TO_BIN (var val : dword);
function  CMOS_READ (port : byte) : byte;
procedure configurer_frequence_PIT(frequence : word);
function  get_value_counter : dword;
procedure initialise_compteur;
procedure mdelay (time : dword);
function  sys_gettimeofday (tv : P_timeval ; tz : P_timezone) : dword; cdecl;
function  sys_time (t : pointer) : dword; cdecl;


{ Global variables }

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   compteur : dword;


IMPLEMENTATION



{******************************************************************************
 * configurer_frequence_PIT
 *
 * Entrée : fréquence désirée en Hertz (pas les véhicule de location !)
 *
 * Configure PIT. PIT = programmable interval timer (8253, 8254)
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

    outb(PIT_CONTROL_REG, (PIT_COMPTEUR0 or PIT_COMPTEUR_MODE_3 or 
                           PIT_CONTROL_MODE_LH or PIT_COMPTEUR_16BITS)) ;
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
procedure mdelay (time : dword); [public, alias : 'MDELAY'];
var ancien_compteur : dword ;
begin
    ancien_compteur := compteur ;

    while ((compteur - ancien_compteur) < time) do ;
        { on se fait une belotte ?
          FIXME: à modifier car attente active }
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



{******************************************************************************
 * CMOS_READ
 *
 ******************************************************************************}
function CMOS_READ (port : byte) : byte;
begin

   outb($70, $80 or port);

   asm
      nop
      nop
      nop
      nop
      nop
   end;

   result := inb($71);

end;



{******************************************************************************
 * BCD_TO_BIN
 *
 ******************************************************************************}
procedure BCD_TO_BIN (var val : dword);
begin

   val := (val and 15) + ((val shr 4) * 10);

end;



{******************************************************************************
 * sys_time
 *
 ******************************************************************************}
function sys_time (t : pointer) : dword; cdecl; [public, alias : 'SYS_TIME'];

var
   sec, min, hour, day, mon, year : dword;

begin

   repeat
      sec  := CMOS_READ(0);
      min  := CMOS_READ(2);
      hour := CMOS_READ(4);
      day  := CMOS_READ(7);
      mon  := CMOS_READ(8);
      year := CMOS_READ(9);
   until (sec = CMOS_READ(0));

   asm
      sti   { Put interrupts on }
   end;

   BCD_TO_BIN(sec);
   BCD_TO_BIN(min);
   BCD_TO_BIN(hour);
   BCD_TO_BIN(day);
   BCD_TO_BIN(mon);
   BCD_TO_BIN(year);

{printk('sec: %d  min: %d  hour: %d  day: %d  mon: %d  year: %d\n',
       [sec, min, hour, day, mon, year]);}

   { 1..12 -> 11,12,1..10 
     Puts Feb last since it has leap day }
   mon  -=  2;
   if (0 >= mon) then
   begin
      mon  += 12;
      year -=  1;
   end;

   result :=
   ((((year div 4 - year div 100 + year div 400 + 367 * mon div 12 + day) +
   (year * 365) - (719499)) * 24 + hour) * 60 + min) * 60 + sec;

   if (t <> NIL) and (t > pointer($FFC01000)) then
       longint(t^) := result;

{printk('sys_time (%d): t=%h  result=%d\n', [current^.pid, t, result]);}

end;



{******************************************************************************
 * sys_gettimeofday
 *
 * FIXME: sys_gettimeofday does nothing !!!
 ******************************************************************************}
function sys_gettimeofday (tv : P_timeval ; tz : P_timezone) : dword; cdecl; [public, alias : 'SYS_GETTIMEOFDAY'];
begin

{   printk('sys_gettimeofday (%d): tv=%h  tz=%h\n', [current^.pid, tv, tz]);}

   if (tv <> NIL) then
   begin
      memset(tv, 0, sizeof(timeval));
      { FIXME: Fill tv }
   end;

   if (tz <> NIL) then
   begin
      memset(tz, 0, sizeof(timezone));
      { FIXME: Fill tz }
   end;

   result := -ENOTSUP;

end;



begin
end.
