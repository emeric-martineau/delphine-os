{
  This file defines structures used in ext2 filesystems management.
}


{$IFNDEF __EXT2__}
{$DEFINE __EXT2__}

{$I buffer.inc}


const


   {* File system states *}
   EXT2_VALID_FS = 1;	{* Unmounted cleanly *}
   EXT2_ERROR_FS = 2;	{* Errors detected *}


   {* Special inode numbers *}
   EXT2_BAD_INO	     	= 1;	{* Bad blocks inode *}
   EXT2_ROOT_INO			= 2;	{* Root inode *}
   EXT2_ACL_IDX_INO     = 3;	{* ACL inode *}
   EXT2_ACL_DATA_INO    = 4;	{* ACL inode *}
   EXT2_BOOT_LOADER_INO = 5;	{* Boot loader inode *}
   EXT2_UNDEL_DIR_INO   = 6;	{* Undelete directory inode *}


   {* First non-reserved inode for old ext2 filesystems *}
   EXT2_GOOD_OLD_FIRST_INO = 11;


   {* The second extended file system magic number *}
   EXT2_SUPER_MAGIC = $EF53;


   {* Ext2 directory file types.  Only the low 3 bits are used.  The
    * other bits are reserved for now. *}
   EXT2_FT_UNKNOWN  = 0;
   EXT2_FT_REG_FILE = 1;
   EXT2_FT_DIR      = 2;
   EXT2_FT_CHRDEV   = 3;
   EXT2_FT_BLKDEV   = 4;
   EXT2_FT_FIFO     = 5;
   EXT2_FT_SOCK     = 6;
   EXT2_FT_SYMLINK  = 7;
   EXT2_FT_MAX      = 8;


   {*
    * Constants relative to the data blocks
    *}
   EXT2_NDIR_BLOCKS  = 12;
   EXT2_IND_BLOCK    = EXT2_NDIR_BLOCKS;
   EXT2_DIND_BLOCK   = (EXT2_IND_BLOCK + 1);
   EXT2_TIND_BLOCK   = (EXT2_DIND_BLOCK + 1);
   EXT2_N_BLOCKS     = (EXT2_TIND_BLOCK + 1);


type

   P_ext2_inode       = ^ext2_inode;
   P_ext2_super_block = ^ext2_super_block;
   P_ext2_group_desc  = ^ext2_group_desc;
   P_ext2_dir_entry   = ^ext2_dir_entry;


   ext2_super_block = record     { 1024 bytes }
      inodes_count      : dword; { Inodes count }
      blocks_count      : dword; { Blocks count }
      r_blocks_count    : dword; { Reserved blocks count }
      free_blocks_count : dword; { Free blocks count }
      free_inodes_count : dword; { Free inodes count }
      first_data_block  : dword; { First Data Block }
      log_block_size    : dword; { Block size }
      log_frag_size     : dword; { Fragment size }
      blocks_per_group  : dword; { # Blocks per group }
      frags_per_group   : dword; { # Fragments per group }
      inodes_per_group  : dword; { # Inodes per group }
      mtime             : dword; { Mount time }
      wtime             : dword; { Write time }
      mnt_count         : word;  { Mount count }
      max_mnt_count     : word;  { Maximal mount count }
      magic             : word;  { Magic signature }
      state             : word;  { File system state }
      errors            : word;  { Behaviour when detecting errors }
      minor_rev_level   : word;  { minor revision level }
      lastcheck         : dword; { time of last check }
      checkinterval     : dword; { max. time between checks }
      creator_os        : dword; { OS }
      rev_level         : dword; { Revision level }
      def_resuid     	: word;  { Default uid for reserved blocks }
      def_resgid     	: word;  { Default gid for reserved blocks }
      reserved          : array [0..234] of dword;
   end;

   ext2_sb_info = record
      inodes_per_block : dword;
      blocks_per_group : dword;
      inodes_per_group : dword;
      inodes_count     : dword;
      blocks_count     : dword;
      groups_count     : dword;
      desc_per_block   : dword;
      log_block_size   : dword;
      real_sb          : P_ext2_super_block;
      real_sb_bh       : P_buffer_head;
      group_desc       : PP_buffer_head;
   end;

{-----------------------------------------------------------------------------}

   ext2_inode = record   { 128 bytes }
      mode        : word;
      uid         : word;
      size        : dword; { Size in bytes }
      atime       : dword; { Access time }
      ctime       : dword; { Creation time }
      mtime       : dword; { Modification time }
      dtime       : dword; { Deletion time }
      gid         : word;
      links_count : word;
      blocks      : dword; { Blocks (512 bytes) count }
      flags       : dword;
      reserved1   : dword;
      block       : array [0..14] of dword; { Pointers to blocks }
      version     : dword;
      file_acl    : dword;
      dir_acl     : dword;
      faddr       : dword; { Fragment address }
      frag        : byte;  { Fragment number }
      fsize       : byte;  { Fragment size }
      pad1        : word;
      reserved2   : array [0..1] of dword;
   end;

   ext2_inode_info = record
      data        : array[0..14] of dword;
      block_group : dword;
   end;

{-----------------------------------------------------------------------------}

   ext2_group_desc = record   { 32 bytes }
      block_bitmap : dword;
      inode_bitmap : dword;
      inode_table  : dword;
      free_blocks_count : word;
      free_inodes_count : word;
      used_dirs_count   : word;
      pad               : word;
      reserved          : array[0..2] of dword;
   end;

{-----------------------------------------------------------------------------}

   ext2_dir_entry = record
      inode     : dword;
      rec_len   : word;
      name_len  : byte;
      file_type : byte;
      name      : array [0..254] of char;
   end;

{$ENDIF}
