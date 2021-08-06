{******************************************************************************
 *  init_vfs.pp
 * 
 *  Virtual File System initialization
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
{$I major.inc}
{$I process.inc}


procedure init_ext2_fs; external;
procedure init_pipe; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure printk(format : string ; args : array of const); external;

function  blkdev_open (inode : P_inode_t ; filp : P_file_t) : dword; external;
function  chrdev_open (inode : P_inode_t ; filp : P_file_t) : dword; external;

function  null_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; external;
function  null_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword; external;

function  tty_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; external;

function  zero_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; external;
function  zero_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword; external;

var
   file_systems : P_file_system_type;
   chrdevs : array [0..MAX_NR_CHAR_DEV] of device_struct;
   blkdevs : array [0..MAX_NR_BLOCK_DEV] of device_struct;
   def_blk_fops, null_fops, zero_fops : file_operations;
   blkdev_inode_operations, chrdev_inode_operations : inode_operations;
   def_chr_fops : file_operations;
   wait_for_request : P_wait_queue;

   tty_fops : file_operations; external name 'U_TTY__TTY_FOPS';
   buffer_head_list : array [1..1024] of P_buffer_head; external name 'U_BUFFER_BUFFER_HEAD_LIST';
   nr_buffer_head   : dword; external name 'U_BUFFER_NR_BUFFER_HEAD';
   blk_dev : array [0..MAX_NR_BLOCK_DEV] of blk_dev_struct; external name 'U_RW_BLOCK_BLK_DEV';
   blksize : array [0..MAX_NR_BLOCK_DEV, 0..128] of dword; external name 'U_RW_BLOCK_BLKSIZE';
   lookup_cache : array[1..1024] of lookup_cache_entry; external name 'U__NAMEI_LOOKUP_CACHE';
   lookup_cache_entries : dword; external name 'U__NAMEI_LOOKUP_CACHE_ENTRIES';



IMPLEMENTATION



{******************************************************************************
 * register_filesystem
 *
 * Entrée : système de fichiers
 *
 * Enregistre le système de fichier dans le VFS
 *****************************************************************************}
procedure register_filesystem (fs : P_file_system_type); [public, alias : 'REGISTER_FILESYSTEM'];

{ FIXME: Il faudrait verifier si le système de fichiers n'est pas deja enregistré }

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

   if (nb > MAX_NR_CHAR_DEV) or (nb = 0) then
   begin
      printk('register_chrdev: illegal major number (%d) \n', [nb]);
      exit;
   end;

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

   if (nb > MAX_NR_BLOCK_DEV) or (nb = 0) then
   begin
      printk('register_blkdev: illegal major number (%d)\n', [nb]);
      exit;
   end;

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
   memset(@lookup_cache, 0, sizeof(lookup_cache));

{printk('VFS: %d bytes reserved for lookup_cache\n', [sizeof(lookup_cache)]);}

   nr_buffer_head       := 0;
   lookup_cache_entries := 0;
   file_systems         := NIL;
   wait_for_request     := NIL;

   { Initialisation des opérations sur les périphériques en mode bloc }
   memset(@def_blk_fops, 0, sizeof(file_operations));
   memset(@blkdev_inode_operations, 0, sizeof(inode_operations));
   def_blk_fops.open  := @blkdev_open;
   blkdev_inode_operations.default_file_ops := @def_blk_fops;

   { Initialisation des opérations sur les périphériques en mode caractère }
   memset(@def_chr_fops, 0, sizeof(file_operations));
   memset(@chrdev_inode_operations, 0, sizeof(inode_operations));
   def_chr_fops.open  := @chrdev_open;
   chrdev_inode_operations.default_file_ops := @def_chr_fops;

   { Filesystems structures initialization }

   init_ext2_fs();
   init_pipe();

   { Register 'tty' device }
   register_chrdev(TTY_MAJOR, 'tty', @tty_fops);
   register_chrdev(TTYAUX_MAJOR, 'ttyaux', @tty_fops);
   
   { Register 'null' device }
   memset(@null_fops, 0, sizeof(file_operations));
   null_fops.read  := @null_read;
   null_fops.write := @null_write;
   register_chrdev(NULL_MAJOR, 'null', @null_fops);
   
   { Register 'zero' device }
   memset(@zero_fops, 0, sizeof(file_operations));
   zero_fops.read  := @zero_read;
   zero_fops.write := @zero_write;
   register_chrdev(ZERO_MAJOR, 'zero', @zero_fops);

end;



begin
end.
