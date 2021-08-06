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
{$I reboot.inc}
{$I resource.inc}
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

function  sys_getrlimit (resource : dword ; rlim : P_rlimit) : dword; cdecl;
function  sys_pause : dword; cdecl;
function  sys_reboot (magic1, magic2, cmd : dword ; arg : pointer) : dword; cdecl;
function  sys_setsid : dword; cdecl;
function  sys_setuid (uid : dword) : dword; cdecl;
function  sys_umask (cmask : dword) : dword; cdecl;
function  sys_uname (name : P_utsname) : dword; cdecl;


IMPLEMENTATION


{$I inline.inc}


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * sys_uname
 *
 *****************************************************************************}
function sys_uname (name : P_utsname) : dword; cdecl; [public, alias : 'SYS_UNAME'];
begin

	sti();

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
	   	 name^.version[5]     := '1';
{	   	 name^.version[6]     := 'l';}
	   	 name^.version[6]     := #0;
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

	sti();

   current^.state := TASK_INTERRUPTIBLE;
   schedule();
   result := -EINTR;

end;



{******************************************************************************
 * sys_umask
 *
 * Set the process file creation mask to 'cmask'. The file creation mask is
 * used during open(), creat(), mkdir() and mkfifo() calls to turn off
 * permission bits in the 'mode' argument. Bits position that set in 'cmask'
 * are cleared in the mode of the created file.
 *
 * The file creation mask is inherited across fork() and exec() calls.
 *****************************************************************************}
function sys_umask (cmask : dword) : dword; cdecl; [public, alias : 'SYS_UMASK'];
begin

	sti();

   result := current^.umask;
   current^.umask := cmask and $1FF;

end;



{******************************************************************************
 * sys_setuid
 *
 * Sets the user ID.
 *
 * FIXME: finish this function
 *****************************************************************************}
function sys_setuid (uid : dword) : dword; cdecl; [public, alias : 'SYS_SETUID'];
begin

	sti();

   printk('sys_setuid: uid=%d  current^.uid=%d\n', [uid, current^.uid]);

   result := 0;

end;



{******************************************************************************
 * sys_reboot
 *
 * Reboot system call: for obvious reasons only root may call it,
 * and even root needs to set up some magic numbers in the registers
 * so that some mistake won't make this reboot the whole machine.
 * You can also set the meaning of the ctrl-alt-del-key here.
 *
 * reboot doesn't sync: do that yourself before calling this.
 *****************************************************************************}
function sys_reboot (magic1, magic2, cmd : dword ; arg : pointer) : dword; cdecl; [public, alias : 'SYS_REBOOT'];
begin

   { We only trust the superuser with rebooting the system. }
   if (current^.uid <> 0) then
   begin
      result := -EPERM;
      exit;
   end;

   { For safety, we require "magic" arguments. }
   if ((magic1 <> LINUX_REBOOT_MAGIC1) or
      ((magic2 <> LINUX_REBOOT_MAGIC2) and (magic2 <> LINUX_REBOOT_MAGIC2A) and
       (magic2 <> LINUX_REBOOT_MAGIC2B))) then
   begin
      result := -EINVAL;
      exit;
   end;

   result := 0;

   case (cmd) of

      LINUX_REBOOT_CMD_RESTART:
      begin
      	 printk('sys_reboot: got to restart the system\n', []);
      end;

      LINUX_REBOOT_CMD_CAD_ON:
      begin
      	 printk('sys_reboot: CAD on\n', []);
      end;

      LINUX_REBOOT_CMD_CAD_OFF:
      begin
      	 printk('sys_reboot: CAD off\n', []);
      end;

      LINUX_REBOOT_CMD_HALT:
      begin
      	 printk('sys_reboot: stop OS\n', []);
      end;

      LINUX_REBOOT_CMD_POWER_OFF:
      begin
      	 printk('sys_reboot: Power off\n', []);
      end;

      LINUX_REBOOT_CMD_RESTART2:
      begin
      	 printk('sys_reboot: Restart 2\n', []);
      end

      else
      	 result := -EINVAL;
   end;

end;



{******************************************************************************
 * sys_setsid
 *
 * FIXME: this function is not done !!!
 *****************************************************************************}
function sys_setsid : dword; cdecl; [public, alias : 'SYS_SETSID'];
begin

	sti();

   result := -ENOSYS;

end;



{******************************************************************************
 * sys_getrlimit
 *
 * FIXME: this function is not done !!!
 *****************************************************************************}
function sys_getrlimit (resource : dword ; rlim : P_rlimit) : dword; cdecl; [public, alias : 'SYS_GETRLIMIT'];
begin

	sti();

   if (resource >= RLIM_NLIMITS) then
   begin
      result := -EINVAL;
      exit;
   end;

   result := 0;

	case (resource) of
		RLIMIT_DATA:	begin
								rlim^.rlim_cur := 1024 * 1024 * 1024; { 1 Gb }
								rlim^.rlim_max := 1024 * 1024 * 1024;
							end;

		RLIMIT_RSS: 	begin
								rlim^.rlim_cur := 4096;
								rlim^.rlim_max := 4096;
							end;

		RLIMIT_AS:	 	begin
								rlim^.rlim_cur := $FFFFFFFF;
								rlim^.rlim_max := $FFFFFFFF;
							end;

		else
							begin
						   	printk('sys_getrlimit (%d): resource=%d  rlim=%h\n', [current^.pid, resource, rlim]);
								result := -ENOSYS;
							end;
	end;

end;



{******************************************************************************
 * sys_getrusage
 *
 * FIXME: this function is not done !!!
 *****************************************************************************}
function sys_getrusage (who : dword ; ru : pointer) : dword; cdecl; [public, alias : 'SYS_GETRUSAGE'];
begin

	sti();

   printk('sys_getrusage (%d): who=%d  ru=%h\n', [current^.pid, who, ru]);

   result := -ENOSYS;

end;



begin
end.
