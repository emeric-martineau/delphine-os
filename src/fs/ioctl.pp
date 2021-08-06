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


{DEFINE DEBUG}


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



{******************************************************************************
 * sys_ioctl
 *
 *****************************************************************************}
function sys_ioctl(fd, req : dword ; argp : pointer) : dword; cdecl; [public, alias : 'SYS_IOCTL'];

var
   fichier : P_file_t;

begin

   asm
      sti   { Put interrupts on }
   end;

   {$IFDEF DEBUG}
      printk('Welcome in ioctl... (%d, %h4, %h)\n', [fd, req, argp]);
   {$ENDIF}

   if (fd >= OPEN_MAX) then
       begin
	     printk('VFS (ioctl): fd number is too big (%d)\n', [fd]);
	     result := -EBADF;
	     exit;
       end;

   fichier := current^.file_desc[fd];

   if (fichier = NIL) then
       begin
	     printk('VFS (ioctl): file isn''t opened (%d)\n', [fd]);
	     result := -EBADF;
	     exit;
       end;
   if (fichier^.inode = NIL) then
       begin
          printk('VFS (ioctl): inode not defined for fd %d\n', [fd]);
	  result := -EBADF;
	  exit;
       end;
   if (fichier^.op = NIL) then
       begin
          printk('VFS (ioctl): file operations not defined for fd %d\n', [fd]);
	  result := -1;
	  exit;
       end;
   if (fichier^.op^.ioctl = NIL) then
       begin
          printk('VFS (ioctl): ioctl operation not defined for fd %d\n', [fd]);
	  result := -1;
	  exit;
       end;

   result := fichier^.op^.ioctl(fichier, req, argp);

end;



begin
end.
