{$IFNDEF __SIGNAL__}
{$DEFINE __SIGNAL__}


const
   _NSIG = 64;
   
   SIGHUP    = 1;    {* Hangup detected on controlling terminal or death of a
      	              * controlling process *}

   SIGINT    = 2;    {* Interrupt special character typed on controlling
      	              * keyboard *}

   SIGQUIT   = 3;    {* Quit special character typed on controlling keyboard *}

   SIGILL    = 4;    {* Illegal instruction indicating a program error.
      	              * Applications may wish to catch this signal and attempt
		      * to recover from bugs. A portable program should not
		      * intentionally generate illegal instructions *}

   SIGTRAP   = 5;    {* *}

   SIGABRT   = 6;    {* Abnormal termination signal caused by the abort()
      	              * function. A portable program should avoid catching
		      * SIGABRT *}

   SIGIOT    = 6;    {* *}

   SIGBUS    = 7;    {* *}

   SIGFPE    = 8;    {* Arithmetic exception, such as overflow or division by
      	              * zero *}

   SIGKILL   = 9;    {* Termination signal. This signal cannot be caught
      	              * or ignored *}

   SIGUSR1   = 10;   {* Application-defined signal 1 *}

   SIGSEGV   = 11;   {* Invalid memory reference. Like SIGILL, portable
      	              * programs should not intentionally generate invalid
		      * memory reference *}

   SIGUSR2   = 12;   {* Application-defined signal 2 *}

   SIGPIPE   = 13;   {* Write to a pipe with no readers *}

   SIGALRM   = 14;   {* The timer set by the alarm() function has timed-out *}

   SIGTERM   = 15;   {* Termination signal *}

   SIGSTKFLT = 16;

   SIGCHLD   = 17;   {* Child process terminated or stopped. By default, this
      	              * signal is ignored *}

   SIGCONT   = 18;   {* Continue the process if it is currently stopped;
      	              * otherwise, ignore the signal *}

   SIGSTOP   = 19;   {* Stop signal. This signal cannot be caught or ignored *}

   SIGTSTP   = 20;   {* Stop special character typed on the controlling
      	              * keyboard *}

   SIGTTIN   = 21;   {* Read from the controlling terminal attempted by a
      	              * member of a background process group *}

   SIGTTOU   = 22;   {* Write to controlling terminal attempted by a member
      	              * of a background process group *}

   SIGURG    = 23;   {* *}

   SIGXCPU   = 24;   {* *}

   SIGXFSZ   = 25;   {* *}

   SIGVTALRM = 26;   {* *}

   SIGPROF   = 27;   {* *}

   SIGWINCH  = 28;   {* *}

   SIGIO     = 29;   {* *}

   SIGPWR    = 30;   {* *}

   SIGSYS    = 31;   {* *}

   SIGUNUSED = 31;


   SIG_BLOCK   = 0;
   SIG_UNBLOCK = 1;
   SIG_SETMASK = 2;

   {* Signal actions *}
   SIG_DFL = 0;   {* Signal-specific default action *}

   SIG_IGN = 1;   {* Ignore the signal.
      	           * 
		   * It is possible to ignore SIGFPE, SIGILL and SIGSEGV;
		   * however, programs with illegal instructions are not
		   * portable.
		   *
		   * The default for SIGCHLD is to ignore the signal.
		   * Applications that wish to ignore SIGCHLD should set the
		   * action to be SIG_DFL, not to SIG_IGN *}

   SIG_ERR = -1;


   {*
    * SA_FLAGS values:
    *
    * SA_ONSTACK indicates that a registered stack_t will be used.
    * SA_INTERRUPT is a no-op, but left due to historical reasons. Use the
    * SA_RESTART flag to get restarting signals (which were the default long ago)
    * SA_NOCLDSTOP flag to turn off SIGCHLD when children stop.
    * SA_RESETHAND clears the handler when the signal is delivered.
    * SA_NOCLDWAIT flag on SIGCHLD to inhibit zombies.
    * SA_NODEFER prevents the current signal from being masked in the handler.
    *
    * SA_ONESHOT and SA_NOMASK are the historical Linux names for the Single
    * Unix names RESETHAND and NODEFER respectively.
    *}
     SA_NOCLDSTOP	= $00000001;
     SA_NOCLDWAIT	= $00000002; { not supported yet }
     SA_SIGINFO		= $00000004;
     SA_ONSTACK		= $08000000;
     SA_RESTART		= $10000000;
     SA_NODEFER		= $40000000;
     SA_RESETHAND	= $80000000;

     SA_NOMASK		= SA_NODEFER;
     SA_ONESHOT		= SA_RESETHAND;
     SA_INTERRUPT	= $20000000; { dummy -- ignored }

     SA_RESTORER	= $04000000;

type

   P_sigset_t  = ^sigset_t;
   P_sigaction = ^sigaction;

   sigset_t   = array[0..1] of dword;

   sigaction = record
      sa_handler  : procedure (num : dword);   {* SIG_DFL for the default action.
      	             	      	             	* or:
      	             	      	             	* SIG_IGN to ignore this signal
						* or:
						* pointer to the signal-catching function *}

      sa_flags    : dword;    	               {* This member is used only for the SIGCHLD
      	             	      	             	* signal. If the value SA_NOCLDSTOP is used,
						* then SIGCHLD will not be generated when
						* children stop *}

      sa_restorer : procedure;	               {* Only used by DelphineOS *}

      sa_mask     : sigset_t; 	               {* Additional signals to be blocked during
      	             	      	             	* the execution of the signal-catching
						* function. *}
   end;

{$ENDIF}
