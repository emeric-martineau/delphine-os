{******************************************************************************
 *  ioctl.pp
 *
 *  ioctl system call management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 22/02/2003 - GaLi - Initial version
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

unit ioctl;


{DEFINE DEBUG_SYS_IOCTL}


INTERFACE


{$I errno.inc}
{$I process.inc}


{* External procedure and functions *}

procedure printk (format : string ; args : array of const); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

function sys_ioctl(fd, req : dword ; argp : pointer) : dword; cdecl;



IMPLEMENTATION


{$I inline.inc}


{******************************************************************************
 * sys_ioctl
 *
 *****************************************************************************}
function sys_ioctl(fd, req : dword ; argp : pointer) : dword; cdecl; [public, alias : 'SYS_IOCTL'];

var
   fichier : P_file_t;

begin

	sti();

   fichier := current^.file_desc[fd];

   {$IFDEF DEBUG_SYS_IOCTL}
      printk('sys_ioctl (%d): fd=%d, req=%h4, argp=%h (%h)\n', [current^.pid, fd, req, argp, fichier]);
   {$ENDIF}

   if (fd >= OPEN_MAX) or (fichier = NIL) then
   begin
      result := -EBADF;
      exit;
   end;

   if (fichier^.inode = NIL) then
	begin
		printk('VFS (ioctl) PID=%d: inode not defined for fd %d\n', [current^.pid, fd]);
	   result := -EBADF;
		exit;
	end;

   if (fichier^.op = NIL) then
	begin
		printk('VFS (ioctl) PID=%d: file operations not defined for fd %d\n', [current^.pid, fd]);
		result := -1;
		exit;
	end;

   if (fichier^.op^.ioctl = NIL) then
	begin
		printk('VFS (ioctl) PID=%d: ioctl operation (req=%h) not defined for fd %d\n', [current^.pid, req, fd]);
		result := -1;
		exit;
	end;

   result := fichier^.op^.ioctl(fichier, req, argp);

end;



begin
end.
