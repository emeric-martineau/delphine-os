
{$IFNDEF _UNISTD_}
{$DEFINE _UNISTD_}

{$I sys/types.inc}


const

   STDIN_FILENO  = 0;
   STDOUT_FILENO = 1;
   STDERR_FILENO = 2;

   SEEK_SET = 0;   { Set offset to 'offset' }
   SEEK_CUR = 1;   { Add 'offset' to current position }
   SEEK_END = 2;   { Add 'offset' to cuurent file size }

   R_OK     = 4;   { Read }
   W_OK     = 2;   { Write }
   X_OK     = 1;   { Execute }


   function  access (path : pchar ; amode : dword) : dword; cdecl; external;
   function  chdir (path : pchar) : dword; cdecl; external;
   function  chown (path : pchar ; owner, group : dword) : dword; cdecl; external;
   function  close (fildes : dword) : dword; cdecl; external;
   function  execv (path : pchar ; argv : array of const) : dword; cdecl; external;
   function  execvp (path : pchar ; argv : array of const) : dword; cdecl; external;
   function  fchown (fd : dword ; owner, group : dword) : dword; cdecl; external;
   function  fork : pid_t; cdecl; external;
   function  getcwd (buf : pchar ; size : dword) : pchar; cdecl; external;
   function  getpid : dword; cdecl; external;
   function  isatty (fildes : dword) : dword; cdecl; external;
   function  link (existing, newf : pchar) : dword; cdecl; external;
   function  lseek (fildes : dword ; ofs : off_t ; whence : dword)  : off_t; cdecl; external;
   function  malloc (size : dword) : pointer; cdecl; external;
   function  read  (fildes : dword ; buf : pointer ; nbyte : dword) : dword; cdecl; external;
   function  realloc (ptr : pointer ; size : dword) : pointer; cdecl; external;
   function  rename (oldf, newf : pchar) : dword; cdecl; external;
   function  rmdir (path : pchar) : dword; cdecl; external;
   function  sync : dword; cdecl; external;
   function  unlink (path : pchar) : dword; cdecl; external;
   function  write (fildes : dword ; buf : pointer ; nbyte : dword) : dword; cdecl; external;

{$ENDIF}   { _UNISTD_ }
