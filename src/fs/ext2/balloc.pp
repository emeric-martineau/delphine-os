{******************************************************************************
 *  balloc.pp
 *
 *  This file contains the blocks allocation and deallocation routines.
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 29/09/2003 - GaLi - Initial version
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


unit ext2_balloc;


INTERFACE


{* Headers *}

{$I config.inc}
{$I errno.inc}
{$I fs.inc}
{$I lock.inc}
{$I process.inc}


{* External procedure and functions *}

function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
procedure brelse (bh : P_buffer_head); external;
function  buffer_dirty (bh : P_buffer_head) : boolean; external;
function  ext2_find_first_zero_bit (addr : pointer ; size : dword) : dword; external;
function  ext2_get_group_desc (sb : P_super_block_t ; block_group : dword ; bh : PP_buffer_head) : P_ext2_group_desc; external;
function  ext2_set_bit (nr : dword ; addr : pointer) : dword; external;
function  ext2_unset_bit (nr : dword ; addr : pointer) : dword; external;
function  find_buffer (major, minor : byte ; block, size : dword ; ind : pointer) : P_buffer_head; external;
procedure kfree_s (adr : pointer ; size : dword); external;
procedure lock_buffer (bh : P_buffer_head); external;
procedure mark_buffer_clean (bh : P_buffer_head); external;
procedure mark_buffer_dirty (bh : P_buffer_head); external;
procedure mark_inode_dirty (inode : P_inode_t); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure write_lock (rw : P_rwlock_t); external;
procedure write_unlock (rw : P_rwlock_t); external;



{* External variables *}

var
   current  					: P_task_struct; external name 'U_PROCESS_CURRENT';
	buffer_head_list  	 	: array [1..1024] of P_buffer_head; external name 'U_BUFFER_BUFFER_HEAD_LIST';
	buffer_head_list_lock 	: rwlock_t; external name 'U_BUFFER_BUFFER_HEAD_LIST_LOCK';
	nr_buffer_head        	: dword; external name 'U_BUFFER_NR_BUFFER_HEAD';
	nr_buffer_head_dirty  	: dword; external name 'U_BUFFER_NR_BUFFER_HEAD_DIRTY';


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure ext2_free_block (inode : P_inode_t ; block : dword);
function  ext2_new_block (inode : P_inode_t) : dword;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * ext2_new_block
 *
 * Returns a logical block number or 0 on error.
 *****************************************************************************}
function ext2_new_block (inode : P_inode_t) : dword; [public, alias : 'EXT2_NEW_BLOCK'];

var
   i, group   : dword;
   bh, bh2    : P_buffer_head;
   sb 	     : P_super_block_t;
   ext2_sb    : P_ext2_super_block;
   group_desc : P_ext2_group_desc;

label next_group;

begin

   {$IFDEF DEBUG_EXT2_NEW_BLOCK}
      print_bochs('ext2_new_block (%d): ino=%d\n', [current^.pid, inode^.ino]);
   {$ENDIF}

   sb := inode^.sb;
   if (sb = NIL) then
   begin
      print_bochs('ext2_new_block (%d): sb=NIL for inode %d\n', [current^.pid, inode^.ino]);
		result := -EIO;   { FIXME: another error code ??? }
      exit;
   end;

   group   := inode^.ext2_i.block_group;
   ext2_sb := sb^.ext2_sb.real_sb;

   if (ext2_sb^.free_blocks_count <= ext2_sb^.r_blocks_count) and
      (ext2_sb^.def_resuid <> current^.uid) then
   begin
      print_bochs('ext2_new_block (%d): no more free blocks (or free blocks are reserved)\n', [current^.pid]);
		result := -ENOSPC;
      exit;
   end;

   {$IFDEF DEBUG_EXT2_NEW_BLOCK}
      print_bochs('ext2_new_block (%d): Trying to get group_desc for group %d\n', [current^.pid, group]);
   {$ENDIF}

	i := 0;
	result := -EIO;

