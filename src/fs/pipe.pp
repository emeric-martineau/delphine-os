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
{$I pipe.inc}
{$I process.inc}
{$I signal.inc}
{$I tty.inc}

{* Local macros *}

{DEFINE PIPE_CLOSE_WARNING}
{DEFINE DEBUG_PIPE_CLOSE}
{DEFINE DEBUG_PIPE_READ}
{DEFINE DEBUG_PIPE_WRITE}
{DEFINE DEBUG_SYS_PIPE}

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
procedure wake_up (p : PP_wait_queue); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure init_pipe;
function  pipe_close (fichier : P_file_t) : dword;
function  pipe_ioctl (fichier : P_file_t ; req : dword ; argp : pointer) : dword;
function  pipe_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
procedure pipe_wait (inode : P_inode_t);
function  pipe_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function  sys_pipe (fildes : pointer) : dword; cdecl;


IMPLEMENTATION

{$I inline.inc}

{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}

var
   pipe_file_operations : file_operations;



{******************************************************************************
 * PIPE_BASE
 *
 *****************************************************************************}
function PIPE_BASE (inode : P_inode_t) : dword; inline;
begin
	result := longint(inode^.pipe_i.base);
end;



{******************************************************************************
 * PIPE_END
 *
 *****************************************************************************}
function PIPE_END (inode : P_inode_t) : dword; inline;
begin
	result := (inode^.pipe_i.start + inode^.size) and (4096 - 1);
end;



{******************************************************************************
 * PIPE_FREE
 *
 *****************************************************************************}
function PIPE_FREE (inode : P_inode_t) : dword; inline;
begin
	result := 4096 - inode^.size;
end;



{******************************************************************************
 * PIPE_LEN
 *
 *****************************************************************************}
function PIPE_LEN (inode : P_inode_t) : dword; inline;
begin
	result := inode^.size;
end;



{******************************************************************************
 * PIPE_READERS
 *
 *****************************************************************************}
function PIPE_READERS (inode : P_inode_t) : dword; inline;
begin
	result := inode^.pipe_i.readers;
end;



{******************************************************************************
 * PIPE_START
 *
 *****************************************************************************}
function PIPE_START (inode : P_inode_t) : dword; inline;
begin
	result := longint(inode^.pipe_i.start);
end;



{******************************************************************************
 * PIPE_MAX_RCHUNK
 *
 * Returns the number of byte we can read in one shot
 *
 *****************************************************************************}
function PIPE_MAX_RCHUNK (inode : P_inode_t) : dword; inline;
begin
	if (inode^.pipe_i.start + inode^.size) > 4096 then
		 result := 4096 - inode^.pipe_i.start
	else
		 result := inode^.size;
end;



