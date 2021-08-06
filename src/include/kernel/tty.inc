
Const

    ESnormal      = 1;
    ESesc         = 2;
    ESsquare      = 3;
    ESgetpars     = 4;
    ESgotpars     = 5;
    ESfunckey     = 6;
    ESsetterm     = 7;
    ESsetgraph    = 8;
    NBPAR         = 15;

    MAX_BUFF_CLAV = 31;
    Num_Lock      = 0;
    Caps_Lock     = 1;
    Scroll_Lock   = 2;
    NCCS          = 19;

    TCGETS        = $5401;
    TIOCGWINSZ    = $5413;

Type 
    tty_struct = record 
       x, y, attr, align    : byte;      { alignement }
       buffer_keyboard      : array[0..MAX_BUFF_CLAV] of char;
       keyboard_wq          : P_wait_queue;
       next_c,last_c        : byte;
       pad, pad1            : byte;      { alignement }
       depassement          : boolean;
       num_caps_scroll      : dword;
       echo                 : boolean;
       npar		    : dword;
       par                  : array[0..15] of dword;
    end;

    P_vesa_info_t = ^vesa_info_t;
    
    vesa_info_t = record
       signature    : dword;   { 0x41534556 }
       version      : word;
       oemstr       : pointer;
       capabilities : dword;
       modes        : pointer;
       memory       : word;
       reserved     : array [1..236] of byte;
    end;

    cc_t      = byte;    { typedef unsigned char cc_t; }
    speed_t   = dword;   { typedef unsigned int speed_t; }
    tcflag_t  = dword;   { typedef unsigned int	tcflag_t; }

    P_termios = ^termios;

    termios   = record
       c_iflag : tcflag_t;   { input mode flags }
       c_oflag : tcflag_t;   { output mode flags }
       c_cflag : tcflag_t;   { control mode flags }
       c_lflag : tcflag_t;   { local mode flags }
       c_line  : cc_t;       { line discipline }
       c_cc    : array[0..NCCS - 1] of cc_t;   { control characters }
    end;