next_group:
   group_desc := ext2_get_group_desc(sb, group, @bh2);
   if (group_desc = NIL) then
   begin
      printk('ext2_new_block (%d): cannot get group_desc for group %d\n', [current^.pid, group]);
      exit;
   end;

   if (group_desc^.free_blocks_count = 0) then
   begin
      group += 1;
		i     += 1;
		if (i = sb^.ext2_sb.groups_count) then
		begin
			result := -ENOSPC;
			exit;
		end;
      if (group >= sb^.ext2_sb.groups_count) then
      	 group := 0;
      goto next_group;
   end;

   { Read block bitmap }
   bh := bread(sb^.dev_major, sb^.dev_minor, group_desc^.block_bitmap, sb^.blksize);
   if (bh = NIL) then
   begin
      printk('ext2_new_block (%d): cannot read block bitmap (%d)\n', [current^.pid, group_desc^.block_bitmap]);
      exit;
   end;

   i := ext2_find_first_zero_bit(bh^.data, sb^.ext2_sb.blocks_per_group);
   if (i >= sb^.ext2_sb.blocks_per_group) then
   begin
      printk('EXT2-fs: Free blocks count corrupted in group %d\n', [group]);
      exit;
   end;

   ext2_set_bit(i, bh^.data);
   mark_buffer_dirty(bh);

   group_desc^.free_blocks_count -= 1;
   mark_buffer_dirty(bh2);

   ext2_sb^.free_blocks_count -= 1;
   mark_buffer_dirty(sb^.ext2_sb.real_sb_bh);

   inode^.blocks += inode^.blksize div 512;
   mark_inode_dirty(inode);

   result := (group * sb^.ext2_sb.blocks_per_group) + i + 1;

   {$IFDEF DEBUG_EXT2_NEW_BLOCK}
      print_bochs('ext2_new_block (%d): new block=%d\n', [current^.pid, result]);
   {$ENDIF}

end;



{******************************************************************************
 * ext2_free_block
 *
 *****************************************************************************}
procedure ext2_free_block (inode : P_inode_t ; block : dword); [public, alias : 'EXT2_FREE_BLOCK'];

var
   bh, bh2     		: P_buffer_head;
   sb 	      		: P_super_block_t;
   ext2_sb     		: P_ext2_super_block;
   group, bit, ind	: dword;
   group_desc  		: P_ext2_group_desc;

begin

   ext2_sb := inode^.sb^.ext2_sb.real_sb;
   group   := ((block - ext2_sb^.first_data_block) div ext2_sb^.blocks_per_group);
   bit     := ((block - ext2_sb^.first_data_block) mod ext2_sb^.blocks_per_group);
   sb      := inode^.sb;

   group_desc := ext2_get_group_desc(inode^.sb, group, @bh2);

   bh := bread(sb^.dev_major, sb^.dev_minor, group_desc^.block_bitmap, sb^.blksize);

   ext2_unset_bit(bit, bh^.data);
   mark_buffer_dirty(bh);

   group_desc^.free_blocks_count += 1;
   mark_buffer_dirty(bh2);

   ext2_sb^.free_blocks_count += 1;
   sb^.dirty := 1;
   mark_buffer_dirty(sb^.ext2_sb.real_sb_bh);


	{ Remove block from buffer_head_list }

	find_buffer(inode^.dev_maj, inode^.dev_min, block, inode^.blksize, @ind);
	if (ind <> 0) then
	{ The block has been found in buffer_head_list }
	begin
		if (buffer_head_list[ind]^.count = 0) then
		begin
			write_lock(@buffer_head_list_lock);
			lock_buffer(buffer_head_list[ind]);
			if (buffer_dirty(buffer_head_list[ind])) then
			 	 mark_buffer_clean(buffer_head_list[ind]);
			kfree_s(buffer_head_list[ind]^.data, buffer_head_list[ind]^.size);
			kfree_s(buffer_head_list[ind], sizeof(buffer_head));
			buffer_head_list[ind] := NIL;
			nr_buffer_head -= 1;
			write_unlock(@buffer_head_list_lock);
		end
		else
		begin
			print_bochs('ext2_free_block: block %d is used (count=%d)\n',
							[buffer_head_list[ind]^.blocknr,
							 buffer_head_list[ind]^.count]);
		end;
	end;

end;



begin
end.
