{******************************************************************************
 *  sched.pp
 * 
 *  DelphineOS scheduler
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0.4 - 10/06/2003 -  GaLi  - Scheduler modification
 *
 *  version 0.0.2 - 25/06/2002 -  GaLi  - Move process management functions in
 *                                        src/kernel/process.pp
 *
 *  version 0.0.1 - 25/04/2002 - Bubule - Scheduler and timer modification
 *
 *  version 0.0.0 - ??/01/2002 -  GaLi  - Initial version
 *
 *  Je voudrais remercier Frank Cornelis qui developpe EduOS car il m'a permis
 *  de faire une commutation de tache qui fonctionne (apres toute une nuit de
 *  codage inutile !!!) : voir start.S
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


unit sched;


INTERFACE


{DEFINE DEBUG}


{$I fs.inc}
{$I process.inc}
{$I sched.inc}
{$I time.inc}


{ External procedures and functions }

procedure add_to_runqueue (task : P_task_struct); external;
procedure del_from_runqueue (task : P_task_struct); external;
function  do_signal (signr : dword) : boolean; external;
procedure dump_task; external;
procedure enable_IRQ (irq : byte); external;
procedure farjump (tss : word ; ofs : pointer); external;
procedure initialize_PIT (freq : dword); external;
procedure outb (port : word ; val : byte); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure set_intr_gate (n : dword ; addr : pointer); external;
function  signal_pending (p : P_task_struct) : dword; external;
procedure wake_up_process (task : P_task_struct); external;


{ External variables }
var
   jiffies      : dword; external name 'U_TIME_JIFFIES';
   current      : P_task_struct; external name 'U_PROCESS_CURRENT';
   first_task   : P_task_struct; external name 'U_PROCESS_FIRST_TASK';
   nr_nanosleep : dword; external name 'U_TIME_NR_NANOSLEEP';
   nanosleep_wq : P_wait_queue; external name 'U_TIME_NANOSLEEP_WQ';


IMPLEMENTATION


{$I inline.inc}



{******************************************************************************
 * schedule
 *
 * This is probably the most simple scheduler in the world...  :-)
 *
 * NOTE: be REALLY careful if you change this
 *****************************************************************************}
procedure schedule; [public, alias : 'SCHEDULE'];

var
   prev, first_tsk, tmp_tsk : P_task_struct;
   sig : dword;

begin

	pushfd();
	pushad();
	cli();

   { Check for any pending alarm }
   first_tsk := first_task;
   tmp_tsk   := first_task;
   repeat
      if (tmp_tsk^.alarm <> 0) and (tmp_tsk^.alarm < jiffies) then
      begin
      	tmp_tsk^.signal[0] := tmp_tsk^.signal[0] or (1 shl (SIGALRM - 1));
	 		tmp_tsk^.alarm := 0;
      end;
      tmp_tsk := tmp_tsk^.next_task;
   until (tmp_tsk = first_tsk);

   prev    := current;
   current := prev^.next_run;

   if (prev^.state <> TASK_RUNNING) then
   begin
      {print_bochs('schedule: PID %d is going to sleep %d %d  |  ', [prev^.pid, current^.pid]);}
      del_from_runqueue(prev);
      {print_bochs('%d %d\n', [prev^.pid, current^.pid]);}
   end;

   { If the next process ready to run is 'init', we launch the next (after 'init') }
   if (current^.pid = 1) then
       current := current^.next_run;

   if (current <> prev) then
       farjump(current^.tss_entry, NIL);

	popad();
	popfd();

end;



{******************************************************************************
 * timer_intr
 *
 * Activée uniquement par l'IRQ 0. Permet d'obtenir une valeur de "jiffies"
 * valide et d'activer le scheduler à intervalles réguliers.
 *
 * REMARQUE: Les interruptions sont automatiquement coupées.
 *****************************************************************************}
procedure timer_intr; interrupt;

var
   r_cs, r_eip, sig : dword;
   tmp_wq : P_wait_queue;
   task   : P_task_struct;

begin

   asm
      mov   eax, [ebp + 40]   { Get CS register value }
      mov   r_cs, eax
		mov   eax, [ebp + 36]
		mov   r_eip, eax
   end;

{printk(' %h ', [r_eip]);}

   jiffies += 1;

	{ Mise à jour du temps CPU utilisé par le processus }
	if (r_cs = $23) then
		 current^.utime += 1
	else
		 current^.stime += 1;

   if (nanosleep_wq <> NIL) then
   begin
      tmp_wq := nanosleep_wq;
      while (tmp_wq <> NIL) do
      begin
      	task := tmp_wq^.task;
	 		task^.timeout -= 1;
	 		if (task^.timeout = 0) then
	      	 wake_up_process(task);
      	tmp_wq := tmp_wq^.next;
      end;
   end;

   asm
      mov   al , $20
      out   $20, al
   end;

   { We call the scheduler every 200 ms and only if we are in user mode }
   if ((jiffies mod 20) = 0) and (r_cs = $23) then
        schedule();

end;



{******************************************************************************
 * init_sched
 *
 * Initialise le scheduler
 * Appelée uniquement à l'initialisation de DelphineOS
 *****************************************************************************}
procedure init_sched; [public, alias : 'INIT_SCHED'];

begin

   {* On va reprogrammer le PIT pour qu'il déclenche une interruption toutes
    * les 10ms (environ) *}

   initialize_PIT(HZ);
   jiffies      := 0;
   nr_nanosleep := 0;
   nanosleep_wq := NIL;

   set_intr_gate(32, @timer_intr);
   enable_IRQ(0);

end;



begin
end.
