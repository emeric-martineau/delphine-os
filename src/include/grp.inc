{$IFNDEF __GRP__}
{$DEFINE __GRP__}


type
   group = record
      gr_name : pchar;
      gr_gid  : dword;
      gr_mem  : pointer;
   end;
   P_group = ^group

function  getgrgid (gid : dword) : P_group; cdecl; extenral;
function  getgrnam (name : pchar) : P_group; cdecl; external;


{$ENDIF}
