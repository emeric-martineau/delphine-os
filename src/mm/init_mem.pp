 {*****************************************************************************
 *  init_mem.pp
 * 
 *  DelphineOS memory initialization
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.2a - 23/06/2002 - GaLi - Kernel is now protected.
 *
 *  version 0.2  - 20/06/2002 - GaLi - RAM is managed by mem_map
 *
 *  version 0.1  - ??/??/2001 - GaLi - Initial version
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
 ******************************************************************************}


unit mem_init;


INTERFACE


{DEFINE DEBUG}

{$I mm.inc}

function  get_free_page : pointer; external;
procedure init_gdt; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
function  PageReserved (adr : dword) : boolean; external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure push_page (page_adr : dword); external;
procedure set_bit (i : dword ; ptr_nb : pointer); external;
procedure unset_bit (i : dword ; ptr_nb : pointer); external;



var
   size_dir       : array[1..9] of size_dir_entry; external name 'U_MEM_SIZE_DIR';
   mem_map        : P_page;  external name 'U_MEM_MEM_MAP';
   total_memory   : dword;   external name 'U_MEM_TOTAL_MEMORY'; { RAM size in bytes }
   free_memory    : dword;   external name 'U_MEM_FREE_MEMORY';
   shared_pages   : dword;   external name 'U_MEM_SHARED_PAGES';
   debut_pile     : pointer; external name 'U_MEM_DEBUT_PILE';
   fin_pile       : pointer; external name 'U_MEM_FIN_PILE';
   debut_pile_dma : pointer; external name 'U_MEM_DEBUT_PILE_DMA';
   fin_pile_dma   : pointer; external name 'U_MEM_FIN_PILE_DMA';


procedure init_mm;
procedure init_paging;



IMPLEMENTATION


{$I inline.inc}


var
   txt_section         : dword; { Kernel code size }
   data_section        : dword; { Kernel data size }
   bss_section         : dword; { Kernel data size }
   kernel_size         : dword; { Kernel size in Kb }
   nb_pages            : dword; { Total number of pages }
   i386_endbase        : dword; { Début de la zone réservée au BIOS }
   start_mem           : dword; {* Première adresse libre (après mem_map et
                                 * les piles de pages libres) }



{******************************************************************************
 * init_mm
 *
 * Memory initialization. Only called during DelphineOS initialization.
 *****************************************************************************}
procedure init_mm; [public, alias : 'INIT_MM'];

var
   i, j, size        : dword;
   end_kernel        : dword; { Last address used by the kernel }
   size_mem_map      : dword; { mem_map size in bytes }
   reserved_pages    : dword;
   nb_dma_pages      : dword; { Register the number of pages usable by DMA }
   nb_free           : dword; { Total number of free pages }
   bios_map_entries  : dword;
   bios_map          : P_bios_map_entry;

begin

   free_memory  := 0;
   shared_pages := 0;
   nb_free      := 0;
   nb_dma_pages := 0;

   { Get values set by setup.S }

   asm
      mov   edi, $10000
      mov   eax, dword [edi]
      mov   total_memory, eax
      add   edi, 4
      mov   eax, dword [edi]
      mov   txt_section, eax
      add   edi, 4
      mov   eax, dword [edi]
      mov   data_section, eax
      add   edi, 4
      mov   eax, dword [edi]
      mov   bss_section, eax
      add   edi, 4
      mov   eax, dword [edi]
      mov   kernel_size, eax
      mov   esi, $413   { BIOS data area }
      xor   eax, eax
      mov   ax , word [esi]
      shl   eax, 10
      and   eax, 1111111111111111111000000000000b
      mov   i386_endbase, eax
      mov   eax, dword [$10000 + 20]
      mov   bios_map_entries, eax    
   end;

   if (bios_map_entries <> 0) then
   begin
		print_bochs('\nBIOS map entries:\n', []);
		print_bochs('-----------------\n', []);
      bios_map := $10000 + 24;
      size     := 0;
      for i := 1 to bios_map_entries do
      begin
			print_bochs('%h -> %h (%d)\n', [bios_map^.addr_low, bios_map^.addr_low + bios_map^.length_low, bios_map^.mem_type]);
	 		bios_map += 1;
      end;
   end;

   { Really important variables initialization !!! }
   end_kernel := $12000 + txt_section + data_section + bss_section;
   
   { Align end_kernel on a 4096 bytes boundary (1 page) }
   if ((end_kernel mod 4096) <> 0) then
        end_kernel := (end_kernel and $FFFFF000) + 4096;

   nb_pages     := total_memory div 4;
   mem_map      := $101000;   { mem_map address }
   size_mem_map := nb_pages * sizeof(T_page);

	start_mem 		:= longint(mem_map) + size_mem_map;
	debut_pile  	:= pointer(longint(mem_map) + size_mem_map);
	debut_pile_dma := pointer(longint(mem_map) + size_mem_map);
	fin_pile 		:= pointer(longint(mem_map) + size_mem_map);
	fin_pile_dma 	:= pointer(longint(mem_map) + size_mem_map);

   { Align start_mem on a 4096 bytes boundary (1 page) }
   if ((start_mem mod 4096) <> 0) then
        start_mem := (start_mem and $FFFFF000) + 4096;

