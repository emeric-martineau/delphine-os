{******************************************************************************
 * inode.pp
 *
 *****************************************************************************}


unit _inode;



INTERFACE

{$I fs.inc}
{$I wait.inc}


procedure printk (format : string ; args : array of const); external;
procedure sleep_on (p : PP_wait_queue); external;
procedure wake_up (p : PP_wait_queue); external;


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
 * Renvoie vrai si l'inode pass� en param�tre est l'inode du tube FIFO
 *****************************************************************************}
function IS_FIFO (inode : P_inode_t) : boolean;
begin
   if (inode^.mode and $1000) = $1000 then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_LNK
 *
 * Renvoie vrai si l'inode pass� en param�tre est l'inode d'un lien
 *****************************************************************************}
function IS_LNK (inode : P_inode_t) : boolean; [public, alias : 'IS_LNK'];
begin
   if (inode^.mode and $C000) = $C000 then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_REG
 *
 * Renvoie vrai si l'inode pass� en param�tre est l'inode d'un fichier
 * r�gulier
 *****************************************************************************}
function IS_REG (inode : P_inode_t) : boolean; [public, alias : 'IS_REG'];
begin
   if (inode^.mode and $8000) = $8000 then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_CHR
 *
 * Renvoie vrai si l'inode pass� en param�tre est l'inode d'un p�riph�rique
 * en mode caract�re.
 *****************************************************************************}
function IS_CHR (inode : P_inode_t) : boolean; [public, alias : 'IS_CHR'];
begin
   if (inode^.mode and $2000) = $2000 then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_BLK
 *
 * Renvoie vrai si l'inode pass� en param�tre est l'inode d'un p�riph�rique
 * en mode bloc.
 *****************************************************************************}
function IS_BLK (inode : P_inode_t) : boolean; [public, alias : 'IS_BLK'];
begin
   if (inode^.mode and $6000) = $6000 then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * IS_DIR
 *
 * Renvoie vrai si l'inode pass� en param�tre est l'inode d'un r�pertoire
 *****************************************************************************}
function IS_DIR (inode : P_inode_t) : boolean; [public, alias : 'IS_DIR'];
begin
   if (inode^.mode and $4000) = $4000 then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * lock_inode
 *
 *****************************************************************************}
procedure lock_inode (inode : P_inode_t);
begin

   asm
      cli
   end;

   { On attend que l'inode soit d�verrouill� }
   while (inode^.state and I_Lock) = I_Lock do
      sleep_on(@inode^.wait);

   inode^.state := inode^.state or I_Lock;

   asm
      sti
   end;

end;



{******************************************************************************
 * unlock_inode
 *
 *****************************************************************************}
procedure unlock_inode (inode : P_inode_t);
begin

   if (inode^.state and I_Lock) = 0 then
       printk('unlock_inode: inode not locked\n', [])
   else
       begin
          inode^.state := inode^.state and (not I_Lock);
	  wake_up(@inode^.wait);
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
 * V�rifie la validit� de l'inode pass� en param�tre puis �x�cute la
 * proc�dure read_inode() sp�cifique au syst�me de fichier concern�.
 *****************************************************************************}
procedure read_inode(inode : P_inode_t); [public, alias : 'READ_INODE'];
begin
   if (inode = NIL) then
       printk('VFS: read_inode: ino is NIL !!!\n', [])
   else if (inode^.sb^.op^.read_inode = NIL) then
       printk('VFS: read_inode: operation not defined !!!\n', [])
   else
       begin
          lock_inode(inode);
          inode^.sb^.op^.read_inode(inode);
	  unlock_inode(inode);
       end;
end;



begin
end.
