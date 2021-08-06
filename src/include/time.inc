{$IFNDEF _TIME_}
{$DEFINE _TIME_}

{$I stddef.inc}


type
   time_t   = dword;
   P_time_t = ^time_t;


function time(timer : P_time_t) : time_t;


{$ENDIF}
