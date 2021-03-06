{$IFNDEF __BLK__}
{$DEFINE __BLK__}

{$I buffer.inc}

type

   P_request = ^request;

   request = record
      major      : byte;
      minor      : byte;
      cmd        : byte;   { READ or WRITE }
      errors     : byte;
      sector     : dword;
      nr_sectors : dword;
      buffer     : pointer;
      bh         : ^buffer_head;
      next       : ^request;
   end;

   blk_dev_struct = record
      request_fn : procedure (major : byte);
      current_request : ^request;
   end;



const

   { La proc�dure ll_rw_block prend en param�tre le type d'op�ration que l'on
     veut effectuer. Les 2 valeurs possibles sont les suivantes : }

   READ  = 1;
   
   WRITE = 2;

{$ENDIF}
