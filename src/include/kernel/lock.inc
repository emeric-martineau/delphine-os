{$IFNDEF __LOCK__}
{$DEFINE __LOCK__}

{$I wait.inc}

type

   P_rwlock_t = ^rwlock_t;

   rwlock_t = record
      lock : dword;   { Bit 31 is used for the exclusive write lock }
   end;


{$ENDIF}
