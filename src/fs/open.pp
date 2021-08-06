{******************************************************************************
 *  open.pp
 *
 *  open(), access(), chdir() , fchdir() and close() system calls
 *  implementation
 *
 *  Copyleft 2002 GaLi
 *
 *  version 0.4 - 14/09/2003 - GaLi - move namei() in src/fs/namei.pp
 *
 *  version 0.3 - 15/05/2003 - GaLi - Open() can now open directories.
 *                                    Add sys_chdir().
 *
 *  version 0.2 - 02/10/2002 - GaLi - Add namei()
 *
 *  version 0.1 - 24/09/2002 - GaLi - Correct a few bugs and check access
 *                                    rigths
 *
 *  version 0.0 - 22/08/2002 - GaLi - initial version
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


unit _open;


INTERFACE


{DEFINE DEBUG}
{DEFINE DEBUG_CREATE}
{DEFINE DEBUG_SYS_OPEN}
{DEFINE DEBUG_SYS_CHMOD}
{DEFINE DEBUG_SYS_CLOSE}
{DEFINE DEBUG_SYS_ACCESS}
{DEFINE SYS_ACCESS_WARNING}
{DEFINE OPEN_WARNING}
{DEFINE CLOSE_WARNING}
{DEFINE CHDIR_WARNING}


{$I errno.inc}
{$I fs.inc}
{$I process.inc}
{$I time.inc}


{* External procedures and functions definition *}
function  access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; external;
function  alloc_inode : P_inode_t; external;
function  dir_namei (path : pchar ; name : pointer) : P_inode_t; external;
procedure free_inode (inode : P_inode_t); external;
procedure interruptible_wake_up (p : PP_wait_queue); external;
function  IS_DIR (inode : P_inode_t) : boolean; external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure lock_inode (inode : P_inode_t); external;
function  lookup (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : longint; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
function  namei (path : pchar) : P_inode_t; external;
procedure printk (format : string ; args : array of const); external;
procedure unlock_inode (inode : P_inode_t); external;


{* External variables definition *}
var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables definition *}


{* Unit procedures and functions definition *}
function  create (dir : P_inode_t ; path : pchar ; fd, flags, mode : dword) : P_inode_t;
function  sys_access (filename : pchar ; mode : dword) : dword; cdecl;
function  sys_chdir (filename : pchar) : dword; cdecl;
function  sys_chmod (filename : pchar ; mode : dword) : dword; cdecl;
function  sys_close (fd : dword) : dword; cdecl;
function  sys_fchdir (fd : dword) : dword; cdecl;
function  sys_open (path : pchar ; flags, mode : dword) : dword; cdecl;
function  sys_utime (path : pchar ; times : P_utimbuf) : dword; cdecl;


IMPLEMENTATION


{$I inline.inc}


{* Constants only used in THIS unit *}


{* Types only used in THIS file *}


{* Global variables only used in THIS file *}



{******************************************************************************
 * sys_open
 *
 * Input : pointer to pathname, flags, mode (if file has to be created).
 *
 * Output : file descriptor or error code
 *
 * FIXME: care about flags...
 *****************************************************************************}
function sys_open (path : pchar ; flags, mode : dword) : dword; cdecl; [public, alias : 'SYS_OPEN'];

var
   fd, res, i : dword;
   fichier    : P_file_t;
   dir_inode  : P_inode_t;
   file_inode : P_inode_t;
   filename   : string;

begin

   {$IFDEF DEBUG_SYS_OPEN}
      printk('sys_open (%d): PATH=%s flags=%h mode=%h\n', [current^.pid, path, flags, mode]);
   {$ENDIF}

	sti();

   { Look for a free file descriptor }
   fd := 0;
   while (current^.file_desc[fd] <> NIL) and (fd < OPEN_MAX) do
          fd += 1;

   if (current^.file_desc[fd] = NIL) then
   { There is at least one free file descriptor }
   begin

      fichier := kmalloc(sizeof(file_t));
      if (fichier = NIL) then
      begin
	 		printk('sys_open: not enough memory to open %s\n', [path]);
	 		result := -ENOMEM;
	 		exit;
      end;

      memset(fichier, 0, sizeof(file_t));

      {$IFDEF DEBUG_SYS_OPEN}
         printk('sys_open (%d): going to call dir_namei(path)...', [current^.pid]);
      {$ENDIF}

      dir_inode := dir_namei(path, @filename);

      {$IFDEF DEBUG_SYS_OPEN}
         printk('   OK\n', []);
      {$ENDIF}

      if (longint(dir_inode) < 0) then
      {* dir_namei() returned an error code, not a valid pointer.
       * It means that the file hasn't been found and that we have to
       * create it *}
      begin
         {$IFDEF OPEN_WARNING}
            printk('sys_open (%d): no inode returned by dir_namei (%d)\n', [current^.pid, dir_inode]);
	 		{$ENDIF}
	 		{$IFDEF DEBUG_SYS_OPEN}
	    		printk('sys_open (%d): no inode returned by dir_namei (%d)\n', [current^.pid, dir_inode]);
	 		{$ENDIF}
      	kfree_s(fichier, sizeof(file_t));
      	result := longint(dir_inode);
      	exit;
      end;

      { Get filename length }
      i := 0;
      while (filename[i] <> #0) do i += 1;

      file_inode := alloc_inode();

      {$IFDEF DEBUG_SYS_OPEN}
      	 printk('sys_open (%d): calling lookup %s\n', [current^.pid, filename]);
      {$ENDIF}

      if (lookup(dir_inode, @filename, i, @file_inode) < 0) then
      begin
      	if (flags and O_CREAT) = 0 then
	 		begin
	    		result := -ENOENT;
	    		free_inode(dir_inode);
	    		free_inode(file_inode);
	    		exit;
	 		end
	 		else
	 		begin
	    		file_inode := create(dir_inode, @filename, fd, flags, mode);
	    		if (longint(file_inode) < 0) then
	    		begin
	       		free_inode(dir_inode);
	       		result := longint(file_inode);
	       		exit;
	    		end;
	 		end;
      end;

      if ((flags and O_DIRECTORY) = O_DIRECTORY) and
      	 (not IS_DIR(file_inode)) then
      begin
      	printk('sys_open (%d): called with O_DIRECTORY but %s is not directory\n', [current^.pid, path]);
      	result := -ENOTDIR;
	 		free_inode(dir_inode);
	 		free_inode(file_inode);
	 		exit;
      end;

      {$IFDEF DEBUG_SYS_OPEN}
         printk('sys_open (%d): %s has inode number %d\n', [current^.pid, path, file_inode^.ino]);
      {$ENDIF}

      if not (access_rights_ok(flags, file_inode)) then
      begin
      	{$IFDEF DEBUG_SYS_OPEN}
	    		printk('sys_open (%d): permission denied\n', [current^.pid]);
	 		{$ENDIF}
	 		kfree_s(fichier, sizeof(file_t));
	 		free_inode(dir_inode);
	 		free_inode(file_inode);
	 		result := -EACCES;
	 		exit;
      end;

      if (flags and O_APPEND) = O_APPEND then
      	 fichier^.pos := file_inode^.size
      else if (flags and O_TRUNC) = O_TRUNC then
      begin
	   	fichier^.pos := 0;
      	if (file_inode^.op <> NIL) and (file_inode^.op^.truncate <> NIL) then
	          file_inode^.op^.truncate(file_inode);
	   end
      else
      	fichier^.pos := 0;

      { Access rights are ok, we fill 'fichier' }
      fichier^.inode := file_inode;
      fichier^.count := 1;
      fichier^.uid   := current^.uid;
      fichier^.gid   := current^.gid;
      fichier^.flags := flags;
      fichier^.op    := file_inode^.op^.default_file_ops;
      
      { Can we call file-specific open() function ? }
      if ((fichier^.op <> NIL) and (fichier^.op^.open <> NIL)) then
           fichier^.op^.open(file_inode, fichier);

      current^.file_desc[fd] := fichier;
      
      result := fd;  { OK, stop here (that was not funny) }

      {$IFDEF DEBUG_SYS_OPEN}
         printk('sys_open (%d): fd %d (%h) is opened (%s)\n', [current^.pid, fd, current^.file_desc[fd], path]);
      {$ENDIF}

   end
   else
   { No more free file descriptors }
   begin
      printk('sys_open (%d): cannot open %s (no file descriptor)\n', [current^.pid, path]);
      result := -EMFILE;
   end;

end;



{******************************************************************************
 * sys_close
 *
 *****************************************************************************}
function sys_close (fd : dword) : dword; cdecl; [public, alias : 'SYS_CLOSE'];

var
   fichier : P_file_t;

begin

   {$IFDEF DEBUG_SYS_CLOSE}
      printk('sys_close (%d): fd=%d (%h) \n', [current^.pid, fd, current^.file_desc[fd]]);
   {$ENDIF}

	sti();

   fichier := current^.file_desc[fd];
	result  := 0;

   if ((fichier = NIL) or (fd >= OPEN_MAX)) then
   begin
      {$IFDEF DEBUG_SYS_CLOSE}
         printk('sys_close (%d): fd #%d is not opened. Can''t close it  :-)\n', [current^.pid, fd]);
      {$ENDIF}
      result := -EBADF;
      exit;
   end;

   {$IFDEF DEBUG_SYS_CLOSE}
      printk(' f_count: %d  i_count: %d\n', [fichier^.count, fichier^.inode^.count]);
   {$ENDIF}

   fichier^.count -= 1;

   if (fichier^.count = 0) then
   begin
      {$IFDEF DEBUG_SYS_CLOSE}
         printk('sys_close (%d): freeing fichier\n', [current^.pid]);
      {$ENDIF}
      if ((fichier^.op <> NIL) and (fichier^.op^.close <> NIL)) then
      begin
	 		{$IFDEF DEBUG_SYS_CLOSE}
	    		printk('sys_close (%d): calling specific close() function\n', [current^.pid]);
	 		{$ENDIF}
         result := fichier^.op^.close(fichier);
      end
      else
      begin
         {$IFDEF DEBUG_SYS_CLOSE}
	    		printk('sys_close (%d): ''close'' operation is not defined for fd #%d.\n', [current^.pid, fd]);
	 		{$ENDIF}
	 		result := 0;
      end;
      free_inode(fichier^.inode);
      kfree_s(fichier, sizeof(file_t));
   end;

   current^.file_desc[fd] := NIL;

	{$IFDEF DEBUG_SYS_CLOSE}
		printk('sys_close (%d): BYE fd=%d res=%d\n', [current^.pid, fd, result]);
	{$ENDIF}

end;



{******************************************************************************
 * sys_utime
 *
 * FIXME: this function does nothing   :-)
 *****************************************************************************}
function sys_utime (path : pchar ; times : P_utimbuf) : dword; cdecl; [public, alias : 'SYS_UTIME'];
begin

	sti();

   printk('sys_utime (%d): %s  %h\n', [current^.pid, path, times]);

   result := -ENOSYS;

end;



{******************************************************************************
 * sys_chdir
 *
 * Changes the current working directory.
 *****************************************************************************}
function sys_chdir (filename : pchar) : dword; cdecl; [public, alias : 'SYS_CHDIR'];

var
   inode : P_inode_t;

begin

	sti();

   inode := namei(filename);

   if (longint(inode) < 0) then
   {* namei() returned an error code, not a valid pointer.
    * It means that the directory hasn't been found. *}
   begin
      {$IFDEF CHDIR_WARNING}
         printk('VFS (chdir): no inode returned by namei()\n', []);
      {$ENDIF}
      result := -ENOENT;
      exit;
   end;

   if not IS_DIR(inode) then
   begin
      free_inode(inode);
      result := -ENOTDIR;
   end;

   free_inode(current^.pwd);
   current^.pwd := inode;

   {FIXME: We have to update current^.cwd}

   result := 0;

end;



{******************************************************************************
 * sys_fchdir
 *
 * Changes the current working directory.
 *****************************************************************************}
function sys_fchdir (fd : dword) : dword; cdecl; [public, alias : 'SYS_FCHDIR'];
begin

	sti();

   if (fd >= OPEN_MAX) or (current^.file_desc[fd] = NIL) then
   begin
      printk('sys_fchdir: fd %d is not a valid fd\n', [fd]);
      result := -EBADF;
      exit;
   end;

   if (not IS_DIR(current^.file_desc[fd]^.inode)) then
   begin
      printk('sys_fchdir: fd %d is not a directory\n', [fd]);
      result := -ENOTDIR;
      exit;
   end;

   free_inode(current^.pwd);
   current^.file_desc[fd]^.inode^.count += 1;
   current^.pwd := current^.file_desc[fd]^.inode;

   {FIXME: il faut updater current^.cwd}

   result := 0;

end;



{******************************************************************************
 * sys_access
 *
 * FIXME: sys_access always succeed if the file exists.
 *****************************************************************************}
function sys_access (filename : pchar ; mode : dword) : dword; cdecl; [public, alias : 'SYS_ACCESS'];

var
   inode : P_inode_t;

begin

   {$IFDEF DEBUG_SYS_ACCESS}
      printk('Welcome in sys_access (%s, %h)\n', [filename, mode]);
   {$ENDIF}

	sti();

   if (mode and (not 7)) <> 0 then
   begin
      result := -EINVAL;
      exit;
   end;

   inode := namei(filename);

   if (longint(inode) < 0) then
   {* namei() returned an error code, not a valid pointer.
    * It means that the file hasn't been found *}
   begin
      {$IFDEF DEBUG_SYS_ACCESS}
         printk('sys_access: no inode returned by namei()\n', []);
      {$ENDIF}
      result := longint(inode);
      exit;
   end;

   {$IFDEF SYS_ACCESS_WARNING}
      printk('WARNING: sys_access %s (mode=%h)\n', [filename, mode]);
   {$ENDIF}

   free_inode(inode);

   result := 0;

end;



{*******************************************************************************
 * sys_chmod
 *
 ******************************************************************************}
function sys_chmod (filename : pchar ; mode : dword) : dword; cdecl; [public, alias : 'SYS_CHMOD'];

var
   inode : P_inode_t;

begin

	{$IFDEF DEBUG_SYS_CHMOD}
		printk('sys_chmod (%d): %s (mode=%h4)\n', [current^.pid, filename, mode]);
	{$ENDIF}

	sti();

	{* Check 'mode' value *}
	if (mode > $8ff) then
	begin
		{$IFDEF DEBUG_SYS_CHMOD}
			printk('sys_chmod (%d): mode has a bad value (%h4)\n', [current^.pid, mode]);
		{$ENDIF}
		result := -EINVAL;
		exit;
	end;

	{* Check if the file exists *}
   inode := namei(filename);

   if (longint(inode) < 0) then
   {* namei() returned an error code, not a valid pointer.
    * It means that the file hasn't been found *}
   begin
      {$IFDEF DEBUG_SYS_CHMOD}
         printk('sys_chmod (%d): no inode returned by namei()\n', [current^.pid]);
      {$ENDIF}
      result := longint(inode);
      exit;
   end;

	if (inode^.uid <> current^.uid) and (current^.uid <> 0) then
	begin
		{$IFDEF DEBUG_SYS_CHMOD}
			printk('sys_chmod (%d): permission denied\n', [current^.pid]);
		{$ENDIF}
		free_inode(inode);
		result := -EPERM;
		exit;
	end;

	{$IFDEF DEBUG_SYS_CHMOD}
		printk('sys_chmod (%d): %h4 -> ', [current^.pid, inode^.mode]);
	{$ENDIF}

	inode^.mode := mode or (inode^.mode and IFMT);

	{$IFDEF DEBUG_SYS_CHMOD}
		printk('%h4\n', [current^.pid, inode^.mode]);
	{$ENDIF}

	free_inode(inode);

	result := 0;

end;



{*******************************************************************************
 * create
 *
 * This function is called by sys_open() when a file does not exist and the
 * O_CREATE flag is set.
 *
 * Output : pointer to the newly created inode or an error code
 ******************************************************************************}
function create (dir : P_inode_t ; path : pchar ; fd, flags, mode : dword) : P_inode_t;

var
   new_inode : P_inode_t;

begin

   {$IFDEF DEBUG_CREATE}
      printk('create: PATH=%s dir=%d  flags=%h mode=%h\n', [path, dir^.ino, flags, mode]);
   {$ENDIF}

   lock_inode(dir);

   { Can we write in 'dir' }
   if (not access_rights_ok(O_WRONLY, dir)) then
   begin
      result := -EACCES;
      unlock_inode(dir);
      exit;
   end;

   if (dir^.op = NIL) or (dir^.op^.create = NIL) then
   begin
      printk('create (%d): create() operation not defined for inode %d\n', [current^.pid, dir^.ino]);
      result := -EACCES;   { FIXME: another error code ??? }
      unlock_inode(dir);
      exit;
   end;

   mode := mode and $1FF and (not current^.umask);

   new_inode := dir^.op^.create(dir, path, mode);

   if (longint(new_inode) < 0) then
   begin
      result := new_inode;
      unlock_inode(dir);
      exit;
   end;

   unlock_inode(dir);

   result := new_inode;

end;



end.
