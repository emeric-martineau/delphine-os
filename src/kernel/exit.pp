{******************************************************************************
 *  exit.pp
 *
 *  Exit() and waitpid() system calls management
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


{DEFINE DEBUG}
{DEFINE DEBUG_SYS_WAITPID}
{DEFINE DEBUG_DO_EXIT}
{DEFINE DEBUG_SYS_EXIT}
{DEFINE DEBUG_FREE_MEMORY}

{$I errno.inc}
{$I process.inc}
{$I sched.inc}


{* Local macros *}


{* External procedure and functions *}

procedure del_from_runqueue (task : P_task_struct); external;
procedure del_mmap_req (req : P_mmap_req); external;
procedure del_task (task : P_task_struct); external;
procedure dump_task; external;
procedure free_gdt_entry (index : dword); external;
procedure free_inode (inode : P_inode_t); external;
procedure interruptible_sleep_on (p : PP_wait_queue); external;
procedure interruptible_wake_up (p : PP_wait_queue ; schedule : boolean); external;
procedure kfree_s (addr : pointer ; size : dword); external;
procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_addr : pointer); external;
procedure schedule; external;
procedure send_sig (sig : dword ; p : P_task_struct); external;
procedure sleep_on (p : PP_wait_queue); external;
function  sys_close (fd : dword) : dword; external;
procedure unload_process_cr3 (ts : P_task_struct); external;
procedure wake_up (p : PP_wait_queue); external;


{* External variables *}

var
   pid_table : P_pid_table_struct; external name 'U_PROCESS_PID_TABLE';
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure do_exit (status : dword);
procedure release (p : P_task_struct);
procedure sys_exit (status : dword); cdecl;
function  sys_waitpid (pid : longint ; stat_loc : pointer ; options : dword) : dword; cdecl;



IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}


{$I inline.inc}


{******************************************************************************
 * release
 *
 * NOTE: this procedure is only called by sys_waitpid().
 *****************************************************************************}
procedure release (p : P_task_struct);
begin

   {$IFDEF DEBUG_SYS_WAITPID}
      printk('sys_waitpid (%d): releasing process %d\n', [current^.pid, p^.pid]);
   {$ENDIF}

   if (p = current) then
   begin
      printk('WARNING: task releasing itself\n', []);
      exit;
   end;

   if (p^.p_osptr <> NIL) then
       p^.p_osptr^.p_ysptr := p^.p_ysptr;

   if (p^.p_ysptr <> NIL) then
       p^.p_ysptr^.p_osptr := p^.p_osptr
   else
       p^.p_pptr^.p_cptr := p^.p_osptr;

   pushfd();
	cli();

   if (p^.pid > 1022) then
       printk('WARNING release: PID > 1022 (%d)\n', [p^.pid]);

   pid_table^.pid_nb[p^.pid] := NIL;
   pid_table^.nb_free_pids   += 1;

	popfd();

   schedule();

   free_gdt_entry(p^.tss_entry div 8);
   push_page(p^.cr3);
   push_page(pointer(longint(p^.tss^.esp0) - 4096));   { Free kernel mode stack }
   kfree_s(p^.tss, sizeof(tss_struct));
   del_task(p);
   kfree_s(p, sizeof(task_struct));

end;



{******************************************************************************
 * sys_exit
 *
 *****************************************************************************}
procedure sys_exit (status : dword); cdecl; [public, alias : 'SYS_EXIT'];
begin

   {$IFDEF DEBUG_SYS_EXIT}
      printk('sys_exit (%d): status=%d\n', [current^.pid, status]);
   {$ENDIF}

   { From Linux 0.12 }
   asm
      mov   eax, status
      and   eax, $FF
      shl   eax, 8
      mov   status, eax
   end;

   do_exit(status);

end;



{******************************************************************************
 * do_exit
 *
 *****************************************************************************}
procedure do_exit (status : dword); [public, alias : 'DO_EXIT'];

var
   p : P_task_struct;
   i : dword;

   {$IFDEF DEBUG_DO_EXIT}
   	tmp_p : P_task_struct;
   {$ENDIF}

