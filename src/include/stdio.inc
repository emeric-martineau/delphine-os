{$IFNDEF _STDIO_}
{$DEFINE _STDIO_}


{$DEFINE NULL NIL}
{$DEFINE EOF  -1}

const
   stdin  = 0;
   stdout = 1;
   stderr = 2;


procedure clearerr (stream : pointer); cdecl; external;
function  fclose (stream : pointer) : dword; cdecl; external;
function  ferror (stream : pointer) : dword; cdecl; external;
function  fflush (stream : pointer) : dword; cdecl; external;
function  fgetc (stream : pointer) : dword; cdecl; external;
function  fgets (s : pchar ; n : dword ; stream : pointer) : pchar; cdecl; external;
function  fileno (stream : pointer) : dword; cdecl; external;
function  fopen (filename, mode : pchar) : pointer; cdecl; external;
function  fprintf (stream : dword ; format : pchar ; args : array of const) : dword; cdecl; external;
function  fputc (c : dword ; stream : pointer) : dword; cdecl; external;
function  fputs (s : pchar ; stream : pointer) : dword; cdecl; external;
procedure perror (s : pchar); cdecl; external;
function  putchar (c : char) : dword; cdecl; external;
function  puts (s : pchar) : dword; cdecl; external;
function  printf (format : pchar ; args : array of const) : dword; cdecl; external;
function  scanf  (format : pchar ; args : array of const) : dword; cdecl; external;
function  sprintf (s, format : pchar ; args : array of const) : dword; cdecl; external;


{$ENDIF}
