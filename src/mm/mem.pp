{******************************************************************************
 *  mem.pp
 *
 *  Contient des fonctions pour la gestion de la RAM
 *
 *  La memoire est allouée par blocs (objets) de taille fixe. Ces objets
 *  peuvent avoir une taille de : 16, 32, 64, 128, 256, 512, 1024, 2048 ou
 *  4096 octets. Chaque taille d'objet possède 3 listes : free_list (liste des
 *  pages contenant que des objets libres), full_list (liste des pages ne
 *  contenant plus d'objets libres) et full_free_list (liste des pages
 *  contenant encore des objets libres)
 *
 *  NOTE: This file also contains /dev/null and /dev/zero management
 *
 *  CopyLeft 2003 GaLi
 *
 *  version 0.5b - 21/08/2002 - GaLi - Correction d'un bug dans kfree_s() et
 *									   			dans kmalloc().
 *
 *  version 0.5a - 27/05/2002 - GaLi - Ajout de deux variables : total_memory
 *                               		et free_memory. total_memory contient
 *    			              			   la quantité de RAM du système en octets.
 *				       				   		free_memory : contient la quantité de
 *				       				   		RAM disponible en octets à un instant
 *				      					   	donné. free_memory est modifié par :
 *				          				  			- kmalloc()
 *				          							- kfree_s()
 *					  									- get_free_page()
 *					  									- push_page()
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
{DEFINE DEBUG_GET_PTE}
{DEFINE DEBUG_KREE_S}


