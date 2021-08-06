{******************************************************************************
 *  read_write.pp
 * 
 *  lseek(), read() and write() system calls management
 *
 *  CopyLeft 2003 GaLi
 *
 *  version 0.0 - ??/??/2001 - GaLi - initial version
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit read_write;


INTERFACE


{$DEFINE SHOW_SYS_READ_ERRORS}
{$DEFINE SHOW_SYS_WRITE_ERRORS}

{DEFINE DEBUG_SYS_LSEEK}
{DEFINE DEBUG_SYS_READ}
{DEFINE DEBUG_SYS_WRITE}


{$I errno.inc}
{$I fs.inc}
{$I process.inc}
{$I sched.inc }


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


function  IS_REG (inode : P_inode_t) : boolean; external;
procedure lock_inode (inode : P_inode_t); external;
procedure printk (format : string ; args : array of const); external;
procedure unlock_inode (inode : P_inode_t); external;


function  sys_lseek (fd, offset, whence : dword) : dword; cdecl;
function  sys_read (fd : dword ; buf : pointer ; count : longint) : dword; cdecl;
function  sys_write (fd : dword ; buf : pointer ; count : dword) : dword; cdecl;



IMPLEMENTATION


{$I inline.inc}


{******************************************************************************
 * sys_lseek
 *
 * whence values:
 * 	0 : Set offset to 'offset'
 * 	1 : Add 'offset' to current position
 * 	2 : Add 'offset' to current file size
 *
 *****************************************************************************}
function sys_lseek (fd, offset, whence : dword) : dword; cdecl; [public, alias : 'SYS_LSEEK'];

var
   fichier : P_file_t;

begin

	sti();

   result  := -EBADF;
   fichier := current^.file_desc[fd];

   if (fd >= OPEN_MAX) or (fichier = NIL) then exit;

   {$IFDEF DEBUG_SYS_LSEEK}
      printk('sys_lseek (%d): fd=%d  ofs=%d  whence=%d  fichier^.pos=%d  ',
				 [current^.pid, fd, offset, whence, fichier^.pos]);
   {$ENDIF}

   if (fichier^.inode = NIL) then
   begin
      printk('sys_lseek: inode not defined fo fd %d (kernel bug ???)\n', [fd]);
      exit;
   end;

   if (IS_REG(fichier^.inode)) then
   begin
      case (whence) of
      	SEEK_SET: begin
	                	 fichier^.pos := offset;
                   end;
         SEEK_CUR: begin
							 if (longint(fichier^.pos + offset) < 0) then
							 begin
							 	 result := -EINVAL;
								 exit;
							 end;
                      if (fichier^.pos + offset > fichier^.inode^.size) then
		      			 begin
		         		 	 printk('sys_lseek: current ofs + ofs > file size (fd=%d)\n', [fd]);
			 					 result := -EINVAL;
		         			 exit;
		      			 end
		      			 else
		         		    fichier^.pos += offset;
                   end;
         SEEK_END: begin
	               	 if (offset = 0) then
			   			 	  fichier^.pos := fichier^.inode^.size
		      			 else
		      			 begin
                         printk('sys_lseek: cannot add offset to current file size (not supported, fd=%d offset=%d)\n', [fd,offset]);
       		         	 result := -ENOSYS;
		         			 exit;
		      			 end;
                   end;
         else
         begin
	    	   printk('sys_lseek: whence parameter has a bad value (fd=%d, whence=%d)\n', [fd, whence]);
	    		result := -EINVAL;
	    		exit;
	 		end;
      end;
      result := fichier^.pos;
   end
   else
   begin
      if (fichier^.op = NIL) or (fichier^.op^.seek = NIL) then
      begin
         printk('sys_lseek: no seek operation defined for fd %d (ofs=%d whence=%d)\n', [fd, offset, whence]);
	 		result := -ENOSYS;   { FIXME: another error code ??? }
      end
      else
      begin
	 		lock_inode(fichier^.inode);
	 		result := fichier^.op^.seek(fichier, offset, whence);
	 		unlock_inode(fichier^.inode);
      end;
   end;

   {$IFDEF DEBUG_SYS_LSEEK}
      printk('OUT (%d, %d)\n', [result, fichier^.pos]);
   {$ENDIF}

end;



{******************************************************************************
 * sys_read
 *
 * Input : file descriptor number, pointer, count.
 *
 * Output : Bytes read or -1 if error
 *
 * This function is called when a process uses the 'read' system call
 *****************************************************************************}
function sys_read (fd : dword ; buf : pointer ; count : longint) : dword; cdecl; [public, alias : 'SYS_READ'];

var
   fichier : P_file_t;

begin

	sti();

   { Check parameters }

   fichier := current^.file_desc[fd];

   {$IFDEF DEBUG_SYS_READ}
      printk('sys_read (%d): fd=%d  count=%d  pos=%d  ', [current^.pid, fd, count, fichier^.pos]);
   {$ENDIF}

   if (fd >= OPEN_MAX) or (fichier = NIL) then
   begin
      {$IFDEF SHOW_SYS_READ_ERRORS}
      	 printk('sys_read (%d): bad fd (%d)\n', [current^.pid, fd]);
      {$ENDIF}
      result := -EBADF;
      exit;
   end;

   if (count < 0) then
   begin
		{$IFDEF SHOW_SYS_READ_ERRORS}
      	printk('sys_read (%d): count < 0 (%d)\n', [current^.pid, count]);
		{$ENDIF}
      result := -EINVAL;
      exit;
   end;

   if (fichier^.inode = NIL) then
   begin
		{$IFDEF SHOW_SYS_READ_ERRORS}
      	printk('sys_read (%d): inode not defined for fd %d\n', [current^.pid, fd]);
		{$ENDIF}
      result := -EBADF;
      exit;
   end;

   if (fichier^.op = NIL) then
   begin
		{$IFDEF SHOW_SYS_READ_ERRORS}
      	printk('sys_read (%d): file operations not defined for fd %d\n', [current^.pid, fd]);
		{$ENDIF}
      result := -1;
      exit;
   end;

   if (fichier^.op^.read = NIL) then
   begin
      {$IFDEF SHOW_SYS_READ_ERRORS}
			printk('sys_read (%d): read operation not defined for fd %d\n', [current^.pid, fd]);
      {$ENDIF}
		result := -1;
      exit;
   end;

{	if (buf < pointer(BASE_ADDR)) then
	begin
		{$IFDEF SHOW_SYS_READ_ERRORS}
			printk('sys_read (%d): buf=%h\n', [current^.pid, buf]);
		{$ENDIF}
		result := -EFAULT;
		exit;
	end;}

   if (count = 0) then
   begin
      result := 0;
      exit;
   end;

   if (fichier^.flags = O_WRONLY) then
   begin
		{$IFDEF SHOW_SYS_READ_ERRORS}
			printk('sys_read (%d): permission denied\n', [current^.pid]);
		{$ENDIF}
      result := -EPERM;
      exit;
   end;

   lock_inode(fichier^.inode);
   result := fichier^.op^.read(fichier, buf, count);
   unlock_inode(fichier^.inode);

   {$IFDEF DEBUG_SYS_READ}
      printk('OUT (%d)\n', [result]);
   {$ENDIF}

end;



{******************************************************************************
 * sys_write
 *
 * Entrée : descripteur de fichier, pointeur, count.
 *
 * Sortie : Nombre d'octets ecrits ou -1 en cas d'erreur
 *
 * Cette fonction est appelée lors d'un appel système 'write'
 *****************************************************************************}
function sys_write (fd : dword ; buf : pointer ; count : dword) : dword; cdecl; [public, alias : 'SYS_WRITE'];

var
   fichier : P_file_t;

begin

	sti();

   { Check parameters }

   fichier := current^.file_desc[fd];   

   {$IFDEF DEBUG_SYS_WRITE}
      printk('sys_write (%d): fd=%d  count=%d  pos=%d  ', [current^.pid, fd, count, fichier^.pos]);
   {$ENDIF}

   if (fd >= OPEN_MAX) or (fichier = NIL) then
   begin
      {$IFDEF SHOW_SYS_WRITE_ERRORS}
      	 printk('sys_write (%d): bad fd (%d)\n', [current^.pid, fd]);
      {$ENDIF}
      result := -EBADF;
      exit;
   end;
   
   
   if (count < 0) then
   begin
		{$IFDEF SHOW_SYS_WRITE_ERRORS}
      	printk('sys_write (%d): count < 0 (%d)\n', [current^.pid, count]);
		{$ENDIF}
      result := -EINVAL;
      exit;
   end;
   
   if (fichier^.inode = NIL) then
   begin
		{$IFDEF SHOW_SYS_WRITE_ERRORS}
      	printk('sys_write (%d): inode not defined for fd %d\n', [current^.pid, fd]);
      {$ENDIF}
		result := -EBADF;
      exit;
   end;

   if (fichier^.op = NIL) then
   begin
		{$IFDEF SHOW_SYS_WRITE_ERRORS}
      	printk('sys_write (%d): file operations not defined for fd %d\n', [current^.pid, fd]);
      {$ENDIF}
		result := -1;
      exit;
   end;

   if (fichier^.op^.write = NIL) then
   begin
		{$IFDEF SHOW_SYS_WRITE_ERRORS}
      	printk('sys_write (%d): write operation not defined for fd %d\n', [current^.pid, fd]);
      {$ENDIF}
		result := -1;
      exit;
   end;

   if (count = 0) then
   begin
      result := 0;
      exit;
   end;

   if ((fichier^.flags and (O_RDWR or O_WRONLY)) <> 0) then
   begin
      lock_inode(fichier^.inode);
      result := fichier^.op^.write(fichier, buf, count);
      unlock_inode(fichier^.inode);
   end
   else
      result := -EPERM;

   {$IFDEF DEBUG_SYS_WRITE}
      printk('OUT (%d)\n', [result]);
   {$ENDIF}

end;



begin
end.
