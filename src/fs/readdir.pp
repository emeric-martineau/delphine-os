{******************************************************************************
 *  readdir.pp
 *
 *  Directories management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 16/05/2003 - GaLi - Initial version
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


unit readdir;


INTERFACE


{* Headers *}

{$I process.inc}
{$I errno.inc}
{$I fs.inc}


{* Local macros *}

{DEFINE DEBUG_SYS_GETDENTS}

{* External procedure and functions *}

function  IS_DIR (inode : P_inode_t) : boolean; external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

function sys_getdents (fd : dword ; dirent : pointer ; count : dword) : dword; cdecl;


IMPLEMENTATION

{$I inline.inc}

{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * sys_getdents
 *
 * FIXME: don't know the result value.
 *****************************************************************************}
function sys_getdents (fd : dword ; dirent : pointer ; count : dword) : dword; cdecl; [public, alias : 'SYS_GETDENTS'];

var
   fichier : P_file_t;

begin

	sti();

   {$IFDEF DEBUG_SYS_GETDENTS}
      print_bochs('sys_getdents: fd=%d  dirent=%h  count=%d\n', [fd, dirent, count]);
   {$ENDIF}

   fichier := current^.file_desc[fd];

   if (fd >= OPEN_MAX) or (fichier = NIL) then
   begin
      print_bochs('sys_getdents: fd %d is not a valid fd\n', [fd]);
      result := -EBADF;
      exit;
   end;

   if (not IS_DIR(fichier^.inode)) then
   begin
      print_bochs('sys_getdents: fd %d is not a directory\n', [fd]);
      result := -ENOTDIR;
      exit;
   end;

   result := -ENOSYS;   { FIXME: another error code ? }

   if ((fichier^.op <> NIL) and (fichier^.op^.read <> NIL)) then
        result := fichier^.op^.read(fichier, dirent, count)
   else
        print_bochs('sys_getdents: no read operation defined for fd %d\n', [fd]);

   {$IFDEF DEBUG_SYS_GETDENTS}
      print_bochs('sys_getdents: result=%d\n', [result]);
   {$ENDIF}

end;



begin
end.
