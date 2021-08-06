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

{DEFINE DEBUG_SYS_NANOSLEEP}

procedure enable_IRQ (irq : byte); external;
function  inb (port : word) : byte; external;
procedure interruptible_sleep_on (p : PP_wait_queue); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure outb (port : word ; val : byte); external;
procedure print_bochs (format : string ; args : array of const);external;
procedure printk (format : string ; args : array of const);external;
procedure set_intr_gate (n : dword ; addr : pointer); external;


procedure BCD_TO_BIN (var val : dword);
function  CMOS_READ (port : byte) : byte;
procedure initialize_PIT(frequence : word);
function  get_value_counter : dword;
function  sys_alarm (seconds : dword) : dword; cdecl;
function  sys_gettimeofday (tv : P_timeval ; tz : P_timezone) : dword; cdecl;
function  sys_nanosleep (rqtp, rmtp : P_timespec) : dword; cdecl;
function  sys_time (t : pointer) : dword; cdecl;
function  sys_times (buffer : P_tms) : dword; cdecl;
function  sys_utime (path : pchar ; times : P_utimbuf) : dword; cdecl;


var
   current  : P_task_struct; external name 'U_PROCESS_CURRENT';

{ Global variables }
   jiffies  : dword;
   nr_nanosleep : dword;   {* Nb of process which are sleeping because of
      	             	    * sys_nanosleep *}
   nanosleep_wq : P_wait_queue;


IMPLEMENTATION


{$I inline.inc}


{******************************************************************************
 * initialize_PIT
 *
 * Entrée : fréquence désirée en Hertz (pas les véhicule de location !)
 *
 * Configure PIT. PIT = programmable interval timer (8253, 8254)
 ******************************************************************************} 
procedure initialize_PIT (frequence : word); [public, alias : 'INITIALIZE_PIT'];
begin
    {* Calcule le nombre à mettre dans le compteur en fonction de la fréquence
     * voulue. Le compteur tourne à 1,19318 MHz *}
    frequence := 1193180 div frequence ;

	pushfd();
	cli();

    outb(PIT_CONTROL_REG, (PIT_COMPTEUR0 or PIT_COMPTEUR_MODE_3 or 
                           PIT_CONTROL_MODE_LH or PIT_COMPTEUR_16BITS)) ;
    outb(PIT_COUNTER0_REG, (frequence and $FF));
    outb(PIT_COUNTER0_REG, (frequence shr 8));

	popfd();

end ;



{******************************************************************************
 * get_value_counter
 *
 * Retour : valeur du compteur
 ******************************************************************************}
function get_value_counter : dword; [public, alias : 'GET_VALUE_COUNTER'];
begin
    result := jiffies div HZ;
end;



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

	sti();

   BCD_TO_BIN(sec);
   BCD_TO_BIN(min);
   BCD_TO_BIN(hour);
   BCD_TO_BIN(day);
   BCD_TO_BIN(mon);
   BCD_TO_BIN(year);

	year += 1900;
	if (year < 1970) then
		 year += 100;

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

   if (t <> NIL) and (t > pointer(BASE_ADDR)) then
       longint(t^) := result;

{print_bochs('sys_time (%d): t=%h  result=%d\n', [current^.pid, t, result]);}

end;



{******************************************************************************
 * sys_gettimeofday
 *
 * FIXME: sys_gettimeofday does nothing !!!
 ******************************************************************************}
function sys_gettimeofday (tv : P_timeval ; tz : P_timezone) : dword; cdecl; [public, alias : 'SYS_GETTIMEOFDAY'];
begin

   print_bochs('FIXME: sys_gettimeofday (%d): tv=%h  tz=%h\n', [current^.pid, tv, tz]);

	sti();

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

   result := -ENOSYS;

end;



{******************************************************************************
 * sys_alarm
 *
 * INPUT : seconds -> Number of elapsed seconds before signal.
 *
 * OUTPUT: Number of seconds left in previous request or zero if no previous
 *         request.
 *
 * Causes the system to send the calling process a SIGALRM signal after a
 * specified number of seconds elapse.
 *
 * There can be only one outstanding alarm request at any given time. A call to
 * sys_alarm() will reschedule any previous unsignaled request. An argument of
 * zero causes any previous request to be canceled.
 *****************************************************************************}
