{$IFNDEF _STDLIB_}
{$DEFINE _STDLIB_}

function  atoi(nptr : pchar) : dword; cdecl; external;
procedure free(ptr : pointer); cdecl; external;
function  getenv(name : pchar) : pchar; cdecl; external;
function  putenv(name : pchar) : dword; cdecl; external;
procedure qsort (base : pointer ; nmemb, size : dword ; compar : pointer); cdecl; external;
function  system_ (str : pchar) : dword; cdecl; external;

{$ENDIF}
