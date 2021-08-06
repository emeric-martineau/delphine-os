{******************************************************************************
 *  pipe.pp
 *
 *  Pipes management
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

{* Local macros *}

{$DEFINE PIPE_CLOSE_WARNING}
{DEFINE DEBUG_PIPE_CLOSE}
{DEFINE DEBUG_PIPE_READ}
{DEFINE DEBUG_PIPE_WRITE}
{DEFINE DEBUG_SYS_PIPE}

{* External procedure and functions *}

function  alloc_inode : P_inode_t; external;
procedure free_inode (inode : P_inode_t); external;
function  get_free_page : pointer; external;
procedure interruptible_sleep_on (p : PP_wait_queue); external;
procedure interruptible_wake_up (p : PP_wait_queue); external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure lock_inode (inode : P_inode_t); external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_addr : pointer); external;
procedure unlock_inode (inode : P_inode_t); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure init_pipe;
function  pipe_close (fichier : P_file_t) : dword;
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

   pipe_file_operations.open  := NIL;
   pipe_file_operations.read  := @pipe_read;
   pipe_file_operations.write := @pipe_write;
   pipe_file_operations.close := @pipe_close;
   pipe_file_operations.seek  := NIL;
   pipe_file_operations.ioctl := NIL;

end;



{******************************************************************************
 * pipe_read
 *
 *****************************************************************************}
function pipe_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [public, alias : 'PIPE_READ'];

var
   pipe_size  : dword;   { Nb of bytes in the pipe that have not been read }

begin

   pipe_size  := fichier^.inode^.size;

   {$IFDEF DEBUG_PIPE_READ}
      printk('pipe_read (%d): pipe_size=%d  count=%d\n', [current^.pid, pipe_size, count]);
   {$ENDIF}

   if (pipe_size = 0) then
   begin
      if (fichier^.inode^.pipe_i.writers = 0) then
      begin
         {$IFDEF DEBUG_PIPE_READ}
	    printk('pipe_read (%d): no writers, result=0.\n', [current^.pid]);
	 {$ENDIF}
         result := 0;
	 exit;
      end
      else
      begin
         {$IFDEF DEBUG_PIPE_READ}
            printk('pipe_read (%d): going to wait for some data\n', [current^.pid]);
         {$ENDIF}
	 interruptible_sleep_on(@fichier^.inode^.pipe_i.wait);
      end;
   end
   else if (count > pipe_size) then
   begin
      {$IFDEF DEBUG_PIPE_READ}
         printk('pipe_read (%d): going to read %d bytes from %h\n', [current^.pid, pipe_size,
	 							     fichier^.inode^.pipe_i.base +
								     fichier^.inode^.pipe_i.start]);
      {$ENDIF}
      memcpy(fichier^.inode^.pipe_i.base + fichier^.inode^.pipe_i.start, buf, pipe_size);
      fichier^.inode^.size := 0;
      result := pipe_size;
   end
   else
   begin
      {$IFDEF DEBUG_PIPE_READ}
         printk('pipe_read (%d): going to read %d bytes from %h\n', [current^.pid, pipe_size,
	 							     fichier^.inode^.pipe_i.base +
								     fichier^.inode^.pipe_i.start]);
      {$ENDIF}
      memcpy(fichier^.inode^.pipe_i.base + fichier^.inode^.pipe_i.start, buf, count);
      fichier^.inode^.size := pipe_size - count;
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

begin

   {FIXME: check if buf has a correct value }

   if (fichier^.inode^.pipe_i.readers = 0) then
   { The pipe is "broken", there are no readers. }
   begin
      { FIXME: we have to send a SIGPIPE signal }
      result := -EPIPE;
      exit;
   end;

   pipe_size  := fichier^.inode^.size;
   pipe_free  := 4096 - pipe_size;

   {$IFDEF DEBUG_PIPE_WRITE}
      printk('pipe_write (%d): pipe_size=%d  pipe_free=%d  count=%d\n', [current^.pid, pipe_size,
      									 pipe_free, count]);
   {$ENDIF}

   if (pipe_free >= count) then
   begin
      {$IFDEF DEBUG_PIPE_WRITE}
         printk('pipe_write (%d): going to write %d bytes at %h\n', [current^.pid, count,
	 							     fichier^.inode^.pipe_i.base +
								     pipe_size]);
      {$ENDIF}
      memcpy(buf, fichier^.inode^.pipe_i.base + pipe_size, count);
      fichier^.inode^.size += count;
      result := count;
   end
   else if (count > 4096) then
   begin
      {$IFDEF DEBUG_PIPE_WRITE}
         printk('pipe_write (%d): going to write %d bytes at %h\n', [current^.pid, pipe_free,
	 							     fichier^.inode^.pipe_i.base +
								     fichier^.inode^.pipe_i.start]);
      {$ENDIF}
      memcpy(buf, fichier^.inode^.pipe_i.base + fichier^.inode^.pipe_i.start, pipe_free);
      result := pipe_free;
   end
   else
   begin
      {$IFDEF DEBUG_PIPE_WRITE}
         printk('pipe_write (%d): going to write %d bytes at %h\n', [current^.pid, count,
	 							     fichier^.inode^.pipe_i.base +
								     fichier^.inode^.pipe_i.start]);
         printk('pipe_write (%d): we have to wait for more free bytes in the pipe\n', [current^.pid]);
      {$ENDIF}
   end;

   if (fichier^.inode^.pipe_i.wait <> NIL) then
   begin
      {$IFDEF DEBUG_PIPE_WRITE}
         printk('pipe_write (%d): waking up a process\n', [current^.pid]);
      {$ENDIF}
      interruptible_wake_up(@fichier^.inode^.pipe_i.wait);
   end;

   {$IFDEF DEBUG_PIPE_WRITE}
      printk('pipe_write (%d): exiting. result=%d\n', [current^.pid, result]);
   {$ENDIF}

