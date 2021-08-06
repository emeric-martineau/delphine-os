{******************************************************************************
 *  mem.pp
 * 
 *  Contient des fonctions pour la gestion de la RAM
 *
 *  La memoire est allou�e par blocs (objets) de taille fixe. Ces objets
 *  peuvent avoir une taille de : 16, 32, 64, 128, 256, 512, 1024, 2048 ou
 *  4096 octets. Chaque taille d'objet poss�de 3 listes : free_list (liste des
 *  pages contenant que des objets libres), full_list (liste des pages ne
 *  contenant plus d'objets libres) et full_free_list (liste des pages
 *  contenant encore des objets libres)
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.5b - 21/08/2002 - GaLi - Correction d'un bug dans kfree_s() et
 *                                     dans kmalloc().
 *
 *  version 0.5a - 27/05/2002 - GaLi - Ajout de deux variables : total_memory
 *                                     et free_memory. total_memory contient
 *    			               la quantit� de RAM du syst�me en octets.
 *				       free_memory : contient la quantit� de
 *				       RAM disponible en octets � un instant
 *				       donn�. free_memory est modifi� par :
 *				          - kmalloc()
 *					  - kfree_s()
 *					  - get_free_page()
 *					  - push_page()
 *
 *  version 0.5  - ??/??/2001 - GaLi - version initiale
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


unit mem;


INTERFACE


{DEFINE DEBUG}
{DEFINE DEBUG_KREE_S}
{DEFINE KMALLOC_WARNING}
{DEFINE DEBUG_UNLOAD_PAGE_TABLE}
{$DEFINE USE_MEMSET}   { FIXME: one day, we'll have to unset this }

{$I process.inc}
{$I mm.inc}


var
   total_memory   : dword; { nb of bytes }
   free_memory    : dword; { nb of bytes }
   shared_pages   : dword; { nb of pages }
   nb_free_pages  : dword;
   mem_map        : P_page;
   debut_pile     : pointer;
   fin_pile       : pointer;
   debut_pile_dma : pointer;
   fin_pile_dma   : pointer;
   size_dir       : array[1..9] of size_dir_entry;

   current        : P_task_struct; external name 'U_PROCESS_CURRENT';

function  find_page (page : pointer ; list : P_page_desc) : P_page_desc;
procedure free_to_full_free (i : dword ; src : P_page_desc);
procedure full_free_to_full (i : dword ; src : P_page_desc);
procedure full_to_full_free (i : dword ; src : P_page_desc);
procedure full_free_to_free (i : dword ; src : P_page_desc);
function  get_free_dma_page : pointer;
function  get_free_page : pointer;
function  get_page_rights (adr : pointer) : dword;
function  get_phys_addr (adr : pointer) : pointer;
function  init_free_list (i : dword) : dword;
procedure kfree_s (addr : pointer ; size : dword);
function  kmalloc (len : dword) : pointer;
function  MAP_NR(adr : pointer) : dword;
function  memcmp (src, dest : pointer ; size : dword) : boolean;
procedure memcpy (src, dest : pointer ; size : dword);
procedure memset (adr : pointer ; c : byte ; size : dword);
function  null_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function  null_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function  page_align (nb : longint) : dword;
function  page_aligned (nb : longint) : boolean;
function  PageReserved (adr : dword) : boolean;
procedure push_page (page_addr : pointer);
procedure set_page_rights (adr : pointer ; r :dword);
procedure unload_page_table (ts : P_task_struct);


procedure panic (reason : string); external;
procedure printk (format : string ; args : array of const); external;
procedure set_bit (i : dword ; ptr_nb : pointer); external;
procedure unset_bit (i : dword ; ptr_nb : pointer); external;
function  bitscan (nb : dword) : dword; external;



IMPLEMENTATION



{******************************************************************************
 * get_free_mem
 *
 * Retour : qdt de RAM
 *
 * Cette fonction renvoie la quantit� de RAM disponible en octets
 *****************************************************************************}
function get_free_mem : dword; [public, alias : 'GET_FREE_MEM'];

begin
   result := free_memory;
end;



{******************************************************************************
 * get_total_mem
 *
 * Retour : qdt de RAM totale
 *
 * Cette fonction renvoie la quantit� totale de RAM disponible en octets
 *****************************************************************************}
function get_total_mem : dword; [public, alias : 'GET_TOTAL_MEM'];

begin
   result := total_memory;
end;



{******************************************************************************
 * get_free_page
 *
 * Retour : pointeur sur page libre
 *
 * Cette fonction renvoie un pointeur sur une page de 4ko libre. Elle renvoie
 * NIL si il n'y a plus de pages libres. On prend une page utilisable par le
 * DMA si il n'y a plus de pages libres dans l'autre pile.
 *****************************************************************************}
function get_free_page : pointer; [public, alias : 'GET_FREE_PAGE'];

var
   tmp : pointer;

begin
   if (debut_pile = fin_pile) then
      begin
         result := get_free_dma_page;
      end
   else
      begin
         asm
	    pushfd
	    cli   { On coupe les interruptions (section critique) }
            mov   esi, debut_pile
            sub   esi, 4
            mov   eax, [esi]
            mov   tmp, eax
            mov   debut_pile, esi
         end;

         {$IFDEF DEBUG}
            printk('get_free_page: %h\n', [tmp]);
	 {$ENDIF}

	 nb_free_pages -= 1;
	 free_memory   -= 4096;
	 mem_map[longint(tmp) shr 12].count := 1;
	 asm
	    popfd   { Fin section critique }
	 end;

	 {$IFDEF USE_MEMSET}
	 memset(tmp, 0, 4096);   {* FIXME: We don't have to put this if
	                          *        everything was coded the rigth way*}
	 {$ENDIF}

	 result := tmp;

      end;
end;



{******************************************************************************
 * get_free_dma_page
 *
 * Retour : pointeur sur page libre
 *
 * Cette fonction renvoie un pointeur sur une page de 4ko libre et utilisable
 * par le DMA. Elle renvoie NIL si il n'y a plus de pages libres.
 *****************************************************************************}
function get_free_dma_page : pointer; [public, alias : 'GET_FREE_DMA_PAGE'];

var
   tmp : pointer;

begin
   if (debut_pile_dma = fin_pile_dma) then
      begin
         printk('get_free_dma_pages: no more free pages !!!\n', []);
         result := NIL;
      end
   else
      begin
         asm
	    pushfd
	    cli   { On coupe les interruptions (section critique) }
            mov   esi, debut_pile_dma
            sub   esi, 4
            mov   eax, [esi]
            mov   tmp, eax
            mov   debut_pile_dma, esi
         end;

         {$IFDEF DEBUG}
            printk('get_free_dma_page: %h\n', [tmp]);
         {$ENDIF}

	 nb_free_pages -= 1;
	 free_memory   -= 4096;
	 mem_map[longint(tmp) shr 12].count := 1;
	 asm
	    popfd  { On remet les interruptions (fin section critique) }
	 end;
	 result := tmp;

	 {$IFDEF USE_MEMSET}
	 memset(tmp, 0, 4096);   {* FIXME: We don't have to put this if
	                          *       everything else was right coded  :-) *}
	 {$ENDIF}

      end;
