{******************************************************************************
 *  signal.pp
 *
 *  Signals management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 28/05/2003 - GaLi - Initial version
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


unit signal;


INTERFACE


{* Headers *}

{$I errno.inc}
{$I process.inc}
{$I sched.inc}
{$I signal.inc}

{* Local macros *}

{DEFINE DEBUG_DO_SIGNAL}
{DEFINE DEBUG_SEND_SIG}
{DEFINE DEBUG_SYS_KILL}
{DEFINE DEBUG_SYS_SIGPROCMASK}
{DEFINE DEBUG_SYS_SIGACTION}
{DEFINE SHOW_WARNINGS}

{* External procedure and functions *}

procedure add_to_runqueue (task : P_task_struct); external;
procedure dump_task; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure panic(reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure schedule; external;
procedure do_exit (status : dword); external;

{* External variables *}

var
   current   : P_task_struct; external name 'U_PROCESS_CURRENT';
   pid_table : P_pid_table_struct; external name 'U_PROCESS_PID_TABLE';

{* Exported variables *}


{* Procedures and functions defined in this file *}

function  do_signal (signr : dword) : boolean;
procedure send_sig (sig : dword ; p : P_task_struct);
function  signal_pending (p : P_task_struct) : dword;
function  sys_kill (pid : longint ; sig : dword) : dword; cdecl;
function  sys_rt_sigsuspend (sigmask : P_sigset_t ; sigsetsize : dword) : dword; cdecl;
function  sys_sigaction (sig : longint ; act, oact : P_sigaction ; nr : dword) : dword; cdecl;
function  sys_sigprocmask (how : dword ; nset, oset : P_sigset_t) : dword; cdecl;

IMPLEMENTATION


{$I inline.inc}


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}


{******************************************************************************
 * sys_sigprocmask
 *
 * Examines and changes blocked signals.
 *****************************************************************************}
function sys_sigprocmask (how : dword ; nset, oset : P_sigset_t) : dword; cdecl; [public, alias : 'SYS_SIGPROCMASK'];

var
   tmp_set : sigset_t;
   old_set : sigset_t;

begin

	sti();

   old_set := current^.blocked;
   result  := 0;

   {$IFDEF DEBUG_SYS_SIGPROCMASK}
      printk('sys_sigprocmask (%d): how=%d nset=%h (%h %h), oset=%h\n', [current^.pid, how, nset, nset^[0], nset^[1], oset]);
   {$ENDIF}

   if (nset <> NIL) then
   begin
      if (longint(nset) < BASE_ADDR) then
      begin
         result := -EFAULT;   { Bad address }
	 		exit;
      end;
      tmp_set := nset^;
      case (how) of
         SIG_BLOCK:		begin
	 	         				current^.blocked[0] :=
									(current^.blocked[0] or nset^[0])
									 and ((not (1 shl (SIGKILL - 1)))
									 and (not (1 shl (SIGSTOP - 1))));
	               		end;

	 		SIG_UNBLOCK:	begin
	 		 						current^.blocked[0] :=
									(current^.blocked[0] and (not nset^[0]))
									 and ((not (1 shl (SIGKILL -1 )))
									 and (not (1 shl (SIGSTOP - 1))));
	 	      				end;

	 		SIG_SETMASK:	begin
	 		 						current^.blocked[0] :=
									nset^[0] and ((not (1 shl (SIGKILL - 1)))
									and (not (1 shl (SIGSTOP - 1))));
	 	      				end;

	 	else
	 	      				result := -EINVAL;
		end;
   end;

   if (oset <> NIL) then
   begin
      if (longint(oset) < BASE_ADDR) then
          result := -EFAULT
      else
          oset^ := old_set;
   end;

   {$IFDEF DEBUG_SYS_SIGPROCMASK}
      printk('sys_sigprocmask (%d): result=%d %h\n', [current^.pid, result, current^.blocked[0]]);
   {$ENDIF}

end;



{******************************************************************************
 * sys_sigaction
 *
 * Examines and changes signal action.
 *****************************************************************************}
function sys_sigaction (sig : longint ; act, oact : P_sigaction ; nr : dword) : dword; cdecl; [public, alias : 'SYS_SIGACTION'];
begin

	sti();

   {$IFDEF DEBUG_SYS_SIGACTION}
      printk('sys_sigaction (%d): sig=%d  handler=%h flags=%h\n               restorer=%h mask=%h\n',
             [current^.pid, sig, act^.sa_handler, act^.sa_flags, act^.sa_restorer, act^.sa_mask[0]]);
   {$ENDIF}

   if (sig < 1) or (sig > 32) or
      ((act <> NIL) and (sig = SIGKILL) or (sig = SIGSTOP)) then
   begin
      result := -EINVAL;
      exit;
   end;

   {$IFDEF SHOW_WARNINGS}
      if (act <> NIL) and (act^.sa_flags <> 0) and (act^.sa_flags <> SA_INTERRUPT) then
          printk('sys_sigaction (%d): process is trying to use flags %h for signal %d\n', [current^.pid, act^.sa_flags, sig]);
   {$ENDIF}

   { FIXME: check if act and oact are in the process memory space }
   if (act <> NIL) then
        memcpy(act, @current^.signal_struct[sig], sizeof(sigaction));

   if (oact <> NIL) then
        memcpy(@current^.signal_struct[sig], oact, sizeof(sigaction));

   result := 0;

end;



{******************************************************************************
 * do_signal
 *
 *****************************************************************************}
function do_signal (signr : dword) : boolean; [public, alias : 'DO_SIGNAL'];

var
   sig  : sigaction;
   test : dword;


begin

   asm
      mov   eax, esp
      and   eax, $FFFFF000
      add   eax, 4096
      sub   eax, 20
      mov   ebx, [eax]   { old EIP }
      mov   test, ebx
   end;

   {$IFDEF DEBUG_DO_SIGNAL}
      print_bochs('do_signal (%d): %d, %h (PID=%d)\n', [current^.pid, signr, current^.signal_struct[signr].sa_handler, current^.pid]);
   {$ENDIF}

   if (current^.pid = 1) then   { We can't send signals to init }
       exit;

   sig := current^.signal_struct[signr];

   if (longint(sig.sa_handler) = SIG_IGN) then
   begin
      {$IFDEF SHOW_WARNINGS}
         printk('do_signal (%d): signal %d is ignored\n', [current^.pid, signr]);
      {$ENDIF}
   end
   else
   if (longint(sig.sa_handler) = SIG_DFL) then   { On réalise l'action par défaut du signal }
   begin
      case (signr) of
			SIGCHLD: begin   { Do nothing }
	          		end;

			SIGCONT: begin   { Do nothing }
	          		end;

			SIGKILL:	begin
	 	      			do_exit(signr);
	 	   			end;

			SIGSEGV: begin
	             		do_exit(signr);
	          		end;

         SIGILL:  begin
	             		do_exit(signr);
	          		end;

         SIGHUP:	begin
	             		do_exit(signr);
	          		end;

			SIGFPE:  begin
	             		do_exit(signr);
	          		end;

			SIGALRM: begin
	             		do_exit(signr);
	          		end;

			SIGPIPE: begin
	             		do_exit(signr);
	          		end;

		else
			printk('do_signal (%d): don''t know what to do with signal %d\n', [current^.pid, signr]);
      end;
   end
   else
   begin
      {printk('do_signal: we have to execute a handler for signal %d (test=%h)\n', [signr, test]);}
      print_bochs('do_signal (%d): calling handler for signal %d\n', [current^.pid, signr]);
      test := longint(sig.sa_handler);
      if (sig.sa_flags and SA_RESETHAND) = SA_RESETHAND then
      	  longint(sig.sa_handler) := SIG_DFL;
      asm
         mov   eax, test
	 		mov   ebx, signr
	 		cli
	 		push  ebx
	 		call  eax   { FIXME: this is REALLY awful. (the signal handler is excuted in kernel mode) }
	 		pop   ebx
	 		sti
      end;
      print_bochs('do_signal (%d): back from handler\n', [current^.pid]);
   end;

   current^.signal[0] := current^.signal[0] and (not (1 shl (signr - 1)));

   {$IFDEF DEBUG_DO_SIGNAL}
      print_bochs('do_signal (%d): EXITING\n', [current^.pid]);
{		dump_task();}
   {$ENDIF}

   result := TRUE;

end;



{******************************************************************************
 * send_sig
 *
******************************************************************************}
procedure send_sig (sig : dword ; p : P_task_struct); [public, alias : 'SEND_SIG'];
begin

   {$IFDEF DEBUG_SEND_SIG}
      print_bochs('send_sig (%d): dest PID=%d (state=%d), SIG=%d\n', [current^.pid, p^.pid, p^.state, sig]);
   {$ENDIF}

   if (sig > 32) then
   begin
      print_bochs('send_sig (%d): sig is > 32 (%d). Signal won''t be sent\n', [current^.pid, sig]);
      exit;
   end;

   if (p^.state = TASK_ZOMBIE) then exit;

   if (p^.pid <> 1) then
   begin
      if (p^.state = TASK_INTERRUPTIBLE) then
      begin
			pushfd();
			cli();
         p^.signal[0] := p^.signal[0] or (1 shl (sig - 1));
         {$IFDEF DEBUG_SEND_SIG}
            print_bochs('send_sig (%d): waking up process %d\n', [current^.pid, p^.pid]);
         {$ENDIF}
         add_to_runqueue(p);
			popfd();
      end
      else if (p^.state = TASK_UNINTERRUPTIBLE) then
      begin
         print_bochs('send_sig (%d): task %d is uninterruptible\n', [current^.pid, p^.pid]);
      end
      else
         p^.signal[0] := p^.signal[0] or (1 shl (sig - 1));
   end;

   {$IFDEF DEBUG_SEND_SIG}
      print_bochs('send_sig (%d): END\n', [current^.pid]);
   {$ENDIF}

end;



{******************************************************************************
 * sys_rt_sigsuspend
 *
 * FIXME: it seems that the result is not correct
 ******************************************************************************}
function sys_rt_sigsuspend (sigmask : P_sigset_t ; sigsetsize : dword) : dword; cdecl; [public, alias : 'SYS_RT_SIGSUSPEND'];

var
   savemask : sigset_t;
   tmp_sig, tmp_block, sig : dword;

begin

	sti();

   printk('sys_rt_sigsuspend (%d): sigmask=%h\n', [current^.pid, sigmask^[0]]);

   if (longint(sigmask) < BASE_ADDR) then
   begin
      result := -EFAULT;
      exit;
   end;

   result := -ERESTART;

   savemask := current^.blocked;
   current^.blocked := sigmask^;

   current^.state := TASK_INTERRUPTIBLE;
   schedule();

   current^.blocked := savemask;

end;



{******************************************************************************
 * signal_pending
 *
 * Returns, if p has some pending signals, the first signal number. Else, 0.
 ******************************************************************************}
function signal_pending (p : P_task_struct) : dword; [public, alias : 'SIGNAL_PENDING'];

var
   tmp_sig, tmp_block, res : dword;

begin

{printk('Welcome in signal_pending (%h, %h)\n', [p^.signal[0], p^.blocked[0]]);}

   tmp_sig   := p^.signal[0];
   tmp_block := p^.blocked[0];

   asm
      mov   res, 0
      mov   ebx, tmp_sig
      mov   ecx, tmp_block
      not   ecx
      and   ecx, ebx
      bsf   ecx, ecx
      je    @no_signals
      btr   ebx, ecx
      inc   ecx
      mov   res, ecx

      @no_signals:

   end;

   result := res;

end;



{******************************************************************************
 * sys_kill
 *
 * This function sends a signal to a process or a group of process specified by
 * 'pid'. If the signal is zero, error checking is performed but no signal is
 * actually sent. This can be used to check for a valid pid.
 *
 * If 'pid' is greater than zero, 'sig' is sent to the process whose process ID
 * is 'pid'. If 'pid' is negative, 'sig' is sent to all processes whose process
 * group ID is equal to the absolute value of 'pid'.
 *
 * NOTE: 'pid' must not be -1.
 *
 * FIXME: do this function correctly  :-)
 *****************************************************************************}
function sys_kill (pid : longint ; sig : dword) : dword; cdecl; [public, alias : 'SYS_KILL'];
begin

	{$IFDEF DEBUG_SYS_KILL}
		printk('sys_kill (%d): pid=%d sig=%d\n', [current^.pid, pid, sig]);
	{$ENDIF}

	sti();

   if (pid > 1022) then
   begin
      print_bochs('WARNING sys_kill (%d): PID > 1022 (%d)\n', [current^.pid, pid]);
      result := -ESRCH;   { No such process }
      exit;
   end;

   if (sig = 0) then
   begin
      if (pid < 0) then
      	 result := -EINVAL
      else
      begin
			if (pid_table^.pid_nb[pid] <> NIL) then
      	    result := 0
			else
      	    result := -ESRCH;
      end;
      exit;
   end;

   if (pid > 0) then
   begin
      send_sig(sig, pid_table^.pid_nb[pid]);
      result := 0;
   end
   else
   begin
      print_bochs('sys_kill (%d): got to send signal %d to process group %d\n', [current^.pid, sig, -pid]);
      result := -ENOSYS;
   end;

end;



begin
end.
