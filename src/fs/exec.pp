{******************************************************************************
 *  exec.pp
 *
 *  exec() system call implementation
 *
 *  Copyleft (C) 2002
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
{DEFINE SHOW_HEADER}
{DEFINE SHOW_PROGRAM_TABLE}


{* External procedure and functions *}
function  access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; external;
procedure farjump (tss : word ; ofs : pointer); external;
function  get_free_mem : dword; external;
function  get_pt_entry (addr : P_pte_t) : pointer; external;
procedure kfree_s (buf : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
function  MAP_NR (adr : pointer) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
function  namei (path : pointer) : P_inode_t; external;
procedure printk (format : string ; args : array of const); external;
procedure set_pt_entry (addr : P_pte_t ; val : dword); external;


{* External variables *}
var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   mem_map : P_page; external name 'U_MEM_MEM_MAP';


{* Exported variables *}


{* Procedures and functions only used in THIS file *}
function sys_exec (path : pointer ; arg : array of const) : dword; cdecl;



IMPLEMENTATION



{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * unload_page_table
 *
 *****************************************************************************}
procedure unload_page_table (pt : P_pte_t);

var
   i : dword;

begin

   i := 0;
   while (pt[i] <> 0) and (i <= 1023) do
   begin
      kfree_s(pointer(pt[i] and $FFFFF000), 4096);
      pt[i] := $0;
      i += 1;
   end;

end;



{******************************************************************************
 * sys_exec
 *
 * Input  : path is the file to execute and arg are the arguments which will
 *          be passed to the process.
 *
 * Output : -1 on error, never returns on success
 *
 * TODO: check alignment in ELF file
 *****************************************************************************}
function sys_exec (path : pointer ; arg : array of const) : dword; cdecl; [public, alias : 'SYS_EXEC'];

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
   ret_adr          : pointer;

   pages_to_read    : dword;
   new_page_table   : P_pte_t;


begin

   asm
      sti
   end;

   { For the moment, we don't care about arg }

   buf       := kmalloc(4096);
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
      printk('exec: no inode returned by namei()\n', []);
      kfree_s(buf, 4096);
      result := longint(tmp_inode);
      exit;
   end;

   {* Check if we can execute this file *}
   if not access_rights_ok(I_XO, tmp_inode) then
   begin
      printk('exec: permission denied\n', []);
      kfree_s(buf, 4096);
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
          printk('exec: cannot call read() for this file\n', []);
	  kfree_s(buf, 4096);
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
          printk('exec: cannot read %s (ret = %d)\n', [path, dest_ofs]);
	  kfree_s(buf, 4096);
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
      printk('Arch : %d (0: None  1: AT&T 32100  2: Sparc  3: 386  4: 68k  5: 88k  6: 860)\n', [elf_header^.e_machine]);
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
         printk('exec: %s has an invalid ELF header\n', [path]);
	 kfree_s(buf, 4096);
	 kfree_s(tmp_inode, sizeof(inode_t));
	 result := -1;
	 exit;
      end;


   { ELF header seems to be ok. Going to load program and launch it. }


   { First, we read the program header table }

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

   process_mem := longint(elf_header^.e_entry) and $FFF;
   len         := longint(elf_header^.e_entry) and $FFF;
   for i := 0 to (elf_header^.e_phnum - 1) do
       begin
          process_mem += phdr_table[i].p_memsz;
	  len         += phdr_table[i].p_filesz;
       end;

   pages_to_read := len div 4096;
   if (len mod 4096 <> 0) then
       pages_to_read += 1;

   process_pages := process_mem div 4096;
   if (process_mem mod 4096 <> 0) then
       process_pages += 1;

   if (process_pages > 1023) then
       begin
          printk('exec: %s cannot be load by DelphineOS (>4Mb)\n', [path]);
	  kfree_s(buf, 4096);
	  kfree_s(tmp_inode, sizeof(inode_t));
	  result := -1;
	  exit;
       end;

   {$IFDEF DEBUG}
      printk('exec: program needs %d bytes of memory (%d pages), %d pages_to_read\n', [process_mem, process_pages, pages_to_read]);
   {$ENDIF}

   new_page_table := kmalloc(4096);
   if (new_page_table = NIL) then
       begin
          printk('exec: not enough memory\n', []);
	  kfree_s(buf, 4096);
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
          buf := kmalloc(4096);
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
	         printk('exec: cannot read file %s\n', [path]);
		 unload_page_table(new_page_table);
		 kfree_s(tmp_inode, sizeof(inode_t));
		 result := -1;
		 exit;
	      end;
	  new_page_table[i] := longint(buf) or USER_PAGE;
       end;

   { We now need to allocate pages for the .bss section }

   {$IFDEF DEBUG}
      printk('exec: loading %d pages for .bss section\n', [process_pages - i + 1]);
   {$ENDIF}
   for j := i to process_pages do
       begin
          buf := kmalloc(4096);
	  if (buf = NIL) then
	      begin
	         printk('exec: not enough memory\n', []);
		 unload_page_table(new_page_table);
		 kfree_s(tmp_inode, sizeof(inode_t));
		 result := -1;
		 exit;
	      end;
	  new_page_table[j] := longint(buf) or USER_PAGE;
       end;

   { Free all we don't need }
   kfree_s(tmp_inode, sizeof(inode_t));

   { Freeing current page table entries but not the user mode stack entry }
   i := 1;
   while (current^.page_table[i] <> 0) and (i <= 1023) do
      begin
         kfree_s(pointer(longint(current^.page_table[i]) and $FFFFF000), 4096);
	 current^.page_table[i] := $0;
	 i += 1;
      end;
   kfree_s(current^.page_table, 4096);

   { We have to update process descriptor }

   asm
      cli   { Turn interruptions off }
   end;

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
      mov   eax, $FFC01000
      mov   [ebp + 56], eax   { Modify stack address }
   end;

end;



begin
end.
