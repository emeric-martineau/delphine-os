{******************************************************************************
 * fork.pp
 *
 * Permet de créer des processus
 *
 * Copyleft 2002 GaLi
 *
 * version 0.2a - 20/07/2002 - GaLi - Correction d'un bug (pile utilisateur mal
 *                                    copiée)
 *
 * version 0.2  - 15/07/2002 - GaLi - Correction d'un bug (mauvaises valeurs
 *                                    de retour pour le père et le fils)
 *
 * version 0.1a - 23/06/2002 - GaLi - Correction d'un bug (mauvaise valeurs
 *                                    des registres ESP et EBP)
 *
 * version 0.1  - 20/06/2002 - GaLi - Tous les processus ont désormais le même
 *                                    espace d'adresses virtuelles.
 *
 * version 0.0  - ??/05/2002 - GaLi - Version initiale
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit fork;


{DEFINE DEBUG}


INTERFACE


{$I fs.inc}
{$I mm.inc}
{$I process.inc }
{$I sched.inc }


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   mem_map : P_page; external name 'U_MEM_MEM_MAP';


procedure memcpy (src, dest : pointer ; size : dword); external;
procedure printk (format : string ; args : array of const); external;
procedure init_tss (tss : P_tss_struct); external;
procedure add_task (task : P_task_struct); external;
procedure schedule; external;
procedure panic (reason : string); external;
function  kmalloc (len : dword) : pointer; external;
function  set_tss_desc (addr : pointer) : dword; external;
function  get_new_pid : dword; external;
function  MAP_NR (adr : pointer) : dword; external;



IMPLEMENTATION



{******************************************************************************
 * sys_fork
 *
 * Entrée : Aucune
 * Retour : PID du fils pour le processus père et 0 pour le processus fils si
 *          tout c'est bien passé (-1 en cas d'erreur)
 *
 * Cette fonction est éxécutée lors d'un appel système 'fork'. On est donc en
 * mode noyau.
 *
 *****************************************************************************}
function sys_fork : dword; cdecl; [public, alias : 'SYS_FORK'];

var
   cr3_task, cr3_original                 : P_pte_t;
   tmp, adr                               : pointer;
   page_table, page_table_original        : P_pte_t;
   new_stack0, new_stack3, index, ret_adr : pointer;
   new_task_struct                        : P_task_struct;
   new_tss                                : P_tss_struct;
   i, r_ebp, r_esp, r_ss, r_cs, eflags    : dword;
   new_pid                                : dword;

begin

{* Tout d'abord on va récupérer l'adresse à laquelle le nouveau processus
 * devra commencer son éxécution ainsi que quelques registres du processus qui
 * a appelé sys_fork *}

  asm
     mov   eax, [ebp + 44]
     mov   ret_adr, eax
     mov   eax, [ebp + 28]
     mov   r_ebp, eax
     mov   eax, [ebp + 56]
     mov   r_esp, eax
     mov   eax, [ebp + 60]   { Debug }
     mov   r_ss, eax         { ... }
     mov   eax, [ebp + 48]   { ... }
     mov   r_cs, eax         { Fin debug }
     mov   eax, [ebp + 52]
     mov   eflags, eax
     mov   eax, cr3
     mov   cr3_original, eax
     mov   esi, eax
     add   esi, 4092
     mov   eax, [esi]
     and   eax, $FFFFF000
     mov   page_table_original, eax
     sti   { On réactive les interruptions }
  end;

{$IFDEF DEBUG}
   printk('current(%h) ss: %h4 esp: %h cs: %h4 eip: %h\neflags: %h ebp: %h\n', [current^.tss_entry, r_ss, r_esp, r_cs, ret_adr, eflags, r_ebp]);
   printk('\nWelcome in sys_fork !!!\nNew task values:\n', []);
{$ENDIF}

   cr3_task    := kmalloc(4096);   { Adresse du répertoire global de pages pour
                                     le nouveau processus }
   page_table  := kmalloc(4096);
   new_stack0  := kmalloc(4096);   { Nouvelle pile (mode noyau) }
   new_stack3  := kmalloc(4096);   { Nouvelle pile (mode utilisateur) }
   new_task_struct := kmalloc(sizeof(task_struct));
   new_tss         := kmalloc(sizeof(tss_struct));
   new_pid         := get_new_pid;

   {* cr3_task    : pointeur sur le répertoire global de pages du nouveau 
    *               processus
    * page_table  : pointeur vers la table de pages allouée au processus
    * stack_entry : pointeur vers la table de pages pour les piles *}

   if ((new_stack0 = NIL) or (new_stack3 = NIL) or (cr3_task = NIL)
   or (new_task_struct = NIL) or (new_tss = NIL)) then
      begin
         printk('sys_fork: Cannot create a new task (not enough memory)\n', []);
	 result := -1;
	 exit;
      end;

   { On va remplir new_task_struct et new_tss avec les bonnes valeurs }

   memcpy(current, new_task_struct, sizeof(task_struct));
   new_task_struct^.cr3   := cr3_task;
   new_task_struct^.ticks := 0;
   new_task_struct^.page_table := page_table;
   new_task_struct^.errno := 0;
   new_task_struct^.pid   := new_pid;
   new_task_struct^.ppid  := current^.pid;
   new_task_struct^.tss   := new_tss;
   new_task_struct^.tss_entry := set_tss_desc(new_tss) * 8;

   if (new_task_struct^.tss_entry = -1) then
      begin
         printk('sys_fork: Cannot set tss_entry !!!\n', []);
	 result := -1;
	 exit;
      end;

