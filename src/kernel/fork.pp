{******************************************************************************
 * fork.pp
 *
 * Create user processes and kernel thread
 *
 * Copyleft 2002 GaLi
 *
 * version 0.2a - 20/07/2002 - GaLi - Correct a bug (user stack wasn't
 *                                    correctly copied)
 *
 * version 0.2  - 15/07/2002 - GaLi - Correct a bug (Bad return values)
 *
 * version 0.1a - 23/06/2002 - GaLi - Correct a bug (ESP and EBP had bad values)
 *
 * version 0.1  - 20/06/2002 - GaLi - All processes have the same virtual
 *                                    address
 *
 * version 0.0  - ??/05/2002 - GaLi - Initial version
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


{$I errno.inc}
{$I fs.inc}
{$I mm.inc}
{$I process.inc }
{$I sched.inc }


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   mem_map : P_page; external name 'U_MEM_MEM_MAP';


procedure add_task (task : P_task_struct); external;
function  get_free_page : pointer; external;
function  get_new_pid : dword; external;
procedure init_tss (tss : P_tss_struct); external;
procedure kfree_s (addr : pointer ; size : dword); external;
function  kmalloc (len : dword) : pointer; external;
function  MAP_NR (adr : pointer) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_adr : pointer); external;
procedure schedule; external;
function  set_tss_desc (addr : pointer) : dword; external;




IMPLEMENTATION



{******************************************************************************
 * sys_fork
 *
 * INPUT  : None
 * OUTPUT : -1 on error. On success, the PID of the child is returned to the
 *          parent and zero is returned to the child.
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

   {* First, we have to get the new process start address and some registers
    * saved on the stack by the calling process *}

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
     mov   r_cs, eax         { End debug }
     mov   eax, [ebp + 52]
     mov   eflags, eax
     mov   eax, cr3
     mov   cr3_original, eax
     mov   esi, eax
     add   esi, 4092
     mov   eax, [esi]
     and   eax, $FFFFF000
     mov   page_table_original, eax
     sti   { Set interrupts on }
  end;

{$IFDEF DEBUG}
   printk('fork: current(%h) ss: %h4 esp: %h cs: %h4 eip: %h\nfork: eflags: %h ebp: %h', [current^.tss_entry, r_ss, r_esp, r_cs, ret_adr, eflags, r_ebp]);
   printk('\nfork: New task values:\n', []);
{$ENDIF}

   cr3_task    := get_free_page;   {* New global page directory address for 
                                    * the new process *}
   page_table  := get_free_page;
   new_stack0  := get_free_page;   { New stack (kernel mode) }
   new_stack3  := get_free_page;   { New stack (user mode) }
   new_task_struct := kmalloc(sizeof(task_struct));
   new_tss         := kmalloc(sizeof(tss_struct));
   new_pid         := get_new_pid;

   {* cr3_task    : pointer to the new global page directory
    * page_table  : pointer to the new page table
    * stack_entry : pointer to the page table (for stacks) *}

   { FIXME: If a call to get_free_page() failed, we have to exit fork() with an error code. But, if we
            exit and a call to get_free_page() suceed, we first have to free memory with push_page() }
   if ((new_stack0 = NIL) or (new_stack3 = NIL) or (cr3_task = NIL)
   or (new_task_struct = NIL) or (new_tss = NIL)) then
      begin
         printk('sys_fork: Cannot create a new task (not enough memory)\n', []);
	 result := -ENOMEM;
	 exit;
      end;

   { We are going to fill new_task_struct and new_tss with the correct values }

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
	 push_page(cr3_task);
	 push_page(page_table);
	 push_page(new_stack0);
	 push_page(new_stack3);
	 kfree_s(new_task_struct, sizeof(task_struct));
	 kfree_s(new_tss, sizeof(tss_struct));
	 result := -ENOMEM;   { FIXME: may be you could use another error code }
	 exit;
      end;

{$IFDEF DEBUG}
   printk('fork: tss_entry: %h   stack0: %h  stack3: %h\n', [new_task_struct^.tss_entry, new_stack0, new_stack3]);
   printk('fork: CR3: %h  page_table: %h\n', [cr3_task, page_table]);
{$ENDIF}


   { We are going to fill the new process TSS }

   init_tss(new_tss);
   new_tss^.esp0   := new_stack0 + 4096;
   new_tss^.esp    := pointer(r_esp);
   new_tss^.ebp    := pointer(r_ebp);
   new_tss^.cr3    := cr3_task;
   new_tss^.eflags := $202;
   new_tss^.eax    := 0;   { Return value for the child }
   new_tss^.eip    := ret_adr;

   { Copy user mode stack }
   memcpy(pointer($FFC00000), new_stack3, 4096);

   { Fill global page directory (We copy the parent's one }
   memcpy(cr3_original, cr3_task, 4096);

   cr3_task[1023] := longint(page_table) or USER_PAGE;
   page_table[0]  := longint(new_stack3) or USER_PAGE;   { user mode stack }

   {* Les pages physiques sont partagées entre le processus fils et le
    * processus père donc, on enlève le droit d'écrire sur toutes les pages.
    * Si un processus veut écrire dans une page, il déclenchera une
    * 'page_fault' (exception 14) qui lui allouera une nouvelle page afin
    * qu'il puisse écrire dessus (voir int.pp) 
    *
    * NOTE: only the user stack is not shared *}
   for i := 1 to current^.size do
   {* We begin with '1' because we don't care about user mode stack (already
    * initialized) which is entry #0 *}
      begin
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

   result := new_pid;   { Return value for the parent }

   {$IFDEF DEBUG}
      printk('EXITING FROM FORK (ret_adr = %h) !!!!!!!!!!\n', [ret_adr]);
   {$ENDIF}

   asm
      cli   { Critical section }
   end;

   add_task(new_task_struct);

   schedule;

   asm
      sti
   end;

end;



{******************************************************************************
 * kernel_thread
 *
 * INPUT : Thread entry point
 *
 * This procedure creates a kernel thread
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
   new_stack0 := get_free_page;   { Instead of kmalloc }
   new_stack3 := get_free_page;   { Instead of kmalloc }
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
   new_task^.ppid      := 0;   { Kernel thread have no parent }
   new_task^.next_run  := NIL;
   new_task^.prev_run  := NIL;

   add_task(new_task);

end;



begin
end.
