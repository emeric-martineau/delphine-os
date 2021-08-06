{******************************************************************************
 *  inode.pp
 *
 *  Ext2 inodes management
 *
 *  Copyleft 2003 GaLi
 *
 *  version 0.0 - 07/08/2002 - initial version
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

unit _ext2_inode;



INTERFACE


{$I blk.inc}
{$I buffer.inc}
{$I config.inc}
{$I errno.inc}
{$I ext2.inc}
{$I fs.inc}
{$I process.inc}


function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
procedure brelse (bh : P_buffer_head); external;
function  buffer_uptodate (bh : P_buffer_head) : boolean; external;
procedure ext2_free_block (inode : P_inode_t ; block : dword); external;
procedure ext2_free_inode (inode : P_inode_t); external;
function  IS_BLK (inode : P_inode_t) : boolean; external;
function  IS_CHR (inode : P_inode_t) : boolean; external;
function  IS_DIR (inode : P_inode_t) : boolean; external;
function  IS_FIFO (inode : P_inode_t) : boolean; external;
function  IS_LNK (inode : P_inode_t) : boolean; external;
function  IS_REG (inode : P_inode_t) : boolean; external;
procedure ll_rw_block (rw : dword ; bh : P_buffer_head); external;
procedure lock_buffer (bh : P_buffer_head); external;
procedure mark_buffer_dirty (bh : P_buffer_head); external;
procedure mark_inode_clean (inode : P_inode_t); external;
procedure mark_inode_dirty (inode : P_inode_t); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure wait_on_buffer (bh : P_buffer_head); external;


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   blkdev_inode_operations    : inode_operations; external name 'U_VFS_BLKDEV_INODE_OPERATIONS';
   chrdev_inode_operations    : inode_operations; external name 'U_VFS_CHRDEV_INODE_OPERATIONS';
   ext2_dir_inode_operations  : inode_operations; external name 'U_EXT2_SUPER_EXT2_DIR_INODE_OPERATIONS';
   ext2_file_inode_operations : inode_operations; external name 'U__EXT2_FILE_EXT2_FILE_INODE_OPERATIONS';


procedure ext2_delete_inode (inode : P_inode_t);
procedure ext2_free_data (inode : P_inode_t);
procedure ext2_read_inode (inode : P_inode_t);
procedure ext2_truncate (inode : P_inode_t);
procedure ext2_write_inode (inode : P_inode_t);



IMPLEMENTATION



{******************************************************************************
 * ext2_read_inode
 *
 * Read an inode on an ext2 filesystem and initialize 'inode' parameter.
 * 'sb' and 'ino' fields in 'inode' must be initialized BEFORE calling this
 * procedure.
 *
 *****************************************************************************}
procedure ext2_read_inode (inode : P_inode_t); [public, alias : 'EXT2_READ_INODE'];

var
   bh               : P_buffer_head;
   gdp              : P_ext2_group_desc;
   raw_inode        : P_ext2_inode;
   major, minor     : byte;
   offset, block, i : dword; 
   block_group      : dword;
   group_desc, desc : dword;

begin

   {$IFDEF DEBUG_EXT2_READ_INODE}
      print_bochs('inode to read: %d  ', [inode^.ino]);
      print_bochs('inodes count: %d  ', [inode^.sb^.ext2_sb.inodes_count]);
      print_bochs('inodes per group: %d\n', [inode^.sb^.ext2_sb.inodes_per_group]);
      print_bochs('groups count: %d  ', [inode^.sb^.ext2_sb.groups_count]);
      print_bochs('desc per block: %d\n', [inode^.sb^.ext2_sb.desc_per_block]);
   {$ENDIF}

   major := inode^.sb^.dev_major;
   minor := inode^.sb^.dev_minor;

   inode^.state := inode^.state and (not I_Uptodate);

   if (inode^.ino <> EXT2_ROOT_INO) and
      (inode^.ino < EXT2_GOOD_OLD_FIRST_INO) and
      (inode^.ino > inode^.sb^.ext2_sb.inodes_count) then
   begin
      printk('ext2_read_inode: bad inode number (%d)\n', [inode^.ino]);
      exit;
   end;

   { block_group contains the inode we are looking for }
   block_group := (inode^.ino - 1) div (inode^.sb^.ext2_sb.inodes_per_group);
   if (block_group >= inode^.sb^.ext2_sb.groups_count) then
   begin
      printk('ext2_read_inode: block_group >= groups_count (ino=%d)\n', [inode^.ino]);
      exit;
   end;

   {$IFDEF DEBUG_EXT2_READ_INODE}
      print_bochs('block_group: %d  ', [block_group]);
   {$ENDIF}

   { group_desc defines the index used to read ext2_sb.group_desc[] }
   group_desc := block_group div inode^.sb^.ext2_sb.desc_per_block;

   {$IFDEF DEBUG_EXT2_READ_INODE}
      print_bochs('group desc: %d  ', [group_desc]);
   {$ENDIF}

   {* desc défini le descripteur concerné à l'intérieur de
    * ext2_sb.group_desc[group_desc] *}
   desc := block_group and (inode^.sb^.ext2_sb.desc_per_block - 1);

   {$IFDEF DEBUG_EXT2_READ_INODE}
      print_bochs('desc: %d\n', [desc]);
   {$ENDIF}

   { group_desc[group_desc] a été initialisé lors du montage du
     système de fichiers }
   bh := inode^.sb^.ext2_sb.group_desc[group_desc];
   if (bh = NIL) then
   begin
      printk('ext2_read_inode: descriptor not loaded (%d)\n', [block_group]);
      exit;
   end;

   { gdp est un pointeur vers le bloc contenant le descripteur de groupe }
   gdp := bh^.data;

   {$IFDEF DEBUG_EXT2_READ_INODE}
      print_bochs('inode table: %d  ', [gdp[desc].inode_table]);
      print_bochs('dirs: %d\n', [gdp[desc].used_dirs_count]);
   {$ENDIF}

   { On doit maintenant lire le bloc contenant l'inode demandé }

   {* Un bloc contient plusieurs inodes. offset défini l'offset ou commence
    * l'inode demandé dans le bloc contenant cet inode }
   offset := (inode^.ino - 1) mod inode^.sb^.ext2_sb.inodes_per_block *
              sizeof(ext2_inode);

   {$IFDEF DEBUG_EXT2_READ_INODE}
      print_bochs('offset: %d  ', [offset]);
   {$ENDIF}

   { block défini le bloc contenant l'inode demandé }
   block := gdp[desc].inode_table + (((inode^.ino - 1) mod 
            inode^.sb^.ext2_sb.inodes_per_group * sizeof(ext2_inode)) 
 	    shr (inode^.sb^.ext2_sb.log_block_size + 10));

   {$IFDEF DEBUG_EXT2_READ_INODE}
      print_bochs('block: %d\n', [block]);
   {$ENDIF}

   bh := bread(major, minor, block, inode^.sb^.blksize);
   if (bh = NIL) then
   begin
      printk('EXT2-fs: unable to read inode block %d\n', [block]);
      exit;
   end;

   raw_inode := bh^.data + offset;

   inode^.dev_maj  := major;
   inode^.dev_min  := minor;
   inode^.rdev_maj := major;
   inode^.rdev_min := minor;
   inode^.state    := inode^.state or I_Uptodate;
   inode^.atime    := raw_inode^.atime;
   inode^.ctime    := raw_inode^.ctime;
   inode^.mtime    := raw_inode^.mtime;
   inode^.dtime    := raw_inode^.dtime;
   inode^.mode     := raw_inode^.mode;
   inode^.uid      := raw_inode^.uid;
   inode^.gid      := raw_inode^.gid;
   inode^.nlink    := raw_inode^.links_count;
   inode^.size     := raw_inode^.size;
   inode^.blksize  := inode^.sb^.blksize;
   inode^.blocks   := raw_inode^.blocks;
   inode^.ext2_i.block_group := block_group;

   if (IS_BLK(inode) or IS_CHR(inode)) then
   begin
      inode^.rdev_maj := hi(lo(raw_inode^.block[0]));
      inode^.rdev_min := lo(lo(raw_inode^.block[0]));
   end
   else
   begin
      inode^.rdev_maj := major;
      inode^.rdev_min := minor;
      for i := 0 to 14 do
      	 inode^.ext2_i.data[i] := raw_inode^.block[i];
      {$IFDEF DEBUG_EXT2_READ_INODE}
			for i := 0 to 14 do
      	    print_bochs('%d ', [raw_inode^.block[i]]);
				 print_bochs('\n', []);
      {$ENDIF}
   end;

   { Define 'inodes_operations' }
   if IS_DIR(inode) then
      inode^.op := @ext2_dir_inode_operations
   else if IS_REG(inode) then
      inode^.op := @ext2_file_inode_operations
   else if IS_CHR(inode) then
      inode^.op := @chrdev_inode_operations
   else if IS_BLK(inode) then
      inode^.op := @blkdev_inode_operations
   else
   begin
      inode^.op := NIL;
      printk('EXT2-fs (read_inode): no operations defined for this type of file (%h)\n', [inode^.mode]);
   end;

   brelse(bh);

end;



{******************************************************************************
 * ext2_write_inode
 *
 *****************************************************************************}
procedure ext2_write_inode (inode : P_inode_t); [public, alias : 'EXT2_WRITE_INODE'];

var
   group, group_desc, blocksize : dword;
   desc, offset, block : dword;
   major, minor, i     : byte;
   raw_inode           : P_ext2_inode;
   gdp                 : P_ext2_group_desc;
   bh 	               : P_buffer_head;

begin

   if (inode^.ino <> EXT2_ROOT_INO) and
      (inode^.ino < EXT2_GOOD_OLD_FIRST_INO) and
      (inode^.ino > inode^.sb^.ext2_sb.inodes_count) then
      begin
         printk('ext2_write_inode: bad inode number (%d)\n', [inode^.ino]);
	 		inode^.state := 0;
	 		exit;
      end;

   {$IFDEF DEBUG_EXT2_WRITE_INODE}
      print_bochs('ext2_write_inode: ino=%d, ', [inode^.ino]);
   {$ENDIF}

   { group contains the inode we are looking for }
   group := (inode^.ino - 1) div (inode^.sb^.ext2_sb.inodes_per_group);
   if (group >= inode^.sb^.ext2_sb.groups_count) then
   begin
      printk('ext2_write_inode: group >= groups_count\n', []);
      inode^.state := 0;
      exit;
   end;

   { group_desc defines the index used to read ext2_sb.group_desc[] }
   group_desc := group div inode^.sb^.ext2_sb.desc_per_block;

   {* desc défini le descripteur concerné à l'intérieur de
    * ext2_sb.group_desc[group_desc] *}
   desc := group and (inode^.sb^.ext2_sb.desc_per_block - 1);

   {$IFDEF DEBUG_EXT2_WRITE_INODE}
      print_bochs('group=%d, group_desc=%d, desc=%d, ', [group, group_desc, desc]);
   {$ENDIF}

   { group_desc[group_desc] a été initialisé lors du montage du
     système de fichiers }
   bh := inode^.sb^.ext2_sb.group_desc[group_desc];
   if (bh = NIL) then
   begin
      printk('ext2_write_inode: descriptor not loaded (group=%d)\n', [group]);
      inode^.state := 0;
      exit;
   end;

   { gdp est un pointeur vers le bloc contenant le descripteur de groupe }
   gdp := bh^.data;

   {* Un bloc contient plusieurs inodes. offset défini l'offset ou commence
    * l'inode demandé dans le bloc contenant cet inode }
   offset := (inode^.ino - 1) mod inode^.sb^.ext2_sb.inodes_per_block *
              sizeof(ext2_inode);

   { block défini le bloc contenant l'inode demandé }
   block := gdp[desc].inode_table + (((inode^.ino - 1) mod 
            inode^.sb^.ext2_sb.inodes_per_group * sizeof(ext2_inode)) 
 	    		shr (inode^.sb^.ext2_sb.log_block_size + 10));

   major := inode^.sb^.dev_major;
   minor := inode^.sb^.dev_minor;

   {$IFDEF DEBUG_EXT2_WRITE_INODE}
      print_bochs('block=%d\n', [block]);
   {$ENDIF}

   bh := bread(major, minor, block, inode^.blksize);
   if (bh = NIL) then
   begin
      printk('ext2_write_inode: unable to read inode block %d\n', [block]);
      inode^.state := 0;
      exit;
   end;

   raw_inode := bh^.data + offset;
   blocksize := inode^.blksize;

   { raw_inode initialization }
   memset(raw_inode, 0, sizeof(ext2_inode));
   raw_inode^.mode 			:= inode^.mode;
   raw_inode^.uid  			:= inode^.uid;
   raw_inode^.size 			:= inode^.size;
   raw_inode^.blocks 	   := inode^.blocks * (blocksize div 512);
   raw_inode^.atime  	   := inode^.atime;
   raw_inode^.ctime  	   := inode^.ctime;
   raw_inode^.mtime  	   := inode^.mtime;
   raw_inode^.dtime  	   := inode^.dtime;
   raw_inode^.gid    	   := inode^.gid;
   raw_inode^.links_count  := inode^.nlink;
   raw_inode^.flags  	   := 0;
   for i := 0 to 14 do
       raw_inode^.block[i] := inode^.ext2_i.data[i];

   {$IFDEF DEBUG_EXT2_WRITE_INODE}
      print_bochs('ext2_write_inode: size=%d  blocks(512 bytes)=%d\n',
						[raw_inode^.size, raw_inode^.blocks]);
   {$ENDIF}

   mark_buffer_dirty(bh);
	mark_inode_clean(inode);

end;



{******************************************************************************
 * ext2_truncate
 *
 * Set inode size to zero by calling ext2_free_data().
 *****************************************************************************}
procedure ext2_truncate (inode : P_inode_t); [public, alias : 'EXT2_TRUNCATE'];
begin

   if (IS_DIR(inode) or not IS_REG(inode) or IS_LNK(inode)) then exit;

   if (inode^.blocks <> 0) then
       ext2_free_data(inode);

end;


{******************************************************************************
 * ext2_free_data
 *
 * Free all allocated data blocks.
 *****************************************************************************}
procedure ext2_free_data (inode : P_inode_t); [public, alias : 'EXT2_FREE_DATA'];

var
   nblocks, blocksize : dword;
   major, minor, n	 : dword;
   tmp	             : pointer;
   bh                 : P_buffer_head;

label finish;

begin

   blocksize := inode^.blksize;
   nblocks   := inode^.size div blocksize;
   if (inode^.size mod blocksize) <> 0 then nblocks += 1;

   {$IFDEF DEBUG_EXT2_FREE_DATA}
      printk('ext2_free_data (%d): inode size=%d -> going to free %d blocks\n', [current^.pid, inode^.size, nblocks]);
   {$ENDIF}

   { Free direct blocks }
   n := 0;
   while (n < EXT2_NDIR_BLOCKS) and (nblocks <> 0) do
   begin
      if (inode^.ext2_i.data[n] <> 0) then
      begin
      	 {$IFDEF DEBUG_EXT2_FREE_DATA}
	    printk('ext2_free_data (%d): freeing file block %d (%d)\n', [current^.pid, n, inode^.ext2_i.data[n]]);
	 {$ENDIF}
	 ext2_free_block(inode, inode^.ext2_i.data[n]);
	 inode^.ext2_i.data[n] := 0;
	 nblocks -= 1;
      end;
      n += 1;
   end;

   major := inode^.dev_maj;
   minor := inode^.dev_min;

   if (nblocks <> 0) then
   begin
      if (inode^.ext2_i.data[EXT2_IND_BLOCK] <> 0) then
      { We have to free simple indirection blocks }
      begin
      	 bh := bread(major, minor, inode^.ext2_i.data[EXT2_IND_BLOCK], blocksize);
	 if (bh = NIL) then
	 begin
	    printk('ext2_free_data (%d): cannot read simple indirection block (%d)\n', [current^.pid, inode^.ext2_i.data[EXT2_IND_BLOCK]]);
	    goto finish;
	 end;
	 tmp := bh^.data;
	 while (nblocks <> 0) and (tmp < (bh^.data + blocksize)) do
	 begin
	    if (longint(tmp^) <> 0) then
	    begin
	       {$IFDEF DEBUG_EXT2_FREE_DATA}
	          printk('ext2_free_data (%d): going to free block %d\n', [current^.pid, longint(tmp^)]);
	       {$ENDIF}
	       ext2_free_block(inode, longint(tmp^));
	       nblocks -= 1;
	    end;
	    tmp += 4;
	 end;
	 brelse(bh);
	 ext2_free_block(inode, inode^.ext2_i.data[EXT2_IND_BLOCK]);
      end;
   end;

   if (nblocks <> 0) then
   begin
      if (inode^.ext2_i.data[EXT2_DIND_BLOCK] <> 0) then
      { We have to free double indirection blocks }
      begin
      	 printk('ext2_free_data (%d): got to free double indirection blocks (not implemented)\n', [current^.pid]);
	 goto finish;
      end;
   end;


finish:

   inode^.size   := 0;
   inode^.blocks := 0;
   mark_inode_dirty(inode);

end;



{******************************************************************************
 * ext2_delete_inode
 *
 * Called by free_inode() when inode^.count=0.
 *****************************************************************************}
procedure ext2_delete_inode (inode : P_inode_t); [public, alias : 'EXT2_DELETE_INODE'];
begin

   {$IFDEF DEBUG_EXT2_DELETE_INODE}
      printk('ext2_delete_inode: ino=%d size=%d blocks=%d group=%d\n',
      	     [inode^.ino, inode^.size, inode^.blocks, inode^.ext2_i.block_group]);
   {$ENDIF}

   { FIXME: modify m_time }

   ext2_truncate(inode);

   {$IFDEF DEBUG_EXT2_DELETE_INODE}
      printk('ext2_delete_inode: calling ext2_free_inode()\n', []);
   {$ENDIF}

   ext2_free_inode(inode);

end;



begin
end.
