{******************************************************************************
 *  fcntl.pp
 *
 *  fcntl system call management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 15/05/2003 - GaLi - Initial version
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


unit fcntl;


INTERFACE


{* Headers *}

{$I process.inc}
{$I errno.inc}
{$I fs.inc}

{* Local macros *}

{DEFINE DEBUG_SYS_FCNTL}
{DEFINE DEBUG_SYS_DUP}

{* External procedure and functions *}

procedure printk (format : string ; args : array of const); external;
function  sys_close (fd : dword) : dword; external;


{* External variables *}
var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

function  sys_dup (fildes : dword) : dword; cdecl;
function  sys_dup2 (fildes, fildes2 : dword) : dword; cdecl;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * dupfd
 *
 * NOTE: This function is not used for the moment
 *****************************************************************************}
function dupfd (fd, arg : dword) : dword;
begin

   if (fd >= OPEN_MAX) or (current^.file_desc[fd] = NIL) then
   begin
      result := -EBADFD;
      exit;
   end;

   if (arg >= OPEN_MAX) then
   begin
      result := -EINVAL;
      exit;
   end;

end;



{******************************************************************************
 * sys_dup2
 *
 * Duplicates an open file descriptor
 *
 * FIXME: not tested
 *****************************************************************************}
function sys_dup2 (fildes, fildes2 : dword) : dword; cdecl; [public, alias : 'SYS_DUP2'];
begin

   if (fildes >= OPEN_MAX) or (current^.file_desc[fildes] = NIL) then
   begin
      result := -EBADF;
      exit;
   end;

   if (fildes2 >= OPEN_MAX) then
   begin
      result := -EINVAL;
   end
   else
   begin
      sys_close(fildes2);
      current^.file_desc[fildes2] := current^.file_desc[fildes];
      result := fildes2;
   end;

end;



{******************************************************************************
 * sys_dup
 *
 * Duplicates an open file descriptor
 *****************************************************************************}
function sys_dup (fildes : dword) : dword; cdecl; [public, alias : 'SYS_DUP'];

var
   fd : dword;

begin

   asm
      sti
   end;

   if (fildes >= OPEN_MAX) {or (current^.file_desc[fildes] = NIL)} then
   begin
      result := -EBADF;
      exit;
   end;

   { Look for a free file descriptor }
   fd := 0;
   while (current^.file_desc[fd] <> NIL) and (fd < OPEN_MAX) do
          fd += 1;

   if (current^.file_desc[fd] = NIL) then
       { There is at least one free file descriptor }
       begin
	  current^.file_desc[fildes]^.count += 1;
	  current^.file_desc[fildes]^.inode^.count += 1;
          current^.file_desc[fd] := current^.file_desc[fildes];
          {$IFDEF DEBUG_SYS_DUP}
	     printk('sys_dup (%d): %d -> %d\n', [current^.pid, fildes, fd]);
	  {$ENDIF}
	  result := fd;
       end
   else
       begin
          printk('sys_dup (%d): too many opened files\n', [current^.pid]);
	  result := -EMFILE;
       end;

end;



{******************************************************************************
 * sys_fcntl
 *
 * FIXME: finish this function
 *****************************************************************************}
function sys_fcntl (fd, cmd, arg : dword) : dword; cdecl; [public, alias : 'SYS_FCNTL'];

var
   fichier : P_file_t;

begin

   asm
      sti
   end;

   fichier := current^.file_desc[fd];

   if ((fd >= OPEN_MAX) or (fichier = NIL)) then
   begin
      result := -EBADF;
      exit;
   end;

   case (cmd) of
      F_DUPFD: result := sys_dup(fd);
      F_GETFD: begin
                  result := (current^.close_on_exec shr fd) and 1;
      		  printk('F_GETFD (fd=%d): close_on_exec=%h\n', [fd, current^.close_on_exec]);
      	       end;
      F_SETFD: begin
      		  if (arg and 1) = 1 then   { We set the flag }
		      current^.close_on_exec := current^.close_on_exec or (1 shl fd)
		  else
		  begin   { We unset the flag }
{		     printk('F_SETFD (fd=%d, arg=%d): %h ', [fd, arg, current^.close_on_exec]);}
		     current^.close_on_exec := current^.close_on_exec and ( not (1 shl fd));
{		     printk('%h\n', [current^.close_on_exec]);}
		  end;
		  result := 0;
      	       end;
      F_GETFL: result := fichier^.flags;
      else
         printk('sys_fcntl (%d): unknown command (%h)\n', [current^.pid, cmd]);
   end;

   {$IFDEF DEBUG_SYS_FCNTL}
      printk('sys_fcntl (%d): cmd=%d, fd=%d, arg=%d -> res=%d\n', [current^.pid, cmd, fd, arg, result]);
   {$ENDIF}

end;



begin
end.
