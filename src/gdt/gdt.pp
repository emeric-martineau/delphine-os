{******************************************************************************
 *  gdt.pp
 * 
 *  Gestion du bitmap de la GDT et gestion des TSS. Les entrées de la GDT sont 
 *  numerotées de 0 a 8191.
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.2 - ??/??/2001 - GaLi
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


unit _gdt;


INTERFACE


function  set_tss_desc (adr : pointer) : dword;
procedure set_gdt_entry(index : dword);
function  get_free_gdt_entry : dword;
procedure free_gdt_entry (index : dword);


function  bitscan(nb : dword) : dword; external;
procedure printf(format : string ; args : array of const); external;
procedure memcpy(src, dest : pointer ; size : dword); external;


{$I fs.inc}
{$I gdt.inc }
{$I process.inc }


var
   gdt : pointer;


IMPLEMENTATION



{******************************************************************************
 * init_gdt
 *
 * GDT initialization. Only called during DelphineOS initialization.
 *****************************************************************************}
procedure init_gdt; [public, alias : 'INIT_GDT'];
begin

   gdt := $2000;

   asm

   { Set GDT entries bitmap to 0 }

      mov   edi, $100000
      mov   ecx, 256
      xor   eax, eax
      rep   stosd

      mov   edi, gdt
      add   edi, 6*8   { There are 6 defined descriptors (see boot/setup.S) }
      xor   eax, eax
      mov   ecx, 16372
      rep   stosd
   end;

   { Entries 0 to 5 are used (see boot/setup.S) }

   set_gdt_entry(0);   { NULL DESCRIPTOR }
   set_gdt_entry(1);   { init TSS }
   set_gdt_entry(2);   { Kernel code }
   set_gdt_entry(3);   { Kernel data }
   set_gdt_entry(4);   { User code }
   set_gdt_entry(5);   { User data }

end;



{******************************************************************************
 * init_tss
 *
 * Entrée : pointeur vers une structure tss_struct
 *
 * Initialise une structure tss_struct
 *****************************************************************************}
procedure init_tss (tss : P_tss_struct); [public, alias : 'INIT_TSS'];
begin
   with tss^ do
      begin
         back_link := 0;
         __blh     := 0;
   
         ss0    := $18;
	 __ss0  := 0;
	 esp0   := 0;
         ss1    := 0;
         __ss1  := 0;
         esp1   := 0;
         ss2    := 0;
         __ss2  := 0;
         esp2   := 0;
	 ss     := $2B;
	 __ss   := 0;
         esp    := 0;
         ebp    := 0;
	 cs     := $23;
	 ds     := $2B;
	 es     := $2B;
	 fs     := $2B;
	 gs     := $2B;
         ldt    := 0;
         __ldt  := 0;
         trace  := 0;
         bitmap := 0;
      end;
end;



{******************************************************************************
 * set_tss_desc
 *
 * Entrée : pointeur vers une zone mémoire qui contient un TSS
 * Sortie : Numéro du descripteur de TSS ou -1 en cas d'erreur
 *
 * Crée un descripteur de TSS dans la GDT. L'adresse du TSS est specifiée
 * par le paramètre adr. Cette fonction renvoie le numéro de l'entrée utilisée
 * dans la GDT ou -1 si la GDT est remplie
 *****************************************************************************}
function set_tss_desc(adr : pointer) : dword; [public, alias : 'SET_TSS_DESC'];

var
   nb                : dword;
   tmp_desc          : t_gdt_desc;
   tss_desc_dest_adr : pointer;
   tmp1              : word;
   tmp2, tmp3        : byte;

begin
   asm
      mov   eax, adr
      mov   tmp1, ax
      shr   eax, 16
      mov   tmp2, al
      mov   tmp3, ah
   end;

   tmp_desc.limit1    := 103;   { Taille d'un TSS en octets }
   tmp_desc.base1     := tmp1;
   tmp_desc.base2     := tmp2;
   tmp_desc.desc_type := $89;   { Type : i386 valid TSS }
   tmp_desc.limit2    := $40;   { Limit2 = 0, Granularity = 0 }
   tmp_desc.base3     := tmp3;

   { On recupère une entrée libre dans la GDT }

   asm
      pushfd
      cli   { Section critique }
   end;

   nb := get_free_gdt_entry;
   
   if (nb <> -1) then
      begin
         tss_desc_dest_adr := pointer(gdt_start + (nb * 8));

         memcpy(@tmp_desc, tss_desc_dest_adr, sizeof(tmp_desc));

         set_gdt_entry(nb);
	 result := nb;
	 asm
	    popfd   { Fin section critique }
	 end;
      end
   else
      begin
         result := -1;
	 asm
	    popfd   { Fin section critique }
	 end;
      end;
end;



{******************************************************************************
 * get_free_gdt_entry
 *
 * Retour : numéro d'une entrée libre dans la GDT
 *
 * Renvoie le numéro de la première entrée libre dans la GDT ou -1 si il n'y a
 * plus d'entrées libres.
 *****************************************************************************}
function get_free_gdt_entry : dword; [public, alias : 'GET_FREE_GDT_ENTRY'];

var
   adr   : dword;  { Contient l'adresse du dword traité actuellement }
   tmp   : dword;  { Contient la valeur du dword traité actuellement }
   compt : dword;  { Un petit compteur de dword }

begin

   adr   := bitmap_start;
   compt := 0;

   while (adr <= bitmap_end) do
      begin
         asm
	    mov   esi, adr
	    mov   eax, [esi]
	    mov   tmp, eax
	 end;

	 if (tmp<>$FFFFFFFF) then
	    begin
	       result := (compt * 32) + bitscan(tmp);
	       exit;
	    end;

	 compt := compt + 1;
	 adr   := adr + 4;

      end;

   { Si on n'arrive ici, c'est qu'il n'y a plus d'entrées libres !!! }

   result := -1;

end;



{******************************************************************************
 * set_gdt_entry
 *
 * Entrée : numéro d'index à mettre occupé dans la GDT
 *
 * Met a 1 le bit du bitmap correspondant a l'index donné.
 * ATTENTION : index doit être < 8192
 *****************************************************************************}
procedure set_gdt_entry (index : dword); [public, alias : 'SET_GDT_ENTRY'];

var
   ofs, adr, val : dword;

begin

   ofs := (index div 32) * 4;
   adr := bitmap_start + ofs;   { Adresse du dword à modifier dans le bitmap }

   val := value[index mod 32];

   asm
      mov   edi, adr
      mov   eax, [edi]
      or    eax, val
      mov   [edi], eax
   end;

end;



{******************************************************************************
 * free_gdt_entry
 *
 * Entrée : numéro d'index à mettre libre dans la GDT
 *
 * Met a 0 le bit du bitmap correspondant a l'index donné.
 *****************************************************************************}
procedure free_gdt_entry (index : dword); [public, alias : 'FREE_GDT_ENTRY'];

var
   ofs, adr, val : dword;

begin

   ofs := (index div 32) * 4;
   adr := bitmap_start + ofs;

   val := value[index mod 32];

   asm
      mov   edi, adr
      mov   eax, [edi]
      not   val
      and   eax, val
      mov   [edi], eax
   end;

end;



begin
end.
