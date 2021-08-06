{$IFNDEF __SIGNAL__}
{$DEFINE __SIGNAL__}


const
   _NSIG = 64;
   
   SIGHUP    = 1;
   SIGINT    = 2;
   SIGQUIT   = 3;
   SIGILL    = 4;
   SIGTRAP   = 5;
   SIGABRT   = 6;
   SIGIOT    = 6;
   SIGFPE    = 8;
   SIGKILL   = 9;
   SIGSEGV   = 11;
   SIGPIPE   = 13;
   SIGALRM   = 14;
   SIGTERM   = 15;
   SIGUNUSED = 31;
   
   SIGBUS    = 7;
   SIGUSR1   = 10;
   SIGUSR2   = 12;
   SIGSTKFLT = 16;
   SIGCHLD   = 17;
   SIGCONT   = 18;
   SIGSTOP   = 19;
   SIGTSTP   = 20;
   SIGTTIN   = 21;
   SIGTTOU   = 22;
   SIGURG    = 23;
   SIGXCPU   = 24;
   SIGXFSZ   = 25;
   SIGVTALRM = 26;
   SIGPROF   = 27;
   SIGWINCH  = 28;
   SIGIO     = 29;
   SIGPWR    = 30;
   SIGSYS    = 31;

   SIG_BLOCK   = 0;
   SIG_UNBLOCK = 1;
   SIG_SETMASK = 2;

   SIG_DFL = 0;
   SIG_IGN = 1;
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
      sa_handler  : procedure (num : dword);
      sa_flags    : dword;
      sa_restorer : procedure;
      sa_mask     : sigset_t;
   end;

{$ENDIF}
