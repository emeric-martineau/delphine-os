{******************************************************************************
 *  dir.pp
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

{$I config.inc}
{$I errno.inc}
{$I ext2.inc}
{$I fs.inc}
{$I process.inc}


{* External procedure and functions *}

function  alloc_buffer_head (major, minor : byte ; block, size : dword) : P_buffer_head; external;
function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
procedure brelse (bh : P_buffer_head); external;
function  ext2_get_data (block : dword ; inode : P_inode_t) : P_buffer_head; external;
function  ext2_new_block (inode : P_inode_t) : dword; external;
procedure ext2_set_real_block (block : dword ; inode : P_inode_t ; real_block : dword); external;
procedure mark_buffer_dirty (bh : P_buffer_head); external;
procedure mark_inode_dirty (inode : P_inode_t); external;
function  memcmp (src, dest : pointer ; size : dword) : boolean; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;

{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

function  ext2_add_link (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword;
function  ext2_delete_entry (inode : P_inode_t ; dir : P_ext2_dir_entry ; bh : P_buffer_head) : dword;
function  ext2_empty_dir (inode : P_inode_t) : boolean;
function  ext2_find_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_bh : PP_buffer_head) : P_ext2_dir_entry;
function  ext2_last_byte (inode : P_inode_t ; page_nr : dword) : dword;
function  ext2_make_empty (inode, parent : P_inode_t) : dword;
function  ext2_match (len : dword ; name : pchar ; de : P_ext2_dir_entry) : boolean;
function  ext2_readdir (fichier : P_file_t ; dirent : P_dirent_t ; count : dword) : dword;


IMPLEMENTATION


{$I ext2_inline.inc}

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
   block     : dword;
   blocksize : dword; { Logical filesystem block size in bytes }
   res       : dword;
   dir_entry : P_ext2_dir_entry;
   inode     : P_inode_t;
   bh        : P_buffer_head;

   {$IFDEF DEBUG_EXT2_READDIR}
      i : dword;
   {$ENDIF}

begin

   {$IFDEF DEBUG_EXT2_READDIR}
      print_bochs('ext2_readdir: fichier=%h dirent=%h count=%d)\n', [fichier, dirent, count]);
   {$ENDIF}

   if (fichier^.pos + count > fichier^.inode^.size) then
       count := fichier^.inode^.size - fichier^.pos;

   {$IFDEF DEBUG_EXT2_READDIR}
		print_bochs('ext2_readdir: pos=%d size=%d count=%d block=%d\n',
		[fichier^.pos, fichier^.inode^.size, count, fichier^.pos div fichier^.inode^.blksize]);
	{$ENDIF}

   if (count = 0) then
   begin
      result := 0;
      exit;
   end;

   res       := 0;
   blocksize := fichier^.inode^.blksize;
   inode     := fichier^.inode;

   block := fichier^.pos div blocksize;

   bh := ext2_get_data(block, inode);
   if (bh = NIL) then
   begin
      printk('ext2_readdir: unable to read logical block %d\n', [block]);
      result := -EIO;
      exit;
   end;

   dir_entry := bh^.data;

   while (count > 0) do
   begin

		if (dir_entry^.name_len <> 0) then
		begin
      	dirent^.d_ino    := dir_entry^.inode;
      	dirent^.d_off    := 0;   { not used by dietlibc ??? }
      	dirent^.d_reclen := {dir_entry^.rec_len} dir_entry^.name_len + 11;

      	memcpy(@dir_entry^.name, @dirent^.d_name, dir_entry^.name_len);

      	dirent^.d_name[dir_entry^.name_len] := #0;
			res += dirent^.d_reclen;

      	{$IFDEF DEBUG_EXT2_READDIR}
         	i := 0;
         	while (dirent^.d_name[i] <> #0) do i += 1;
         	print_bochs('ext2_readdir: pos=%d rec_len=%d: %s (%d + 11) res=%d\n',
							[fichier^.pos, dir_entry^.rec_len, @dirent^.d_name, i, res]);
      	{$ENDIF}
		end;

      count -= dir_entry^.rec_len;
      fichier^.pos += dir_entry^.rec_len;

		if (longint(count) <= 0) then break;

      longint(dir_entry) += dir_entry^.rec_len;
      longint(dirent)    += dirent^.d_reclen;

		if (count > 0) and ((fichier^.pos mod blocksize) = 0) 
		and (fichier^.pos < fichier^.inode^.size) then
		{ We have reached a block boundary, got to read the next one }
		begin
			{$IFDEF DEBUG_EXT2_READDIR}
				print_bochs('ext2_readdir: changing block %d -> ', [block]);
			{$ENDIF}
			block := fichier^.pos div blocksize;
			{$IFDEF DEBUG_EXT2_READDIR}
				print_bochs('%d\n', [block]);
			{$ENDIF}
			bh := ext2_get_data(block, inode);
			if (bh = NIL) then
   		begin
      		printk('ext2_readdir: unable to read logical block %d\n', [block]);
      		result := -EIO;
      		exit;
   		end;
			dir_entry := bh^.data;
		end;
   end; { while }

   {$IFDEF DEBUG_EXT2_READDIR}
      print_bochs('ext2_readdir: END (result=%d)\n', [res]);
   {$ENDIF}

   brelse(bh);

   result := res;

end;



{******************************************************************************
 * ext2_add_link
 *
 * Add an entry for 'name' in 'dir'
 *****************************************************************************}
function ext2_add_link (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword; [public, alias : 'EXT2_ADD_LINK'];

var
   n, nblocks, block_size : dword;
   namelen, reclen, err   : dword;
   name_len, rec_len 	  : dword;
   from_, to_, new_block  : dword;    {* These variables are named like this
				         	      	      * because 'to' is a reserved word
				       							* in pascal *}
   de, de1             	  : P_ext2_dir_entry;
   bh 	             	  : P_buffer_head;
   kaddr 		      	  : pointer;

label out_page, got_it;

begin

   {$IFDEF DEBUG_EXT2_ADD_LINK}
      print_bochs('ext2_add_link (%d): dir=%d  %s (%d)\n', [current^.pid, dir^.ino, name, inode^.ino]);
   {$ENDIF}

   block_size := dir^.sb^.blksize;
   nblocks := (dir^.size + block_size - 1) div block_size;

   {$IFDEF DEBUG_EXT2_ADD_LINK}
      print_bochs('ext2_add_link (%d): dir size = %d bytes -> %d blocks\n', [current^.pid, dir^.size, nblocks]);
   {$ENDIF}

   namelen := 0;
   while (name[namelen] <> #0) do namelen += 1;

   reclen := (namelen + 8 + 3) and not 3;

   {$IFDEF DEBUG_EXT2_ADD_LINK}
      print_bochs('ext2_add_link (%d): namelen=%d  reclen=%d\n', [current^.pid, namelen, reclen]);
   {$ENDIF}

   for n := 0 to (nblocks - 1) do
   begin
      bh := ext2_get_data(n, dir);
      if (bh = NIL) then
      begin
      	print_bochs('ext2_add_link (%d): cannot read logical block %d\n', [current^.pid, n]);
	 		result := -EIO;
	 		exit;
      end;

      kaddr   := bh^.data;
      de      := kaddr;
      kaddr   += block_size - reclen;
      while (de <= kaddr) do
      begin
      	err := -EEXIST;
	 		if (ext2_match(namelen, name, de)) then
	      	 goto out_page;
      	name_len := (de^.name_len + 8 + 3) and not 3;
	 		rec_len  := de^.rec_len;
	 		if (de^.inode = 0) and (rec_len >= reclen) then
	      	 goto got_it;
      	if (rec_len >= name_len + reclen) then
	      	 goto got_it;
	 		de := pointer(longint(de) + rec_len);
      end;
      brelse(bh);
   end;

	{ If we get here, we need to expand dir }

	{ Get a now block for dir }
	new_block := ext2_new_block(dir);
	if (longint(new_block) <= 0) then
	begin
		brelse(bh);
		err := new_block;
		goto out_page;
	end;

	{$IFDEF DEBUG_EXT2_ADD_LINK}
		print_bochs('ext2_add_link: add block %d to dir\n', [new_block]);
	{$ENDIF}

	ext2_set_real_block(nblocks, dir, new_block);
	dir^.size += block_size;
	mark_inode_dirty(dir);

   { Get an unused buffer }
	brelse(bh);
	bh := alloc_buffer_head(dir^.dev_maj, dir^.dev_min, new_block, block_size);
	if (bh = NIL) then goto out_page;
	memset(bh^.data, 0, bh^.size);   { Clear it (FIXME: Do we really need this ? }
	bh^.state := BH_Uptodate;

	{ Initialize it }
	de := bh^.data;
	kaddr := de;
	de^.rec_len := block_size;
	de^.inode   := 0;
	goto got_it;

got_it:
   from_ := longint(de) - longint(bh^.data);
   to_   := from_ + rec_len;

   {$IFDEF DEBUG_EXT2_ADD_LINK}
      print_bochs('ext2_add_link (%d): GOT_IT: from=%d  to=%d\n', [current^.pid, from_, to_]);
   {$ENDIF}

   if (de^.inode <> 0) then
   begin
      de1 := pointer(longint(de) + name_len);
      de1^.rec_len := rec_len - name_len;
      de^.rec_len  := name_len;
      de := de1;
   end;

   de^.name_len := namelen;
   memcpy(name, @de^.name, namelen);
   de^.inode := inode^.ino;
	case (inode^.mode and IFMT) of
		IFSOCK: de^.file_type := EXT2_FT_SOCK;
		IFLNK:  de^.file_type := EXT2_FT_SYMLINK;
		IFREG:  de^.file_type := EXT2_FT_REG_FILE;
		IFBLK:  de^.file_type := EXT2_FT_BLKDEV;
		IFDIR:  de^.file_type := EXT2_FT_DIR;
		IFCHR:  de^.file_type := EXT2_FT_CHRDEV;
		IFIFO:  de^.file_type := EXT2_FT_FIFO;
	else
		de^.file_type := EXT2_FT_UNKNOWN;
	end;

   mark_buffer_dirty(bh);
	brelse(bh);
   err := 0;

out_page:

   result := err;

end;



{******************************************************************************
 * ext2_match
 *
 * NOTE! unlike strncmp, ext2_match returns 1 for success, 0 for failure.
 *
 * len <= EXT2_NAME_LEN and de != NULL are guaranteed by caller.
 *****************************************************************************}
function ext2_match (len : dword ; name : pchar ; de : P_ext2_dir_entry) : boolean;
begin

   result := FALSE;

   if (len <> de^.name_len) then exit;

   if (de^.inode = 0) then exit;

   result := memcmp(@de^.name, name, len);

end;



{******************************************************************************
 * ext2_find_entry
 *
 * Finds an entry in the specified directory with the wanted name.
 *****************************************************************************}
function ext2_find_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_bh : PP_buffer_head) : P_ext2_dir_entry; [public, alias : 'EXT2_FIND_ENTRY'];

var
   blocksize    : dword;
   ofs, i       : dword;
   major, minor : byte;
   de           : P_ext2_dir_entry;
   bh           : P_buffer_head;

begin

	{$IFDEF DEBUG_EXT2_FIND_ENTRY}
		print_bochs('ext2_find_entry: name=%s (%d)... ', [name, len]);
	{$ENDIF}

   result  := NIL;
   res_bh^ := NIL;

   major     := dir^.dev_maj;
   minor     := dir^.dev_min;
   blocksize := dir^.blksize;

   for i := 0 to (EXT2_NDIR_BLOCKS - 1) do   { FIXME: We only read direct blocks }
   begin
      if (dir^.ext2_i.data[i] <> 0) then
      begin
      	bh := bread(major, minor, dir^.ext2_i.data[i], blocksize);
	 		if (bh = NIL) then
	 		begin
	    		printk('ext2_find_entry (%d): cannot read block %d\n', [current^.pid, dir^.ext2_i.data[i]]);
	    		result := pointer(-EIO);
	    		exit;
	 		end;

	 		ofs := 0;

	 		while (ofs < blocksize) do
	 		begin
	    		de  := bh^.data + ofs;
	    		ofs += de^.rec_len;

            if (ext2_match(len, name, de)) then
	    		{ File has been found, exiting }
	    		begin
	       		result  := de;
	       		res_bh^ := bh;
					{$IFDEF DEBUG_EXT2_FIND_ENTRY}
						print_bochs('FOUND\n', []);
					{$ENDIF}
	       		exit;
	    		end;
	 		end; { while (ofs < blocksize) }

      end { if (dir^.ext2_i.data[i] <> 0) }
      else
      	  break;   { No more blocks to read }

      brelse(bh);

   end; { for i := 0 to (EXT2_NDIR_BLOCKS - 1) }

	{$IFDEF DEBUG_EXT2_FIND_ENTRY}
		print_bochs(' NOT FOUND\n', []);
	{$ENDIF}

end;



{******************************************************************************
 * ext2_delete_entry
 *
 * Deletes a directory entry by merging it with the
 * previous entry.
 *
 * INPUT : inode -> directory in which we delete the entry
 *         dir   -> which entry we delete
 *         bh    -> buffer containing 'dir'
 *
 * OUTPUT: 0 on success. Otherwise, an error code.
 *
 * NOTE: code inspired from fs/ext2/dir.c (Linux 2.4.22)
 *****************************************************************************}
function ext2_delete_entry (inode : P_inode_t ; dir : P_ext2_dir_entry ; bh : P_buffer_head) : dword; [public, alias : 'EXT2_DELETE_ENTRY'];

var
   from_, to_ : dword;
   de, pde    : P_ext2_dir_entry;

begin

   {$IFDEF DEBUG_EXT2_DELETE_ENTRY}
      print_bochs('ext2_delete_entry: ino=%d  dir=%h  bh^.data=%h\n', [inode^.ino, dir, bh^.data]);
   {$ENDIF}

   from_ := (longint(dir) - longint(bh^.data)) and not(inode^.blksize - 1);
   to_   := (longint(dir) - longint(bh^.data)) + dir^.rec_len;

   {$IFDEF DEBUG_EXT2_DELETE_ENTRY}
      print_bochs('ext2_delete_entry: from=%d  to=%d\n', [from_, to_]);
   {$ENDIF}

   de  := bh^.data + from_;
   pde := NIL;

   {$IFDEF DEBUG_EXT2_DELETE_ENTRY}
      print_bochs('ext2_delete_entry: de=%h  pde=%h\n', [de, pde]);
   {$ENDIF}

   while (longint(de) < longint(dir)) do
   begin
      pde := de;
      de  := pointer(longint(de) + de^.rec_len);
   end;

   {$IFDEF DEBUG_EXT2_DELETE_ENTRY}
      print_bochs('ext2_delete_entry: de=%h  pde=%h\n', [de, pde]);
   {$ENDIF}

   if (pde <> NIL) then
       from_ := longint(pde) - longint(bh^.data);

   {$IFDEF DEBUG_EXT2_DELETE_ENTRY}
      print_bochs('ext2_delete_entry: from=%d  to=%d\n', [from_, to_]);
   {$ENDIF}

   if (pde <> NIL) then
       pde^.rec_len := to_ - from_;

   dir^.inode := 0;

   mark_buffer_dirty(bh);

   result := 0;

end;



{******************************************************************************
 * ext2_make_empty
 *
 *****************************************************************************}
function ext2_make_empty (inode, parent : P_inode_t) : dword; [public, alias : 'EXT2_MAKE_EMPTY'];

var
	tmp	: string[3];
	block : longint;
	bh 	: P_buffer_head;
	de 	: P_ext2_dir_entry;

begin

	result := -EIO;

	block := ext2_new_block(inode);
	if (block <= 0) then
	begin
		result := block;
		exit;
	end;

	ext2_set_real_block(0, inode, block);

	bh := ext2_get_data(0, inode);
	if (bh = NIL) then exit;

	de := bh^.data;

	de^.name_len 	:= 1;
	de^.rec_len  	:= (1 + 8 + 3) and not 3;
	tmp[0] := '.';   { FIXME: really not clean }
	tmp[1] := #0;
	memcpy(@tmp, @de^.name, 2);
	de^.inode	 	:= inode^.ino;
	de^.file_type	:= EXT2_FT_DIR;

	pointer(de) += de^.rec_len;

	de^.name_len 	:= 2;
	de^.rec_len  	:= inode^.blksize - ((1 + 8 + 3) and not 3);
	tmp[0] := '.';   { FIXME: really not clean }
	tmp[1] := '.';
	tmp[2] := #0;
	memcpy(@tmp, @de^.name, 3);
	de^.inode	 	:= parent^.ino;
	de^.file_type	:= EXT2_FT_DIR;

	inode^.size := 1024;

	mark_buffer_dirty(bh);
	mark_inode_dirty(inode);

	result := 0;

end;



{******************************************************************************
 * ext2_last_byte
 *
 * Return the offset into page `page_nr' of the last valid
 * byte in that page, plus one.
 *
 * Code from inspired from linux-2.6.7
 *****************************************************************************}
function ext2_last_byte (inode : P_inode_t ; page_nr : dword) : dword;

var
	last_byte : dword;

begin

	last_byte := inode^.size;
	last_byte -= page_nr * inode^.sb^.blksize;

	if (last_byte > inode^.sb^.blksize) then
		 last_byte := inode^.sb^.blksize;

	result := last_byte;

end;



{******************************************************************************
 * ext2_empty_dir
 *
 * Routine to check that the specified directory is empty (for rmdir)
 *
 * Code from inspired from linux-2.6.7
 *****************************************************************************}
function ext2_empty_dir (inode : P_inode_t) : boolean; [public, alias : 'EXT2_EMPTY_DIR'];

var
	nblocks, i	: dword;
	blksize		: dword;
	kaddr 		: pointer;
	bh 			: P_buffer_head;
	de 			: P_ext2_dir_entry;

label not_empty;

begin

	blksize := inode^.sb^.blksize;
	nblocks  := (inode^.size + blksize - 1) div blksize;

	{$IFDEF DEBUG_EXT2_EMPTY_DIR}
		print_bochs('ext2_empty_dir: blksize=%d size=%d nblocks=%d\n',
		[blksize, inode^.size, nblocks]);
	{$ENDIF}

	for i := 0 to (nblocks - 1) do
	begin
		bh := ext2_get_data(i, inode);
		if (bh = NIL) then exit;

		kaddr := bh^.data;
		de    := kaddr;
		kaddr += ext2_last_byte(inode, i) - EXT2_DIR_REC_LEN(1);

		while (de <= kaddr) do
		begin
			if (de^.rec_len = 0) then
			begin
				print_bochs('ext2_empty_dir: zero-length directory entry. kaddr=%h de=%h\n',
				[kaddr, de]);
				goto not_empty;
			end;

			if (de^.inode <> 0) then
			{* check for . and .. *}
			begin
				if (de^.name[0] <> '.') then
					goto not_empty;
				if (de^.name_len > 2) then
					goto not_empty;
				if (de^.name_len < 2) then
				begin
					if (de^.inode <> inode^.ino) then
						goto not_empty;
				end
				else if (de^.name[1] <> '.') then
					goto not_empty;
			end;
			pointer(de) += de^.rec_len;
		end;
		brelse(bh);
	end;

	result := TRUE;
	exit;

not_empty:
	brelse(bh);
	result := FALSE;

end;



begin
end.
