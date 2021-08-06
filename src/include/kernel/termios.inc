{$IFNDEF __TERMIOS__}
{$DEFINE __TERMIOS__}


type

   P_winsize = ^winsize;

   winsize = record
      ws_row    : word;
      ws_col    : word;
      ws_xpixel : word;
      ws_ypixel : word;
   end;


{$ENDIF}
