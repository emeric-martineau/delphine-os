{$IFNDEF _FCNTL_}
{$DEFINE _FCNTL_}


{$I sys/types.inc}


const
   O_RDONLY = 4;
   O_WRONLY = 2;
   O_RDWR   = 6;

   O_CREAT    = $08;
   O_EXCL     = $10;
   O_APPEND   = $20;
   O_NONBLOCK = $40;
   O_TRUNC    = $80;

   S_IFMT   = $10000;
   S_IFSOCK = $A000;
   S_IFLNK  = $C000;
   S_IFREG  = $8000;
   S_IFBLK  = $6000;
   S_IFDIR  = $4000;
   S_IFCHR  = $2000;
   S_IFIFO  = $1000;

   S_ISUID  = $800;
   S_ISGID  = $400;
   S_ISVTX  = $200;

   S_IRUSR  = $100;
   S_IWUSR  = $080;
   S_IXUSR  = $040;

   S_IRGRP  = $20;
   S_IWGRP  = $10;
   S_IXGRP  = $08;

   S_IROTH  = $04;
   S_IWOTH  = $02;
   S_IXOTH  = $01;


function  creat(path : pchar ; mode : dword) : dword; cdecl; external;
function  open (path : pchar ; oflag : dword ; mode : mode_t) : dword; cdecl; external;
function  S_ISBLK(mode : dword) : dword; cdecl; external;
function  S_ISCHR(mode : dword) : dword; cdecl; external;
function  S_ISDIR(mode : dword) : dword; cdecl; external;
function  S_ISFIFO(mode : dword) : dword; cdecl; external;
function  S_ISLNK(mode : dword) : dword; cdecl; external;
function  S_ISREG(mode : dword) : dword; cdecl; external;
function  S_ISSOCK(mode : dword) : dword; cdecl; external;


{$ENDIF}
