{******************************************************************************
 *  exec.pp
 *
 *  exec() system call implementation
 *
 *  Copyleft (C) 2002
 *
 *  version 0.4 - 22/02/2003 - GaLi - remove a bug in sys_exec(). (wasn't
 *                                    correctly filling new process pages table)
 *  version 0.3 - 20/02/2003 - GaLi - sys_exec() now REALLY supports arguments
 *  version 0.2 - 20/01/2003 - GaLi - Try to make sys_exec() support arguments
 *
 *  version 0.0 - 16/10/2002 - GaLi - initial version
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
{DEFINE DEBUG_ARGS}
{DEFINE SHOW_HEADER}
{DEFINE SHOW_PROGRAM_TABLE}


{* External procedure and functions *}
function  access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; external;
procedure farjump (tss : word ; ofs : pointer); external;
function  get_free_page : pointer; external;
function  get_free_mem : dword; external;
function  get_pt_entry (addr : P_pte_t) : pointer; external;
procedure kfree_s (buf : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
function  MAP_NR (adr : pointer) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
function  namei (path : pointer) : P_inode_t; external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_adr : pointer); external;
procedure set_pt_entry (addr : P_pte_t ; val : dword); external;
procedure unload_page_table (pt : P_pte_t); external;


{* External variables *}
var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   mem_map : P_page; external name 'U_MEM_MEM_MAP';


{* Exported variables *}


{* Procedures and functions only used in THIS file *}
function sys_exec (path : pointer ; args, envp : pointer) : dword; cdecl;



IMPLEMENTATION



{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * get_arg_length
 *
 * Returns size in bytes of the argument pointed to by arg_ptr
 *
 * used by sys_exec
 *****************************************************************************}
function get_arg_length (arg_ptr : pointer) : dword;

var
   count : dword;

begin

   count := 0;

   while (chr(byte(arg_ptr^)) <> #0) do
   begin
      count   += 1;
      arg_ptr += 1;
   end;

   result := count + 1;   { We add 1 to count the null terminating character }

end;



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
 * FIXME: Check alignment in ELF file.
 *        For the moment, we don't care about envp.
 *****************************************************************************}
function sys_exec (path : pointer ; args, envp : pointer) : dword; cdecl; [public, alias : 'SYS_EXEC'];

var
   phdr_table       : P_elf_phdr;
   elf_header       : P_elf_header_t;
   tmp_file         : file_t;
   tmp_inode        : P_inode_t;
   i, j, tmp        : dword;
   buf, dest        : pointer;
   entry, old_entry : pointer;
   dest_ofs, ofs    : dword;
   process_mem, process_pages : dword;
   r_esp, len       : dword;
   num_args         : dword;
   ret_adr          : pointer;

   pages_to_read    : dword;
   new_page_table   : P_pte_t;

   args_addr        : pointer;  { Calling process arguments address }
   stack_addr       : pointer;  { Stack address for the new process }
   args_page        : pointer;  { Virtual address where new process arguments are stored }
   args_page_ofs    : pointer;
   nb_args          : dword;
   args_length      : dword;
   cur_arg_length   : dword;

   test : pointer;

begin

   {$IFDEF DEBUG}
      printk('Welcome in sys_exec (%c%s)\n', [chr(byte(path^)), path]);
   {$ENDIF}

   asm
      sti   { Puts interrupts on }
   end;

   {* First check, if parameters are correct.
    *
    * NOTE: It's normal for process #2 to call sys_exec() without any parameters *}
   if (pointer(args^) = NIL) then
       begin
          if (current^.pid <> 2) then
                 printk('WARNING: sys_exec() called with no arguments\n', []);
       end;

   if (pointer(envp^) = NIL) then
        begin
          if (current^.pid <> 2) then
              printk('WARNING: sys_exec() called with no environment variables pointer\n', []);
        end;

   buf       := get_free_page();   { Instead of kmalloc }
   tmp_inode := namei(path);

   if (buf = NIL) then
       begin
          printk('exec: not enough memory\n', []);
	  kfree_s(tmp_inode, sizeof(inode_t));
	  result := -1;
	  exit;
       end;

   if (longint(tmp_inode) < 0) then
   { namei() returned an error code, not a valid pointer }
   begin
      {$IFDEF DEBUG}
         printk('exec: no inode returned by namei()\n', []);
      {$ENDIF}
      push_page(buf);   { Instead of kfree_s }
      result := longint(tmp_inode);
      exit;
   end;

   {* Check if we can execute this file *}
   if not access_rights_ok(I_XO, tmp_inode) then
   begin
      printk('exec: permission denied\n', []);
      push_page(buf);   { Instead of kfree_s }
      kfree_s(tmp_inode, sizeof(inode_t));
      result := -1;
      exit;
   end;

   {* Inode's file has been found. Going to read the first 4096 bytes to look
    * for an ELF header *}

   tmp_file.inode := tmp_inode;
   tmp_file.pos   := 0;
   tmp_file.op    := tmp_inode^.op^.default_file_ops;
   { We just don't care about filing the whole file structure }

   if (tmp_inode^.op = NIL) or (tmp_file.op = NIL) or 
      (tmp_file.op^.read = NIL) then
       begin
          printk('exec: cannot call read() for %c%s\n', [chr(byte(path^)), path]);
	  push_page(buf);   { Instead of kfree_s }
	  kfree_s(tmp_inode, sizeof(inode_t));
	  result := -1;
	  exit;
       end;

   {* Read the first 4096 bytes of the file
    *
    * NOTE: dest_ofs could be < 4096 if file size is < 4096 *}
   dest_ofs := tmp_file.op^.read(@tmp_file, buf, 4096);
   if (dest_ofs < 1) then
       begin
          printk('exec: cannot read %c%s (ret = %d)\n', [chr(byte(path^)), path, dest_ofs]);
	  push_page(buf);   { Instead of kfree_s }
	  kfree_s(tmp_inode, sizeof(inode_t));
	  result := -1;
	  exit;
       end;

   elf_header := buf;

   {$IFDEF SHOW_HEADER}
      printk('%s (%d bytes) ELF header dump:\n', [path, tmp_inode^.size]);
      printk('Class: %d (0: Invalid  1: 32 bits  2: 64 bits)\n', [elf_header^.e_ident[EI_CLASS]]);
      printk('Data : %d (0: Invalid  1: LSB  2: MSB)\n', [elf_header^.e_ident[EI_DATA]]);
      printk('Type : %d (0: None  1: Reloc  2: Exec  3: Shared  4: Core)\n', [elf_header^.e_type]);
      printk('Arch : %d (0: None  1: AT&T 32100  2: Sparc  3: x86  4: 68k  5: 88k  6: 860)\n', [elf_header^.e_machine]);
      printk('Vers : %d (0: None  1: Current)\n', [elf_header^.e_version]);
      printk('Entry: %h  Flags: %h  Header size: %h\n', [elf_header^.e_entry, elf_header^.e_flags, elf_header^.e_ehsize]);
      printk('phoff: %h  %d entries (%d bytes each)\n\n', [elf_header^.e_phoff, elf_header^.e_phnum, elf_header^.e_phentsize]);
   {$ENDIF}

   { Check ELF header }
   if (elf_header^.e_ident[EI_MAG0]    <> ELFMAG0) or
      (elf_header^.e_ident[EI_MAG1]    <> ELFMAG1) or
      (elf_header^.e_ident[EI_MAG2]    <> ELFMAG2) or
      (elf_header^.e_ident[EI_MAG3]    <> ELFMAG3) or
      (elf_header^.e_ident[EI_CLASS]   <> ELFCLASS32) or
      (elf_header^.e_ident[EI_DATA]    <> ELFDATA2LSB) or
      (elf_header^.e_type              <> ET_EXEC) or
      (elf_header^.e_machine           <> EM_386) or
      (elf_header^.e_version           <> 1) then
      begin
         printk('exec: %c%s has an invalid ELF header\n', [chr(byte(path^)), path]);
	 push_page(buf);   { Instead of kfree_s }
	 kfree_s(tmp_inode, sizeof(inode_t));
	 result := -1;
	 exit;
      end;


   { ELF header seems to be ok. Going to load program and launch it. }


   {* First, we read the program header table (In fact, we have already read it
    * because it's in the 4096 first bytes of the file *}

   phdr_table := pointer(longint(elf_header) + elf_header^.e_phoff);

   {$IFDEF SHOW_PROGRAM_TABLE}
      printk('Program header table:\n', []);
      for i := 0 to (elf_header^.e_phnum - 1) do
      begin
         printk('Segment %d\n', [i]);
	 printk('Type: %d  Offset: %h\n', [phdr_table[i].p_type, phdr_table[i].p_offset]);
	 printk('vaddr: %h  paddr: %h  filesz: %d  memsz: %d\n', [phdr_table[i].p_vaddr, phdr_table[i].p_paddr, phdr_table[i].p_filesz, phdr_table[i].p_memsz]);
	 printk('flags: %h  align: %d\n', [phdr_table[i].p_flags, phdr_table[i].p_align]);
      end;
   {$ENDIF}

   process_mem := phdr_table[0].p_offset; {longint(elf_header^.e_entry) and $FFF;}
   len         := process_mem;
   for i := 0 to (elf_header^.e_phnum - 1) do
       begin
          process_mem += phdr_table[i].p_memsz;
	  len         += phdr_table[i].p_filesz;
       end;

   {$IFDEF DEBUG}
      printk('exec: On-disk size: %d  memory size: %d\n', [len, process_mem]);
   {$ENDIF}

   pages_to_read := len div 4096;
   if (len mod 4096 <> 0) then
       pages_to_read += 1;

   process_pages := process_mem div 4096;
   if (process_mem mod 4096 <> 0) then
       process_pages += 1;

   if ((pointer(args^) <> NIL) or (pointer(envp^) <> NIL)) then
       process_pages += 1;   { We add 1 page to store arguments and environment variables }

   if (process_pages > 1023) then
       begin
          printk('exec: %c%s cannot be load by DelphineOS (>4Mb)\n', [chr(byte(path^)), path]);
	  push_page(buf);   { Instead of kfree_s }
	  kfree_s(tmp_inode, sizeof(inode_t));
	  result := -1;
	  exit;
       end;

   {$IFDEF DEBUG}
      printk('exec: going to read %d pages (total pages: %d+1)\n', [pages_to_read, process_pages - 1]);
   {$ENDIF}

   new_page_table := get_free_page;   { Instead of kmalloc }
   if (new_page_table = NIL) then
       begin
          printk('exec: not enough memory to allocate a new page table\n', []);
	  push_page(buf);   { Instead of kfree_s }
	  kfree_s(tmp_inode, sizeof(inode_t));
	  result := -1;
	  exit;
       end;

   new_page_table[0] := current^.page_table[0];   { User mode statck entry }
   new_page_table[1] := longint(buf) or USER_PAGE;

   { We already have load the first program page. We're going to load the
     others }
   for i := 2 to (pages_to_read) do
       begin
          buf := get_free_page;   { Instead of kmalloc }
	  if (buf = NIL) then
	      begin
	         printk('exec: not enough memory\n', []);
		 unload_page_table(new_page_table);
		 kfree_s(tmp_inode, sizeof(inode_t));
		 result := -1;
		 exit;
	      end;
	  len := tmp_file.op^.read(@tmp_file, buf, 4096);
	  if (len < 1) then
	      begin
	         printk('exec: cannot read file %c%s (ret = %d)\n', [chr(byte(path^)), path, len]);
		 unload_page_table(new_page_table);
		 kfree_s(tmp_inode, sizeof(inode_t));
		 result := -1;
		 exit;
	      end;
	  new_page_table[i] := longint(buf) or USER_PAGE;
	  {$IFDEF DEBUG}
	     printk('exec: reading page #%d from disk (%h)\n', [i, $FFC00000 + i * 4096]);
	  {$ENDIF}
       end;

   { We now need to allocate pages for the .bss section }

   {$IFDEF DEBUG}
      printk('exec: loading %d pages for .bss section\n', [process_pages - pages_to_read]);
   {$ENDIF}
   for j := (pages_to_read + 1) to process_pages do
       begin
          buf := get_free_page;   { Instead of kmalloc }
	  if (buf = NIL) then
	      begin
	         printk('exec: not enough memory\n', []);
		 unload_page_table(new_page_table);
		 kfree_s(tmp_inode, sizeof(inode_t));
		 result := -1;
		 exit;
	      end;
	  new_page_table[j] := longint(buf) or USER_PAGE;
	  {$IFDEF DEBUG}
	     printk('exec: allocating page #%d for .bss (%h)\n', [j, $FFC00000 + j * 4096]);
	  {$ENDIF}
       end;

   {* Going to read arguments from the calling process user stack and
    * put them in the new process data space *}

   args_addr := args;

   {$IFDEF DEBUG_ARGS}
      printk('exec: args_addr=%h (%h)\n', [args_addr, pointer(args_addr^)]);
   {$ENDIF}

   {* Arguments will be stored in buf (initialized when we have allocate pages
    * for ths .bss section. *}

   stack_addr := $FFC01000 - 4;   { Initial stack address }
   pointer(stack_addr^) := NIL;   { Environnement variables pointer }
   stack_addr -= 4;
   args_page  := pointer($FFC00000 + (j * 4096));   { j is already initialized }

   { First, we have to count the number of arguments }
   nb_args := 0;
   while (pointer(args_addr^) <> NIL) do
   begin
      {$IFDEF DEBUG_ARGS}
         {printk('exec: arg %d is at %h (%d bytes) : %s\n', [nb_args, pointer(args_addr^),
	                                                    get_arg_length(pointer(args_addr^)),
							    pointer(args_addr^)]);}
      {$ENDIF}
      nb_args   += 1;
      args_addr += 4;
   end;

   {* Then, we store arguments in buf. Array of pointers to arguments is in the stack.
    *
    * NOTE: dest      -> physical address where we put arguments
    *       args_page -> virtual address where we put arguments
    *}
   dest       := buf;
   {args_page  += nb_args * 4;}
   args_addr  := args;
   stack_addr -= nb_args * 4;
   for i := 1 to (nb_args) do
   begin
      {$IFDEF DEBUG_ARGS}
         printk('exec: put arg %d at %h <=> %h\n', [i - 1, dest, args_page]);
      {$ENDIF}
      pointer(stack_addr^) := args_page;
      cur_arg_length := get_arg_length(pointer(args_addr^));
      memcpy(pointer(args_addr^), dest, cur_arg_length);
      args_page  += cur_arg_length;
      dest       += cur_arg_length;
      args_addr  += 4;
      stack_addr += 4;
   end;
   stack_addr -= nb_args * 4;   { Final stack_addr }

   { Free all we don't need }
   kfree_s(tmp_inode, sizeof(inode_t));

   asm
      pushfd
      cli   { Turn interrupts off }
   end;

   { Freeing current page table entries but not the user mode stack entry }
   for i := 1 to current^.size do
   begin
      push_page(pointer(longint(current^.page_table[i]) and $FFFFF000));   { Instead of kfree_s }
      current^.page_table[i] := $0;
   end;
   push_page(current^.page_table);   { Instead of kfree_s }

   { We have to update process descriptor }

   current^.ticks      := 0;
   current^.errno      := 0;
   current^.size       := process_pages;
   current^.page_table := new_page_table;
   current^.cr3[1023]  := longint(new_page_table) or USER_PAGE;

   ret_adr := elf_header^.e_entry;

   asm
      mov   eax, cr3
      mov   cr3, eax   { Flush CPU TLB }

      mov   eax, ret_adr
      mov   [ebp + 44], eax   { Modify return address }
   end;

   {$IFDEF DEBUG_ARGS}
      printk('exec: final stack address=%h\n', [stack_addr - 4]);
   {$ENDIF}

   asm
      mov   eax, stack_addr
      sub   eax, 4
      mov   ebx, nb_args
      mov   dword [eax], ebx       { argc -> OK }
      mov   dword [ebp + 56], eax  { Modify stack address }
   end;

   {$IFDEF DEBUG_ARGS}
      printk('exec: Dump new process user stack\n', []);
      i := longint(stack_addr - 4);
      stack_addr := $FFC01000 - 4;
      while (longint(stack_addr) >= i) do
      begin
         test := pointer(stack_addr^);
         printk('exec: %h -> %h (%h)\n', [stack_addr, pointer(stack_addr^), pointer(test^)]);
	 stack_addr -= 4;
      end;
   {$ENDIF}

   {$IFDEF DEBUG}
      printk('Exiting from sys_exec (entry point=%h)\n', [ret_adr]);
   {$ENDIF}

   asm
      popfd
   end;

end;



begin
end.
