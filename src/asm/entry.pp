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
{$I config.inc}


procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
function  signal_pending (p : P_task_struct) : dword; external;
function  sys_access (filename : pchar ; mode : dword) : dword; external;
function  sys_alarm (seconds : dword) : dword; external;
function  sys_brk (brk : dword) : dword; external;
function  sys_chdir (filename : pchar) : dword; external;
function  sys_chmod (filename : pchar ; mode : dword) : dword; external;
function  sys_close (fd : dword) : dword; external;
function  sys_dup (fildes : dword) : dword; external;
function  sys_dup2 (fildes, fildes2 : dword) : dword; external;
function  sys_exec (path : pointer ; arg : array of const) : dword; external;
procedure sys_exit (status : dword); external;
function  sys_fchdir (fd : dword) : dword; external;
function  sys_fcntl (fd, cmd, arg : dword) : dword; cdecl; external;
function  sys_fork : dword; external;
function  sys_fstat (fd : dword ; statbuf : pointer) : dword; cdecl; external;
function  sys_getcwd (buf : pchar ; size : dword) : dword; external;
function  sys_getdents (fd : dword ; dirent : pointer ; count : dword) : dword; external;
function  sys_geteuid : dword; external;
function  sys_getgid : dword; external;
function  sys_gettimeofday (tv : pointer ; tz : pointer) : dword; external;
function  sys_getpgid : dword; external;
function  sys_getpid : dword; external;
function  sys_getppid : dword; external;
function  sys_getrlimit (resource : dword ; rlim : pointer) : dword; external;
function  sys_getrusage (who : dword ; ru : pointer) : dword; external;
function  sys_getuid : dword; cdecl; external;
function  sys_ioctl(fd, req : dword ; argp : pointer) : dword; cdecl; external;
function  sys_kill (pid, sig : dword) : dword; cdecl; external;
function  sys_lseek (fd, offset, whence : dword) : dword; external;
function  sys_mmap (test : pointer) : pointer; external;
procedure sys_mount_root; external;
function  sys_mremap (addr, old_len, new_len, flags, new_addr : dword) : dword; external;
function  sys_munmap (start : pointer ; length : dword) : dword; external;
function  sys_nanosleep (rqtp, rmtp : pointer) : dword; external;
function  sys_open (path : string ; flags, mode : dword) : dword; external;
function  sys_pause : dword; external;
function  sys_pipe (fildes : pointer) : dword; cdecl; external;
function  sys_read (fd : dword ; buffer : pointer ; count : dword) : dword; external;
function  sys_readlink (path : pchar ; buf : pchar ; bufsiz : dword) : dword; external;
function  sys_reboot (magic1, magic2, cmd : dword ; arg : pointer) : dword; cdecl; external;
function  sys_rt_sigsuspend (unewset : P_sigset_t ; sigsetsize : dword) : dword; external;
function  sys_select (n : dword ; inp, outp, exp : pointer ; tvp : pointer) : dword; external;
function  sys_setpgid (pid, pgid : dword) : dword; external;
function  sys_setsid : dword; external;
function  sys_setuid (uid : dword) : dword; external;
function  sys_sigaction (sig : dword ; act, oact : pointer) : dword; external;
function  sys_sigprocmask (how : dword ; nset, oset : pointer) : dword; external;
function  sys_socketcall (call : dword ; args : pointer) : dword; external;
function  sys_stat (filename : pchar ; statbuf : pointer) : dword; cdecl; external;
function  sys_stat64 (filename : pchar ; statbuf : pointer ; flags : dword) : dword; external;
function  sys_sync : dword; external;
function  sys_time : dword; external;
function  sys_times (buffer : pointer) : dword; external;
function  sys_unlink (path : pchar) : dword; external;
function  sys_utime (path : pchar ; times : pointer) : dword; external;
function  sys_umask (cmask : dword) : dword; external;
function  sys_uname (name : pointer) : dword; external;
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
   nb, addr : dword;

begin

   asm
      shr   eax, 2
      mov   nb , eax
      mov   eax, [ebp + 44]
      mov   addr, eax
   end;

   printk('\nSystem call %d not implemented (PID=%d) addr=%h\n', [nb, current^.pid, addr]);
   panic('Missing system call');

end;



procedure start_system_call; [public, alias : 'START_SYSTEM_CALL'];
var
	nb, pid : dword;

begin

	asm
		mov nb, eax
	end;

	pid := current^.pid;

	print_bochs('%d: System call %d\n', [pid, nb]);

