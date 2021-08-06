{$IFNDEF _TIME_}
{$DEFINE _TIME_}

{$I stddef.inc}


type
   time_t   = dword;
   P_time_t = ^time_t;


function  time_ (timer : pointer) : dword; cdecl; external;
function  ctime (timer : pointer) : pchar; cdecl; external;


{$ENDIF}
