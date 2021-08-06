{******************************************************************************
 *  init_vfs.pp
 * 
 *  Initialisation du Virtual File System
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0 - ??/??/2001 - GaLi
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
 *****************************************************************************}


unit vfs;


INTERFACE


{$I blk.inc}
{$I buffer.inc}
{$I fs.inc}
{$I process.inc}


procedure printk(format : string ; args : array of const); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure init_ext2_fs; external;
function  blkdev_open (inode : P_inode_t ; filp : P_file_t) : dword; external;
function  chrdev_open (inode : P_inode_t ; filp : P_file_t) : dword; external;
function  tty_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; external;


var
   file_systems : P_file_system_type;
   chrdevs : array [0..MAX_NR_CHAR_DEV] of device_struct;
   blkdevs : array [0..MAX_NR_BLOCK_DEV] of device_struct;
   def_blk_fops : file_operations;
   blkdev_inode_operations : inode_operations;
   def_chr_fops : file_operations;
   chrdev_inode_operations : inode_operations;

   tty_fops : file_operations; external name 'U_TTY__TTY_FOPS';
   buffer_head_list : array [1..1024] of P_buffer_head; external name 'U_BUFFER_BUFFER_HEAD_LIST';
   nr_buffer_head   : dword; external name 'U_BUFFER_NR_BUFFER_HEAD';
   blk_dev : array [0..MAX_NR_BLOCK_DEV] of blk_dev_struct; external name 'U_RW_BLOCK_BLK_DEV';
   blksize : array [0..MAX_NR_BLOCK_DEV, 0..128] of dword; external name 'U_RW_BLOCK_BLKSIZE';
   wait_for_request : P_wait_queue;



IMPLEMENTATION



{******************************************************************************
 * register_filesystem
 *
 * Entrée : système de fichiers
 *
 * Enregistre le système de fichier dans le VFS
 *****************************************************************************}
procedure register_filesystem (fs : P_file_system_type); [public, alias : 'REGISTER_FILESYSTEM'];

{ Il faudrait verifier si le système de fichiers n'est pas deja enregistré }

var
   tmp : P_file_system_type;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   tmp := file_systems;
   file_systems := fs;
   fs^.next := tmp;

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * register_chrdev
 *
 * Entrée : numéro majeur, nom, pointeur vers opérations sur périphérique
 *
 * Enregistre un périphérique en mode caractère
 *****************************************************************************}
procedure register_chrdev (nb : byte ; name : string[20] ; fops : pointer); [public, alias : 'REGISTER_CHRDEV'];
begin

   if (nb > MAX_NR_CHAR_DEV) or (nb = 0) then
       begin
          printk('register_chrdev: illegal major number (%d) \n', [nb]);
	  exit;
       end;

   if (chrdevs[nb].fops <> NIL) then
       begin
          printk('register_chrdev: device %d is already registered\n', [nb]);
	  exit;
       end;

   asm
      pushfd
      cli     { Section critique }
   end;
   chrdevs[nb].name := name;
   chrdevs[nb].fops := fops;
   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * unregister_chrdev
 *
 * Entrée : numéro majeur
 *
 * Désenregistre un périphérique en mode caractère
 *****************************************************************************}
procedure unregister_chrdev (nb : byte);
begin

   if (chrdevs[nb].fops = NIL) then
       begin
          printk('unregister_chrdev: device %d is not registered\n', [nb]);
	  exit;
       end;

   asm
      pushfd
      cli   { Section critique }
   end;
   chrdevs[nb].name := '';
   chrdevs[nb].fops := NIL;
   asm
      popfd   { Fin section critique }
   end;
end;



{******************************************************************************
 * register_blkdev
 *
 * Entrée : numéro majeur, nom, pointeur vers opérations sur périphérique
 *
 * Enregistre un périphérique en mode bloc
 *****************************************************************************}
procedure register_blkdev (nb : byte ; name : string[20] ; fops : P_file_operations); [public, alias : 'REGISTER_BLKDEV'];
begin

   if (nb > MAX_NR_BLOCK_DEV) or (nb = 0) then
       begin
          printk('register_blkdev: illegal major number (%d)\n', [nb]);
	  exit;
       end;

   if (blkdevs[nb].fops <> NIL) then
       begin
          printk('register_blkdev: device %d already registered\n', [nb]);
	  exit;
       end;

   asm
      pushfd
      cli     { Section critique }
   end;
   blkdevs[nb].name := name;
   blkdevs[nb].fops := fops;
   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * unregister_blkdev
 *
 * Entrée : numéro majeur
 *
 * Désenregistre un périphérique en mode bloc
 *****************************************************************************}
procedure unregister_blkdev (nb : byte);
begin

   if (blkdevs[nb].fops = NIL) then
       begin
          printk('unregister_blkdev: device %d is not registered\n', [nb]);
	  exit;
       end;

   asm
      pushfd
      cli   { Section critique }
   end;
   blkdevs[nb].name := '';
   blkdevs[nb].fops := NIL;
   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * init_vfs
 *
 * Initialize virtual file system. The procedure is only called during
 * DelphineOS initialization.
 *****************************************************************************}
procedure init_vfs; [public, alias : 'INIT_VFS'];

begin

   { Initialize kernel data }
   memset(@buffer_head_list, 0, sizeof(buffer_head_list));
   memset(@chrdevs, 0, sizeof(chrdevs));
   memset(@blkdevs, 0, sizeof(blkdevs));
   memset(@blk_dev, 0, sizeof(blk_dev));
   memset(@blksize, 0, sizeof(blksize));

   nr_buffer_head   := 0;
   file_systems     := NIL;
   wait_for_request := NIL;

   { Initialisation des opérations sur les périphériques en mode bloc }
   def_blk_fops.open  := @blkdev_open;
   def_blk_fops.read  := NIL;
   def_blk_fops.write := NIL;
   blkdev_inode_operations.default_file_ops := @def_blk_fops;
   blkdev_inode_operations.lookup           := NIL;

   { Initialisation des opérations sur les périphériques en mode caractère }
   def_chr_fops.open  := @chrdev_open;
   def_chr_fops.read  := NIL;
   def_chr_fops.write := NIL;
   chrdev_inode_operations.default_file_ops := @def_chr_fops;
   chrdev_inode_operations.lookup           := NIL;

   { Filesystems structures initialization }

   init_ext2_fs;

   { Register 'tty' device }
   register_chrdev(4, 'tty', @tty_fops);
end;



begin
end.
