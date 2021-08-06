
{$IFNDEF _UNISTD_}
{$DEFINE _UNISTD_}

{$I sys/types.inc}

{$IFDEF _POSIX_SOURCE}


const

   STDIN_FILENO  = 0;
   STDOUT_FILENO = 1;
   STDERR_FILENO = 2;

   SEEK_SET = 0;   { Set offset to 'offset' }
   SEEK_CUR = 1;   { Add 'offset' to current position }
   SEEK_END = 2;   { Add 'offset' to cuurent file size }


   function  fork : pid_t; cdecl; external;
   function  write (fildes : dword ; buf : pointer ; nbyte : dword) : dword; cdecl; external;
   function  lseek (fildes : dword ; ofs : off_t ; whence : dword)  : off_t; cdecl; external;


{$ENDIF}   { _POSIX_SOURCE }

{$ENDIF}   { _UNISTD_ }
