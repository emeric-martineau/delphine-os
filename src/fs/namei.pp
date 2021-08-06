{******************************************************************************
 *  namei.pp
 *
 *  This file contains lookup(), namei() and dir_namei() and functions
 *  necessary to lookup() cache.
 *
 *  NOTE: Functions used to manage lookup_cache begin with 'lc_'
 *
 *  Copyleft (C) 2003
 *
 *  version 0.1 - 15/10/2003 - GaLi - lookup_cache management is nearly OK.
 *				      Just a few bugs left.
 *
 *  version 0.0 - 13/10/2003 - GaLi - Initial version
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


unit _namei;


INTERFACE


{* Headers *}

{$I errno.inc}
{$I fs.inc}
{$I process.inc}

{* Local macros *}

{DEFINE DEBUG_LC_ADD_ENTRY}
{DEFINE DEBUG_LC_FIND_ENTRY}
{DEFINE DEBUG_NAMEI}
{DEFINE NAMEI_WARNING}
{DEFINE DEBUG_DIR_NAMEI}
{DEFINE DIR_NAMEI_WARNING}
{DEFINE DEBUG_LOOKUP}


{* External procedure and functions *}

function  alloc_inode : P_inode_t; external;
procedure free_inode (inode : P_inode_t); external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
function  IS_DIR (inode : P_inode_t) : boolean; external;
procedure lock_inode (inode : P_inode_t); external;
function  memcmp (src, dest : pointer ; size : dword) : boolean; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure printk (format : string ; args : array of const); external;
procedure unlock_inode (inode : P_inode_t); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}
var
   lookup_cache : array[1..1024] of P_lookup_cache_entry;
   lookup_cache_entries : dword;


{* Procedures and functions defined in this file *}

function  dir_namei (path : pchar ; name : pointer) : P_inode_t;
procedure lc_add_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t);
function  lc_find_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : boolean;
function  lookup (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : boolean;
function  namei (path : pchar) : P_inode_t;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * lc_add_entry
 *
 * Add an entry in lookup_cache
 *****************************************************************************}
procedure lc_add_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t);

var
   new_ent : P_lookup_cache_entry;
   i       : dword;

begin

   if (lookup_cache_entries = 1024) then
   begin
      printk('lc_add_entry  (%d): lookup_cache is full\n', [current^.pid]);
      exit;
   end;

   new_ent := kmalloc(sizeof(lookup_cache_entry));
   if (new_ent = NIL) then
   begin
      printk('lc_add_entry  (%d): WARNING -> not enough memory (1)\n', [current^.pid]);
      exit;
   end;

   new_ent^.name := kmalloc(len);
   if (new_ent^.name = NIL) then
   begin
      printk('lc_add_entry  (%d): WARNING -> not enough memory (2)\n', [current^.pid]);
      kfree_s(new_ent, sizeof(lookup_cache_entry));
      exit;
   end;

   dir^.count += 1;
   res_inode^^.count += 1;

   new_ent^.dir := dir;
   memcpy(name, new_ent^.name, len);
   new_ent^.len := len;
   new_ent^.res_inode := res_inode^;

   i := 1;
   while (lookup_cache[i] <> NIL) and (i <= 1024) do i += 1;

   lookup_cache[i] := new_ent;
   lookup_cache_entries += 1;

   {$IFDEF DEBUG_LC_ADD_ENTRY}
      printk('lc_add_entry  (%d): %d %s %d %d (i=%d)\n', [current^.pid, dir^.ino, name, len, res_inode^^.ino, i]);
   {$ENDIF}

end;



{******************************************************************************
 * lc_find_entry
 *
 * Find an entry in lookup_cache
 *****************************************************************************}
function lc_find_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : boolean;

var
   i, i_max : dword;

