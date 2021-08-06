{$IFNDEF _STRING_}
{$DEFINE _STRING_}


{$I sys/types.inc}


function  memchr (s : pchar ; c, n : dword) : pointer; cdecl; external;
function  memcmp (s1, s2 : pointer ; n : dword) : dword; cdecl; external;
function  memcpy (s1, s2 : pointer ; n : size_t) : pointer; cdecl; external;
function  memset (s : pointer ; c, n : dword) : pointer; cdecl; external;
function  strcat (s1, s2 : pchar) : pchar; cdecl; external;
function  strchr (s : pchar ; c : char) : pchar; cdecl; external;
function  strcmp (s1, s2 : pchar) : dword; cdecl; external;
function  strcpy (s1, s2 : pchar) : pchar; cdecl; external;
function  strdup (s : pchar) : pchar; cdecl; external;
function  strerror (errnum : dword) : pchar; cdecl; external;
function  strlen (s : pchar) : size_t; cdecl; external;
function  strncmp (s1, s2 : pchar ; n : dword) : pchar; cdecl; external;
function  strncpy (s1, s2 : pchar ; n : dword) : pchar; cdecl; external;
function  strrchr (s : pchar ; c : dword) : pchar; cdecl; external;
function  strstr (s1, s2 : pchar) : pchar; cdecl; external;


{$ENDIF}
