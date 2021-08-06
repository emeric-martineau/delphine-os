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

{$I fs.inc}
{$I process.inc }
{$I sched.inc }


{ External procedures and functions }

procedure printk (format : string ; args : array of const); external;
procedure kfree_s (addr : pointer ; size : dword); external;
procedure schedule; external;
function  kmalloc (size : dword) : pointer; external;


procedure add_to_runqueue (task : P_task_struct);
procedure del_from_runqueue (task : P_task_struct);



{ Exported variables }

var
   current    : P_task_struct;
   first_task : P_task_struct;
   pid_table  : P_pid_table_struct;
   nr_tasks   : dword;   { Indique le nb total de processus }
   nr_running : dword;   { Indique le nb de processus prêts à être éxécutés }



IMPLEMENTATION



{******************************************************************************
 * add_task
 *
 * Entrée : pointeur sur la structure de la tache à éxécuter
 *
 * Insère un descripteur de processus au début de la liste
 *
 * REMARQUE : les interruptions doivent être coupées AVANT l'appel de cette
 *            procédure.
 *****************************************************************************}
procedure add_task (task : P_task_struct); [public, alias : 'ADD_TASK'];

begin

   {$IFDEF DEBUG}
      printk('add_task: \n', []);
   {$ENDIF}

   nr_tasks += 1;

   task^.prev_task := first_task^.prev_task;
   task^.next_task := first_task;
   first_task^.prev_task^.next_task := task;
   first_task^.prev_task := task;

   add_to_runqueue(task);

end;



{******************************************************************************
 * del_task
 *
 * Entrée : pointeur sur la structure de la tache à supprimer
 *
 * Efface un descripteur liste des processus
 *
 * REMARQUE : les interruptions doivent être coupées AVANT l'appel de cette
 *            procédure.
 *****************************************************************************}
procedure del_task (task : P_task_struct); [public, alias : 'DEL_TASK'];

begin

   {$IFDEF DEBUG}
      printk('del_task: \n', []);
   {$ENDIF}

   nr_tasks -= 1;

   del_from_runqueue(task);

   task^.prev_task^.next_task := task^.next_task;
   task^.next_task^.prev_task := task^.prev_task;

end;



{******************************************************************************
 * add_to_runqueue
 *
 * Entrée : pointeur sur la structure d'une tache
 *
 * Ajoute la tache dans la liste des taches à éxécuter
 *
 * REMARQUE : les interruptions doivent être coupées AVANT l'appel de cette
 *            procédure
 *****************************************************************************}
procedure add_to_runqueue (task : P_task_struct);
begin

   {$IFDEF DEBUG}
      printk('add_to_runqueue: \n', []);
   {$ENDIF}

   nr_running += 1;

   task^.prev_run := first_task^.prev_run;
   task^.next_run := first_task;
   first_task^.prev_run^.next_run := task;
   first_task^.prev_run := task;

   task^.state := TASK_RUNNING;

end;



{******************************************************************************
 * del_from_runqueue
 *
 * Entrée : pointeur sur la structure d'une tache
 *
 * Supprime un descripteur de processus de la liste
 *****************************************************************************}
procedure del_from_runqueue (task : P_task_struct);

begin

   {$IFDEF DEBUG}
      printk('del_from_runqueue: \n', []);
   {$ENDIF}

   task^.prev_run^.next_run := task^.next_run;
   task^.next_run^.prev_run := task^.prev_run;

   task^.state := TASK_INTERRUPTIBLE;

   nr_running -= 1;

end;



{******************************************************************************
 * get_new_pid
 *
 * Entrée : aucune
 * Retour : un numéro de processus libre
 *****************************************************************************}
function get_new_pid : dword; [public, alias : 'GET_NEW_PID'];

var
   cur_table : P_pid_table_struct;
   i, j, add : dword;

begin

   cur_table := pid_table;
   add       := 0;
   i         := 1;
   
   while (cur_table^.nb_free_pids = 0) do
      begin
         add += 1022;
	 cur_table := cur_table^.next;
      end;

   {* Ici, cur_table contient au moins un PID non utilisé. On va donc regarder
    * duquel il s'agit *}
   
   while (cur_table^.pid_nb[i] <> NIL) do
      begin
         i += 1;
      end;

   { On va marquer le nouveau PID comme occupé }

   cur_table^.pid_nb[i] := pointer($01);   { Cette valeur sera modifiée par
                                             add_task }
   cur_table^.nb_free_pids -= 1;

   if (cur_table^.nb_free_pids = 0) then
   { Il faut allouer une nouvelle pid_table_struct }
      begin
         cur_table^.next := kmalloc(4096);
	 cur_table := cur_table^.next;
	 cur_table^.nb_free_pids := 1022;
	 cur_table^.next := NIL;
	 for j := 1 to 1022 do
	    begin
	       cur_table^.pid_nb[i] := NIL;
	    end;
      end;

{printk('\nnew pid: %d\n\n', [i+add]);}

   result := i + add;

end;



{******************************************************************************
 * sys_get_pid
 *
 * Entrée : aucune
 * Sortie : numéro du processus courant
 *
 * Cette fonction est un appel système
 *****************************************************************************}
function sys_get_pid : dword; [public, alias : 'SYS_GET_PID'];
begin
   result := current^.pid;
end;



{******************************************************************************
 * add_wait_queue
 *
 * Inspiré de __add_wait_queue (sched.h) de Linux 2.2.13
 *****************************************************************************}
procedure add_wait_queue (p : PP_wait_queue ; wait : P_wait_queue);

begin
   wait^.next := p^;
   p^ := wait;
end;



{******************************************************************************
 * remove_from_queue
 *
 * Inspiré de la procédure __remove_wait_queue (sched.h) de Linux 2.2.13
 *****************************************************************************}
procedure remove_wait_queue (p : PP_wait_queue ; wait : P_wait_queue);

var
   tmp : P_wait_queue;

begin

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
 * plus éxécuté jusqu'à son réveil.
 *****************************************************************************}
procedure sleep_on (p : PP_wait_queue); [public, alias : 'SLEEP_ON'];

var
   wait : wait_queue;  {* Chaque processus a sa propre pile noyau. De plus, la
                        * pile noyau n'est pas dans l'espace d'adressage
			* virtuel, donc, pas de problème avec cette
			* déclaration *}

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   {$IFDEF DEBUG}
      printk('sleep_on: task %h2\n', [current^.pid]);
   {$ENDIF}

   del_from_runqueue(current);

   wait.task := current;
   add_wait_queue(p, @wait);

   schedule;

   remove_wait_queue(p, @wait);

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * wake_up
 *
 * Réveille TOUS les processus de le file d'attente p
 *****************************************************************************}
procedure wake_up (p : PP_wait_queue); [public, alias : 'WAKE_UP'];

var
   tmp : P_wait_queue;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   {$IFDEF DEBUG}
      printk('wake_up: task %h2\n', [current^.pid]);
   {$ENDIF}

   tmp := p^;

   if (tmp <> NIL) then
      begin
         while (tmp <> NIL) do
         begin
	    add_to_runqueue(tmp^.task);
	    tmp := tmp^.next;
         end;
      end;

   asm
      popfd   { Fin section critique }
   end;

end;



begin
end.