end;



{******************************************************************************
 * push_page
 *
 * Entr�e : page � inscrire (adresse physique)
 *
 * Cette proc�dure remet dans la pile des pages libres la page point�e par
 * page_adr
 *****************************************************************************}
procedure push_page (page_addr : pointer); [public, alias : 'PUSH_PAGE'];

var
    index, r_eip : dword;

begin

   index := longint(page_addr) shr 12;

   asm
      pushfd
      cli   { Section critique }
   end;

   if (mem_map[index].count = 0) then
   begin
      asm
         mov   eax, [ebp + 4]
	 mov   r_eip, eax
      end;
      printk('push_page (%d): %h is already free (EIP=%h) !!!\n', [current^.pid, page_addr, r_eip]);
      asm
         popfd
      end;
      panic('');
   end
   else
   begin
      mem_map[index].count -= 1;
      if (mem_map[index].count = 0) then
      { On lib�re vraiment la page car plus aucun processus ne l'utilise }
      begin
         if (page_addr < pointer($1000000)) then   { This a "DMA page" }
         begin
            asm
               mov   edi, debut_pile_dma
               mov   eax, page_addr
               mov   [edi], eax
               add   edi, 4
               mov   debut_pile_dma, edi
            end;
         end
         else
         begin
            asm
               mov   edi, debut_pile
               mov   eax, page_addr
               mov   [edi], eax
               add   edi, 4
               mov   debut_pile, edi
            end;
         end;

	 nb_free_pages += 1;
	 free_memory   += 4096;
	 {$IFDEF DEBUG}
	    printk('push_page: %h\n', [page_addr]);
	 {$ENDIF}

      end
      else
      begin
         shared_pages -= 1;
      end;
   end;

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * kmalloc
 *
 * Entr�e : longueur desir�e (<= 4096)
 * Retour : pointeur sur la zone m�moire
 *
 * Cette fonction renvoie un pointeur vers une zone de m�moire de taille len.
 * ATTENTION : len doit �tre inferieure ou �gale � 4096
 *
 * FIXME: utiliser un s�maphore pour acc�der � 'size_dir' plutot que de couper
 *        les interruptions.
 *****************************************************************************}