begin

   {$IFDEF DEBUG_DO_EXIT}
      printk('do_exit (%d): status=%d (%h)\n', [current^.pid, status, status]);
   {$ENDIF}

	sti();

   for i := 0 to (OPEN_MAX - 1) do
   begin
      if (current^.file_desc[i] <> NIL) then
      begin
         {$IFDEF DEBUG_DO_EXIT}
            printk('do_exit (%d): calling sys_close(%d)\n', [current^.pid, i]);
	 		{$ENDIF}
         sys_close(i);
      end;
   end;

   {$IFDEF DEBUG_FREE_MEMORY}
      printk('do_exit (%d): freeing memory...  ', [current^.pid]);
   {$ENDIF}

   unload_process_cr3(current);

   {$IFDEF DEBUG_FREE_MEMORY}
      printk('OK\n', []);
      printk('do_exit (%d): freeing mmap list...  ', [current^.pid]);
      i := 0;
   {$ENDIF}

   { Free mmap requests list }
   if (current^.mmap <> NIL) then
   begin
      repeat
			{$IFDEF DEBUG_FREE_MEMORY}
				i += 1;
			{$ENDIF}
			del_mmap_req(current^.mmap^.next);
      until (current^.mmap^.next = current^.mmap);
      del_mmap_req(current^.mmap);
   end;

   {$IFDEF DEBUG_FREE_MEMORY}
      printk('OK (%d mmap requests freed)\n', [i + 1]);
   {$ENDIF}


   { Following code inspired from Linux 0.12 }
	pushfd();
	cli();

   p := current^.p_cptr;
   if (p <> NIL) then   { Current process has at least one child }
   begin
      while (TRUE) do
      begin
{         send_sig(SIGKILL, p);}   { Send a signal to the child... }
{         printk('do_exit (%d): child left (%d)\n', [current^.pid, p^.pid]);}
         p^.p_pptr := pid_table^.pid_nb[1];   { ...which becomes 'init' child }
	 		p^.ppid   := 1;
	 		if (p^.p_osptr <> NIL) then
	 		begin
	    		p := p^.p_osptr;
	    		continue;
	 		end;
	 		p^.p_osptr := pid_table^.pid_nb[1]^.p_cptr;
	 		pid_table^.pid_nb[1]^.p_cptr^.p_ysptr := p;
	 		pid_table^.pid_nb[1]^.p_cptr := current^.p_cptr;
	 		current^.p_cptr := 0;
	 		break;
      end;
   end;

	popfd();

   {$IFDEF DEBUG_DO_EXIT}
      printk('do_exit (%d): parent PID is %d (%h)\n', [current^.pid, current^.p_pptr^.pid, current^.p_pptr^.wait_queue]);
   {$ENDIF}

   if (current^.wait_queue <> NIL) then
   begin
      while (current^.wait_queue <> NIL) do
      begin
         {$IFDEF DEBUG_DO_EXIT}
	    		tmp_p := current^.wait_queue^.task;
            printk('do_exit (%d): waking up process %d\n', [current^.pid, tmp_p^.pid]);
	 		{$ENDIF}
         interruptible_wake_up(@current^.wait_queue, TRUE);
      end;
   end;

   {$IFDEF DEBUG_DO_EXIT}
      printk('do_exit (%d): %d send SIGCHLD to %d\n', [current^.pid, current^.pid, current^.ppid]);
   {$ENDIF}

   { Send a signal to the father }
   { FIXME: error if current^.ppid > 1022 }
   send_sig(SIGCHLD, pid_table^.pid_nb[current^.ppid]);

   {$IFDEF DEBUG_DO_EXIT}
      printk('do_exit (%d): END\n', [current^.pid]);
   {$ENDIF}

   current^.state     := TASK_ZOMBIE;
   current^.brk       := 0;   { NOTE: not necessary but cool for debugging }
   current^.exit_code := status;

   schedule();   { We never get back  :-(  }

end;



{******************************************************************************
 * sys_waitpid
 *
 *****************************************************************************}
function sys_waitpid (pid : longint ; stat_loc : pointer ; options : dword) : dword; cdecl; [public, alias : 'SYS_WAITPID'];

var
   nb, ofs : dword;
   p          : P_task_struct;
   flag       : dword;

label again, next;

begin

   {$IFDEF DEBUG_SYS_WAITPID}
      printk('Welcome in waitpid(%d, %h, %d) current pid=%d\n', [pid, stat_loc, options, current^.pid]);
   {$ENDIF}

   asm
      sti
   end;

   if (stat_loc <> NIL) and (stat_loc < pointer($C0000000)) then
   begin
      {$IFDEF DEBUG_SYS_WAITPID}
         printk('sys_waitpid: stat_loc has a bad value (%h)\n', [stat_loc]);
      {$ENDIF}
      result := -EINVAL;
      exit;
   end;

again:

   flag := 0;
   p := current^.p_cptr;

   while (p <> NIL) do
   begin

      {$IFDEF DEBUG_SYS_WAITPID}
         printk('sys_waitpid: pid=%d, flag=%d\n', [p^.pid, flag]);
      {$ENDIF}

      if (pid > 0) then   { We are waiting for the specific child whose process ID is equal to 'pid' }
      begin
         if (p^.pid <> pid) then goto next;
      end
      else if (pid = 0) then   {* We are waiting for any child process whose
                                * process group ID is equal to that of the calling process *}
      begin
         {$IFDEF DEBUG_SYS_WAITPID}
            printk('sys_waitpid (%d): called with pid=0 but DelphineOS doesn''t understand process group ID\n', [current^.pid]);
	 		{$ENDIF}
	 		result := -ENOSYS;
	 		exit;
      end
      else if (pid <> -1) then   {* We are waiting for any child process whose
                                  * process group ID is equal to the absolute value of pid *}
      begin
         {$IFDEF DEBUG_SYS_WAITPID}
            printk('sys_waitpid (%d): called with pid=%d but DelphineOS doesn''t understand process group ID\n', [current^.pid, pid]);
	 		{$ENDIF}
	 		result := -ENOSYS;
	 		exit;
      end;

      { We are looking for any child }

      {$IFDEF DEBUG_SYS_WAITPID}
         printk('sys_waitpid: process %d is ok\n', [p^.pid]);
      {$ENDIF}
      case (p^.state) of
         TASK_ZOMBIE:	begin
  		         				if (stat_loc <> NIL) then
										 longint(stat_loc^) := p^.exit_code;
		         				flag := p^.pid;
			 						{$IFDEF DEBUG_SYS_WAITPID}
			    						printk('sys_waitpid: process %d is a ZOMBIE\n', [p^.pid]);
			 						{$ENDIF}
		         				release(p);
		         				result := flag;
		         				{$IFDEF DEBUG_SYS_WAITPID}
		            				printk('sys_waitpid: EXIT - EXIT result is %d, stat_loc=%d\n', [result, longint(stat_loc^)]);
		         				{$ENDIF}
		         				exit;
	       	      		end;
	         else
	               		begin
		         				{$IFDEF DEBUG_SYS_WAITPID}
		            				printk('sys_waitpid: process %d is still running, continuing\n', [p^.pid]);
		         				{$ENDIF}
		         				flag := 1;
		         				goto next;
	               		end;
       end;   { case (p^.state) }

   next:
      p := p^.p_osptr;

   end;   { while (p <> NIL) }

   {$IFDEF DEBUG_SYS_WAITPID}
      printk('sys_waitpid: fin boucle while\n', []);
   {$ENDIF}

   if (flag = 1) then   { We found a child but he's still running }
   begin
      if (options and WNOHANG) = WNOHANG then   {* We don't suspend execution of the calling process because status
                                                 * is not immediately available for any of the child processes *}
		begin
			{$IFDEF DEBUG_SYS_WAITPID}
	         printk('sys_waitpid: WNOHANG flag, exiting...\n', []);
	      {$ENDIF}
{	      schedule();}
	      result := 0;
	      longint(stat_loc^) := 0;
		end
      else
		begin
			{$IFDEF DEBUG_SYS_WAITPID}
				printk('sys_waitpid: suspend process %d\n', [current^.pid]);
	   	{$ENDIF}
	   	interruptible_sleep_on(@current^.wait_queue);
	   	goto again;
		end;
   end
   else   { We haven't find any child }
   begin
      {$IFDEF DEBUG_SYS_WAITPID}
         printk('sys_waitpid: no child found\n', []);
      {$ENDIF}
      result := -ECHILD;
      longint(stat_loc^) := 0;
   end;

   {$IFDEF DEBUG_SYS_WAITPID}
      printk('sys_waitpid: EXIT - EXIT result is %d, stat_loc=%d\n', [result, longint(stat_loc^)]);
   {$ENDIF}

end;



begin
end.
