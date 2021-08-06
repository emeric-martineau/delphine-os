{******************************************************************************
 *  ialloc.pp
 *
 *  Contains the inodes allocation and deallocation routines for an ext2
 *  filesystem.
 *
 *  NOTE: - this code is inspired from the code you can find in Linux 2.4.22.
 *    	  - On the other hand, it's only a simplified version  :-)
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 27/09/2003 - GaLi - Initial version
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


unit ext2_ialloc;


INTERFACE


{* Headers *}

{$I config.inc}
{$I errno.inc}
{$I fs.inc}
{$I process.inc}


{* External procedure and functions *}

function  alloc_inode : P_inode_t; external;
function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
procedure brelse (bh : P_buffer_head); external;
function  ext2_find_first_zero_bit (addr : pointer ; size : dword) : dword; external;
function  ext2_get_group_desc (sb : P_super_block_t ; block_group : dword ; bh : PP_buffer_head) : P_ext2_group_desc; external;
function  ext2_set_bit (nr : dword ; addr : pointer) : dword; external;
function  ext2_unset_bit (nr : dword ; addr : pointer) : dword; external;
function  free_inode : P_inode_t; external;
function  IS_DIR (inode : P_inode_t) : boolean; external;
procedure mark_buffer_dirty (bh : P_buffer_head); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
function  sys_time (t : pointer) : dword; cdecl; external;


{* External variables *}

var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure ext2_free_inode (inode : P_inode_t);
function  ext2_new_inode (dir : P_inode_t ; mode : dword) : P_inode_t;
function  find_group (sb : P_super_block_t ; parent_group : dword) : dword;


IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * find_group
 *
 *****************************************************************************}
function find_group (sb : P_super_block_t ; parent_group : dword) : dword;

var
   ngroups, group : dword;
   desc           : P_ext2_group_desc;
   bh 	          : P_buffer_head;

label found;

begin

   ngroups := sb^.ext2_sb.groups_count;

   {$IFDEF DEBUG_FIND_GROUP}
      print_bochs('find_group (%d): parent group: %d  ngroups: %d\n', [current^.pid, parent_group, ngroups]);
   {$ENDIF}

   {* Try to place the inode in its parent directory *}
   group := parent_group;

   desc := ext2_get_group_desc(sb, group, @bh);

   if (desc <> NIL) and (desc^.free_inodes_count <> 0) then
       goto found
   else
   begin
      printk('find_group (%d): inode cannot be in its father''s group\n', [current^.pid]);
      result := -1;
   end;

found:
   desc^.free_inodes_count -= 1;
   mark_buffer_dirty(bh);
   result := group;

end;



{******************************************************************************
 * ext2_new_inode
 *
 *****************************************************************************}
function ext2_new_inode (dir : P_inode_t ; mode : dword) : P_inode_t; [public, alias : 'EXT2_NEW_INODE'];

var
   inode : P_inode_t;
   group, i, ino, t : dword;
   sb    : P_super_block_t;
   bh    : P_buffer_head;

begin

   {$IFDEF DEBUG_EXT2_NEW_INODE}
      print_bochs('ext2_new_inode (%d): dir->ino=%d  group=%d\n', [current^.pid, dir^.ino, dir^.ext2_i.block_group]);
   {$ENDIF}

   inode := alloc_inode();
   if (inode = NIL) then
   begin
      result := -ENOMEM;
      exit;
   end;

   sb := dir^.sb;
   group := find_group(sb, dir^.ext2_i.block_group);

   if (group = -1) then
   begin
      result := -ENOSPC;
      exit;
   end;

   {$IFDEF DEBUG_EXT2_NEW_INODE}
      print_bochs('ext2_new_inode (%d): going to read inode bitmap for group %d\n', [current^.pid, group]);
   {$ENDIF}

   { Read inode bitmap }
   bh := bread(sb^.dev_major, sb^.dev_minor,
      	       ext2_get_group_desc(sb, group, NIL)^.inode_bitmap, sb^.blksize);

   if (bh = NIL) then
   begin
      printk('ext2_new_inode (%d): cannot read block %d\n', [current^.pid, ext2_get_group_desc(sb, group, NIL)^.inode_bitmap]);
      result := -EIO;
      exit;
   end;

   i := ext2_find_first_zero_bit(bh^.data, sb^.ext2_sb.inodes_per_group);
   if (i >= sb^.ext2_sb.inodes_per_group) then
   begin
      printk('EXT2-fs: Free inodes count corrupted in group %d\n', [group]);
      result := -ENOSPC;
      exit;
   end;

   ext2_set_bit(i, bh^.data);

   mark_buffer_dirty(bh);

   ino := (group * sb^.ext2_sb.inodes_per_group) + i + 1;
   {$IFDEF DEBUG_EXT2_NEW_INODE}
      print_bochs('ext2_new_inode (%d): find_first_zero_bit() result=%d -> ino=%d\n', [current^.pid, i, ino]);
   {$ENDIF}
   if (ino < EXT2_GOOD_OLD_FIRST_INO) or (ino > sb^.ext2_sb.real_sb^.inodes_count) then
   begin
      printk('EXT2-fs: reserved inode or inode > inodes count\n', []);
      result := -EIO;
      exit;
   end;

   sb^.ext2_sb.real_sb^.free_inodes_count -= 1;
   mark_buffer_dirty(sb^.ext2_sb.real_sb_bh);
   sb^.dirty := 1;

   { Inode initialization }

	t := sys_time(NIL);

   inode^.dev_maj := dir^.dev_maj;
   inode^.dev_min := dir^.dev_min;
   inode^.uid     := current^.uid;
   inode^.gid     := current^.gid;
   inode^.mode    := mode;
   inode^.ino     := ino;
   inode^.blksize := sb^.blksize;
   inode^.blocks  := 0;
   inode^.state   := I_Uptodate or I_Dirty;
   inode^.nlink   := 1;
   inode^.atime   := t;
   inode^.ctime   := t;
   inode^.mtime   := t;
   inode^.dtime   := 0;
   inode^.sb      := dir^.sb;
   inode^.ext2_i.block_group := group;

   for i := 0 to 14 do
      inode^.ext2_i.data[i] := 0;

   result := inode;

