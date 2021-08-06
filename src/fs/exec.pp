{******************************************************************************
 *  exec.pp
 *
 *  exec() system call implementation
 *
 *  Each process have up to 1Gb for his text, data and bss sections and 4Mb
 *  for his stack (minus arguments and environment variables size).
 *
 *  Copyleft (C) 2003
 *
 *  version 0.6 - 20/10/2003 - GaLi - Use demand paging.
 *
 *  version 0.0 - 16/10/2002 - GaLi - Initial version
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit _exec;


INTERFACE


{$I elf.inc}
{$I errno.inc}
{$I fs.inc}
{$I mm.inc}
{$I process.inc}

{DEFINE DEBUG}
{DEFINE DEBUG_SYS_EXEC}
{DEFINE DEBUG_ARGS}
{DEFINE DEBUG_COPY_STRINGS}
{DEFINE DEBUG_SET_STACK}
{DEFINE SHOW_HEADER}
{DEFINE SHOW_PROGRAM_TABLE}


{* External procedure and functions *}

function  access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; external;
procedure del_mmap_req (req : P_mmap_req); external;
procedure dump_mmap_req (t : P_task_struct); external;
procedure farjump (tss : word ; ofs : pointer); external;
procedure free_inode (inode : P_inode_t); external;
function  get_free_page : pointer; external;
function  get_free_mem : dword; external;
function  get_pte (addr : dword) : P_pte_t; external;
procedure kfree_s (buf : pointer ; len : dword); external;
procedure lock_inode (inode : P_inode_t); external;
function  MAP_NR (adr : pointer) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
function  namei (path : pointer) : P_inode_t; external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_adr : pointer); external;
procedure set_pte (addr : dword ; pte : pte_t); external;
function  sys_close (fd : dword) : dword; cdecl; external;
procedure unload_process_cr3 (pt : P_task_struct); external;
procedure unlock_inode (inode : P_inode_t); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   mem_map : P_page; external name 'U_MEM_MEM_MAP';


{* Exported variables *}


{* Procedures and functions only used in THIS file *}

function  check_ELF_header (elf_header : P_elf_header_t ; path : pchar ; inode : P_inode_t) : dword;
function  check_Script_header (buf : pchar ; path : pchar ; inode : P_inode_t) : dword;
function  copy_strings (arg : pointer ; count : dword ; arg_pages : array of pointer ; p : longint) : dword;
function  count (argv : pointer) : dword;
function  set_stack (arg_pages : array of pointer ; p : pointer ; argc, envc : dword) : pointer;
function  sys_exec (path : pointer ; argv, envp : pointer) : dword; cdecl;



IMPLEMENTATION


{$I inline.inc}


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}




{******************************************************************************
 * sys_exec
 *
 * Input  : path -> Pointer to the path name for new process image file.
 *          args -> Pointer to an array of arguments to pass to new process.
 *          envp -> Pointer to an array of characters pointers to the
 *                  environment strings.
 *
 * Output : -1 on error, never returns on success
 *
 * FIXME: - Check alignment in ELF file.
 *****************************************************************************}
function sys_exec (path : pointer ; argv, envp : pointer) : dword; cdecl; [public, alias : 'SYS_EXEC'];

var
   phdr_table       : P_elf_phdr;
   elf_header       : P_elf_header_t;
   tmp_file         : file_t;
   tmp_inode        : P_inode_t;
   i, tmp           : dword;

   process_mem, process_pages : dword;
   len, res, p      : longint;
   buf, ret_adr     : pointer;
   new_page_table   : P_pte_t;
   argc, envc       : dword;
   stack_addr       : pointer;  { Stack address for the new process }
   arg_pages        : array[0..(MAX_ARG_PAGES - 1)] of pointer;

   {$IFDEF DEBUG_ARGS}
   test, tmp_stack_addr : pointer;
   {$ENDIF}

begin

