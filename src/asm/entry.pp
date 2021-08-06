{******************************************************************************
 * entry.pp
 *
 * This file defines the system calls entry point
 *
 * Copyleft 2002 GaLi
 *
 * version 0.0 - ??/04/2002 - GaLi - Initial version
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope tha it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU Genral Public License along
 * with this program; if not, write to the Free Software Foundation,
 * Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit entry;


INTERFACE


function  sys_dup (fildes : dword) : dword; external;
function  sys_exec (path : pointer ; arg : array of const) : dword; external;
function  sys_write (fd : dword ; buffer : pointer ; count : dword) : dword; external;
function  sys_read (fd : dword ; buffer : pointer ; count : dword) : dword; external;
function  sys_fork : dword; external;
function  sys_get_pid : dword; external;
function  sys_lseek (fd, offset, whence : dword) : dword; external;
function  sys_open (path : string ; flags, mode : dword) : dword; cdecl; external;
procedure sys_printf (format : string ; args : array of const); external;
procedure sys_mount_root; external;
procedure printk (format : string ; args : array of const); external;
procedure print_registers; external;


procedure bad_syscall;
procedure system_call;



IMPLEMENTATION



{******************************************************************************
 * bad_syscall
 *
 * Input  : EAX contains the system call number
 * Output : None
 *
 * This procedure is called when a system call doesn't exist or isn't
 * implemented
 *****************************************************************************}
procedure bad_syscall;

var
   nb : dword;

begin

   asm
      mov   nb , eax
   end;

   printk('System call %d not implemented !!!\n', [nb]);

end;



{******************************************************************************
 * system_call
 *
 * Input  : Registers are set differently for each system call
 *
 * Output : EAX contains an error code used to go back to user mode.
 *
 * This procedure is called each time a process use the 'INT $30' instruction
 *
 * We are in kernel mode here.
 *
 *
 * NOTE: I think we'll have to put the errno management here.
 *****************************************************************************}
procedure system_call; assembler; [public, alias : 'SYSTEM_CALL'];

asm

   push  eax   
   push  es
   push  ds
   push  ebp
   push  edi
   push  esi
   push  edx
   push  ecx
   push  ebx
   mov   edx, $18
   mov   ds , dx
   mov   es , dx

   cmp   eax, @MAX_NR_SYSCALLS
   jg    @error

   shl   eax, 2
   lea   edi, @syscall_table
   mov   ebx, dword [edi + eax]
   call  ebx

   jmp @ret_to_user_mode

   @error:
      call bad_syscall
      mov  eax, -38  { Error code }

   @ret_to_user_mode:
      mov   dword [esp+32], eax
      pop   ebx
      pop   ecx
      pop   edx
      pop   esi
      pop   edi
      pop   ebp
      pop   ds
      pop   es
      pop   eax
      iret

   @syscall_table:
   dd PRINT_REGISTERS   { System call 0 }
   dd SYS_MOUNT_ROOT    { System call 1 ... }
   dd SYS_FORK
   dd SYS_READ
   dd SYS_WRITE
   dd SYS_GET_PID       { System call 5 }
   dd SYS_OPEN
   dd SYS_EXEC
   dd SYS_LSEEK
   dd SYS_DUP
   dd SYS_PRINTF

   @MAX_NR_SYSCALLS:
      dd 10
end;



begin
end.