end;



procedure end_system_call; [public, alias : 'END_SYSTEM_CALL'];
begin
	print_bochs('End of system call\n', []);
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

	{$IFDEF DEBUG_SYSTEM_CALL}
	pushad
		call start_system_call
	popad
	{$ENDIF}

   shl   eax, 2
   lea   edi, @syscall_table
   mov   ebx, dword [edi + eax]
   call  ebx

	{$IFDEF DEBUG_SYSTEM_CALL}
	pushad
		call end_system_call
	popad
	{$ENDIF}

   jmp @ret_to_user_mode

   @error:
      shl  eax, 2
      call bad_syscall
      mov  eax, -38  { Error code (-ENOSYS) }

   @ret_to_user_mode:
      mov   dword [esp+32], eax
      
      { Check if there are pending signals }
{      mov   eax, current
      push  eax
      call  SIGNAL_PENDING
      cmp   eax, 0
      je    @no_signals     

      @no_signals:}

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
   dd SYS_EXIT
   dd SYS_FORK
   dd SYS_READ
   dd SYS_WRITE
   dd SYS_OPEN          { System call 5 }
   dd SYS_CLOSE
   dd SYS_WAITPID
   dd BAD_SYSCALL       { (creat) }
   dd BAD_SYSCALL       { (link) }
   dd SYS_UNLINK        { System call 10 }
   dd SYS_EXEC
   dd SYS_CHDIR
   dd SYS_TIME
   dd BAD_SYSCALL       { (mknod) }
   dd SYS_CHMOD			{ System call 15 }
   dd BAD_SYSCALL       { (lchown) }
   dd BAD_SYSCALL       { (break) }
   dd BAD_SYSCALL       { (oldstat) }
   dd SYS_LSEEK
   dd SYS_GETPID        { System call 20 }
   dd BAD_SYSCALL       { (mount) }
   dd BAD_SYSCALL       { (umount) }
   dd SYS_SETUID
   dd SYS_GETUID
   dd BAD_SYSCALL       { System call 25 (stime) }
   dd BAD_SYSCALL       { (ptrace) }
   dd SYS_ALARM
   dd BAD_SYSCALL       { (oldfstat) }
   dd SYS_PAUSE
   dd SYS_UTIME         { System call 30 }
   dd BAD_SYSCALL       { (stty) }
   dd BAD_SYSCALL       { (gtty) }
   dd SYS_ACCESS
   dd BAD_SYSCALL       { (nice) }
   dd BAD_SYSCALL       { System call 35 (ftime) }
   dd SYS_SYNC
   dd SYS_KILL
   dd BAD_SYSCALL       { (rename) }
   dd BAD_SYSCALL       { (mkdir) }
   dd BAD_SYSCALL       { System call 40 (rmdir) }
   dd SYS_DUP
   dd SYS_PIPE
   dd SYS_TIMES
   dd BAD_SYSCALL       { (prof) }
   dd SYS_BRK           { System call 45 }
   dd BAD_SYSCALL       { (setgid) }
   dd SYS_GETGID
   dd BAD_SYSCALL       { (signal) }
   dd SYS_GETEUID
   dd SYS_GETEUID       { System call 50 (getegid) FIXME: getegid = geteuid }
   dd BAD_SYSCALL       { (acct) }
   dd BAD_SYSCALL       { (umount2) }
   dd BAD_SYSCALL       { (lock) }
   dd SYS_IOCTL
   dd SYS_FCNTL         { System call 55 }
   dd BAD_SYSCALL       { (mpx) }
   dd SYS_SETPGID
   dd BAD_SYSCALL       { (ulimit) }
   dd BAD_SYSCALL       { (oldolduname) }
   dd SYS_UMASK         { System call 60 }
   dd BAD_SYSCALL       { (chroot) }
   dd BAD_SYSCALL       { (ustat) }
   dd SYS_DUP2
   dd SYS_GETPPID
   dd BAD_SYSCALL       { System call 65 (getpgrp) }
   dd SYS_SETSID
   dd SYS_SIGACTION
   dd BAD_SYSCALL       { (sgetmask) }
   dd BAD_SYSCALL       { (ssetmask) }
   dd BAD_SYSCALL       { System call 70 (setreuid) }
   dd BAD_SYSCALL       { (setregid) }
   dd BAD_SYSCALL       { (sigsuspend) }
   dd BAD_SYSCALL       { (sigpending) }
   dd BAD_SYSCALL       { (sethostname) }
   dd BAD_SYSCALL       { System call 75 (setrlimit) }
   dd SYS_GETRLIMIT
   dd SYS_GETRUSAGE
   dd SYS_GETTIMEOFDAY
   dd BAD_SYSCALL       { (settimeofday) }
   dd BAD_SYSCALL       { System call 80 (getgroups) }
   dd BAD_SYSCALL       { (setgroups) }
   dd BAD_SYSCALL       { (select) }
   dd BAD_SYSCALL       { (symlink) }
   dd BAD_SYSCALL       { (oldlstat) }
   dd SYS_READLINK      { System call 85 }
   dd BAD_SYSCALL       { (uselib) }
   dd BAD_SYSCALL       { (swapon) }
   dd SYS_REBOOT
   dd BAD_SYSCALL       { (readdir) }
   dd SYS_MMAP          { System call 90 }
   dd SYS_MUNMAP
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
   dd SYS_SOCKETCALL
   dd BAD_SYSCALL       { (syslog) }
   dd BAD_SYSCALL       { (setitimer) }
   dd BAD_SYSCALL       { System call 105 (getitimer) }
   dd SYS_STAT
   dd SYS_STAT          { (lstat) FIXME: SYS_LSTAT = SYS_STAT }
   dd SYS_FSTAT
   dd BAD_SYSCALL       { (olduname) }
   dd BAD_SYSCALL       { System call 110 (iopl) }
   dd BAD_SYSCALL       { (vhangup) }
   dd BAD_SYSCALL       { (idle) }
   dd BAD_SYSCALL       { (vm86old) }
   dd BAD_SYSCALL       { (wait4) }
   dd BAD_SYSCALL       { System call 115 (swapoff) }
   dd BAD_SYSCALL       { (sysinfo) }
   dd BAD_SYSCALL       { (ipc) }
   dd BAD_SYSCALL       { (fsync) }
   dd BAD_SYSCALL       { (sigreturn) }
   dd BAD_SYSCALL       { System call 120 (clone) }
   dd BAD_SYSCALL       { (setdomainname) }
   dd SYS_UNAME
   dd BAD_SYSCALL       { (modify_ldt) }
   dd BAD_SYSCALL       { (adjtimex) }
   dd BAD_SYSCALL       { System call 125 (mprotect) }
   dd SYS_SIGPROCMASK
   dd BAD_SYSCALL       { (create_module) }
   dd BAD_SYSCALL       { (init_module) }
   dd BAD_SYSCALL       { (delete_module) }
   dd BAD_SYSCALL       { System call 130 (get_kernel_syms) }
   dd BAD_SYSCALL       { (quotactl) }
   dd SYS_GETPGID
   dd SYS_FCHDIR
   dd BAD_SYSCALL       { (bdflush) }
   dd BAD_SYSCALL       { Systm call 135 (sysfs) }
   dd BAD_SYSCALL       { (personality) }
   dd BAD_SYSCALL       { (afs_syscall) }
   dd BAD_SYSCALL       { (setfsuid) }
   dd BAD_SYSCALL       { (setfsgid) }
   dd BAD_SYSCALL       { System call 140 (_llseek) }
   dd SYS_GETDENTS
   dd SYS_SELECT
   dd BAD_SYSCALL       { (flock) }
   dd BAD_SYSCALL       { (msync) }
   dd BAD_SYSCALL       { System call 145 (readv) }
   dd BAD_SYSCALL       { (writev) }
   dd BAD_SYSCALL       { (getsid) }
   dd BAD_SYSCALL       { (fdatasync) }
   dd BAD_SYSCALL       { (_sysctl) }
   dd BAD_SYSCALL       { System call 150 (mlock) }
   dd BAD_SYSCALL       { (munlock) }
   dd BAD_SYSCALL       { (mlockall) }
   dd BAD_SYSCALL       { (munlockall) }
   dd BAD_SYSCALL       { (sched_setparam) }
   dd BAD_SYSCALL       { System call 155 (sched_getparam) }
   dd BAD_SYSCALL       { (sched_setscheduler) }
   dd BAD_SYSCALL       { (sched_getscheduler) }
   dd BAD_SYSCALL       { (sched_yield) }
   dd BAD_SYSCALL       { (sched_get_priority_max) }
   dd BAD_SYSCALL       { System call 160 (sched_get_priority_min) }
   dd BAD_SYSCALL       { (sched_rr_get_interval) }
   dd SYS_NANOSLEEP
   dd SYS_MREMAP
   dd BAD_SYSCALL       { (setresuid) }
   dd BAD_SYSCALL       { System call 165 (getresuid) }
   dd BAD_SYSCALL       { (vm86) }
   dd BAD_SYSCALL       { (query_module) }
   dd BAD_SYSCALL       { (poll) }
   dd BAD_SYSCALL       { (nfsservctl) }
   dd BAD_SYSCALL       { System call 170 (setresgid) }
   dd BAD_SYSCALL       { (getresgid) }
   dd BAD_SYSCALL       { (prctl) }
   dd BAD_SYSCALL       { (rt_sigreturn) }
   dd SYS_SIGACTION     { (rt_sigaction) FIXME: rt_sigaction = sigaction }
   dd SYS_SIGPROCMASK   { System call 175 (rt_sigprocmask) FIXME: rt_sigprocmask = sigprocmask }
   dd BAD_SYSCALL       { (rt_sigpending) }
   dd BAD_SYSCALL       { (rt_sigtimedwait) }
   dd BAD_SYSCALL       { (rt_sigqueueinfo) }
   dd SYS_RT_SIGSUSPEND
   dd BAD_SYSCALL       { System call 180 (pread) }
   dd BAD_SYSCALL       { (pwrite) }
   dd BAD_SYSCALL       { (chown) }
   dd SYS_GETCWD
   dd BAD_SYSCALL       { (capget) }
   dd BAD_SYSCALL       { System call 185 (capset) }
   dd BAD_SYSCALL       { (sigaltstack) }
   dd BAD_SYSCALL       { (sendfile) }
   dd BAD_SYSCALL       { (getpmsg) }
   dd BAD_SYSCALL       { (putpmsg) }
   dd BAD_SYSCALL       { System call 190 (vfork) }
   dd BAD_SYSCALL       { (ugetrlimit) }
   dd BAD_SYSCALL       { (mmap2) }
   dd BAD_SYSCALL       { (truncate64) }
   dd BAD_SYSCALL       { (ftruncate64) }
   dd SYS_STAT64        { System call 195 (stat64) }
   dd SYS_STAT64        { (lstat64) FIXME: SYS_LSTAT64 = SYS_STAT64 }
   dd BAD_SYSCALL       { (fstat64) }
   dd BAD_SYSCALL       { (lchown32) }
   dd BAD_SYSCALL       { (getuid32) }
   dd BAD_SYSCALL       { System call 200 (getgid32) }
   dd BAD_SYSCALL       { (geteuid32) }
   dd BAD_SYSCALL       { (getegid32) }
   dd BAD_SYSCALL       { (setreuid32) }
   dd BAD_SYSCALL       { (setregid32) }
   dd BAD_SYSCALL       { System call 205 (getgroups32) }
   dd BAD_SYSCALL       { (setgroups32) }
   dd BAD_SYSCALL       { (fchown32) }
   dd BAD_SYSCALL       { (setresuid32) }
   dd BAD_SYSCALL       { (getresuid32) }
   dd BAD_SYSCALL       { Systtem call 210 (setresgid32) }
   dd BAD_SYSCALL       { (getresgid32) }
   dd BAD_SYSCALL       { (chown32) }
   dd BAD_SYSCALL       { (setuid32) }
   dd BAD_SYSCALL       { (setgid32) }
   dd BAD_SYSCALL       { System call 215 (setfsuid32) }
   dd BAD_SYSCALL       { (setfsgid32) }
   dd BAD_SYSCALL       { (pivot_root) }
   dd BAD_SYSCALL       { (mincore) }
   dd BAD_SYSCALL       { (madvise/madvise1) }
   dd BAD_SYSCALL       { System call 220 (getdents64) }
   dd BAD_SYSCALL       { (fcntl64) }
   dd BAD_SYSCALL       { (???) }
   dd BAD_SYSCALL       { (security) }
   dd BAD_SYSCALL       { (gettid) }
   dd BAD_SYSCALL       { System call 225 (readahead) }
   dd BAD_SYSCALL       { (setxattr) }
   dd BAD_SYSCALL       { (lsetxattr) }
   dd BAD_SYSCALL       { (fsetxattr) }
   dd BAD_SYSCALL       { (getxattr) }
   dd BAD_SYSCALL       { System call 230 (lgetxattr) }
   dd BAD_SYSCALL       { (fgetxattr) }
   dd BAD_SYSCALL       { (listxattr) }
   dd BAD_SYSCALL       { (llistxattr) }
   @MAX_NR_SYSCALLS:
      dd 233
end;



begin
end.