end;



{******************************************************************************
 * ext2_free_inode
 *
 *****************************************************************************}
procedure ext2_free_inode (inode : P_inode_t); [public, alias : 'EXT2_FREE_INODE'];

var
   ino, block_group   : dword;
   offset, bit, block : dword;
   is_directory       : boolean;
   bh, bh2            : P_buffer_head;
   desc               : P_ext2_group_desc;
   gdp                : P_ext2_group_desc;
   sb                 : P_super_block_t;
   es                 : P_ext2_super_block;

begin

   ino := inode^.ino;
   sb  := inode^.sb;
   es  := inode^.sb^.ext2_sb.real_sb;
   is_directory := IS_DIR(inode);

   {FIXME: call clear_inode() -> function not written }

   if (ino < EXT2_GOOD_OLD_FIRST_INO) or
      (ino > es^.inodes_count) then
   begin
      printk('ext2_free_inode: bad inode number (%d)\n', [ino]);
      exit;
   end;

   block_group := (ino - 1) div es^.inodes_per_group;
   bit         := (ino - 1) mod es^.inodes_per_group;

   {$IFDEF DEBUG_EXT2_FREE_INODE}
      print_bochs('ext2_free_inode: block_group=%d bit=%d\n', [block_group, bit]);
   {$ENDIF}

   { Read inode bitmap }
   bh := bread(sb^.dev_major, sb^.dev_minor,
      	       ext2_get_group_desc(sb, block_group, NIL)^.inode_bitmap, sb^.blksize);

   if (bh = NIL) then
   begin
      printk('ext2_free_inode: cannot read block %d\n', [ext2_get_group_desc(sb, block_group, NIL)^.inode_bitmap]);
      exit;
   end;

   if (ext2_unset_bit(bit, bh^.data) = 0) then
   begin
      printk('ext2_free_inode: bit already cleared for inode %d\n', [ino]);
      exit;
   end
   else
   begin
      desc := ext2_get_group_desc(sb, block_group, @bh2);
      if (desc <> NIL) then
      begin
      	 {$IFDEF DEBUG_EXT2_FREE_INODE}
	    print_bochs('ext2_free_inode: desc^.free_inodes_count += 1;\n', []);
	 {$ENDIF}
      	 desc^.free_inodes_count += 1;
	 if (is_directory) then
	     desc^.used_dirs_count -= 1;
      end;
      mark_buffer_dirty(bh2);
      {$IFDEF DEBUG_EXT2_FREE_INODE}
      	 print_bochs('ext2_free_inode: es^.free_inodes_count += 1;\n', []);
      {$ENDIF}
      es^.free_inodes_count += 1;
      mark_buffer_dirty(sb^.ext2_sb.real_sb_bh);
   end;

   mark_buffer_dirty(bh);
   sb^.dirty := 1;

   { Set inode to 0 on disk }
   gdp := ext2_get_group_desc(inode^.sb, inode^.ext2_i.block_group, NIL);
   if (gdp = NIL) then
   begin
      printk('ext2_free_inode: cannot get group descriptor for group %d\n', [inode^.ext2_i.block_group]);
      exit;
   end;

   {* Un bloc contient plusieurs inodes. offset défini l'offset ou commence
    * l'inode demandé dans le bloc contenant cet inode *}
   offset := (inode^.ino - 1) mod inode^.sb^.ext2_sb.inodes_per_block *
              sizeof(ext2_inode);

   { block défini le bloc contenant l'inode demandé }
   block := gdp^.inode_table + (((inode^.ino - 1) mod 
            inode^.sb^.ext2_sb.inodes_per_group * sizeof(ext2_inode)) 
 	    shr (inode^.sb^.ext2_sb.log_block_size + 10));

   bh := bread(inode^.dev_maj, inode^.dev_min, block, inode^.blksize);
   if (bh = NIL) then
   begin
      printk('ext2_free_inode: cannot read block %d\n', [block]);
      exit;
   end;

   memset(bh^.data + offset, 0, sizeof(ext2_inode));

   mark_buffer_dirty(bh);
   brelse(bh);

end;



begin
end.
