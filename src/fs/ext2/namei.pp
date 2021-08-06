{******************************************************************************
 *  namei.pp
 *
 *  Ext2 filenames management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 06/11/2003 - GaLi - Initial version
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


unit _ext2_namei;


INTERFACE


{$I config.inc}
{$I errno.inc}
{$I ext2.inc}
{$I fs.inc}
{$I process.inc}


function  bread (major, minor : byte ; block, size : dword) : P_buffer_head; external;
procedure brelse (bh : P_buffer_head); external;
function  ext2_add_link (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword; external;
function  ext2_delete_entry (inode : P_inode_t ; dir : P_ext2_dir_entry ; bh : P_buffer_head) : dword; external;
function  ext2_empty_dir (inode : P_inode_t) : boolean; external;
function  ext2_find_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_bh : PP_buffer_head) : P_ext2_dir_entry; external;
function  ext2_get_group_desc (sb : P_super_block_t ; block_group : dword ; bh : PP_buffer_head) : P_ext2_group_desc; external;
function  ext2_make_empty (inode, parent : P_inode_t) : dword; external;
function  ext2_new_inode (dir : P_inode_t ; mode : dword) : P_inode_t; external;
procedure ext2_read_inode (inode : P_inode_t); external;
procedure free_inode (inode : P_inode_t); external;
function  inode_uptodate (inode : P_inode_t) : boolean; external;
procedure lc_add_entry (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t); external;
procedure mark_inode_dirty (inode : P_inode_t); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   ext2_file_inode_operations : inode_operations; external name 'U__EXT2_FILE_EXT2_FILE_INODE_OPERATIONS';
	ext2_dir_inode_operations : inode_operations; external name 'U_EXT2_SUPER_EXT2_DIR_INODE_OPERATIONS';



function  ext2_add_nondir (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword;
function  ext2_create (dir : P_inode_t ; name : pchar ; mode : dword) : P_inode_t;
procedure ext2_dec_count(inode : P_inode_t);
procedure ext2_inc_count(inode : P_inode_t);
function  ext2_lookup (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : boolean;
function  ext2_mkdir (dir : P_inode_t ; name : pchar ; mode : dword) : dword;
function  ext2_rmdir (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword;
function  ext2_unlink (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword;



IMPLEMENTATION



{******************************************************************************
 * ext2_inc_count
 *
 *****************************************************************************}
procedure ext2_inc_count(inode : P_inode_t);
begin
	inode^.nlink += 1;
	mark_inode_dirty(inode);
end;



{******************************************************************************
 * ext2_dec_count
 *
 *****************************************************************************}
procedure ext2_dec_count(inode : P_inode_t);
begin
	inode^.nlink -= 1;
	mark_inode_dirty(inode);
end;



{******************************************************************************
 * ext2_create
 *
 *****************************************************************************}
function ext2_create (dir : P_inode_t ; name : pchar ; mode : dword) : P_inode_t; [public, alias : 'EXT2_CREATE'];

var
   inode : P_inode_t;
   len   : dword;
   res   : longint;

begin

   {$IFDEF DEBUG_EXT2_CREATE}
      print_bochs('ext2_create (%d): DIR ino=%d  name=%s  mode=%h\n', [current^.pid, dir^.ino, name, mode]);
   {$ENDIF}

   mode := mode or IFREG;

   inode := ext2_new_inode(dir, mode);
   if (longint(inode) < 0) then
   begin
      result := inode;
      exit;
   end;

   {$IFDEF DEBUG_EXT2_CREATE}
      print_bochs('ext2_create (%d): NEW ino=%d\n', [current^.pid, inode^.ino]);
   {$ENDIF}

   inode^.op := @ext2_file_inode_operations;

   res := ext2_add_link(dir, name, inode);
   if (res < 0) then
   begin
      print_bochs('ext2_create (%d): cannot add link\n', [current^.pid]);
      free_inode(inode);
      result := pointer(res);
      exit;
   end;

   result := inode;

   { Put the new inode in the lookup cache }
   len := 0;
   while (name[len] <> #0) do len += 1;
   lc_add_entry(dir, name, len, @inode);

   {$IFDEF DEBUG_EXT2_CREATE}
      print_bochs('ext2_create (%d): END\n', [current^.pid]);
   {$ENDIF}

end;



{******************************************************************************
 * ext2_lookup
 *
 * This function looks for 'name' in directory 'dir'. It returns FALSE if it
 * fails. Else, 'res_inode' is filled and TRUE is returned.
 *
 * FIXME: - il faudrait 'traverser' les points de montage afin de remplir
 *          correctement le champ sb de la variable inode lors de l'appel
 *          de ext2_read_inode().
 *****************************************************************************}
function ext2_lookup (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : boolean; [public, alias : 'EXT2_LOOKUP'];

var
   bh : P_buffer_head;
   de : P_ext2_dir_entry;

begin

   result := FALSE;

   de := ext2_find_entry(dir, name, len, @bh);

   if (de = NIL) then exit;

   res_inode^^.ino := de^.inode;
   res_inode^^.sb  := dir^.sb;

   ext2_read_inode(res_inode^);

   if not inode_uptodate(res_inode^) then
      res_inode^^.state := 0
   else
      result := TRUE;

   brelse(bh);

end;



{******************************************************************************
 * ext2_unlink
 *
 * Code from inspired from linux-2.6.7
 *****************************************************************************}
function ext2_unlink (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword; [public, alias : 'EXT2_UNLINK'];

var
   res, len : dword;
   bh       : P_buffer_head;
   de       : P_ext2_dir_entry;

begin

   result := -ENOENT;

   len := 0;
   while (name[len] <> #0) do len += 1;

   {$IFDEF DEBUG_EXT2_UNLINK}
      print_bochs('ext2_unlink: dir=%d name=%s (%d) ino=%d\n', [dir^.ino, name, len, inode^.ino]);
   {$ENDIF}

   de := ext2_find_entry(dir, name, len, @bh);
   if (de = NIL) then
	begin
		{$IFDEF DEBUG_EXT2_UNLINK}
			print_bochs('ext2_unlink: entry not found -> %d\n', [result]);
		{$ENDIF}
		exit;
	end;

   res := ext2_delete_entry(inode, de, bh);
   if (res <> 0) then
	begin
		print_bochs('ext2_unlink: error in ext2_delete_entry()\n', []);
      result := res;
	end
   else
   begin
		inode^.ctime := dir^.ctime;
		inode^.dtime := 1;   { FIXME }
      ext2_dec_count(inode);
      result := 0;
   end;

	{$IFDEF DEBUG_EXT2_UNLINK}
		print_bochs('ext2_unlink: END\n', []);
	{$ENDIF}

end;



{******************************************************************************
 * ext2_mkdir
 *
 * Code from inspired from linux-2.6.7
 *****************************************************************************}
function ext2_mkdir (dir : P_inode_t ; name : pchar ; mode : dword) : dword; [public, alias : 'EXT2_MKDIR'];

var
	err	: longint;
	len	: dword;
	inode : P_inode_t;

label out, out_dir, out_fail;

begin

	{$IFDEF DEBUG_EXT2_MKDIR}
		print_bochs('ext2_mkdir (%d): dir^.nlink=%d dir^.ino=%d dir^.blocks=%d\n',
						[current^.pid, dir^.nlink, dir^.ino, dir^.blocks]);
	{$ENDIF}

	err := -EMLINK;

	if (dir^.nlink >= EXT2_LINK_MAX) then
		 goto out;

	ext2_inc_count(dir);

	inode := ext2_new_inode(dir, IFDIR or mode);
	if (longint(inode) < 0) then
		 goto out_dir;

	{$IFDEF DEBUG_EXT2_MKDIR}
		print_bochs('ext2_mkdir (%d): OK, new inode created (%d)\n',
						[current^.pid, inode^.ino]);
	{$ENDIF}

	inode^.op := @ext2_dir_inode_operations;

	ext2_inc_count(inode);

	err := ext2_make_empty(inode, dir);
	if (err <> 0) then
		goto out_fail;

	err := ext2_add_link(dir, name, inode);
	if (err <> 0) then
		goto out_fail;

   { Put the new inode in the lookup cache }
   len := 0;
   while (name[len] <> #0) do len += 1;
   lc_add_entry(dir, name, len, @inode);


out:
	result := err;
	exit;

out_fail:
	ext2_dec_count(inode);
	ext2_dec_count(inode);
	free_inode(inode);

out_dir:
	ext2_dec_count(dir);
	goto out;

end;



{******************************************************************************
 * ext2_rmdir
 *
 * Code from inspired from linux-2.6.7
 *****************************************************************************}
function ext2_rmdir (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword; [public, alias : 'EXT2_RMDIR'];

var
	err : dword;

begin

	err := -ENOTEMPTY;

	if (ext2_empty_dir(inode)) then
	begin
print_bochs('ext2_rmdir: ino=%d  nlink=%d\n', [inode^.ino, inode^.nlink]);
		err := ext2_unlink(dir, name, inode);
print_bochs('ext2_rmdir: ino=%d  nlink=%d  err=%d\n',
[inode^.ino, inode^.nlink, err]);
		if (err <> 0) then
		begin
			print_bochs('ext2_rmdir: ext2_unlink() failed (%d) !!!\n', [err]);
		end
		else
		begin
			ext2_dec_count(inode);
			ext2_dec_count(dir);
		end;
	end;
print_bochs('ext2_rmdir: ino=%d  nlink=%d\n', [inode^.ino, inode^.nlink]);
	result := err;

end;



{******************************************************************************
 * ext2_add_nondir
 *
 *****************************************************************************}
function ext2_add_nondir (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword; [public, alias : 'EXT2_ADD_NONDIR'];

var
	err : longint;

begin

	err := ext2_add_link(dir, name, inode);
	if (err = 0) then
		 ext2_dec_count(inode);

	result := err;

end;



begin
end.