{*
 * Standard memory map (if BIOS function E820h is not supported) :
 * ----------------------------
 *
 * Kernel reserved zone (kernel stack, GDT, kernel) :
 *    0x00000000 -> end_kernel - 1
 *
 * Dynamic memory 1 :
 *    end_kernel -> i386_endbase - 1
 *
 * Reserved (ISA cards mapping + BIOS) :
 *    i386_endbase -> 0xFFFFF
 *
 * Fundamental kernel data :
 *    0x100000 -> 0x100FFF
 *
 * Mem_map :
 *    0x101000 -> start_mem - 1
 *
 * Dynamic memory 2 :
 *    start_mem -> total_memory - 1
 *}


   {$IFDEF DEBUG}
      printk('\nMemory map:\n', []);
      printk('end_kernel    : %h\n', [end_kernel]);
      printk('i386_endbase  : %h\n', [i386_endbase]);
      printk('total_memory  : %h\n', [total_memory]);
      printk('start mem_map : %h\n', [mem_map]);
      printk('mem_map has %d entries\n', [nb_pages]);
      printk('mem_map is %d bytes long\n', [size_mem_map]);
      printk('start_mem     : %h\n\n', [start_mem]);
   {$ENDIF}

   {* Set pages descriptors as reserved and usable for DMA *}
   for i := 0 to ((nb_pages) - 1) do
   begin
      mem_map[i].count := 1;
      mem_map[i].flags := $C0000000; { PG_DMA flag set to 1 }
   end;

   {* Set the PG_reserved bit to 0 for pages in the 1st dynamic memory zone *}
   i := end_kernel;
   while (i < i386_endbase) do
   begin
      unset_bit(PG_reserved, @mem_map[i shr 12].flags);
      nb_free      += 1;
      nb_dma_pages += 1;
      i += 4096;
   end;

   {* Set the PG_reserved bit to 0 for pages in the 2nd dynamic memory zone *}
   i := start_mem;
   while (i < total_memory * 1024) do
   begin
      unset_bit(PG_reserved, @mem_map[i shr 12].flags);
      nb_free      += 1;
      nb_dma_pages += 1;
      if (i >= $1000000) then { The page can't be used for DMA ( >16Mb) }
      begin
         mem_map[i shr 12].flags := 0;
	 		nb_dma_pages -= 1;
      end;
      i += 4096;
   end;

   {* We now know how many pages are free. So, we have to mark pages which
    * contain free pages addresses as NOT FREE !!! We also redefine
    * start_mem *}

   j := start_mem;

   start_mem := start_mem + (nb_free * 4);

   { Align start_mem on a 4096 bytes boundary (1 page) }
   if ((start_mem mod 4096) <> 0) then
        start_mem := (start_mem and $FFFFF000) + 4096;

   while (j < start_mem) do
   begin
      set_bit(PG_reserved, @mem_map[j shr 12].flags);
      nb_free      -= 1;
      nb_dma_pages -= 1; {* Because pages used for pages stacks are in the
	                  * DMA zone *}
      j += 4096;
   end;

   {* Now, we make 2 stacks which contain free pages physical addresses.
    * One stack is used for pages usable for DMA (addr < 0x1000000), the other
    * for all the other pages *}

   i := 0;
   reserved_pages := 0;
   asm
      mov    eax, nb_dma_pages
      shl    eax, 2   { EAX = EAX * 4 }
      add    debut_pile, eax
      add    fin_pile, eax
   end;

   while (i < total_memory * 1024) do
   begin
      if (PageReserved(i)) then
          reserved_pages := reserved_pages + 1
      else
          {* NOTE : push_page() updates debut_pile, fin_pile,
	   	  * debut_pile_dma and fin_pile_dma pointers as well as
	   	  * nb_free_pages and free_memory variables (see mm/mem.pp) *}
	   	 push_page(i);

      i += 4096;

   end;

   {$IFDEF DEBUG}
      printk('Nb free pages  : %d\n', [nb_free]);
      printk('Reserved pages : %d\n', [reserved_pages]);
      printk('dma_pages      : %d\n', [nb_dma_pages]);
      printk('start_mem      : %h\n', [start_mem]);
      printk('debut_pile_dma : %h\n', [debut_pile_dma]);
      printk('fin_pile_dma   : %h\n', [fin_pile_dma]);
      printk('debut_pile     : %h\n', [debut_pile]);
      printk('fin_pile       : %h\n\n', [fin_pile]);
   {$ENDIF}

   init_paging();

   { Initialize kernel 'size_dir' }

   size := 16;

   for i := 1 to 9 do
   begin
      size_dir[i].size := size;
      size_dir[i].full_list := NIL;
      size_dir[i].free_list := NIL;
      size_dir[i].full_free_list := NIL;
      size := size * 2;
   end;

   { Print info for user }

   printk('Memory: %dk/%dk available (%dk kernel code, %dk data, %dk reserved)\n', [nb_free * 4, total_memory, txt_section shr 10, (data_section + bss_section) shr 10, reserved_pages * 4]);

   { total_memory has to be the RAM size in bytes }
   total_memory := total_memory * 1024;

end;



{******************************************************************************
 * init_paging
 *
 * Paging initialization. Only called during DelphineOS initialization.
 *****************************************************************************}
procedure init_paging;

var
   i, j  : dword;
   cr3_k : pointer;
   cmpt  : dword;
   tmp   : pointer;
   adr   : dword;

begin

   adr   := 0;
   cr3_k := get_free_page();     { Adresse du répertoire global de pages }
   memset(cr3_k, 0, 4096);

   {* cmpt correspond au nombre d'entrées à remplir dans le répertoire global
    * des pages. 1 entrée de ce répertoire global indexe 1024 pages et permet
    * donc de gérer 4Mo de memoire. Comme ce répertoire a 1024 entrées, on
    * peut adresser 4Go de RAM (vive le 80386 !!!) *}

   cmpt := nb_pages div 1024;
   if (nb_pages mod 1024 <> 0) then cmpt := cmpt + 1;

   for i := 0 to (cmpt - 1) do
   begin
      tmp := get_free_page();
      asm
         mov   edi, cr3_k
	 mov   eax, i
	 shl   eax, 2     { EAX = EAX * 4 }
	 add   edi, eax
	 mov   eax, tmp
	 or    eax, 1     { Droits }
	 mov   [edi], eax

	 mov   edi, tmp
	 mov   eax, adr
	 mov   ecx, 1024
	 @loop:
	    or    eax, 1  { Droits }
	    mov   [edi], eax
	    add   edi, 4
	    add   eax, $1000
	 loop @loop

	 mov   adr, eax

      end;
   end;

   asm
      mov   eax, cr3_k       { Adr physique du répertoire global de pages }
      mov   cr3, eax
      mov   eax, cr0
      or    eax, $80000000
      mov   cr0, eax         { Activate paging !!! }
      jmp   @FLUSH           { 1st flush }
   @FLUSH:
      lea   eax, @FLUSH1
      jmp   eax              { 2nd flush }
   @FLUSH1:
   end;

   flush_tlb();              { 3rd flush (on est jamais trop prudent) }

end;



begin
end.