begin

   {$IFDEF DEBUG_LC_FIND_ENTRY}
{      printk('lc_find_entry (%d): %d %s %d\n', [current^.pid, dir^.ino, name, len]);}
   {$ENDIF}

   result := FALSE;
   i_max  := lookup_cache_entries;

   for i := 1 to 1024 do
   begin
      if (lookup_cache[i] <> NIL) then
      begin
	 if  (dir^.ino = lookup_cache[i]^.dir^.ino)
	 and (dir^.dev_maj = lookup_cache[i]^.dir^.dev_maj)
	 and (dir^.dev_min = lookup_cache[i]^.dir^.dev_min)
	 and (len = lookup_cache[i]^.len)
	 and (memcmp(name, lookup_cache[i]^.name, len) = TRUE) then
	 begin
	    {$IFDEF DEBUG_LC_FIND_ENTRY}
	       printk('lc_find_entry (%d): entry found for %s i=%d, ino=%d (%h)\n', [current^.pid, name, i,
	       									     lookup_cache[i]^.res_inode^.ino,
										     lookup_cache[i]^.res_inode]);
	    {$ENDIF}
	    lookup_cache[i]^.res_inode^.count += 1;
	    free_inode(res_inode^);
	    res_inode^ := lookup_cache[i]^.res_inode;
	    result := TRUE;
	    exit;
	 end
	 else
	 begin
	    i_max -= 1;
	    {$IFDEF DEBUG_LC_FIND_ENTRY}
	    {printk('lc_find_entry (%d): i=%d  %d/%d, %d/%d, %d/%d, %s/%s %d/%d\n',
	    								[current^.pid, i, dir^.ino, lookup_cache[i]^.dir^.ino,
	    								 dir^.dev_maj, lookup_cache[i]^.dir^.dev_maj,
									 dir^.dev_min, lookup_cache[i]^.dir^.dev_min,
									 name, lookup_cache[i]^.name,
									 len, lookup_cache[i]^.len]);}
	    {$ENDIF}
	    if (longint(i_max) <= 0) then
	    begin
	       {$IFDEF DEBUG_LC_FIND_ENTRY}
	          printk('lc_find_entry (%d): entry NOT found for %s\n', [current^.pid, name]);
	       {$ENDIF}
	       exit;
	    end;
	 end;
      end;
   end;
end;



{******************************************************************************
 * lookup
 *
 * Input  : directory inode, file/directory we look for, size of 'name', inode
 *	    to fill
 *
 * Output : TRUE or FALSE
 *
 * If everything is ok, 'res_inode' is fill with 'name' inode info
 *
 * FIXME: use a cache to speed up this function.
 *****************************************************************************}
