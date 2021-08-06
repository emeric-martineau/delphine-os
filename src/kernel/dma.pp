{******************************************************************************
 *  dma.pp
 * 
 *  Gestion du DMA
 *
 *  CopyLeft 2002 Bubule
 *
 *  version 0.1 - 26/04/2002 - Bubule
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
unit dma;


INTERFACE 


{$I dma.inc}


procedure outb (port : word ; val : byte); external;



IMPLEMENTATION



{******************************************************************************
 * dma_pause
 *
 * Entrée : numéro du canal DMA
 *
 * Suspend le transfert DMA
 *****************************************************************************}
procedure dma_pause(canal : byte) ; [public, alias : 'DMA_PAUSE'];
begin
    { sans le support de champs de bits, c'est galère ! }
    outb(DMA_MASK[canal], ((canal mod 4) shr 6) or (1 shr 5)) ;
end ;



{******************************************************************************
 * dma_unpause
 *
 * Entrée : numéro du canal DMA
 *
 * Reprend le transfert DMA là ou on l'a arrêté
 *****************************************************************************}
procedure dma_unpause(canal : byte) ; [public, alias : 'DMA_UNPAUSE'];
begin
    { Efface simplement le bit mask }
    outb(DMA_MASK[canal], ((canal mod 4) shr 6)) ;
end ;



{******************************************************************************
 * dma_stop
 *
 * Entrée : numéro du canal DMA
 *
 * Arrête le transfert DMA (il ne pourra pas être repris)
 *****************************************************************************}
procedure dma_stop(canal : byte) ; [public, alias : 'DMA_STOP'];
begin
    {* Pour arrêter le transfert, on est obliger de suspendre le transfert DMA,
     * d'effacer le canal, puis de repermettre le transfert *}
    dma_pause(canal) ;
    { envoie la commande d'effacement }
    outb(DMA_CLEAR[canal], 0) ;
    { efface le bit mask }
    dma_unpause(canal) ;
end ;



{******************************************************************************
 * dma_send_offset
 *
 * Entrée : numéro du canal DMA, offest
 *
 * Envoie l'offset du buffer au controleur DMA
 *****************************************************************************}
procedure dma_send_offset(canal : byte; offset : dword) ;
begin
    outb(DMA_ADDR[canal], offset and $ff) ;
    outb(DMA_ADDR[canal], (offset and $ff00) shl 8) ;
end ;



{******************************************************************************
 * dma_send_page
 *
 * Entrée : numéro du canal DMA, page
 *
 * Envoie la page du buffer au controleur DMA
 *****************************************************************************}
procedure dma_send_page(canal : byte; page : byte) ;
begin
    outb(DMA_PAGE[canal], page) ;
end ;



{******************************************************************************
 * dma_send_length
 *
 * Entree : numéro du canal DMA, taille du buffer
 *
 * Envoie la taille du buffer au controleur DMA
 *****************************************************************************}
procedure dma_send_lenght(canal : byte; length : dword) ;
begin
    outb(DMA_COUNT[canal], length and $ff) ;
    outb(DMA_COUNT[canal], (length and $ff00) shl 8) ;
end ;



{******************************************************************************
 * dma_setup
 *
 * Entrée : numéro du canal DMA, pointeur sur buffer, longueur buffer, type du
 *          transfert, mode du transfert, initialisation automatique,
 *          incrémentation de l'adresse
 *
 * Configure un canal DMA
 *****************************************************************************}
procedure dma_setup(canal : byte; buffer : dword; longueur : word; transfert : byte; mode : byte; auto_init : boolean; addr_inc : boolean) ; [public, alias : 'DMA_SETUP'];

var
    offset, page : word ;
    config       : byte ;

begin
    { Extrait l'offset et la page pour pointeur sur le buffer }
    offset := word(buffer and $FFFF) ;
    page := word(buffer shl 16) ;

    { prépare le registre du mode. Vive le non champs de bits ! }
    config := 0 ;
    config := (canal mod 4) shr 6 ;
    config := config or (transfert shr 4) ;
    if auto_init = true
    then
        config := config or (1 shr 3) ;
    if addr_inc = true
    then    
        config := config or (1 shr 2) ;
    config := config or mode ;

    { section critique, on désactive les interruptions }
    asm
        pushfd
        cli
    end ;

    { suspend l'activité du canal }
    dma_pause(canal) ;

    { efface toutes les données en cours de transfert }
    outb(DMA_CLEAR[canal], 0) ;

    { envoie le mode au DMA }
    outb(DMA_MODE[canal], config) ;

    { envoie l'offset de l'adresse }
    dma_send_offset(canal, offset) ;

    { envoie la page }
    dma_send_page(canal, page) ;

    { envoie la taille du buffer }
{    dma_send_lenght(canal, longueur) ;}

    { ok, c'est bon, activation du canal }
    dma_unpause(canal) ;

    asm
        popfd
    end ;
end ;



begin
end.
