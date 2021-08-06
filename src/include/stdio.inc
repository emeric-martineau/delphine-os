{$IFNDEF _STDIO_}
{$DEFINE _STDIO_}


function printf (format : string ; args : array of const) : dword; cdecl; external;
function scanf  (format : string ; args : array of const) : dword; cdecl; external;


{$ENDIF}