print_bochs('\nsys_exec (%d): (%s) args: %h envp: %h\n',
				[current^.pid, path, argv, envp]);

   {$IFDEF DEBUG_SYS_EXEC}
      print_bochs('sys_exec (%d): (%s) args: %h envp: %h\n', [current^.pid, path, argv, envp]);
   {$ENDIF}

	sti();

   {$IFDEF DEBUG_SYS_EXEC}
      print_bochs('sys_exec (%d): going to call namei(%s)\n', [current^.pid, path]);
   {$ENDIF}

   tmp_inode := namei(path);
   if (longint(tmp_inode) < 0) then
   { namei() returned an error code, not a valid pointer }
   begin
      {$IFDEF DEBUG_SYS_EXEC}
         print_bochs('sys_exec (%d): no inode returned by namei()\n', [current^.pid]);
      {$ENDIF}
      result := longint(tmp_inode);
      exit;
   end;

   lock_inode(tmp_inode);

   {$IFDEF DEBUG_SYS_EXEC}
      print_bochs('sys_exec (%d): checking access rights\n', [current^.pid]);
   {$ENDIF}

   {* Check if we can execute this file *}
   if not access_rights_ok(I_XO, tmp_inode) then
   begin
      free_inode(tmp_inode);
      result := -ENOEXEC;
      exit;
   end;

   {* Inode's file has been found. Going to read the first 4096 bytes to look
    * for an ELF or a script header *}

   memset(@tmp_file, 0, sizeof(file_t));
   tmp_file.inode := tmp_inode;
   tmp_file.op    := tmp_inode^.op^.default_file_ops;
   { NOTE: We just don't care about filing the whole file structure }

   if (tmp_inode^.op = NIL) or (tmp_file.op = NIL) or (tmp_file.op^.read = NIL) then
   begin
      printk('sys_exec (%d): read function not defined for for %s\n', [current^.pid, path]);
      free_inode(tmp_inode);
      result := -1;   { FIXME: another error code ??? }
      exit;
   end;
   
   buf := get_free_page();   
   if (buf = NIL) then
   begin
      printk('sys_exec (%d): not enough memory\n', [current^.pid]);
      result := -ENOMEM;
      exit;
   end;

   {$IFDEF DEBUG_SYS_EXEC}
      print_bochs('sys_exec (%d): reading header\n', [current^.pid]);
   {$ENDIF}

   {* Read the first 4096 bytes of the file
    *
    * NOTE: res could be < 4096 if file size is < 4096 *}
   res := tmp_file.op^.read(@tmp_file, buf, 4096);
   if (res < 1) then
   begin
      printk('sys_exec (%d): cannot read %s (ret = %d)\n', [current^.pid, path, res]);
      push_page(buf);
      unlock_inode(tmp_inode);
      free_inode(tmp_inode);
      result := res;
      exit;
   end;

   result := -ENOEXEC;

   {$IFDEF DEBUG_SYS_EXEC}
      print_bochs('sys_exec (%d): checking header\n', [current^.pid]);
   {$ENDIF}

   res := check_ELF_header(buf, path, tmp_inode);
   if (res <> 0) then
   begin
      res := check_Script_header(buf, path, tmp_inode);
      if (res <> 0) then
      	  exit
      else
          { NOTE: ksh seems to run scripts on his own }
          {printk('sys_exec (%d): script cannot be executed (still in progress)\n',[current^.pid]);}
          exit;
   end;

   unlock_inode(tmp_inode);

   { ELF header seems to be ok. }

   {* First, we read the program header table (In fact, we have already read it
    * because it's in the 4096 first bytes of the file *}

   elf_header := buf;
   phdr_table := pointer(longint(elf_header) + elf_header^.e_phoff);

   {$IFDEF SHOW_PROGRAM_TABLE}
      print_bochs('Program header table:\n', []);
      for i := 0 to (elf_header^.e_phnum - 1) do
      begin
         print_bochs('Segment %d\n', [i]);
	 		print_bochs('Type: %d  Offset: %h\n', [phdr_table[i].p_type, phdr_table[i].p_offset]);
	 		print_bochs('vaddr: %h  paddr: %h  filesz: %d  memsz: %d\n', [phdr_table[i].p_vaddr, phdr_table[i].p_paddr, phdr_table[i].p_filesz, phdr_table[i].p_memsz]);
	 		print_bochs('flags: %h  align: %d\n', [phdr_table[i].p_flags, phdr_table[i].p_align]);
      end;
   {$ENDIF}

   if ((phdr_table[1].p_vaddr and $FFF) <> 0) or
      ((phdr_table[2].p_vaddr and $FFF) <> 0) then
   begin
      printk('sys_exec (%d): invalid program table (%s)\n', [current^.pid, path]);
      result := -ENOEXEC;
      exit;
   end;

   len         := (phdr_table[1].p_vaddr - BASE_ADDR) + phdr_table[1].p_filesz;
   process_mem := (phdr_table[2].p_vaddr - BASE_ADDR) + phdr_table[2].p_memsz;

   process_pages := process_mem div 4096;
   if (process_mem mod 4096 <> 0) then
       process_pages += 1;

   {$IFDEF DEBUG_SYS_EXEC}
      print_bochs('sys_exec (%d): On-disk size: %d  memory size: %d -> %d pages\n',
						[current^.pid, len, process_mem, process_pages]);
   {$ENDIF}




{--------------------------------------------------------------------------------------------}


   if (current^.mmap <> NIL) then
   begin
      repeat
			del_mmap_req(current^.mmap);
      until (current^.mmap = NIL);
   end;

   {* Going to read arguments from the calling process and
    * put them in the new process data space *}

   argc := count(argv);
   envc := count(envp);

   for i := 0 to (MAX_ARG_PAGES - 2) do
       arg_pages[i] := NIL;

   arg_pages[MAX_ARG_PAGES - 1] := get_free_page();
   if (arg_pages[MAX_ARG_PAGES - 1] = NIL) then
   begin
      printk('sys_exec: not enough memory to set the stack\n', []);
      result := -ENOMEM;
      exit;
   end;

   memset(arg_pages[MAX_ARG_PAGES - 1], 0, 4096);

   p := MAX_ARG_PAGES * 4096;

   p := copy_strings(envp, envc, arg_pages, p);
   if (p = 0) then
   begin
      printk('sys_exec (%d): not enough memory during copy_strings() (1)\n', [current^.pid]);
      result := -ENOMEM;
      exit;
   end;

   p := copy_strings(argv, argc, arg_pages, p);
   if (p = 0) then
   begin
      printk('sys_exec (%d): not enough memory during copy_strings() (2)\n', [current^.pid]);
      result := -ENOMEM;
      exit;
   end;

   { Now, we check if some file descriptors have got the close_on_exec flag set }
   if (current^.close_on_exec <> 0) then
   begin
      {$IFDEF DEBUG_SYS_EXEC}
         print_bochs('sys_exec (%d): we have to close some files (%h)\n', [current^.pid, current^.close_on_exec]);
      {$ENDIF}
      tmp := current^.close_on_exec;
      while (tmp <> 0) do
      begin
         asm
            mov   eax, tmp
	    		bsf   ebx, eax
	    		mov   tmp, ebx
	    		btr   eax, ebx
	    		mov   i  , eax
         end;
	 		{$IFDEF DEBUG_SYS_EXEC}
	    		print_bochs('sys_exec (%d): calling sys_close(%d)\n', [current^.pid, tmp]);
         {$ENDIF}
         sys_close(tmp);
         {$IFDEF DEBUG_SYS_EXEC}
            print_bochs('sys_exec (%d): tmp=%d %h\n', [current^.pid, tmp, i]);
	 		{$ENDIF}
	 		tmp := i;
      end;
   end;

	{$IFDEF DEBUG_SYS_EXEC}
		print_bochs('sys_exec (%d): Unloading process cr3\n', [current^.pid]);
	{$ENDIF}
   unload_process_cr3(current);


   { We have to update process descriptor. FIXME: update is not completly done }

   current^.end_code   := page_align(phdr_table[0].p_vaddr + phdr_table[0].p_memsz);
   current^.end_data   := page_align(phdr_table[1].p_vaddr + phdr_table[1].p_memsz);
   current^.brk        := page_align(phdr_table[2].p_vaddr + phdr_table[2].p_memsz);
	current^.mmap  	  := NIL;
   current^.size  	  := process_pages;
   current^.real_size  := 1;
   current^.first_size := process_pages;
   current^.executable := tmp_inode;
   current^.wait_queue := NIL;

   new_page_table := get_free_page();
   if (new_page_table = NIL) then
   begin
      printk('sys_exec (%d): not enough memory for a new page table\n', [current^.pid]);
      result := -ENOMEM;
      exit;
   end;

   memset(new_page_table, 0, 4096);

   for i := 770 to 1023 do
       current^.cr3[i] := 0;

   current^.cr3[769] := longint(new_page_table) or USER_PAGE;

	set_pte(BASE_ADDR, longint(buf) or RDONLY_PAGE);

	i := BASE_ADDR + 4096;
	while i <= (current^.brk - 4096) do
	begin
		set_pte(i, USED_ENTRY);
		i += 4096;
	end;

   p := BASE_ADDR - ((MAX_ARG_PAGES * 4096) - p);

   stack_addr := set_stack(arg_pages, pointer(p), argc, envc);

	current^.arg_addr := stack_addr;

   ret_adr := elf_header^.e_entry;

   asm
      mov   eax, cr3
      mov   cr3, eax

      mov   eax, ret_adr
      mov   [ebp + 44], eax   { Modify return address }

      mov   eax, stack_addr
      mov   dword [ebp + 56], eax  { Modify stack address }
   end;

   {$IFDEF DEBUG_ARGS}
      print_bochs('sys_exec (%d): New process user stack dump :\n', [current^.pid]);
      i := longint(stack_addr);
      tmp_stack_addr := pointer((p and $FFFFFFFC) - 4);
      while (longint(tmp_stack_addr) >= i) do
      begin
         test := pointer(tmp_stack_addr^);
         print_bochs('sys_exec (%d): %h -> %h (%h)\n', [current^.pid, tmp_stack_addr, test, pointer(test^)]);
	 		tmp_stack_addr -= 4;
      end;
   {$ENDIF}

   {$IFDEF DEBUG_SYS_EXEC}
      print_bochs('sys_exec (%d): exiting  (entry point=%h, brk=%h)\n', [current^.pid, ret_adr, current^.brk]);
   {$ENDIF}

end;



{******************************************************************************
 * check_ELF_header
 *
 *****************************************************************************}
function check_ELF_header (elf_header : P_elf_header_t ; path : pchar ; inode : P_inode_t) : dword;
begin

   { Check ELF header }
   if (elf_header^.e_ident[EI_MAG0]  <> ELFMAG0) or
      (elf_header^.e_ident[EI_MAG1]  <> ELFMAG1) or
      (elf_header^.e_ident[EI_MAG2]  <> ELFMAG2) or
      (elf_header^.e_ident[EI_MAG3]  <> ELFMAG3) or
      (elf_header^.e_ident[EI_CLASS] <> ELFCLASS32) or
      (elf_header^.e_ident[EI_DATA]  <> ELFDATA2LSB) or
      (elf_header^.e_type            <> ET_EXEC) or
      (elf_header^.e_machine         <> EM_386) or
      (elf_header^.e_version         <> 1) then
      begin
   	 	{$IFDEF SHOW_HEADER}
				printk('sys_exec (%d): %s has an invalid ELF header\n', [current^.pid, path]);
         {$ENDIF}
	 		push_page(elf_header);
	 		unlock_inode(inode);
	 		free_inode(inode);
	 		result := -ENOEXEC;
	 		exit;
      end;

   {$IFDEF SHOW_HEADER}
      printk('%s (%d bytes) ELF header dump:\n', [path, inode^.size]);
      printk('Class: %d (0: Invalid  1: 32 bits  2: 64 bits)\n', [elf_header^.e_ident[EI_CLASS]]);
      printk('Data : %d (0: Invalid  1: LSB  2: MSB)\n', [elf_header^.e_ident[EI_DATA]]);
      printk('Type : %d (0: None  1: Reloc  2: Exec  3: Shared  4: Core)\n', [elf_header^.e_type]);
      printk('Arch : %d (0: None  1: AT&T 32100  2: Sparc  3: x86  4: 68k  5: 88k  6: 860)\n', [elf_header^.e_machine]);
      printk('Vers : %d (0: None  1: Current)\n', [elf_header^.e_version]);
      printk('Entry: %h  Flags: %h  Header size: %h\n', [elf_header^.e_entry, elf_header^.e_flags, elf_header^.e_ehsize]);
      printk('phoff: %h  %d entries (%d bytes each)\n\n', [elf_header^.e_phoff, elf_header^.e_phnum, elf_header^.e_phentsize]);
   {$ENDIF}

   if (elf_header^.e_entry < pointer(BASE_ADDR)) then
   begin
      printk('sys_exec (%d): %s has an invalid entry point. (%h)\n', [current^.pid, path, elf_header^.e_entry]);
      if ((longint(elf_header^.e_entry) and $08000000) = $08000000) then
      	 printk('sys_exec (%d): It looks like a GNU/Linux binary file.\n', [current^.pid]);
      push_page(elf_header);
      unlock_inode(inode);
      free_inode(inode);
      result := -ENOEXEC;
      exit;
   end;

   result := 0;

end;



{******************************************************************************
 * check_Script_header
 *
 *****************************************************************************}
function check_Script_header (buf : pchar ; path : pchar ; inode : P_inode_t) : dword;
begin
  if ((buf[0] = '#') and (buf[1] = '!')) then
       result := 0 
  else 
       result := -1;
end;



{******************************************************************************
 * count
 *
 * Returns the number of elements in an array. (used to initialize argc and
   envc)
 *****************************************************************************}
function count (argv : pointer) : dword;

var
   nb : dword;

begin

   nb := 0;
   while (pointer(argv^) <> NIL) do
   begin
      nb   += 1;
      argv += 4;
   end;

   result := nb;

end;



{******************************************************************************
 * set_stack
 *
 * INPUT : arg_pages -> array of pages we have written to
 *    	   p        -> current stack virtual address.
 *         argc      -> nb of arguments
 *         envc      -> nb of environnement variables
 *
 * OUPUT : stack new virtual address
 *****************************************************************************}
function set_stack (arg_pages : array of pointer ; p : pointer ; argc, envc : dword) : pointer;

var
   i, pt_ofs    : dword;
   pag, sp, tmp : pointer;
   argv, envp   : pointer;
   pt 	        : P_pte_t;   { Page table containing stack pages }

begin

{printk('set_stack: p=%d MAX=%d  argc=%d envc=%d\n', [p, MAX_ARG_PAGES * 4096, argc, envc]);}

   result := $DEADBEEF;

   {$IFDEF DEBUG_SET_STACK}
      printk('set_stack: p=%h. %d bytes to write\n', [p, (argc * 4) + (envc * 4) + 12]);
   {$ENDIF}

   pt := get_free_page();
   if (pt = NIL) then
   begin
      printk('set_stack: not enough memory\n', []);
      exit;
   end;

   memset(pt, 0, 4096);

   { pt initialization }
   i  	 := MAX_ARG_PAGES - 1;
   pt_ofs := 1023;

   while (arg_pages[i] <> NIL) do
   begin
      {$IFDEF DEBUG_SET_STACK}
      	 printk('set_stack: entry %d  %h\n', [pt_ofs, arg_pages[i]]);
      {$ENDIF}
      pt[pt_ofs] := longint(arg_pages[i]) or USER_PAGE;
      i      -= 1;
      pt_ofs -= 1;
   end;

   current^.cr3[768] := longint(pt) or USER_PAGE;
   asm
      mov   eax, cr3
      mov   cr3, eax
   end;

   sp   := pointer(longint(p) and $FFFFFFFC);   { Align sp on a 4-byte boundary }
   sp   -= (envc + 1) * 4;
   envp := sp;
   sp   -= (argc + 1) * 4;
   argv := sp;

   sp -= 4;
   longint(sp^) := argc;

   tmp := pointer(longint(argv) + argc * 4);
   longint(tmp^) := 0;   

   while (argc <> 0) do
   begin
      tmp := pointer(longint(argv) + (argc - 1) * 4);
      {$IFDEF DEBUG_SET_STACK}
      	 printk('set_stack: arg%d -> %s\n', [argc, p]);
      {$ENDIF}
      pointer(tmp^) := p;
      while (byte(p^) <> 0) do p += 1;
      p    += 1;
      argc -= 1;
   end;

   tmp := pointer(longint(envp) + envc * 4);
   longint(tmp^) := 0;   

   while (envc <> 0) do
   begin
      tmp := pointer(longint(envp) + (envc - 1) * 4);
      {$IFDEF DEBUG_SET_STACK}
      	 printk('set_stack: arg%d -> %s\n', [envc, p]);
      {$ENDIF}
      pointer(tmp^) := p;
      while (byte(p^) <> 0) do p += 1;
      p    += 1;
      envc -= 1;
   end;

   result := sp;

end;



{******************************************************************************
 * copy_strings
 *
 * INPUT : arg       -> pointer to an array of arguments
 *         count     -> nb of arguments in the array
 *         arg_pages -> array of pages we can write to
 *         p         -> nb of bytes we can write to the pages in 'arg_pages'
 *
 * OUTPUT: New value for 'p' or 0 if there was not enough memory.
 *****************************************************************************}
function copy_strings (arg : pointer ; count : dword ; arg_pages : array of pointer ; p : longint) : dword;

var
   len, offset : longint;
   str         : pchar;
   pag, ptr    : pointer;

begin

   while (count <> 0) do
   begin
      len := 0;
      str := pointer(arg^);

      while (str[len] <> #0) do
      	    len += 1;

      len += 1;   { Because of the null terminating character }

      {$IFDEF DEBUG_COPY_STRINGS}
      	 printk('copy_strings: arg %d (%h) -> %h (%d) p=%d\n', [count, arg, str, len, p]);
      {$ENDIF}

      if (p - len < 0) then   { No more space left in 'arg_pages' }
      begin
			result := p;
	 		exit;
      end;
      
      { We now have to copy the argument to 'arg_pages' }
      offset := 0;
      while (len <> 0) do
      begin
			p      -= 1;
			len    -= 1;
			offset -= 1;
	 		if (offset < 0) then
	 		begin
	    		{$IFDEF DEBUG_COPY_STRINGS}
	       		printk('copy_strings: recalculating offset -> ', []);
	    		{$ENDIF}
	    		offset := p mod 4096;
	    		pag    := arg_pages[p div 4096];
	    		if (pag = NIL) then
	    		begin
	       		pag := get_free_page();
	       		if (pag = NIL) then
	       		begin
	          		printk('copy_strings: not enough memory\n', []);
		   			result := 0;
		   			exit;
	       		end;
	       		arg_pages[p div 4096] := pag;
	    		end;
	    		{$IFDEF DEBUG_COPY_STRINGS}
	       		printk('%d\n', [offset]);
	    		{$ENDIF}
	 		end;
	 		ptr        := pointer(pag + offset);
	 		byte(ptr^) := byte(str[len]);

{      	 print_bochs('moving char %c at ofs %d in page %d (pag=%h -> %h)\n', [byte(str[len]), offset, p div 4096,
	          pag, pointer(pag + offset)]);}

      end;
      
      arg   := arg + 4;   { Next argument }
      count -= 1;
   end;

   result := p;

end;



begin
end.
