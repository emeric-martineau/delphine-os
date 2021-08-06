{******************************************************************************
 *  ll_rw_block.pp
 *
 *  Gestion des requêtes d'écriture/lecture des périphériques en mode bloc.
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0 - 28/07/2002 - GaLi - initial version
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


unit rw_block;


INTERFACE


{$I blk.inc}
{$I buffer.inc}
{$I fs.inc}
{$I process.inc}


{DEFINE DEBUG}
{DEFINE DEBUG_MAKE_REQUEST}
{DEFINE DEBUG_END_REQUEST}
{DEFINE DEBUG_LOCK_BUFFER}
{DEFINE DEBUG_UNLOCK_BUFFER}


{ Déclaration des procédures externes }
function  buffer_dirty (bh : P_buffer_head) : boolean; external;
function  buffer_uptodate (bh : P_buffer_head) : boolean; external;
procedure interruptible_sleep_on (wait : PP_wait_queue); external;
procedure interruptible_wake_up (p : PP_wait_queue ; schedule : boolean); external;
procedure kfree_s (adr : pointer ; len : dword); external;
function  kmalloc (len : dword) : pointer; external;
procedure lock_buffer (bh : P_buffer_head); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;
procedure schedule; external;
procedure unlock_buffer (bh : P_buffer_head); external;


{ Variables externes }
var
   current : P_task_struct; external name 'U_PROCESS_CURRENT';
   ide_wq  : P_wait_queue; external name 'U_IDE_HD_IDE_WQ';


{ Variables exportées }

   blk_dev : array [0..MAX_NR_BLOCK_DEV] of blk_dev_struct;
   blksize : array [0..MAX_NR_BLOCK_DEV, 0..128] of dword;



procedure end_request (major : byte ; uptodate : boolean);
procedure ll_rw_block (rw : dword; bh : P_buffer_head);
procedure make_request (major : byte ; rw : dword ; bh : P_buffer_head);



IMPLEMENTATION


{$I inline.inc}


{******************************************************************************
 * make_request
 *
 * Ajoute une requête dans le file des requêtes d'un périphérique
 *****************************************************************************}
procedure make_request (major : byte ; rw : dword ; bh : P_buffer_head);

var
   tmp, req : P_request;

begin

   if (rw <> READ) and (rw <> WRITE) then
   begin
      printk('make_request: bad command (%d)\n', [rw]);
      panic('kernel bug ???');
   end;

   if ((rw = READ) and buffer_uptodate(bh))
   or ((rw = WRITE) and not buffer_dirty(bh)) then
   begin
      {IFDEF DEBUG_MAKE_REQUEST}
         if (rw = READ) then
             printk('make_request: does not need to read\n', [])
	 		else
	      	 printk('make_request: does not need to write\n', []);
      {ENDIF}
      unlock_buffer(bh);
      exit;
   end;

   req := kmalloc(sizeof(request));
   if (req = NIL) then
   begin
      printk('make_request: not enough memory to add a request !!!\n', []);
      panic('');
   end;

   { Initialize req }
   memset(req, 0, sizeof(request));
   req^.major  := major;
   req^.minor  := bh^.minor;
   req^.cmd    := rw;
   req^.sector := bh^.rsector;
   req^.nr_sectors := bh^.size div 512;
   req^.buffer := bh^.data;
   req^.bh     := bh;

   {* Add request
    * FIXME: order requests to avoid stupid read/write heads moves *}

	cli();

   {$IFDEF DEBUG_MAKE_REQUEST}
      printk('make_request: adding request %h ', [req]);
   {$ENDIF}

   if (blk_dev[major].current_request) = NIL then
   begin
      {$IFDEF DEBUG_MAKE_REQUEST}
         printk('(0)\n', []);
      {$ENDIF}
      blk_dev[major].current_request := req;
		sti();
      blk_dev[major].request_fn(major);   { Execute the request }
   end
   else
   begin
      {$IFDEF DEBUG_MAKE_REQUEST}
         printk('(1)\n', []);
      {$ENDIF}
      tmp := blk_dev[major].current_request;
      while (tmp^.next <> NIL) do
	     tmp := tmp^.next;
      tmp^.next := req;
		sti();
   end;
end;



{******************************************************************************
 * ll_rw_block
 *
 * Prépare une requête de lecture ou d'écriture pour un périphérique en mode
 * bloc
 *****************************************************************************}
procedure ll_rw_block (rw : dword ; bh : P_buffer_head); [public, alias : 'LL_RW_BLOCK'];

var
   major : byte;

begin

   major := bh^.major;

   if (major > MAX_NR_BLOCK_DEV) or (blk_dev[major].request_fn = NIL) then
   begin
      printk('ll_rw_block: Trying to read invalid block device (%d, %h)\n', [major, blk_dev[major].request_fn]);
      exit;
   end;

   { On finit d'initialiser l'en-tête du tampon avant d'envoyer la requête }

   bh^.rsector := bh^.blocknr * (bh^.size shr 9);

   make_request(major, rw, bh);

end;



{******************************************************************************
 * end_request
 *
 * Termine une requête
 *****************************************************************************}
procedure end_request (major : byte ; uptodate : boolean); [public, alias : 'END_REQUEST'];

var
   cur_req : P_request;

begin

	pushfd();
	cli();

   cur_req := blk_dev[major].current_request;

   {$IFDEF DEBUG_END_REQUEST}
      printk('end_request: req=%h major=%d  %d  sector=%d\n', [cur_req, major, uptodate, cur_req^.sector]);
   {$ENDIF}

   if (uptodate = FALSE) then
   begin

      if (cur_req^.cmd = READ) then
      	 printk('end_request: I/O error. Cannot read sector %d on dev %d:%d\n', [cur_req^.sector, cur_req^.major, cur_req^.minor])
      else
      	 printk('end_request: I/O error. Cannot write sector %d on dev %d:%d\n', [cur_req^.sector, cur_req^.major, cur_req^.minor]);

      cur_req^.bh^.state := cur_req^.bh^.state and (not BH_Uptodate);
   end
   else
      cur_req^.bh^.state := cur_req^.bh^.state or BH_Uptodate and (not BH_dirty);

   {$IFDEF DEBUG_END_REQUEST}
      printk('end_request: next req=%h\n', [cur_req^.next]);
   {$ENDIF}

   blk_dev[major].current_request := cur_req^.next;

	popfd();

   unlock_buffer(cur_req^.bh);
   kfree_s(cur_req, sizeof(request));
   if (blk_dev[major].current_request <> NIL) then
   begin
      {$IFDEF DEBUG_END_REQUEST}
      	 printk('end_request: calling request_fn()\n', []);
      {$ENDIF}
      blk_dev[major].request_fn(major);
   end;

end;



begin
end.
