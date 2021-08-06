{******************************************************************************
 *  super.pp
 * 
 *  mount/unmount filesystems
 *
 *  FIXME: for the moment, delphineOS can only mount ONE filesystem. (the root
 *         filesystem which MUST be an ext2 filesystem)
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0 - ??/??/2001 - GaLi - initial version
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


unit vfs_super;


INTERFACE


{$I fs.inc}
{$I process.inc }


function  blkdev_open (inode : P_inode_t ; filp : P_file_t) : dword; external;
function  inode_uptodate (inode : P_inode_t) : boolean; external;
function  kmalloc (len : dword) : pointer; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;
procedure read_inode (ino : P_inode_t); external;


var
   file_systems : P_file_system_type; external name 'U_VFS_FILE_SYSTEMS';
   current      : P_task_struct; external name 'U_PROCESS_CURRENT';



IMPLEMENTATION



{******************************************************************************
 * sys_mount_root
 *
 * Mount the root filesystem. This procedure is called by init() through a
 * system call. Only init() can call this procedure.
 *
 * Note : - code inspired by fs/super.c from Linux
 *        - root filesystem MUST be an ext2 filesystem.
 *****************************************************************************}
procedure sys_mount_root; cdecl; [public, alias : 'SYS_MOUNT_ROOT'];


{* FIXME: It would be better if we checked if the device could be opened with
 * asked mode (read only or read/write). We could check that with retval *}


const
   ROOT_DEV_MAJ = 3; { Major number (see drivers/block/ide.pp) }
   ROOT_DEV_MIN = 1; { Minor number (see drivers/block/ide.pp) }

var
   inode   : P_inode_t;
   filp    : file_t;
   retval  : dword;
   fs_type : P_file_system_type;
   sb      : P_super_block_t;

begin

   asm
      sti   { Put interrupts on }
   end;

   inode := kmalloc(sizeof(inode_t));
   if (inode = NIL) then
      begin
         printk('MOUNT_ROOT: not enough memory\n', []);
      end;

   memset(@filp, 0, sizeof(filp));
   memset(inode, 0, sizeof(inode_t));

   { Inode object initialization }
   inode^.dev_maj  := ROOT_DEV_MAJ;
   inode^.dev_min  := ROOT_DEV_MIN;
   inode^.rdev_maj := ROOT_DEV_MAJ;
   inode^.rdev_min := ROOT_DEV_MIN;

   filp.mode  := 1; { Read only }

   retval := blkdev_open(inode, @filp);

   { retval = 0 if everything is ok }
   if (retval <> 0) then
      begin
         printk('VFS: cannot open device %d:%d !!!\n', [ROOT_DEV_MAJ,ROOT_DEV_MIN]);
	 panic('no root filesystem');
      end
   else
      begin
         fs_type := file_systems;
	 sb := kmalloc(sizeof(super_block_t));
	 sb^.dev_major := ROOT_DEV_MAJ;
	 sb^.dev_minor := ROOT_DEV_MIN;
	 repeat
	    if (fs_type^.name = 'ext2') then
	    begin
	       sb := fs_type^.read_super(sb);
	       if (sb <> NIL) then
	       {* We successfully read an ext2 superblock. So, we stop looking
	        * for a superblock. Then, we try to read the ROOT_INODE
		* (inode n°2). *}
	       begin
		  inode^.sb    := sb;
		  inode^.ino   := 2;
		  read_inode(inode);
		  if not inode_uptodate(inode) then
		     begin
		        printk('VFS: unable to read root inode\n', []);
			panic('no root filesystem');
		     end;
		  current^.root := inode;
		  current^.pwd  := inode;
		  printk('VFS: Mounted root (ext2 filesystem) readonly.\n', []);
	          exit;
	       end;
	    end;
	    fs_type := fs_type^.next;
            sb := NIL;
	 until fs_type = NIL;
      end;

   if (sb = NIL) then
      begin
         printk('VFS: Ext2 superblock not found on dev %d:%d !!!\n', [ROOT_DEV_MAJ, ROOT_DEV_MIN]);
	 panic('no root filesystem');
      end;

end;



{******************************************************************************
 * acces_rights_ok
 *
 * Input : acces mode, inode.
 *
 * Output : TRUE or FALSE.
 *
 * Compare inode's access rights and user's access rights
 *****************************************************************************}
function access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; [public, alias : 'ACCESS_RIGHTS_OK'];

var
   tuid, tgid, tflags : dword;

begin

   result := TRUE;

   { If user is 'root', then we consider him as the owner }
   if (current^.uid = 0) and (current^.gid = 0) then
       begin
          tuid := inode^.uid;
	  tgid := inode^.gid;
       end
   else
       begin
          tuid := current^.uid;
	  tgid := current^.gid;
       end;

   if (tuid = inode^.uid) then
   { User is the owner }
       begin
          tflags := (inode^.mode and $1C0) div 64;
	  if (flags and tflags) <> flags then
	      result := FALSE;
       end
   else if (tgid = inode^.gid) then
   { User is a group member }
       begin
          tflags := (inode^.mode and $038) div 8;
	  if (flags and tflags) <> flags then
	      result := FALSE;
       end
   else
   { User is 'others' }
       begin
          tflags := (inode^.mode and $007);
	  if (flags and tflags) <> flags then
	      result := FALSE;
       end;

end;



begin
end.
