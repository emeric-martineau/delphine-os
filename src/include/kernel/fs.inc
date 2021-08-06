{
  Ce fichier défini les structures pour le VFS
  
  Le VFS fonctionne grâce à trois objets :

     - super_block_t : permet d'enregistrer le superbloc d'un système de
                       fichier monté.

     - inode_t : intègre les informations requises par le système de fichiers
                 pour traiter un fichier.

     - file_t  : décrit la manière dont un processus communique avec un fichier
                 qu'il a ouvert.
}


{$IFNDEF __FS__}
{$DEFINE __FS__}

{$I ext2.inc}
{$I fcntl.inc}
{$I pipe.inc}

const

	MAX_LOOKUP_ENTRIES = 1024;

   SEEK_SET = 0;   { Set offset to 'offset' }
   SEEK_CUR = 1;   { Add 'offset' to current position }
   SEEK_END = 2;   { Add 'offset' to current file size }

   OPEN_MAX = 32;   { A process can open 32 files }

   MAX_NR_BLOCK_DEV = 10; { Nb maximum de périphériques blocs gérés par
                            DelphineOS. Cette constante permet de réduire
			    considérablement la taille des tables utilisées
			    dans la gestion des périphériques en mode bloc }

   MAX_NR_CHAR_DEV  = 10; { Même chose pour les périphériques caractères }

   {* Values for the second argument to access.
    * These may be OR'd together. *}
   R_OK = 4; { Test for read permission. }
   W_OK = 2; { Test for write permission. }
   X_OK = 1; { Test for execute permission. }
   F_OK = 0; { Test for existence. }


   { Inode flags }
   I_RO       = 0;   { Read }
   I_WO       = 1;   { Write }
   I_XO       = 3;   { Execute }

   { Inode state }
   I_Lock     = 1;
   I_Uptodate = 2;
   I_Dirty    = 4;

   { File types }
	IFMT		= $f000; 	{ Format mask }
   IFSOCK 	= $a000; 	{ Socket }
   IFLNK  	= $c000; 	{ Symbolic link }
   IFREG  	= $8000; 	{ Regular file }
   IFBLK  	= $6000; 	{ Block device }
   IFDIR  	= $4000; 	{ Directory }
   IFCHR  	= $2000; 	{ Character device }
   IFIFO  	= $1000; 	{ FIFO }

	{ Mode flags }
	ISUID 	= $800;		{ SUID }
	ISGID 	= $400;		{ SGID }
	ISVTX 	= $200;		{ Sticky bit }

	IRWXU 	= $1c0;		{ User mask }
	IRUSR 	= $100;		{ Read }
	IWUSR 	= $080;		{ Write }
	IXUSR 	= $040;		{ Execute }

	IRWXG 	= $038;		{ Group mask }
	IRGRP 	= $020;		{ Read }
	IWGRP 	= $010;		{ Write }
	IXGRP 	= $008;		{ Execute }

	IRWXO 	= $007;		{ Other mask }
	IROTH 	= $004;		{ Read }
	IWOTH 	= $002;		{ Write }
	IXOTH 	= $001;		{ Execute }


type

   P_dirent_t         = ^dirent_t;
   P_file_t           = ^file_t;
   PP_inode_t         = ^P_inode_t;
   P_inode_t          = ^inode_t;
   P_file_system_type = ^file_system_type;
   P_file_operations  = ^file_operations;
   P_super_block_t    = ^super_block_t;
   P_super_operations = ^super_operations;
   P_inode_operations = ^inode_operations;


   file_system_type = record
      name       : string[20];
      fs_flag    : dword;
      read_super : function (sb : P_super_block_t) : P_super_block_t;
      next       : ^file_system_type;
   end;


   file_operations = record
      open  : function (inode : P_inode_t ; fichier : P_file_t) : dword;
      read  : function (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
      write : function (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
      close : function (fichier : P_file_t) : dword;
      seek  : function (fichier : P_file_t ; offset, whence : dword) : dword;
      ioctl : function (fichier : P_file_t ; req : dword ; argp : pointer) : dword;
		mmap  : function (fichier : P_file_t ) : dword;
   end;


   inode_operations = record
      default_file_ops : P_file_operations;
      lookup   : function (dir : P_inode_t ; name : pchar ; len : dword ; res_inode : PP_inode_t) : boolean;
      create   : function (dir : P_inode_t ; name : pchar ; mode : dword) : P_inode_t;
      truncate : procedure (inode : P_inode_t);
      unlink   : function (dir : P_inode_t ; name : pchar ; inode : P_inode_t) : dword;
   end;


   super_operations = record
      read_inode   : procedure (ino : P_inode_t);
      write_inode  : procedure (ino : P_inode_t);
      write_super  : procedure (sb : P_super_block_t);
      delete_inode : procedure (ino : P_inode_t);
   end;


   device_struct = record
      name : string[20];
      fops : P_file_operations;
   end;

   dirent_t = record
      d_ino    : dword;   { Inode number }
      d_off    : dword;   { Offset to next dirent (not used by dietlibc ???) }
      d_reclen : word;    { Length if this dirent }
      d_name   : array[0..255] of char;   { Filename (null-terminated) }
   end;


{-----------------------------------------------------------------------------}

   super_block_t = record
      dev_major : byte;
      dev_minor : byte;
      dirty     : byte;
      state     : byte;    { Etat : Lock, Uptodate, ... }
      blksize   : dword;   { Taille d'un bloc logique en octets }
      fs_type   : P_file_system_type;
      op        : P_super_operations;
      { Les données suivantes sont liées au type de système de fichiers }
      case dword of
         1: (ext2_sb : ext2_sb_info);
   end;

{-----------------------------------------------------------------------------}

   inode_t = record
      ino      : dword;   { Numéro d'inode }
      dev_maj  : byte;    { Péripherique majeur sur lequel se trouve l'inode }
      dev_min  : byte;    { Péripherique mineur sur lequel se trouve l'inode }
      rdev_maj : byte;    { Périphérique adressé par l'inode }
      rdev_min : byte;    { Périphérique adressé par l'inode }
      count    : byte;    { Compteur d'utilisation }
      state    : byte;    { Etat : Lock, Uptodate, ... }
      atime    : dword;   { Access time }
      ctime    : dword;   { Creation time }
      mtime    : dword;   { Modification time }
      dtime    : dword;   { Deletion time }
      nlink    : word;    { Nombre de liens système }
      mode     : dword;   { Type de fichier et droits d'accès }
      uid      : dword;   { Identificateur de propriétaire }
      gid      : dword;   { Identificateur de groupe }
      size     : dword;   { Longueur du fichier en octets }
      blksize  : dword;   { Taille d'un bloc en octets }
      blocks   : dword;   { Nb de blocs de 512 octets du fichier }
      wait     : P_wait_queue;   { File d'attente }
      sb       : P_super_block_t;
      op       : P_inode_operations;
      { Les données suivantes sont liées au type de système de fichiers }
      case dword of
         1: (ext2_i : ext2_inode_info);
	 		2: (pipe_i : pipe_inode_info);
   end;

{-----------------------------------------------------------------------------}

   file_t = record
      mode   		 : dword;   { Mode d'acces au processus }
      flags  		 : dword;   { Drapeaux spécifiés à l'ouverture du fichier }
      pos    		 : dword;   { Deplacement du fichier courant }
      uid    		 : dword;   { UID de l'utilisateur }
      gid    		 : dword;   { GID de l'utilisateur }
      count  		 : dword;   { Compteur d'utilisation }
      op     		 : P_file_operations;
      inode  		 : P_inode_t;
   end;

{-----------------------------------------------------------------------------}

{* Following structures are used for lookup() cache *}

   P_lookup_cache_entry = ^lookup_cache_entry;

   lookup_cache_entry = record
      dir   		: P_inode_t;
      name  		: pchar;
      len   		: dword;
      res_inode	: P_inode_t;
   end;

{$ENDIF}
