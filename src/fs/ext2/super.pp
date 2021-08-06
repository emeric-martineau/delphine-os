{******************************************************************************
 *  ext2_super.pp
 * 
 *  Ext2 filesystems management
 *
 *  CopyLeft 2002 GaLi
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


{DEFINE DEBUG}


{$I buffer.inc}
{$I ext2.inc}
{$I fs.inc}


procedure register_filesystem (fs : P_file_system_type); external;
procedure printk (format : string ; args : array of const); external;
function  ext2_file_read (fichier : P_file_t ; buffer : pointer ; count : dword) : dword; external;
function  ext2_lookup (dir : P_inode_t ; name : string ; len : dword ; res_inode : P_inode_t) : boolean; external;
procedure ext2_read_inode (inode : P_inode_t); external;
function  kmalloc (len : dword) : pointer; external;
function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;


var
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
    * bloc logique n°1 (un bloc logique = 2 secteurs *}

   major := sb^.dev_major;
   minor := sb^.dev_minor;
   logic_sb_block := 1;

   bh := bread(major, minor, logic_sb_block, 1024);

   if (bh = NIL) then
      begin
         printk('EXT2-fs: unable to read superblock\n', []);
	 result := NIL;
	 exit;
      end
   else
      begin
         super := bh^.data;
	 { Check if superblock is valid }
         if (super^.magic <> $EF53) then
	     begin
	        printk('EXT2-fs: bad magic number on superbloc (%h4) !!!\n', [super^.magic]);
	        result := NIL;
		exit;
	     end
	 else if (super^.log_block_size > 2) then
	     begin
	        printk('EXT2-fs: logical block size is invalid (%d) !!!\n', [super^.log_block_size]);
	        result := NIL;
		exit;
	     end
	 else if (super^.free_blocks_count > super^.blocks_count) then
	     begin
	        printk('EXT2-fs: free blocks count > blocks count !!!\n', []);
		result := NIL;
		exit;
	     end
	 else
	     {* Superblock seems to be valid, we are going to fill sb (passed
	      * a parameter) *}
	      
	     if (super^.rev_level > 0) then
	         printk('EXT2-fs: superblock has revision level > 0 (%d), I may not read it correctly !!!\n', [super^.rev_level]);

	     case (super^.log_block_size) of
	        0: blk_size := 1024;
		1: blk_size := 2048;
		2: blk_size := 4096;
	     end;

	     logic_sb_block := super^.first_data_block;
	     sb^.dirty := 0;
	     sb^.blocksize := blk_size;
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
	     sb^.ext2_sb.desc_per_block   := blk_size div
	                                     sizeof(ext2_group_desc);
	     db_count := (sb^.ext2_sb.groups_count +
	                  sb^.ext2_sb.desc_per_block - 1) div
			  sb^.ext2_sb.desc_per_block;

{$IFDEF DEBUG}
printk('\nroot fs: revision %d  inode count: %d  block count: %d\n', [super^.rev_level, super^.inodes_count, super^.blocks_count]);
printk('block size: %d  first block: %d  db_count: %d\n', [blk_size, super^.first_data_block, db_count]);
{$ENDIF}

	     sb^.ext2_sb.group_desc := kmalloc(db_count * sizeof(P_buffer_head));
	     if (sb^.ext2_sb.group_desc = NIL) then
	        begin
		   printk('EXT2-fs: not enough memory\n', []);
		   result := NIL;
		   exit;
		end;

	     for i := 0 to (db_count - 1) do
	        begin
		   sb^.ext2_sb.group_desc[i] := bread(major, minor,
		                                      logic_sb_block + i + 1,
						      sb^.blocksize);
		   if (sb^.ext2_sb.group_desc[i] = NIL) then
		      begin
		         printk('EXT2-fs: unable to read group descriptors\n', []);
			 result := NIL;
			 exit;
		      end;
		end;

{ Il faudrait charger en mémoire quelques blocs de bitmap }

	     sb^.op := @ext2_super_operations;
	     result := sb;
      end;
end;



{******************************************************************************
 * init_ext2_fs
 *
 * Initialisation du systeme de fichiers EXT2
 *****************************************************************************}
procedure init_ext2_fs; [public, alias : 'INIT_EXT2_FS'];
begin
   ext2_fs_type.name := 'ext2';
   ext2_fs_type.fs_flag := 0;
   ext2_fs_type.read_super := @ext2_read_super;

   ext2_super_operations.read_inode := @ext2_read_inode;
   ext2_inode_operations.lookup     := @ext2_lookup;

   { Opérations sur fichiers réguliers }
   ext2_file_operations.open  := NIL;
   ext2_file_operations.read  := @ext2_file_read;
   ext2_file_operations.write := NIL;
   ext2_file_inode_operations.default_file_ops := @ext2_file_operations;
   ext2_file_inode_operations.lookup := NIL;

   { Opérations sur répertoires }
   ext2_dir_operations.open  := NIL;
   ext2_dir_operations.read  := NIL;
   ext2_dir_operations.write := NIL;
   ext2_dir_inode_operations.default_file_ops := @ext2_dir_operations;
   ext2_dir_inode_operations.lookup := @ext2_lookup;

   register_filesystem(@ext2_fs_type);
end;



begin
end.
