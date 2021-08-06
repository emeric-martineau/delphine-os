{******************************************************************************
 *  namei.pp
 *
 *  This file contains lookup(), sys_unlink(), sys_mkdir(), sys_rmdir(),
 *  namei() and dir_namei().
 *
 *  It also contains functions necessary to lookup_cache.
 *
 *  NOTE: Functions used to manage lookup_cache begin with 'lc_'
 *
 *  Copyleft (C) 2003
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
{$I lock.inc}
{$I process.inc}

{* Local macros *}

{DEFINE DEBUG_LC_ADD_ENTRY}
{DEFINE DEBUG_LC_DEL_ENTRY}
{DEFINE DEBUG_LC_FIND_ENTRY}
{DEFINE DEBUG_NAMEI}
{DEFINE NAMEI_WARNING}
{DEFINE DEBUG_DIR_NAMEI}
{DEFINE DEBUG_SYS_UNLINK}
{DEFINE DEBUG_SYS_MKDIR}
{DEFINE DEBUG_SYS_RMDIR}
{DEFINE DIR_NAMEI_WARNING}
{DEFINE DEBUG_LOOKUP}


{* External procedure and functions *}

function  access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; external;
function  alloc_inode : P_inode_t; external;
procedure free_inode (inode : P_inode_t); external;
procedure free_lookup_cache; external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
function  IS_DIR (inode : P_inode_t) : boolean; external;
procedure lock_inode (inode : P_inode_t); external;
function  memcmp (src, dest : pointer ; size : dword) : boolean; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure read_lock (rw : P_rwlock_t); external;
procedure read_unlock (rw : P_rwlock_t); external;
procedure unlock_inode (inode : P_inode_t); external;
procedure write_lock (rw : P_rwlock_t); external;
procedure write_unlock (rw : P_rwlock_t); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}
var
   lookup_cache         : array[1..MAX_LOOKUP_ENTRIES] of P_lookup_cache_entry;
	lookup_cache_lock    : rwlock_t;
   lookup_cache_entries : dword;


{* Procedures and functions defined in this file *}

function  dir_namei (path : pchar ; name : pointer) : P_inode_t;
function  lc_add_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : longint;
function  lc_find_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : longint;
function  lookup (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : longint;
function  namei (path : pchar) : P_inode_t;
function  sys_mkdir (pathname : pchar ; mode : dword) : dword; cdecl;
function  sys_rmdir (pathname : pchar ; mode : dword) : dword; cdecl;
function  sys_unlink (path : pchar) : dword; cdecl;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * lc_del_entry
 *
 * Del an entry in lookup_cache
 *
 *****************************************************************************}
procedure lc_del_entry (ind : dword);

var
	lc_entry : P_lookup_cache_entry;

begin

	write_lock(@lookup_cache_lock);

	lc_entry := lookup_cache[ind];

	{$IFDEF DEBUG_LC_DEL_ENTRY}
		print_bochs('lc_del_entry: i=%d  res_inode^.count=%d\n', [ind, lc_entry^.res_inode^.count]);
	{$ENDIF}

	free_inode(lc_entry^.dir);
	kfree_s(lc_entry^.name, lc_entry^.len);
	free_inode(lc_entry^.res_inode);
	lookup_cache[ind] := NIL;
	lookup_cache_entries -= 1;

	write_unlock(@lookup_cache_lock);

end;



{******************************************************************************
 * lc_add_entry
 *
 * Add an entry in lookup_cache
 *
 * OUPUT : -1 on error, lookup_cache index in which the new entry is.
 *****************************************************************************}
function lc_add_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : longint; [public, alias : 'LC_ADD_ENTRY'];

var
   new_ent : P_lookup_cache_entry;
   i       : dword;