{$I config.inc}
{$I mm.inc}
{$I process.inc}


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
function  get_page_rights (addr : dword) : dword;
function  get_phys_addr (addr : dword) : dword;
function  get_pte (addr : dword) : P_pte_t;
function  init_free_list (i : dword) : dword;
procedure kfree_s (addr : pointer ; size : dword);
function  kmalloc (len : dword) : pointer;
function  MAP_NR(addr : dword) : dword;
function  memcmp (src, dest : pointer ; size : dword) : boolean;
procedure memcpy (src, dest : pointer ; size : dword);
procedure memset (adr : pointer ; c : byte ; size : dword);
function  null_write (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function  null_read (fichier : P_file_t ; buf : pointer ; count : dword) : dword;
function  PageReserved (adr : dword) : boolean;
procedure push_page (page_addr : pointer);
procedure set_page_rights (adr : pointer ; r :dword);
procedure set_pte (addr : dword ; pte : pte_t);
procedure unload_process_cr3 (ts : P_task_struct);


procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure set_bit (i : dword ; ptr_nb : pointer); external;
procedure unset_bit (i : dword ; ptr_nb : pointer); external;
function  bitscan (nb : dword) : dword; external;



IMPLEMENTATION


{$I inline.inc}


{******************************************************************************
 * get_free_mem
 *
 * Retour : qdt de RAM
 *
 * Cette fonction renvoie la quantité de RAM disponible en octets
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
 * Cette fonction renvoie la quantité totale de RAM disponible en octets
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
       result := get_free_dma_page()
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
	 		mem_map[longint(tmp) shr 12].flags := 0;

    		popfd();   { Fin section critique }

	 		{$IFDEF USE_MEMSET}
	 			memset(tmp, 0, 4096);   {* FIXME: We don't have to put this if
	                           		 *        everything was coded the rigth way *}
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
	 		mem_map[longint(tmp) shr 12].flags := 0;

    		popfd();  { On remet les interruptions (fin section critique) }

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
 * Entrée : page à inscrire (adresse physique)
 *
 * Cette procédure remet dans la pile des pages libres la page pointée par
 * page_adr
 *****************************************************************************}
procedure push_page (page_addr : pointer); [public, alias : 'PUSH_PAGE'];

var
    index, r_eip : dword;

begin

   index := longint(page_addr) shr 12;

	pushfd();
	cli();

   if (mem_map[index].count = 0) then
   begin
      asm
         mov   eax, [ebp + 4]
	 		mov   r_eip, eax
      end;
      print_bochs('push_page (%d): %h is already free (EIP=%h) !!!\n', [current^.pid, page_addr, r_eip]);
   end
   else
   begin
      mem_map[index].count -= 1;
      if (mem_map[index].count = 0) then
      { On libère vraiment la page car plus aucun processus ne l'utilise }
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

			mem_map[index].flags := 0;
	 		nb_free_pages += 1;
	 		free_memory   += 4096;
	 		{$IFDEF DEBUG}
	    		printk('push_page: %h\n', [page_addr]);
	 		{$ENDIF}

      end
      else   { mem_map[index].count <> 0 }
         shared_pages -= 1;
   end;

	popfd();   { Fin section critique }

end;



{******************************************************************************
 * kmalloc
 *
 * Input  : length wanted (<= 4096)
 * Output : pointer to allocated zone
 *
 * Cette fonction renvoie un pointeur vers une zone de mémoire de taille len.
 * ATTENTION : len doit être inferieure ou égale à 4096
 *
 * FIXME: utiliser un sémaphore pour accéder à 'size_dir' plutot que de couper
 *        les interruptions.
 *****************************************************************************}
function kmalloc (len : dword) : pointer; [public, alias : 'KMALLOC'];

var
   i         : dword;
   res, res2 : dword;
   tmp       : P_page_desc;
   tmp_ptr   : ^dword;

begin

   if (len > 4096) then
   begin
      asm
         mov   eax, [ebp + 4]
	 		mov   res, eax
      end;
      printk('kmalloc: Process #%d is trying to allocate %d bytes (>4096)\n', [current^.pid, len]);
      printk('kmalloc: EIP=%h\n', [res]);
      result := NIL;
      exit;
   end;

   {$IFDEF KMALLOC_WARNING}
   if (len = 4096) then
   {* We put a warning here because it's better to call get_free_page() than
	 * kmalloc(4096) although it still works *}
      print_bochs('WARNING (%d): kmalloc() called with len=4096\n', [current^.pid]);
   {$ENDIF}

   { On va rechercher quelle entrée de size_dir utiliser }

   i := 0;

   repeat
      i += 1;
   until (size_dir[i].size >= len);

   { i est donc notre index dans size_dir }

	pushfd();
	cli();

   if (size_dir[i].full_free_list = NIL) then
   begin
      if (size_dir[i].free_list = NIL) then
      begin
         res := init_free_list(i);
	 		if (res = 0) then { On n'a pas pu allouer une nouvelle page }
	 		begin
	    		printk('kmalloc (%d): init_free_list() failed\n', [current^.pid]);
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

   if (i > 3) then { La taille demandée est supérieure à 64 octets }
   begin

      { Recherche du premier bloc libre }
      res := bitscan(tmp^.bitmap);

      { On va marquer le bloc comme occupé }
      set_bit(res, @tmp^.bitmap);
	 
      { On regarde si tous les blocs sont maintenant pris. Si oui, on
        déplace le descripteur dans la full_list }
      if (tmp^.bitmap = $FFFFFFFF) then full_free_to_full(i, tmp);

      { On met à jour free_memory }
      free_memory -= size_dir[i].size;

      { On renvoie au noyau l'adresse du bloc }
      result := tmp^.page + (res * size_dir[i].size);

   end
   else  { La taille demandée est inférieure ou égale à 64 octets }
   begin

      { Recherche du premier bloc libre }
      res := bitscan(tmp^.bitmap);

      { res correspond a un bitmap secondaire, on va rechercher un bloc
        libre dans le bitmap secondaire }
      tmp_ptr := pointer(tmp^.page + tmp^.adr_bitmap2 + (res * 4));

      { tmp_ptr est un pointer sur le bitmap secondaire }
      res2 := bitscan(tmp_ptr^);

      { On va marquer le bloc comme occupé }
      set_bit(res2, @tmp_ptr^);

      if (tmp_ptr^ = $FFFFFFFF) then
      begin
         set_bit(res, @tmp^.bitmap);
         if (tmp^.bitmap = $FFFFFFFF) then
             full_free_to_full(i, tmp);
      end;

      { On met à jour free_memory }
      free_memory -= size_dir[i].size;

      { On renvoie l'adresse du bloc au noyau }
      result := tmp^.page + (((res * 32) + res2) * size_dir[i].size);
if (longint(result) = $febfe0) then
begin
print_bochs('res=%d res2=%d\n', [res, res2]);
end;

   end;

	popfd();

end;



{******************************************************************************
 * kfree
 *
 * Entrée : pointeur sur l'adresse
 *
 * Libère la zone mémoire passe en paramètre
 *****************************************************************************}
procedure kfree (addr : pointer); [public, alias : 'KFREE'];
begin
   kfree_s(addr, 0);
end;



{******************************************************************************
 * kfree_s
 *
 * Entrée : adresse de la mémoire, longueur
 *
 * Cette procédure libère un bloc de taille size pointé par addr. Si size=0, on
 * recherche le bloc dans toutes les entrées de size_dir. Sinon, on effectue la
 * recherche dans l'entrée correspondante a size, ce qui est beaucoup plus
 * rapide. => il faut utiliser au maximum la procedure free_s plutôt que free
 *
 * FIXME: utiliser un sémaphore pour accéder à 'size_dir' plutot que de couper
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

   i    := 1;
   page := pointer(longint(addr) and $FFFFF000);

	pushfd();
	cli();

   { page pointe vers la page qui contient le bloc à libérer. On va rechercher
     cette page dans size_dir en fonction de size }

   if (size = 0) then
   { On ne connait pas la taille du bloc à libérer, on va donc le rechercher
     dans toutes les entrées de size_dir }
   begin
      {$IFDEF DEBUG_KREE_S}
      	 printk('kfree_s: size=0\n', []);
      {$ENDIF}
      repeat
         desc := find_page(page, size_dir[i].full_list);
	 		i += 1;
      until ((desc <> NIL) or (i = 10));
	 
      if (i = 10) then
      { Le bloc demander n'a pas été trouvé dans la full_list, on va
        rechercher dans la full_free_list }
      begin
	 		i := 1;
	 		repeat
	    		desc := find_page(page, size_dir[i].full_free_list);
	    		i += 1;
	 		until ((desc <> NIL) or (i = 10));

	 		if (i = 10) then
      	{ Le bloc n'a pas été trouvé dans la full_free_list => erreur }
         begin
	    		asm
					mov   eax, [ebp + 4]
					mov   i  , eax
	    		end;
	    		printk('kfree_s (%d): page not found in full_free_list 1 (%h) EIP=%h\n',
	            	 [current^.pid, addr, i]);
	    		print_bochs('kfree_s (%d): page not found in full_free_list 1 (%h) EIP=%h\n',
	            	 		[current^.pid, addr, i]);
	       	popfd();
	    		exit;
	 		end;
      end;
      i -= 1;
   end
   else
   { On connait la taille du bloc à libérer, on va donc le rechercher
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
      if (desc = NIL) then { On a pas trouvé la page }
      begin
	 		desc := find_page(page, size_dir[i].full_free_list);       
         if (desc = NIL) then
	 		begin
	    		asm
	       		mov   eax, [ebp + 4]
	       		mov   i  , eax
	    		end;
	    		printk('kfree_s (%d): page not found in full_free_list 2 (%h) EIP=%h\n',
	            	 [current^.pid, addr, i]);
	    		print_bochs('kfree_s (%d): page not found in full_free_list 2 (%h) EIP=%h\n',
	            	 		[current^.pid, addr, i]);
				popfd();
	    		exit;
	 		end;
      end;
   end;

   {* desc pointe sur le page_desc correspondant au bloc recherché et i est
    * l'index dans size_dir *}

   block := longint(addr) and $FFF;

   if ((block mod size_dir[i].size) <> 0) then
   begin
      asm
			mov   eax, [ebp + 4]
	 		mov   i  , eax
      end;
      printk('kfree_s: (block mod size_dir[i].size) <> 0. (%h) EIP=%h\n', [addr, i]);
		print_bochs('kfree_s: (block mod size_dir[i].size) <> 0. (%h) EIP=%h\n', [addr, i]);
		popfd();
      exit;
   end;

   block := block div size_dir[i].size;
   { block correspond au numéro du bloc à libérer dans la page }

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

   { On met à jour free_memory }
   free_memory += size_dir[i].size;

	popfd();

end;



{******************************************************************************
 * find_page
 *
 * Entrée : la page, la liste
 *
 * Cette fonction recherche page dans list. Elle renvoie NIL si elle n'a pas
 * trouvé et un pointeur vers le descripeur dans le cas contraire
 *****************************************************************************}
function find_page (page : pointer ; list : P_page_desc) : P_page_desc;

begin

   { On vérifie d'abord si list n'est pas vide }

   if (list = NIL) then
   begin
      result := NIL;
      exit;
   end;

	pushfd();
	cli();

   while ((list^.page <> page) and (list^.next <> NIL)) do
           list := list^.next;

	popfd();

   if ((list^.next = NIL) and (list^.page <> page)) then
   { On n'a pas trouvé la page }
        result := NIL
   else
   { On n'a trouvé la page }
        result := list;

end;



{******************************************************************************
 * full_free_to_free
 *
 * Entrée : ?, ?
 *
 * Déplace src de la full_free_list vers la free_list. Cette fonction doit
 * être appelée si full_free_list contient au moins un élément.
 *****************************************************************************}
procedure full_free_to_free (i : dword ; src : P_page_desc);

var
   tmp : P_page_desc;

begin

	pushfd();
	cli();

   if (src = size_dir[i].full_free_list) then
   { Si src est le premier élément de la full_free_list, on met l'élément 
     suivant en premier }
       size_dir[i].full_free_list := src^.next
   else
   begin
      { Recherche du précédent }
      tmp := size_dir[i].full_free_list;
      while (tmp^.next <> src) do
      	    tmp := tmp^.next;

      tmp^.next := src^.next;
   end;

   { Ici, src ne fait plus partie de la full_free_list. On va maintenant mettre 
     src dans la free_list }

   tmp := size_dir[i].free_list;
   size_dir[i].free_list := src;
   src^.next := tmp;

	popfd();

end;



{******************************************************************************
 * full_to_full_free
 *
 * Entree : ?, ?
 *
 * Déplace src de la full_list vers la full_free_list. Cette fonction doit
 * être appelée si full_list contient au moins un élément.
 *****************************************************************************}
procedure full_to_full_free (i : dword ; src : P_page_desc);

var
   tmp : P_page_desc;

begin

	pushfd();
	cli();

   if (src = size_dir[i].full_list) then
   { Si src est le premier élément de la full_list, on met l'élément 
     suivant en premier }
       size_dir[i].full_list := src^.next
   else
   begin
      { Recherche du précédent }
      tmp := size_dir[i].full_list;
      while (tmp^.next <> src) do
             tmp := tmp^.next;

      tmp^.next := src^.next;
   end;

   { Ici, src ne fait plus partie de la full_list. On va maintenant mettre src 
     dans la full_free_list }

   tmp := size_dir[i].full_free_list;
   size_dir[i].full_free_list := src;
   src^.next := tmp;

	popfd();

end;



{******************************************************************************
 * full_free_to_full
 *
 * Entrée : ?, ?
 *
 * Déplace src de la full_free_list vers la full_list. Cette fonction doit
 * être appelée si full_free_list contient au moins un élément.
 *****************************************************************************}
procedure full_free_to_full (i : dword ; src : P_page_desc);

{* Déplace src de la full_free_list vers la full_list. Cette fonction doit
 * être appelée si full_free_list contient au moins un élément. *}

var
   tmp : P_page_desc;

begin

	pushfd();
	cli();

   if (src = size_dir[i].full_free_list) then
   { Si src est le premier élément de la full_free_list, on met l'élément 
     suivant en premier }
       size_dir[i].full_free_list := src^.next
   else
   begin
      { Recherche du précédent }
      tmp := size_dir[i].full_free_list;
      while (tmp^.next <> src) do
             tmp := tmp^.next;

      tmp^.next := src^.next;
   end;

   { Ici, src ne fait plus partie de la full_free_list. On va maintenant mettre 
     src dans la full_list }

   tmp := size_dir[i].full_list;
   size_dir[i].full_list := src;
   src^.next := tmp;

	popfd();

end;



{******************************************************************************
 * free_to_full_free
 *
 * Entrée : ?, ?
 *
 * Déplace src de la free_list vers la full_free_list. Cette fonction doit
 * être appelée si free_list contient au moins un élément. De plus, on doit
 * initialiser le champ page de src si celui-ci est a NIL (puisqu'il est dans
 * la free_list)
 *****************************************************************************}
procedure free_to_full_free (i : dword ; src : P_page_desc);

var
   tmp : P_page_desc;
   res : pointer;

begin

	pushfd();
	cli();

   if (src = size_dir[i].free_list) then
   { Si src est le premier élément de la free_list, on met l'élément suivant
     en premier }
       size_dir[i].free_list := src^.next
   else
   begin
      { Recherche du précédent }
      tmp := size_dir[i].free_list;
      while (tmp^.next <> src) do
             tmp := tmp^.next;

      tmp^.next := src^.next;
   end;

   { Ici, src ne fait plus partie de la free_list. On va maintenant mettre src
     dans la full_free_list }

   tmp := size_dir[i].full_free_list;
   size_dir[i].full_free_list := src;
   src^.next := tmp;

	popfd();

   { On va initialiser le champ page de src s'il y a lieu }

   if (src^.page = NIL) then
   begin
      res := get_free_page();
      if (res = NIL) then
      begin
         printk('kmalloc error (free_to_full_free) : no more free pages !!!', []);
         exit;
      end
      else
         src^.page := res;

		{* We have to initalize the 2nd bitmap (inside the page) for i=1, 2 and 3
		 * because we don't want to allocate the bitmap  :)  *}

		case (i) of

			1: begin   { object size = 16, 2nd bitmap is 32 bytes long }
					res := pointer(longint(src^.page) + 4092);
					dword(res^) := 3;
				end;

			2: begin   { object size = 32, 2nd bitmap is 16 bytes long }
					res := pointer(longint(src^.page) + 4092);
					dword(res^) := 1;
				end;

			3: begin   { object size = 64, 2nd bitmap is 8 bytes long }
					res := pointer(longint(src^.page) + 4092);
					dword(res^) := 1;
				end;
		end;

   end;
end;



{******************************************************************************
 * init_free_list
 *
 * Entrée : index dans size_dir
 *
 * Cette fonction initialise et met des descripteurs dans la free_list quand
 * celle-ci est vide. Le parametre i permet de savoir quelle free_list remplir.
 * Elle renvoie 1 si tout c'est bien passé, sinon elle renvoie 0
 *****************************************************************************}
function init_free_list (i : dword) : dword;

var
   nb   : dword;
   desc : P_page_desc;

begin

   desc := get_free_page(); {* On récupère une page libre pour stocker des
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

   { Remplissage du 256 ème descripteur (le champ next est NIL) }

   desc^.page        := NIL;
   desc^.next        := NIL;
   desc^.bitmap      := bitmap[i];
   desc^.adr_bitmap2 := bitmap2[i];

   { Il faut maintenant insérer ces descripteurs dans la free list }

   desc -= 255; { Pointe vers le premier descripteur }

	pushfd();
	cli();

   size_dir[i].free_list := desc;

	popfd();

   result := 1; { Tout c'est bien passé (ouf !!!) }

end;



{******************************************************************************
 * memcmp
 *
 * Entrée : souce, destination, taille
 *
 * Compare size octets entre src et dest
 *
 * FIXME: write this in asssembly for speed.
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
 * Entrée : souce, destination, taille
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
 * Entrée : adresse, valeur, taille
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
function get_phys_addr (addr : dword) : dword; [public, alias : 'GET_PHYS_ADDR'];

begin

   result := longint(get_pte(addr)) and $FFFFF000;

end;



{******************************************************************************
 * get_page_rights
 *
 * Input  : virtual address
 * Output : page rights
 *
 * NOTE : I don't think we have to put interrupts off because each process has
 *        his own CR3 value (hope I'm right)
 *****************************************************************************}
function get_page_rights (addr : dword) : dword; [public, alias : 'GET_PAGE_RIGHTS'];
begin

   result := longint(get_pte(addr)) and $FFF;

end;



{******************************************************************************
 * set_page_rights
 *
 * Input  : VIRTUAL address, access rights
 * Output : NONE
 *
 * NOTE : I don't think we have to put interrupts off because each process has
 *        his own CR3 value (hope I'm right)
 *
 *****************************************************************************}
procedure set_page_rights (adr : pointer ; r : dword); assembler; [public, alias : 'SET_PAGE_RIGHTS'];

var
   glob_index, page_index : dword;

asm
   mov   eax, adr
   push  eax
   shr   eax, 22   { On récupère les 10 bits de poids fort }
   mov   glob_index, eax
   pop   eax
   shr   eax, 12
   and   eax, 1111111111b
   mov   page_index, eax
      
   mov   edi, cr3
   mov   eax, glob_index
   shl   eax, 2   { EAX = EAX * 4 }
   add   edi, eax
   mov   ebx, [edi]
   and   ebx, $FFFFF000
   mov   eax, page_index
   shl   eax, 2
   add   ebx, eax
   mov   eax, [ebx]
   or    eax, r
   mov   [ebx], eax
   
   mov   eax, cr3
   mov   cr3, eax
   
end;



{******************************************************************************
 * MAP_NR
 *
 * Entrée : adresse virtuelle ou adresse physique
 * Retour : index dans mem_map qui correspond au descripteur de la page
 *          dans laquelle se trouve l'adresse passée en paramètre
 *
 *****************************************************************************}
function MAP_NR(addr : dword) : dword; [public, alias : 'MAP_NR'];

begin
    result := get_phys_addr(addr) shr 12;
end;



{******************************************************************************
 * PageReserved
 *
 * Entrée : adresse physique d'une page
 * Retour : vrai si la page est réservée. Sinon, faux.
 *****************************************************************************}
function PageReserved (adr : dword) : boolean; [public, alias : 'PAGERESERVED'];

begin

	pushfd();
	cli();

   if (mem_map[adr shr 12].flags and ($80000000 shr PG_reserved) = $80000000 shr PG_reserved) then
       result := true
   else
       result := false;

	popfd();

end;



{******************************************************************************
 * unload_process_cr3
 *
 *****************************************************************************}
procedure unload_process_cr3 (ts : P_task_struct); [public, alias : 'UNLOAD_PROCESS_CR3'];

var
   i, j : dword;
   pt   : P_pte_t;

begin

{printk('unload_process_cr3: PID=%d  size=%d  (current=%d)\n', [ts^.pid, ts^.size,
      	 current^.pid]);}

   for i := 769 to 1023 do
	begin
      pt := pointer(ts^.cr3[i] and $FFFFF000);
      if (pt <> NIL) then
      begin
			for j := 0 to 1023 do
			begin
				if (pt[j] and $FFFFF000) <> 0 then
	    		begin
	       		push_page(pointer(pt[j] and $FFFFF000));
	       		ts^.real_size -= 1;
	    		end;
			end;
			push_page(pt);
			if (ts^.real_size = 0) then break;
      end;
   end;

   { Freeing stack }
   pt := pointer(ts^.cr3[768] and $FFFFF000);
   i  := 1023;

   while ((pt[i] and $FFFFF000) <> 0) do
   begin
      push_page(pointer(pt[i] and $FFFFF000));
      i -= 1;
   end;

   push_page(pt);

end;



{******************************************************************************
 * get_pte
 *
 * INPUT : virtual address
 *
 * OUTPUT: Page table entry for the page containing 'addr'
 *
 *****************************************************************************}
function get_pte (addr : dword) : P_pte_t; [public, alias : 'GET_PTE'];

var
   pt : P_pte_t;

begin

   addr := addr and $FFFFF000;

   pt := pointer(current^.cr3[addr div $400000] and $FFFFF000);

   if (pt = NIL) then
       result := NIL
   else
       result := pointer(pt[(addr and ($400000 - 1)) div 4096]);

   {$IFDEF DEBUG_GET_PTE}
      print_bochs('get_pte (%d): addr=%h  %d  %d => %h\n',
						[current^.pid, addr, addr div $400000,
						 (addr and ($400000 - 1)) div 4096, result]);
   {$ENDIF}

end;



{******************************************************************************
 * set_pte
 *
 * INPUT : addr -> Virtual address
 *         pte  -> Page table entry for 'addr'
 *
 *****************************************************************************}
procedure set_pte (addr : dword ; pte : pte_t); [public, alias : 'SET_PTE'];

var
   pt : P_pte_t;

begin

   pt := pointer(current^.cr3[addr div $400000] and $FFFFF000);

   if (pt = NIL) then
   begin
      pt := get_free_page();
      if (pt = NIL) then
      begin
			print_bochs('WARNING: set_pte: not enough memory\n', []);
	 		exit;
      end;
      memset(pt, 0, 4096);
      current^.cr3[addr div $400000] := longint(pt) or USER_PAGE;
   end;

   pt[(addr and ($400000 - 1)) div 4096] := pte;

   mem_map[longint(pte) shr 12].flags := longint(pte) and $F;

end;



{******************************************************************************
 * /dev/null management
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
 * /dev/zero management
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
