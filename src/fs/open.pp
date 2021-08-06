{******************************************************************************
 *  open.pp
 *
 *  open(), access(), chdir() and close() system calls implementation
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
{DEFINE DEBUG_SYS_OPEN}
{DEFINE DEBUG_SYS_CLOSE}
{DEFINE DEBUG_ACCESS}
{DEFINE ACCESS_WARNING}
{DEFINE OPEN_WARNING}
{DEFINE CLOSE_WARNING}
{DEFINE CHDIR_WARNING}


{$I errno.inc}
{$I fs.inc}
{$I process.inc}
{$I time.inc}


{* External procedures and functions definition *}
function  access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; external;
procedure free_inode (inode : P_inode_t); external;
procedure interruptible_wake_up (p : PP_wait_queue); external;
function  IS_DIR (inode : P_inode_t) : boolean; external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
function  namei (path : pchar) : P_inode_t; external;
procedure printk (format : string ; args : array of const); external;


{* External variables definition *}
var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables definition *}


{* Unit procedures and functions definition *}
function  create_file (path : pchar ; fd, flags, mode : dword) : P_inode_t;
function  sys_access (filename : pchar ; mode : dword) : dword; cdecl;
function  sys_chdir (filename : pchar) : dword; cdecl;
function  sys_close (fd : dword) : dword; cdecl;
function  sys_fchdir (fd : dword) : dword; cdecl;
function  sys_open (path : pchar ; flags, mode : dword) : dword; cdecl;
function  sys_utime (path : pchar ; times : P_utimbuf) : dword; cdecl;


IMPLEMENTATION


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
   fd, res : dword;
   fichier : P_file_t;
   inode   : P_inode_t;

begin

   {$IFDEF DEBUG_SYS_OPEN}
      printk('Welcome in sys_open (%s) flags=%h mode=%h\n', [path, flags, mode]);
   {$ENDIF}

   asm
      sti   { Interrupts on }
   end;

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

      {$IFDEF DEBUG_SYS_OPEN}
         printk('sys_open (%d): going to call namei(path)...', [current^.pid]);
      {$ENDIF}

      inode := namei(path);

      {$IFDEF DEBUG_SYS_OPEN}
         printk('   OK\n', []);
      {$ENDIF}

      if (longint(inode) < 0) then
      {* namei() returned an error code, not a valid pointer.
       * It means that the file hasn't been found and that we have to
       * create it *}
      begin
         {$IFDEF OPEN_WARNING}
            printk('sys_open (%d): no inode returned by namei (%d)\n', [current^.pid, inode]);
	 {$ENDIF}
	 {$IFDEF DEBUG_SYS_OPEN}
	    printk('sys_open (%d): no inode returned by namei (%d)\n', [current^.pid, inode]);
	 {$ENDIF}
	 if (flags and O_CREAT) = O_CREAT then
	 begin
	    inode := create_file(path, fd, flags, mode);
	    if (longint(inode) <> 0) then
	    begin
	       kfree_s(fichier, sizeof(file_t));
	       result := longint(inode);
	       exit;
	    end;
	 end
	 else
	 begin
	    kfree_s(fichier, sizeof(file_t));
	    result := longint(inode);
	    exit;
	 end;
      end;

      {$IFDEF DEBUG_SYS_OPEN}
         printk('sys_open: %s has inode number %d (flags=%h)\n', [path, inode^.ino, flags]);
      {$ENDIF}

      { Check if "inode" is not a directory }
{      if IS_DIR(inode) and ((flags and O_DIRECTORY) <> O_DIRECTORY) then
      begin
         printk('sys_open: trying to open a directory without O_DIRECTORY flag\n', []);
         kfree_s(fichier, sizeof(file_t));
	 free_inode(inode);
         result := -EISDIR;
	 exit;
      end;}

      if not (access_rights_ok(flags, inode)) then
      begin
	 printk('sys_open: permission denied\n', []);
	 kfree_s(fichier, sizeof(file_t));
	 free_inode(inode);
	 result := -EACCES;
	 exit;
      end;

      { Access rights are ok, we fill 'fichier' }
      fichier^.inode := inode;
      fichier^.count := 1;
      fichier^.pos   := 0;
      fichier^.uid   := current^.uid;
      fichier^.gid   := current^.gid;
      fichier^.mode  := 0;   { FIXME: don't know what to put here (when you don't create the file) }
      fichier^.flags := flags;
      fichier^.op    := inode^.op^.default_file_ops;
      
      { Can we call file-specific open() function ? }
      if ((fichier^.op <> NIL) and (fichier^.op^.open <> NIL)) then
           fichier^.op^.open(inode, fichier);

      current^.file_desc[fd] := fichier;
      
      if (fd = 1) and (inode^.rdev_maj = 4) then   { FIXME: do this in drivers/char/tty.pp }
          current^.tty := inode^.rdev_min;
      
      result := fd;  { OK, stop here (that was not funny) }
      {$IFDEF DEBUG_SYS_OPEN}
         printk('sys_open (%d): fd %d (%h) is opened (%s)\n', [current^.pid, fd, current^.file_desc[fd], path]);
      {$ENDIF}
   end
   else
   { No more free file descriptors }
   begin
      printk('sys_open: cannot open %s (no file descriptor)\n', [path]);
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
      printk('sys_close (%d): fd=%d (%h) ', [current^.pid, fd, current^.file_desc[fd]]);
   {$ENDIF}

   asm
      sti
   end;

   fichier := current^.file_desc[fd];

   if ((fichier = NIL) or (fd >= OPEN_MAX)) then
   begin
      {$IFDEF DEBUG_SYS_CLOSE}
         printk('\nsys_close: fd #%d is not opened. Can''t close it  :-)\n', [fd]);
      {$ENDIF}
      result := -EBADF;
      exit;
   end;

   {$IFDEF DEBUG_SYS_CLOSE}
      printk(' f_count: %d  i_count: %d\n', [fichier^.count, fichier^.inode^.count]);
   {$ENDIF}

   free_inode(fichier^.inode);

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
      kfree_s(fichier, sizeof(file_t));
   end;

   current^.file_desc[fd] := NIL;

   if (fd = 1) then   { FIXME: do this in drcivers/char/tty.pp }
       current^.tty := $FF;

