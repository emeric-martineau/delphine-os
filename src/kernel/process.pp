{******************************************************************************
 *  process.pp
 * 
 *  Process management
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0.1 - 27/07/2002 - GaLi - Add wake_up() and sleep_on() procedures
 *
 *  version 0.0.0 - 25/06/2002 - GaLi - Initial version
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


unit process;


INTERFACE

{DEFINE DEBUG}
{DEFINE DEBUG_SLEEP_ON}
{DEFINE DEBUG_WAKE_UP}
{DEFINE DEBUG_SYS_GETCWD}
{DEFINE DEBUG_ADD_TO_RUNQUEUE}
{DEFINE DEBUG_DEL_FROM_RUNQUEUE}
{DEFINE DEBUG_INTERRUPTIBLE_SLEEP_ON}
{DEFINE DEBUG_INTERRUPTIBLE_WAKE_UP}

{$I process.inc}
{$I errno.inc}
{$I fs.inc}
{$I time.inc}
{$I wait.inc}
{$I sched.inc}


{ External procedures and functions }

procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;
procedure kfree_s (addr : pointer ; size : dword); external;
procedure schedule; external;
function  get_free_page : pointer; external;


procedure add_task (task : P_task_struct);
procedure add_to_runqueue (task : P_task_struct);
procedure del_from_runqueue (task : P_task_struct);
procedure del_task (task : P_task_struct);
function  get_new_pid : dword;
procedure interruptible_sleep_on (p : PP_wait_queue);
procedure interruptible_wake_up (p : PP_wait_queue ; s : boolean);
procedure sleep_on (p : PP_wait_queue);
function  sys_getcwd (buf : pchar ; size : dword) : dword; cdecl;
function  sys_getgid : dword; cdecl;
function  sys_getpgid : dword; cdecl;
function  sys_getpid : dword; cdecl;
function  sys_getppid : dword; cdecl;
function  sys_getuid : dword; cdecl;
function  sys_geteuid : dword; cdecl;
function  sys_setpgid (pid, pgid : dword) : dword; cdecl;
function  sys_times (buffer : P_tms) : dword; cdecl;
procedure wake_up (p : PP_wait_queue);
procedure wake_up_process (task : P_task_struct);


var
	jiffies : dword; external name 'U_TIME_JIFFIES';

{ Exported variables }

var
   current    : P_task_struct;
   first_task : P_task_struct;
   pid_table  : P_pid_table_struct;
   nr_tasks   : dword;   { Indique le nb total de processus }
   nr_running : dword;   { Indique le nb de processus prêts à être éxécutés }



IMPLEMENTATION


{$I inline.inc}


{******************************************************************************
 * add_task
 *
 * Entrée : pointeur sur la structure de la tache à éxécuter
 *
 * Insère un descripteur de processus au début de la liste
 *
 *****************************************************************************}
procedure add_task (task : P_task_struct); [public, alias : 'ADD_TASK'];

var
   cur_table	: P_pid_table_struct;
   i, nb, ofs	: dword;

begin

   {$IFDEF DEBUG}
      printk('add_task: PID=%d\n', [task^.pid]);
   {$ENDIF}

   cur_table := pid_table;
   nb  := task^.pid div 1022;
   ofs := task^.pid mod 1022;

	pushfd();
	cli();

   for i := 1 to nb do
       cur_table := cur_table^.next;

   cur_table^.pid_nb[ofs] := task;

   nr_tasks += 1;

   task^.prev_task := first_task^.prev_task;
   task^.next_task := first_task;
   first_task^.prev_task^.next_task := task;
   first_task^.prev_task := task;

   task^.next_run := NIL;

   add_to_runqueue(task);

	popfd();

end;



{******************************************************************************
 * del_task
 *
 * Entrée : pointeur sur la structure de la tache à supprimer
 *
 * Efface un descripteur liste des processus
 *****************************************************************************}
procedure del_task (task : P_task_struct); [public, alias : 'DEL_TASK'];

begin

   {$IFDEF DEBUG}
      printk('del_task: PID=%d\n', [task^.pid]);
   {$ENDIF}

	pushfd();
	cli();

   nr_tasks -= 1;

   del_from_runqueue(task);

   task^.prev_task^.next_task := task^.next_task;
   task^.next_task^.prev_task := task^.prev_task;

	popfd();

end;



{******************************************************************************
 * add_to_runqueue
 *
 * Entrée : pointeur sur la structure d'une tache
 *
 * Ajoute la tache dans la liste des taches à éxécuter
 *
 *****************************************************************************}
procedure add_to_runqueue (task : P_task_struct); [public, alias : 'ADD_TO_RUNQUEUE'];
begin

	pushfd();
	cli();

   {$IFDEF DEBUG_ADD_TO_RUNQUEUE}
      printk('add_to_runqueue: PID=%d\n', [task^.pid]);
   {$ENDIF}

   if (task^.next_run = NIL) then
   begin
      nr_running += 1;

      task^.state := TASK_RUNNING;

      task^.prev_run := first_task^.prev_run;
      task^.next_run := first_task;
      first_task^.prev_run^.next_run := task;
      first_task^.prev_run := task;
   end;

	popfd();

end;



{******************************************************************************
 * del_from_runqueue
 *
 * Entrée : pointeur sur la structure d'une tache
 *
 * Supprime un descripteur de processus de la liste
 *
 * NOTE: le processus idle (PID=1) ne doit pas dormir.
 *****************************************************************************}
procedure del_from_runqueue (task : P_task_struct); [public, alias : 'DEL_FROM_RUNQUEUE'];

begin

	pushfd();
	cli();

      if (task^.next_run <> NIL) and (task^.pid <> 1) then
      begin
         {$IFDEF DEBUG_DEL_FROM_RUNQUEUE}
            printk('del_from_runqueue: PID=%d\n', [task^.pid]);
         {$ENDIF}
         task^.prev_run^.next_run := task^.next_run;
         task^.next_run^.prev_run := task^.prev_run;
         task^.next_run := NIL;

         nr_running -= 1;
      end;

	popfd();

end;



{******************************************************************************
 * get_new_pid
 *
 * INPUT  : none
 * OUTPUT : A free PID
 *
 * NOTE: interrupts are disabled during the execution of this function
 *****************************************************************************}
function get_new_pid : dword; [public, alias : 'GET_NEW_PID'];

var
   cur_table : P_pid_table_struct;
   i, j, add : dword;

begin

   cur_table := pid_table;
   add       := 0;
   i         := 1;

	pushfd();
	cli();

   while (cur_table^.nb_free_pids = 0) do
	begin
		add += 1022;
		cur_table := cur_table^.next;
	end;

   {* Ici, cur_table contient au moins un PID non utilisé. On va donc regarder
    * duquel il s'agit *}
   
   while (cur_table^.pid_nb[i] <> NIL) do
		i += 1;

   { On va marquer le nouveau PID comme occupé }

   cur_table^.pid_nb[i] := pointer($01);   { Cette valeur sera modifiée par
                                             add_task }
   cur_table^.nb_free_pids -= 1;

   if (cur_table^.nb_free_pids = 0) then
   { Il faut allouer une nouvelle pid_table_struct }
	begin
		cur_table^.next := get_free_page();
	 	if (cur_table^.next = NIL) then
			 panic('get_new_pid: not enough memory');
	 	cur_table := cur_table^.next;
	 	cur_table^.nb_free_pids := 1022;
	 	cur_table^.next := NIL;
	 	for j := 1 to 1022 do
	       cur_table^.pid_nb[i] := NIL;
	end;

	popfd();

   {$IFDEF DEBUG}
      printk('get_new_pid: %d\n', [i + add]);
   {$ENDIF}

   if (i + add) > 1022 then
      printk('WARNING get_new_pid: new PID is > 1022 (%d)\n', [i + add]);

   result := i + add;

end;



{******************************************************************************
 * sys_setpgid
 *
 * INPUT  : pid  -> process to set
 *          pgid -> new process group ID
 *
 * OUTPUT : zero on success and -1 on failure
 *
 * FIXME: sys_setpgid always returns 0
 *****************************************************************************}
function sys_setpgid (pid, pgid : dword) : dword; cdecl; [public, alias : 'SYS_SETPGID'];
begin
	sti();
   result := 0;
end;



{******************************************************************************
 * sys_getpgid
 *
 * INPUT  : none
 * OUTPUT : parent process GID (I suppose)
 *
 * FIXME: sys_getpgid always returns 0
 *****************************************************************************}
function sys_getpgid : dword; cdecl; [public, alias : 'SYS_GETPGID'];
begin
	sti();
   result := 0;
end;



{******************************************************************************
 * sys_getpid
 *
 * INPUT  : none
 * OUTPUT : current process PID
 *
 *****************************************************************************}
function sys_getpid : dword; cdecl; [public, alias : 'SYS_GETPID'];
begin
	sti();
   result := current^.pid;
end;



{******************************************************************************
 * sys_getppid
 *
 * INPUT  : none
 * OUTPUT : parent process PID
 *
 *****************************************************************************}
function sys_getppid : dword; cdecl; [public, alias : 'SYS_GETPPID'];
begin
	sti();
   result := current^.ppid;
end;



{******************************************************************************
 * sys_getuid
 *
 * INPUT  : none
 * OUTPUT : real user UID
 *
 *****************************************************************************}
function sys_getuid : dword; cdecl; [public, alias : 'SYS_GETUID'];
begin
	sti();
   result := current^.uid;
end;



{******************************************************************************
 * sys_geteuid
 *
 * INPUT  : none
 * OUTPUT : user EUID
 *
 * FIXME: DelphineOS doesn't support EUID
 *****************************************************************************}
function sys_geteuid : dword; cdecl; [public, alias : 'SYS_GETEUID'];
begin
	sti();
   result := current^.uid;
end;



{******************************************************************************
 * sys_getgid
 *
 * INPUT  : none
 * OUTPUT : real user GID
 *
 *****************************************************************************}
function sys_getgid : dword; cdecl; [public, alias : 'SYS_GETGID'];
begin
	sti();
   result := current^.gid;
end;



{******************************************************************************
 * add_wait_queue
 *
 * Inspiré de __add_wait_queue (sched.h) de Linux 2.2.13
 *****************************************************************************}
procedure add_wait_queue (p : PP_wait_queue ; wait : P_wait_queue);

begin
{printk('add_wait_queue (%d): wait=%h wait^.next=%h\n', [current^.pid, wait, p^]);}
   wait^.next := p^;
   p^ := wait;
end;



{******************************************************************************
 * remove_wait_queue
 *
 * Inspiré de la procédure __remove_wait_queue (sched.h) de Linux 2.2.13
 *****************************************************************************}
procedure remove_wait_queue (p : PP_wait_queue ; wait : P_wait_queue);

var
   tmp : P_wait_queue;

begin
{printk('remove_wait_queue (%d): wait=%h wait^.next=%h\n', [current^.pid, wait, wait^.next]);}

   if (p^ = wait) then   { wait est le 1er élément de p }
       p^ := wait^.next
   else
      begin
         tmp  := p^;
         while (tmp^.next <> wait) do
	        tmp := tmp^.next;
	 		tmp^.next := wait^.next;
      end;

end;



{******************************************************************************
 * sleep_on
 *
 * Met le processus courant dans la file d'attente p. Le processus n'est
 * plus éxécuté jusqu'à son réveil meme si un signal arrive.
 *
 * NOTE: this function is only used by kflushd().
 *****************************************************************************}
procedure sleep_on (p : PP_wait_queue); [public, alias : 'SLEEP_ON'];

var
   wait : wait_queue;  {* Chaque processus a sa propre pile noyau. De plus, la
                        * pile noyau n'est pas dans l'espace d'adressage
								* virtuel, donc, pas de problème avec cette
								* déclaration *}

begin

   {$IFDEF DEBUG_SLEEP_ON}
      printk('sleep_on: PID=%d (%h)\n', [current^.pid, @wait]);
   {$ENDIF}

   wait.task := current;
   add_wait_queue(p, @wait);

   current^.state := TASK_UNINTERRUPTIBLE;
   schedule();

   remove_wait_queue(p, @wait);

end;



{******************************************************************************
 * wake_up
 *
 * Wake up ALL processes in a wait queue.
 *
 ******************************************************************************}
procedure wake_up (p : PP_wait_queue); [public, alias : 'WAKE_UP'];

var
   tmp : P_wait_queue;

begin

   tmp := p^;

   if (tmp <> NIL) then
   begin
      while (tmp <> NIL) do
      begin
         {$IFDEF DEBUG_WAKE_UP}
            printk('wake_up: PID=%d\n', [longint(tmp^.task^)]);
         {$ENDIF}
	 		add_to_runqueue(tmp^.task);
	 		tmp := tmp^.next;
      end;
   end;

   schedule();

end;



{******************************************************************************
 * interruptible_sleep_on
 *
 * Met le processus courant dans la file d'attente p. Le processus n'est
 * plus éxécuté jusqu'à son réveil sauf si un signal arrive.
 *****************************************************************************}
procedure interruptible_sleep_on (p : PP_wait_queue); [public, alias : 'INTERRUPTIBLE_SLEEP_ON'];

var
   wait : wait_queue;  {* Chaque processus a sa propre pile noyau. De plus, la
                        * pile noyau n'est pas dans l'espace d'adressage
								* virtuel, donc, pas de problème avec cette
								* déclaration *}

{$IFDEF DEBUG_INTERRUPTIBLE_SLEEP_ON}
   r_eip : dword;
{$ENDIF}

begin

	cli();

   {$IFDEF DEBUG_INTERRUPTIBLE_SLEEP_ON}
      asm
			mov   eax, [ebp + 4]
			mov   r_eip, eax
      end;
      printk('interruptible_sleep_on: PID=%d (%h) EIP=%h\n', [current^.pid, @wait, r_eip]);
   {$ENDIF}

   wait.task := current;
   add_wait_queue(p, @wait);

   current^.state := TASK_INTERRUPTIBLE;

   schedule();

   remove_wait_queue(p, @wait);

	sti();

end;



{******************************************************************************
 * interruptible_wake_up
 *
 * Wake up the first processe in a wait queue.
 *
 * NOTE: You must be sure that the wait queue is NOT empty when calling this
 *       procedure.
 *****************************************************************************}
procedure interruptible_wake_up (p : PP_wait_queue ; s : boolean); [public, alias : 'INTERRUPTIBLE_WAKE_UP'];

var
   tmp : P_wait_queue;
	{$IFDEF DEBUG_INTERRUPTIBLE_WAKE_UP}
	r_eip : dword;
	{$ENDIF}

begin

	{$IFDEF DEBUG_INTERRUPTIBLE_WAKE_UP}
		asm
			mov   eax, [ebp + 4]
			mov   r_eip, eax
		end;
	{$ENDIF}

   tmp := p^;

   if (tmp <> NIL) then
   begin
      {$IFDEF DEBUG_INTERRUPTIBLE_WAKE_UP}
         printk('interruptible_wake_up: PID=%d EIP=%h\n', [longint(tmp^.task^), r_eip]);
      {$ENDIF}
      add_to_runqueue(tmp^.task);
   end;

   if (s) then
       schedule();

end;



{******************************************************************************
 * wake_up_process
 *
 *****************************************************************************}
procedure wake_up_process (task : P_task_struct); [public, alias : 'WAKE_UP_PROCESS'];
begin

   add_to_runqueue(task);

end;



{******************************************************************************
 * sys_times
 *
 * Store process times for the calling process
 *
 * FIXME: sys_times do nothing !!!
 *****************************************************************************}
function sys_times (buffer : P_tms) : dword; cdecl; [public, alias : 'SYS_TIMES'];
begin

{   printk('sys_times (%d): buffer=%h\n', [current^.pid, buffer]);}

   if (buffer = NIL) then
       result := -EFAULT
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
 * sys_getcwd
 *
 *****************************************************************************}
function sys_getcwd (buf : pchar ; size : dword) : dword; cdecl; [public, alias : 'SYS_GETCWD'];

var
   i : dword;

begin

   asm
      sti
   end;

   {$IFDEF DEBUG_SYS_GETCWD}
      printk('sys_getcwd: ', []);
   {$ENDIF}

   if (size < ord(current^.cwd[0])) then
       result := -ERANGE
   else
       begin
          for i := 1 to ord(current^.cwd[0]) do
	  begin
              buf[i - 1] := current^.cwd[i];
	      {$IFDEF DEBUG_SYS_GETCWD}
	         printk('%c', [current^.cwd[i]]);
	      {$ENDIF}
	  end;
	  {$IFDEF DEBUG_SYS_GETCWD}
	     printk(' (%d)\n', [i + 1]);
	  {$ENDIF}
          buf[i] := #0;
          result := i + 1;
       end;

end;



begin
end.
