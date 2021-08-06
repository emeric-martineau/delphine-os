{******************************************************************************
 *  mmap.pp
 *
 *  brk, mmap, munmap and mremap system calls management
 *
 *  FIXME: functions are not fully tested...
 *
 *  NOTE: For the moment, DelphineOS can't map files. This functions are just
 *        support for the dietlibc malloc(), ... functions.
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 02/04/2003 - GaLi - Initial version
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


unit delphine_mmap;


INTERFACE


{* Headers *}

{$I errno.inc}
{$I mm.inc}
{$I process.inc}

{* Local macros *}

{DEFINE DEBUG_GET_UNMAPPED_AREA}
{DEFINE DEBUG_FIND_PAGE_TABLE_OFS}
{DEFINE DEBUG_ADD_MMAP_REQ}
{DEFINE DEBUG_DEL_MMAP_REQ}
{DEFINE DEBUG_SYS_MUNMAP}
{DEFINE DEBUG_SYS_MREMAP}
{DEFINE DEBUG_SYS_MMAP}
{$DEFINE DEBUG_SYS_BRK}

{* External procedure and functions *}

function  get_free_page : pointer; external;
function  get_phys_addr (addr : pointer) : pointer; external;
function  get_pte (addr : dword) : P_pte_t; external;
procedure kfree_s (addr : pointer ; size : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
function  page_align (nb : longint) : dword; external;
procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_addr : pointer); external;
procedure set_pte (addr : dword ; pte : pte_t); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure add_mmap_req (p : P_task_struct ; addr : pointer ; size : dword ; flags, prot : byte ; count : word);
procedure del_mmap_req (req : P_mmap_req);
procedure do_munmap (req : P_mmap_req ; start_addr : pointer ; len : dword);
function  find_mmap_req (addr : pointer ; size : dword) : P_mmap_req;
function  find_page_table_ofs (nb, idx, from : dword) : longint;
function  sys_brk (brk : dword) : dword; cdecl;
function  sys_mmap (str : P_mmap_struct) : dword; cdecl;
function  sys_mremap (addr, old_len, new_len, flags, new_addr : dword) : dword; cdecl;
function  sys_munmap (start : pointer ; length : dword) : dword; cdecl;


IMPLEMENTATION


{$I inline.inc}


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{*******************************************************************************
 * get_unmapped_area
 *
 ******************************************************************************}
function get_unmapped_area (fichier : P_file_t ; len, vm_flags : dword) : dword;

var
	cr3_idx, pt_ofs	: dword;
	i, j					: dword;
	new_page 			: pointer;
	pt 					: P_pte_t;

begin

	result := -ENOMEM;

	cr3_idx := (current^.first_size div 1023) + 769;
	pt_ofs  := current^.first_size mod 1023;

	{$IFDEF DEBUG_GET_UNMAPPED_AREA}
		print_bochs('get_unmapped_area (%d): len=%d first_size=%d => cr3_idx=%d  pt_ofs=%d\n', [current^.pid, len, current^.first_size, cr3_idx, pt_ofs]);
	{$ENDIF}

	pt_ofs := find_page_table_ofs(len div 4096, cr3_idx, pt_ofs);

	while (pt_ofs = -1) do
	begin
		cr3_idx += 1;
		if (cr3_idx > 1023) then
		begin
			printk('get_unmapped_area (%d): cr3_idx > 1023\n', []);
			exit;
		end;
		if (current^.cr3[cr3_idx] = 0) then
		begin
			new_page := get_free_page();
			if (new_page = NIL) then
			begin
				printk('get_unmapped_area (%d): not enough memory to allocate a new page table\n', [current^.pid]);
				exit;
			end;
			memset(new_page, 0, 4096);
			current^.cr3[cr3_idx] := longint(new_page) or USER_PAGE;
			pt_ofs := 0;
			break;
		end;
		pt_ofs := find_page_table_ofs(len div 4096, cr3_idx, 0);
	end;

	{$IFDEF DEBUG_GET_UNMAPPED_AREA}
		print_bochs('get_unmapped_area (%d): find_page_table_ofs result : %d -> %d\n', [current^.pid, pt_ofs, (pt_ofs + (len div 4096) - 1)]);
	{$ENDIF}

	{* OK, now, we have some free pages.
	 *
	 * Here, cr3_idx (to know the page table) and pt_ofs (to know which entry
	 * within the page table) are initialized *}

{	if (fichier <> NIL) then
		 vm_flags := vm_flags or MAPPED_PAGE;}

	pt := pointer(current^.cr3[cr3_idx] and $FFFFF000);
	j  := pt_ofs + (len div 4096) - 1;

	for i := pt_ofs to j do
		 pt[i] := MAPPED_PAGE;

	{$IFDEF DEBUG_GET_UNMAPPED_AREA}
		print_bochs('get_unmapped_area (%d): new brk: %h  | brk: %h\n', [current^.pid, (BASE_ADDR + (pt_ofs + (len div 4096)) * 4096), current^.brk]);
	{$ENDIF}

	if (BASE_ADDR + (pt_ofs + (len div 4096)) * 4096) > current^.brk then   { FIXME: test this }
		 current^.brk := BASE_ADDR + (pt_ofs + (len div 4096)) * 4096;

	result := ((cr3_idx - 769) * $400000) + (pt_ofs * 4096) + BASE_ADDR;

   asm   { Don't know if we really need this }
      mov   eax, cr3
      mov   cr3, eax
   end;

end;



{*******************************************************************************
 * sys_mmap
 *
 * NOTE:  - MAP_FIXED is not supported (for the moment)
 *        - MAP_SHARED is not supported (for the moment)
 *
 * FIXME: - check if processes are not asking for too much memory
 *        - Store flags in mmap_req ???
 *
 * NOTE :  not fully tested.
 *
 * NOTE2: Code inspired from mm/mmap.c (Linux 2.4.25)
 ******************************************************************************}
function sys_mmap (str : P_mmap_struct) : dword; cdecl; [public, alias : 'SYS_MMAP'];

var
	addr, len, prot  : dword;
	flags, fd, pgoff : dword;

	fichier			  : P_file_t;
   vm_flags	   	  : dword;

begin

	addr  := str^.addr;
	len   := str^.len;
	prot  := str^.prot;
	flags := str^.flags;
	fd    := str^.fd;
	pgoff := str^.pgoff;

	fichier := NIL;

   {$IFDEF DEBUG_SYS_MMAP}
      print_bochs('sys_mmap (%d): start: %h  length: %d  prot: %d\n', [current^.pid, addr, len, prot]);
      print_bochs('sys_mmap: flags: %h  fd: %d  offset: %d\n', [flags, fd, pgoff]);
      print_bochs('sys_mmap: current brk=%h\n', [current^.brk]);
   {$ENDIF}

	sti();

   { Check flags value }

	flags := flags and (not (MAP_EXECUTABLE or MAP_DENYWRITE));

   if ((flags and (MAP_PRIVATE or MAP_SHARED)) = (MAP_PRIVATE or MAP_SHARED)) then
   begin
      printk('sys_mmap (%d): Flags have a bad value (%h)\n', [current^.pid, flags]);
		result := -EINVAL;
      exit;
   end;

   if ((flags and MAP_SHARED) = MAP_SHARED) then
   begin
      printk('sys_mmap (%d): MAP_SHARED not supported (for the moment)\n', [current^.pid]);
      result := -ENOSYS;
      exit;
   end;

   if ((flags and MAP_FIXED) = MAP_FIXED) then
   begin
      printk('sys_mmap (%d): trying to telling me what I have to do... (MAP_FIXED)\n', [current^.pid]);
      result := -ENOSYS;
      exit;
   end;

	if ((flags and MAP_ANONYMOUS) <> MAP_ANONYMOUS) then
	{ We have to map a file }
	begin
		fichier := current^.file_desc[fd];
		if (fichier = NIL) then
		begin
			printk('sys_mmap (%d): fd %d is not opened\n', [current^.pid, fd]);
			result := -EBADF;
			exit;
		end;
	end;

	if (fichier <> NIL) then
	begin
		if ((fichier^.op = NIL) or (fichier^.op^.mmap = NIL)) then
		begin
			printk('sys_mmap (%d): mmap() not defined for fd %d\n', [current^.pid, fd]);
			result := -ENODEV;
			exit;
		end;
	end;

	if (len = 0) then
	begin
		result := addr;
		exit;
	end;

	len := (len + 4096 - 1) and $FFFFF000;   { Page-align len }
	if ((len = 0) or (len > TASK_SIZE)) then
	begin
		printk('sys_mmap (%d): len has a bad value (%d)\n', [current^.pid, len]);
		result := -EINVAL;
		exit;
	end;

	{ Offset overflow ? }
	if ((pgoff + (len shr 12)) < pgoff) then
	begin
		printk('sys_mmap (%d): OVERFLOW (pgoff=%d, len=%d)\n', [current^.pid, pgoff, len]);
		result := -EINVAL;
		exit;
	end;

	{* Set vm_flags (which will be used by get_unmapped_area()
	 *
	 * FIXME: do this better ??? *}
{	vm_flags := PRESENT_PAGE;
	if ((prot and PROT_READ) = PROT_READ) then
		  vm_flags := vm_flags or USER_MODE;
	if ((prot and PROT_WRITE) = PROT_WRITE) then
		  vm_flags := vm_flags or WRITE_PAGE;}
vm_flags := 0;
	addr := get_unmapped_area(fichier, len, vm_flags);
	if ((addr and $fff) > 0) then
	begin
		result := addr and $fff;
		exit;
	end;

	add_mmap_req(current, pointer(addr), len, 0, 0, 1);


{------------------------------------------------------------------------------}


	result := addr;


   {$IFDEF DEBUG_SYS_MMAP}
      print_bochs('sys_mmap (%d): EXITING (result=%h) new brk=%h len=%d\n',
						[current^.pid, result, current^.brk, len]);
   {$ENDIF}

end;



{*****************************************************************************
 * sys_munmap
 *
 *****************************************************************************}
function sys_munmap (start : pointer ; length : dword) : dword; cdecl; [public, alias : 'SYS_MUNMAP'];

var
   i   : dword;
   req : P_mmap_req;

begin

   {$IFDEF DEBUG_SYS_MUNMAP}
      print_bochs('sys_munmap (%d): %h %d\n', [current^.pid, start, length]);
   {$ENDIF}

	sti();

   result := -EINVAL;

   { Check if 'start' and 'length' are page-aligned }
   if (longint(start) mod 4096 <> 0) or ((length mod 4096) <> 0) then exit;

   req := find_mmap_req(start, length);
   if (req = NIL) then
   begin
      printk('BUG -> sys_munmap (%d): couldn''t find request\n', [current^.pid]);
      result := -ENOSYS;
      exit;
   end;

   do_munmap(req, req^.addr, req^.size);

   { Remove the request from the list }
   del_mmap_req(req);

   result := 0;

   {$IFDEF DEBUG_SYS_MUNMAP}
      print_bochs('sys_munmap (%d): EXITING new brk=%h\n', [current^.pid, current^.brk]);
   {$ENDIF}

   asm   { NOTE: Don't know if we really need this }
      mov   eax, cr3
      mov   cr3, eax
   end;

end;



{*****************************************************************************
 * do_munmap
 *
 * NOTE: 'start_addr' and 'len' have to be page-aligned
 *****************************************************************************}
procedure do_munmap (req : P_mmap_req ; start_addr : pointer ; len : dword);

var
   i, nb, a : dword;
   nb_pages : dword;
   addr		: pointer;

begin

   a := longint(start_addr);

   nb_pages := (longint(start_addr) - BASE_ADDR) div 4096;
   if (longint(start_addr) - BASE_ADDR) mod 4096 <> 0 then
       nb_pages += 1;

   {$IFDEF DEBUG_SYS_MUNMAP}
      print_bochs('do_munmap: start_addr=%h\n', [get_pte(longint(start_addr))]);
   {$ENDIF}

   nb := len div 4096;

   for i := 1 to nb do
   begin
      addr := get_phys_addr(start_addr);
      if (addr <> NIL) and (longint(addr) <> MAPPED_PAGE) then
      begin
			{$IFDEF DEBUG_SYS_MUNMAP}
				print_bochs('do_munmap: freeing page %h\n', [addr]);
	 		{$ENDIF}
			push_page(addr);
	 		set_pte(longint(start_addr), 0);
	 		current^.real_size -= 1;
      end;
      start_addr += 4096;
   end;

   req^.size -= len;

   if (current^.brk = a + len) then
       current^.brk -= len;

end;



{*****************************************************************************
 * sys_mremap
 *
 * Expand (or shrink) an existing mapping, potentially moving it at the
 * same time (controlled by the MREMAP_MAYMOVE flag and available VM space)
 *
 *****************************************************************************}
function sys_mremap (addr, old_len, new_len, flags, new_addr : dword) : dword; cdecl; [public, alias : 'SYS_MREMAP'];

var
   ret, ofs, i : dword;
   nb_pages    : dword;
   new_page    : pointer;
   req         : P_mmap_req;
   pt 	      : P_pte_t;

label out;

begin

   {$IFDEF DEBUG_SYS_MREMAP}
      print_bochs('sys_mremap (%d): IN %h  %d -> %d  %h  %h\n', [current^.pid, addr, old_len, new_len, flags,
      	             	      	             	      	    new_addr]);
   {$ENDIF}

	sti();

   ret := -EINVAL;

   if (flags and (not (MREMAP_MAYMOVE or MREMAP_FIXED))) <> 0 then goto out;

   { Check if addr is page-aligned }
   if (addr and $FFF) <> 0 then goto out;

   old_len := page_align(old_len);
   new_len := page_align(new_len);

   { new_addr is only valid if MREMAP_FIXED is specified }
   if (flags and MREMAP_FIXED) = MREMAP_FIXED then
       printk('sys_mremap (%d): MREMAP_FIXED\n', [current^.pid]);

   ret := addr;

   req := find_mmap_req(pointer(addr), old_len);
   if (req = NIL) then
   begin
      printk('sys_mremap (%d): old request not found\n', [current^.pid]);
      ret := -ENOSYS;   { FIXME: another erro code ??? }
      goto out;
   end;

   { Do we have to shrink the old request ??? }
   if (old_len >= new_len) then
   begin
      if (old_len > new_len) then
      	 do_munmap(req, pointer(addr + new_len), old_len - new_len);
      if (new_addr = addr) or ((flags and MREMAP_FIXED) <> MREMAP_FIXED) then
          goto out;
   end;

   { Ok, we need to grow..  or relocate. }

   { Trying to just expand the area }

   { It sometimes happens. Dietlibc bug ??? }
   if (new_len = old_len) then goto out;

   ret := -ENOMEM;

   nb_pages := (new_len - old_len) div 4096;
   ofs := find_page_table_ofs(nb_pages, 769, 0);
   if (ofs = 0) then goto out;

   pt := pointer(current^.cr3[769] and $FFFFF000);

   if (((addr - BASE_ADDR) div 4096) + 1 = ofs) then
   begin
      { We just have to add 'nb_pages' pages }
      {$IFDEF DEBUG_SYS_MREMAP}
         print_bochs('sys_mremap (%d): just adding %d pages\n', [current^.pid, nb_pages]);
      {$ENDIF}
      for i := ofs to (ofs + nb_pages - 1) do
      begin
         new_page := get_free_page();
	 		if (new_page = NIL) then
	 		begin
	    		printk('sys_mremap (%d): no enough memory to add %d pages\n', [current^.pid, (new_len - old_len) div 4096]);
	    		goto out;
	 		end;
	 		pt[i] := longint(new_page) or USER_PAGE;
	 		{$IFDEF DEBUG_SYS_MREMAP}
	    		print_bochs('sys_mremap (%d): i=%d page=%h\n', [current^.pid, i, new_page]);
	 		{$ENDIF}
      end;

      req^.size := new_len;

      if (addr + new_len) > current^.brk then   { FIXME: test this }
          current^.brk := addr + new_len;

      current^.real_size += nb_pages;
      ret := addr;

      {$IFDEF DEBUG_SYS_MREMAP}
         print_bochs('sys_mremap (%d): %h -> %h\n', [current^.pid, addr, addr + new_len]);
      {$ENDIF}

      goto out;
   end
   else
   begin
      {$IFDEF DEBUG_SYS_MREMAP}
      	 print_bochs('sys_mremap (%d): need to realloc\n', [current^.pid]);
      {$ENDIF}
      for i := ofs to (ofs + (new_len div 4096) - 1) do
      begin
			new_page := get_free_page();
	 		if (new_page = NIL) then
	 		begin
	    		printk('sys_mremap (%d): not enoug memoty to reallocate\n', [current^.pid]);
	    		goto out;
	 		end;
	 		pt[i] := longint(new_page) or USER_PAGE;
      end;
      memcpy(req^.addr, pointer((ofs * 4096) + BASE_ADDR), req^.size);
      do_munmap(req, req^.addr, req^.size);
      current^.real_size += new_len div 4096;
      req^.addr := pointer((ofs * 4096) + BASE_ADDR);
      req^.size := new_len;
      ret := (ofs * 4096) + BASE_ADDR;
   end;

{   printk('sys_mremap: adding %d bytes. old_ofs=%d ofs=%d\n', [(new_len - old_len), (addr - BASE_ADDR) div 4096, ofs]);}

out:

   asm   { Don't know if we really need this }
      mov   eax, cr3
      mov   cr3, eax
   end;

   result := ret;

   {$IFDEF DEBUG_SYS_MREMAP}
      print_bochs('sys_mremap (%d): END result=%h\n', [current^.pid, result]);
   {$ENDIF}

end;



{*****************************************************************************
 * sys_brk
 *
 * FIXME: not fully tested
 *****************************************************************************}
function sys_brk (brk : dword) : dword; cdecl; [public, alias : 'SYS_BRK'];

var
   newbrk, oldbrk, i : dword;
   new_page          : pointer;
   pt                : P_pte_t;

begin

	sti();

   pt := pointer(current^.cr3[769] and $FFFFF000);

   if (brk < current^.brk) then result := current^.brk
   else
   begin
      printk('WARNING: sys_brk: function not tested\n', []);
      {$IFDEF DEBUG_SYS_BRK}
      	 print_bochs('sys_brk (%d): brk=%h  current^.brk=%h size=%d\n', [current^.pid, brk, current^.brk, current^.real_size]);
      {$ENDIF}
      newbrk := (brk + $FFF) and $FFFFF000;
      oldbrk := (current^.brk + $FFF) and $FFFFF000;
      {$IFDEF DEBUG_SYS_BRK}
         print_bochs('sys_brk: newbrk=%h  oldbrk=%h\n', [newbrk, oldbrk]);
      {$ENDIF}
      if (oldbrk = newbrk) then
      begin
         current^.brk := newbrk;
	 		result := 0;
      end
      else
      begin
         for i := (current^.real_size + 1) to (current^.real_size + (newbrk - oldbrk) div 4096) do
	 		begin
	    		new_page := get_free_page();
	    		if (new_page = NIL) then
	    		begin
	       		printk('sys_brk: no enough memory\n', []);
	       		result := -ENOMEM;
	       		exit;
	    		end;
	    		pt[i] := longint(new_page) or USER_PAGE;
	 		end;
	 		current^.brk  := BASE_ADDR + i * 4096;
	 		current^.real_size := i;
	 		result := 0;
	 		{$IFDEF DEBUG_SYS_BRK}
	    		print_bochs('sys_brk: after allocation, brk=%h, size=%d\n', [current^.brk, current^.real_size]);
	 		{$ENDIF}
      end;
   end;
end;



{*****************************************************************************
 * add_mmap_req
 *
 * This function is used by mmap() and copy_mm() (src/kernel/fork.pp) to add a
 * request so that we know all the requests the process have made.
 *****************************************************************************}
procedure add_mmap_req (p : P_task_struct ; addr : pointer ; size : dword ; flags, prot : byte ; count : word); [public, alias : 'ADD_MMAP_REQ'];

var
   req : P_mmap_req;

begin

   req := kmalloc(sizeof(mmap_req));
   if (req = NIL) then
   begin
      printk('add_mmap_req (%d): not enough memory to add request\n', [current^.pid]);
      exit;
   end;

   if (p^.mmap = NIL) then
   begin
      p^.mmap        := req;
      p^.mmap^.addr  := addr;
      p^.mmap^.size  := size;
		p^.mmap^.count := count;
      p^.mmap^.next  := p^.mmap;
      p^.mmap^.prev  := p^.mmap;
   end
   else
   begin
      req^.addr  := addr;
      req^.size  := size;
		req^.count := count;
      req^.prev  := p^.mmap^.prev;
      req^.next  := p^.mmap;
      p^.mmap^.prev^.next := req;
      p^.mmap^.prev := req;
   end;

   {$IFDEF DEBUG_ADD_MMAP_REQ}
      print_bochs('add_mmap_req (%d):current^.mmap=%h req=%h(%h,%h)\n', [p^.pid, p^.mmap, req, req^.next, req^.prev]);
   {$ENDIF}

end;




{*****************************************************************************
 * del_mmap_req
 *
 *****************************************************************************}
procedure del_mmap_req (req : P_mmap_req); [public, alias : 'DEL_MMAP_REQ'];
begin

   {$IFDEF DEBUG_DEL_MMAP_REQ}
      print_bochs('del_mmap_req (%d): req=%h (%h, %h)\n', [current^.pid, req, req^.next, req^.prev]);
   {$ENDIF}

	req^.count -= 1;
	if (req^.count = 0) then
	begin
   	req^.prev^.next := req^.next;
   	req^.next^.prev := req^.prev;
   	kfree_s(req, sizeof(mmap_req));
	end;

end;



{*****************************************************************************
 * find_mmap_req
 *
 * This function looks for a request in current^.mmap list
 *****************************************************************************}
function find_mmap_req (addr : pointer ; size : dword) : P_mmap_req;

var
   res, tmp : P_mmap_req;

begin

   res := NIL;
   tmp := current^.mmap;

   repeat
{      printk('find_mmap_req: %h %d\n', [tmp^.addr, tmp^.size]);}
      if (tmp^.addr = addr) and (tmp^.size = size) then
      begin
         res := tmp;
	 		break;
      end;
      tmp := tmp^.next;
   until (tmp = current^.mmap);

   result := res;

end;



{*****************************************************************************
 * find_page_table_ofs
 *
 * INPUT : nb   -> nb of adjacent entries we want.
 *         idx  -> index used to know which page table to use.
 *    	  from -> don't look at the first 'from' entries.
 *
 * OUPUT : first entry number or -1.
 *
 * Look for 'nb' free adjacent entries in the page table indexed by 'i'.
 *
 * FIXME: may be more tests
 *****************************************************************************}
function find_page_table_ofs (nb, idx, from : dword) : longint;

var
   i, ofs : dword;
   ok     : boolean;
   pt     : P_pte_t;

label restart;

begin

   if (nb = 0) or (nb > 1024) or (idx > 1023) or (from > 1023) then
   begin
		print_bochs('find_page_table_ofs: bad parameter (%d %d %d)\n',
						[nb, idx, from]);
      result := -1;
      exit;
   end;

   {$IFDEF DEBUG_FIND_PAGE_TABLE_OFS}
      print_bochs('find_page_table_ofs (%d): nb=%d  idx=%d  from=%d\n', [current^.pid, nb, idx, from]);
   {$ENDIF}

   ofs := from;

restart:

   ok  := TRUE;
   pt  := pointer(current^.cr3[idx] and $FFFFF000);

   while (pt[ofs] <> 0) and (ofs < 1024) do ofs += 1;

   {$IFDEF DEBUG_FIND_PAGE_TABLE_OFS}
      print_bochs('find_page_table_ofs (%d): first free entry, ofs=%d (%h)\n', [current^.pid, ofs, pt[ofs]]);
   {$ENDIF}

   {* ofs is a free entry in current^.page_table. We now have to check if we
    * have nb free entries starting from ofs *}

   {$IFDEF DEBUG_FIND_PAGE_TABLE_OFS}
      printk('find_page_table_ofs (%d): looking for %d free entries from ofs=%d\n', [current^.pid, nb, ofs]);
   {$ENDIF}

   result := ofs;

   for i := 1 to (nb - 1) do
   begin
      {$IFDEF DEBUG_FIND_PAGE_TABLE_OFS}
         print_bochs('find_page_table_ofs (%d): ofs=%d (%h)\n', [current^.pid, ofs + i, pt[ofs + i]]);
      {$ENDIF}
      if (pt[ofs + i] <> 0) then
      begin
         ok := FALSE;
	 		result := 0;
	 		break;
      end;
   end;

   ofs += i;

   if (ok = FALSE) and (ofs < 1024) then goto restart;

   {$IFDEF DEBUG_FIND_PAGE_TABLE_OFS}
      print_bochs('find_page_table_ofs (%d): result=%d\n', [current^.pid, result]);
   {$ENDIF}

end;



begin
end.
