{******************************************************************************
 *  super.pp
 * 
 *  mount/unmount filesystems
 *
 *  FIXME: for the moment, delphineOS can only mount ONE filesystem. (the root
 *         filesystem which MUST be an ext2 filesystem)
 *
 *  CopyLeft 2003 GaLi
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


{DEFINE DEBUG_MOUNT_ROOT}
{DEFINE ACCESS_RIGHTS_WARNING}
{DEFINE SHOW_BLOCKSIZE}

{$I fs.inc}
{$I process.inc }


function  alloc_inode : P_inode_t; external;
function  blkdev_open (inode : P_inode_t ; filp : P_file_t) : dword; external;
function  inode_uptodate (inode : P_inode_t) : boolean; external;
procedure kernel_thread (addr : pointer); external;
procedure kflushd; external;
function  kmalloc (len : dword) : pointer; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;
procedure read_inode (ino : P_inode_t); external;


function  access_rights_ok (flags : dword ; inode : P_inode_t) : boolean;
procedure sys_mount_root; cdecl;


var
   file_systems : P_file_system_type; external name 'U_VFS_FILE_SYSTEMS';
   current      : P_task_struct; external name 'U_PROCESS_CURRENT';



IMPLEMENTATION


{$I inline.inc}


{******************************************************************************
 * sys_mount_root
 *
 * Mount the root filesystem. This procedure is called by init() through a
 * system call. Only init() can call this procedure.
 *
 * NOTE : - code inspired by fs/super.c from Linux
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

	sti();

   if (current^.root <> NIL) or (current^.pwd <> NIL) then
       panic('Non root process trying to call sys_mount_root()');

   inode := alloc_inode();
   if (inode = NIL) then
   begin
      printk('mount_root: not enough memory\n', []);
      panic('no root filesystem');
   end;

   memset(@filp, 0, sizeof(filp));

   { Inode object initialization }
   inode^.dev_maj  := ROOT_DEV_MAJ;
   inode^.dev_min  := ROOT_DEV_MIN;
   inode^.rdev_maj := ROOT_DEV_MAJ;
   inode^.rdev_min := ROOT_DEV_MIN;

   filp.mode := 1; { Read only }

   {$IFDEF DEBUG_MOUNT_ROOT}
      printk('mount_root: calling blkdev_open()...   ', []);
   {$ENDIF}
   retval := blkdev_open(inode, @filp);
   {$IFDEF DEBUG_MOUNT_ROOT}
      printk('OK\n', []);
   {$ENDIF}

   { retval = 0 if everything is ok }
   if (retval <> 0) then
   begin
      printk('VFS: cannot open device %d:%d\n', [ROOT_DEV_MAJ,ROOT_DEV_MIN]);
      panic('no root filesystem');
   end
   else
   begin
      {$IFDEF DEBUG_MOUNT_ROOT}
         printk('mount_root: retval=0\n', []);
      {$ENDIF}
      fs_type := file_systems;
      sb := kmalloc(sizeof(super_block_t));
      sb^.dev_major := ROOT_DEV_MAJ;
      sb^.dev_minor := ROOT_DEV_MIN;
      repeat
         {$IFDEF DEBUG_MOUNT_ROOT}
            printk('mount_root: fs_type=%h\n', [fs_type]);
         {$ENDIF}
         if (fs_type^.name = 'ext2') then
	 		begin
	    		{$IFDEF DEBUG_MOUNT_ROOT}
	       		printk('mount_root: fs_type^.name=''ext2''\n', []);
	       		printk('mount_root: calling read_super()...   ', []);
	    		{$ENDIF}
	    		sb := fs_type^.read_super(sb);
	    		{$IFDEF DEBUG_MOUNT_ROOT}
	       		printk('OK\n', []);
	    		{$ENDIF}
	    		if (sb <> NIL) then
	    		{* We successfully read an ext2 superblock. So, we stop looking
	      	* for a superblock. Then, we try to read the ROOT_INODE
	      	* (inode n°2). *}
	    		begin
	       		inode^.sb   := sb;
	       		inode^.ino  := EXT2_ROOT_INO;
	       		read_inode(inode);
	       		if not inode_uptodate(inode) then
	       		begin
	          		printk('VFS: unable to read root inode\n', []);
		   			panic('no root filesystem');
	       		end;
	       		inode^.count    := 2;
	       		current^.root   := inode;
	       		current^.pwd    := inode;
	       		current^.cwd[0] := #1;
	       		current^.cwd[1] := '/';
	       		printk('VFS: Mounted root (ext2 filesystem)\n', []);
					printk('\nUse ''sync'' to save changes to disk\n\n', []);
	       
	       		{ Launch kflushd }
	       		kernel_thread(@kflushd);
	       
	       		exit;
	    		end;
	 		end;
	 		fs_type := fs_type^.next;
         sb := NIL;
      until fs_type = NIL;
   end;

   if (sb = NIL) then
   begin
      printk('VFS: Ext2 superblock not found on dev %d:%d\n', [ROOT_DEV_MAJ, ROOT_DEV_MIN]);
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
 *
 * FIXME: rewrite this function.
 *****************************************************************************}
function access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; [public, alias : 'ACCESS_RIGHTS_OK'];

var
   tuid, tgid, tflags : dword;

begin

   {* We just care about the three first bits *}
   flags := flags and $3;

   {$IFDEF ACCESS_RIGHTS_WARNING}
      if (flags = 3) then
          printk('WARNING: access_rights_ok called with flags=3\n', []);
   {$ENDIF}

   case (flags) of
   0: begin
         flags := 4;   { Read only }
      end;
   1: begin
         flags := 2;   { Write only }
      end;
   2: begin
         flags := 6;   { Read/Write }
      end;
   3: begin
         flags := 1;   { Execute ??? } { FIXME }
      end;
   else
      begin
         printk('access_rights_ok: %h is not a correct value. Set flags to read only.\n', [flags]);
	 		flags := 4;
      end;
   end;

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
