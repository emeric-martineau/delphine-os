{$IFNDEF __BUFFER__}
{$DEFINE __BUFFER__}

{$I wait.inc}

type

   P_buffer_head  = ^buffer_head;
   PP_buffer_head = ^P_buffer_head;

{ ATTENTION : chaque structure buffer_head ne gère qu'un seul bloc logique }

   buffer_head = record
      blocknr : dword;   { Numéro de bloc logique }
      size    : dword;   { Taille du bloc en octets }
      count   : dword;
      major   : byte;    { Numéro majeur du périphérique concerné }
      minor   : byte;    { Numéro mineur du périphérique concerné }
      state   : byte;    { Etat du tampon }
      pad     : byte;    { Pour l'alignement }
      rsector : dword;   { Numéro du sector initial du périphérique réel }
      data    : pointer; { Pointeur vers tampon }
      wait    : P_wait_queue; { File d'attente du tampon }
      next    : P_buffer_head;
   end;


{ Le champ state défini les drapeaux actifs sur un tampon. Ils peuvent avoir
  les valeurs suivantes : }

const

   BH_Uptodate = 1;
   { Il est défini si le tampon contient des données valides. La valeur de ce
     drapeau est renvoyée par la fonction buffer_uptodate() }

   BH_Dirty    = 2;
   { Il est défini si le tampon est modifié, i.e. s'il contient des données à
     écrire sur le périphérique bloc. La valeur de ce drapeau est renvoyée par
     la fonction buffer_dirty() }

   BH_Lock     = 4;
   { Il est défini si le tampon est vérouillé, ce qui se produit si le tampon
     est impliqué dans un transfert de disque. La valeur de ce drapeau est
     renvoyée par la fonction buffer_lock() }

{$ENDIF}