function lookup (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : boolean; [public, alias : 'LOOKUP'];
begin

   {$IFDEF DEBUG_LOOKUP}
      printk('lookup (%d): looking for %s in inode directory %d\n', [current^.pid, name, dir^.ino]);
   {$ENDIF}

   if not IS_DIR(dir) then
   begin
      printk('lookup (%d): inode %h is not a directory\n', [current^.pid]);
      result := FALSE;
      exit;
   end;

   if (lc_find_entry(dir, name, len, res_inode) = TRUE) then
       result := TRUE
   else
   begin
       if (dir^.op <> NIL) and (dir^.op^.lookup <> NIL) then
       begin
         lock_inode(dir);
         result := dir^.op^.lookup(dir, name, len, res_inode);
	 if (result = TRUE) then lc_add_entry(dir, name, len, res_inode);
         unlock_inode(dir);
       end
       else
       begin
          printk('lookup (%d): lookup() not defined for inode %d\n', [current^.pid, dir^.ino]);
          result := FALSE;
       end;
   end;
end;



{******************************************************************************
 * dir_namei
 *
 * Input  : pointer to string
 *
 * Output : Pointer to inode or an error code
 *
 * Returns the inode of the directory of the specified name, and the name
 * within that directory.
 *
 * FIXME: for the moment, dir_namei() doesn't check directories access rights
 *
 * NOTE: may be we could optimize this function
 *****************************************************************************}
function dir_namei (path : pchar ; name : pointer) : P_inode_t; [public, alias : 'DIR_NAMEI'];

var
   tmp, res_name       : pchar;
   filename, basename  : string;
   base, inode         : P_inode_t;
   i, index, nb_dir, j : dword;
   str_len             : dword;

begin

   { Check if path is not a null string }
   if (path[0] = #0) then
   begin
      {$IFDEF DIR_NAMEI_WARNING}
         printk('dir_namei (%d): file name is a null string\n', [current^.pid]);
      {$ENDIF}
      result := -EINVAL;
      exit;
   end;

   {$IFDEF DEBUG_DIR_NAMEI}
      printk('dir_namei (%d): trying to find %s\n', [current^.pid, path]);
   {$ENDIF}

   tmp := path;

   { 'filename' initialization }

   i := 0;
   while (tmp^ <> #0) do
   begin
      filename[i] := tmp^;
      tmp += 1;
      i   += 1;
   end;
   filename[i] := #0;

   base := alloc_inode();
   if (base = NIL) then
   begin
      printk('dir_namei (%d): not enough memory\n', [current^.pid]);
      result := NIL;
      exit;
   end;

   if (filename[0] = '/') then
   begin
      {base := current^.root;}
      memcpy(current^.root, base, sizeof(inode_t));
      { Remove the first character ('/') }
      i := 0;
      while (filename[i] <> #0) do
      begin
         filename[i] := filename[i + 1];
         i += 1;
      end;
      filename[i] := #0;
   end
   else
      memcpy(current^.pwd, base, sizeof(inode_t));
      {base := current^.pwd;}

   if (filename[0] = #0) then   { It happens when path='/' }
   begin
      result := current^.root;
      exit;
   end;

   {* We are going to call lookup() for each directory in the path. So we
    * calculate how many directories there are *}

   nb_dir := 0;
   index  := 0;

   i := 0;
   while (filename[i] <> #0) do
   begin
      if (filename[i] = '/') then nb_dir += 1;
      i += 1;
   end;

   {$IFDEF DEBUG_DIR_NAMEI}
      printk('dir_namei (%d): %d directories in the path\n', [current^.pid, nb_dir]);
   {$ENDIF}

   inode := alloc_inode();
   if (inode = NIL) then
   begin
      printk('dir_namei (%d): not enough memory to look for %s\n', [current^.pid, path]);
      result := -ENOMEM;
      exit;
   end;

   if (nb_dir = 0) then
       basename := filename
   else
       for i := 1 to nb_dir do
       begin
	   j := 0;
	   str_len := 0;
	   while (filename[index] <> '/') do
	   begin
	      basename[j] := filename[index];
	      str_len += 1;
	      index   += 1;
	      j       += 1;
	   end;
	   basename[j] := #0;   { A string MUST end with this character }

	   if not lookup(base, @basename, str_len, @inode) then
	   begin
	      { One of the directory in the path has not been found !!! }
	      free_inode(inode);
	      {printk('VFS (namei): cannot find directory %s (in %s)\n', [basename, path]);}
	      result := -ENOENT;
	      exit;
	   end;

	   { Check if 'inode' is really a directory }
	   if not IS_DIR(inode) then
	   begin
	      free_inode(inode);
	      printk('dir_namei (%d): %s is not a directory\n', [current^.pid, basename]);
	      result := -ENOTDIR;
	      exit;
	   end;

           base  := inode;   { Next directory }
	   index += 1;
       end;

   { Look for the file }
   j       := 0;
   str_len := 0;
   while (filename[index] <> #0) do
   begin
      basename[j] := filename[index];
      str_len     += 1;
      index       += 1;
      j           += 1;
   end;
   basename[j] := #0;

{printk('calling lookup(%d, %s)\n', [base^.ino, basename]);}

   if not lookup(base, @basename, str_len, @inode) then
   begin
      { File has not been found !!! }
      free_inode(inode);
      {$IFDEF DIR_NAMEI_WARNING}
         printk('dir_namei (%d): cannot find file %s (in %s)\n', [current^.pid, basename, path]);
      {$ENDIF}
      result := -ENOENT;
      exit;
   end
   else
      result := inode;

end;



{******************************************************************************
 * namei
 *
 * Input  : pointer to string
 *
 * Output : Pointer to inode or an error code
 *
 * Returns the inode of the specified name.
 *
 * FIXME: for the moment, namei() doesn't check directories access rights
 *
 * NOTE: may be we could optimize this function 
 *****************************************************************************}
function namei (path : pchar) : P_inode_t; [public, alias : 'NAMEI'];

var
   tmp                 : pchar;
   filename, basename  : string;
   base, inode         : P_inode_t;
   i, index, nb_dir, j : dword;
   str_len             : dword;

begin

   { Check if path is not a null string }
   if (path[0] = #0) then
   begin
      {$IFDEF NAMEI_WARNING}
         printk('namei (%d): file name is a null string\n', [current^.pid]);
      {$ENDIF}
      result := -EINVAL;
      exit;
   end;

   {$IFDEF DEBUG_NAMEI}
      printk('namei (%d): trying to find %s\n', [current^.pid, path]);
   {$ENDIF}

   { First check if path isn't an easy one  :-) }
   if (path[1] = #0) then
   begin
      if (path[0] = '.') then
      begin
         current^.pwd^.count += 1;
	 result := current^.pwd;
	 exit;
      end
      else if (path[0] = '/') then
      begin
         current^.root^.count += 1;
	 result := current^.root;
	 exit;
      end;
   end
   else if (path[2] = #0) and (path[0] = '.') and (path[1] = '.')
       and (current^.pwd = current^.root) then
   begin
      current^.root^.count += 1;
      result := current^.root;
      exit;
   end;

   { So, path is not so easy... }

   tmp := path;

   {* 'filename' initialization (we copy path into filename)
    *
    * NOTE: path length MUST be < 255 *}

   i := 0;
   while (tmp^ <> #0) do
   begin
      filename[i] := tmp^;
      tmp += 1;
      i   += 1;
   end;
   filename[i] := #0;

   { base initialization }
   if (filename[0] = '/') then
   begin
      base := current^.root;
      { Remove the first character ('/') }
      i := 0;
      while (filename[i] <> #0) do
      begin
         filename[i] := filename[i + 1];
         i += 1;
      end;
      filename[i] := #0;
   end
   else
      base := current^.pwd;

   {* We are going to call lookup() for each directory in the path. So we
    * count how many directories there are *}
   nb_dir := 0;
   index  := 0;
   i      := 0;

   while (filename[i] <> #0) do
   begin
      if (filename[i] = '/') then nb_dir += 1;
      i += 1;
   end;

   {$IFDEF DEBUG_NAMEI}
      printk('namei (%d): %d directories in the path\n', [current^.pid, nb_dir]);
   {$ENDIF}

   inode := alloc_inode();
   if (inode = NIL) then
   begin
      printk('namei (%d): not enough memory to look for %s\n', [current^.pid, path]);
      result := -ENOMEM;
      exit;
   end;

   if (nb_dir = 0) then
       basename := filename
   else
       for i := 1 to nb_dir do
       begin
	   j       := 0;
	   str_len := 0;
	   while (filename[index] <> '/') do
	   begin
	      basename[j] := filename[index];
	      str_len += 1;
	      index   += 1;
	      j       += 1;
	   end;
	   basename[j] := #0;   { A string MUST end with this character }

	   if not lookup(base, @basename, str_len, @inode) then
	   begin
	      { One of the directory in the path has not been found !!! }
	      free_inode(inode);
	      result := -ENOENT;
	      exit;
	   end;

	   { Check if 'inode' is really a directory }
	   if not IS_DIR(inode) then
	   begin
	      free_inode(inode);
	      result := -ENOTDIR;
	      exit;
	   end;

           base  := inode;   { Next directory }
	   inode := alloc_inode();
	   if (inode = NIL) then
	   begin
	      printk('namei (%d): not enough memory\n', [current^.pid]);
	      result := NIL;
	      exit;
	   end;
	   index += 1;
       end;

   { Look for the file }
   j       := 0;
   str_len := 0;
   while (filename[index] <> #0) do
   begin
      basename[j] := filename[index];
      str_len     += 1;
      index       += 1;
      j           += 1;
   end;
   basename[j] := #0;

   if (basename[0] = #0) then   { This happens when 'path' ends with a'/' }
   begin
      result := inode;
      exit;
   end;

   {$IFDEF DEBUG_NAMEI}
      printk('namei (%d): looking for %s in inode %d\n', [current^.pid, basename, base^.ino]);
   {$ENDIF}

   if not lookup(base, @basename, str_len, @inode) then
   begin
      { File has not been found !!! }
      free_inode(inode);
      {$IFDEF NAMEI_WARNING}
         printk('namei (%d): cannot find file %s (in %s)\n', [current^.pid, basename, path]);
      {$ENDIF}
      {$IFDEF DEBUG_NAMEI}
         printk('namei (%d): cannot find file %s (in %s)\n', [current^.pid, basename, path]);
      {$ENDIF}
      result := -ENOENT;
      exit;
   end
   else
      result := inode;

   {$IFDEF DEBUG_NAMEI}
      printk('namei (%d): %s -> %d\n', [current^.pid, path, inode^.ino]);
   {$ENDIF}

end;



begin
end.
