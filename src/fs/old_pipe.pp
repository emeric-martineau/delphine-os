{******************************************************************************
 *  pipe.pp
 *
 *  Pipes management
 *
 *  FIXME: finish this
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 12/08/2003 - GaLi - Initial version
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit pipe;


INTERFACE


{* Headers *}

{$I errno.inc}
{$I fcntl.inc}
{$I fs.inc}
{$I pipe.inc}
{$I process.inc}
{$I signal.inc}
{$I tty.inc}

{* Local macros *}

{$DEFINE PIPE_CLOSE_WARNING}
{$DEFINE DEBUG_PIPE_CLOSE}
{$DEFINE DEBUG_PIPE_READ}
{$DEFINE DEBUG_PIPE_WRITE}
{$DEFINE DEBUG_SYS_PIPE}

{* External procedure and functions *}

function  alloc_inode : P_inode_t; external;
procedure free_inode (inode : P_inode_t); external;
function  get_free_page : pointer; external;
procedure interruptible_sleep_on (p : PP_wait_queue); external;
procedure interruptible_wake_up (p : PP_wait_queue ; schedule : boolean); external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure lock_inode (inode : P_inode_t); external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_addr : pointer); external;
procedure send_sig (sig : dword ; p : P_task_struct); external;
function  signal_pending (p : P_task_struct) : dword; external;
procedure unlock_inode (inode : P_inode_t); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure init_pipe;
function  pipe_close (fichier : P_file_t) : dword;
function  pipe_ioctl (fichier : P_file_t ; req : dword ; argp : pointer) : dword;
function  pipe_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function  pipe_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function  sys_pipe (fildes : pointer) : dword; cdecl;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}

var
   pipe_file_operations : file_operations;



{******************************************************************************
 * init_pipe
 *
 * This procedure is called from src/fs/init_vfs.pp
 *****************************************************************************}
procedure init_pipe; [public, alias : 'INIT_PIPE'];
begin

   memset(@pipe_file_operations, 0, sizeof(file_operations));

   pipe_file_operations.read  := @pipe_read;
   pipe_file_operations.write := @pipe_write;
   pipe_file_operations.close := @pipe_close;
	pipe_file_operations.ioctl := @pipe_ioctl;

end;



{******************************************************************************
 * pipe_ioctl
 *
 *****************************************************************************}
function pipe_ioctl (fichier : P_file_t ; req : dword ; argp : pointer) : dword; [public, alias : 'PIPE_IOCTL'];
begin
	if (req = FIONREAD) then
		 result := 4096
	else
		result := -EINVAL;
end;



{******************************************************************************
 * pipe_read
 *
 *****************************************************************************}
function pipe_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [public, alias : 'PIPE_READ'];

var
   pipe_size  : dword;   { Nb of bytes in the pipe that have not been read }
	pipe_inode : P_inode_t;

label again;

begin

   result := 0;

	pipe_inode := fichier^.inode;
   pipe_size  := pipe_inode^.size;

   {$IFDEF DEBUG_PIPE_READ}
		print_bochs('pipe_read (%d): count=%d buf=%h pipe_size=%d\n',
				 		[current^.pid, count, pipe_inode^.pipe_i.base, pipe_size]);
   {$ENDIF}

again:

	pipe_size := pipe_inode^.size;

   if (pipe_size = 0) then
   begin
      if (pipe_inode^.pipe_i.writers = 0) then
      begin
         {$IFDEF DEBUG_PIPE_READ}
	    		print_bochs('pipe_read (%d): no writers, result=0.\n', [current^.pid]);
	 		{$ENDIF}
         result := 0;
	 		exit;
      end
      else
      begin
         {$IFDEF DEBUG_PIPE_READ}
            print_bochs('pipe_read (%d): going to wait for some data\n', [current^.pid]);
         {$ENDIF}
	 		unlock_inode(pipe_inode);
	 		interruptible_sleep_on(@pipe_inode^.pipe_i.wait);
	 		lock_inode(pipe_inode);
	 		{$IFDEF DEBUG_PIPE_READ}
	    		print_bochs('pipe_read (%d): data is there (%d)\n', [current^.pid, pipe_inode^.size]);
	 		{$ENDIF}
			goto again;
      end;
   end
   else if (count > pipe_size) then
   begin
      {$IFDEF DEBUG_PIPE_READ}
         print_bochs('pipe_read (%d): (1) going to read %d bytes from %h\n',
					 		[current^.pid, pipe_size, pipe_inode^.pipe_i.base + pipe_inode^.pipe_i.start]);
      {$ENDIF}
      memcpy(pipe_inode^.pipe_i.base + pipe_inode^.pipe_i.start, buf, pipe_size);
      pipe_inode^.size := 0;
      result := pipe_size;
   end
   else
   begin
      {$IFDEF DEBUG_PIPE_READ}
         print_bochs('pipe_read (%d): (2) going to read %d bytes from %h\n',
					 		[current^.pid, pipe_size, pipe_inode^.pipe_i.base + pipe_inode^.pipe_i.start]);
      {$ENDIF}
      memcpy(pipe_inode^.pipe_i.base + pipe_inode^.pipe_i.start, buf, count);
      pipe_inode^.size := pipe_size - count;
      result := count;
   end;

