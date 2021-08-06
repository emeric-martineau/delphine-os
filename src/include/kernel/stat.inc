{$IFNDEF __STAT__}
{$DEFINE __STAT__}

type

   P_stat_t   = ^stat_t;
   P_stat64_t = ^stat64_t;

   stat_t = record
      st_dev     : word;
      __pad1     : word;
      st_ino     : dword;
      st_mode    : word;
      st_nlink   : word;
      st_uid     : word;
      st_gid     : word;
      st_rdev    : word;
      __pad2     : word;
      st_size    : dword;
      st_blksize : dword;
      st_blocks  : dword;
      st_atime   : dword;
      __unused1  : dword;
      st_mtime   : dword;
      __unused2  : dword;
      st_ctime   : dword;
      __unused3  : dword;
      __unused4  : dword;
      __unused5  : dword;
   end;

   stat64_t = record
      st_dev     : word;
      __pad0     : array[0..9] of char;
      __st_ino   : dword;
      st_mode    : dword;
      st_nlink   : dword;
      st_uid     : dword;
      st_gid     : dword;
      st_rdev    : word;
      __pad3     : array[0..9] of char;
      st_size    : dword;   { FIXME: st_size is a 64 bits value. For the moment, I'll use 2 dwords }
      st_size2   : dword;
      st_blksize : dword;
      st_blocks  : dword;   { Number 512-byte blocks allocated. }
      __pad4     : dword;   { future possible st_blocks high bits }
      st_atime   : dword;
      __pad5     : dword;
      st_mtime   : dword;
      __pad6     : dword;
      st_ctime   : dword;
      __pad7     : dword;   { will be high 32 bits of ctime someday }
      st_ino     : dword;
      st_ino2    : dword;   { FIXME: st_ino is a 64 bits value. For the moment, I'll use 2 dwords }
   end;

{$ENDIF}
