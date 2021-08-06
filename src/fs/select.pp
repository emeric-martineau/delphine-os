{******************************************************************************
 *  select.pp
 *
 *  select() system call management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 01/10/2003 - GaLi - Initial version
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


unit select;


INTERFACE


{* Headers *}

{$I errno.inc}
{$I process.inc}
{$I time.inc}

{* Local macros *}


{* External procedure and functions *}

procedure printk (format : string ; args : array of const); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

function  sys_select (n : dword ; inp, outp, exp : pointer ; tvp : P_timeval) : dword; cdecl;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * sys_select
 *
 *****************************************************************************}
function sys_select (n : dword ; inp, outp, exp : pointer ; tvp : P_timeval) : dword; cdecl; [public, alias : 'SYS_SELECT'];
begin

   printk('sys_select (%d): n=%d inp=%h outp=%h exp=%h tvp=%h\n', [current^.pid, n, inp, outp, exp, tvp]);

   result := -ENOSYS;

end;



begin
end.
