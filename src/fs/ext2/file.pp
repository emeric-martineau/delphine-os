{******************************************************************************
 *  file.pp
 *
 *  Ext2 filesystem files management.
 *
 *  Copyleft 2002
 *
 *  version 0.0 - 12/09/2002 - GaLi - Work in progess...
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


unit _ext2_file;


INTERFACE


{$I buffer.inc}
{$I ext2.inc}
{$I fs.inc}


{DEFINE DEBUG}


{* External procedure and functions *}
function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
function  buffer_uptodate (bh : P_buffer_head) : boolean; external;
function  kmalloc (len : dword) : pointer; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure printk (format : string ; args : array of const); external;


{* External variables *}

var
   ext2_file_operations : file_operations;
   ext2_file_inode_operations : inode_operations;


{* Procedures and functions only used in THIS file *}
function  get_real_block (block : dword ; inode : P_inode_t) : dword;



IMPLEMENTATION



{******************************************************************************
 * ext2_file_read
 *
 * Input : file descriptor, pointer to buffer, number of bytes to read
 *
 * Output : bytes read or -1
 *
 * Read a file on an ext2 filesystem
 *
 * WARNING : NOT FULLY TESTED, but it should work :-)
 *****************************************************************************}
function ext2_file_read (fichier : P_file_t ; buffer : pointer ; count : dword) : dword; [public, alias : 'EXT2_FILE_READ'];

var
   block        : dword; { Block to read }
   real_block   : dword;
   nb_blocks    : dword; { Number of blocks to read }
   blocksize    : dword; { Logical filesystem block size in bytes }
   i, file_ofs  : dword;
   major, minor : byte;
   inode        : P_inode_t;
   bh           : P_buffer_head;

   test : pointer;
   test1 : dword;
   save : pointer;
begin

   {$IFDEF DEBUG}
      save := buffer;
   {$ENDIF}

   blocksize   := fichier^.inode^.sb^.blocksize;

   {$IFDEF DEBUG}
      printk('ext2_file_read: going to read %d bytes to %h (blocksize=%d)\n', [count, buffer, blocksize]);
   {$ENDIF}

   if (fichier^.pos + count > fichier^.inode^.size) then
       begin
          while (fichier^.pos + count > fichier^.inode^.size) do
	         count -= 1;
	  {$IFDEF DEBUG}
	     printk('ext2_file_read: modify count to %d\n', [count]);
	  {$ENDIF}
       end;

   result      := count;   { If everything is ok, this will be the result }
   major       := fichier^.inode^.dev_maj;
   minor       := fichier^.inode^.dev_min;
   inode       := fichier^.inode;
   block       := (fichier^.pos + blocksize) div blocksize;
   file_ofs    := fichier^.pos;
   nb_blocks   := count div blocksize;
   if (count mod blocksize <> 0) then
       nb_blocks += 1;

   {$IFDEF DEBUG}
      printk('ext2_file_read: going to read %d blocks from block %d (file_ofs=%d)\n', [nb_blocks, block, file_ofs]);
   {$ENDIF}

   { while count > 0 ??? }
   for i := block to (block + nb_blocks - 1) do
   begin
      real_block := get_real_block(block, inode);
      {$IFDEF DEBUG}
         printk('ext2_file_read: reading block %d (%d)\n', [i, real_block]);
      {$ENDIF}
      bh := bread(major, minor, real_block, blocksize);
      if (bh = NIL) then
          begin
	     printk('ext2_file_read: unable to read block %d\n', [real_block]);
	     result := -1;
	     exit;
	  end;

      {$IFDEF DEBUG}
         test := bh^.data;
         asm
            mov esi, test
            mov eax, [esi]
            mov test1, eax
         end;
         printk('ext2 (data): %d %h ', [block, test1]);
      {$ENDIF}

      { Copying data to buffer }
      {$IFDEF DEBUG}
         printk('ext2_file_read: copying %d bytes from block %d (block_ofs=%d)\n', [(block*blocksize)-file_ofs, i, file_ofs-((block-1)*blocksize)]);
      {$ENDIF}
      memcpy(pointer(bh^.data + file_ofs-((block-1)*blocksize)), buffer, (block*blocksize)-file_ofs);

      buffer   += (block*blocksize)-file_ofs;
      file_ofs += (block*blocksize)-file_ofs;
      block += 1;

   end;

   { Update file position }
   fichier^.pos += count;

   {$IFDEF DEBUG}
      for i := block to (block + nb_blocks - 1) do
      begin
         printk('ext2_file_read: (buffer data): %h @ %h\n', [longint(save^), save]);
         save += blocksize;
      end;
   {$ENDIF}

end;



{******************************************************************************
 * get_real_block
 *
 * Input : logical block number
 *
 * Output : real block number
 *
 * Convert a logical block number into a real block number by reading inode
 * information
 *****************************************************************************}
function get_real_block (block : dword ; inode : P_inode_t) : dword;

var
   blocksize    : dword;
   tmp_block    : dword;
   major, minor : byte;
   buffer       : ^dword;
   bh           : P_buffer_head;

begin

   blocksize := inode^.sb^.blocksize;
   major     := inode^.dev_maj;
   minor     := inode^.dev_min;

   if (block <= 12) then
       result := inode^.ext2_i.data[block]

   else if (block <= (12 + (blocksize div 4))) then
       begin
          tmp_block  := inode^.ext2_i.data[13];
          bh := bread(major, minor, tmp_block, blocksize);
	  if (bh = NIL) then
	      begin
	         printk('EXT2-fs (read_file: unable to read block %d\n', [tmp_block]);
		 result := 0;
	      end;
	  buffer := bh^.data;
	  result := buffer[(block - 12) - 1];
       end
   else
       begin
          printk('EXT2-fs (read file): unable to read block %d (not supported)\n', [block]);
	  result := 0;
       end;
end;



begin
end.
