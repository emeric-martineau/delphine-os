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


{ Déclaration des procédures externes }
procedure schedule; external;
procedure printk (format : string ; args : array of const); external;
procedure sleep_on (wait : PP_wait_queue); external;
procedure wake_up (wait : PP_wait_queue); external;
procedure kfree_s (adr : pointer ; len : dword); external;
procedure panic (reason : string); external;
function  buffer_uptodate (bh : P_buffer_head) : boolean; external;
function  buffer_dirty (bh : P_buffer_head) : boolean; external;
function  kmalloc (len : dword) : pointer; external;


{ Variables externes }
var
   ide_wq : P_wait_queue; external name 'U_IDE_HD_IDE_WQ';


{ Variables exportées }

   blk_dev : array [0..MAX_NR_BLOCK_DEV] of blk_dev_struct;
   blksize : array [0..MAX_NR_BLOCK_DEV, 0..128] of dword;



procedure end_request (major : byte ; uptodate : boolean);
procedure ll_rw_block (rw : dword; bh : P_buffer_head);
procedure lock_buffer (bh : P_buffer_head);
procedure make_request (major : byte ; rw : dword ; bh : P_buffer_head);
procedure unlock_buffer (bh : P_buffer_head);



IMPLEMENTATION



{******************************************************************************
 * lock_buffer
 *
 *****************************************************************************}
procedure lock_buffer (bh : P_buffer_head);
begin

   {$IFDEF DEBUG}
      printk('lock_buffer: Trying to lock buffer\n', []);
   {$ENDIF}


   asm
      pushfd
      cli
   end;

   { Wait for the buffer to be unlocked }
   while (bh^.state and BH_Lock) = BH_Lock do
      sleep_on(@bh^.wait);

   asm
      popfd
   end;

   {$IFDEF DEBUG}
      printk('lock_buffer: lock buffer\n', []);
   {$ENDIF}
   bh^.state := bh^.state or BH_Lock;
end;



{******************************************************************************
 * unlock_buffer
 *
 *****************************************************************************}
procedure unlock_buffer (bh : P_buffer_head);
begin
   if (bh^.state and BH_Lock) = 0 then
      printk('unlock_buffer: buffer not locked !!!\n', [])
   else
      begin
         {$IFDEF DEBUG}
	    printk('unlock_buffer: unlock buffer and wake up processes\n', []);
	 {$ENDIF}
         bh^.state := bh^.state and (not BH_Lock);
	 wake_up(@bh^.wait);
      end;
end;



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

   lock_buffer(bh);

   if ((rw = READ) and buffer_uptodate(bh)) or
      ((rw = WRITE) and not buffer_dirty(bh)) then
      begin
         {$IFDEF DEBUG}
	    printk('make_request: does not need to do anything\n', []);
	 {$ENDIF}
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

   req^.major  := major;
   req^.minor  := bh^.minor;
   req^.cmd    := rw;
   req^.errors := 0;
   req^.sector := bh^.rsector;
   req^.nr_sectors := bh^.size div 512;
   req^.buffer := bh^.data;
   req^.bh     := bh;
   req^.next   := NIL;

   {* Add request
    * FIXME: order requests to avoid stupid read/write heads moves *}

   asm
      pushfd
      cli   { Section critique }
   end;

   {$IFDEF DEBUG}
      printk('make_request: going to add a new request\n', []);
   {$ENDIF}

   if (blk_dev[major].current_request) = NIL then
      begin
         {$IFDEF DEBUG}
	    printk('make_request: no request in queue\n', []);
	 {$ENDIF}
         blk_dev[major].current_request := req;
	 asm
	    popfd   { Fin section critique }
	 end;
	 blk_dev[major].request_fn(major);   { Execute the request }
      end
   else
      begin
         {$IFDEF DEBUG}
	    printk('make_request: at least one request in queue\n', []);
	 {$ENDIF}
         tmp := blk_dev[major].current_request;
	 while (tmp^.next <> NIL) do
	        tmp := tmp^.next;
	 tmp^.next := req;
	 asm
	    popfd   { Fin section critique }
	 end;
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
         printk('ll_rw_block: Trying to read invalid block device\n', []);
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

   asm
      pushfd
      cli   { Section critique }
   end;

   {$IFDEF DEBUG}
      printk('end_request: %d\n', [uptodate]);
   {$ENDIF}

   cur_req := blk_dev[major].current_request;

   unlock_buffer(cur_req^.bh);

   if (uptodate = FALSE) then
      begin
         printk('end_request: I/O error, dev %d:%d, sector %d !!!\n', [cur_req^.major, cur_req^.minor, cur_req^.sector]);
	 cur_req^.bh^.state := cur_req^.bh^.state and (not BH_Uptodate);
	 {$IFDEF DEBUG}
	    printk('end_request: buffer is NOT uptodate\n', []);
	 {$ENDIF}
	 blk_dev[major].current_request := cur_req^.next;
	 asm
	    popfd   { Fin section critique }
	 end;
	 kfree_s(cur_req, sizeof(request));
   {schedule;}
	 if (blk_dev[major].current_request <> NIL) then
	     blk_dev[major].request_fn(major);
      end
   else
      begin
	 cur_req^.bh^.state := cur_req^.bh^.state or BH_Uptodate;
	 {$IFDEF DEBUG}
	    printk('end_request: buffer is now uptodate\n', []);
	 {$ENDIF}
	 cur_req := blk_dev[major].current_request;
	 blk_dev[major].current_request := cur_req^.next;
	 asm
	    popfd   { Fin section critique }
	 end;
	 kfree_s(cur_req, sizeof(request));
   {schedule;}
	 if (blk_dev[major].current_request <> NIL) then
	     blk_dev[major].request_fn(major);
      end;

{   wake_up(@wait_for_request); }   { Réveille les processus qui attendent une
                                      demande de reqête !!! Inutile !!!}

end;



begin
end.
