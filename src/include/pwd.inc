{$IFNDEF __PWD__}
{$DEFINE __PWD__}


type

   passwd = record
      pw_name  : pchar;
      pw_uid   : dword;
      pw_gid   : dword;
      pw_dir   : pchar;
      pw_shell : pchar
   end;

   P_passwd = ^passwd;


function  getpwnam (name : pchar) : P_passwd; cdecl; external;
function  getpwuid (uid : dword) : P_passwd; cdecl; external;


{$ENDIF}
