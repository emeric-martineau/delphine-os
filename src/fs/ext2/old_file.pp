{******************************************************************************
 *  file.pp
 *
 *  Ext2 filesystem files management.
 *
 *  Copyleft 2003
 *
 *  version 0.0 - 12/09/2002 - GaLi - Initial version
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
{$I config.inc}
{$I errno.inc}
{$I ext2.inc}
{$I fs.inc}
{$I process.inc}


{* External procedure and functions *}

function  alloc_buffer_head (major, minor : byte ; block, size : dword) : P_buffer_head; external;
function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
procedure brelse (bh : P_buffer_head); external;
function  buffer_uptodate (bh : P_buffer_head) : boolean; external;
function  ext2_new_block (inode : P_inode_t) : dword; external;
procedure ext2_write_inode (inode : P_inode_t); external;
procedure free_buffers; external;
procedure insert_buffer_head (bh : P_buffer_head); external;
function  kmalloc (len : dword) : pointer; external;
procedure mark_buffer_dirty (bh : P_buffer_head); external;
procedure mark_inode_dirty (inode : P_inode_t); external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';

var
   ext2_file_operations : file_operations;
   ext2_file_inode_operations : inode_operations;


{* Procedures and functions only used in THIS file *}

function  ext2_file_read (fichier : P_file_t ; buffer : pointer ; count : dword) : dword;
function  ext2_file_write (fichier : P_file_t ; buffer : pointer ; count : dword) : dword;
function  ext2_get_data (block : dword ; inode : P_inode_t) : P_buffer_head;
function  ext2_get_real_block (block : dword ; inode : P_inode_t) : dword;
procedure ext2_set_real_block (block : dword ; inode : P_inode_t ; real_block : dword);



IMPLEMENTATION



function MIN (a, b : dword) : dword;
begin
   if (a < b) then
       result := a
   else
       result := b;
end;



{******************************************************************************
 * ext2_file_read
 *
 * Input : file descriptor, pointer to buffer, number of bytes to read
 *
 * Output : bytes read or -1
 *
 * Read a file on an ext2 filesystem
 *
 * NOTE: code inspired from Linux 0.12 (fs/file_dev.c)
 *
 * WARNING : NOT FULLY TESTED, but it should work :-)
 *****************************************************************************}
function ext2_file_read (fichier : P_file_t ; buffer : pointer ; count : dword) : dword; [public, alias : 'EXT2_FILE_READ'];

var
   blocksize, left : dword;
   nr, chars, pos  : dword;
   major, minor    : byte;
   inode           : P_inode_t;
   bh              : P_buffer_head;

begin

   pos   := fichier^.pos;
   inode := fichier^.inode;

   if (pos + count > inode^.size) then
       count := inode^.size - pos;

   if (count = 0) then
   begin
      result := 0;
      exit;
   end;

   left      := count;
   major     := inode^.dev_maj;
   minor     := inode^.dev_min;
   blocksize := inode^.blksize;

   {$IFDEF DEBUG_EXT2_FILE_READ}
		asm
			mov eax , [ebp + 4]
			mov nr  , eax
		end;
      print_bochs('ext2_file_read: going to read %d bytes to %h (pos=%d) EIP=%h\n', [count, buffer, pos, nr]);
   {$ENDIF}

   while (left <> 0) do
   begin
      nr := ext2_get_real_block(pos div blocksize, inode);
      if (longint(nr) > 0) then
      begin
			bh := bread(major, minor, nr, blocksize);
			if (bh = NIL) then
			begin
				print_bochs('ext2_file_read: unable to read block %d\n', [nr]);
				break;
      	 end;
      end
      else
      	 bh := NIL;

      {$IFDEF DEBUG_EXT2_FILE_READ}
      	 print_bochs('ext2_file_read: nr=%d bh^.data=%h => %h\n', [nr, bh^.data, longint(bh^.data^)]);
      {$ENDIF}

      nr    := pos mod blocksize;
      chars := MIN(blocksize - nr, left);
      pos   += chars;
      left  -= chars;
      if (bh <> NIL) then
      	  memcpy(bh^.data + nr, buffer, chars)
      else
      	  memset(buffer, 0, chars);

      buffer += chars;
      brelse(bh);
   end;

   fichier^.pos := pos;

   if (count - left) = 0 then
       result := -EIO
   else
       result := count - left;

   {$IFDEF DEBUG_EXT2_FILE_READ}
      print_bochs('ext2_file_read: result=%d\n', [result]);
   {$ENDIF}