begin

	result := -1;

	write_lock(@lookup_cache_lock);

   if (lookup_cache_entries = MAX_LOOKUP_ENTRIES) then
   begin
      print_bochs('lc_add_entry  (%d): lookup_cache is full\n', [current^.pid]);
		free_lookup_cache();
   end;

   new_ent := kmalloc(sizeof(lookup_cache_entry));
   if (new_ent = NIL) then
   begin
      printk('lc_add_entry  (%d): WARNING -> not enough memory (1)\n', [current^.pid]);
		write_unlock(@lookup_cache_lock);
      exit;
   end;

   new_ent^.name := kmalloc(len);
   if (new_ent^.name = NIL) then
   begin
      printk('lc_add_entry  (%d): WARNING -> not enough memory (2)\n', [current^.pid]);
      kfree_s(new_ent, sizeof(lookup_cache_entry));
		write_unlock(@lookup_cache_lock);
      exit;
   end;

   dir^.count        += 1;
   res_inode^^.count += 1;

   new_ent^.dir := dir;
   memcpy(name, new_ent^.name, len);
   new_ent^.len := len;
   new_ent^.res_inode := res_inode^;

   i := 1;
   while (lookup_cache[i] <> NIL) and (i < MAX_LOOKUP_ENTRIES) do i += 1;

   lookup_cache[i] := new_ent;
   lookup_cache_entries += 1;

	write_unlock(@lookup_cache_lock);

   {$IFDEF DEBUG_LC_ADD_ENTRY}
      print_bochs('lc_add_entry: %d %s %d %d (i=%d) %h\n', [dir^.ino, name, len, res_inode^^.ino, i, res_inode^]);
   {$ENDIF}

	result := i;

end;



{******************************************************************************
 * lc_find_entry
 *
 * OUTPUT : -1 on error, 0 if entry was not found, lookup_cache index if entry
 *          was found.
 *
 * Find an entry in lookup_cache
 *****************************************************************************}
function lc_find_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : longint;

var
   i, i_max : dword;

begin

   {$IFDEF DEBUG_LC_FIND_ENTRY}
{      printk('lc_find_entry (%d): %d %s %d\n', [current^.pid, dir^.ino, name, len]);}
   {$ENDIF}

	read_lock(@lookup_cache_lock);

   result := -1;
   i_max  := lookup_cache_entries;

   for i := 1 to MAX_LOOKUP_ENTRIES do
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
	       		printk('lc_find_entry (%d): entry found for %s i=%d, ino=%d (%h)\n',
							 [current^.pid, name, i,
							  lookup_cache[i]^.res_inode^.ino,
							  lookup_cache[i]^.res_inode]);
	    		{$ENDIF}
	    		lookup_cache[i]^.res_inode^.count += 1;
	    		free_inode(res_inode^);
	    		res_inode^ := lookup_cache[i]^.res_inode;
	    		result := i;
				read_unlock(@lookup_cache_lock);
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
					result := 0;
					read_unlock(@lookup_cache_lock);
	       		exit;
	    		end;
	 		end;
      end;
   end;

	read_unlock(@lookup_cache_lock);

end;



{******************************************************************************
 * lookup
 *
 * Input  : directory inode, file/directory we look for, size of 'name', inode
 *	    		to fill
 *
 * Output : 0 if entry don't need to be in cache, -1 on error or index in
 * 			lookup_cache if entry has been found or just added in cache.
 *
 * If everything is ok, 'res_inode' is fill with 'name' inode info
 *
 *****************************************************************************}
