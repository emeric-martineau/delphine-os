const
    CHANNEL0 = 0 ;
    CHANNEL1 = 1 ;
    CHANNEL2 = 2 ;
    CHANNEL3 = 3 ;

    VERIF_TRANS   = 0 ;
    WRITE_TRANS   = 1 ;
    READ_TRANS    = 2 ;
    CASCADE_TRANS = 3 ; { je ne suis pas sur que ca existe }

    DEMAND_MODE  = 0 ;
    SINGLE_MODE  = 1 ;
    BLOCK_MODE   = 2 ;
    CASCADE_MODE = 3 ;
    
    DMA_MASK  : array[0..7] of byte = ($0a, $0a, $0a, $0a, $d4, $d4, $d4, $d4) ;
    DMA_MODE  : array[0..7] of byte = ($0b, $0b, $0b, $0b, $d6, $d6, $d6, $d6) ;
    DMA_CLEAR : array[0..7] of byte = ($0c, $0c, $0c, $0c, $d8, $d8, $d8, $d8) ;

    DMA_PAGE  : array[0..7] of byte = ($87, $83, $81, $82, $8f, $8b, $89, $8a) ;
    DMA_ADDR  : array[0..7] of byte = ($00, $02, $04, $06, $c0, $c4, $c8, $cc) ;
    DMA_COUNT : array[0..7] of byte = ($01, $03, $05, $07, $c2, $c6, $ca, $ce) ;
