{******************************************************************************
 *  socket.pp
 *
 *  socketcall system call management. (bash 1.14 uses this system call)
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 04/06/2003 - GaLi - Initial version
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


unit socket;


INTERFACE


{* Headers *}

{$I errno.inc}
{$I process.inc}
{$I socket.inc}

{* Local macros *}


{* External procedure and functions *}

procedure memcpy (src, dest : pointer ; size : dword); external;
procedure printk (format : string ; args : array of const); external;

{* External variables *}


{* Exported variables *}


{* Procedures and functions defined in this file *}

function  sys_getpeername (fd : dword ; name : P_sockaddr ; namelen : pointer) : dword; cdecl;
function  sys_socketcall (call : longint ; args : pointer) : dword; cdecl;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * sys_getpeername
 *
 *****************************************************************************}
function sys_getpeername (fd : dword ; name : P_sockaddr ; namelen : pointer) : dword; cdecl; [public, alias : 'SYS_GETPEERNAME'];
begin

   {printk('Welcome in sys_getpeername (%d, %h, %d)\n', [fd, name, longint(namelen^)]);}
   result := -ENOTSOCK;

end;



{******************************************************************************
 * sys_socketcall
 *
 * INPUT:   call -> determines which socket function to invoke
 *          args -> points to a block containing the actual arguments.
 *
 * This function is a common kernel entry point for the socket system calls.
 *
 * NOTE: This call is specific to Linux, and should not be used in programs
 *       intended to be portable. (so, the dietlibc is not portable...)
 *****************************************************************************}
function sys_socketcall (call : longint ; args : pointer) : dword; cdecl; [public, alias : 'SYS_SOCKETCALL'];

var
   a   : array [0..5] of dword;
   res : dword;

begin

   printk('WARNING: sys_socketcall always failed\n', []);

   asm
      sti
   end;

   if (call < 1) or (call > NSYS_RECVMSG) then
   begin
      result := -EINVAL;
      exit;
   end;

   if (longint(args) < BASE_ADDR) then
   begin
      result := -EFAULT;
      exit;
   end;

   res := -ENOSYS;

   memcpy(args, @a, nargs[call] * 4);

   case (call) of
      NSYS_GETPEERNAME: res := sys_getpeername(a[0], pointer(a[1]), pointer(a[2]));
      else
      	 printk('WARNING sys_socketcall called with call=%d\n', [call]);
   end;

   result := res;

end;



begin
end.