function sys_alarm (seconds : dword) : dword; cdecl; [public, alias : 'SYS_ALARM'];

var
   old : dword;

begin

	sti();

   old := current^.alarm;

   if (old <> 0) then
       old := (old - jiffies) div HZ;

   result := old;

   if (seconds = 0) then
   begin
      current^.alarm := 0;
      exit;
   end;

   current^.alarm := jiffies + (HZ * seconds);

{   print_bochs('sys_alarm (%d): jiffies=%d seconds=%d -> alarm=%d\n', [current^.pid, jiffies, seconds, current^.alarm]);}

end;



{******************************************************************************
 * sys_nanosleep
 *
 * nano * 1000 == usecs
 * usecs * 1000 == msecs
 * msecs * 1000 = secs
 *****************************************************************************}
function sys_nanosleep (rqtp, rmtp : P_timespec) : dword; cdecl; [public, alias : 'SYS_NANOSLEEP'];

var
   nb_ticks, sec, nsec : dword;

begin

	sti();

   if (rqtp^.tv_nsec >= 1000000000) or
      (longint(rqtp^.tv_nsec) < 0) or
      (longint(rqtp^.tv_sec) < 0) then
   begin
      result := -EINVAL;
      exit;
   end;

{   nb_ticks := ((rqtp^.tv_sec * 1000) + (rqtp^.tv_nsec div 1000000)) div INTERVAL;}

   sec      := rqtp^.tv_sec;
   nsec     := rqtp^.tv_nsec;
   nsec     += 1000000000 div HZ - 1;
   nsec     := nsec div (1000000000 div HZ);
   nb_ticks := HZ * sec + nsec;

   {$IFDEF DEBUG_SYS_NANOSLEEP}
      printk('sys_nanosleep (%d): tv_sec=%d tv_nsec=%d -> %d ticks\n', [current^.pid, sec, nsec, nb_ticks]);
   {$ENDIF}

   current^.timeout := nb_ticks;
   interruptible_sleep_on(@nanosleep_wq);

   result := 0;

   if (current^.timeout > 0) then
   begin
      {$IFDEF DEBUG_SYS_NANOSLEEP}
      	 print_bochs('sys_nanosleep (%d): current^.timeout=%d  =>  \n', [current^.pid, current^.timeout]);
      {$ENDIF}
      if (rmtp <> NIL) then
      begin
			rmtp^.tv_sec  := current^.timeout div HZ;
			rmtp^.tv_nsec := (current^.timeout mod HZ) * (1000000000 div HZ);
      end;
      {$IFDEF DEBUG_SYS_NANOSLEEP}
			print_bochs('%d secs, %d nsecs\n', [rmtp^.tv_sec, rmtp^.tv_nsec]);
      {$ENDIF}
      result := -EINTR;
   end
   else
   begin
      if (rmtp <> NIL) then
      begin
			rmtp^.tv_sec  := 0;
	 		rmtp^.tv_nsec := 0;
      end;
   end;

end;



{******************************************************************************
 * sys_times
 *
 * Store process times for the calling process
 *
 *****************************************************************************}
function sys_times (buffer : P_tms) : dword; cdecl; [public, alias : 'SYS_TIMES'];
begin

   print_bochs('sys_times (%d): buffer=%h\n', [current^.pid, buffer]);

   if (buffer = NIL) then
       result := -EFAULT   { FIXME: -EINVAL ??? }
   else
   begin
      buffer^.tms_utime  := current^.utime;
      buffer^.tms_stime  := current^.stime;
      buffer^.tms_cutime := 1;
      buffer^.tms_cstime := 1;
      result := jiffies;
   end;

end;



{******************************************************************************
 * sys_utime
 *
 * FIXME: this function does nothing   :-)
 *****************************************************************************}
function sys_utime (path : pchar ; times : P_utimbuf) : dword; cdecl; [public, alias : 'SYS_UTIME'];
begin

	sti();

   print_bochs('sys_utime (%d): %s  %h\n', [current^.pid, path, times]);

   result := -ENOSYS;

end;



begin
end.
