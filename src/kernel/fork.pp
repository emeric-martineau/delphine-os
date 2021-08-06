{******************************************************************************
 * fork.pp
 *
 * Create user processes and kernel threads
 *
 * Copyleft 2002 GaLi
 *
 * version 0.3  - 01/10/2003 - GaLi - Copy mmap requests info
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
{DEFINE DEBUG_COPY_MM}


INTERFACE


{$I errno.inc}
{$I fs.inc}
{$I mm.inc}
{$I process.inc }
{$I sched.inc }


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   mem_map : P_page; external name 'U_MEM_MEM_MAP';
   shared_pages : dword; external name 'U_MEM_SHARED_PAGES';


procedure add_mmap_req (p : P_task_struct ; addr : pointer ; size : dword); external;
procedure add_task (task : P_task_struct); external;
function  get_free_page : pointer; external;
function  get_new_pid : dword; external;
procedure init_tss (tss : P_tss_struct); external;
procedure kfree_s (addr : pointer ; size : dword); external;
function  kmalloc (len : dword) : pointer; external;
function  MAP_NR (adr : pointer) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_adr : pointer); external;
procedure schedule; external;
function  set_tss_desc (addr : pointer) : dword; external;


procedure copy_mm (p : P_task_struct);
procedure kernel_thread (addr : pointer);
function  sys_fork : dword; cdecl;



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
   es_ent, es_data                        : P_pte_t;   { Use for extra stack }
   tmp, adr                               : pointer;
   page_table, page_table_original        : P_pte_t;
   new_stack0, new_stack3, index, ret_adr : pointer;
   new_task_struct                        : P_task_struct;
   new_tss                                : P_tss_struct;
   i, j, r_ebp, r_esp, r_ss, r_cs, eflags : dword;
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
   printk('sys_fork: current(%d) ss: %h4 esp: %h cs: %h4 eip: %h\nsys_fork: eflags: %h ebp: %h', [current^.pid, r_ss, r_esp, r_cs, ret_adr, eflags, r_ebp]);
   printk('\nsys_fork: New task values:\n', []);
{$ENDIF}

   cr3_task    := get_free_page();   {* New global page directory address for 
                                      * the new process *}
   page_table  := get_free_page();
   new_stack0  := get_free_page();   { New stack (kernel mode) }
   new_stack3  := get_free_page();   { New stack (user mode) }
   new_task_struct := kmalloc(sizeof(task_struct));
   new_tss         := kmalloc(sizeof(tss_struct));
   new_pid         := get_new_pid();

   {* cr3_task    : pointer to the new global page directory
    * page_table  : pointer to the new page table
    * stack_entry : pointer to the page table (for stacks) *}

   { Check if all pointers are correctly initialized }
   if ((new_stack0 = NIL) or (new_stack3 = NIL) or (cr3_task = NIL)
   or (new_task_struct = NIL) or (new_tss = NIL)) then
   begin
      if (new_stack0 <> NIL) then push_page(new_stack0);
      if (new_stack3 <> NIL) then push_page(new_stack3);
      if (cr3_task <> NIL) then push_page(cr3_task);
      if (new_task_struct <> NIL) then kfree_s(new_task_struct, sizeof(task_struct));
      if (new_tss <> NIL) then kfree_s(new_tss, sizeof(tss_struct));
      printk('sys_fork (%d): cannot create a new task (not enough memory)\n', [current^.pid]);
      result := -ENOMEM;
      exit;
   end;

   { We are going to fill new_task_struct and new_tss with the correct values }
   for i := 0 to (OPEN_MAX - 1) do
   begin
      if (current^.file_desc[i] <> NIL) then
      begin
	 current^.file_desc[i]^.count += 1;
	 current^.file_desc[i]^.inode^.count += 1;
      end;
   end;

   current^.pwd^.count  += 1;
   current^.root^.count += 1;

   memcpy(current, new_task_struct, sizeof(task_struct));
   new_task_struct^.cr3   := cr3_task;
   new_task_struct^.ticks := 0;
   new_task_struct^.page_table := page_table;
   new_task_struct^.errno := 0;
   new_task_struct^.pid   := new_pid;
   new_task_struct^.ppid  := current^.pid;
   new_task_struct^.tss   := new_tss;
   new_task_struct^.tss_entry := set_tss_desc(new_tss) * 8;
   new_task_struct^.p_pptr  := current;
   new_task_struct^.p_cptr  := NIL;
   new_task_struct^.p_ysptr := NIL;
   new_task_struct^.p_osptr := current^.p_cptr;
   if (new_task_struct^.p_osptr <> NIL) then
       new_task_struct^.p_osptr^.p_ysptr := new_task_struct;
   current^.p_cptr := new_task_struct;

   copy_mm(new_task_struct);

   if (new_task_struct^.tss_entry = -1) then
   begin
      printk('sys_fork (%d): cannot set tss_entry\n', [current^.pid]);
      push_page(cr3_task);
      push_page(page_table);
      push_page(new_stack0);
      push_page(new_stack3);
      kfree_s(new_task_struct, sizeof(task_struct));
      kfree_s(new_tss, sizeof(tss_struct));
      result := -ENOMEM;   { FIXME: may be we could use another error code }
      exit;
   end;

   { We are going to fill the new process TSS }
   init_tss(new_tss);
   new_tss^.esp0   := new_stack0 + 4096;
   new_tss^.esp    := pointer(r_esp);
   new_tss^.ebp    := pointer(r_ebp);
   new_tss^.cr3    := cr3_task;
   new_tss^.eflags := $202;
   new_tss^.eax    := 0;   { Return value for the child }
   new_tss^.eip    := ret_adr;

   { Fill global page directory (We copy the parent's one }
   memcpy(cr3_original, cr3_task, 4096);

   { Copy user mode stack }
   memcpy(pointer($FFC00000), new_stack3, 4096);

   if (current^.cr3[1022] <> 0) then
   { Current process has extra stack, copying it too }
   begin
      es_ent  := get_free_page();
      es_data := get_free_page();
      if (es_ent = NIL) or (es_data = NIL) then
      begin
         if (es_ent <> NIL) then push_page(es_ent);
	 if (es_data <> NIL) then push_page(es_data);
         printk('sys_fork (%d): I can''t copy the extra stack but let''s continue\n', [current^.pid])
      end
      else
      begin
         memset(es_ent, 0, 4096);
	 memset(es_data, 0, 4096);
	 cr3_task[1022] := longint(es_ent) or USER_PAGE;
	 es_ent[1023]   := longint(es_data) or USER_PAGE;
         memcpy(pointer($FFBFF000), es_data, 4096);
      end;
   end;

   cr3_task[1023] := longint(page_table) or USER_PAGE;
   memset(page_table, 0, 4096);
   page_table[0]  := longint(new_stack3) or USER_PAGE;   { user mode stack }

   {* Les pages physiques sont partagées entre le processus fils et le
    * processus père donc, on enlève le droit d'écrire sur toutes les pages.
    * Si un processus veut écrire dans une page, il déclenchera une
    * 'page_fault' (exception 14) qui lui allouera une nouvelle page afin
    * qu'il puisse écrire dessus (voir int.pp) 
    *
    * NOTE: only the user stack is not shared *}

   i := 1;
   j := 0;
   repeat
   {* We begin with i=1 because we don't care about user mode stack (already
    * initialized) which is entry #0 *}
      if (page_table_original[i] <> 0) then
      begin
         j += 1;
         page_table[i] := page_table_original[i] and (not WRITE_PAGE);
	 page_table_original[i] := page_table_original[i] and (not WRITE_PAGE);
	 asm
	    pushfd
	    cli
	 end;
	 shared_pages += 1;
	 mem_map[MAP_NR(pointer(page_table[i] and $FFFFF000))].count += 1;
	 asm
	    popfd
	 end;
      end;
      i += 1;
   until (j = current^.size);

   result := new_pid;   { Return value for the parent }

   {$IFDEF DEBUG}
      printk('sys_fork: %h %h %h %h (%h)\n', [current^.p_pptr, current^.p_cptr, current^.p_ysptr, current^.p_osptr, current]);
      printk('sys_fork: %h %h %h %h (%h)\n', [new_task_struct^.p_pptr, new_task_struct^.p_cptr, new_task_struct^.p_ysptr,
					      new_task_struct^.p_osptr, new_task_struct]);

      printk('EXITING FROM SYS_FORK (ret_adr = %h) new_pid=%d\n', [ret_adr, new_pid]);
   {$ENDIF}

{printk('sys_fork (%d): new pid=%d\n', [current^.pid, new_pid]);}

   asm
      pushfd
      cli   { Critical section }
      mov   eax, cr3   { FIXME: do we really need this ??? }
      mov   cr3, eax
   end;

   add_task(new_task_struct);

   asm
      popfd
   end;

end;



{******************************************************************************
 * copy_mm
 *
 * FIXME: Another solution ??? A faster procedure ???
 *****************************************************************************}
procedure copy_mm (p : P_task_struct);

var
   first_req, req : P_mmap_req;
   {$IFDEF DEBUG_COPY_MM}
   i : dword;
   {$ENDIF}

begin

   first_req := current^.mmap;
   p^.mmap   := NIL;

   {$IFDEF DEBUG_COPY_MM}
      i := 0;
   {$ENDIF}

   if (first_req <> NIL) then
   begin
      add_mmap_req(p, first_req^.addr, first_req^.size);
      req := first_req^.next;
      {$IFDEF DEBUG_COPY_MM}
         i += 1;
      {$ENDIF}
      while (req <> first_req) do
      begin
         {$IFDEF DEBUG_COPY_MM}
	    i += 1;
	 {$ENDIF}
         add_mmap_req(p, req^.addr, req^.size);   
	 req := req^.next;
      end;
   end;

   {$IFDEF DEBUG_COPY_MM}
      printk('copy_mm: %d request have been copied from %d to %d\n', [i, current^.pid, p^.pid]);
   {$ENDIF}

end;



{******************************************************************************
 * kernel_thread
 *
 * INPUT : Thread entry point
 *
 * This procedure creates a kernel thread
 *
 * NOTE: this procedure is not used for the moment
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
   new_stack0 := get_free_page;
   new_stack3 := get_free_page;
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
