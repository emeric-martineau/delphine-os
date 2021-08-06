{
  Ce fichier d�fini les structures pour le VFS
  
  Le VFS fonctionne gr�ce � trois objets :

     - super_block_t : permet d'enregistrer le superbloc d'un syst�me de
                       fichier mont�.

     - inode_t : int�gre les informations requises par le syst�me de fichiers
                 pour traiter un fichier.

     - file_t  : d�crit la mani�re dont un processus communique avec un fichier
                 qu'il a ouvert.
}


{$IFNDEF __FS__}
{$DEFINE __FS__}

{$I ext2.inc}

const

   SEEK_SET = 0;   { Set offset to 'offset' }
   SEEK_CUR = 1;   { Add 'offset' to current position }
   SEEK_END = 2;   { Add 'offset' to current file size }

   OPEN_MAX = 32;   { A process can open 32 files }

   MAX_NR_BLOCK_DEV = 10; { Nb maximum de p�riph�riques blocs g�r�s par
                            DelphineOS. Cette constante permet de r�duire
			    consid�rablement la taille des tables utilis�es
			    dans la gestion des p�riph�riques en mode bloc }

   MAX_NR_CHAR_DEV  = 10; { M�me chose pour les p�riph�riques caract�res }

   { L'argument 'flags' utilis� lors de l'appel syst�me open() peut prendre
     UNE SEULE des valeurs suivantes }

   O_RDONLY   = 4;   { Ouverture en lecture }
   O_WRONLY   = 2;   { Ouverture en �criture }
   O_RDWR     = 6;   { Ouverture en lecture/�criture }

   { Inodes flags }
   I_RO       = 4;   { Read }
   I_WO       = 2;   { Write }
   I_XO       = 1;   { Execute }

   I_Lock     = 1;
   I_Uptodate = 2;

type

   P_file_t           = ^file_t;
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
      seek  : function (fichier : P_file_t ; offset, whence : dword) : dword;
   end;


   inode_operations = record
      default_file_ops : P_file_operations;
      lookup : function (dir : P_inode_t ; name : string ; len : dword ; res_inode : P_inode_t) : boolean;
   end;


   super_operations = record
      read_inode : procedure(ino : P_inode_t);
   end;


   device_struct = record
      name : string[20];
      fops : P_file_operations;
   end;


{-----------------------------------------------------------------------------}

   super_block_t = record
      dev_major : byte;
      dev_minor : byte;
      dirty     : byte;
      state     : byte;    { Etat : Lock, Uptodate, ... }
      blocksize : dword;   { Taille d'un bloc logique en octets }
      fs_type   : P_file_system_type;
      op        : P_super_operations;
      { Les donn�es suivantes sont li�es au type de syst�me de fichiers }
      case dword of
         1: (ext2_sb : ext2_sb_info);
   end;

{-----------------------------------------------------------------------------}

   inode_t = record
      ino      : dword;   { Num�ro d'inode }
      dev_maj  : byte;    { P�ripherique majeur sur lequel se trouve l'inode }
      dev_min  : byte;    { P�ripherique mineur sur lequel se trouve l'inode }
      rdev_maj : byte;    { P�riph�rique adress� par l'inode }
      rdev_min : byte;    { P�riph�rique adress� par l'inode }
      count    : byte;    { Compteur d'utilisation }
      state    : byte;    { Etat : Lock, Uptodate, ... }
      atime    : dword;   { Access time }
      ctime    : dword;   { Creation time }
      mtime    : dword;   { Modification time }
      dtime    : dword;   { Deletion time }
      nlink    : word;    { Nombre de liens syst�me }
      mode     : dword;   { Type de fichier et droits d'acc�s }
      uid      : dword;   { Identificateur de propri�taire }
      gid      : dword;   { Identificateur de groupe }
      size     : dword;   { Longueur du fichier en octets }
      blksize  : dword;   { Taille du bloc en octets }
      blocks   : dword;   { Nb de blocs du fichier }
      wait     : P_wait_queue;   { File d'attente }
      sb       : P_super_block_t;
      op       : P_inode_operations;
      { Les donn�es suivantes sont li�es au type de syst�me de fichiers }
      case dword of
         1: (ext2_i : ext2_inode_info);
   end;

{-----------------------------------------------------------------------------}

   file_t = record
      mode   : dword;   { Mode d'acces au processus }
      flags  : dword;   { Drapeaux sp�cifi�s � l'ouverture du fichier }
      pos    : dword;   { Deplacement du fichier courant }
      uid    : dword;   { UID de l'utilisateur }
      gid    : dword;   { GID de l'utilisateur }
      op     : P_file_operations;
      inode  : P_inode_t;
   end;

{$ENDIF}