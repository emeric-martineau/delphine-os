{$IFNDEF _SIGNAL_}
{$DEFINE _SIGNAL_}


{ Here is a set of standard signals a process can use }
{$DEFINE SIGABRT    $2}
{$DEFINE SIGALRM    $4}
{$DEFINE SIGFPE     $8}
{$DEFINE SIGHUP    $10}
{$DEFINE SIGILL    $20}
{$DEFINE SIGINT    $40}
{$DEFINE SIGKILL   $80}
{$DEFINE SIGPIPE  $100}
{$DEFINE SIGQUIT  $200}
{$DEFINE SIGSEGV  $400}
{$DEFINE SIGTERM  $800}
{$DEFINE SIGUSR1  $1000}
{$DEFINE SIGUSR2  $2000}

{ There is also a set of job control signals. There are : }
{$DEFINE SIGCHLD  $4000}
{$DEFINE SIGCONT  $8000}
{$DEFINE SIGSTOP  $10000}
{$DEFINE SIGTSTP  $20000}
{$DEFINE SIGTTIN  $40000}
{$DEFINE SIGTTOU  $80000}


{$I sys/types.inc}


function  kill (pid : pid_t ; sig : dword) : dword; cdecl; external;
procedure signal (sig : dword ; func : pointer); cdecl; external;


{$ENDIF}
