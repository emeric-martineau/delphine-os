{$IFNDEF __FCNTL__}
{$DEFINE __FCNTL__}

const

   O_RDONLY   = $0;
   O_WRONLY   = $1;
   O_RDWR     = $2;
   O_CREAT    = $40;
   O_EXCL     = $80;
   O_NOCTTY   = $100;
   O_TRUNC    = $200;
   O_APPEND   = $400;
   O_NONBLOCK = $800;

   O_DIRECTORY = $10000;

   { Valeur des commandes pour l'appel système fcntl() }

   F_DUPFD = 0;
   F_GETFD = 1;
   F_SETFD = 2;
   F_GETFL = 3;
   F_SETFL = 4;


{$ENDIF}
