{******************************************************************************
 * inode.pp
 *
 *****************************************************************************}


unit _inode;



INTERFACE

{$I fs.inc}
{$I process.inc}
{$I wait.inc}

{DEFINE DEBUG_LOCK_INODE}
{DEFINE DEBUG_UNLOCK_INODE}
{DEFINE DEBUG_WAIT_ON_INODE}
{DEFINE DEBUG_FREE_INODE}


procedure interruptible_sleep_on (p : PP_wait_queue); external;
procedure interruptible_wake_up (p : PP_wait_queue ; schedule : boolean); external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   lookup_cache : array[1..1024] of P_lookup_cache_entry; external name 'U__NAMEI_LOOKUP_CACHE';
   lookup_cache_entries : dword; external name 'U__NAMEI_LOOKUP_CACHE_ENTRIES';


function  alloc_inode : P_inode_t;
procedure free_inode (inode : P_inode_t);
function  inode_dirty (inode : P_inode_t) : boolean;
function  inode_uptodate (inode : P_inode_t) : boolean;
function  IS_BLK (inode : P_inode_t) : boolean;
function  IS_CHR (inode : P_inode_t) : boolean;
function  IS_DIR (inode : P_inode_t) : boolean;
function  IS_FIFO (inode : P_inode_t) : boolean;
function  IS_LNK (inode : P_inode_t) : boolean;
function  IS_REG (inode : P_inode_t) : boolean;
procedure lock_inode (inode : P_inode_t);
procedure mark_inode_clean (inode : P_inode_t);
procedure mark_inode_dirty (inode : P_inode_t);
procedure read_inode (inode : P_inode_t);
procedure unlock_inode (inode : P_inode_t);
procedure wait_on_inode (inode : P_inode_t);
procedure write_inode (inode : P_inode_t);


IMPLEMENTATION


{$I inline.inc}


{******************************************************************************
 * IS_FIFO
 *
 * Renvoie vrai si l'inode passé en paramètre est l'inode du tube FIFO
 *****************************************************************************}
function IS_FIFO (inode : P_inode_t) : boolean;
begin
   if (inode^.mode and IFIFO) = IFIFO then
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
   if (inode^.mode and IFLNK) = IFLNK then
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
   if (inode^.mode and IFREG) = IFREG then
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
   if (inode^.mode and IFCHR) = IFCHR then
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
   if (inode^.mode and IFBLK) = IFBLK then
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
   if (inode^.mode and IFDIR) = IFDIR then
       result := TRUE
   else
       result := FALSE;
end;



{******************************************************************************
 * wait_on_inode
 *
 * Wait for inode to be unlocked
 *****************************************************************************}
procedure wait_on_inode (inode : P_inode_t); [public, alias : 'WAIT_ON_INODE'];
begin

	cli();

   {$IFDEF DEBUG_WAIT_ON_INODE}
      printk('waiting for inode %d\n', [inode^.ino]);
   {$ENDIF}

   while (inode^.state and I_Lock) = I_Lock do
   begin
		sti();
      interruptible_sleep_on(@inode^.wait);
		cli();
   end;

	sti();

end;



{******************************************************************************
 * lock_inode
 *
 *****************************************************************************}
procedure lock_inode (inode : P_inode_t); [public, alias : 'LOCK_INODE'];
begin

	cli();

   {$IFDEF DEBUG_LOCK_INODE}
      printk('locking inode %d -> ', [inode^.ino]);
   {$ENDIF}

   { On attend que l'inode soit déverrouillé }
   while (inode^.state and I_Lock) = I_Lock do
	begin
		interruptible_sleep_on(@inode^.wait);
		cli();
	end;

   inode^.state := inode^.state or I_Lock;

	{$IFDEF DEBUG_LOCK_INODE}
		printk('OK\n', []);
	{$ENDIF}

	sti();

end;



{******************************************************************************
 * unlock_inode
 *
 *****************************************************************************}
procedure unlock_inode (inode : P_inode_t); [public, alias : 'UNLOCK_INODE'];
begin

	cli();

   {$IFDEF DEBUG_UNLOCK_INODE}
      printk('unlocking inode %d -> ', [inode^.ino]);
   {$ENDIF}

   if (inode^.state and I_Lock) = 0 then
       printk('unlock_inode (%d): inode %d not locked\n', [current^.pid, inode^.ino])
   else
	begin
		inode^.state := inode^.state and (not I_Lock);
		while (inode^.wait <> NIL) do
			interruptible_wake_up(@inode^.wait, TRUE);
	end;

	{$IFDEF DEBUG_UNLOCK_INODE}
		printk('OK\n', []);
	{$ENDIF}

	sti();

end;



{******************************************************************************
 * inode_uptodate
 *
 *****************************************************************************}
function inode_uptodate (inode : P_inode_t) : boolean; [public, alias : 'INODE_UPTODATE'];
begin

	cli();

   if (inode^.state and I_Uptodate) = I_Uptodate then
       result := TRUE
   else
       result := FALSE;

	sti();

end;



{******************************************************************************
 * inode_dirty
 *
 *****************************************************************************}
function inode_dirty (inode : P_inode_t) : boolean; [public, alias : 'INODE_DIRTY'];
begin

	cli();

   if (inode^.state and I_Dirty) = I_Dirty then
       result := TRUE
   else
       result := FALSE;

	sti();

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
 * write_inode
 *
 * Vérifie la validité de l'inode passé en paramètre puis éxécute la
 * procédure write_inode() spécifique au système de fichier concerné.
 *****************************************************************************}