end;



{******************************************************************************
 * ext2_file_write
 *
 * NOTE: code inspired from Linux 0.12 (fs/file_dev.c)
 *****************************************************************************}
function ext2_file_write (fichier : P_file_t ; buffer : pointer ; count : dword) : dword; [public, alias : 'EXT2_FILE_WRITE'];

var
   i, block, pos   : dword;
   blocksize, c, p : dword;
   major, minor    : byte;
   inode           : P_inode_t;
   bh 	          : P_buffer_head;

label end_write;

begin

   i         := 0;
   pos       := fichier^.pos;
   inode     := fichier^.inode;
   major     := inode^.dev_maj;
   minor     := inode^.dev_min;
   blocksize := inode^.blksize;

   {$IFDEF DEBUG_EXT2_FILE_WRITE}
      print_bochs('ext2_file_write: going to write %d bytes from %h (blocksize=%d)\n', [count, buffer, blocksize]);
   {$ENDIF}

   while (i < count) do
   begin
      block := ext2_get_real_block(pos div blocksize, inode);
      if (longint(block) = -1) then goto end_write;
      if (block = 0) then
      begin
			block := ext2_new_block(inode);
	 		if (block = 0) then goto end_write;
			{$IFDEF DEBUG_EXT2_FILE_WRITE}
	    		print_bochs('ext2_file_write: setting logical block %d to fs block %d\n', [pos div blocksize, block]);
	 		{$ENDIF}
	 		ext2_set_real_block(pos div blocksize, inode, block);

	 		bh := alloc_buffer_head(major, minor, block, blocksize);   { Get an unused buffer }
	 		if (bh = NIL) then goto end_write;
	 		memset(bh^.data, 0, bh^.size);   { Clear it }
	 		bh^.state := BH_Uptodate;
      end
      else
      begin
			{$IFDEF DEBUG_EXT2_FILE_WRITE}
	    		print_bochs('ext2_file_write: going to read block %d\n', [block]);
	 		{$ENDIF}
			bh := bread(major, minor, block, blocksize);
	 		if (bh = NIL) then goto end_write;
      end;

      c := pos mod blocksize;
      p := longint(bh^.data + c);
      c := blocksize - c;
      if (c > count - i) then c := count - i;
      pos += c;
      i   += c;
      {$IFDEF DEBUG_EXT2_FILE_WRITE}
      	 print_bochs('ext2_file_write: bh^.data=%h p=%h (%h)\n', [bh^.data, p, longint(buffer^)]);
      {$ENDIF}
      memcpy(buffer, pointer(p), c);

      buffer += c;
      mark_buffer_dirty(bh);
      brelse(bh);
   end;

end_write:

   if (pos > inode^.size) then
   begin
      inode^.size := pos;
      mark_inode_dirty(inode);
   end;

   fichier^.pos := pos;

   if (i = 0) then
       result := -EIO
   else
       result := i;

	{$IFDEF DEBUG_EXT2_FILE_WRITE}
		print_bochs('ext2_file_write: result=%d\n', [result]);
	{$ENDIF}

end;



{******************************************************************************
 * ext2_get_data
 *
 * INPUT : block -> logical block number
 *         inode -> file inode
 *
 * OUTPUT: NIL on error.
 *
 * Reads block data from disk.
 *****************************************************************************}
function ext2_get_data (block : dword ; inode : P_inode_t) : P_buffer_head; [public, alias : 'EXT2_GET_DATA'];

var
   real_block : dword;
   bh 	     : P_buffer_head;

begin

   result := NIL;

   real_block := ext2_get_real_block(block, inode);
   if (real_block = 0) then
   begin
      print_bochs('ext2_get_data (%d): cannot get real block for block %d\n', [current^.pid, block]);
      exit;
   end;

   bh := bread(inode^.dev_maj, inode^.dev_min, real_block, inode^.blksize);
   if (bh = NIL) then
   begin
      print_bochs('ext2_get_data (%d): cannot read block %d\n', [current^.pid, real_block]);
      exit;
   end;

   result := bh;

end;



{******************************************************************************
 * ext2_get_real_block
 *
 * Input : logical block number
 *
 * Output : real block number, -1 on error
 *
 * Convert a logical block number into a real block number by reading inode
 * information
 *****************************************************************************}
function ext2_get_real_block (block : dword ; inode : P_inode_t) : dword; [public, alias : 'EXT2_GET_REAL_BLOCK'];

