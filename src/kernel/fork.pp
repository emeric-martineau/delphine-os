{******************************************************************************
 * fork.pp
 *
 * Create user processes and kernel threads
 *
 * Copyleft 2003 GaLi
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
{DEFINE SHOW_LINKS}
{DEFINE DEBUG_SYS_FORK}
{DEFINE DEBUG_COPY_MM}


INTERFACE


{$I config.inc}
{$I errno.inc}
{$I fs.inc}
{$I mm.inc}
{$I process.inc }
{$I sched.inc }


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   mem_map : P_page; external name 'U_MEM_MEM_MAP';
   shared_pages : dword; external name 'U_MEM_SHARED_PAGES';


procedure add_mmap_req (p : P_task_struct ; addr : pointer ; size : dword ; pgoff : dword ; flags, prot : byte ; count : word ; fichier : P_file_t); external;
procedure add_task (task : P_task_struct); external;
procedure dump_mmap_req (t : P_task_struct); external;
function  get_free_page : pointer; external;
function  get_new_pid : dword; external;
procedure init_tss (tss : P_tss_struct); external;
procedure kfree_s (addr : pointer ; size : dword); external;
function  kmalloc (len : dword) : pointer; external;
function  MAP_NR (adr : pointer) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_adr : pointer); external;
procedure schedule; external;
function  set_tss_desc (addr : pointer) : dword; external;


procedure copy_mm (p : P_task_struct);
procedure copy_stack (p : P_task_struct ; cr3_original : P_pte_t);
procedure kernel_thread (addr : pointer);
function  sys_fork : dword; cdecl;



IMPLEMENTATION


{$I inline.inc}


{******************************************************************************
 * sys_fork
 *
 * INPUT  : None
 * OUTPUT : On success, the PID of the child is returned to the parent and zero
 *    	    is returned to the child.
 *
 *****************************************************************************}
function sys_fork : dword; cdecl; [public, alias : 'SYS_FORK'];

var
   cr3_task, cr3_original                 : P_pte_t;
   es_ent, es_data                        : P_pte_t;   { Use for extra stack }
   tmp, adr                               : pointer;
   page_table, new_page_table             : P_pte_t;
   new_stack0, index, ret_addr 	         : pointer;
   new_task_struct                        : P_task_struct;
   new_tss                                : P_tss_struct;
   r_ebp, r_esp, r_ss, r_cs, eflags       : dword;
   new_pid , i, j, k                      : dword;

begin

   {* First, we have to get the new process start address and some registers
    * saved on the stack by the calling process *}

  asm
     mov   eax, [ebp + 44]
     mov   ret_addr, eax
     mov   eax, [ebp + 28]
     mov   r_ebp, eax
     mov   eax, [ebp + 56]
     mov   r_esp, eax

     {$IFDEF DEBUG_SYS_FORK}
        mov   eax, [ebp + 60]
        mov   r_ss, eax
        mov   eax, [ebp + 48]
        mov   r_cs, eax
     {$ENDIF}

     mov   eax, [ebp + 52]
     mov   eflags, eax
     sti   { Set interrupts on }
  end;

{printk('FORK\n', []);}

   {$IFDEF DEBUG_SYS_FORK}
      print_bochs('\nsys_fork: current(%d) ss: %h4 esp: %h cs: %h4 eip: %h\nsys_fork: eflags: %h ebp: %h brk: %h\n', [current^.pid, r_ss, r_esp, r_cs, ret_addr, eflags, r_ebp, current^.brk]);
   {$ENDIF}

   cr3_task        := get_free_page();   {* New global page directory address for 
                                          * the new process *}
   new_stack0      := get_free_page();   { New stack (kernel mode) }
   new_task_struct := kmalloc(sizeof(task_struct));
   new_tss         := kmalloc(sizeof(tss_struct));
   new_pid         := get_new_pid();

   {* cr3_task    : pointer to the new global page directory
    * page_table  : pointer to the new page table
    * stack_entry : pointer to the page table (for stacks) *}

   { Check if all pointers are correctly initialized }
   if ((new_stack0 = NIL) or (cr3_task = NIL)
   or (new_task_struct = NIL) or (new_tss = NIL)) then
   begin
      if (new_stack0 <> NIL) then push_page(new_stack0);
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
		current^.file_desc[i]^.count += 1;
   end;

