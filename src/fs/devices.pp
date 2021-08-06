{******************************************************************************
 *  devices.pp
 * 
 *  Fonctions de gestion des périphériques via le VFS
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



unit devices;


INTERFACE


{$I blk.inc}
{$I buffer.inc}
{$I fs.inc}
{$I process.inc}


procedure printk (format : string ; args : array of const); external;


var
   chrdevs : array[0..MAX_NR_CHAR_DEV] of device_struct; external name 'U_VFS_CHRDEVS';
   blkdevs : array[0..MAX_NR_BLOCK_DEV] of device_struct; external name 'U_VFS_BLKDEVS';


function  blkdev_open (inode : P_inode_t ; filp : P_file_t) : dword;
function  chrdev_open (inode : P_inode_t ; filp : P_file_t) : dword;



IMPLEMENTATION



{******************************************************************************
 * blkdev_open
 *
 * Entrée : inode, fichier
 *
 * Retour : -1 en cas d'erreur, sinon code de retour de la fonction open()
 *          du périphérique.
 *
 * Cette fonction est appelée lorsqu'un fichier spécial en mode bloc est
 * ouvert.
 *****************************************************************************}
function blkdev_open (inode : P_inode_t ; filp : P_file_t) : dword; [public, alias : 'BLKDEV_OPEN'];

begin

   if (inode^.rdev_maj > MAX_NR_BLOCK_DEV) then
       begin
          printk('VFS (blkdev_open): major number is too big (%d)\n', [inode^.rdev_maj]);
	  result := -1;
	  exit;
       end;

   filp^.op := blkdevs[inode^.rdev_maj].fops;

   if (filp^.op = NIL) then
      begin
         printk('VFS (open): block device %d:%d is not registered\n', [inode^.rdev_maj, inode^.rdev_min]);
         result := -1;
      end
   else
      begin
         if (filp^.op^.open = NIL) then
	     result := 0
	 else
	     result := filp^.op^.open(inode, filp);
      end;
end;



{******************************************************************************
 * chrdev_open
 *
 * Entrée : inode, fichier
 *
 * Retour : -1 en cas d'erreur, sinon, code de retour de la fonction open()
 *          du périphérique.
 *
 * Cette fonction est appelée lorsqu'un fichier spécial en mode caractère est
 * ouvert.
 *****************************************************************************}
function chrdev_open (inode : P_inode_t ; filp : P_file_t) : dword; [public, alias : 'CHRDEV_OPEN'];
begin

   if (inode^.rdev_maj > MAX_NR_CHAR_DEV) then
       begin
          printk('VFS (chrdev_open): major number is too big (%d)\n', [inode^.rdev_maj]);
	  result := -1;
	  exit;
       end;

   filp^.op := chrdevs[inode^.rdev_maj].fops;

   if (filp^.op = NIL) then
      begin
         printk('VFS (open): char device %d:%d is not registered\n', [inode^.rdev_maj, inode^.rdev_min]);
	 result := -1;
      end
   else
      begin
         if (filp^.op^.open = NIL) then
	     result := 0
	 else
	     result := filp^.op^.open(inode, filp);
      end;
end;



begin
end.
