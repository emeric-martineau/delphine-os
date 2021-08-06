
Const
    MAX_BUFF_CLAV = 31;

    Num_Lock    = 0;
    Caps_Lock   = 1;
    Scroll_Lock = 2;


Type 
    tty_struct = record 
       x, y, align1, align2 : byte;    { align1&2 pour aligner sur 32bits }
       buffer_keyboard      : array[0..MAX_BUFF_CLAV] of word;
       next_c,last_c        : byte;
       pad, pad1            : byte;     { align 4 bytes }
       depassement          : boolean;
       num_caps_scroll      : dword;
       echo                 : boolean; 

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
