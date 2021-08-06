{******************************************************************************
 *  exit.pp
 *
 *  Exit() system call management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 06/03/2003 - GaLi - Initial version
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


unit exit_;


INTERFACE


{$I process.inc}
{$I sched.inc}


{* Local macros *}


{* External procedure and functions *}

procedure del_from_runqueue (task : P_task_struct); external;
procedure free_gdt_entry (index : dword); external;
procedure kfree_s (addr : pointer ; size : dword); external;
procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_addr : pointer); external;
procedure schedule; external;
procedure unload_page_table (pt : P_pte_t); external;


{* External variables *}


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure sys_exit (status : dword); cdecl;



var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';



IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * sys_exit
 *
 * FIXME: care about interrupts (may be...)
 *****************************************************************************}
procedure sys_exit (status : dword); cdecl; [public, alias : 'SYS_EXIT'];
begin

   printk('sys_exit called by PID %d with status %d\n', [current^.pid, status]);

   del_from_runqueue(current);

   unload_page_table(current^.page_table);
   push_page(current^.page_table);
   push_page(current^.cr3);
   kfree_s(current^.tss, sizeof(tss_struct));

   free_gdt_entry(current^.tss_entry);
   current^.tss_entry := 0;

   current^.state := TASK_ZOMBIE;

   schedule;

end;



begin
end.