end;



{******************************************************************************
 * pipe_write
 *
 *****************************************************************************}
function pipe_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [public, alias : 'PIPE_WRITE'];

var
   pipe_size  : dword;   { Nb of bytes in the pipe that have not been read }
   pipe_free  : dword;   { Nb of bytes which can be written to the pipe }
	pipe_inode : P_inode_t;

begin

{ Code from Linux 2.6.7

min <=> count
PIPE_LEN <=> pipe_size
PIPE_SIZE <=> 4096
PIPE_END <=> (pipe_inode^.pipe_i.start + pipe_size) and (4096 - 1)


{}

total_len := count;
min := total_len;

if (min > 4096) then min := 1;

while (true) do
begin
	Si pas de reader -> -EPIPE;
	pipe_size  := pipe_inode^.size;
	pipe_free  := 4096 - pipe_size;
	if (pipe_free >= count) then   { Transfer data }
	begin
		{ chars will be the number of bytes we can write in one shot }
		chars := 4096 - ((pipe_inode^.pipe_i.start + pipe_size) and (4096 - 1));
		pipe_buf := pipe_inode^.pipe_i.base + (pipe_inode^.pipe_i.start + pipe_size) and (4096 - 1);
		if (chars > total_len) then
			 chars := total_len;
		if (chars > pipe_free) then
			 chars := pipe_free;

		'copy chars bytes to pipe_buf;'

		ret += chars;
		pipe_size += chars;
		total_len -= chars;
		if (total_len = 0) then break;

	end;
end;

}

   {FIXME: check if buf has a correct value }

	pipe_inode := fichier^.inode;

   if (pipe_inode^.pipe_i.readers = 0) then
   { The pipe is "broken", there are no readers. }
   begin
      send_sig(SIGPIPE, current);
      result := -EPIPE;
      exit;
   end;

   pipe_size  := pipe_inode^.size;
   pipe_free  := 4096 - pipe_size;

   {$IFDEF DEBUG_PIPE_WRITE}
   	print_bochs('pipe_write (%d): count=%d buf=%h pipe_size=%d  pipe_free=%d\n',
				 		[current^.pid, count, pipe_inode^.pipe_i.base, pipe_size, pipe_free]);
	{$ENDIF}

   if (pipe_free >= count) then
   begin
      {$IFDEF DEBUG_PIPE_WRITE}
         print_bochs('pipe_write (%d): (1) going to write %d bytes at %h\n',
					 		[current^.pid, count, pipe_inode^.pipe_i.base + pipe_size]);
      {$ENDIF}
      memcpy(buf, pipe_inode^.pipe_i.base + pipe_size, count);
      pipe_inode^.size += count;
      result := count;
   end
   else   { count > pipe_free }
   begin
      {$IFDEF DEBUG_PIPE_WRITE}
         print_bochs('pipe_write (%d): (2) going to write %d bytes at %h\n',
					 		[current^.pid, pipe_free, pipe_inode^.pipe_i.base + pipe_inode^.pipe_i.start]);
      {$ENDIF}
      memcpy(buf, pipe_inode^.pipe_i.base + pipe_inode^.pipe_i.start, pipe_free);
      pipe_inode^.size += pipe_free;
		result := pipe_free;
   end;

   if (pipe_inode^.pipe_i.wait <> NIL) then
   begin
      {$IFDEF DEBUG_PIPE_WRITE}
         print_bochs('pipe_write (%d): waking up a process\n', [current^.pid]);
      {$ENDIF}
      interruptible_wake_up(@pipe_inode^.pipe_i.wait, TRUE);
   end;

   {$IFDEF DEBUG_PIPE_WRITE}
      print_bochs('pipe_write (%d): exiting. result=%d\n', [current^.pid, result]);
   {$ENDIF}

end;



{******************************************************************************
 * pipe_close
 *
 *****************************************************************************}
