{$IFNDEF __STAT__}
{$DEFINE __STAT__}


{$I sys/types.inc}


const
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

   S_IEXEC  = S_IXUSR

{ #define S_   I_RO       = 4;   { Read }
#define S_   I_WO       = 2;   { Write } }


type

   stat = record
      st_mode  : mode_t;
      st_ino   : ino_t;
      st_dev   : dev_t;
      st_rdev  : dev_t;   { This member is not a POSIX one }
      st_nlink : nlink_t;
      st_uid   : uid_t;
      st_gid   : gid_t;
      st_size  : off_t;
      st_atime : time_t;
      st_ctime : time_t;
      st_mtime : time_t;
   end;


function  chmod (path : pchar ; mode : dword) : dword; cdecl; external;
function  fchmod (fildes, mode : dword) : dword; cdecl; external;
function  fstat (fildes : dword ; buf : pointer) : dword; cdecl; external;
function  lstat (file_name : pchar ; buf : pointer) : dword; cdecl; external;
function  mknod (path : pchar ; mode, dev : dword) : dword; cdecl; external;
function  mkdir (path : pchar ; mode : dword) : dword; cdecl; external;
function  S_ISBLK(mode : dword) : dword; cdecl; external;
function  S_ISCHR(mode : dword) : dword; cdecl; external;
function  S_ISDIR(mode : dword) : dword; cdecl; external;
function  S_ISFIFO(mode : dword) : dword; cdecl; external;
function  S_ISLNK(mode : dword) : dword; cdecl; external;
function  S_ISREG(mode : dword) : dword; cdecl; external;
function  S_ISSOCK(mode : dword) : dword; cdecl; external;
function  stat (path : pchar : buf : pointer) : dword; cdecl; external;
function  umask (cmask : mode_t) : mode_t; cdecl;


{$ENDIF}
