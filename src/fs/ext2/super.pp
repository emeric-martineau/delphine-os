{******************************************************************************
 *  ext2_super.pp
 * 
 *  Ext2 filesystems management
 *
 *  CopyLeft 2003 GaLi
 *
 *  version 0.1 - 16/10/2002 - GaLi - correct a bug to read filesystems with
 *                                    any block size (1Kb, 2Kb or 4Kb)
 *
 *  version 0.0 - ??/??/2002 - GaLi - initial version
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
 ******************************************************************************}


unit ext2_super;


INTERFACE


{$I blk.inc}
{$I buffer.inc}
{$I config.inc}
{$I ext2.inc}
{$I fs.inc}
{$I process.inc}


function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
function  ext2_create (dir : P_inode_t ; name : pchar ; mode : dword) : P_inode_t; external;
procedure ext2_delete_inode (inode : P_inode_t); external;
function  ext2_file_read (fichier : P_file_t ; buffer : pointer ; count : dword) : dword; external;
function  ext2_file_write (fichier : P_file_t ; buffer : pointer ; count : dword) : dword; external;
function  ext2_lookup (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : boolean; external;
function  ext2_readdir (fichier : P_file_t ; buffer : pointer ; count : dword) : dword; external;
procedure ext2_read_inode (inode : P_inode_t); external;
procedure ext2_truncate (inode : P_inode_t); external;
function  ext2_unlink (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword; external;
procedure ext2_write_inode (inode : P_inode_t); external;
function  find_buffer (major, minor : byte ; block, size : dword) : P_buffer_head; external;
function  kmalloc (len : dword) : pointer; external;
procedure ll_rw_block (rw : dword ; bh : P_buffer_head); external;
procedure lock_buffer (bh : P_buffer_head); external;
procedure mark_buffer_dirty (bh : P_buffer_head); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure register_filesystem (fs : P_file_system_type); external;
procedure unlock_buffer (bh : P_buffer_head); external;
procedure wait_on_buffer (bh : P_buffer_head); external;


function  ext2_find_first_zero_bit (addr : pointer ; size : dword) : dword;
function  ext2_get_group_desc (sb : P_super_block_t ; block_group : dword ; bh : PP_buffer_head) : P_ext2_group_desc;
function  ext2_read_super (sb : P_super_block_t) : P_super_block_t;
function  ext2_set_bit (nr : dword ; addr : pointer) : dword;
function  ext2_unset_bit (nr : dword ; addr : pointer) : dword;
procedure ext2_write_super (sb : P_super_block_t);
procedure init_ext2_fs;


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   ext2_file_operations : file_operations; external name 'U__EXT2_FILE_EXT2_FILE_OPERATIONS';
   ext2_file_inode_operations : inode_operations; external name 'U__EXT2_FILE_EXT2_FILE_INODE_OPERATIONS';


var
   ext2_fs_type : file_system_type;
   ext2_super_operations : super_operations;
   ext2_inode_operations : inode_operations;

   { Directories operations }
   ext2_dir_operations : file_operations;
   ext2_dir_inode_operations : inode_operations;



IMPLEMENTATION



{******************************************************************************
 * ext2_read_super
 *
 * Entree : Pointeur vers superbloc 'semi-initialisé'
 * Retour : Pointeur vers superbloc complètement initialisé ou NIL si un
 *          problème se présente au cours de l'initialisation du superbloc.
 *
 * Lit le superbloc du système de fichiers EXT2 et initialise un objet
 * superbloc propre au VFS.
 *****************************************************************************}
function ext2_read_super (sb : P_super_block_t) : P_super_block_t;

var
   bh             : P_buffer_head;
   super          : P_ext2_super_block;
   major, minor   : byte;
   blk_size       : dword;
   db_count, i    : dword;
   logic_sb_block : dword;

begin

   {* On va essayer de lire le superbloc du système de fichiers. Celui-ci est
    * situé juste le après le secteur de boot (bloc logique n°0) qui fait 2
    * secteurs dans un système de fichiers ext2. On demande donc la lecture du
    * bloc logique n°1 (un bloc logique = 2 secteurs) *}

	major := sb^.dev_major;
   minor := sb^.dev_minor;
   logic_sb_block := 1;

   {$IFDEF DEBUG_EXT2_READ_SUPER}
      print_bochs('ext2_read_super: calling bread()...   ', []);
   {$ENDIF}

   bh := bread(major, minor, logic_sb_block, 1024);

   {$IFDEF DEBUG_EXT2_READ_SUPER}
      print_bochs('OK\n', []);
   {$ENDIF}

   if (bh = NIL) then
   begin
      printk('EXT2-fs: unable to read superblock on dev %d:%d\n', [major, minor]);
      result := NIL;
      exit;
   end
   else
   begin
      super := bh^.data;
      { Check if superblock is valid }
		result := NIL;
      if (super^.magic <> EXT2_SUPER_MAGIC) then
      begin
         printk('EXT2-fs: bad magic number on superbloc (%h4)\n', [super^.magic]);
	 		exit;
      end
      else if (super^.log_block_size > 2) then
      begin
	 		printk('EXT2-fs: logical block size is invalid (%d)\n', [super^.log_block_size]);
	 		exit;
      end
      else if (super^.free_blocks_count > super^.blocks_count) then
      begin
         printk('EXT2-fs: free blocks count > blocks count\n', []);
	 		exit;
      end;
	end;

 	{* Superblock seems to be valid, we are going to fill sb (passed
    * as parameter) *}

 	{$IFDEF REVISION_WARNING}
		if (super^.rev_level > 0) then
			print_bochs('WARNING: EXT2-fs: superblock has revision level > 0 (%d)\n', [super^.rev_level]);
 	{$ENDIF}

 	if (super^.state and EXT2_ERROR_FS) = EXT2_ERROR_FS then
 	begin
    	printk('EXT2-fs: root filesystem not cleanly unmounted (dev %d:%d)\n', [major, minor]);
    	printk('\nPlease run e2fsck under Linux and retry\n', []);
    	panic('no root filesystem');
 	end;

	case (super^.log_block_size) of
	    0: blk_size := 1024;
	    1: blk_size := 2048;
	    2: blk_size := 4096;
	end;

	logic_sb_block := super^.first_data_block;
	sb^.dirty   := 0;
	sb^.blksize := blk_size;
	sb^.fs_type := @ext2_fs_type;
	     
	{ Ext2 filesystem specific information }
	sb^.ext2_sb.log_block_size   := super^.log_block_size;
	sb^.ext2_sb.inodes_per_block := blk_size div sizeof(ext2_inode);
	sb^.ext2_sb.blocks_per_group := super^.blocks_per_group;
	sb^.ext2_sb.inodes_per_group := super^.inodes_per_group;
	sb^.ext2_sb.inodes_count     := super^.inodes_count;
	sb^.ext2_sb.blocks_count     := super^.blocks_count;
	sb^.ext2_sb.groups_count     := (super^.blocks_count -
												super^.first_data_block +
												super^.blocks_per_group - 1) div
												super^.blocks_per_group;
	sb^.ext2_sb.desc_per_block   := blk_size div sizeof(ext2_group_desc);
	sb^.ext2_sb.real_sb  	     := bh^.data;
	sb^.ext2_sb.real_sb_bh       := bh;
	db_count := (sb^.ext2_sb.groups_count +
	             sb^.ext2_sb.desc_per_block - 1) div sb^.ext2_sb.desc_per_block;

	{$IFDEF DEBUG_EXT2_READ_SUPER}
		print_bochs('root fs: revision %d  inode count: %d  block count: %d\n',
						[super^.rev_level, super^.inodes_count, super^.blocks_count]);
		print_bochs('block size: %d  first block: %d  db_count: %d\n',
						[blk_size, super^.first_data_block, db_count]);
	{$ENDIF}

	{* FIXME: there is a problem if db_count > 146 because if so,
	 * we ask kmalloc() a block > 4096 bytes; which it cannot do *}
	sb^.ext2_sb.group_desc := kmalloc(db_count * sizeof(P_buffer_head));
	if (sb^.ext2_sb.group_desc = NIL) then
	begin
		printk('EXT2-fs: not enough memory\n', []);
		result := NIL;
		exit;
	end;

	for i := 0 to (db_count - 1) do
	begin
		sb^.ext2_sb.group_desc[i] := bread(major, minor, logic_sb_block + i + 1, sb^.blksize);
		if (sb^.ext2_sb.group_desc[i] = NIL) then
	       printk('EXT2-fs: unable to read group descriptor %d\n', [i]);
	end;

	{ FIXME: Il faudrait charger en mémoire quelques blocs de bitmap }

	sb^.op := @ext2_super_operations;
	result := sb;

{   super^.state := EXT2_ERROR_FS;
   ext2_write_super(sb);}

end;



{******************************************************************************
 * ext2_write_super
 *
 *****************************************************************************}
procedure ext2_write_super (sb : P_super_block_t);

begin

   mark_buffer_dirty(sb^.ext2_sb.real_sb_bh);
   lock_buffer(sb^.ext2_sb.real_sb_bh);
   ll_rw_block(WRITE, sb^.ext2_sb.real_sb_bh);
   wait_on_buffer(sb^.ext2_sb.real_sb_bh);
   sb^.dirty := 0;

end;



{******************************************************************************
 * ext2_get_group_desc
 *
 *****************************************************************************}
function ext2_get_group_desc (sb : P_super_block_t ; block_group : dword ; bh : PP_buffer_head) : P_ext2_group_desc; [public, alias : 'EXT2_GET_GROUP_DESC'];

var
   group_desc, desc : dword;
   gdp : P_ext2_group_desc;

begin

   result := NIL;

   if (sb = NIL) then
   begin
      printk('ext2_get_group_desc: sb=NIL\n', []);
      exit;
   end;

   if (block_group > sb^.ext2_sb.groups_count) then
   begin
      printk('ext2_get_group_desc (%d): block_group (%d) > groups_counts (%d)\n',
				 [current^.pid, block_group, sb^.ext2_sb.groups_count]);
      exit;
   end;

   {$IFDEF DEBUG_EXT2_GET_GROUP_DESC}
      print_bochs('ext2_get_group_desc (%d): trying to get group desc #%d\n', [current^.pid, block_group]);
   {$ENDIF}

   group_desc := block_group div sb^.ext2_sb.desc_per_block;
   desc       := block_group mod sb^.ext2_sb.desc_per_block;

   {$IFDEF DEBUG_EXT2_GET_GROUP_DESC}
      print_bochs('ext2_get_group_desc (%d): group_desc=%d  desc=%d\n', [current^.pid, group_desc, desc]);
   {$ENDIF}

   if (sb^.ext2_sb.group_desc[group_desc] = NIL) then
   begin
      printk('ext2_get_group_desc (%d): Group descriptor not loaded\n', [current^.pid]);
      exit;
   end;

   gdp := sb^.ext2_sb.group_desc[group_desc]^.data;

   if (bh <> NIL) then
       bh^ := sb^.ext2_sb.group_desc[group_desc];

   result := gdp + desc;

end;



{******************************************************************************
 * ext2_set_bit
 *
 * INPUT : nr   -> Bit to set
 *    	   addr -> Address to count from
 *
 *****************************************************************************}
function ext2_set_bit (nr : dword ; addr : pointer) : dword; [public, alias : 'EXT2_SET_BIT'];
begin

   asm
      mov   edx, addr
      mov   eax, nr
      bts   [edx], eax
      sbb   eax, eax
      mov   result, eax
   end;

end;



{******************************************************************************
 * ext2_unset_bit
 *
 * INPUT : nr   -> Bit to set
 *    	   addr -> Address to count from
 *
 *****************************************************************************}
function ext2_unset_bit (nr : dword ; addr : pointer) : dword; [public, alias : 'EXT2_UNSET_BIT'];
begin

   asm
      mov   edx, addr
      mov   eax, nr
      btr   [edx], eax
      sbb   eax, eax
      mov   result, eax
   end;

end;



{******************************************************************************
 * ext2_find_first_zero_bit
 *
 * INPUT : addr -> The address to start the search at
 *    	   size -> The maximum size to search
 *
 * OUPUT: Returns the bit-number of the first zero bit, not the number of the
 *    	  byte containing a bit.
 *
 * Finds the first zero bit in a memory region.
 *
 * NOTE: code from Linux 2.4.22 (include/asm-i386/bitops.h)
 *
 * FIXME: not fully tested
 *****************************************************************************}
function ext2_find_first_zero_bit (addr : pointer ; size : dword) : dword; [public, alias : 'EXT2_FIND_FIRST_ZERO_BIT'];

var
   d0, d1, d2, res : dword;
   r_edi, r_eax : dword;

begin

   if (size = 0) then
   begin
      result := 0;
      exit;
   end;

   asm
      mov   eax, size
      add   eax, 31
      mov   ecx, eax
      shr   ecx, 5   { ECX = ECX div 32 (number of dwords we have to look at) }
      mov   edi, addr
      mov   ebx, addr
      mov   eax, $FFFFFFFF
      xor   edx, edx
      repz  scasd    { Compares EAX and ES:[EDI] }
      je    @suite

      xor   eax, [edi - 4]
      sub   edi, 4
      bsf   edx, eax

      @suite:
      sub   edi, ebx
      shl   edi, 3   { EDI = EDI div 8 }
      add   edx, edi
{      mov   ebx, eax}
      mov   eax, edx
{      mov   d0 , eax
      mov   eax, ecx
      mov   d1 , eax
      mov   eax, edi
      mov   d2 , eax
      mov   eax, ebx
      mov   res, eax
      mov   eax, d0}
      mov   result, eax
   end;
end;



{******************************************************************************
 * init_ext2_fs
 *
 * EXT2 filesystem initialization
 *****************************************************************************}
procedure init_ext2_fs; [public, alias : 'INIT_EXT2_FS'];
begin

   memset(@ext2_fs_type,                0, sizeof(file_system_type));
   memset(@ext2_super_operations,       0, sizeof(super_operations));
   memset(@ext2_inode_operations,       0, sizeof(inode_operations));
   memset(@ext2_file_operations ,       0, sizeof(file_operations));
   memset(@ext2_file_inode_operations , 0, sizeof(inode_operations));
   memset(@ext2_dir_operations ,        0, sizeof(file_operations));
   memset(@ext2_dir_inode_operations ,  0, sizeof(inode_operations));

   ext2_fs_type.name       := 'ext2';
   ext2_fs_type.fs_flag    := 0;
   ext2_fs_type.read_super := @ext2_read_super;

   { Super block operations }
   ext2_super_operations.read_inode   := @ext2_read_inode;
   ext2_super_operations.write_inode  := @ext2_write_inode;
   ext2_super_operations.write_super  := @ext2_write_super;
   ext2_super_operations.delete_inode := @ext2_delete_inode;

   { Inode operations }
{   ext2_inode_operations.lookup := @ext2_lookup;}
{   ext2_inode_operations.truncate := @ext2_truncate;}

   { File operations }
   ext2_file_operations.read  := @ext2_file_read;
   ext2_file_operations.write := @ext2_file_write;
   ext2_file_inode_operations.unlink   := @ext2_unlink;
   ext2_file_inode_operations.truncate := @ext2_truncate;
   ext2_file_inode_operations.default_file_ops := @ext2_file_operations;

   { Directory operations }
   ext2_dir_operations.read := @ext2_readdir;
   ext2_dir_inode_operations.lookup := @ext2_lookup;
   ext2_dir_inode_operations.create := @ext2_create;
   ext2_dir_inode_operations.default_file_ops := @ext2_dir_operations;

   register_filesystem(@ext2_fs_type);

end;



begin
end.
