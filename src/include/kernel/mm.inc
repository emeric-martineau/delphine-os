{$IFNDEF __MM__}
{$DEFINE __MM__}

type

   P_bios_map_entry = ^T_bios_map_entry;

   T_bios_map_entry = record
      addr_low    : dword;
      addr_high   : dword;
      length_low  : dword;
      length_high : dword;
      mem_type    : dword;
   end;

   P_page = ^T_page;

   T_page = record
      count : dword;
      flags : dword;
   end;

   T_page_desc = record
       page        : pointer;      { Page dans laquelle est contenue des 
	                              objets de la meme taille }
       next        : ^T_page_desc; { Pointeur sur le prochain page_desc }
       bitmap      : dword;        { Bitmap primaire de la page }
       adr_bitmap2 : dword;        { Adresse du bitmap secondaire }
   end;

   P_page_desc = ^T_page_desc;

   P_pte_t = ^pte_t;
   pte_t   = dword;

   size_dir_entry = record
       size           : dword;
       free_list      : P_page_desc;
       full_list      : P_page_desc;
       full_free_list : P_page_desc;
   end;



const
    bitmap : array[1..9] of dword = ($FFFFFF, $FFFFFFF, $3FFFFFFF, $0, $FFFF,
                                     $7FFFFF, $FFFFFFF, $3FFFFFFF, $7FFFFFFF);

    bitmap2 : array[1..9] of dword = (4064, 4080, 4088, 0, 0, 0, 0, 0, 0);

{ Définition (index) des bits du champ 'flags' du type 'T_page' }

    PG_reserved = 0;
    PG_DMA      = 1;

{ Page table entries flags }

    USER_PAGE    = 7;   { PRESENT or WRITE_PAGE or USER_MODE }
    KERNEL_PAGE  = 1;

    USER_MODE    = 4;
    WRITE_PAGE   = 2;
    PRESENT_PAGE = 1;

{$ENDIF}
