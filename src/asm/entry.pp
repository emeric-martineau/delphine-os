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

{$I process.inc}

procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;
function  sys_dup (fildes : dword) : dword; external;
function  sys_exec (path : pointer ; arg : array of const) : dword; external;
procedure sys_exit (status : dword); external;
function  sys_fork : dword; external;
function  sys_getpid : dword; external;
function  sys_getuid : dword; cdecl; external;
function  sys_ioctl(fd, req : dword ; argp : pointer) : dword; cdecl; external;
function  sys_lseek (fd, offset, whence : dword) : dword; external;
procedure sys_mount_root; external;
function  sys_open (path : string ; flags, mode : dword) : dword; cdecl; external;
function  sys_read (fd : dword ; buffer : pointer ; count : dword) : dword; external;
function  sys_time : dword; external;
function  sys_waitpid (pid : dword ; stat_loc : pointer ; options : dword) : dword; cdecl; external;
function  sys_write (fd : dword ; buffer : pointer ; count : dword) : dword; external;


procedure bad_syscall;
procedure system_call;


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


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
procedure bad_syscall; [public, alias : 'BAD_SYSCALL'];

var
   nb : dword;

begin

   asm
      shr   eax, 2
      mov   nb , eax
   end;

   printk('\nSystem call %d not implemented !!! (PID=%d)\n', [nb, current^.pid]);
   panic('');

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
   dd SYS_MOUNT_ROOT    { System call 0 }
   dd SYS_EXIT          { System call 1 (exit) }
   dd SYS_FORK
   dd SYS_READ
   dd SYS_WRITE
   dd SYS_OPEN          { System call 5 }
   dd BAD_SYSCALL       { (close) }
   dd SYS_WAITPID       { (waitpid) }
   dd BAD_SYSCALL       { (creat) }
   dd BAD_SYSCALL       { (link) }
   dd BAD_SYSCALL       { System call 10 (unlink) }
   dd SYS_EXEC          {  }
   dd BAD_SYSCALL       { (chdir) }
   dd SYS_TIME          { (time) }
   dd BAD_SYSCALL       { (mknod) }
   dd BAD_SYSCALL       { System call 15 (chmod) }
   dd BAD_SYSCALL       { (lchown) }
   dd BAD_SYSCALL       { (break) }
   dd BAD_SYSCALL       { (oldstat) }
   dd SYS_LSEEK         { }
   dd SYS_GETPID        { System call 20 }
   dd BAD_SYSCALL       { (mount) }
   dd BAD_SYSCALL       { (umount) }
   dd BAD_SYSCALL       { (setuid) }
   dd SYS_GETUID        { (getuid) }
   dd BAD_SYSCALL       { System call 25 (stime) }
   dd BAD_SYSCALL       { (ptrace) }
   dd BAD_SYSCALL       { (alarm) }
   dd BAD_SYSCALL       { (oldfstat) }
   dd BAD_SYSCALL       { (pause) }
   dd BAD_SYSCALL       { System call 30 (utime) }
   dd BAD_SYSCALL       { (stty) }
   dd BAD_SYSCALL       { (gtty) }
   dd BAD_SYSCALL       { (access) }
   dd BAD_SYSCALL       { (nice) }
   dd BAD_SYSCALL       { System call 35 (ftime) }
   dd BAD_SYSCALL       { (sync) }
   dd BAD_SYSCALL       { (kill) }
   dd BAD_SYSCALL       { (rename) }
   dd BAD_SYSCALL       { (mkdir) }
   dd BAD_SYSCALL       { System call 40 (rmdir) }
   dd SYS_DUP           { }
   dd BAD_SYSCALL       { (pipe) }
   dd BAD_SYSCALL       { (times) }
   dd BAD_SYSCALL       { (prof) }
   dd BAD_SYSCALL       { System call 45 (brk) }
   dd BAD_SYSCALL       { (setgid) }
   dd BAD_SYSCALL       { (getgid) }
   dd BAD_SYSCALL       { (signal) }
   dd BAD_SYSCALL       { (geteuid) }
   dd BAD_SYSCALL       { System call 50 (getegid) }
   dd BAD_SYSCALL       { (acct) }
   dd BAD_SYSCALL       { (umount2) }
   dd BAD_SYSCALL       { (lock) }
   dd SYS_IOCTL         { (ioctl) }
   dd BAD_SYSCALL       { System call 55 (fcntl) }
   dd BAD_SYSCALL       { (mpx) }
   dd BAD_SYSCALL       { (setpgid) }
   dd BAD_SYSCALL       { (ulimit) }
   dd BAD_SYSCALL       { (oldolduname) }
   dd BAD_SYSCALL       { System call 60 (umask) }
   dd BAD_SYSCALL       { (chroot) }
   dd BAD_SYSCALL       { (ustat) }
   dd BAD_SYSCALL       { (dup2) }
   dd BAD_SYSCALL       { (getppid) }
   dd BAD_SYSCALL       { System call 65 (getpgrp) }
   dd BAD_SYSCALL       { (setsid) }
   dd BAD_SYSCALL       { (sigaction) }
   dd BAD_SYSCALL       { (sgetmask) }
   dd BAD_SYSCALL       { (ssetmask) }
   dd BAD_SYSCALL       { System call 70 (setreuid) }
   dd BAD_SYSCALL       { (setregid) }
   dd BAD_SYSCALL       { (sigsuspend) }
   dd BAD_SYSCALL       { (sigpending) }
   dd BAD_SYSCALL       { (sethostname) }
   dd BAD_SYSCALL       { System call 75 (setrlimit) }
   dd BAD_SYSCALL       { (getrlimit) }
   dd BAD_SYSCALL       { (getrusage) }
   dd BAD_SYSCALL       { (gettimeofday) }
   dd BAD_SYSCALL       { (settimeofday) }
   dd BAD_SYSCALL       { System call 80 (getgroups) }
   dd BAD_SYSCALL       { (setgroups) }
   dd BAD_SYSCALL       { (select) }
   dd BAD_SYSCALL       { (symlink) }
   dd BAD_SYSCALL       { (oldlstat) }
   dd BAD_SYSCALL       { System call 85 (readlink) }
   dd BAD_SYSCALL       { (uselib) }
   dd BAD_SYSCALL       { (swapon) }
   dd BAD_SYSCALL       { (reboot) }
   dd BAD_SYSCALL       { (readdir) }
   dd BAD_SYSCALL       { System call 90 (mmap) }
   dd BAD_SYSCALL       { (munmap) }
   dd BAD_SYSCALL       { (truncate) }
   dd BAD_SYSCALL       { (ftruncate) }
   dd BAD_SYSCALL       { (fchmod) }
   dd BAD_SYSCALL       { System call 95 (fchown) }
   dd BAD_SYSCALL       { (getpriority) }
   dd BAD_SYSCALL       { (setpriority) }
   dd BAD_SYSCALL       { (profil) }
   dd BAD_SYSCALL       { (statfs) }
   dd BAD_SYSCALL       { System call 100 (fstatfs) }
   dd BAD_SYSCALL       { (ioperm) }
   @MAX_NR_SYSCALLS:
      dd 101
end;



begin
end.
