{$IFNDEF __WAIT__}
{$DEFINE __WAIT__}

type
   P_wait_queue  = ^wait_queue;
   PP_wait_queue = ^P_wait_queue;

   wait_queue = record
      task : pointer;
      next : P_wait_queue;
   end;

{$ENDIF}
