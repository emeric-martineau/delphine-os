{$IFNDEF __RESOURCE__}
{$DEFINE __RESOURCE__}


const

   RLIMIT_CPU	   	= 0;		{* CPU time in ms *}
   RLIMIT_FSIZE	   = 1;		{* Maximum filesize *}
   RLIMIT_DATA	   	= 2;		{* max data size *}
   RLIMIT_STACK	   = 3;		{* max stack size *}
   RLIMIT_CORE	   	= 4;		{* max core file size *}
   RLIMIT_RSS	   	= 5;		{* max resident set size *}
   RLIMIT_NPROC	   = 6;		{* max number of processes *}
   RLIMIT_NOFILE  	= 7;		{* max number of open files *}
   RLIMIT_MEMLOCK 	= 8;		{* max locked-in-memory address space *}
   RLIMIT_AS	   	= 9;		{* address space limit *}
   RLIMIT_LOCKS	   = 10;		{* maximum file locks held *}

   RLIM_NLIMITS	   = 11;

   RLIM_INFINITY  	= $FFFFFFFF;


type

   P_rlimit = ^rlimit;

   rlimit = record
      rlim_cur : dword;
      rlim_max : dword;
   end;



{$ENDIF}
