{$IFNDEF __CTYPE__}
{$DEFINE __CTYPE__}


function  isprint (c : dword) : dword; cdecl; external;
function  isspace (c : dword) : dword; cdecl; external;
function  isupper (c : dword) : dword; cdecl; external;
function  tolower (c : dword) : dword; cdecl; external;


{$ENDIF}
