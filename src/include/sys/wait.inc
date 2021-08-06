{$IFNDEF _WAIT_}
{$DEFINE _WAIT_}

{$I sys/types.inc}


function waitpid (pid : dword ; stat_loc : pointer ; options : dword) : dword; cdecl; external;
function WIFSIGNALED (val : dword) : dword; cdecl; external;
function WTERMSIG (val : dword) : dword; cdecl; external;


{$ENDIF}