{******************************************************************************
 * PIPE_MAX_WCHUNK
 *
 * Returns the number of byte we can write in one shot
 *
 * NOTE: Have to use 'tmp' because of the Free Pascal Compiler  :(
 *****************************************************************************}
function PIPE_MAX_WCHUNK (inode : P_inode_t) : dword; inline;
var
	tmp : dword;
begin
	if (inode^.pipe_i.start + inode^.size) >= 4096 then
	begin
		result := 4096 - inode^.size;
	end
	else
	begin
		tmp := inode^.pipe_i.start;
		tmp += inode^.size;
		result := 4096 - tmp;
	end;
end;



{******************************************************************************
 * PIPE_WAITING_WRITERS
 *
 *****************************************************************************}
function PIPE_WAITING_WRITERS (inode : P_inode_t) : dword; inline;
begin
	result := inode^.pipe_i.waiting_writers;
end;



{******************************************************************************
 * PIPE_WRITERS
 *
 *****************************************************************************}
function PIPE_WRITERS (inode : P_inode_t) : dword; inline;
begin
	result := inode^.pipe_i.writers;
end;



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
	inode 		: P_inode_t;
	pipebuf		: pointer;
	ret, chars	: dword;

label again;

begin

	{FIXME: check if buf has a correct value (-EFAULT) }

	if (count = 0) then
	begin
		result := 0;
		exit;
	end;

	ret   := 0;
	inode := fichier^.inode;

	{$IFDEF DEBUG_PIPE_READ}
		print_bochs('pipe_read (%d): count=%d buf=%h PIPE_LEN=%d\n',
		[current^.pid, count, buf, PIPE_LEN(inode)]);
	{$ENDIF}

again:

	if (PIPE_LEN(inode) = 0) then
	{ There is nothing in the pipe }
	begin
		{$IFDEF DEBUG_PIPE_READ}
			print_bochs('pipe_read (%d): PIPE_LEN=0, ret=%d ', [current^.pid, ret]);
		{$ENDIF}
		if (inode^.pipe_i.writers = 0) then
		{ No writer, so there won't be any more data }
		begin
			{$IFDEF DEBUG_PIPE_READ}
				print_bochs('No writer => result=0\n', []);
			{$ENDIF}
			result := 0;
			exit;
		end
		else
		begin
			if (fichier^.flags and O_NONBLOCK) = O_NONBLOCK then
			begin
				{$IFDEF DEBUG_PIPE_READ}
					print_bochs('Non-blocking file -> exiting\n', []);
				{$ENDIF}
				result := -EAGAIN;
				exit;
			end
			else
			{ We have to wait for some data }
			begin
				{ Waking up processes which were waiting for the pipe's data to change }
				if (inode^.pipe_i.wait <> NIL) then
		 			 wake_up(@inode^.pipe_i.wait);

				{$IFDEF DEBUG_PIPE_READ}
					print_bochs('=> WAITING\n', []);
				{$ENDIF}
				unlock_inode(inode);
				interruptible_sleep_on(@inode^.pipe_i.wait);
				lock_inode(inode);
				{$IFDEF DEBUG_PIPE_READ}
					print_bochs('pipe_read (%d): UP\n', [current^.pid]);
				{$ENDIF}
				goto again;
			end;
		end;
	end
	else
	{ There is something in the pipe, copying data }
	begin
		while (PIPE_LEN(inode) <> 0) and (count <> 0) do
		begin
			chars   := PIPE_MAX_RCHUNK(inode);
			pipebuf := pointer(PIPE_BASE(inode) + PIPE_START(inode));

			if (chars > count) then chars := count;

			{$IFDEF DEBUG_PIPE_READ}
				print_bochs('pipe_read (%d): copying %d bytes from %d to %h\n',
				[current^.pid, chars, longint(pipebuf) - longint(inode^.pipe_i.base), buf]);
			{$ENDIF}

			memcpy(pipebuf, buf, chars);
			count -= chars;
			inode^.pipe_i.start += chars;
			inode^.pipe_i.start := inode^.pipe_i.start and (4096 - 1);
			inode^.size -= chars;
			ret += chars;
			buf += chars;
		end;
	end;

	{ Waking up processes which were waiting for the pipe's data to change }
	if (inode^.pipe_i.wait <> NIL) then
		 wake_up(@inode^.pipe_i.wait);

	{$IFDEF DEBUG_PIPE_READ}
		print_bochs('pipe_read (%d): result=%d\n', [current^.pid, ret]);
	{$ENDIF}

	result := ret;

end;



{******************************************************************************
 * pipe_write
 *
 *****************************************************************************}
function pipe_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [public, alias : 'PIPE_WRITE'];

var
	ret, chars	: dword;
	inode 		: P_inode_t;
	pipebuf		: pointer;

label again, chunk_again;

begin

	if (count = 0) then
	begin
		result := 0;
		exit;
	end;

	ret   := 0;
	inode := fichier^.inode;

	{$IFDEF DEBUG_PIPE_WRITE}
		print_bochs('pipe_write (%d): count=%d buf=%h PIPE_LEN=%d\n',
		[current^.pid, count, buf, PIPE_LEN(inode)]);
	{$ENDIF}

	if (inode^.pipe_i.lock <> 0) then
	begin
		if (fichier^.flags and O_NONBLOCK) = O_NONBLOCK then
		begin
			result := -EAGAIN;
			exit;
		end
		else
		begin
			unlock_inode(inode);
			interruptible_sleep_on(@inode^.pipe_i.wait);
			lock_inode(inode);
			goto again;
		end;
	end
	else
		inode^.pipe_i.lock := 1;

	{ OK, now we have the write lock }

again:

   if (inode^.pipe_i.readers = 0) then
   { The pipe is "broken", there are no readers. }
   begin
		{$IFDEF DEBUG_PIPE_WRITE}
			print_bochs('pipe_write (%d): broken pipe !!!\n', [current^.pid]);
		{$ENDIF}
      send_sig(SIGPIPE, current);
      result := -EPIPE;
      exit;
   end;

chunk_again:

	chars   := PIPE_MAX_WCHUNK(inode);
	pipebuf := pointer(PIPE_BASE(inode) + PIPE_END(inode));

	if (chars > count) then chars := count;

	{$IFDEF DEBUG_PIPE_WRITE}
		print_bochs('pipe_write (%d): copying %d bytes from %h to %d (count=%d)\n',
		[current^.pid, chars, buf, longint(pipebuf) - longint(inode^.pipe_i.base), count]);
	{$ENDIF}

	memcpy(buf, pipebuf, chars);

	count -= chars;
	ret   += chars;
	inode^.size += chars;

	if (count <> 0) then
	{ Do we have to continue ? }
	begin
		if (PIPE_FREE(inode) <> 0) then
		{ Is there another chunk to write ? }
			 goto chunk_again
		else
		{ We have to wait to continue }
		begin
			if (fichier^.flags and O_NONBLOCK) = O_NONBLOCK then
			begin
				{$IFDEF DEBUG_PIPE_WRITE}
					print_bochs('pipe_write (%d): non-blocking file => result=%d\n',
					[current^.pid, ret]);
				{$ENDIF}
				result := ret;
				inode^.pipe_i.lock := 0;
				exit;
			end
			else
			begin
				{ Waking up processes which were waiting for the pipe's data to change }
				if (inode^.pipe_i.wait <> NIL) then
		 			 wake_up(@inode^.pipe_i.wait);

				{$IFDEF DEBUG_PIPE_WRITE}
					print_bochs('pipe_write (%d): WAITING\n', [current^.pid]);
				{$ENDIF}
				unlock_inode(inode);
				interruptible_sleep_on(@inode^.pipe_i.wait);
				lock_inode(inode);
				{$IFDEF DEBUG_PIPE_WRITE}
					print_bochs('pipe_write (%d): UP\n', [current^.pid]);
				{$ENDIF}
				goto again;
			end;
		end;
	end;

	{$IFDEF DEBUG_PIPE_WRITE}
		print_bochs('pipe_write (%d): result=%d\n', [current^.pid, ret]);
	{$ENDIF}

	inode^.pipe_i.lock := 0;
	result := ret;

end;



{******************************************************************************
 * pipe_wait
 *
 *****************************************************************************}
procedure pipe_wait (inode : P_inode_t);
begin
	unlock_inode(inode);
	interruptible_sleep_on(@inode^.pipe_i.wait);
	lock_inode(inode);
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
		wake_up(@fichier^.inode^.pipe_i.wait);
   end;

   result := 0;

	{$IFDEF DEBUG_PIPE_CLOSE}
		print_bochs('pipe_close (%d): EXITING\n', [current^.pid]);
	{$ENDIF}

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
