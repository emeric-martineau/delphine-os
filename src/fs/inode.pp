{******************************************************************************
 * inode.pp
 *
 *****************************************************************************}


unit _inode;



INTERFACE

{$I fs.inc}
{$I process.inc}
{$I wait.inc}


procedure interruptible_sleep_on (p : PP_wait_queue); external;
procedure interruptible_wake_up (p : PP_wait_queue); external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure printk (format : string ; args : array of const); external;


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';


function  alloc_inode : P_inode_t;
procedure free_inode (inode : P_inode_t);
function  inode_uptodate (inode : P_inode_t) : boolean;
function  IS_BLK (inode : P_inode_t) : boolean;
function  IS_CHR (inode : P_inode_t) : boolean;
function  IS_DIR (inode : P_inode_t) : boolean;
function  IS_FIFO (inode : P_inode_t) : boolean;
function  IS_LNK (inode : P_inode_t) : boolean;
function  IS_REG (inode : P_inode_t) : boolean;
procedure lock_inode (inode : P_inode_t);
procedure read_inode (inode : P_inode_t);
procedure unlock_inode (inode : P_inode_t);


IMPLEMENTATION



{******************************************************************************
 * IS_FIFO
 *
 * Renvoie vrai si l'inode passé en paramètre est l'inode du tube FIFO
 *****************************************************************************}
function IS_FIFO (inode : P_inode_t) : boolean;
begin
   if (inode^.mode and S_IFIFO) = S_IFIFO then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_LNK
 *
 * Renvoie vrai si l'inode passé en paramètre est l'inode d'un lien
 *****************************************************************************}
function IS_LNK (inode : P_inode_t) : boolean; [public, alias : 'IS_LNK'];
begin
   if (inode^.mode and S_IFLNK) = S_IFLNK then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_REG
 *
 * Renvoie vrai si l'inode passé en paramètre est l'inode d'un fichier
 * régulier
 *****************************************************************************}
function IS_REG (inode : P_inode_t) : boolean; [public, alias : 'IS_REG'];
begin
   if (inode^.mode and S_IFREG) = S_IFREG then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_CHR
 *
 * Renvoie vrai si l'inode passé en paramètre est l'inode d'un périphérique
 * en mode caractère.
 *****************************************************************************}
function IS_CHR (inode : P_inode_t) : boolean; [public, alias : 'IS_CHR'];
begin
   if (inode^.mode and S_IFCHR) = S_IFCHR then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_BLK
 *
 * Renvoie vrai si l'inode passé en paramètre est l'inode d'un périphérique
 * en mode bloc.
 *****************************************************************************}
function IS_BLK (inode : P_inode_t) : boolean; [public, alias : 'IS_BLK'];
begin
   if (inode^.mode and S_IFBLK) = S_IFBLK then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_DIR
 *
 * Renvoie vrai si l'inode passé en paramètre est l'inode d'un répertoire
 *****************************************************************************}
function IS_DIR (inode : P_inode_t) : boolean; [public, alias : 'IS_DIR'];
begin
   if (inode^.mode and S_IFDIR) = S_IFDIR then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * lock_inode
 *
 *****************************************************************************}
procedure lock_inode (inode : P_inode_t); [public, alias : 'LOCK_INODE'];
begin

   asm
      cli
   end;

   { On attend que l'inode soit déverrouillé }
   while (inode^.state and I_Lock) = I_Lock do
      interruptible_sleep_on(@inode^.wait);

   inode^.state := inode^.state or I_Lock;

   asm
      sti
   end;

end;



{******************************************************************************
 * unlock_inode
 *
 *****************************************************************************}
procedure unlock_inode (inode : P_inode_t); [public, alias : 'UNLOCK_INODE'];
begin

   asm
      cli
   end;

   if (inode^.state and I_Lock) = 0 then
       printk('unlock_inode (%d): inode not locked\n', [current^.pid])
   else
       begin
          inode^.state := inode^.state and (not I_Lock);
          interruptible_wake_up(@inode^.wait);
       end;

   asm
      sti
   end;

end;



{******************************************************************************
 * inode_uptodate
 *
 *****************************************************************************}
function inode_uptodate (inode : P_inode_t) : boolean; [public, alias : 'INODE_UPTODATE'];
begin
   if (inode^.state and I_Uptodate) = I_Uptodate then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * read_inode
 *
 * Vérifie la validité de l'inode passé en paramètre puis éxécute la
 * procédure read_inode() spécifique au système de fichier concerné.
 *****************************************************************************}
procedure read_inode (inode : P_inode_t); [public, alias : 'READ_INODE'];
begin
   if (inode^.ino = 0) then
       printk('read_inode (%d): ino=0\n', [current^.pid])
   else if ((inode^.sb = NIL) or (inode^.sb^.op = NIL) or (inode^.sb^.op^.read_inode = NIL)) then
       printk('read_inode (%d): operation not defined\n', [current^.pid])
   else
       begin
          lock_inode(inode);
          inode^.sb^.op^.read_inode(inode);
	  unlock_inode(inode);
       end;
end;



{******************************************************************************
 * free_inode
 *
 *****************************************************************************}
procedure free_inode (inode : P_inode_t); [public, alias : 'FREE_INODE'];
begin

   inode^.count -= 1;

   if (inode^.count = 0) then
   begin
      if (inode^.wait <> NIL) then
      begin
         printk('free_inode (%d): inode wait queue is not empty.\n', [current^.pid]);
	 {FIXME: do something clean }
	 while (inode^.wait <> NIL) do
	        interruptible_wake_up(@inode^.wait);
      end;
      { Check if fichier^.inode^.sb <> NIL because for pipes, it is }
      if (inode^.sb <> NIL) then   { NOTE: For pipe inodes, sb=NIL }
          kfree_s(inode^.sb, sizeof(super_block_t));
      kfree_s(inode, sizeof(inode_t));
   end;

end;



{******************************************************************************
 * alloc_inode
 *
 *****************************************************************************}
function alloc_inode : P_inode_t; [public, alias : 'ALLOC_INODE'];

var
   new_inode : P_inode_t;

begin

   result := NIL;

   new_inode := kmalloc(sizeof(inode_t));
   if (new_inode = NIL) then exit;

   memset(new_inode, 0, sizeof(inode_t));
   new_inode^.count := 1;
   result := new_inode;

end;



begin
end.
