{$IFNDEF __MAJOR__}
{$DEFINE __MAJOR__}

const


   { Characters devices }

   NULL_MAJOR   = 1;
   KEYB_MAJOR   = 2;
   COM_MAJOR    = 3;
   TTY_MAJOR    = 4;
   TTYAUX_MAJOR = 5;
   ZERO_MAJOR   = 6;


   { Block devices }

   FLOPPY_MAJOR = 2;
   IDE0_MAJOR   = 3;
   IDE1_MAJOR   = 4;
   IDE2_MAJOR   = 5;
   IDE3_MAJOR   = 6;

{$ENDIF}
