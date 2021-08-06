
{$IFNDEF _TYPES_}
{$DEFINE _TYPES_}

{$IFDEF _POSIX_SOURCE}


type
   pid_t = dword;
   off_t = dword;


{$ENDIF}   { _POSIX_SOURCE }

{$ENDIF}   { _TYPES_ }