function pipe_close (fichier : P_file_t) : dword; [public, alias : 'PIPE_CLOSE'];
begin

   {$IFDEF DEBUG_PIPE_CLOSE}
      print_bochs('pipe_close (%d): readers=%d  writers=%d buf=%h\n',
						[current^.pid, fichier^.inode^.pipe_i.readers,
						 fichier^.inode^.pipe_i.writers,fichier^.inode^.pipe_i.base]);
   {$ENDIF}

   if (fichier^.flags = O_RDONLY) then
   begin
      {$IFDEF DEBUG_PIPE_CLOSE}
         print_bochs('pipe_close (%d): a reader closed the pipe\n', [current^.pid]);
      {$ENDIF}
      fichier^.inode^.pipe_i.readers := 0;
      if (fichier^.inode^.pipe_i.writers = 0) then
      { No one uses the pipe anymore }
      begin
         {$IFDEF DEBUG_PIPE_CLOSE}
	    		print_bochs('pipe_close (%d): ...a reader closed the pipe and there are no more writers\n', [current^.pid]);
	 		{$ENDIF}
	 		push_page(fichier^.inode^.pipe_i.base);
      end;
   end
   else
   begin
      {$IFDEF DEBUG_PIPE_CLOSE}
         print_bochs('pipe_close (%d): a writer closed the pipe\n', [current^.pid]);
      {$ENDIF}
      fichier^.inode^.pipe_i.writers := 0;
      if (fichier^.inode^.pipe_i.readers = 0) then
      { No one uses the pipe anymore }
      begin
         {$IFDEF DEBUG_PIPE_CLOSE}
	    		print_bochs('pipe_close (%d): ...a writer closed the pipe and there are no more readers\n', [current^.pid]);
	 		{$ENDIF}
	 		push_page(fichier^.inode^.pipe_i.base);
      end;
   end;

   if (fichier^.inode^.pipe_i.wait <> NIL) then
   begin
      {$IFDEF PIPE_CLOSE_WARNING}
         print_bochs('pipe_close (%d): pipe wait queue is not empty\n', [current^.pid]);
      {$ENDIF}
      {$IFDEF DEBUG_PIPE_CLOSE}
         print_bochs('pipe_close (%d): pipe wait queue is not empty\n', [current^.pid]);
      {$ENDIF}
      {FIXME: do something clean }
      while (fichier^.inode^.pipe_i.wait <> NIL) do
             interruptible_wake_up(@fichier^.inode^.pipe_i.wait, TRUE);
   end;

   result := 0;

end;



{******************************************************************************
 * sys_pipe
 *
 *****************************************************************************}
function sys_pipe (fildes : pointer) : dword; cdecl; [public, alias : 'SYS_PIPE'];

var
   f0, f1   : dword;
   fichier0 : P_file_t;
   fichier1 : P_file_t;
   inode    : P_inode_t;
   buf      : pointer;   

begin

   { FIXME: check if fildes is a valid pointer for the current process }

   result := -EMFILE;

   { Look for new file descriptor }
   f0 := 0;
   while (current^.file_desc[f0] <> NIL) and (f0 < OPEN_MAX) do
          f0 += 1;

   if (current^.file_desc[f0] <> NIL) then exit;

   current^.file_desc[f0] := 1;   { Temp value }

   { Do the same thing for f1 }
   f1 := 0;
   while (current^.file_desc[f1] <> NIL) and (f1 < OPEN_MAX) do
          f1 += 1;

   if (current^.file_desc[f1] <> NIL) then exit;

   { f0 and f1 are now initialized. We have to allocate 2 file objects and 1 inode object }

   {$IFDEF DEBUG_SYS_PIPE}
      print_bochs('sys_pipe (%d): fd %d to read, fd %d to write\n', [current^.pid, f0, f1]);
   {$ENDIF}

   fichier0 := kmalloc(sizeof(file_t));
   fichier1 := kmalloc(sizeof(file_t));
   inode    := alloc_inode();
   buf      := get_free_page();

   if (fichier0 = NIL) or (fichier1 = NIL)
   or (inode = NIL) or (buf = NIL) then
   begin
      if (fichier0 <> NIL) then kfree_s(fichier0, sizeof(file_t));
      if (fichier1 <> NIL) then kfree_s(fichier1, sizeof(file_t));
      if (inode <> NIL) then free_inode(inode);
      if (buf <> NIL) then push_page(buf);
      result := -ENOMEM;
      exit;
   end;

   { We now have to initialize newly allocated objects }

   memset(fichier0, 0, sizeof(file_t));
   memset(fichier1, 0, sizeof(file_t));
	memset(inode, 0, sizeof(inode_t));

   fichier0^.op    := @pipe_file_operations;
   fichier0^.pos   := 0;
   fichier0^.flags := O_RDONLY;
   fichier0^.inode := inode;
   fichier0^.count := 1;
   fichier1^.op    := @pipe_file_operations;
   fichier1^.pos   := 0;
   fichier1^.flags := O_WRONLY;
   fichier1^.inode := inode;
   fichier1^.count := 1;
   inode^.size     := 0;
   inode^.count    := 2;
	inode^.wait 	 := NIL;
   inode^.pipe_i.base    := buf;
   inode^.pipe_i.start   := 0;
   inode^.pipe_i.wait    := NIL;
   inode^.pipe_i.lock    := 0;
   inode^.pipe_i.readers := 1;
   inode^.pipe_i.writers := 1;

   current^.file_desc[f0] := fichier0;
   current^.file_desc[f1] := fichier1;

   { Write result to user land }
   longint(fildes^) := f0;
   longint(fildes)  += 4;
   longint(fildes^) := f1;

	{ Clear the FD_CLOEXEC flag on both descriptors }
	current^.close_on_exec := current^.close_on_exec and ( not (1 shl f0));
	current^.close_on_exec := current^.close_on_exec and ( not (1 shl f1));

   {$IFDEF DEBUG_SYS_PIPE}
      print_bochs('sys_pipe (%d): base address=%h\n', [current^.pid, buf]);
   {$ENDIF}

   result := 0;

end;



begin
end.