var
   blocksize    : dword;
   tmp_block    : dword;
   major, minor : byte;
   buffer       : ^dword;
   bh, bh2      : P_buffer_head;

begin

   blocksize := inode^.blksize;
   major     := inode^.dev_maj;
   minor     := inode^.dev_min;

	{$IFDEF DEBUG_EXT2_GET_REAL_BLOCK}
		print_bochs('ext2_get_real_block: block=%d ', [block]);
	{$ENDIF}

   if (block < EXT2_NDIR_BLOCKS) then
	begin
		{$IFDEF DEBUG_EXT2_GET_REAL_BLOCK}
			print_bochs('direct block\n', []);
		{$ENDIF}
		result := inode^.ext2_i.data[block];
	end

   { Indirection simple }
   else if (block <= (EXT2_NDIR_BLOCKS + (blocksize div 4) - 1)) then
   begin
		{$IFDEF DEBUG_EXT2_GET_REAL_BLOCK}
			print_bochs('simple indirection\n', []);
		{$ENDIF}
      tmp_block := inode^.ext2_i.data[EXT2_IND_BLOCK];
      if (tmp_block = 0) then
      begin
      	result := 0;
	 		exit;
      end;
      bh := bread(major, minor, tmp_block, blocksize);
      if (bh = NIL) then
      begin
	 		print_bochs('ext2_get_real_block: unable to read block %d\n', [tmp_block]);
	 		result := -1;
      end;
      buffer := bh^.data;
      result := buffer[block - EXT2_NDIR_BLOCKS];
      brelse(bh);
   end


   { Indirection double }
   else if (block <= ((EXT2_NDIR_BLOCKS + (blocksize div 4) + ((blocksize div 4) * (blocksize div 4))) - 1)) then
   begin
		{$IFDEF DEBUG_EXT2_GET_REAL_BLOCK}
			print_bochs('double indirection\n', []);
		{$ENDIF}
      tmp_block := inode^.ext2_i.data[EXT2_DIND_BLOCK];
      if (tmp_block = 0) then
      begin
      	result := 0;
	 		exit;
      end;
      bh := bread(major, minor, tmp_block, blocksize);
      if (bh = NIL) then
      begin
         print_bochs('ext2_get_real_block: unable to read block %d\n', [tmp_block]);
         result := -1;
         exit;
      end;

      buffer := bh^.data;

      {$IFDEF DEBUG_EXT2_GET_REAL_BLOCK}
      	 print_bochs('ext2_get_real_block: going to read block %d  (ofs=%d)\n',
      	       		[buffer[(block - (EXT2_NDIR_BLOCKS + (blocksize div 4))) div (blocksize div 4)],
      	       		(block - (EXT2_NDIR_BLOCKS + (blocksize div 4))) div (blocksize div 4)]);
      {$ENDIF}

      if (buffer[(block - (EXT2_NDIR_BLOCKS + (blocksize div 4))) div (blocksize div 4)] = 0) then
      begin
      	result := 0;
	 		brelse(bh);
	 		exit;
      end;

      bh2 := bread(major, minor, buffer[(block - (EXT2_NDIR_BLOCKS + (blocksize div 4))) div (blocksize div 4)], blocksize);
      if (bh2 = NIL) then
      begin
	 		print_bochs('ext2_get_real_block: unable to read block %d\n', [tmp_block]);
	 		result := -1;
	 		exit;
      end;

      buffer := bh2^.data;

      result := buffer[((block - (EXT2_NDIR_BLOCKS + (blocksize div 4))) mod (blocksize div 4))];

      {$IFDEF DEBUG_EXT2_GET_REAL_BLOCK}
      	 print_bochs('ext2_get_real_block: RESULT=%d (ofs=%d)\n',
      	       		[result, (block - (EXT2_NDIR_BLOCKS + (blocksize div 4))) mod (blocksize div 4)]);
      {$ENDIF}

      brelse(bh);
      brelse(bh2);

   end
   else
   begin
		{$IFDEF DEBUG_EXT2_GET_REAL_BLOCK}
			print_bochs('triple indirection\n', []);
		{$ENDIF}
      print_bochs('ext2_get_real_block: unable to read block %d (not implemented)\n', [block]);
      result := -1;
   end;

	{$IFDEF DEBUG_EXT2_GET_REAL_BLOCK}
		print_bochs('ext2_get_real_block: result=%d\n', [result]);
	{$ENDIF}

