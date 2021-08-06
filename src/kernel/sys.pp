{******************************************************************************
 *  sys.pp
 *
 *  Simple system calls management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 10/05/2003 - GaLi - Initial version
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


unit sys;


INTERFACE


{* Headers *}

{$I errno.inc}
{$I process.inc}
{$I sched.inc}
{$I utsname.inc}


{* Local macros *}


{* External procedure and functions *}

procedure printk (format : string ; args : array of const); external;
procedure schedule; external;


{* External variables *}

var
   current    : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

function  sys_pause : dword; cdecl;
function  sys_uname (name : P_utsname) : dword; cdecl;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * sys_uname
 *
 *****************************************************************************}
function sys_uname (name : P_utsname) : dword; cdecl; [public, alias : 'SYS_UNAME'];
begin

   if (name = NIL) then
       result := -EINVAL
   else
       begin
          name^.sysname[1]     := 'D';
	  name^.sysname[2]     := 'e';
	  name^.sysname[3]     := 'l';
	  name^.sysname[4]     := 'p';
	  name^.sysname[5]     := 'h';
	  name^.sysname[6]     := 'i';
	  name^.sysname[7]     := 'n';
	  name^.sysname[8]     := 'e';
	  name^.sysname[9]     := 'O';
	  name^.sysname[10]    := 'S';
	  name^.sysname[11]    := #0;
	  name^.nodename[1]    := 'l';
	  name^.nodename[2]    := 'o';
	  name^.nodename[3]    := 'c';
	  name^.nodename[4]    := 'a';
	  name^.nodename[5]    := 'l';
	  name^.nodename[6]    := 'h';
	  name^.nodename[7]    := 'o';
	  name^.nodename[8]    := 's';
	  name^.nodename[9]    := 't';
	  name^.nodename[10]   := #0;
	  name^.release[1]     := 'a';
	  name^.release[2]     := 'l';
	  name^.release[3]     := 'p';
	  name^.release[4]     := 'h';
	  name^.release[5]     := 'a';
	  name^.release[6]     := #0;
	  name^.version[1]     := '0';
	  name^.version[2]     := '.';
	  name^.version[3]     := '0';
	  name^.version[4]     := '.';
	  name^.version[5]     := '0';
	  name^.version[6]     := 'e';
	  name^.version[7]     := #0;
	  name^.machine[1]     := 'x';
	  name^.machine[2]     := '8';
	  name^.machine[3]     := '6';
	  name^.machine[4]     := #0;
	  name^.domainname[1]  := #0;
          result := 0;
       end;

end;



{******************************************************************************
 * sys_pause
 *
 *****************************************************************************}
function sys_pause : dword; cdecl; [public, alias : 'SYS_PAUSE'];
begin

   current^.state := TASK_INTERRUPTIBLE;
   schedule();
   result := -EINTR;

end;



begin
end.
