
const
 kbesc   =  1;
 kbenter = 28;
 kbleft  = 75;
 kbright = 77;
 kbSpace = 57;
 kbBkSpc = 14;
 kbCtrl  = 29;
 kbAlt   = 56;
 kbF1    =$3B;
 kbF2    =$3C;
 kbF3    =$3D;
 kbF4    =$3E;
 kbF5    =$3F;
 kbF6    =$40;
 kbF7    =$41;
 kbF8    =$42;
 kbF9    =$43;
 kbF10   =$44;
 kbF11   =$85;
 kbF12   =$86;

 {$ifdef KEYB_US}
 Lettres : array[1..128]of char=
  (  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0, 'q', 'w', 'e', 'r', 't',
    'y', 'u', 'i', 'o', 'p',  #0, '$', #13,  #0, 'a',
    's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';',  #0,
     #0,  #0, '*', 'z', 'x', 'c', 'v', 'b', 'n', 'm',
    ';', ':', '!',  #0,  #0,  #0, ' ',  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0);
 {$else}
 Lettres : array[1..128]of char=
  (  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0, 'a', 'z', 'e', 'r', 't',
    'y', 'u', 'i', 'o', 'p',  #0, '$', #13,  #0, 'q',
    's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm',  #0,
     #0,  #0, '*', 'w', 'x', 'c', 'v', 'b', 'n', ',',
    ';', ':', '!',  #0,  #0,  #0, ' ',  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0,
     #0,  #0,  #0,  #0,  #0,  #0,  #0,  #0);
 {$endif}