procedure write_inode (inode : P_inode_t); [public, alias : 'WRITE_INODE'];
begin
   if (inode^.ino = 0) then
       print_bochs('write_inode (%d): ino=0\n', [current^.pid])
   else if ((inode^.sb = NIL) or (inode^.sb^.op = NIL) or (inode^.sb^.op^.write_inode = NIL)) then
       printk('write_inode (%d): operation not defined\n', [current^.pid])
   else
       begin
          lock_inode(inode);
          inode^.sb^.op^.write_inode(inode);
			 unlock_inode(inode);
       end;
end;



{******************************************************************************
 * free_inode
 *
 *****************************************************************************}
procedure free_inode (inode : P_inode_t); [public, alias : 'FREE_INODE'];

{$IFDEF DEBUG_FREE_INODE}
var
   r_eip : dword;
{$ENDIF}

label free_inode_memory;

begin

   {$IFDEF DEBUG_FREE_INODE}
      asm
      	mov   eax, [ebp + 4]
	 		mov   r_eip, eax
      end;
      print_bochs('free_inode (%d): ino=%d count=%d nlink=%d state=%h2  EIP=%h\n', [current^.pid,
      	    		inode^.ino, inode^.count, inode^.nlink, inode^.state, r_eip]);
   {$ENDIF}

   if (inode = NIL) then   { FIXME: remove this test, it's debugging code }
	begin
		print_bochs('free_inode: called with inode=NIL\n', []);
		exit;
	end;

	wait_on_inode(inode);
	lock_inode(inode);

   inode^.count -= 1;

   if (inode^.count = 0) then
   begin
      if (inode^.state and I_Uptodate) <> I_Uptodate then
      	 goto free_inode_memory;

      if (inode^.nlink = 0) then
      begin
      	if (inode^.sb <> NIL) and
	    		(inode^.sb^.op <> NIL) and
	    		(inode^.sb^.op^.delete_inode <> NIL) then
	 		begin
	    		inode^.sb^.op^.delete_inode(inode);
	    		goto free_inode_memory;
	 		end
			else
	 		begin
	    		print_bochs('\nfree_inode(): nlink=0 but delete_inode() not defined\n', []);
	 		end;
      end;

      if (inode^.state and I_Dirty) = I_Dirty then
      begin
      	if (inode^.sb <> NIL) and
	    		(inode^.sb^.op <> NIL) and
	    		(inode^.sb^.op^.write_inode <> NIL) then
	 		begin
	    		inode^.sb^.op^.write_inode(inode);
	    		goto free_inode_memory;
	 		end
	 		else
	 		begin
	    		print_bochs('\nfree_inode(): inode is dirty but write_inode not defined\n', []);
	 		end;
      end;

   end;   { if (inode^.count = 0) }

	unlock_inode(inode);

   exit;

free_inode_memory:

   if (inode^.wait <> NIL) then
   begin
      print_bochs('free_inode (%d): inode wait queue is not empty.\n', [current^.pid]);
      {FIXME: do something clean }
      while (inode^.wait <> NIL) do
      	    interruptible_wake_up(@inode^.wait, TRUE);
   end;

   { Check if fichier^.inode^.sb <> NIL because for pipes, it is }
   if (inode^.sb <> NIL) then   { NOTE: For pipe inodes, sb=NIL }
       kfree_s(inode^.sb, sizeof(super_block_t));

   kfree_s(inode, sizeof(inode_t));

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



{******************************************************************************
 * mark_inode_dirty
 *
 *****************************************************************************}
procedure mark_inode_dirty (inode : P_inode_t); [public, alias : 'MARK_INODE_DIRTY'];
begin

	cli();

   if (inode <> NIL) then
       inode^.state := inode^.state or I_Dirty;

	sti();

end;



{******************************************************************************
 * mark_inode_clean
 *
 *****************************************************************************}
procedure mark_inode_clean (inode : P_inode_t); [public, alias : 'MARK_INODE_CLEAN'];
begin

	cli();

   if (inode <> NIL) then
       inode^.state := inode^.state and (not I_Dirty);

	sti();

end;



begin
end.
