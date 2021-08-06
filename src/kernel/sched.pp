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
{DEFINE DEBUG_SCHEDULE}


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
procedure initialise_compteur; external;
procedure outb (port : word ; val : byte); external;
procedure printk (format : string ; args : array of const); external;
procedure set_intr_gate (n : dword ; addr : pointer); external;
function  signal_pending (p : P_task_struct) : dword; external;


{ External variables }

var
   compteur : dword; external name 'U_TIME_COMPTEUR';
   current  : P_task_struct; external name 'U_PROCESS_CURRENT';



IMPLEMENTATION



{******************************************************************************
 * schedule
 *
 * This is probably the most simple scheduler in the world...  :-)
 *
 * NOTE: be REALLY careful if you change this
 *****************************************************************************}
procedure schedule; [public, alias : 'SCHEDULE'];

var
   prev     : P_task_struct;
   tmp, sig : dword;

begin

   asm
      pushfd
      cli
   end;

   prev    := current;
   current := prev^.next_run;

   sig := signal_pending(prev);

   if (prev^.state = TASK_INTERRUPTIBLE) and (sig <> 0) then
   begin
      printk('schedule: PID %d has received a signal\n', [prev^.pid]);
      add_to_runqueue(prev);
   end;

   if (prev^.state <> TASK_RUNNING) then
   begin
      {printk('schedule: PID %d is going to sleep %d %d  |  ', [prev^.pid, current^.pid]);}
      del_from_runqueue(prev);
      {printk('%d %d\n', [prev^.pid, current^.pid]);}
   end;

   { If the next process ready to run is 'init', we launch the next (after 'init') }
   if (current^.pid = 1) then
       current := current^.next_run;

   if (current <> prev) then
   begin
{printk('schedule: %d -> %d (state=%d)\n', [prev^.pid, current^.pid, current^.state]);}
      farjump(current^.tss_entry, NIL);
   end;

   sig := signal_pending(current);
   if (sig <> 0) then
   begin
      {printk('schedule: PID %d has received signal %d\n', [current^.pid, sig]);}
      do_signal(sig);
   end;

   asm
      popfd
   end;

end;



{******************************************************************************
 * timer_intr
 *
 * Activée uniquement par l'IRQ 0. Permet d'obtenir une valeur de "compteur"
 * valide et d'activer le scheduler à intervalles réguliers.
 *
 * REMARQUE: Les interruptions sont automatiquement coupées.
 *****************************************************************************}
procedure timer_intr; interrupt;

var
   r_cs : dword;

begin

   asm
      mov   eax, [ebp + 40]   { Get CS register value }
      mov   r_cs, eax
   end;

   { Incrémente le compteur système }
   compteur += INTERVAL;
   current^.ticks += 1;  { Mise à jour du temps CPU utilisé par le processus }

   asm
      mov   al , $20
      out   $20, al
   end;

   { We call the scheduler every 200 ms and only if we are in user mode }
   if ((compteur mod 200) = 0) and (r_cs = $23) then
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

   initialise_compteur();

   set_intr_gate(32, @timer_intr);
   enable_IRQ(0);

end;



begin
end.