function kmalloc (len : dword) : pointer; [public, alias : 'KMALLOC'];

var
   i         : dword;
   res, res2 : dword;
   tmp       : P_page_desc;
   tmp_ptr   : ^dword;

begin

   { On v�rifie si la demande de m�moire n'est pas sup�rieure � 4096 octets }

   if (len > 4096) then
   begin
      printk('kmalloc: Process #%d is trying to allocate %d bytes (>4096) !!!\n', [current^.pid, len]);
      result := NIL;
      exit;
   end;

   {$IFDEF KMALLOC_WARNING}
   if (len = 4096) then
   {* We put a warning here because it's better to call get_free_page() than kmalloc(4096)
    * although it still works *}
      printk('WARNING (%d): kmalloc() called with len=4096\n', [current^.pid]);
   {$ENDIF}

   { On va rechercher quelle entr�e de size_dir utiliser }

   i := 0;

   repeat
      i += 1;
   until (size_dir[i].size >= len);

   { i est donc notre index dans size_dir }

   asm
      pushfd
      cli
   end;

   if (size_dir[i].full_free_list = NIL) then
   begin
      if (size_dir[i].free_list = NIL) then
      begin
         res := init_free_list(i);
	 if (res = 0) then { On n'a pas pu allouer une nouvelle page }
	 begin
	    printk('kmalloc (%d): No more free pages !!!', [current^.pid]);
            result := NIL;
	    exit;
	 end;
      end;

      { On va deplacer un descripteur de la free_list vers la
	full_free_list }
	free_to_full_free(i, size_dir[i].free_list);

   end;

   { Ici, on sait que la full_free_list contient au moins un element }

   tmp := size_dir[i].full_free_list; { tmp = 1er element de full_free }

   if (i > 3) then { La taille demand�e est sup�rieure � 64 octets }
   begin

      { Recherche du premier bloc libre }
      res := bitscan(tmp^.bitmap);

      { On va marquer le bloc comme occup� }
      set_bit(res, @tmp^.bitmap);
	 
      { On regarde si tous les blocs sont maintenant pris. Si oui, on
        d�place le descripteur dans la full_list }
      if (tmp^.bitmap = $FFFFFFFF) then full_free_to_full(i, tmp);

      { On met � jour free_memory }
      free_memory := free_memory - size_dir[i].size;

      { On renvoie au noyau l'adresse du bloc }
      result := tmp^.page + (res * size_dir[i].size);

   end
   else  { La taille demand�e est inf�rieure ou �gale � 64 octets }
   begin

      { Recherche du premier bloc libre }
      res := bitscan(tmp^.bitmap);

      { res correspond a un bitmap secondaire, on va rechercher un bloc
        libre dans le bitmap secondaire }
      tmp_ptr := pointer(tmp^.page + tmp^.adr_bitmap2 + (res * 4));

      { tmp_ptr est un pointer sur le bitmap secondaire }
      res2 := bitscan(tmp_ptr^);

      { On va marquer le bloc comme occup� }
      set_bit(res2, @tmp_ptr^);

      if (tmp_ptr^ = $FFFFFFFF) then
      begin
         set_bit(res, @tmp^.bitmap);
         if (tmp^.bitmap = $FFFFFFFF) then
             full_free_to_full(i, tmp);
      end;

      { On met � jour free_memory }
      free_memory -= size_dir[i].size;

      { On renvoie l'adresse du bloc au noyau }
      result := tmp^.page + (((res * 32) + res2) * size_dir[i].size);

   end;

   asm
      popfd
   end;

end;



{******************************************************************************
 * kfree
 *
 * Entr�e : pointeur sur l'adresse
 *
 * Lib�re la zone m�moire passe en param�tre
 *****************************************************************************}
procedure kfree (addr : pointer); [public, alias : 'KFREE'];
begin
   kfree_s(addr, 0);
end;



{******************************************************************************
 * kfree_s
 *
 * Entr�e : adresse de la m�moire, longueur
 *
 * Cette proc�dure lib�re un bloc de taille size point� par addr. Si size=0, on
 * recherche le bloc dans toutes les entr�es de size_dir. Sinon, on effectue la
 * recherche dans l'entr�e correspondante a size, ce qui est beaucoup plus
 * rapide. => il faut utiliser au maximum la procedure free_s plut�t que free
 *
 * FIXME: utiliser un s�maphore pour acc�der � 'size_dir' plutot que de couper
 *        les interruptions.
 *****************************************************************************}
procedure kfree_s (addr : pointer ; size : dword); [public, alias : 'KFREE_S'];

var
   page          : pointer;
   i             : dword;
   desc          : P_page_desc;
   block, block2 : dword;
   tmp           : ^dword;

begin

   i := 1;

   asm
      mov   eax, addr
      and   eax, $FFFFF000
      mov   page, eax
      pushfd
      cli
   end;

   { page pointe vers la page qui contient le bloc � lib�rer. On va rechercher
     cette page dans size_dir en fonction de size }

   if (size = 0) then

   { On ne connait pas la taille du bloc � lib�rer, on va donc le rechercher
     dans toutes les entr�es de size_dir }

      begin
         {$IFDEF DEBUG_KREE_S}
	    printk('kfree_s: size=0\n', []);
	 {$ENDIF}
         repeat
	    desc := find_page(page, size_dir[i].full_list);
	    i += 1;
	 until ((desc <> NIL) or (i = 10));
	 
	 if (i = 10) then

	 { Le bloc demander n'a pas �t� trouv� dans la full_list, on va
	   rechercher dans la full_free_list }

	    begin
	       i := 1;
	       repeat
	          desc := find_page(page, size_dir[i].full_free_list);
		  i += 1;
	       until ((desc <> NIL) or ( i = 10));

	       if (i = 10) then

	       { Le bloc n'a pas �t� trouv� dans la full_free_list => erreur }

		  begin
		     printk('kfree_s: Bad address passed to kernel (%h) !!!\n', [addr]);
		     asm
		        popfd
		     end;
		     exit;
		  end;
	    end;

         i -= 1;

      end
   else

   { On connait la taille du bloc � lib�rer, on va donc le rechercher
     directement ou il faut }

      begin
         {$IFDEF DEBUG_KREE_S}
	    printk('kfree_s: size=%d\n', [size]);
	 {$ENDIF}
         i := 0;
	 repeat
	    i += 1;
         until (size_dir[i].size >= size);

	 { On va rechercher le bloc dans la full_list }

	 desc := find_page(page, size_dir[i].full_list);

	 if (desc = NIL) then { On a pas trouv� la page }
	    begin
	       desc := find_page(page, size_dir[i].full_free_list);
	       
	       if (desc = NIL) then
	          begin
		     printk('kfree_s: Bad address passed to kernel (%h) !!!\n', [addr]);
		     asm
		        popfd
		     end;
		     exit;
		  end;
	    end;

      end;

   {* desc pointe sur le page_desc correspondant au bloc recherch� et i est
    * l'index dans size_dir *}

   asm
      mov   eax, addr
      and   eax, $00000FFF
      mov   block, eax
   end;

   if ((block mod size_dir[i].size) <> 0) then
      begin
         printk('kfree_s: Bad address passed to kernel (%h) !!!\n', [addr]);
	 asm
	    popfd
	 end;
	 exit;
      end;

   block := block div size_dir[i].size;

   { block correspond au num�ro du bloc � lib�rer dans la page }

   if (i > 3) then { size > 64 }
      begin
         if (desc^.bitmap = $FFFFFFFF) then
	     full_to_full_free(i, desc);
	 unset_bit(block, @desc^.bitmap); { On marque le bloc comme libre }
	 if (desc^.bitmap = bitmap[i]) then
	     begin
	        full_free_to_free(i, desc);
		{printk('kfree_s: may be we could push page %h (i = %d)\n', [desc^.page, i]);}
	     end;
      end
   else { size <= 64 }
      begin
         tmp := pointer(desc^.page + desc^.adr_bitmap2 + ((block div 32) * 4));
	 block2 := block mod 32;
	 if (tmp^ = $FFFFFFFF) then
	    begin
	       if (desc^.bitmap = $FFFFFFFF) then
	  	   full_to_full_free(i, desc);
	       unset_bit(block div 32, @desc^.bitmap);
	    end;
	 unset_bit(block2, @tmp^);   { On marque le bloc comme libre }
	 if (desc^.bitmap = bitmap[i]) then
	     begin
	        {printk('kfree_s: may be we could push page %h (i = %d)\n', [desc^.page, i]);}
	     end;
      end;

   { On met � jour free_memory }
   free_memory += size_dir[i].size;

   asm
      popfd
   end;

end;



{******************************************************************************
 * find_page
 *
 * Entr�e : la page, la liste
 *
 * Cette fonction recherche page dans list. Elle renvoie NIL si elle n'a pas
 * trouv� et un pointeur vers le descripeur dans le cas contraire
 *****************************************************************************}
function find_page (page : pointer ; list : P_page_desc) : P_page_desc;

begin

   { On v�rifie d'abord si list n'est pas vide }

   if (list = NIL) then
      begin
         result := NIL;
	 exit;
      end;

   asm
      pushfd
      cli    { Section critique }
   end;

   while ((list^.page <> page) and (list^.next <> NIL)) do
      begin
         list := list^.next;
      end;

   asm
      popfd   { Fin section critique }
   end;

   if ((list^.next = NIL) and (list^.page <> page)) then
   { On n'a pas trouv� la page }
        result := NIL
   else
   { On n'a trouv� la page }
        result := list;

end;



{******************************************************************************
 * full_free_to_free
 *
 * Entr�e : ?, ?
 *
 * D�place src de la full_free_list vers la free_list. Cette fonction doit
 * �tre appel�e si full_free_list contient au moins un �l�ment.
 *****************************************************************************}
procedure full_free_to_free (i : dword ; src : P_page_desc);

var
   tmp : P_page_desc;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   if (src = size_dir[i].full_free_list) then
   { Si src est le premier �l�ment de la full_free_list, on met l'�l�ment 
     suivant en premier }

      begin
         size_dir[i].full_free_list := src^.next;
      end
   else
      begin
      { Recherche du pr�c�dent }
         tmp := size_dir[i].full_free_list;
         while (tmp^.next <> src) do
	    begin
	       tmp := tmp^.next;
	    end;

	 tmp^.next := src^.next;
      end;

   { Ici, src ne fait plus partie de la full_free_list. On va maintenant mettre 
     src dans la free_list }

   tmp := size_dir[i].free_list;
   size_dir[i].free_list := src;
   src^.next := tmp;

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * full_to_full_free
 *
 * Entree : ?, ?
 *
 * D�place src de la full_list vers la full_free_list. Cette fonction doit
 * �tre appel�e si full_list contient au moins un �l�ment.
 *****************************************************************************}
procedure full_to_full_free (i : dword ; src : P_page_desc);

var
   tmp : P_page_desc;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   if (src = size_dir[i].full_list) then
   { Si src est le premier �l�ment de la full_list, on met l'�l�ment 
     suivant en premier }

      begin
         size_dir[i].full_list := src^.next;
      end
   else
      begin
      { Recherche du pr�c�dent }
         tmp := size_dir[i].full_list;
         while (tmp^.next <> src) do
	    begin
	       tmp := tmp^.next;
	    end;

	 tmp^.next := src^.next;
      end;

   { Ici, src ne fait plus partie de la full_list. On va maintenant mettre src 
     dans la full_free_list }

   tmp := size_dir[i].full_free_list;
   size_dir[i].full_free_list := src;
   src^.next := tmp;

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * full_free_to_full
 *
 * Entr�e : ?, ?
 *
 * D�place src de la full_free_list vers la full_list. Cette fonction doit
 * �tre appel�e si full_free_list contient au moins un �l�ment.
 *****************************************************************************}
procedure full_free_to_full (i : dword ; src : P_page_desc);

{* D�place src de la full_free_list vers la full_list. Cette fonction doit
 * �tre appel�e si full_free_list contient au moins un �l�ment. *}

var
   tmp : P_page_desc;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   if (src = size_dir[i].full_free_list) then
   { Si src est le premier �l�ment de la full_free_list, on met l'�l�ment 
     suivant en premier }

      begin
         size_dir[i].full_free_list := src^.next;
      end
   else
      begin
      { Recherche du pr�c�dent }
         tmp := size_dir[i].full_free_list;
         while (tmp^.next <> src) do
	    begin
	       tmp := tmp^.next;
	    end;

	 tmp^.next := src^.next;
      end;

   { Ici, src ne fait plus partie de la full_free_list. On va maintenant mettre 
     src dans la full_list }

   tmp := size_dir[i].full_list;
   size_dir[i].full_list := src;
   src^.next := tmp;

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * free_to_full_free
 *
 * Entr�e : ?, ?
 *
 * D�place src de la free_list vers la full_free_list. Cette fonction doit
 * �tre appel�e si free_list contient au moins un �l�ment. De plus, on doit
 * initialiser le champ page de src si celui-ci est a NIL (puisqu'il est dans
 * la free_list)
 *****************************************************************************}
procedure free_to_full_free (i : dword ; src : P_page_desc);

var
   tmp : P_page_desc;
   res : pointer;
   tmp_ptr : ^dword;
   j : dword;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   if (src = size_dir[i].free_list) then

   { Si src est le premier �l�ment de la free_list, on met l'�l�ment suivant
     en premier }

      begin
         size_dir[i].free_list := src^.next;
      end
   else
      begin

      { Recherche du pr�c�dent }

         tmp := size_dir[i].free_list;
         while (tmp^.next <> src) do
	    begin
	       tmp := tmp^.next;
	    end;

	 tmp^.next := src^.next;
      end;

   { Ici, src ne fait plus partie de la free_list. On va maintenant mettre src
     dans la full_free_list }

   tmp := size_dir[i].full_free_list;
   size_dir[i].full_free_list := src;
   src^.next := tmp;

   asm
      popfd   { Fin section critique }
   end;

   { On va initialiser le champ page de src s'il y a lieu }

   if (src^.page = NIL) then
      begin

         res := get_free_page;

         if (res = NIL) then
            begin
               printk('kmalloc error (free_to_full_free) : no more free pages !!!', []);
               exit;
            end
         else
               src^.page := res;
      end;
end;



{******************************************************************************
 * init_free_list
 *
 * Entr�e : index dans size_dir
 *
 * Cette fonction initialise et met des descripteurs dans la free_list quand
 * celle-ci est vide. Le parametre i permet de savoir quelle free_list remplir.
 * Elle renvoie 1 si tout c'est bien pass�, sinon elle renvoie 0
 *****************************************************************************}
function init_free_list (i : dword) : dword;

var
   nb   : dword;
   desc : P_page_desc;

begin

   desc := get_free_page; {* On r�cup�re une page libre pour stocker des
                           * page_desc (256) *}
   
   if (desc = NIL) then
      begin
         printk('kmalloc: No more free pages to init a free list\n', []);
	 result := 0;
	 exit;
      end;


   { On va initialiser les 256 page_desc contenus dans la page que l'on vient
     de demander }

   for nb := 1 to 255 do
      begin
         desc^.page        := NIL;
	 desc^.next        := desc + 1;
	 desc^.bitmap      := bitmap[i];
	 desc^.adr_bitmap2 := bitmap2[i];
	 desc += 1;
      end;

   { Remplissage du 256 �me descripteur (le champ next est NIL) }

   desc^.page        := NIL;
   desc^.next        := NIL;
   desc^.bitmap      := bitmap[i];
   desc^.adr_bitmap2 := bitmap2[i];

   { Il faut maintenant ins�rer ces descripteurs dans la free list }

   desc -= 255; { Pointe vers le premier descripteur }

   asm
      pushfd
      cli   { Section critique }
   end;

   size_dir[i].free_list := desc;

   asm
      popfd   { Fin section critique }
   end;

   result := 1; { Tout c'est bien pass� (ouf !!!) }

end;



{******************************************************************************
 * memcmp
 *
 * Entr�e : souce, destination, taille
 *
 * Compare size octets entre src et dest
 *****************************************************************************}
function memcmp (src, dest : pointer ; size : dword) : boolean; [public, alias : 'MEMCMP'];

var
   i : dword;

begin

   result := TRUE;

   for i := 1 to size do
   begin
      if (byte(src^) <> byte(dest^)) then
      begin
         result := FALSE;
         break;
      end;
      src  += 1;
      dest += 1;
   end;

end;



{******************************************************************************
 * memcpy
 *
 * Entr�e : souce, destination, taille
 *
 * Copie size octets de src vers dest
 *****************************************************************************}
procedure memcpy (src, dest : pointer ; size : dword); [public, alias : 'MEMCPY'];

var
   big, small : dword;

begin

   big   := size div 4;
   small := size mod 4;

   asm
      cld
      mov   esi, src
      mov   edi, dest
      mov   ecx, big
      rep   movsd
      
      mov   ecx, small
      rep   movsb
   end;

end;




{******************************************************************************
 * memset
 *
 * Entr�e : adresse, valeur, taille
 *
 * Initialise size octets avec la valeur c a partir de l'adresse adr
 *****************************************************************************}
procedure memset (adr : pointer ; c : byte ; size : dword); [public, alias : 'MEMSET'];

var
   big, small : dword;

begin

   big   := size div 4;
   small := size mod 4;

   asm
      pushfd
      cld
      mov   ecx, big
      mov   al , c
      mov   edi, adr
      rep   stosd

      mov   ecx, small
      rep   stosb
      popfd
   end;

end;



{******************************************************************************
 * get_phys_addr
 *
 * Input : virtual address
 * Ouput : physical address
 *
 * Converts a virtual address into a physical address
 *
 * NOTE : I don't think we have to put interrupts off because each process has
 *        his own CR3 value (hope I'm right)
 *****************************************************************************}
function get_phys_addr (adr : pointer) : pointer; [public, alias : 'GET_PHYS_ADDR'];

var
   glob_index, page_index, ofs : dword;
   res : pointer;

begin

   asm
      mov   eax, adr
      push  eax
      shr   eax, 22    { On r�cup�re les 10 bits de poids fort }
      mov   glob_index, eax
      pop   eax
      push  eax
      shr   eax, 12
      and   eax, 1111111111b
      mov   page_index, eax
      pop   eax
      and   eax, 111111111111b
      mov   ofs, eax

      mov   esi, cr3
      mov   ebx, glob_index
      shl   ebx, 2
      mov   esi, [esi+ebx]
      and   esi, 11111111111111111111000000000000b
      mov   ebx, page_index
      shl   ebx, 2
      mov   eax, [esi+ebx]
      and   eax, 11111111111111111111000000000000b
      add   eax, ofs
      mov   res, eax
   end;

   {$IFDEF DEBUG}
      printk('get_phys_adr: glob_index=%d  page_index=%d  base=%h ofs=%h\n', [glob_index, page_index, longint(res) and $FFFFF000, ofs]);
   {$ENDIF}

   result := res;

end;



{******************************************************************************
 * get_page_rights
 *
 * Input  : physical address
 * Output : page rights
 *
 * NOTE : I don't think we have to put interrupts off because each process has
 *        his own CR3 value (hope I'm right)
 *****************************************************************************}
function get_page_rights (adr : pointer) : dword; [public, alias : 'GET_PAGE_RIGHTS'];

var
   glob_index, page_index, ofs : dword;
   res : dword;

begin
   asm
      mov   eax, adr
      push  eax
      shr   eax, 22   { On r�cup�re les 10 bits de poids fort }
      mov   glob_index, eax
      pop   eax
      shr   eax, 12
      and   eax, 1111111111b
      mov   page_index, eax
      
      mov   esi, cr3
      mov   ebx, glob_index
      shl   ebx, 2
      mov   esi, [esi+ebx]
      and   esi, 11111111111111111111000000000000b
      mov   ebx, page_index
      shl   ebx, 2
      mov   eax, [esi+ebx]
      and   eax, $FFF
      mov   res, eax
   end;

   result := res;

end;



{******************************************************************************
 * set_page_rights
 *
 * Input  : physical address, access rights
 * Output : NONE
 *
 * NOTE : I don't think we have to put interrupts off because each process has
 *        his own CR3 value (hope I'm right)
 *
 *****************************************************************************}
procedure set_page_rights (adr : pointer ; r :dword); assembler; [public, alias : 'SET_PAGE_RIGHTS'];

var
   glob_index, page_index, ofs : dword;

asm
   pushfd
   cli
   mov   eax, adr
   push  eax
   shr   eax, 22   { On r�cup�re les 10 bits de poids fort }
   mov   glob_index, eax
   pop   eax
   shr   eax, 12
   and   eax, 1111111111b
   mov   page_index, eax
      
   mov   esi, cr3
   mov   ebx, glob_index
   shl   ebx, 2   { EAX = EAX * 4 }
   mov   esi, [esi+ebx]
   and   esi, 11111111111111111111000000000000b
   mov   ebx, page_index
   shl   ebx, 2
   mov   eax, r
   and   eax, $FFF   { FIXME: Just to avoid kernel bug (we could remove that later) }
   or   [esi+ebx], eax
   popfd
end;



{******************************************************************************
 * MAP_NR
 *
 * Entr�e : adresse virtuelle ou adresse physique
 * Retour : index dans mem_map qui correspond au descripteur de la page
 *          dans laquelle se trouve l'adresse pass�e en param�tre
 *
 *****************************************************************************}
function MAP_NR(adr : pointer) : dword; [public, alias : 'MAP_NR'];

begin
    result := longint(get_phys_addr(adr)) shr 12;
end;



{******************************************************************************
 * PageReserved
 *
 * Entr�e : adresse physique d'une page
 * Retour : vrai si la page est r�serv�e. Sinon, faux.
 *****************************************************************************}
function PageReserved (adr : dword) : boolean; [public, alias : 'PAGERESERVED'];

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   if (mem_map[adr shr 12].flags and ($80000000 shr PG_reserved) = $80000000 shr PG_reserved) then
       result := true
   else
       result := false;

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * unload_page_table
 *
 *****************************************************************************}
procedure unload_page_table (ts : P_task_struct); [public, alias : 'UNLOAD_PAGE_TABLE'];

var
   i : dword;
   page_table : P_pte_t;

begin

   i := 0;

   while (i <> ts^.size + 1) do
   begin
      if (ts^.page_table[i] <> 0) then
      begin
         {$IFDEF DEBUG_UNLOAD_PAGE_TABLE}
            printk('unload_page_table (%d): freeing entry %d (%h)\n', [ts^.pid, i, longint(ts^.page_table[i]) and $FFFFF000]);
	 {$ENDIF}
         push_page(pointer(longint(ts^.page_table[i]) and $FFFFF000));
      end;
      i += 1;
   end;

   { Free extra stack }
   if (ts^.cr3[1022] <> 0) then
   begin
      {$IFDEF DEBUG_UNLOAD_PAGE_TABLE}
         printk('unload_page_table (%d): freeing extra stack...  ', [ts^.pid]);
      {$ENDIF}
      page_table := pointer(ts^.cr3[1022] and (not $FFF));
      push_page(pointer(page_table[1023] and (not $FFF)));
      push_page(page_table);
      {$IFDEF DEBUG_UNLOAD_PAGE_TABLE}
         printk('OK\n', []);
      {$ENDIF}
      ts^.cr3[1022] := 0;
   end;

   ts^.size -= i - 1;   { NOTE: not necessary but cool for debugging }

   {$IFDEF DEBUG_UNLOAD_PAGE_TABLE}
      printk('unload_page_table (%d): %d pages freed\n', [ts^.pid, i]);
   {$ENDIF}

end;



{******************************************************************************
 * page_align
 *
 *****************************************************************************}
function page_align (nb : longint) : dword; [public, alias : 'PAGE_ALIGN'];
begin

   if (nb mod 4096) = 0 then
       result := nb
   else
       result := (nb + 4096) and $FFFFF000;

end;



{******************************************************************************
 * page_aligned
 *
 *****************************************************************************}
function page_aligned (nb : longint) : boolean; [public, alias : 'PAGE_ALIGNED'];
begin
   if ((nb mod 4096) <> 0) then
       result := FALSE
   else
       result := TRUE;
end;



{******************************************************************************
 * /dev/null 
 *
 *****************************************************************************}



{******************************************************************************
 * null_write 
 *
 *****************************************************************************}
function null_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [ public, alias : 'NULL_WRITE' ];
begin
   result := count;
end;



{******************************************************************************
 * null_read 
 *
 *****************************************************************************}
function null_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [ public, alias : 'NULL_READ' ];
begin
   result := 0;
end;



{******************************************************************************
 * /dev/zero
 *
 *****************************************************************************}



{******************************************************************************
 * zero_write 
 *
 *****************************************************************************}
function zero_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [ public, alias : 'ZERO_WRITE' ];
begin
   result := count;
end;



{******************************************************************************
 * zero_read
 *
 *****************************************************************************}
function zero_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword; [ public, alias : 'ZERO_READ' ];
begin
   { FIXME : check if buf is in user space }
   memset(buf, 0, count);
   result := count;
end;



begin
end.
