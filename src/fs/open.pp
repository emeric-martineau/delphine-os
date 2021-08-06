{******************************************************************************
 *  open.pp
 *
 *  open() system call implementation
 *
 *  Copyleft 2002 GaLi
 *
 *  version 0.2 - 02/10/2002 - GaLi - Add function namei()
 *
 *  version 0.1 - 24/09/2002 - GaLi - Correct a few bugs and check access
 *                                    rigths
 *
 *  version 0.0 - 22/08/2002 - GaLi - initial version
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


unit _open;


INTERFACE

{DEFINE DEBUG}

{$I errno.inc}
{$I fs.inc}
{$I process.inc}


{* External procedures and functions definition *}
function  access_rights_ok (flags : dword ; inode : P_inode_t) : boolean; external;
function  IS_DIR (inode : P_inode_t) : boolean; external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure printk (format : string ; args : array of const); external;


{* External variables definition *}
var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


{* Exported variables definition *}


{* Unit procedures and functions definition *}
function  namei (path : pchar) : P_inode_t;
function  sys_open (path : pchar ; flags, mode : dword) : dword; cdecl;


IMPLEMENTATION


{* Constants only used in THIS unit *}


{* Types only used in THIS file *}


{* Global variables only used in THIS file *}



{******************************************************************************
 * lookup
 *
 * Input  : directory inode, file we look for, size of 'name', inode to fill
 *
 * Output : TRUE or FALSE
 *
 * lookup() is not file system dependent. If everything is ok, 'res_inode'
 * is fill with 'name' inode info
 *****************************************************************************}
function lookup (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : P_inode_t) : boolean;
begin

   {$IFDEF DEBUG}
      printk('looking up %c%s\n', [name[0], name]);
   {$ENDIF}

   if (dir^.op^.lookup <> NIL) then
       result := dir^.op^.lookup(dir, name, len, res_inode)
   else
       begin
          printk('VFS: lookup is not defined for %c%s\n', [name[0], name]);
          result := FALSE;
       end;
end;



{******************************************************************************
 * namei
 *
 * Input  : pointer to string
 *
 * Output : Pointer to inode or an error code
 *
 * Converts a pathname to an inode if the file is found.
 *
 * FIXME: for the moment, namei() doesn't check directories access rights
 *****************************************************************************}
function namei (path : pchar) : P_inode_t; [public, alias : 'NAMEI'];

var
   tmp                 : pchar;
   filename, basename  : string;
   base, inode         : P_inode_t;
   i, index, nb_dir, j : dword;
   str_len            : dword;

begin

   { Check if path is not a null string }

   if (path[0] = #0) then
       begin
          printk('VFS (namei): file name is a null string\n', []);
	  result := -EINVAL;
	  exit;
       end;

   tmp := path;

   { 'filename' initialization }

   i := 0;
   while (tmp^ <> #0) do
   begin
      filename[i] := tmp^;
      tmp += 1;
      i   += 1;
   end;
   filename[i] := #0;

   if (filename[0] = '/') then
       begin
          base := current^.root;
	  { Remove the first character ('/') }
	  i := 0;
	  while (filename[i] <> #0) do
	  begin
	     filename[i] := filename[i + 1];
	     i += 1;
	  end;
	  filename[i] := #0;
       end
   else
       base := current^.pwd;

   {* We are going to call lookup() for each directory in the path. So we
    * calculate how many directories there are *}

   nb_dir := 0;
   index  := 0;

   i := 0;
   while (filename[i] <> #0) do
   begin
      if (filename[i] = '/') then 
          nb_dir += 1;
      i += 1;
   end;

   inode := kmalloc(sizeof(inode_t));
   if (inode = NIL) then
       begin
          printk('VFS (namei): not enough memory to look for %c%s\n', [path[0], path]);
	  result := -ENOMEM;
	  exit;
       end;

   if (nb_dir = 0) then
       basename := filename
   else
       for i := 1 to nb_dir do
       begin
	   j := 0;
	   str_len := 0;
	   while (filename[index] <> '/') do
	   begin
	      basename[j] := filename[index];
	      str_len += 1;
	      index   += 1;
	      j       += 1;
	   end;
	   basename[j] := #0;   { A string MUST end with this character }

	   if not lookup(base, @basename, str_len, inode) then
	   begin
	      { One of the directory in the path has not been found !!! }
	      kfree_s(inode, sizeof(inode_t));
	      printk('VFS (namei): cannot find directory %c%s (in %c%s)\n', [basename[0], basename, path[0], path]);
	      result := -ENOENT;
	      exit;
	   end;

	   { Check if 'inode' is really a directory }
	   if not IS_DIR(inode) then
	      begin
		 kfree_s(inode, sizeof(inode_t));
		 printk('VFS(namei): %c%s is not a directory\n', [basename[0], basename]);
		 result := -ENOTDIR;
		 exit;
	      end;

           base  := inode;   { Next directory }
	   index += 1;
       end;

   { Look for the file }
   j       := 0;
   str_len := 0;
   while (filename[index] <> #0) do
      begin
	 basename[j] := filename[index];
	 str_len     += 1;
	 index       += 1;
	 j           += 1;
      end;
   basename[j] := #0;

   if not lookup(base, @basename, str_len, inode) then
      begin
         { File has not been found !!! }
	 kfree_s(inode, sizeof(inode_t));
	 {$IFDEF DEBUG}
	    printk('VFS (namei): cannot find file %c%s (in %c%s)\n', [basename[0], basename, path[0], path]);
	 {$ENDIF}
	 result := -ENOENT;
	 exit;
      end
   else
      begin
         if IS_DIR(inode) then
	    begin
	       kfree_s(inode, sizeof(inode_t));
	       printk('VFS (namei): %c%s is a directory\n', [path[0], path]);
	       result := -EISDIR;
	       exit;
	    end
	 else
	    result := inode;
      end;

end;



{******************************************************************************
 * sys_open
 *
 * Input : pointer to pathname, flags, mode (if file has to be created).
 *
 * Output : file descriptor or -1
 *****************************************************************************}
function sys_open (path : pchar ; flags, mode : dword) : dword; cdecl; [public, alias : 'SYS_OPEN'];

var
   fd      : dword;
   fichier : P_file_t;
   inode   : P_inode_t;

begin

   {$IFDEF DEBUG}
      printk('Welcome in sys_open (%c%s)\n', [path[0], path]);
   {$ENDIF}

   asm
      sti   { Interrupts on }
   end;

   { Look for a free file descriptor }
   fd := 0;
   while (current^.file_desc[fd] <> NIL) and (fd < OPEN_MAX) do
          fd += 1;

   if (current^.file_desc[fd] = NIL) then
   { There is at least one free file descriptor }
   begin

      fichier := kmalloc(sizeof(file_t));
      if (fichier = NIL) then
          begin
	     printk('VFS (open): not enough memory to open %c%s\n', [path[0], path]);
	     result := -ENOMEM;
	     exit;
	  end;

      inode := namei(path);

      if (longint(inode) < 0) then
      {* namei() returned an error code, not a valid pointer.
       * It means that the file hasn't been found and that wa have to
       * create it (not implemented) *}
      begin
         printk('VFS (open): no inode returned by namei()\n', []);
	 kfree_s(fichier, sizeof(file_t));
	 result := longint(inode);
	 exit;
      end;

      {$IFDEF DEBUG}
         printk('open(): %c%s has inode number %d\n', [path[0], path, inode^.ino]);
      {$ENDIF}

      if not (access_rights_ok(flags, inode)) then
         begin
	    printk('VFS (open): permission denied\n', []);
	    kfree_s(fichier, sizeof(file_t));
	    kfree_s(inode, sizeof(inode_t));
	    result := -EACCES;
	    exit;
	 end;

      { Access rights are ok, we fill 'fichier' }
      fichier^.inode := inode;
      fichier^.pos   := 0;
      fichier^.uid   := current^.uid;
      fichier^.gid   := current^.gid;
      fichier^.mode  := flags;
      fichier^.op    := inode^.op^.default_file_ops;
      
      { Can we call file-specific open() function ? }
      if ((fichier^.op <> NIL) and (fichier^.op^.open <> NIL)) then
           fichier^.op^.open(inode, fichier);

      current^.file_desc[fd] := fichier;
      result := fd;  { OK, stop here (that was not funny) }
      {$IFDEF DEBUG}
         printk('VFS (open): fd %d is opened (%c%s)\n', [fd, path[0], path]);
      {$ENDIF}
   end
   else
   { No more free file descriptors }
   begin
      printk('VFS: cannot open %c%s (no file descriptor)\n', [path[0], path]);
      result := -EMFILE;
   end;

end;



{******************************************************************************
 * dup
 *
 * Duplicates an open file descriptor
 *****************************************************************************}
function sys_dup (fildes : dword) : dword; cdecl; [public, alias : 'SYS_DUP'];

var
   fd : dword;

begin

   { Look for a free file descriptor }
   fd := 0;
   while (current^.file_desc[fd] <> NIL) and (fd < OPEN_MAX) do
          fd += 1;

   if (current^.file_desc[fd] = NIL) then
       { There is at least one free file descriptor }
       begin
          {$IFDEF DEBUG}
	     printk('dup: %d->%d\n', [fildes, fd]);
	  {$ENDIF}
          current^.file_desc[fd] := current^.file_desc[fildes];
	  result := fd;
       end
   else
       begin
          printk('dup: file descrptor is too big (%d)\n', [fildes]);
	  result := -1;
       end;

end;



begin
end.
