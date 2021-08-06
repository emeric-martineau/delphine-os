{$IFNDEF __UTIME__}
{$DEFINE __UTIME__}


{$I sys/types.inc}

type
   utimbuf = record
      actime  : time_t;   { Access time }
      modtime : time_t;   { Modification time }
   end;


function utime (path : pchar ; times : pointer) : dword; cdecl; external;


{$ENDIF}
