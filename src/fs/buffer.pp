{******************************************************************************
 *  buffer.pp
 * 
 *  VFS buffers management
 *
 *  CopyLeft 2003 GaLi
 *
 *  version 0.0 - 27/07/2002 - GaLi
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



unit buffer;


INTERFACE


{$I blk.inc}
{$I buffer.inc}
{$I config.inc}
{$I fs.inc}
{$I lock.inc}
{$I process.inc}
{$I signal.inc}
{$I time.inc}

{DEFINE DEBUG}
{DEFINE DEBUG_BREAD}
{DEFINE DEBUG_WAIT_ON_BUFFER}
{DEFINE DEBUG_FREE_BUFFERS}
{DEFINE DEBUG_UNLOCK_BUFFER}


procedure free_inode (inode : P_inode_t); external;
function  inode_dirty (inode : P_inode_t) : boolean; external;
procedure interruptible_sleep_on (p : PP_wait_queue); external;
procedure interruptible_wake_up (p : PP_wait_queue ; s : boolean); external;
procedure kfree_s (adr : pointer ; size : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure ll_rw_block (rw : dword ; bh : P_buffer_head); external;
procedure lock_inode (inode : P_inode_t); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure read_lock (rw : P_rwlock_t); external;
procedure read_unlock (rw : P_rwlock_t); external;
procedure schedule; external;
procedure send_sig (sig : dword ; p : P_task_struct); external;
procedure sleep_on (p : PP_wait_queue); external;
function  sys_alarm (seconds : dword) : dword; cdecl; external;
function  sys_nanosleep (rqtp, rmtp : P_timespec) : dword; cdecl; external;
procedure unlock_inode (inode : P_inode_t); external;
procedure wake_up (p : PP_wait_queue); external;
procedure write_inode (inode : P_inode_t); external;
procedure write_lock (rw : P_rwlock_t); external;
procedure write_unlock (rw : P_rwlock_t); external;


function  inb (port : word) : byte; external;





function  alloc_buffer_head (major, minor : byte ; block, size : dword) : P_buffer_head;
function  bread (major, minor : byte ; block, size : dword) : P_buffer_head;
procedure brelse (bh : P_buffer_head);
function  buffer_dirty (bh : P_buffer_head) : boolean;
function  buffer_lock (bh : P_buffer_head) : boolean;
function  buffer_uptodate (bh : P_buffer_head) : boolean;
function  find_buffer (major, minor : byte ; block, size : dword ; ind : pointer) : P_buffer_head;
procedure free_buffers;
function  getblk (major, minor : byte ; block, size : dword) : P_buffer_head;
procedure insert_buffer_head (bh : P_buffer_head);
procedure kflushd;
procedure lock_buffer (bh : P_buffer_head);
procedure mark_buffer_clean (bh : P_buffer_head);
procedure mark_buffer_dirty (bh : P_buffer_head);
function  sys_sync : dword; cdecl;
procedure unlock_buffer (bh : P_buffer_head);
procedure wait_on_buffer (bh : P_buffer_head);
procedure wake_up_kflushd;


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   lookup_cache : array[1..LOOKUP_CACHE_MAX_ENTRIES] of P_lookup_cache_entry; external name 'U__NAMEI_LOOKUP_CACHE';
	lookup_cache_lock    : rwlock_t; external name 'U__NAMEI_LOOKUP_CACHE_LOCK';
   lookup_cache_entries : dword; external name 'U__NAMEI_LOOKUP_CACHE_ENTRIES';
   pid_table : P_pid_table_struct; external name 'U_PROCESS_PID_TABLE';


   buffer_head_list      : array [1..BUFFER_HEAD_LIST_MAX_ENTRIES] of P_buffer_head;
   buffer_head_list_lock : rwlock_t;
   nr_buffer_head        : dword;
   nr_buffer_head_dirty  : dword;
   kflushd_wq            : P_wait_queue;



IMPLEMENTATION


{$I inline.inc}



{******************************************************************************
 * lock_buffer
 *
 *****************************************************************************}
procedure lock_buffer (bh : P_buffer_head); [public, alias : 'LOCK_BUFFER'];
begin

	cli();

   {$IFDEF DEBUG_LOCK_BUFFER}
      printk('lock_buffer (%d): Trying to lock buffer %h => %h\n', [current^.pid, bh]);
   {$ENDIF}

   { Wait for the buffer to be unlocked }
   while (bh^.state and BH_Lock) = BH_Lock do
   begin
      interruptible_sleep_on(@bh^.wait);
		cli();
   end;

   {$IFDEF DEBUG_LOCK_BUFFER}
      printk('lock_buffer (%d): buffer %h is locked\n', [current^.pid, bh]);
   {$ENDIF}

   bh^.state := bh^.state or BH_Lock;

	sti();

end;



{******************************************************************************
 * unlock_buffer
 *
 *****************************************************************************}
procedure unlock_buffer (bh : P_buffer_head); [public, alias : 'UNLOCK_BUFFER'];

{$IFDEF DEBUG_UNLOCK_BUFFER}
var
	i : dword;
{$ENDIF}

begin

	cli();

   if (bh^.state and BH_Lock) = 0 then
       print_bochs('unlock_buffer (%d): buffer not locked !!!\n', [current^.pid])
   else
   begin
		{$IFDEF DEBUG_UNLOCK_BUFFER}
			asm
				mov eax, [ebp + 4]
				mov   i, eax
			end;
			print_bochs('unlock_buffer (%d): EIP=%h  unlock buffer %h\n',
							[current^.pid, i, bh]);
		{$ENDIF}
		bh^.state := bh^.state and (not BH_Lock);
		if (bh^.wait <> NIL) then
			 interruptible_wake_up(@bh^.wait, FALSE);
   end;

	sti();

end;



{******************************************************************************
 * buffer_uptodate
 *
 * Input  : pointer to buffer_head
 *
 * Output : TRUE if the buffer's data are uptodate else, FALSE
 *
 *****************************************************************************}
function buffer_uptodate (bh : P_buffer_head) : boolean; [public, alias : 'BUFFER_UPTODATE'];
begin

	cli();

   if ((bh^.state and BH_Uptodate) = BH_Uptodate) then
      result := true
   else
      result := false;

	sti();

end;



{******************************************************************************
 * mark_buffer_dirty
 *
 * Input  : pointer to buffer_head
 *
 *****************************************************************************}
procedure mark_buffer_dirty (bh : P_buffer_head); [public, alias : 'MARK_BUFFER_DIRTY'];

begin

	cli();

   if (bh^.state and BH_Dirty) <> BH_Dirty then
   begin
      bh^.state := bh^.state or BH_Dirty;
      nr_buffer_head_dirty += 1;
   end;

	sti();

end;



{******************************************************************************
 * mark_buffer_clean
 *
 * Input  : pointer to buffer_head
 *
 *****************************************************************************}
procedure mark_buffer_clean (bh : P_buffer_head); [public, alias : 'MARK_BUFFER_CLEAN'];

begin

	cli();

	if (bh^.state and BH_Dirty) = BH_Dirty then
	begin
   	bh^.state := bh^.state and (not BH_Dirty);
   	nr_buffer_head_dirty -= 1;
	end;

	sti();

end;



{******************************************************************************
 * buffer_dirty
 *
 * Input  : pointer to buffer_head
 *
 * Output : TRUE if the buffer has been modified else, FALSE
 *
 *****************************************************************************}
function buffer_dirty (bh : P_buffer_head) : boolean; [public, alias : 'BUFFER_DIRTY'];
begin

	cli();

   if ((bh^.state and BH_Dirty) = BH_Dirty) then
      result := true
   else
      result := false;

	sti();

end;



{******************************************************************************
 * buffer_lock
 *
 * Input  : pointer to buffer_head
 *
 * Output : TRUE if the buffer is locked else, FALSE
 *
 *****************************************************************************}
function buffer_lock (bh : P_buffer_head) : boolean; [public, alias : 'BUFFER_LOCK'];
begin

	cli();

   if ((bh^.state and BH_Lock) = BH_Lock) then
      result := true
   else
      result := false;

	sti();

end;



{******************************************************************************
 * insert_buffer_head
 *
 * Input  : pointer to buffer_head
 *
 * Output : none
 *
 * Insert bh in buffer_head_list
 *
 * FIXME: For the moment, we can only insert BUFFER_HEAD_LIST_MAX_ENTRIES
 * buffers. It could be great if we used a hash table.
 *
 *****************************************************************************}
procedure insert_buffer_head (bh : P_buffer_head); [public, alias : 'INSERT_BUFFER_HEAD'];

var
   i : dword;

begin

   i := 1;

	write_lock(@buffer_head_list_lock);

   if (nr_buffer_head = BUFFER_HEAD_LIST_MAX_ENTRIES) then
   begin
		{$IFDEF DEBUG_KFLUSHD}
      	print_bochs('insert_buffer_head: calling free_buffers()... ', []);
		{$ENDIF}
		write_unlock(@buffer_head_list_lock);
		free_buffers();
		{$IFDEF DEBUG_KFLUSHD}
      	print_bochs('BACK\n', []);
		{$ENDIF}
		write_lock(@buffer_head_list_lock);
   end;

   while ((buffer_head_list[i] <> NIL) and (i <= BUFFER_HEAD_LIST_MAX_ENTRIES)) do
           i += 1;

   {$IFDEF DEBUG}
		print_bochs('insert_buffer_head: %d %h  (pos=%d))\n',
						[bh^.blocknr, bh^.data, i]);
   {$ENDIF}

   buffer_head_list[i] := bh;
   nr_buffer_head += 1;
   write_unlock(@buffer_head_list_lock);

end;



{******************************************************************************
 * find_buffer
 *
 * INPUT  : major -> device major number
 *          minor -> device minor number
 *          block -> block number
 *          size  -> block size (in bytes)
 *          ind   -> pointer to a dword (if buffer is found, initialized to
 *                   buffer_head_list index for found buffer. If the buffer is
 *                   not found, initialized to 0.
 *                   NOTE: you can set ind to NIL if you don't care aboutt the
 *                         index in buffer_head_list.
 *
 * OUTPUT : NIL if the buffer isn't in buffer_head_list or, if it has been
 *          found, his address.
 *
 * This function go through buffer_head_list to find for the asked buffer.
 *
 * FIXME: HASH TABLE ?????????????????????????????????
 *****************************************************************************}
function find_buffer (major, minor : byte ; block, size : dword ; ind : pointer) : P_buffer_head; [public, alias : 'FIND_BUFFER'];

var
   i, i_max : dword;
   tmp : P_buffer_head;

begin

   read_lock(@buffer_head_list_lock);

   result := NIL;
   i_max  := nr_buffer_head;
	if (ind <> NIL) then	dword(ind^) := 0;

   for i := 1 to BUFFER_HEAD_LIST_MAX_ENTRIES do
   begin
      tmp := buffer_head_list[i];
      if (tmp <> NIL) then
      begin
			lock_buffer(tmp);
         if (tmp^.blocknr = block) and (tmp^.size = size) and
				(tmp^.major = major) and (tmp^.minor = minor) then
	 		begin
	    		result := tmp;
	    		{$IFDEF DEBUG}
	       		print_bochs('find_buffer: buffer found at position %d\n', [i]);
	    		{$ENDIF}
				unlock_buffer(tmp);
				read_unlock(@buffer_head_list_lock);
				if (ind <> NIL) then	dword(ind^) := i;
	    		exit;
			end
	 		else
	 		begin
	    		i_max -= 1;
	    		if (longint(i_max) <= 0) then
				begin
					unlock_buffer(tmp);
					break;
				end;
	 		end;
			unlock_buffer(tmp);
      end;
   end;

   read_unlock(@buffer_head_list_lock);

end;



{******************************************************************************
 * getblk
 *
 * Recherche un bloc dans le cache. Si le bloc n'est pas contenu dans le cache,
 * cette fonction alloue un nouveau tampon.
 *****************************************************************************}
function getblk (major, minor : byte ; block, size : dword) : P_buffer_head; [public, alias : 'GETBLK'];

var
   tmp : P_buffer_head;

begin

   tmp := find_buffer(major, minor, block, size, NIL);

   if (tmp <> NIL) then
   begin
      {$IFDEF DEBUG}
         print_bochs('getblk: Buffer found in cache (%h)\n', [tmp]);
      {$ENDIF}
      tmp^.count += 1;
      result := tmp;
   end
   else
   begin
      {$IFDEF DEBUG}
         print_bochs('getblk: buffer not found in cache\n', []);
      {$ENDIF}
      tmp := alloc_buffer_head(major, minor, block, size);
      if (tmp = NIL) then
      begin
			print_bochs('getblk (%d): not enough memory for buffer !!!\n', [current^.pid]);
	 		result := NIL;
	 		exit;
      end;
      result := tmp;
   end;
end;



{******************************************************************************
 * alloc_buffer_head
 *
 *****************************************************************************}
function alloc_buffer_head (major, minor : byte ; block, size : dword) : P_buffer_head; [public, alias : 'ALLOC_BUFFER_HEAD'];

var
   tmp : P_buffer_head;

begin

   result := NIL;

   tmp := kmalloc(sizeof(buffer_head));
   if (tmp = NIL) then exit;

   memset(tmp, 0, sizeof(buffer_head));

   tmp^.data := kmalloc(size);
   if (tmp^.data = NIL) then
   begin
      kfree_s(tmp, sizeof(buffer_head));
      exit;
   end;

   tmp^.blocknr := block;
   tmp^.count   := 1;
   tmp^.size    := size;
   tmp^.major   := major;
   tmp^.minor   := minor;

   insert_buffer_head(tmp);

   result := tmp;

end;



{******************************************************************************
 * wait_on_buffer
 *
 *****************************************************************************}
procedure wait_on_buffer (bh : P_buffer_head); [public, alias : 'WAIT_ON_BUFFER'];
begin

	cli();

   {$IFDEF DEBUG_WAIT_ON_BUFFER}
      print_bochs('wait_on_buffer (%d): buffer state=%d (BH_Lock=%d)\n', [current^.pid, bh^.state, BH_Lock]);
   {$ENDIF}

   while (bh^.state and BH_Lock) = BH_Lock do
   begin
      interruptible_sleep_on(@bh^.wait);
      {$IFDEF DEBUG_WAIT_ON_BUFFER}
         print_bochs('wait_on_buffer (%d): buffer still locked\n', [current^.pid]);
      {$ENDIF}
   end;

	sti();

end;



{******************************************************************************
 * bread
 *
 * Entrée : numéros majeur et mineur du périphérique concerné, numéro du bloc
 *          logique à lire, taille du bloc en octets.
 *
 * Retour : Pointeur vers un en-tête de tampon ou NIL si le bloc n'a pas pu
 *          être lu.
 *
 * Description : Tout d'abord, bread recherche si le bloc à lire n'est pas
 *               déjà dans le cache à l'aide de la fonction getblk(). Dans tous
 *               les cas (que le bloc soit dans le cache ou pas), getblk()
 *               renvoie un pointeur vers un en-tête de tampon (P_buffer_head).
 *               On regarde ensuite si cet en-tête est valide (grâce au flag
 *               BH_Uptodate. Si l'en-ête n'est pas valide, on demande la
 *               lecture effective du bloc à l'aide de la fonction
 *               ll_rw_block(). Cette fonction va enregistrer la requête de
 *               lecture dans la file d'attente du périphérique concerné.
 *               Tant que le bloc n'est pas effectivement lu, l'en-tête de
 *               tampon est bloqué (flag BH_Lock) et le processus qui a appelé
 *               bread() est donc endormi. Une fois le bloc lu, l'en-tête est
 *               débloqué. On vérifie si l'en-tête est valide. S'il ne l'est
 *               pas, c'est que le périphérique n'a pas pu lire le bloc
 *               demandé.
 *
 * REMARQUE : Cette fonction lit UN SEUL bloc logique.
 *****************************************************************************}
function bread (major, minor : byte ; block, size : dword) : P_buffer_head; [public, alias : 'BREAD'];

var
   bh : P_buffer_head;

begin

   {$IFDEF DEBUG_BREAD}
      print_bochs('bread (%d): dev %d:%d block %d size %d\n',
						[current^.pid, major, minor, block, size]);
   {$ENDIF}

	sti();

   bh := getblk(major, minor, block, size);
   if (bh = NIL) then
   begin
      print_bochs('bread (%d): getblk returned NIL\n', [current^.pid]);
      result := NIL;
      exit;
   end;

   lock_buffer(bh);

   if buffer_uptodate(bh) then
   begin
      {$IFDEF DEBUG_BREAD}
         print_bochs('bread (%d): Buffer is uptodate\n', [current^.pid]);
      {$ENDIF}
      unlock_buffer(bh);
      result := bh;
   end
   else
   begin
      {$IFDEF DEBUG_BREAD}
         print_bochs('bread (%d): going to read block (%d) -> %h\n', [current^.pid, bh^.blocknr, bh^.data]);
      {$ENDIF}
      ll_rw_block(READ, bh);
      {$IFDEF DEBUG_BREAD}
         print_bochs('bread (%d): waiting for buffer\n', [current^.pid]);
      {$ENDIF}
      wait_on_buffer(bh);

      if (buffer_uptodate(bh)) then
          result := bh
      else
		begin
			print_bochs('bread: buffer is not uptodate\n', []);
         result := NIL;   { FIXME: we also have to free bh }
		end;
   end;

   {$IFDEF DEBUG_BREAD}
      print_bochs('bread (%d): exiting (result=%h) bh^.wait=%h\n',
						[current^.pid, result, bh^.wait]);
   {$ENDIF}

end;



{******************************************************************************
 * brelse
 *
 * Release a buffer head.
 *****************************************************************************}
procedure brelse (bh : P_buffer_head); [public, alias : 'BRELSE'];
begin
   if (bh <> NIL) then
   begin
      wait_on_buffer(bh);
      if (bh^.count <> 0) then
      	 bh^.count -= 1
      else
      	 printk('brelse: Trying to release a free buffer head\n', []);
   end;
end;




{******************************************************************************
 * sys_sync
 *
 * Write to disk buffer_head_list (dirty blocks) and lookup_cache (dirty
 * inodes)
 *****************************************************************************}
function sys_sync : dword; cdecl; [public, alias : 'SYS_SYNC'];

var
   i, nr     : dword;
	dir_inode : P_inode_t;
	res_inode : P_inode_t;

label again;

begin

	sti();

   again:

   i := 1;

   read_lock(@buffer_head_list_lock);

	{$IFDEF DEBUG_SYS_SYNC}
		print_bochs('sys_sync: syncing buffer_head_list: %d\n', [nr_buffer_head_dirty]);
	{$ENDIF}

	while (nr_buffer_head_dirty <> 0) do
   begin
      if (buffer_head_list[i] <> NIL) then
      begin
			lock_buffer(buffer_head_list[i]);
			if (buffer_dirty(buffer_head_list[i])) then
			begin
				{$IFDEF DEBUG_SYS_SYNC}
					print_bochs('sys_sync: writing block %d (%h) -> ', [buffer_head_list[i]^.blocknr, buffer_head_list[i]]);
	    		{$ENDIF}
	    		ll_rw_block(WRITE, buffer_head_list[i]);
	    		wait_on_buffer(buffer_head_list[i]);
	    		mark_buffer_clean(buffer_head_list[i]);
				{$IFDEF DEBUG_SYS_SYNC}
					print_bochs('done\n', []);
				{$ENDIF}
      	 end
      	 else
      	    unlock_buffer(buffer_head_list[i]);
      end;
      i += 1;
   end;

   read_unlock(@buffer_head_list_lock);

	read_lock(@lookup_cache_lock);
   i  := 1;
   nr := lookup_cache_entries;

	{$IFDEF DEBUG_SYS_SYNC}
		print_bochs('sys_sync: syncing lookup_cache: %d\n', [nr]);
	{$ENDIF}

   while (nr <> 0) do
   begin
      if (lookup_cache[i] <> NIL) then
      begin
			dir_inode := lookup_cache[i]^.dir;
			res_inode := lookup_cache[i]^.res_inode;

			if (inode_dirty(dir_inode)) then
			begin
				{$IFDEF DEBUG_SYS_SYNC}
					print_bochs('sys_sync: writing dir_inode %d\n', [dir_inode^.ino]);
				{$ENDIF}
				write_inode(dir_inode);
			end;

			if (inode_dirty(res_inode)) then
			begin
				{$IFDEF DEBUG_SYS_SYNC}
					print_bochs('sys_sync: writing res_inode %d\n', [res_inode^.ino]);
				{$ENDIF}
				write_inode(res_inode);
			end;
      	nr -= 1;
      end;
      i += 1;
   end;

	read_unlock(@lookup_cache_lock);

   if (nr_buffer_head_dirty <> 0) then goto again;

   {$IFDEF DEBUG_SYS_SYNC}
      print_bochs('sys_sync: END\n', []);
   {$ENDIF}

   result := 0;

end;



{******************************************************************************
 * kflushd
 *
 * NOTE: this procedure is a kernel thread which is launch from
 * sys_mount_root() (fs/super.pp)
 *
 * kflushd() sync buffers and inodes to disk every KFLUSHD_SLEEP_INTERVAL
 * seconds.
 *****************************************************************************}
procedure kflushd; [public, alias : 'KFLUSHD'];

var
   i, nr, max	: dword;
	rqtp			: timespec;
	dir_inode	: P_inode_t;
	res_inode	: P_inode_t;

label sleep;

begin

	{$IFDEF DEBUG_KFLUSHD}
		print_bochs('kflushd: Starting (SLEEP_INTERVAL=%d, BUFFER_SYNC_MAX=%d INODE_SYNC_MAX=%d)\n',
						[KFLUSHD_SLEEP_INTERVAL, KFLUSHD_BUFFER_SYNC_MAX,
						 KFLUSHD_INODE_SYNC_MAX]);
	{$ENDIF}

sleep:
	rqtp.tv_sec  := KFLUSHD_SLEEP_INTERVAL;
	rqtp.tv_nsec := 0;
	sys_nanosleep(@rqtp, NIL);

	read_lock(@buffer_head_list_lock);

	{$IFDEF DEBUG_KFLUSHD}
		print_bochs('kflushd: Syncing buffer_head_list (%d dirty buffers)\n', [nr_buffer_head_dirty]);
	{$ENDIF}


	{********************************}
	{*** Syncing buffer_head_list ***}
	{********************************}

	if (nr_buffer_head_dirty < KFLUSHD_BUFFER_SYNC_MAX) then
		max := nr_buffer_head_dirty
	else
		max := KFLUSHD_BUFFER_SYNC_MAX;

	i := 1;

	while (max <> 0) do
	begin
      if (buffer_head_list[i] <> NIL) then
      begin
			lock_buffer(buffer_head_list[i]);
			if (buffer_dirty(buffer_head_list[i])) then
			begin
				{$IFDEF DEBUG_KFLUSHD}
					print_bochs('kflushd: writing block %d (%h) -> ', [buffer_head_list[i]^.blocknr, buffer_head_list[i]]);
	    		{$ENDIF}
	    		ll_rw_block(WRITE, buffer_head_list[i]);
	    		wait_on_buffer(buffer_head_list[i]);
	    		mark_buffer_clean(buffer_head_list[i]);
				{$IFDEF DEBUG_KFLUSHD}
					print_bochs('done\n', []);
				{$ENDIF}
				max -= 1;
      	 end
      	 else
      	    unlock_buffer(buffer_head_list[i]);
      end;
      i += 1;
	end;

	read_unlock(@buffer_head_list_lock);


	{****************************}
	{*** Syncing lookup_cache ***}
	{****************************}

	{$IFDEF DEBUG_KFLUSHD}
		print_bochs('kflushd: Syncing lookup_cache\n', []);
	{$ENDIF}

	read_lock(@lookup_cache_lock);

   i   := 1;
   nr  := lookup_cache_entries;
	max := KFLUSHD_INODE_SYNC_MAX;

   while ((nr <> 0) and (longint(max) > 0)) do
   begin
      if (lookup_cache[i] <> NIL) then
      begin
			dir_inode := lookup_cache[i]^.dir;
			res_inode := lookup_cache[i]^.res_inode;

			if (inode_dirty(dir_inode)) then
			begin
				{$IFDEF DEBUG_KFLUSHD}
					print_bochs('kflushd: writing dir_inode %d\n', [dir_inode^.ino]);
				{$ENDIF}
				write_inode(dir_inode);
				max -= 1;
			end;

			if (inode_dirty(res_inode)) then
			begin
				{$IFDEF DEBUG_KFLUSHD}
					print_bochs('kflushd: writing res_inode %d\n', [res_inode^.ino]);
				{$ENDIF}
				write_inode(res_inode);
				max -= 1;
			end;
      	nr -= 1;
      end;
      i += 1;
   end;

	read_unlock(@lookup_cache_lock);

	{$IFDEF DEBUG_KFLUSHD}
		print_bochs('kflushd: Going to sleep\n', []);
	{$ENDIF}

	goto sleep;

end;



{******************************************************************************
 * wake_up_kflushd
 *
 ******************************************************************************}
procedure wake_up_kflushd;
begin
   send_sig(SIGCONT, pid_table^.pid_nb[2]);
   interruptible_sleep_on(@kflushd_wq);
end;



{******************************************************************************
 * free_buffers
 *
 ******************************************************************************}
procedure free_buffers; [public, alias : 'FREE_BUFFERS'];

var
	i, nr : dword;
	bh 	: P_buffer_head;

begin

	{$IFDEF DEBUG_FREE_BUFFERS}
		print_bochs('free_buffers: lock ', []);
	{$ENDIF}

	write_lock(@buffer_head_list_lock);

	{$IFDEF DEBUG_FREE_BUFFERS}
		print_bochs('OK\n', []);
	{$ENDIF}

	i := 1;

	{ Nb of buffers we want to free }
	if (nr_buffer_head < FREE_BUFFER_MAX) then
		 nr := nr_buffer_head
	else
		 nr := FREE_BUFFER_MAX;

	while (nr <> 0) do
	begin
		bh := buffer_head_list[i];
		if (bh <> NIL) then
		begin
			lock_buffer(bh);
			if (bh^.count = 0) then
			begin
				if (buffer_dirty(bh)) then
				begin
	    			ll_rw_block(WRITE, bh);
	    			wait_on_buffer(bh);
	    			mark_buffer_clean(bh);
				end;
				kfree_s(bh^.data, bh^.size);
				kfree_s(bh, sizeof(buffer_head));
				buffer_head_list[i] := NIL;
				nr_buffer_head -= 1;
			end
			else
				unlock_buffer(bh);		
			nr -= 1;
		end;
		i += 1;	
	end;

	write_unlock(@buffer_head_list_lock);

end;



{******************************************************************************
 * free_lookup_cache
 *
 ******************************************************************************}
procedure free_lookup_cache; [public, alias : 'FREE_LOOKUP_CACHE'];

var
	i, nr 		: dword;
	res_inode	: P_inode_t;

begin

	write_lock(@lookup_cache_lock);

   i  := 1;

	if (lookup_cache_entries < FREE_LOOKUP_CACHE_MAX) then
   	 nr := lookup_cache_entries
	else
		 nr := FREE_LOOKUP_CACHE_MAX;

   while (nr <> 0) do
   begin
      if (lookup_cache[i] <> NIL) then
      begin
			res_inode := lookup_cache[i]^.res_inode;
      	lock_inode(res_inode);

	 		if (res_inode^.count = 1) then
			{ It means that this inode is only used by the lookup_cache }
	 		begin
				unlock_inode(res_inode);
				free_inode(res_inode);
	    		free_inode(lookup_cache[i]^.dir);
	    		kfree_s(lookup_cache[i]^.name, lookup_cache[i]^.len);
				lookup_cache[i] := NIL;
				lookup_cache_entries -= 1;
	 		end
			else
      		unlock_inode(res_inode);
      	nr -= 1;
      end;
      i += 1;
   end;

	write_unlock(@lookup_cache_lock);

end;



begin
end.
