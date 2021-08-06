{$IFNDEF __DIRENT__}
{$DEFINE __DIRENT__}


type
   DIR = dword;
   dirent = record
      d_name : pchar;
   end;

function  opendir (dirname : pchar) : pointer; cdecl; external;
function  readdir (dirp : pointer) : pointer; cdecl; external;


{$ENDIF}
