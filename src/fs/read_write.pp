{******************************************************************************
 *  read_write.pp
 * 
 *  seek(), read() and write() system calls management
 *
 *  CopyLeft 2002 GaLi
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


{DEFINE DEBUG}


{$I errno.inc}
{$I fs.inc}
{$I process.inc}
{$I sched.inc }


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


function  IS_REG (inode : P_inode_t) : boolean; external;
procedure printk (format : string ; args : array of const); external;



IMPLEMENTATION



{******************************************************************************
 * sys_lseek
 *
 *****************************************************************************}
function sys_lseek (fd, offset, whence : dword) : dword; cdecl; [public, alias : 'SYS_LSEEK'];

var
   fichier : P_file_t;

begin

   asm
      sti   { Put interrupts on }
   end;

   if (fd >= OPEN_MAX) then
       begin
          printk('VFS (lseek): fd number is too big (%d)\n', [fd]);
	  result := -EBADF;
	  exit;
       end;

   fichier := current^.file_desc[fd];

   if (fichier = NIL) then
       begin
          printk('VFS (lseek): fd %d is not a valid file desciptor\n', [fd]);
	  result := -EBADF;
	  exit;
       end;

   if (fichier^.inode = NIL) then
       begin
          printk('VFS (lseek): inode not defined fo fd %d (kernel bug ???)\n', [fd]);
	  result := -EBADF;
	  exit;
       end;

   if (IS_REG(fichier^.inode)) then
       begin
          case (whence) of
             SEEK_SET: begin
                          if (offset > fichier^.inode^.size) then
		              begin
		                 printk('VFS (lseek): offset > file size\n', []);
			         result := -EINVAL;
			         exit;
		              end
		          else
		              fichier^.pos := offset;
                        end;
             SEEK_CUR: begin
                          if (fichier^.pos + offset > fichier^.inode^.size) then
		              begin
		                 printk('VFS (lseek): current ofs + ofs > file size\n', []);
			         result := -EINVAL;
			         exit;
		              end
		          else
		              fichier^.pos += offset;
                        end;
             SEEK_END: begin
                          printk('VFS (lseek): cannot add offset to current file size (not supported)\n', []);
		          result := -ENOSYS;   { May we could return another value ??? }
		          exit;
                       end;
             else
                begin
		   printk('VFS (lseek): whence parameter has a bad value (%d)\n', [whence]);
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
	        printk('VFS (lseek): no seek operation defined for this file\n', []);
		result := -ENOSYS;   { May we could return another value ??? }
	     end
	 else
	     begin
	        result := fichier^.op^.seek(fichier, offset, whence);
	     end;
      end;

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
function sys_read (fd : dword ; buf : pointer ; count : dword) : dword; cdecl; [public, alias : 'SYS_READ'];

var
   fichier : P_file_t;

begin

{ FIXME: It may be great to check if we have read right !!! }

   asm
      sti   { Put interrupts on }
   end;

   { Check parameters }
   
   if (fd >= OPEN_MAX) then
       begin
          printk('VFS (read): fd is too big (%d)\n', [fd]);
	  result := -1;
	  exit;
       end;
   if (count < 0) then
       begin
          printk('VFS (read): count < 0 (%d)\n', [count]);
	  result := -1;
	  exit;
       end;

   fichier := current^.file_desc[fd];

   if (fichier = NIL) then
       begin
          printk('VFS (read): fd %d not defined\n', [fd]);
	  result := -1;
	  exit;
       end;
   if (fichier^.inode = NIL) then
       begin
          printk('VFS (read): inode not defined for fd %d\n', [fd]);
	  result := -1;
	  exit;
       end;
   if (fichier^.op = NIL) then
       begin
          printk('VFS (read): file operations not defined for fd %d\n', [fd]);
	  result := -1;
	  exit;
       end;
   if (fichier^.op^.read = NIL) then
       begin
          printk('VFS (read): read operation not defined for fd %d\n', [fd]);
	  result := -1;
	  exit;
       end;

   if (count = 0) then
      begin
         result := 0;
         exit;
      end;

   result := fichier^.op^.read(fichier, buf, count);

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

{ FIXME: Il faudrait verifier si on a le droit d'écrire !!! }

   {$IFDEF DEBUG}
      printk('sys_write: going to write %d bytes from %h to file %d\n', [count, buf, fd]);
   {$ENDIF}

   asm
      sti   { Put interrupts on }
   end;


   { Check parameters }

   if (fd >= OPEN_MAX) then
       begin
          printk('VFS (write): fd is too big (%d)\n', [fd]);
	  result := -1;
	  exit;
       end;
   
   
   if (count < 0) then
       begin
          printk('VFS (write): count < 0 (%d)\n', [count]);
	  result := -1;
	  exit;
       end;
   
   fichier := current^.file_desc[fd];   
   
   if (fichier = NIL) then
      begin
         printk('VFS (write): fd %d not defined\n', [fd]);
         result := -1;
	 exit;
      end;

   if (fichier^.inode = NIL) then
      begin
         printk('VFS (write): inode not defined for fd %d\n', [fd]);
         result := -1;
	 exit;
      end;

   if (fichier^.op = NIL) then
      begin
         printk('VFS (write): file operations not defined for fd %d\n', [fd]);
         result := -1;
	 exit;
      end;

   if (fichier^.op^.write = NIL) then
      begin
         printk('VFS (write): write operation not defined for fd %d\n', [fd]);
         result := -1;
	 exit;
      end;

   if (count = 0) then
      begin
         result := 0;
         exit;
      end;

   result := fichier^.op^.write(fichier, buf, count);

end;



begin
end.