end;



{******************************************************************************
 * pipe_close
 *
 *****************************************************************************}
function pipe_close (fichier : P_file_t) : dword; [public, alias : 'PIPE_CLOSE'];
begin

   {$IFDEF DEBUG_PIPE_CLOSE}
      printk('pipe_close (%d): readers=%d  writers=%d\n', [current^.pid, fichier^.inode^.pipe_i.readers,
      							   fichier^.inode^.pipe_i.writers]);
   {$ENDIF}

   if (fichier^.inode^.pipe_i.wait <> NIL) then
   begin
      {$IFDEF PIPE_CLOSE_WARNING}
         printk('pipe_close (%d): pipe wait queue is not empty\n', [current^.pid]);
      {$ENDIF}
      {FIXME: do something clean }
      while (fichier^.inode^.pipe_i.wait <> NIL) do
             interruptible_wake_up(@fichier^.inode^.pipe_i.wait);
   end;

   if (fichier^.flags = O_RDONLY) then
   begin
      fichier^.inode^.pipe_i.readers := 0;
      if (fichier^.inode^.pipe_i.writers = 0) then
      { No one uses the pipe anymore }
      begin
         {$IFDEF DEBUG_PIPE_CLOSE}
	    printk('pipe_close (%d): ...a reader closed the pipe and there are no more writers\n', [current^.pid]);
	 {$ENDIF}
         push_page(fichier^.inode^.pipe_i.base);
      end;
   end
   else
   begin
      fichier^.inode^.pipe_i.writers := 0;
      if (fichier^.inode^.pipe_i.readers = 0) then
      { No one uses the pipe anymore }
      begin
         {$IFDEF DEBUG_PIPE_CLOSE}
	    printk('pipe_close (%d): ...a writer closed the pipe and there are no more readers\n', [current^.pid]);
	 {$ENDIF}
         push_page(fichier^.inode^.pipe_i.base);
      end;
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

   {FIXME: check if fildes is a valid pointer for the current process }

   { Look for new file descriptor }
   f0 := 0;
   while (current^.file_desc[f0] <> NIL) and (f0 < OPEN_MAX) do
          f0 += 1;

   if (current^.file_desc[f0] <> NIL) then
   begin
      result := -EMFILE;
      exit;
   end;

   current^.file_desc[f0] := 1;   { Temp value }

   { Do the same thing for f1 }
   f1 := 0;
   while (current^.file_desc[f1] <> NIL) and (f1 < OPEN_MAX) do
          f1 += 1;

   if (current^.file_desc[f1] <> NIL) then
   begin
      result := -EMFILE;
      exit;
   end;

   { f0 and f1 are now initialized. We have to allocate 2 file objects and 1 inode object }

   {$IFDEF DEBUG_SYS_PIPE}
      printk('sys_pipe (%d): fd %d to read, fd %d to write\n', [current^.pid, f0, f1]);
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
   inode^.pipe_i.base    := buf;
   inode^.pipe_i.start   := 0;
   inode^.pipe_i.wait    := NIL;
   inode^.pipe_i.lock    := 0;
   inode^.pipe_i.readers := 1;
   inode^.pipe_i.writers := 1;

   current^.file_desc[f0] := fichier0;
   current^.file_desc[f1] := fichier1;

   longint(fildes^) := f0;
   longint(fildes)  += 4;
   longint(fildes^) := f1;

   {$IFDEF DEBUG_SYS_PIPE}
      printk('sys_pipe (%d): base address=%h\n', [current^.pid, buf]);
   {$ENDIF}

   result := 0;

end;



begin
end.