end;



{******************************************************************************
 * sys_utime
 *
 * FIXME: does nothing   :-)
 *****************************************************************************}
function sys_utime (path : pchar ; times : P_utimbuf) : dword; cdecl; [public, alias : 'SYS_UTIME'];
begin

   printk('Welcome in sys_utime: %c%s  %h\n', [path[0], path, times]);

   result := -ENOTSUP;

end;



{******************************************************************************
 * sys_chdir
 *
 *****************************************************************************}
function sys_chdir (filename : pchar) : dword; cdecl; [public, alias : 'SYS_CHDIR'];

var
   inode : P_inode_t;

begin

   asm
      sti
   end;

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
 *****************************************************************************}
function sys_fchdir (fd : dword) : dword; cdecl; [public, alias : 'SYS_FCHDIR'];
begin

   asm
      sti
   end;

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

   if (current^.pwd <> current^.root) then
       free_inode(current^.pwd);

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

   {$IFDEF DEBUG_ACCESS}
      printk('Welcome in sys_access (%s, %h)\n', [filename, mode]);
   {$ENDIF}

   asm
     sti
   end;

   if (mode and (not 7)) <> 0 then
   begin
      result := -EINVAL;
      exit;
   end;

   inode := namei(filename);

   if (longint(inode) < 0) then
   {* namei() returned an error code, not a valid pointer.
    * It means that the file hasn't been found and that we have to
    * create it (FIXME: not implemented) *}
   begin
      {$IFDEF DEBUG_ACCESS}
         printk('sys_access: no inode returned by namei()\n', []);
      {$ENDIF}
      result := longint(inode);
      exit;
   end;

   {$IFDEF ACCESS_WARNING}
      printk('WARNING: sys_access %s (mode=%h)\n', [filename, mode]);
   {$ENDIF}

   free_inode(inode);

   result := 0;

end;



{******************************************************************************
 * create_file
 *
 * This function is called by sys_open() when a file does not exist and the
 * O_CREATE flag is set.
 *
 * Output : pointer to the newly created inode or an error code
 *****************************************************************************}
function create_file (path : pchar ; fd, flags, mode : dword) : P_inode_t;
begin

   printk('create_file (%d): %s (fd=%d, flags=%h, mode=%h\n', [current^.pid, path, fd, flags, mode]);

   result := -EPERM;

end;



end.
