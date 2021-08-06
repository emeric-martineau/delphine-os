{******************************************************************************
 *  buffer.pp
 * 
 *  VFS buffers management
 *
 *  CopyLeft 2002 GaLi
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
{$I fs.inc}
{$I process.inc}

{DEFINE DEBUG}
{DEFINE DEBUG_BREAD}
{DEFINE DEBUG_WAIT_ON_BUFFER}


procedure interruptible_sleep_on (p : PP_wait_queue); external;
procedure kfree_s (adr : pointer ; size : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure ll_rw_block (rw : dword ; bh : P_buffer_head); external;
procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;


function  bread (major, minor : byte ; block, size : dword) : P_buffer_head;
function  buffer_dirty (bh : P_buffer_head) : boolean;
function  buffer_lock (bh : P_buffer_head) : boolean;
function  buffer_req (bh : P_buffer_head) : boolean;
function  buffer_uptodate (bh : P_buffer_head) : boolean;
function  find_buffer (major, minor : byte ; block, size : dword) : P_buffer_head;
function  getblk (major, minor : byte ; block, size : dword) : P_buffer_head;
procedure insert_buffer_head (bh : P_buffer_head);
procedure wait_on_buffer (bh : P_buffer_head);


var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';

   buffer_head_list : array [1..1024] of P_buffer_head;
   nr_buffer_head   : dword;



IMPLEMENTATION



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
   if ((bh^.state and BH_Uptodate) = BH_Uptodate) then
      result := true
   else
      result := false;
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
   if ((bh^.state and BH_Dirty) = BH_Dirty) then
      result := true
   else
      result := false;
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
   if ((bh^.state and BH_Lock) = BH_Lock) then
      result := true
   else
      result := false;
end;



{******************************************************************************
 * buffer_req
 *
 * Input  : pointer to buffer_head
 *
 * Output : TRUE if the buffer has bee requested else, FALSE
 *
 * NOTE: This function is not used for the moment
 *
 *****************************************************************************}
function buffer_req (bh : P_buffer_head) : boolean; [public, alias : 'BUFFER_REQ'];
begin
   if ((bh^.state and BH_Req) = BH_Req) then
      result := true
   else
      result := false;
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
 * FIXME: For the moment, we can only insert 1024 buffers. It could be great if
 *        we used a hash table.
 *****************************************************************************}
procedure insert_buffer_head (bh : P_buffer_head);

var
   i : dword;

begin

   i := 1;

   if (nr_buffer_head = 1024) then
   begin
      printk('VFS: buffer_head_list is full !!!', []);
      panic('');
   end;

   while ((buffer_head_list[i] <> NIL) and (i <= 1024)) do
           i := i + 1;

   {$IFDEF DEBUG}
      printk('insert_buffer_head at position %d\n', [i]);
   {$ENDIF}
   buffer_head_list[i] := bh;
   nr_buffer_head += 1;

end;



{******************************************************************************
 * find_buffer
 *
 * Input  : major -> device major number
 *          minor -> device minor number
 *          block -> block number
 *          size  -> block size (in bytes)
 *
 * Ouput : NIL if the buffer isn't in buffer_head_list or, if it has been
 *         found, his address.
 *
 * Cette fonction parcours la liste buffer_head_list afin de trouver un tampon
 * correspondant à celui demandé.
 *
 * FIXME: HASH TABLE ?????????????????????????????????
 *****************************************************************************}
function find_buffer (major, minor : byte ; block, size : dword) : P_buffer_head;

var
   i, i_max : dword;
   tmp : P_buffer_head;

begin

   result := NIL;
   i_max  := nr_buffer_head;

   for i := 1 to 1024 do
   begin
      tmp := buffer_head_list[i];
      if (tmp <> NIL) then
      begin
         if (tmp^.major = major) and (tmp^.minor = minor) and 
            (tmp^.blocknr = block) and (tmp^.size = size) then
	 begin
	    result := tmp;
	    {$IFDEF DEBUG}
	       printk('find_buffer: buffer found at position %d\n', [i]);
	    {$ENDIF}
	    exit;
         end
	 else
	 begin
	    i_max -= 1;
	    if (longint(i_max) <= 0) then break;
	 end;
      end;
   end;
end;



{******************************************************************************
 * getblk
 *
 * Recherche un bloc dans le cache. Si le bloc n'est pas contenu dans le cache,
 * cette fonction alloue un nouveau tampon.
 *****************************************************************************}
function getblk (major, minor : byte ; block, size : dword) : P_buffer_head;

var
   tmp : P_buffer_head;

begin

   tmp := find_buffer(major, minor, block, size);

   if (tmp <> NIL) then
   begin
      {$IFDEF DEBUG}
         printk('getblk: Buffer found in cache (%h)\n', [tmp]);
      {$ENDIF}
      result := tmp;
      exit;
   end
   else
   begin
      {$IFDEF DEBUG}
         printk('getblk: buffer not found in cache\n', []);
      {$ENDIF}
      tmp := kmalloc(sizeof(buffer_head));
      tmp^.blocknr := block;
      tmp^.size    := size;
      tmp^.major   := major;
      tmp^.minor   := minor;
      tmp^.state   := 0;
      tmp^.rsector := 0;
      tmp^.data    := kmalloc(size);
      if ((tmp = NIL) or (tmp^.data = NIL)) then
      begin
         printk('getblk (%d): not enough memory for buffer !!!\n', [current^.pid]);
         result := NIL;
         exit;
      end;
      tmp^.wait := NIL;
      insert_buffer_head(tmp);
      result := tmp;
   end;
end;



{******************************************************************************
 * wait_on_buffer
 *
 *****************************************************************************}
procedure wait_on_buffer (bh : P_buffer_head);
begin

   asm
      cli
   end;

   {$IFDEF DEBUG_WAIT_ON_BUFFER}
      printk('wait_on_buffer (%d): buffer state=%d (BH_Lock=%d)\n', [current^.pid, bh^.state, BH_Lock]);
   {$ENDIF}

   while (bh^.state and BH_Lock) = BH_Lock do
   begin
      interruptible_sleep_on(@bh^.wait);
      {$IFDEF DEBUG_WAIT_ON_BUFFER}
         printk('wait_on_buffer (%d): buffer still locked\n', [current^.pid]);
      {$ENDIF}
   end;

   asm
      sti
   end;

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

   asm
      sti
   end;

   {$IFDEF DEBUG_BREAD}
      printk('bread (%d): dev %d:%d block %d size %d\n', [current^.pid, major, minor, block, size]);
   {$ENDIF}

   bh := getblk(major, minor, block, size);

   if (bh = NIL) then
   begin
      printk('bread (%d): getblk returned NIL\n', [current^.pid]);
      result := NIL;
      exit;
   end;

   if buffer_uptodate(bh) then
   begin
      {$IFDEF DEBUG_BREAD}
         printk('bread (%d): Buffer is uptodate\n', [current^.pid]);
      {$ENDIF}
      result := bh;
   end
   else
   begin
      {$IFDEF DEBUG_BREAD}
         printk('bread (%d): going to read block (%d) -> %h\n', [current^.pid, bh^.blocknr, bh^.data]);
      {$ENDIF}
      ll_rw_block(READ, bh);
      wait_on_buffer(bh);

      if (buffer_uptodate(bh)) then
          result := bh
      else
          result := NIL;
   end;

   {$IFDEF DEBUG_BREAD}
      printk('bread (%d): exiting\n', [current^.pid]);
   {$ENDIF}

end;



begin
end.
