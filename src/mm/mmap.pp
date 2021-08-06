{******************************************************************************
 *  mmap.pp
 *
 *  mmap, munmap and mremap system calls management
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
procedure kfree_s (addr : pointer ; size : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
function  page_align (nb : longint) : dword; external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_addr : pointer); external;

{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure add_mmap_req (p : P_task_struct ; addr : pointer ; size : dword);
procedure del_mmap_req (req : P_mmap_req);
function  find_mmap_req (addr : pointer ; size : dword) : P_mmap_req;
function  find_page_table_ofs (nb : dword) : dword;
function  sys_brk (brk : dword) : dword; cdecl;
function  sys_mmap (str : P_mmap_struct) : dword; cdecl;
function  sys_mremap (addr, old_len, new_len, flags, new_addr : dword) : dword; cdecl;
function  sys_munmap (start : pointer ; length : dword) : dword; cdecl;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{*****************************************************************************
 * sys_mmap
 *
 * NOTE:  - MAP_FIXED is not supported (for the moment)
 *        - MAP_SHARED is not supported (for the moment)
 *
 * FIXME: - check if processes are not asking for too much memory
 *        - Store flags in mmap_req ???
 *
 * NOTE:  not fully tested
 *****************************************************************************}
function sys_mmap (str : P_mmap_struct) : dword; cdecl; [public, alias : 'SYS_MMAP'];

var
   i, tmp, f : dword;
   new_page  : pointer;

begin

   {$IFDEF DEBUG_SYS_MMAP}
      printk('sys_mmap (%d): start: %h  length: %d  prot: %d\n', [current^.pid, str^.start, str^.length, str^.prot]);
{      printk('sys_mmap: flags: %h  fd: %d  offset: %d\n', [str^.flags, str^.fd, str^.offset]);}
{      printk('sys_mmap: current brk=%h\n', [current^.brk]);}
   {$ENDIF}

   asm
      sti
   end;

   { Check flags value }

   if ((str^.length mod 4096) <> 0) then
   begin
      printk('sys_mmap (%d): length has a bad value (%d)\n', [current^.pid, str^.length]);
      {printk('sys_mmap: start: %h  length: %d  prot: %d\n', [str^.start, str^.length, str^.prot]);
      printk('sys_mmap: flags: %h  fd: %d  offset: %d\n', [str^.flags, str^.fd, str^.offset]);}
      result := -EINVAL;
      exit;
   end;

   if ((str^.flags and MAP_FIXED) = MAP_FIXED) then
   begin
      printk('sys_mmap (%d): trying to telling me what I have to do... (MAP_FIXED)\n', [current^.pid]);
      result := -ENOTSUP;
      exit;
   end;

   if ((str^.flags and (MAP_PRIVATE or MAP_SHARED)) = (MAP_PRIVATE or MAP_SHARED)) then
   begin
      printk('sys_mmap (%d): Flags have a bad value (%h)\n', [current^.pid, str^.flags]);
      result := -EINVAL;
      exit;
   end;

   if ((str^.flags and MAP_SHARED) = MAP_SHARED) then
   begin
      printk('sys_mmap (%d): MAP_SHARED not supported (for the moment)\n', [current^.pid]);
      result := -ENOTSUP;
      exit;
   end;

   if (str^.flags = MAP_ANONYMOUS or MAP_PRIVATE) then   { DelphineOS only supports this flags }
   begin
      if (str^.fd <> -1) then
      begin
         printk('sys_mmap (%d): fd in not -1 (%d). This is not supported (for the moment)\n', [current^.pid, str^.fd]);
	 result := -EINVAL;
	 exit;
      end;

      if (str^.offset <> 0) then
      begin
         printk('sys_mmap (%d): offset is not 0 (%d). This is not supported (for the moment)\n', [current^.pid, str^.offset]);
	 result := -EINVAL;
	 exit;
      end;

      f := PRESENT_PAGE;   { Flags which will be used for "new_page" }

      if ((str^.prot and PROT_READ) = PROT_READ) then
	 f := f or USER_MODE;

      if ((str^.prot and PROT_WRITE) = PROT_WRITE) then
	 f := f or WRITE_PAGE;

      if ((str^.prot and PROT_EXEC) = PROT_EXEC) then
	 f := f or USER_MODE;

      if (str^.prot = PROT_NONE) then
	 f := PRESENT_PAGE;

      tmp := find_page_table_ofs(str^.length div 4096);

{printk('sys_mmap: find_page_table_ofs result : %d -> %d\n', [tmp, (tmp + (str^.length div 4096) - 1)]);}

      if (tmp = 0) then
      begin
         result := -ENOMEM;
	 exit;
      end
      else
      begin
         for i := tmp to (tmp + (str^.length div 4096) - 1) do
	 begin

	    new_page := get_free_page();

	    if (new_page = NIL) then
	    begin
	       printk('sys_mmap (%d): not enough memory\n', [current^.pid]);
	       result := -ENOMEM;
	       exit;
	    end;

	    current^.page_table[i] := longint(new_page) or f;
	    {memset(new_page, 0, 4096);} { FIXME: don't know if we need this }

	 end;
      end;

      {$IFDEF DEBUG_SYS_MMAP}
         printk('sys_mmap (%d): new brk: %h  | brk: %h\n', [current^.pid, ($FFC00000 + (i + 1) * 4096), current^.brk]);
      {$ENDIF}

      if ($FFC00000 + (i + 1) * 4096) > current^.brk then   { FIXME: test this }
          current^.brk := $FFC00000 + (i + 1) * 4096;

      current^.size += str^.length div 4096;
      result := (tmp * 4096) + $FFC00000;

      add_mmap_req(current, pointer(result), str^.length);

   end
   else
   begin
      printk('sys_mmap (%d): flags=%h (not supported)\n', [current^.pid, str^.flags]);
      result := -ENOTSUP;
      exit;
   end;

   {$IFDEF DEBUG_SYS_MMAP}
      printk('sys_mmap (%d): EXITING (result=%h) new brk=%h\n', [current^.pid, result, current^.brk]);
   {$ENDIF}

   asm   { Don't know if we really need this }
      mov   eax, cr3
      mov   cr3, eax
   end;

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
      printk('sys_munmap (%d): %h %d\n', [current^.pid, start, length]);
   {$ENDIF}

   result := -EINVAL;

   if (longint(start) mod 4096 <> 0) or ((length mod 4096) <> 0) then exit;

   req := find_mmap_req(start, length);
   if (req = NIL) then
   begin
      printk('sys_munmap (%d): couldn''t find request\n', [current^.pid]);
      exit;
   end;

   if (longint(req^.addr) + req^.size) = current^.brk then
       current^.brk -= req^.size;

   for i := 1 to (req^.size div 4096) do
   begin
      {$IFDEF DEBUG_SYS_MUNMAP}
         printk('sys_munmap (%d): freeing page %h -> %h entry #%d\n', [current^.pid, req^.addr, get_phys_addr(req^.addr), (longint(req^.addr) - $FFC00000) div 4096]);
      {$ENDIF}
      push_page(get_phys_addr(req^.addr));
      current^.page_table[(longint(req^.addr) - $FFC00000) div 4096] := 0;
      req^.addr += 4096;
   end;

   current^.size -= length div 4096;
   if (current^.brk = longint(start) + length) then
       current^.brk -= length;

   { Remove the request from the list }
   del_mmap_req(req);

   result := 0;

   {$IFDEF DEBUG_SYS_MUNMAP}
      printk('sys_munmap (%d): EXITING new brk=%h\n', [current^.pid, current^.brk]);
   {$ENDIF}

   asm   { NOTE: Don't know if we really need this }
      mov   eax, cr3
      mov   cr3, eax
   end;

end;



{*****************************************************************************
 * sys_mremap
 *
 * Expand (or shrink) an existing mapping, potentially moving it at the
 * same time (controlled by the MREMAP_MAYMOVE flag and available VM space)
 *
 * FIXME:  - we have to carry about the flags
 *****************************************************************************}
function sys_mremap (addr, old_len, new_len, flags, new_addr : dword) : dword; cdecl; [public, alias : 'SYS_MREMAP'];

var
   ret, ofs, i : dword;
   nb_pages    : dword;
   new_page    : pointer;
   req         : P_mmap_req;

label out;

begin

   printk('sys_mremap (%d): %h\n', [current^.pid, addr]);

   asm
      sti
   end;

   ret := -EINVAL;

   if (flags and (not (MREMAP_MAYMOVE or MREMAP_FIXED))) <> 0 then goto out;

   { Check if addr is page-aligned }
   if (addr and $FFF) <> 0 then goto out;

   old_len := page_align(old_len);
   new_len := page_align(new_len);

   { new_addr is only valid if MREMAP_FIXED is specified }
   if (flags and MREMAP_FIXED) = MREMAP_FIXED then
   begin
      printk('sys_mremap (%d): MREMAP_FIXED\n', [current^.pid]);
   end;

   ret := addr;

   { Do we have to shrink the old request ??? }
   if (old_len >= new_len) then
   begin
      if (old_len > new_len) then
          printk('sys_mremap (%d): we REALLY have to munmap %h %d\n', [current^.pid, addr+new_len, old_len-new_len]);
      if (new_addr = addr) or ((flags and MREMAP_FIXED) <> MREMAP_FIXED) then
      begin
         printk('sys_mremap (%d): EXITING because old_len >= new_len', [current^.pid]);
         goto out;
      end;
   end;

   { Ok, we need to grow..  or relocate. }

   ret := -ENOMEM;

   req := find_mmap_req(pointer(addr), old_len);

   if (req = NIL) then
   begin
      printk('sys_mremap (%d): old request not found\n', [current^.pid]);
      goto out;
   end;

   { Trying to just expand the area }

   nb_pages := (new_len - old_len) div 4096;
   ofs := find_page_table_ofs(nb_pages);
   if (ofs = 0) then goto out;

   if (((addr - $FFC00000) div 4096) + 1 = ofs) then
   begin
      { We just have to add (new_len - old_len) div 4096 pages }
      {$IFDEF DEBUG_SYS_MREMAP}
         printk('sys_mremap (%d): just adding %d pages\n', [current^.pid, nb_pages]);
      {$ENDIF}
      for i := ofs to (ofs + nb_pages - 1) do
      begin
         new_page := get_free_page;
	 if (new_page = NIL) then
	 begin
	    printk('sys_mremap (%d): no enough memory to add %d pages\n', [current^.pid, (new_len - old_len) div 4096]);
	    goto out;
	 end;
	 current^.page_table[i] := longint(new_page) or USER_PAGE;
	 {$IFDEF DEBUG_SYS_MREMAP}
	    printk('sys_mremap (%d): i=%d page=%h\n', [current^.pid, i, new_page]);
	 {$ENDIF}
      end;

      req^.size := new_len;

      if (addr + new_len) > current^.brk then   { FIXME: test this }
          current^.brk := addr + new_len;

      current^.size += nb_pages;
      ret := addr;

      {$IFDEF DEBUG_SYS_MREMAP}
         printk('sys_mremap (%d): %h -> %h\n', [current^.pid, addr, addr + new_len]);
      {$ENDIF}

      goto out;
   end
   else
   begin
      printk('sys_mremap (%d): We need to realloc\n', [current^.pid]);
   end;

{   printk('sys_mremap: adding %d bytes. old_ofs=%d ofs=%d\n', [(new_len - old_len), (addr - $FFC00000) div 4096, ofs]);}

out:

   asm   { Don't know if we really need this }
      mov   eax, cr3
      mov   cr3, eax
   end;

   result := ret;

   {$IFDEF DEBUG_SYS_MREMAP}
      printk('sys_mremap (%d): result=%h (old:%h %d new:%h %d flags:%d)\n', [current^.pid, result, addr, old_len, new_addr, new_len, flags]);
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
   
   new_page : pointer;

begin

   asm
      sti
   end;

   {$IFDEF DEBUG_SYS_BRK}
      printk('Welcome in sys_brk (%h)  brk=%h  size=%d\n', [brk, current^.brk, current^.size]);
   {$ENDIF}

   if (brk < current^.brk) then result := current^.brk
   else
   begin
      newbrk := (brk + $FFF) and $FFFFF000;
      oldbrk := (current^.brk + $FFF) and $FFFFF000;
      {$IFDEF DEBUG_SYS_BRK}
         printk('sys_brk: newbrk=%h  oldbrk=%h\n', [newbrk, oldbrk]);
      {$ENDIF}
      if (oldbrk = newbrk) then
      begin
         current^.brk := newbrk;
	 result := newbrk;
      end
      else
      begin
         for i := (current^.size + 1) to (current^.size + (newbrk - oldbrk) div 4096) do
	 begin
	    new_page := get_free_page;
	    if (new_page = NIL) then
	    begin
	       printk('sys_brk: no enough memory\n', []);
	       result := -1;
	       exit;
	    end;
	    current^.page_table[i] := longint(new_page) or USER_PAGE;
	 end;
	 current^.brk  := $FFC00000 + i * 4096;
	 current^.size := i;
	 result := current^.brk;
	 {$IFDEF DEBUG_SYS_BRK}
	    printk('sys_brk: after allocation, brk=%h, size=%d\n', [current^.brk, current^.size]);
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
procedure add_mmap_req (p : P_task_struct ; addr : pointer ; size : dword); [public, alias : 'ADD_MMAP_REQ'];

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
      p^.mmap       := req;
      p^.mmap^.addr := addr;
      p^.mmap^.size := size;
      p^.mmap^.next := p^.mmap;
      p^.mmap^.prev := p^.mmap;
   end
   else
   begin
      req^.addr := addr;
      req^.size := size;

      req^.prev := p^.mmap^.prev;
      req^.next := p^.mmap;
      p^.mmap^.prev^.next := req;
      p^.mmap^.prev := req;
   end;

   {$IFDEF DEBUG_ADD_MMAP_REQ}
      printk('add_mmap_req (%d):current^.mmap=%h req=%h(%h,%h)\n', [p^.pid, p^.mmap, req, req^.next, req^.prev]);
   {$ENDIF}

end;




{*****************************************************************************
 * del_mmap_req
 *
 *****************************************************************************}
procedure del_mmap_req (req : P_mmap_req);
begin

   {$IFDEF DEBUG_ADD_MMAP_REQ}
      printk('del_mmap_req (%d): req=%h (%h, %h)\n', [current^.pid, req, req^.next, req^.prev]);
   {$ENDIF}

   req^.prev^.next := req^.next;
   req^.next^.prev := req^.prev;

   kfree_s(req, sizeof(mmap_req));

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
 * Recherche nb entrées adjacentes libres dans current^.page_table.
 *
 * OUPUT : first entry number
 *
 * FIXME: may be more tests
 *****************************************************************************}
function find_page_table_ofs (nb : dword) : dword;

var
   ofs, i : dword;
   ok     : boolean;

label restart;

begin

   ofs := 1;

   restart:

   ok := TRUE;

   while (current^.page_table[ofs] <> 0) and (ofs < 1024) do
   begin
      {$IFDEF DEBUG_FIND_PAGE_TABLE_OFS}
         printk('find_page_table_ofs (%d): ofs=%d -> %h\n', [current^.pid, ofs, current^.page_table[ofs]]);
      {$ENDIF}
      ofs += 1;
   end;

   result := ofs;

   {* ofs is a free entry in current^.page_table. We now have to check if we
    * have nb free entries strating from ofs *}

   {$IFDEF DEBUG_FIND_PAGE_TABLE_OFS}
      printk('find_page_table_ofs (%d): at restart, ofs=%d (%h)\n', [current^.pid, ofs, current^.page_table[ofs]]);
   {$ENDIF}

   for i := 1 to (nb - 1) do
   begin
      {$IFDEF DEBUG_FIND_PAGE_TABLE_OFS}
         printk('find_page_table_ofs (%d): ofs=%d (%h)\n', [current^.pid, ofs+i, current^.page_table[ofs+i]]);
      {$ENDIF}
      if (current^.page_table[ofs+i] <> 0) then
      begin
         ok := FALSE;
	 result := 0;
	 break;
      end;
   end;

   ofs += i;

   if (ok = FALSE) and (ofs < 1024) then goto restart;

   {$IFDEF DEBUG_FIND_PAGE_TABLE_OFS}
      printk('find_page_table_ofs (%d): result=%d\n', [current^.pid, result]);
   {$ENDIF}

end;



begin
end.
