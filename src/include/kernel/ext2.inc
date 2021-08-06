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


{*
 * Ext2 directory file types.  Only the low 3 bits are used.  The
 * other bits are reserved for now.
 *}

   EXT2_FT_UNKNOWN  = 0;
   EXT2_FT_REG_FILE = 1;
   EXT2_FT_DIR      = 2;
   EXT2_FT_CHRDEV   = 3;
   EXT2_FT_BLKDEV   = 4;
   EXT2_FT_FIFO     = 5;
   EXT2_FT_SOCK     = 6;
   EXT2_FT_SYMLINK  = 7;
   EXT2_FT_MAX      = 8;


type

   P_ext2_inode       = ^ext2_inode;
   P_ext2_super_block = ^ext2_super_block;
   P_ext2_group_desc  = ^ext2_group_desc;
   P_ext2_dir_entry   = ^ext2_dir_entry;


   ext2_super_block = record     { 1024 bytes }
      inodes_count      : dword;
      blocks_count      : dword;
      r_blocks_count    : dword; { Reserved blocks }
      free_blocks_count : dword;
      free_inodes_count : dword;
      first_data_block  : dword;
      log_block_size    : dword;
      log_frag_size     : dword;
      blocks_per_group  : dword;
      frags_per_group   : dword;
      inodes_per_group  : dword;
      mtime             : dword; { Time of the last mount }
      wtime             : dword; { Time of the last write }
      mnt_count         : word;
      max_mnt_count     : word;
      magic             : word;
      state             : word;
      errors            : word;
      pad               : word;
      lastcheck         : dword;
      checkinterval     : dword;
      creator_os        : dword;
      rev_level         : dword;
      reserved          : array [0..235] of dword;
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
      block       : array [1..15] of dword; { Pointers to blocks }
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
      data        : array[1..15] of dword;
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
      file_type : byte;   { Not used }
      name      : array [0..254] of char;
   end;

{$ENDIF}
