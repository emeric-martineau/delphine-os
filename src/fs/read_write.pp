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
          printk('lseek: fd is > %d\n', [OPEN_MAX - 1]);
	  result := -1;
	  exit;
       end;

   fichier := current^.file_desc[fd];

   if (fichier = NIL) then
       begin
          printk('lseek fd %d is not a valid file desciptor\n', [fd]);
	  result := -1;
	  exit;
       end;

   if (IS_REG(fichier^.inode)) then
       begin
          case (whence) of
             SEEK_SET: begin
                          if (offset > fichier^.inode^.size) then
		              begin
		                 printk('lseek: offset > file size\n', []);
			         result := -1;
			         exit;
		              end
		          else
		              fichier^.pos := offset;
                        end;
             SEEK_CUR: begin
                          if (fichier^.pos + offset > fichier^.inode^.size) then
		              begin
		                 printk('lseek: current ofs + ofs > file size\n', []);
			         result := -1;
			         exit;
		              end
		          else
		              fichier^.pos += offset;
                        end;
             SEEK_END: begin
                          printk('lseek: cannot add offset to current file size (not supported)\n', []);
		          result := -1;
		          exit;
                       end;
             else
                begin
		   printk('lseek: whence parameter has a bad value (%d)\n', [whence]);
		   result := -1;
		   exit;
		end;
          end;
          result := fichier^.pos;
       end
   else
      begin
         if (fichier^.op = NIL) or (fichier^.op^.seek = NIL) then
	     begin
	        printk('seek: no seek operation defined for this file\n', []);
		result := -1;
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

{ NOTE : It may be great to check if we have read right !!! }

   asm
      sti   { Put interrupts on }
   end;

   fichier := current^.file_desc[fd];

   { Check parameters }
   
   {$IFNDEF DEBUG}
   if ((fd >= OPEN_MAX) or (count < 0) or (fichier = NIL)
    or (fichier^.inode = NIL) or (fichier^.op = NIL)
    or (fichier^.op^.read = NIL)) then
      begin
         printk('VFS (read): cannot read file\n', []);
         result := -1;
	 exit;
      end;
   {$ELSE}
   if (fd >= NR_OPEN) then
       begin
          printk('VFS (read): fd is too big (%d)\n', [fd]);
	  result := -1;
	  exit;
       end;
   if (count < 0) then
       begin
          printk('VFS (read): count < 0\n', []);
	  result := -1;
	  exit;
       end;
   if (fichier = NIL) then
       begin
          printk('VFS (read): fd not defined\n', []);
	  result := -1;
	  exit;
       end;
   if (fichier^.inode = NIL) then
       begin
          printk('VFS (read): file inode not defined\n', []);
	  result := -1;
	  exit;
       end;
   if (fichier^.op = NIL) then
       begin
          printk('VFS (read): file operations not defined\n', []);
	  result := -1;
	  exit;
       end;
   if (fichier^.op^.read = NIL) then
       begin
          printk('VFS (read): read operation not defined\n', []);
	  result := -1;
	  exit;
       end;
   {$ENDIF}

   if (count = 0) then
      begin
         result := 0;
         exit;
      end;

   if (fichier^.op <> NIL) and (fichier^.op^.read <> NIL) then
       result := fichier^.op^.read(fichier, buf, count)
   else
       begin
          printk('VFS: read operation is not defined for file %d\n', [fd]);
	  result := -1;
       end;

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

{ NOTE : Il faudrait verifier si on a le droit d'écrire !!! }

   asm
      sti   { Put interruptions on }
   end;

   fichier := current^.file_desc[fd];

   { Verification des paramètres }
   if ((fd >= OPEN_MAX) or (count < 0) or (fichier = NIL)) then
      begin
         printk('VFS (write): wrong parameters !!!\n', []);
         result := -1;
	 exit;
      end;

   if (count = 0) then
      begin
         result := 0;
         exit;
      end;

   if (fichier^.op <> NIL) and (fichier^.op^.write <> NIL) then
       result := fichier^.op^.write(fichier, buf, count)
   else
       begin
          printk('VFS: write operation is not defined for file %d\n', [fd]);
	  result := -1;
       end;

end;



begin
end.