end;



{******************************************************************************
 * ext2_set_real_block
 *
 *****************************************************************************}
procedure ext2_set_real_block (block : dword ; inode : P_inode_t ; real_block : dword); [public, alias : 'EXT2_SET_REAL_BLOCK'];

var
   blocksize, new_block : dword;
   major, minor         : byte;
   buffer               : ^dword;
   bh, bh2              : P_buffer_head;

begin

   bh        := NIL;
   major     := inode^.dev_maj;
   minor     := inode^.dev_min;
   blocksize := inode^.blksize;

   if (block < EXT2_NDIR_BLOCKS) then
   begin
      inode^.ext2_i.data[block] := real_block;
      mark_inode_dirty(inode);
   end

   { Indirection simple }
{   else if (block <= EXT2_NDIR_BLOCKS + (blocksize div 4)) then}
	else if (block <= (EXT2_NDIR_BLOCKS + (blocksize div 4) - 1)) then
   begin
      if (inode^.ext2_i.data[EXT2_IND_BLOCK] = 0) then
      begin
			new_block := ext2_new_block(inode);
	 		if (new_block = 0) then
	 		begin
	    		print_bochs('ext2_set_real_block: cannot get a new block (step 1)\n', []);
	    		exit;
	 		end;
			{ FIXME: Do we really need to read this block ??? }
			bh := kmalloc(sizeof(buffer_head));
			if (bh = NIL) then
			begin
				print_bochs('ext2_set_real_block: not enough memory (1) !!!\n', []);
				exit;
			end;
			bh^.data := kmalloc(blocksize);
			if (bh^.data = NIL) then
			begin
				print_bochs('ext2_set_real_block: not enough memory (2) !!!\n', []);
				exit;
			end;

{	 		bh := bread(major, minor, new_block, blocksize);
	 		if (bh = NIL) then
	 		begin
	    		print_bochs('ext2_set_real_block: cannot read block %d (step 1)\n', [new_block]);
	    		exit;
	 		end;}
	 		memset(bh^.data, 0, blocksize);
	 		inode^.ext2_i.data[EXT2_IND_BLOCK] := new_block;
	 		mark_inode_dirty(inode);
		end;

      if (bh = NIL) then
      begin
			bh := bread(major, minor, inode^.ext2_i.data[12], blocksize);
	 		if (bh = NIL) then
	 		begin
	    		print_bochs('ext2_set_real_block: cannot read block %d (step 2)\n',
	            			[inode^.ext2_i.data[EXT2_IND_BLOCK]]);
	    		exit;
	 		end;
      end;

      buffer := bh^.data;
      buffer[block - EXT2_NDIR_BLOCKS] := real_block;
      mark_buffer_dirty(bh);
      brelse(bh);

   end


   { Indirection double }   
{   else if (block <= (EXT2_NDIR_BLOCKS + (blocksize div 4) + ((blocksize div 4) * (blocksize div 4)))) then}
	else if (block <= ((EXT2_NDIR_BLOCKS + (blocksize div 4) + ((blocksize div 4) * (blocksize div 4))) - 1)) then
   begin
		if (inode^.ext2_i.data[EXT2_DIND_BLOCK] = 0) then
		begin
			new_block := ext2_new_block(inode);
	 		if (new_block = 0) then
	 		begin
	    		print_bochs('ext2_set_real_block: cannot get a new block (step 1)\n', []);
	    		exit;
	 		end;
			{ FIXME: Do we really need to read this block ??? }
	 		bh := bread(major, minor, new_block, blocksize);
	 		if (bh = NIL) then
	 		begin
	    		print_bochs('ext2_set_real_block: cannot read block %d (step 1)\n', [new_block]);
	    		exit;
	 		end;
	 		memset(bh^.data, 0, blocksize);
	 		inode^.ext2_i.data[EXT2_DIND_BLOCK] := new_block;
	 		mark_inode_dirty(inode);
		end;

		buffer := bh^.data;

{		if (buffer[(block - (EXT2_NDIR_BLOCKS + (blocksize div 4))) div (blocksize div 4)] = 0) then
      begin
	 		brelse(bh);
	 		exit;
      end;}


      print_bochs('WARNING ext2_set_real_block: cannot set block %d (not supported)\n', [block]);
   end
   
   else
      print_bochs('ext2_set_real_block: cannot set block %d (not supported)\n', [block]);

end;



begin
end.
