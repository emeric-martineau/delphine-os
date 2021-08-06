{******************************************************************************
 *  inode.pp
 *
 *  Ext2 inodes management
 *
 *  Copyleft 2002 GaLi
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


{DEFINE DEBUG}


{$I fs.inc}
{$I ext2.inc}
{$I buffer.inc}


function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
function  buffer_uptodate (bh : P_buffer_head) : boolean; external;
function  inode_uptodate (inode : P_inode_t) : boolean; external;
function  IS_BLK (inode : P_inode_t) : boolean; external;
function  IS_CHR (inode : P_inode_t) : boolean; external;
function  IS_DIR (inode : P_inode_t) : boolean; external;
function  IS_FIFO (inode : P_inode_t) : boolean; external;
function  IS_REG (inode : P_inode_t) : boolean; external;
procedure printk (format : string ; args : array of const); external;


var
   blkdev_inode_operations    : inode_operations; external name 'U_VFS_BLKDEV_INODE_OPERATIONS';
   chrdev_inode_operations    : inode_operations; external name 'U_VFS_CHRDEV_INODE_OPERATIONS';
   ext2_dir_inode_operations  : inode_operations; external name 'U_EXT2_SUPER_EXT2_DIR_INODE_OPERATIONS';
   ext2_file_inode_operations : inode_operations; external name 'U__EXT2_FILE_EXT2_FILE_INODE_OPERATIONS';


function  ext2_lookup (dir : P_inode_t ; name : string ; len : dword ; res_inode : P_inode_t) : boolean;
procedure ext2_read_inode (inode : P_inode_t);



IMPLEMENTATION



{******************************************************************************
 * ext2_read_inode
 *
 * Lit un inode sur un système de fichier ext2 et rempli l'objet inode passé
 * en paramètre. Les champs sb et ino de l'objet inode passé en paramètre 
 * doivent être initialisés AVANT l'appel de cette procédure.
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

{$IFDEF DEBUG}
printk('inode to read: %d  ', [inode^.ino]);
printk('inodes count: %d  ', [inode^.sb^.ext2_sb.inodes_count]);
printk('inodes per group: %d\n', [inode^.sb^.ext2_sb.inodes_per_group]);
printk('groups count: %d  ', [inode^.sb^.ext2_sb.groups_count]);
printk('desc per block: %d\n', [inode^.sb^.ext2_sb.desc_per_block]);
{$ENDIF}

   major := inode^.sb^.dev_major;
   minor := inode^.sb^.dev_minor;

   if (inode^.ino <> 2) and (inode^.ino < 11) and
      (inode^.ino > inode^.sb^.ext2_sb.inodes_count) then
      begin
         printk('EXT2-fs (ext2_read_inode): bad inode number (%d)\n', [inode^.ino]);
	 inode^.state := 0;
	 exit;
      end;

   {* block_group défini le groupe de blocs contenant l'inode que l'on
    * cherche *}
   block_group := (inode^.ino - 1) div (inode^.sb^.ext2_sb.inodes_per_group);
   if (block_group >= inode^.sb^.ext2_sb.groups_count) then
      begin
         printk('EXT2-fs (ext2_read_inode): block_group >= groups_count\n', []);
	 inode^.state := 0;
	 exit;
      end;

{$IFDEF DEBUG}
printk('block_group: %d  ', [block_group]);
{$ENDIF}

   {* group_desc défini l'index a utilisé dans ext2_sb.group_desc[] afin de
    * pouvoir lire le descripteur de bloc *}
   group_desc := block_group div inode^.sb^.ext2_sb.desc_per_block;

{$IFDEF DEBUG}
printk('group desc: %d  ', [group_desc]);
{$ENDIF}

   {* desc défini le descripteur concerné à l'intérieur de
    * ext2_sb.group_desc[group_desc] *}
   desc := block_group and (inode^.sb^.ext2_sb.desc_per_block - 1);

{$IFDEF DEBUG}
printk('desc: %d\n', [desc]);
{$ENDIF}

   { group_desc[group_desc] a été initialisé lors de la lecture du superbloc
     ext2 }
   bh := inode^.sb^.ext2_sb.group_desc[group_desc];
   if (bh = NIL) then
      begin
         printk('EXT2-fs (ext2_read_inode): descriptor not loaded (%d)\n', [block_group]);
	 inode^.state := 0;
	 exit;
      end;

   { gdp est un pointeur vers le bloc contenant le descripteur de groupe }
   gdp := bh^.data;

{$IFDEF DEBUG}
printk('inode table: %d  ', [gdp[desc].inode_table]);
printk('dirs: %d\n', [gdp[desc].used_dirs_count]);
{$ENDIF}

   { On doit maintenant lire le bloc contenant l'inode demandé }

   {* Un bloc contient plusieurs inodes. offset défini l'offset ou commence
    * l'inode demandé dans le bloc contenant cet inode }
   offset := (inode^.ino - 1) mod inode^.sb^.ext2_sb.inodes_per_block *
              sizeof(ext2_inode);

{$IFDEF DEBUG}
printk('offset: %d  ', [offset]);
{$ENDIF}

   { block défini le bloc contenant l'inode demandé }
   block := gdp[desc].inode_table +  (((inode^.ino - 1) mod 
            inode^.sb^.ext2_sb.inodes_per_group * sizeof(ext2_inode)) 
 	    shr (inode^.sb^.ext2_sb.log_block_size + 10));

{$IFDEF DEBUG}
printk('block: %d\n', [block]);
{$ENDIF}

   bh := bread(major, minor, block, inode^.sb^.blocksize);

   if (bh = NIL) then
      begin
         printk('EXT2-fs: unable to read inode block %d\n', [block]);
	 inode^.state := 0;
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
   inode^.blocks   := raw_inode^.blocks;
   inode^.ext2_i.block_group := block_group;

   { On va définir les 'inodes_operations' }

   if (IS_BLK(inode) or IS_CHR(inode)) then
      begin
         inode^.rdev_maj := hi(lo(raw_inode^.block[1]));
	 inode^.rdev_min := lo(lo(raw_inode^.block[1]));
      end
   else
      begin
         inode^.rdev_maj := major;
	 inode^.rdev_min := minor;
	 for i := 1 to 15 do
	     inode^.ext2_i.data[i] := raw_inode^.block[i];
	 {$IFDEF DEBUG}
	    for i := 1 to 15 do
	        printk('%d ', [raw_inode^.block[i]]);
	    printk('\n', []);
	 {$ENDIF}
      end;

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
         printk('EXT2-fs (read_inode): no operations defined for this type of file\n', []);
      end;

end;



{******************************************************************************
 * ext2_lookup
 *
 * Cette fonction recherche 'name' dans le répertoire 'dir'. En cas d'échec,
 * elle renvoie FALSE. Autrement, 'res_inode' est rempli avec les informations
 * de l'inode de 'name' et la fonction renvoie TRUE.
 *
 * REMARQUE: on ne lit que les blocs directs de l'inode 'dir' (cela ne devrait
 *           pas poser de problème...   j'espère)
 *
 * REMARQUE 2: il faut 'traverser' les points de montage afin de remplir
 *             correctement le champ sb de la variable inode lors de l'appel
 *             de ext2_read_inode().
 *****************************************************************************}
function ext2_lookup (dir : P_inode_t ; name : string ; len : dword ; res_inode : P_inode_t) : boolean; [public, alias : 'EXT2_LOOKUP'];

var
   bh           : P_buffer_head;
   entry        : P_ext2_dir_entry;
   entry_name   : string;
   i, j, ofs    : dword;
   major, minor : byte;

begin

   major  := dir^.dev_maj;
   minor  := dir^.dev_min;
   result := FALSE;

   for i := 1 to 12 do   { On ne lit que les blocs directs }
   begin
      if (dir^.ext2_i.data[i] <> 0) then
      begin
         bh := bread(major, minor, dir^.ext2_i.data[i], dir^.sb^.blocksize);
         if (bh = NIL) then
         begin
            printk('VFS (ext2_lookup): cannot read block %d\n', [dir^.ext2_i.data[1]]);
	    result := FALSE;
	    exit;
         end;

         ofs := 0;

	 while (ofs < dir^.sb^.blocksize) do
	 begin
            entry := bh^.data + ofs;

            { entry_name string initialization }
            entry_name[0] := chr(entry^.name_len);
            for j := 1 to ord(entry_name[0]) do
                entry_name[j] := entry^.name[j];
            entry_name[j+1] := #0;

	    {$IFDEF DEBUG}
	       printk('%s (%d, %d)', [entry_name, entry^.rec_len, ofs]);
	    {$ENDIF}

	    if (entry_name = name) then
	    { Le fichier a été trouvé. On va lire son inode }
	    begin
	       res_inode^.ino := entry^.inode;
	       res_inode^.sb  := dir^.sb;
	       ext2_read_inode(res_inode);
	       if not inode_uptodate(res_inode) then
	          begin
		     res_inode^.state := 0;
		     {$IFDEF DEBUG}
		        printk('\n', []);
		     {$ENDIF}
		     exit;
		  end
	       else
	          begin
	             result := TRUE;
		     {$IFDEF DEBUG}
		        printk('\n', []);
		     {$ENDIF}
		     exit;
		  end;
	    end
	    else
	        ofs += entry^.rec_len;
	 end;   { while }

      end { if }
      else
          break;   { Il n'y a plus de bloc de données à lire }

   end; { for }

   {$IFDEF DEBUG}
      printk('\n', []);
   {$ENDIF}

end;



begin
end.
