{******************************************************************************
 *  exec.pp
 *
 *  exec() system call implementation
 *
 *  Copyleft (C) 2002
 *
 *  version 0.5 - 12/07/2003 - GaLi & Edo - sys_exec() now support environment
 *                                          variables.
 *
 *  version 0.4 - 22/02/2003 - GaLi - remove a bug in sys_exec(). (wasn't
 *                                    correctly filling new process pages table)
 *
 *  version 0.3 - 20/02/2003 - GaLi - sys_exec() now REALLY supports arguments
 *
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
{DEFINE DEBUG_SYS_EXEC}
{DEFINE DEBUG_PAGES_LOADING}
{DEFINE DEBUG_ARGS}
{DEFINE DEBUG_COPY_STRINGS}
{DEFINE SHOW_HEADER}
{DEFINE SHOW_PROGRAM_TABLE}


{* External procedure and functions *}

function  access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; external;
procedure farjump (tss : word ; ofs : pointer); external;
procedure free_inode (inode : P_inode_t); external;
function  get_free_page : pointer; external;
function  get_free_mem : dword; external;
function  get_pt_entry (addr : P_pte_t) : pointer; external;
procedure kfree_s (buf : pointer ; len : dword); external;
procedure lock_inode (inode : P_inode_t); external;
function  MAP_NR (adr : pointer) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
function  namei (path : pointer) : P_inode_t; external;
function  page_align (nb : longint) : dword; external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_adr : pointer); external;
procedure set_pt_entry (addr : P_pte_t ; val : dword); external;
function  sys_close (fd : dword) : dword; cdecl; external;
procedure unload_page_table (pt : P_task_struct); external;
procedure unlock_inode (inode : P_inode_t); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   mem_map : P_page; external name 'U_MEM_MEM_MAP';


{* Exported variables *}


{* Procedures and functions only used in THIS file *}

function  check_ELF_header (elf_header : P_elf_header_t ; path : pchar ; inode : P_inode_t) : dword;
function  check_Script_header (buf : pchar ; path : pchar ; inode : P_inode_t) : dword;
function  copy_strings (stack_addr, args : pointer ; count : dword ; page_table : P_pte_t) : pointer;
function  count (argv : pointer) : dword;
function  sys_exec (path : pointer ; argv, envp : pointer) : dword; cdecl;



IMPLEMENTATION



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
 *        - Free the old page_table
 *****************************************************************************}
function sys_exec (path : pointer ; argv, envp : pointer) : dword; cdecl; [public, alias : 'SYS_EXEC'];

var
   phdr_table       : P_elf_phdr;
   elf_header       : P_elf_header_t;
   tmp_file         : file_t;
   tmp_inode        : P_inode_t;
   i, j, tmp        : dword;
   entry, old_entry : pointer;
   dest_ofs, ofs    : dword;
   process_mem, process_pages : dword;
   len              : longint;
   old_size         : dword;
   buf, ret_adr     : pointer;
   pages_to_read    : dword;
   new_page_table   : P_pte_t;
   argc, envc       : dword;
   req, tmp_req, first_req : P_mmap_req;
   stack_addr, tmp_stack : pointer;  { Stack address for the new process }

   {$IFDEF DEBUG_ARGS}
   test : pointer;
   {$ENDIF}

