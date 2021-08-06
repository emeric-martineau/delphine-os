{$IFNDEF __PIPE__}
{$DEFINE __PIPE__}

{$I wait.inc}

type

   P_pipe_inode_info = ^pipe_inode_info;

   pipe_inode_info = record
      base     		 : pointer;   { Buffer address }
      start    		 : dword;     { Read position in the pipe }
      wait     		 : P_wait_queue;
      lock     		 : dword;
      readers  		 : dword;
      writers  		 : dword;
		waiting_writers : dword;
   end;


{$ENDIF}