{printk('sys_fork (%d): root=%d (%d)  pwd=%d (%d)\n', [current^.pid,
      	             	      	             	      current^.root^.ino,
						      current^.root^.count,
						      current^.pwd^.ino,
						      current^.pwd^.count]);}

   if (current^.root <> NIL) then
       current^.root^.count += 1;

   if (current^.pwd <> NIL) then
       current^.pwd^.count += 1;

   if (current^.executable <> NIL) then
       current^.executable^.count += 1;

   memcpy(current, new_task_struct, sizeof(task_struct));
   new_task_struct^.cr3       := cr3_task;
	new_task_struct^.stime		:= 0;
	new_task_struct^.utime		:= 0;
   new_task_struct^.pid       := new_pid;
   new_task_struct^.ppid      := current^.pid;
   new_task_struct^.tss       := new_tss;
   new_task_struct^.tss_entry := set_tss_desc(new_tss) * 8;
   new_task_struct^.p_pptr    := current;
   new_task_struct^.p_cptr    := NIL;
   new_task_struct^.p_ysptr   := NIL;
   new_task_struct^.p_osptr   := current^.p_cptr;
   if (new_task_struct^.p_osptr <> NIL) then
       new_task_struct^.p_osptr^.p_ysptr := new_task_struct;
   current^.p_cptr := new_task_struct;

   if (new_task_struct^.tss_entry = -1) then
   begin
      printk('sys_fork (%d): cannot set tss_entry\n', [current^.pid]);
      push_page(cr3_task);
      push_page(new_stack0);
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
   new_tss^.eip    := ret_addr;

   { Fill global page directory (We copy the parent's one) }
   memcpy(current^.cr3, cr3_task, 4096);

   copy_stack(new_task_struct, current^.cr3);

   copy_mm(new_task_struct);

   result := new_pid;   { Return value for the parent }

   {$IFDEF SHOW_LINKS}
      print_bochs('sys_fork: %h %h %h %h (%h)\n', [current^.p_pptr, current^.p_cptr, current^.p_ysptr, current^.p_osptr, current]);
      print_bochs('sys_fork: %h %h %h %h (%h)\n', [new_task_struct^.p_pptr, new_task_struct^.p_cptr, new_task_struct^.p_ysptr,
					      new_task_struct^.p_osptr, new_task_struct]);
   {$ENDIF}

   asm
      pushfd
      cli   { Critical section }
      mov   eax, cr3   { FIXME: do we really need this ??? }
      mov   cr3, eax
   end;

   add_task(new_task_struct);

	popfd();

   {$IFDEF DEBUG_SYS_FORK}
      print_bochs('sys_fork (%d): EXITING new pid=%d  ret_addr=%h\n', [current^.pid, new_pid, ret_addr]);
   {$ENDIF}

end;



{******************************************************************************
 * copy_stack
 *
 * Copy the user mode stack
 *****************************************************************************}
procedure copy_stack (p : P_task_struct ; cr3_original : P_pte_t);

var
   stack_addr      : pointer;
   pt, pt_original : P_pte_t;
   i               : dword;

begin

	{$IFDEF DEBUG}
		print_bochs('sys_fork (%d): copying stack\n', [current^.pid]);
	{$ENDIF}

   pt := get_free_page();
   if (pt = NIL) then
   begin
      printk('copy_stack: not enough memory (1)\n', []);
      exit;
   end;

   pt_original := pointer(cr3_original[768] and $FFFFF000);
   p^.cr3[768] := longint(pt) or USER_PAGE;

   for i := 1023 downto 0 do
   begin
      if (pt_original[i] <> 0) then
      begin
			stack_addr := get_free_page();
	 		if (stack_addr = NIL) then
	 		begin
	    		printk('copy_stack: not enough memory (2)\n', []);
	    		exit;
	 		end;
	 		memcpy(pointer(pt_original[i] and $FFFFF000), stack_addr, 4096);
	 		pt[i] := longint(stack_addr) or USER_PAGE;
      end
      else
			break;
   end;

end;



{******************************************************************************
 * copy_mm
 *
 * NOTE: Another solution ??? A faster procedure ???
 *****************************************************************************}
procedure copy_mm (p : P_task_struct);

var
	i, j, k			: dword;
   first_req, req : P_mmap_req;
	page_table		: P_pte_t;
	new_page_table : P_pte_t;
	cr3_task 		: P_pte_t;

label stop_copy;

begin

	{$IFDEF DEBUG_COPY_MM}
		print_bochs('sys_fork (%d): copying memory info (size=%d, real_size=%d)\n',
						[current^.pid, current^.size, current^.real_size]);
	{$ENDIF}

	cr3_task := p^.cr3;

   {* Les pages physiques sont partagées entre le processus fils et le
    * processus père donc, on enlève le droit d'écrire sur toutes les pages.
    * Si un processus veut écrire dans une page, il déclenchera une
    * 'page_fault' (exception 14) qui lui allouera une nouvelle page afin
    * qu'il puisse écrire dessus (voir int.pp) 
    *
    * NOTE: only the user stack is not shared *}

   j := 0;
	for i := 0 to 254 do
	begin
		page_table := pointer(current^.cr3[769 + i] and $FFFFF000);
	 	if (page_table <> NIL) then
	 	begin
	   	new_page_table := get_free_page();
	   	if (new_page_table = NIL) then
	   	begin
	     		printk('sys_fork: not enough memory\n', []);
	     		panic('');
	   	end;
	   	memset(new_page_table, 0, 4096);

			{$IFDEF DEBUG_COPY_MM}
				print_bochs('sys_fork (%d): checking page table %d -> ',
								[current^.pid, i]);
			{$ENDIF}

	   	for k := 0 to 1023 do
	   	begin
				if ((page_table[k] and USED_ENTRY) = USED_ENTRY) then
{	     		if (page_table[k] <> 0) and (page_table[k] <> NULL_PAGE) then}
	     		begin
	        		{$IFDEF DEBUG_COPY_MM}
	           		print_bochs('%h %h (%d)  ',
						[page_table[k], page_table[k] and (not WRITE_PAGE), k]);
	        		{$ENDIF}
	        		page_table[k]     := page_table[k] and (not WRITE_PAGE);
		  			new_page_table[k] := page_table[k];
					if ((page_table[k] and $FFFFF000) <> 0) then
					begin
						pushfd();
						cli();
						shared_pages += 1;
		  				mem_map[page_table[k] shr 12].count += 1;
						popfd();
					end;
		  			j += 1;
					if (j = current^.size) then goto stop_copy;
	     		end;
	   	end;

			{$IFDEF DEBUG_COPY_MM}
				print_bochs('%d\n', [j]);
			{$ENDIF}

	   	cr3_task[769 + i] := longint(new_page_table) or USER_PAGE;
	 	end;
	end;

stop_copy:
	cr3_task[769 + i] := longint(new_page_table) or USER_PAGE;

   {$IFDEF DEBUG_COPY_MM}
      print_bochs('\n', []);
   {$ENDIF}

   first_req := current^.mmap;
   p^.mmap   := NIL;

   {$IFDEF DEBUG_COPY_MM}
      i := 0;
   {$ENDIF}

   if (first_req <> NIL) then
   begin
      add_mmap_req(p, first_req^.addr, first_req^.size, first_req^.pgoff, first_req^.flags, first_req^.prot, first_req^.count, first_req^.fichier);
      req := first_req^.next;
      {$IFDEF DEBUG_COPY_MM}
         i += 1;
      {$ENDIF}
      while (req <> first_req) do
      begin
         {$IFDEF DEBUG_COPY_MM}
	    		i += 1;
	 		{$ENDIF}
         add_mmap_req(p, req^.addr, req^.size, req^.pgoff, req^.flags, req^.prot, req^.count, req^.fichier);   
	 		req := req^.next;
      end;
   end;

   {$IFDEF DEBUG_COPY_MM}
      print_bochs('copy_mm: %d request have been copied from %d to %d\n', [i, current^.pid, p^.pid]);
   {$ENDIF}

end;



{******************************************************************************
 * kernel_thread
 *
 * INPUT : Thread entry point
 *
 * This procedure creates a kernel thread
 *
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

	{$IFDEF DEBUG_KERNEL_THREAD}
		print_bochs('kernel_thread: addr=%h\n', [addr]);
	{$ENDIF}

   tss        := kmalloc(sizeof(tss_struct));
   new_stack0 := get_free_page();
   new_stack3 := get_free_page();
   new_task   := kmalloc(sizeof(task_struct));

   if ((tss = NIL) or (new_stack0 = NIL)
   or (new_stack3 = NIL) or (new_task = NIL)) then
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

   { FIXME: really complete 'new_task' structure }

   memset(new_task, 0, sizeof(task_struct));
   new_task^.tss_entry := tss_entry;
   new_task^.tss       := tss;
   new_task^.pid       := get_new_pid();
   new_task^.uid       := 0;
   new_task^.gid       := 0;
   new_task^.ppid      := 0;   { Kernel thread have no parent }

	{$IFDEF DEBUG_KERNEL_THREAD}
		print_bochs('kernel_thread: PID=%d TSS=%d\n', [new_task^.pid, new_task^.tss_entry]);
	{$ENDIF}

	pushfd();
	cli();

   add_task(new_task);

	popfd();

end;



begin
end.