{$IFDEF DEBUG}
   printk('tss_entry: %h   stack0: %h  stack3: %h\n', [new_task_struct^.tss_entry, new_stack0, new_stack3]);
   printk('CR3: %h  page_table: %h\n', [cr3_task, page_table]);
{$ENDIF}


   { On va remplir le TSS du nouveau processus }

   memcpy(current^.tss, new_tss, sizeof(tss_struct));
   new_tss^.esp0   := new_stack0 + 4096;
   new_tss^.esp    := pointer(r_esp);
   new_tss^.ebp    := pointer(r_ebp);
   new_tss^.cr3    := cr3_task;
   new_tss^.eflags := $202;
   new_tss^.eax    := 0;   { Valeur de retour du processus fils }
   new_tss^.eip    := ret_adr;

   { Copy user mode stack }
   memcpy(pointer($FFC00000), new_stack3, 4096);

   {* On remplit le répertoire global de pages (on recopie celui du processus
    * père) *}
   memcpy(cr3_original, cr3_task, 4096);

   cr3_task[1023] := longint(page_table) or USER_PAGE;
   page_table[0]  := longint(new_stack3) or USER_PAGE;   { user mode stack }

   {* Les pages physiques sont partagées entre le processus fils et le
    * processus père donc, on enlève le droit d'écrire sur toutes les pages.
    * Si un processus veut écrire dans une page, il déclenchera une
    * 'page_fault' (exception 14) qui lui allouera une nouvelle page afin
    * qu'il puisse écrire dessus (voir int.pp) 
    *
    * REMARQUE: seul la pile utilisateur n'est pas partagée *}
   for i := 1 to current^.size do
   {* We begin with '1' because we don't care about user mode stack (already
    * initialized) which is entry #0 *}
      begin
{*         asm
 *	    mov   esi, page_table_original
 *	    add   esi, 4   { On ne s'occupe pas de la pile utilisateur }
 *	    mov   edi, page_table
 *	    add   edi, 4   { On ne s'occupe pas de la pile utilisateur }
 *	    mov   eax, [esi]
 *	    and   eax, 11111111111111111111111111111101b
 *	    mov   index, eax
 *	    mov   [esi], eax
 *	    mov   [edi], eax
 *	    add   esi, 4
 *	    add   edi, 4
 *	    mov   page_table, edi
 *	    mov   page_table_original, esi
 *	 end; *}
         page_table[i] := page_table_original[i] and (not WRITE_PAGE);
	 page_table_original[i] := page_table_original[i] and (not WRITE_PAGE);
	 asm
	    cli
	 end;
	 mem_map[MAP_NR(pointer(page_table[i] and $FFFFF000))].count += 1;
	 asm
	    sti
	 end;
      end;

   asm
      cli   { Section critique }
   end;

   add_task(new_task_struct);

   schedule;

   result := new_pid;   { Valeur de retour du processus père }

end;



{******************************************************************************
 * kernel_thread
 *
 * Entrée : point d'entrée du thread
 *
 * Cette procédure créé un processus noyau
 *****************************************************************************}
procedure kernel_thread (addr : pointer); [public, alias : 'KERNEL_THREAD'];

var
   tss        : P_tss_struct;
   tss_entry  : dword;
   new_task   : P_task_struct;
   new_stack0 : pointer;
   new_stack3 : pointer;
   r_cr3      : dword;

begin

   tss        := kmalloc(sizeof(tss_struct));
   new_stack0 := kmalloc(4096);
   new_stack3 := kmalloc(4096);
   new_task   := kmalloc(sizeof(task_struct));

   if ((tss = NIL) or (new_stack0 = NIL) or (new_stack3 = NIL) or (new_task = NIL)) then
      begin
         printk('Not enough memory to create a new kernel task\n', []);
	 panic('kernel panic');
      end;

   tss_entry := set_tss_desc(tss) * 8;

   asm
      mov   eax, cr3
      mov   r_cr3, eax
   end;

   init_tss(tss);
   tss^.eip    := addr;
   tss^.cs     := $10;
   tss^.ds     := $18;
   tss^.es     := $18;
   tss^.fs     := $18;
   tss^.gs     := $18;
   tss^.ss0    := $18;
   tss^.esp0   := pointer(new_stack0 + 4096);
   tss^.ss     := $18;
   tss^.esp    := pointer(new_stack3 + 4096);
   tss^.eflags := $200;
   tss^.cr3    := pointer(r_cr3);

   new_task^.state     := TASK_RUNNING;
   new_task^.counter   := 20;
   new_task^.tss_entry := tss_entry;
   new_task^.tss       := tss;
   new_task^.pid       := get_new_pid;
   new_task^.uid       := 0;
   new_task^.gid       := 0;
   new_task^.ppid      := 0;   { Les processus noyau n'ont pas de père }
   new_task^.next_run  := NIL;
   new_task^.prev_run  := NIL;

   add_task(new_task);

end;



begin
end.
