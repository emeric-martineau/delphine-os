{******************************************************************************
 *  stat.pp
 *
 *  stat() system call managament
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 14/05/2003 - GaLi - Initial version
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


unit stat;


INTERFACE


{DEFINE DEBUG_SYS_STAT}
{DEFINE DEBUG_SYS_FSTAT}
{DEFINE DEBUG_SYS_STAT64}


{* Headers *}

{$I errno.inc}
{$I fs.inc}
{$I process.inc}
{$I stat.inc}


{* External procedure and functions *}

function  alloc_inode : P_inode_t; external;
procedure free_inode (inode : P_inode_t); external;
procedure kfree_s (addr : pointer ; size : dword); external;
function  namei (path : pchar) : P_inode_t; external;
procedure printk (format : string ; args : array of const); external;


{* External variables *}
var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

function  sys_fstat (fd : dword ; statbuf : P_stat_t) : dword; cdecl;
function  sys_readlink (path : pchar ; buf : pchar ; bufsiz : dword) : dword; cdecl;
function  sys_stat (filename : pchar ; statbuf : P_stat_t) : dword; cdecl;
function  sys_stat64 (filename : pchar ; statbuf : P_stat64_t ; flags : dword) : dword; cdecl;


IMPLEMENTATION

{$I inline.inc}

{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}




{******************************************************************************
 * sys_fstat
 *
 *****************************************************************************}
function sys_fstat (fd : dword ; statbuf : P_stat_t) : dword; cdecl; [public, alias : 'SYS_FSTAT'];

var
   fichier : P_file_t;
   inode   : P_inode_t;

begin

   fichier := current^.file_desc[fd];
   if ((fichier = NIL) or (fd >= OPEN_MAX)) then
   begin
      result := -EBADF;
      exit;
   end;

   inode := fichier^.inode;

   if (inode = NIL) then
   begin
      printk('sys_fstat (%d) fd %d has no inode\n', [current^.pid, fd]);
      result := -EBADF;
      exit;
   end;

   {$IFDEF DEBUG_SYS_FSTAT}
      printk('sys_fstat: fd=%d  mode=%h\n', [fd, inode^.mode]);
   {$ENDIF}

   statbuf^.st_dev     := (inode^.dev_maj shl 8) + inode^.dev_min;
   statbuf^.st_ino     := inode^.ino;
   statbuf^.st_mode    := inode^.mode;    { FIXME: I don't know if there is some changes to do to inode^.mode
                                                   before setting statbuf^.st_mode }
   statbuf^.st_nlink   := inode^.nlink;
   statbuf^.st_uid     := inode^.uid;
   statbuf^.st_gid     := inode^.gid;
   statbuf^.st_rdev    := (inode^.rdev_maj shl 8) + inode^.rdev_min;
   statbuf^.st_size    := inode^.size;
   statbuf^.st_blksize := inode^.blksize;
   statbuf^.st_blocks  := inode^.blocks;
   statbuf^.st_atime   := inode^.atime;
   statbuf^.st_mtime   := inode^.mtime;
   statbuf^.st_ctime   := inode^.ctime;

   result := 0;

end;



{******************************************************************************
 * sys_stat
 *
 *****************************************************************************}
function sys_stat (filename : pchar ; statbuf : P_stat_t) : dword; cdecl; [public, alias : 'SYS_STAT'];

var
   inode : P_inode_t;

begin

	sti();

   {$IFDEF DEBUG_SYS_STAT}
      printk('sys_stat: filename=%s\n', [filename]);
   {$ENDIF}

   inode := namei(filename);

   if (longint(inode) < 0) then
   {* namei() returned an error code, not a valid pointer.
    * It means that "filename" hasn't been found *}
   begin
      {$IFDEF DEBUG_SYS_STAT}
         printk('sys_stat: no inode returned by namei(%s) -> %d\n', [filename, longint(inode)]);
      {$ENDIF}
      result := longint(inode);
      exit;
   end;

   statbuf^.st_dev     := (inode^.dev_maj shl 8) + inode^.dev_min;
   statbuf^.st_ino     := inode^.ino;
   statbuf^.st_mode    := inode^.mode;    { FIXME: I don't know if there is some changes to do to inode^.mode
                                                   before setting statbuf^.st_mode }
   statbuf^.st_nlink   := inode^.nlink;
   statbuf^.st_uid     := inode^.uid;
   statbuf^.st_gid     := inode^.gid;
   statbuf^.st_rdev    := (inode^.rdev_maj shl 8) + inode^.rdev_min;
   statbuf^.st_size    := inode^.size;
   statbuf^.st_blksize := inode^.blksize;
   statbuf^.st_blocks  := inode^.blocks;
   statbuf^.st_atime   := inode^.atime;
   statbuf^.st_mtime   := inode^.mtime;
   statbuf^.st_ctime   := inode^.ctime;

   free_inode(inode);

   result := 0;

end;



{******************************************************************************
 * sys_stat64
 *
 * NOTE: Even Linux don't use the "flags" argument. So, I don't know why it's
 *       here (may be it will be used in the future).
 *
 * FIXME: Don't use this function !!!
 *****************************************************************************}
function sys_stat64 (filename : pchar ; statbuf : P_stat64_t ; flags : dword) : dword; cdecl; [public, alias : 'SYS_STAT64'];

var
   inode : P_inode_t;

begin

   asm
      sti
   end;

   {$IFDEF DEBUG_SYS_STAT64}
      printk('Welcome in sys_stat64 (%h, %h)\n', [statbuf, flags]);
   {$ENDIF}

   inode := namei(filename);

   if (longint(inode) < 0) then
   {* namei() returned an error code, not a valid pointer.
    * It means that "filename" hasn't been found *}
   begin
      {$IFDEF DEBUG_SYS_STAT64}
         printk('sys_stat64: no inode returned by namei(%s)\n', [filename]);
      {$ENDIF}
      result := longint(inode);
      exit;
   end;

   statbuf^.st_dev := (inode^.dev_maj shl 8) + inode^.dev_min;
   statbuf^.__st_ino   := inode^.ino;
   statbuf^.st_mode    := inode^.mode;    { FIXME: I don't know if there is some changes to do to inode^.mode
                                                   before setting statbuf^.st_mode }
   statbuf^.st_nlink   := inode^.nlink;   { FIXME: test if it's correct. inode^.nlink is a word but statbuf^.st_nlink is a dword }
   statbuf^.st_uid     := inode^.uid;
   statbuf^.st_gid     := inode^.gid;
   statbuf^.st_rdev    := (inode^.rdev_maj shl 8) + inode^.rdev_min;
   statbuf^.st_size    := inode^.size;    { FIXME: need tests. (statbuf^.st_size is a 64 bits value) }
   statbuf^.st_size2   := 0;
   statbuf^.st_blksize := inode^.blksize;
   statbuf^.st_blocks  := inode^.blocks;
   statbuf^.st_atime   := inode^.atime;
   statbuf^.st_mtime   := inode^.mtime;
   statbuf^.st_ctime   := inode^.ctime;
   statbuf^.st_ino     := inode^.ino;     { FIXME: need tests. (statbuf^.st_ino is a 64 bits value) }
   statbuf^.st_ino2    := 0;

   free_inode(inode);

   result := 0;

end;



{******************************************************************************
 * sys_readlink
 *
 * FIXME: this function does nothing for the moment !!!
 *****************************************************************************}
function sys_readlink (path : pchar ; buf : pchar ; bufsiz : dword) : dword; cdecl; [public, alias : 'SYS_READLINK'];
begin
   printk('Welcome in sys_readlink (%c%s)\n', [path[0], path]);
   result := -ENOSYS;
   exit;
end;



begin
end.