function lookup (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : longint; [public, alias : 'LOOKUP'];

var
	ok  : boolean;
	res : longint;

begin

   {$IFDEF DEBUG_LOOKUP}
      printk('lookup (%d): looking for %s in inode directory %d\n', [current^.pid, name, dir^.ino]);
   {$ENDIF}

   result := -1;

   if not IS_DIR(dir) then
   begin
      printk('lookup (%d): inode %d is not a directory\n', [current^.pid, dir^.ino]);
      exit;
   end;

   { First check if 'name' isn't an easy one  :-) }
   if (len = 1) and (name[0] = '.') then
   begin
      dir^.count += 1;
      free_inode(res_inode^);
      res_inode^ := dir;
      result := 0;
      {$IFDEF DEBUG_LOOKUP}
      	 printk('namei (%d): %s -> %d (%d) (easy 1)\n', [current^.pid, name, dir^.ino, dir^.count]);
      {$ENDIF}
      exit;
   end
   else if (len = 2) and (name[0] = '.') and (name[1] = '.')
   	 and (dir = current^.root) then
   begin
      current^.root^.count += 1;
      free_inode(res_inode^);
      res_inode^ := current^.root;
      result := 0;
      {$IFDEF DEBUG_LOOKUP}
      	 printk('namei (%d): %s -> %d (%d) (easy 2)\n', [current^.pid, name, current^.root^.ino, current^.root^.count]);
      {$ENDIF}
      exit;
   end;

   { So, 'name' is not so easy... }

	res := lc_find_entry(dir, name, len, res_inode);
   if (res > 0) then
   begin
      {$IFDEF DEBUG_LOOKUP}
      	 printk('lookup (%d): found in cache\n', [current^.pid]);
      {$ENDIF}
      result := res;
   end
   else
   begin
		result := -1;
      if (dir^.op <> NIL) and (dir^.op^.lookup <> NIL) then
      begin
         lock_inode(dir);
         ok := dir^.op^.lookup(dir, name, len, res_inode);
	 		if (ok) then
				 result := lc_add_entry(dir, name, len, res_inode);
         unlock_inode(dir);
      end
      else
         printk('lookup (%d): lookup() not defined for inode %d\n', [current^.pid, dir^.ino]);
   end;

	{$IFDEF DEBUG_LOOKUP}
		printk('lookup (%d): result=%d\n', [current^.pid, result]);
	{$ENDIF}

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
   tmp			        : pchar;
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
      print_bochs('dir_namei (%d): trying to find %s\n', [current^.pid, path]);
   {$ENDIF}

   tmp := path;

   {* FIXME ???
	 *
	 * 'filename' initialization (we copy path into filename)
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

	{ If last character is '/' remove it }
	if (filename[i-1] = '/') then
		 filename[i-1] := #0;

   {* We are going to call lookup() for each directory in the path. So we
    * calculate how many directories there are *}
   nb_dir := 0;
   index  := 0;
   i      := 0;

   while (filename[i] <> #0) do
   begin
      if (filename[i] = '/') then nb_dir += 1;
      i += 1;
   end;

   {$IFDEF DEBUG_DIR_NAMEI}
      print_bochs('dir_namei (%d): %d directories in the path\n', [current^.pid, nb_dir]);
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
	begin
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

			if (str_len <> 0) then
	   	begin
	      	{$IFDEF DEBUG_DIR_NAMEI}
	         	print_bochs('dir_namei (%d): calling lookup(%s) DIR\n', [current^.pid, basename]);
	      	{$ENDIF}
	      	if (lookup(base, @basename, str_len, @inode) < 0) then
	      	begin
	         	{ One of the directory in the path has not been found !!! }
		 			{$IFDEF DEBUG_DIR_NAMEI}
		    			print_bochs('dir_namei (%d): %s has not been found by lookup()\n', [current^.pid, basename]);
		 			{$ENDIF}
	         	free_inode(inode);
	         	result := -ENOENT;
	         	exit;
	      	end;

	      	{ Check if 'inode' is really a directory }
	      	if not IS_DIR(inode) then
	      	begin
	         	{$IFDEF DEBUG_DIR_NAMEI}
	            	print_bochs('dir_namei (%d): %s is not a directory\n', [current^.pid, basename]);
	         	{$ENDIF}
	         	free_inode(inode);
	         	result := -ENOTDIR;
	         	exit;
	      	end;

	      	base  := inode;   { Next directory }
	      	inode := alloc_inode();
	      	if (inode = NIL) then
	      	begin
	         	printk('dir_namei (%d): not enough memory\n', [current^.pid]);
		 			result := NIL;
		 			exit;
	      	end;
			end;
	   	index += 1;
		end;
	end;

   str_len := 0;
   tmp     := name;
   j       := 0;
   while (filename[index] <> #0) do
   begin
      tmp[j]  := filename[index];
      str_len += 1;
      j       += 1;
      index   += 1;
   end;
   tmp[j] := #0;

   if (str_len = 0) then
   begin
      {IFDEF DEBUG_DIR_NAMEI}
         print_bochs('dir_namei (%d): str_len=0\n', [current^.pid]);
      {ENDIF}
      free_inode(inode);
      result := -EISDIR;
   end
   else
   begin
      free_inode(inode);
      result := base;
   end;

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
 * FIXME: - for the moment, namei() doesn't check directories access rights
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
         print_bochs('namei (%d): file name is a null string\n', [current^.pid]);
      {$ENDIF}
      result := -EINVAL;
      exit;
   end;

   {$IFDEF DEBUG_NAMEI}
      print_bochs('namei (%d): trying to find %s\n', [current^.pid, path]);
   {$ENDIF}

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
    * count how many directories there are (nb_dir) *}
   nb_dir := 0;
   index  := 0;
   i      := 0;

   while (filename[i] <> #0) do
   begin
      if (filename[i] = '/') then nb_dir += 1;
      i += 1;
   end;

   {$IFDEF DEBUG_NAMEI}
      print_bochs('namei (%d): %d directories in the path\n', [current^.pid, nb_dir]);
   {$ENDIF}

   inode := alloc_inode();
   if (inode = NIL) then
   begin
      print_bochs('namei (%d): not enough memory to look for %s\n', [current^.pid, path]);
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

	   if (str_len <> 0) then
	   begin
	      {$IFDEF DEBUG_NAMEI}
	         print_bochs('namei (%d): calling lookup(%s) DIR\n', [current^.pid, basename]);
	      {$ENDIF}
	      if (lookup(base, @basename, str_len, @inode) < 0) then
	      begin
	         { One of the directory in the path has not been found !!! }
	         {$IFDEF DEBUG_NAMEI}
	            print_bochs('namei (%d): %s has not been found by lookup()\n', [current^.pid, basename]);
	         {$ENDIF}
	         free_inode(inode);
	         result := -ENOENT;
	         exit;
	      end;

	      { Check if 'inode' is really a directory }
	      if not IS_DIR(inode) then
	      begin
	         {$IFDEF DEBUG_NAMEI}
	            print_bochs('namei (%d): %s is not a directory\n', [current^.pid, basename]);
	         {$ENDIF}
	         free_inode(inode);
	         result := -ENOTDIR;
	         exit;
	      end;

         base  := inode;   { Next directory }
	      inode := alloc_inode();
	      if (inode = NIL) then
	      begin
	         print_bochs('namei (%d): not enough memory\n', [current^.pid]);
	         result := NIL;
	         exit;
	      end;
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
      {$IFDEF DEBUG_NAMEI}
         print_bochs('namei (%d): %s -> %d\n', [current^.pid, path, base^.ino]);
      {$ENDIF}
      free_inode(inode);
      result := base;
      exit;
   end;

   {$IFDEF DEBUG_NAMEI}
      print_bochs('namei (%d): calling lookup(%s) FILE\n', [current^.pid, basename]);
   {$ENDIF}

   if (lookup(base, @basename, str_len, @inode) < 0) then
   begin
      { File has not been found !!! }
      free_inode(inode);
      {$IFDEF NAMEI_WARNING}
         print_bochs('namei (%d): cannot find file %s (in %s)\n', [current^.pid, basename, path]);
      {$ENDIF}
      {$IFDEF DEBUG_NAMEI}
         print_bochs('namei (%d): cannot find file %s (in %s)\n', [current^.pid, basename, path]);
      {$ENDIF}
      result := -ENOENT;
      exit;
   end
   else
      result := inode;

   {$IFDEF DEBUG_NAMEI}
      print_bochs('namei (%d): %s -> %d\n', [current^.pid, path, inode^.ino]);
   {$ENDIF}

end;



{******************************************************************************
 * sys_unlink
 *
 * Removes a directory entry
 *
 * FIXME: this function is not done
 *****************************************************************************}
function sys_unlink (path : pchar) : dword; cdecl; [public, alias : 'SYS_UNLINK'];

var
   len, ind         : dword;
   name             : string;
   dir_inode, inode : P_inode_t;

begin

   {$IFDEF DEBUG_SYS_UNLINK}
      print_bochs('sys_unlink (%d): path=%s\n', [current^.pid, path]);
   {$ENDIF}

   if (path[0] = #0) then
   begin
      result := -EINVAL;
      exit;
   end;

   dir_inode := dir_namei(path, @name);
   if (longint(dir_inode) < 0) then
   begin
      {$IFDEF DEBUG_SYS_UNLINK}
      	 print_bochs('sys_unlink (%d): no such file\n', [current^.pid]);
      {$ENDIF}
      result := longint(dir_inode);
      exit;
   end;

   {$IFDEF DEBUG_SYS_UNLINK}
      print_bochs('sys_unlink (%d): name=%s (dir ino=%d)\n', [current^.pid, name, dir_inode^.ino]);
   {$ENDIF}

	{ Check if we can write in dir_inode }
   if not access_rights_ok(O_WRONLY, dir_inode) then
   begin
      {$IFDEF DEBUG_SYS_UNLINK}
      	 print_bochs('sys_unlink (%d): cannot write to inode %d\n', [current^.pid, dir_inode^.ino]);
      {$ENDIF}
      result := -EPERM;
      free_inode(dir_inode);
      exit;
   end;

   len := 0;
   while (name[len] <> #0) do len += 1;

   inode := alloc_inode();
   if (inode = NIL) then
   begin
      print_bochs('sys_unlink: not enough memory for alloc_inode() (1)\n', []);
      result := -ENOMEM;
      exit;
   end;

	ind := lookup(dir_inode, @name, len, @inode);
   if (ind = -1) then
   begin
      {$IFDEF DEBUG_SYS_UNLINK}
      	 print_bochs('sys_unlink (%d): lookup() failed\n', [current^.pid]);
      {$ENDIF}      
      result := -ENOENT;
      free_inode(dir_inode);
      free_inode(inode);
      exit;
   end;

   if not access_rights_ok(O_WRONLY, inode) then
   begin
      {$IFDEF DEBUG_SYS_UNLINK}
      	 print_bochs('sys_unlink (%d): cannot write to inode %d\n', [current^.pid, inode^.ino]);
      {$ENDIF}
      result := -EPERM;
      free_inode(dir_inode);
      free_inode(inode);
      exit;
   end;

   if IS_DIR(inode) then
   begin
      {$IFDEF DEBUG_SYS_UNLINK}
      	 print_bochs('sys_unlink (%d): %s (ino=%d) is a directory\n', [current^.pid, name, inode^.ino]);
      {$ENDIF}      
      result := -EISDIR;
      free_inode(dir_inode);
      free_inode(inode);
      exit;
   end;

   {$IFDEF DEBUG_SYS_UNLINK}
      print_bochs('sys_unlink (%d): %s ino=%d\n', [current^.pid, name, inode^.ino]);
   {$ENDIF}

   lock_inode(inode);

   if (inode^.op <> NIL) and (inode^.op^.unlink <> NIL) then
       result := inode^.op^.unlink(dir_inode, @name, inode)
   else
   begin
      print_bochs('sys_unlink: unlink() operation not defined for %s\n', [path]);
      result := -ENOSYS;
   end;

   if (result <> 0) then
       print_bochs('sys_unlink: error during fs-unlink() -> %d\n', [result]);

   unlock_inode(inode);
   free_inode(dir_inode);
   free_inode(inode);


	{ Remove inode from lookup_cache }

	if (ind <> 0) then
		 lc_del_entry(ind);

end;



{******************************************************************************
 * sys_mkdir
 *
 *****************************************************************************}
function sys_mkdir (pathname : pchar ; mode : dword) : dword; cdecl; [public, alias : 'SYS_MKDIR'];

var
	len			: dword;
	name			: string;
	inode 		: P_inode_t;
	dir_inode 	: P_inode_t;

label fin;

begin

	result := -ENOSYS;

	{$IFDEF DEBUG_SYS_MKDIR}
		print_bochs('sys_mkdir (%d): pathname=%s mode=%h\n',
						[current^.pid, pathname, mode]);
	{$ENDIF}

	{ Get directory in which we have to create the new one }
	dir_inode := dir_namei(pathname, @name);
   if (longint(dir_inode) < 0) then
	{ Cannot find it }
   begin
		{$IFDEF DEBUG_SYS_MKDIR}
			print_bochs('sys_mkdir (%d): dir_namei() failed\n', [current^.pid]);
		{$ENDIF}
		result := longint(dir_inode);
		exit;
   end
	else
	{ OK, check if the file already exists }
	begin
	   len := 0;
		while (name[len] <> #0) do len += 1;

   	inode := alloc_inode();
   	if (inode = NIL) then
   	begin
      	print_bochs('sys_mkdir (%d): not enough memory for alloc_inode() (1)\n',
							[current^.pid]);
      	result := -ENOMEM;
			free_inode(dir_inode);
   	   exit;
	   end;

		lookup(dir_inode, @name, len, @inode);
		if (inode^.ino <> 0) then
		{ The file already exists }
		begin
			{$IFDEF DEBUG_SYS_MKDIR}
				print_bochs('sys_mkdir (%d): %s already exists\n',
								[current^.pid, name]);
			{$ENDIF}
			result := -EEXIST;
			goto fin;
		end;

		if (dir_inode^.op = NIL) or (dir_inode^.op^.mkdir = NIL) then
		begin
			{$IFDEF DEBUG_SYS_MKDIR}
				print_bochs('sys_mkdir (%d): op^.mkdir = NIL\n', [current^.pid]);
			{$ENDIF}
			result := -ENOSYS;
			goto fin;
		end;

		result := dir_inode^.op^.mkdir(dir_inode, @name, mode);

	end;

fin:
	free_inode(dir_inode);
	free_inode(inode);

end;



{******************************************************************************
 * sys_rmdir
 *
 *****************************************************************************}
function sys_rmdir (pathname : pchar ; mode : dword) : dword; cdecl; [public, alias : 'SYS_RMDIR'];

var
	dir_inode	: P_inode_t;
	inode			: P_inode_t;
	name			: string;
	len, ind 	: dword;

begin

	{$IFDEF DEBUG_SYS_RMDIR}
		print_bochs('sys_rmdir (%d): pathname=%s\n', [current^.pid, pathname]);
	{$ENDIF}

   dir_inode := dir_namei(pathname, @name);
   if (longint(dir_inode) < 0) then
   begin
      {$IFDEF DEBUG_SYS_RMDIR}
      	 print_bochs('sys_rmdir (%d): no such file\n', [current^.pid]);
      {$ENDIF}
      result := longint(dir_inode);
      exit;
   end;

   {$IFDEF DEBUG_SYS_RMDIR}
      print_bochs('sys_rmdir (%d): name=%s (dir ino=%d)\n', [current^.pid, name, dir_inode^.ino]);
   {$ENDIF}

	{ Check if we can write in dir_inode }
   if not access_rights_ok(O_WRONLY, dir_inode) then
   begin
      {$IFDEF DEBUG_SYS_RMDIR}
      	 print_bochs('sys_rmdir (%d): cannot write to inode %d\n', [current^.pid, dir_inode^.ino]);
      {$ENDIF}
      result := -EPERM;
      free_inode(dir_inode);
      exit;
   end;

   len := 0;
   while (name[len] <> #0) do len += 1;

   inode := alloc_inode();
   if (inode = NIL) then
   begin
      print_bochs('sys_rmdir: not enough memory for alloc_inode() (1)\n', []);
      result := -ENOMEM;
      exit;
   end;

	ind := lookup(dir_inode, @name, len, @inode);
   if (ind = -1) then
   begin
      {$IFDEF DEBUG_SYS_RMDIR}
      	 print_bochs('sys_rmdir (%d): lookup() failed\n', [current^.pid]);
      {$ENDIF}      
      result := -ENOENT;
      free_inode(dir_inode);
      free_inode(inode);
      exit;
   end;

   if not access_rights_ok(O_WRONLY, inode) then
   begin
      {$IFDEF DEBUG_SYS_RMDIR}
      	 print_bochs('sys_rmdir (%d): cannot write to inode %d\n', [current^.pid, inode^.ino]);
      {$ENDIF}
      result := -EPERM;
      free_inode(dir_inode);
      free_inode(inode);
      exit;
   end;

   {$IFDEF DEBUG_SYS_RMDIR}
      print_bochs('sys_rmdir (%d): %s ino=%d\n', [current^.pid, name, inode^.ino]);
   {$ENDIF}

   lock_inode(inode);

   if (inode^.op <> NIL) and (inode^.op^.rmdir <> NIL) then
       result := inode^.op^.rmdir(dir_inode, @name, inode)
   else
   begin
      print_bochs('sys_rmdir: rmdir() operation not defined for %s\n', [pathname]);
      result := -ENOSYS;
   end;

   if (result <> 0) then
       print_bochs('sys_rmdir: error during fs-rmdir() -> %d\n', [result]);

   unlock_inode(inode);
   free_inode(dir_inode);
   free_inode(inode);


	{ Remove inode from lookup_cache }

	if (ind <> 0) then
		 lc_del_entry(ind);

end;



begin
end.