begin

   {$IFDEF DEBUG_SYS_EXEC}
      printk('sys_exec (%d): (%s) args: %h envp: %h\n', [current^.pid, path, argv, envp]);
   {$ENDIF}

   asm
      sti   { Puts interrupts on }
   end;

   memset(@tmp_file, 0, sizeof(file_t));

   old_size := current^.size;

   {$IFDEF DEBUG_SYS_EXEC}
      printk('sys_exec (%d): going to call namei(path)\n', [current^.pid]);
   {$ENDIF}
   tmp_inode := namei(path);

   if (longint(tmp_inode) < 0) then
   { namei() returned an error code, not a valid pointer }
   begin
      {$IFDEF DEBUG_SYS_EXEC}
         printk('sys_exec (%d): no inode returned by namei()\n', [current^.pid]);
      {$ENDIF}
      result := longint(tmp_inode);
      exit;
   end;

   lock_inode(tmp_inode);

   {* Check if we can execute this file *}
   if not access_rights_ok(I_XO, tmp_inode) then
   begin
      free_inode(tmp_inode);
      result := -ENOEXEC;
      exit;
   end;

   {* Inode's file has been found. Going to read the first 4096 bytes to look
    * for an ELF or a script header *}

   tmp_file.inode := tmp_inode;
   tmp_file.pos   := 0;
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

   {* Read the first 4096 bytes of the file
    *
    * NOTE: dest_ofs could be < 4096 if file size is < 4096 *}
   dest_ofs := tmp_file.op^.read(@tmp_file, buf, 4096);
   if (dest_ofs < 1) then
   begin
      printk('sys_exec (%d): cannot read %s (ret = %d)\n', [current^.pid, path, dest_ofs]);
      push_page(buf);
      free_inode(tmp_inode);
      unlock_inode(tmp_inode);
      result := dest_ofs;
      exit;
   end;

   elf_header := buf;
   tmp := check_ELF_header(buf, path, tmp_inode);
   if (tmp <> 0) then
   begin
      tmp := check_Script_header(buf, path, tmp_inode);
      if (tmp <> 0) then
      begin
         unlock_inode(tmp_inode);
         result := -ENOEXEC;
         exit;
      end
      else
      begin
         { NOTE: ksh seems to run scripts on his own }
         {printk('sys_exec (%d): script cannot be executed (still in progress)\n',[current^.pid]);}
	 unlock_inode(tmp_inode);
         result := -ENOEXEC;
         exit;
      end;
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

   {$IFDEF DEBUG_SYS_EXEC}
      printk('sys_exec (%d): On-disk size: %d  memory size: %d\n', [current^.pid, len, process_mem]);
   {$ENDIF}

   pages_to_read := len div 4096;
   if (len mod 4096 <> 0) then
       pages_to_read += 1;

   process_pages := process_mem div 4096;
   if (process_mem mod 4096 <> 0) then
       process_pages += 1;

   if (process_pages > 1023) then
   begin
      printk('sys_exec (%d): %s cannot be loaded by DelphineOS (>4Mb)\n', [current^.pid, path]);
      unlock_inode(tmp_inode);
      push_page(buf);
      free_inode(tmp_inode);
      result := -1;   { FIXME: an other error code ??? }
      exit;
   end;

   {$IFDEF DEBUG_SYS_EXEC}
      printk('sys_exec (%d): going to read %d pages\n', [current^.pid, pages_to_read]);
   {$ENDIF}

   new_page_table := get_free_page();
   if (new_page_table = NIL) then
   begin
      printk('sys_exec (%d): not enough memory to allocate a new page table\n', [current^.pid]);
      unlock_inode(tmp_inode);
      push_page(buf);
      free_inode(tmp_inode);
      result := -ENOMEM;
      exit;
   end;

   { Set unused entries to zero }
   for i := (pages_to_read) to 1023 do
       new_page_table[i] := 0;

   new_page_table[0] := longint(get_free_page()) or USER_PAGE;
   if (new_page_table[0] = USER_PAGE) then
   begin
      printk('sys_exec (%d): not enough memory to allocate a new stack\n', [current^.pid]);
      unlock_inode(tmp_inode);
      push_page(buf);
      free_inode(tmp_inode);
      result := -ENOMEM;
      exit;
   end;
   new_page_table[1] := longint(buf) or USER_PAGE;

   current^.size := 1;

   { We already have load the first program page. We're going to load the
     others }
   for i := 2 to (pages_to_read) do
   begin
      {$IFDEF DEBUG_PAGES_LOADING}
         printk('sys_exec (%d): reading page #%d from disk (%h)\n', [current^.pid, i, $FFC00000 + i * 4096]);
      {$ENDIF}
      buf := get_free_page();
      if (buf = NIL) then
      begin
         printk('sys_exec (%d): not enough memory\n', [current^.pid]);
	 {unload_page_table();}   { FIXME: we've got to free the new allocated page_table entries }
	 unlock_inode(tmp_inode);
	 free_inode(tmp_inode);
	 result := -ENOMEM;
	 exit;
      end;
      len := tmp_file.op^.read(@tmp_file, buf, 4096);
      if (len < 0) then
      begin
         printk('sys_exec (%d): cannot read file %s (ret = %d)\n', [current^.pid, path, len]);
	 {unload_page_table();}   { FIXME: we've got to free the new allocated page_table entries }
	 unlock_inode(tmp_inode);
	 free_inode(tmp_inode);
	 result := len;
	 exit;
      end;
      new_page_table[i] := longint(buf) or USER_PAGE;
      current^.size     += 1;
   end;

   unlock_inode(tmp_inode);

   { We now need to allocate pages for the .bss section }

   {$IFDEF DEBUG_SYS_EXEC}
      printk('sys_exec (%d): allocating %d pages for the .bss section\n', [current^.pid, process_pages - pages_to_read]);
   {$ENDIF}
   for j := (pages_to_read + 1) to process_pages do
   begin
      {$IFDEF DEBUG_PAGES_LOADING}
         printk('sys_exec (%d): allocating page #%d for .bss (%h)\n', [current^.pid, j, $FFC00000 + j * 4096]);
      {$ENDIF}
      buf := get_free_page();
      if (buf = NIL) then
      begin
         printk('sys_exec (%d): not enough memory\n', [current^.pid]);
	 {unload_page_table();}   { FIXME: we've got to free the new allocated page_table }
	 free_inode(tmp_inode);
	 result := -ENOMEM;
	 exit;
      end;
      new_page_table[j] := longint(buf) or USER_PAGE;
      current^.size     += 1;
      memset(buf, 0, 4096);   { FIXME: Should we let this here ??? }
   end;

   { Free all we don't need }
   free_inode(tmp_inode);




{--------------------------------------------------------------------------------------------}




   {* Going to read arguments from the calling process and
    * put them in the new process data space *}

   argc := count(argv);
   envc := count(envp);

   current^.brk := $FFC01000 + process_mem;
   stack_addr   := $FFC01000;   { Initial stack address }
   tmp_stack    := pointer((new_page_table[0] and $FFFFF000) + 4096);

   i := longint(tmp_stack) - longint(copy_strings(tmp_stack, envp, envc, new_page_table));
   stack_addr -= i;
   tmp_stack  -= i;
   i := longint(tmp_stack) - longint(copy_strings(tmp_stack, argv, argc, new_page_table));
   stack_addr -= i;

   { Now, we check if some file descriptors have got the close_on_exec flag set }
   if (current^.close_on_exec <> 0) then
   begin
      {$IFDEF DEBUG_SYS_EXEC}
         printk('sys_exec (%d): we have to close some files (%h)\n', [current^.pid, current^.close_on_exec]);
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
	    printk('sys_exec (%d): calling sys_close(%d)\n', [current^.pid, tmp]);
         {$ENDIF}
         sys_close(tmp);
         {$IFDEF DEBUG_SYS_EXEC}
            printk('sys_exec (%d): tmp=%d %h\n', [current^.pid, tmp, i]);
	 {$ENDIF}
	 tmp := i;
      end;
   end;

   { FIXME: This is quite ugly but it works   :-) }
   i := current^.size;
   current^.size := old_size;
   unload_page_table(current);
   current^.size := i;

   { We have to update process descriptor. FIXME: update is not completly done }

   current^.ticks := 0;
   current^.errno := 0;
   current^.wait_queue := NIL;

   if (current^.mmap <> NIL) then
   begin
      first_req := current^.mmap;
      req       := first_req;
      repeat
         i += 1;
         tmp_req := req^.next;
         kfree_s(req, sizeof(mmap_req));
	 req := tmp_req;
      until (req = first_req);
   end;

   current^.mmap       := NIL;
   push_page(current^.page_table);
   current^.page_table := new_page_table;
   current^.cr3[1023]  := longint(new_page_table) or USER_PAGE;

   ret_adr := elf_header^.e_entry;

   asm
      mov   eax, cr3
      mov   cr3, eax   { Flush CPU TLB }

      mov   eax, ret_adr
      mov   [ebp + 44], eax   { Modify return address }

      mov   eax, stack_addr
      sub   eax, 4
      mov   ebx, argc
      mov   dword [eax], ebx       { argc -> OK }
      mov   dword [ebp + 56], eax  { Modify stack address }
   end;

   {$IFDEF DEBUG_ARGS}
      printk('sys_exec (%d): New process user stack dump :\n', [current^.pid]);
      i := longint(stack_addr - 4);
      stack_addr := $FFC01000 - 4;
      while (longint(stack_addr) >= i) do
      begin
         test := pointer(stack_addr^);
         printk('sys_exec (%d): %h -> %h (%h)\n', [current^.pid, stack_addr, pointer(stack_addr^), pointer(test^)]);
	 stack_addr -= 4;
      end;
   {$ENDIF}

   {$IFDEF DEBUG_SYS_EXEC}
      printk('sys_exec (%d): exiting  (entry point=%h, brk=%h)\n', [current^.pid, ret_adr, current^.brk]);
   {$ENDIF}

end;



{******************************************************************************
 * check_ELF_header
 *
 *****************************************************************************}
function check_ELF_header (elf_header : P_elf_header_t ; path : pchar ; inode : P_inode_t) : dword;
begin

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
	 free_inode(inode);
	 result := -ENOEXEC;
	 exit;
      end;

   if (elf_header^.e_entry < pointer($FFC01000)) then
       begin
          printk('sys_exec (%d): %s has an invalid entry point. (%h)\n', [current^.pid, path, elf_header^.e_entry]);
	  if ((longint(elf_header^.e_entry) and $08000000) = $08000000) then
	       printk('sys_exec (%d): it looks like a Linux binary file. Try to compile it for DelphineOS.\n', [current^.pid]);
	  push_page(elf_header);
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
 * get_arg_length
 *
 * Returns size in bytes of the argument pointed to by arg_ptr
 *
 * Used by copy_strings()
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

   result := count + 1;   { We add 1 because of the null terminating character }

end;



{******************************************************************************
 * copy_strings
 *
 * Returns the new value for stack_addr
 *****************************************************************************}
function copy_strings (stack_addr, args : pointer ; count : dword ; page_table : P_pte_t) : pointer;

var
   i, buf_len, arg_len : dword;
   physical_buf_addr   : pointer;
   virtual_buf_addr    : pointer;

begin

   {$IFDEF DEBUG_COPY_STRINGS}
      printk('copy_strings: stack_addr=%h, count=%d\n', [stack_addr, count]);
      printk('copy_strings: writing 0x00000000 at %h\n', [stack_addr - 4]);
   {$ENDIF}

   stack_addr -= 4;
   pointer(stack_addr^) := NIL;

   if (count = 0) then
   begin
      result := stack_addr;
      {$IFDEF DEBUG_COPY_STRINGS}
         printk('copy_strings: result=%h\n', [result]);
      {$ENDIF}
      exit;
   end;

   stack_addr -= count * 4;

   physical_buf_addr := get_free_page();
   if (physical_buf_addr = NIL) then
   begin
      printk('copy_strings: not enough memory\n', []);
      result := stack_addr;
      exit;
   end;
   buf_len := 4096;

   current^.size += 1;
   page_table[current^.size] := longint(physical_buf_addr) or USER_PAGE;
   current^.brk  := $FFC00000 + (current^.size + 1) * 4096;
   virtual_buf_addr := pointer(current^.brk - 4096);

   for i := 1 to count do
   begin
      arg_len := get_arg_length(pointer(args^));
      {$IFDEF DEBUG_COPY_STRINGS}
         {printk('%d: %s\n', [i, pointer(args^)]);}
      {$ENDIF}
      memcpy(pointer(args^), physical_buf_addr, arg_len);
      pointer(stack_addr^) := virtual_buf_addr;
      {$IFDEF DEBUG_COPY_STRINGS}
         printk('copy_strings: writing %h at %h\n', [virtual_buf_addr, stack_addr]);
      {$ENDIF}
      args += 4;
      stack_addr += 4;
      physical_buf_addr += arg_len;
      virtual_buf_addr += arg_len;
      buf_len  -= arg_len;
   end;

   result := stack_addr - count * 4;

   {$IFDEF DEBUG_COPY_STRINGS}
      printk('copy_strings: result=%h\n', [result]);
   {$ENDIF}

end;



begin
end.
