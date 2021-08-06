{******************************************************************************
 *  filename.pp
 *
 *  Ext2 directories management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 14/06/2003 - GaLi - Initial version
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


unit unit_name;


INTERFACE


{* Headers *}

{$I ext2.inc}
{$I fs.inc}

{* Local macros *}

{DEFINE DEBUG_EXT2_READDIR}

{* External procedure and functions *}

function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
function  ext2_get_real_block (block : dword ; inode : P_inode_t) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure printk (format : string ; args : array of const); external;

{* External variables *}


{* Exported variables *}


{* Procedures and functions defined in this file *}

function  ext2_readdir (fichier : P_file_t ; dirent : P_dirent_t ; count : dword) : dword;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * ext2_readdir
 *
 * FIXME: Check if the return value is correct
 *****************************************************************************}
function  ext2_readdir (fichier : P_file_t ; dirent : P_dirent_t ; count : dword) : dword; [public, alias : 'EXT2_READDIR'];

var
   block, real_block : dword;
   blocksize         : dword; { Logical filesystem block size in bytes }
   res               : dword;
   major, minor      : byte;
   dir_entry         : P_ext2_dir_entry;
   inode             : P_inode_t;
   fin               : boolean;
   bh                : P_buffer_head;

   {$IFDEF DEBUG_EXT2_READDIR}
      i : dword;
   {$ENDIF}

begin

   {$IFDEF DEBUG_EXT2_READDIR}
      printk('Welcome in ext2_readdir (%h, %h, %d)\n', [fichier, dirent, count]);
   {$ENDIF}

   if (fichier^.pos + count > fichier^.inode^.size) then
       begin
          while (fichier^.pos + count > fichier^.inode^.size) do
	         count -= 1;
	  {$IFDEF DEBUG_EXT2_READDIR}
	     printk('ext2_readdir: modify count to %d\n', [count]);
	  {$ENDIF}
       end;

   if (count = 0) then
   begin
      result := 0;
      exit;
   end;

   res       := 0;
   fin       := FALSE;
   major     := fichier^.inode^.dev_maj;
   minor     := fichier^.inode^.dev_min;
   blocksize := fichier^.inode^.sb^.blocksize;
   inode     := fichier^.inode;

   block      := (fichier^.pos + blocksize) div blocksize;
   real_block := ext2_get_real_block(block, inode);

   if (real_block = 0) then
   begin
      printk('ext2_readdir: cannot convert block %d\n', [block]);
      result := -1;
      exit;
   end;

   bh := bread(major, minor, real_block, blocksize);
   if (bh = NIL) then
   begin
      printk('ext2_readdir: unable to read block %d\n', [real_block]);
      result := -1;
      exit;
   end;

   dir_entry := bh^.data;

   while (count > 0) and not fin do
   begin

      dirent^.d_ino    := dir_entry^.inode;
      dirent^.d_off    := 0;   { not used by dietlibc ??? }
      dirent^.d_reclen := {dir_entry^.rec_len} dir_entry^.name_len + 1 + 10;
      memcpy(@dir_entry^.name, @dirent^.d_name, dir_entry^.name_len);
      dirent^.d_name[dir_entry^.name_len] := #0;

      {$IFDEF DEBUG_EXT2_READDIR}
         i := 0;
         while (dirent^.d_name[i] <> #0) do i += 1;
         printk('ext2_readdir: %h (%d)  %h (%d) : %s (%d + 11) res=%d\n', [dir_entry, dir_entry^.rec_len, dirent, dirent^.d_reclen,
								           @dirent^.d_name, i, res]);
      {$ENDIF}

      count -= dir_entry^.rec_len;
      fichier^.pos += dir_entry^.rec_len;

      {if (dir_entry^.inode = 0) or (dir_entry^.rec_len = 0) then fin := TRUE;}

      res                += dirent^.d_reclen;
      longint(dir_entry) += dir_entry^.rec_len;
      longint(dirent)    += dirent^.d_reclen;

   end; { while }

   {$IFDEF DEBUG_EXT2_READDIR}
      printk('ext2_file_read: EXITING (result=%d)\n', [res]);
   {$ENDIF}

   result := res;

end;



begin
end.
