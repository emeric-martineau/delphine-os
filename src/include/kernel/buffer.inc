{$IFNDEF __BUFFER__}
{$DEFINE __BUFFER__}

{$I wait.inc}

type

   P_buffer_head  = ^buffer_head;
   PP_buffer_head = ^P_buffer_head;

{ ATTENTION : chaque structure buffer_head ne g�re qu'un seul bloc logique }

   buffer_head = record  { 32 bytes }
      blocknr : dword;   { Num�ro de bloc logique }
      size    : dword;   { Taille du bloc en octets }
      count   : dword;
      major   : byte;    { Num�ro majeur du p�riph�rique concern� }
      minor   : byte;    { Num�ro mineur du p�riph�rique concern� }
      state   : byte;    { Etat du tampon }
      pad     : byte;    { Pour l'alignement }
      rsector : dword;   { Num�ro du sector initial du p�riph�rique r�el }
      data    : pointer; { Pointeur vers tampon }
      wait    : P_wait_queue; { File d'attente du tampon }
      next    : P_buffer_head;
   end;


{ Le champ state d�fini les drapeaux actifs sur un tampon. Ils peuvent avoir
  les valeurs suivantes : }

const

   BH_Uptodate = 1;
   { Il est d�fini si le tampon contient des donn�es valides. La valeur de ce
     drapeau est renvoy�e par la fonction buffer_uptodate() }

   BH_Dirty    = 2;
   { Il est d�fini si le tampon est modifi�, i.e. s'il contient des donn�es �
     �crire sur le p�riph�rique bloc. La valeur de ce drapeau est renvoy�e par
     la fonction buffer_dirty() }

   BH_Lock     = 4;
   { Il est d�fini si le tampon est v�rouill�, ce qui se produit si le tampon
     est impliqu� dans un transfert de disque. La valeur de ce drapeau est
     renvoy�e par la fonction buffer_lock() }

{$ENDIF}
