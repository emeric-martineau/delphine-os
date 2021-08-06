type

   t_gdt_desc = record
      limit1    : word;
      base1     : word;
      base2     : byte;
      desc_type : byte;
      limit2    : byte;
      base3     : byte;
   end;

const
   gdt_start    = $2000;   { Adresse du debut de la GDT }
   bitmap_start = $100000;
   bitmap_end   = $100400;
   value : array[0..31] of dword = ($80000000, $40000000, $20000000,
                                    $10000000, $8000000, $4000000, $2000000,
                                    $1000000, $800000, $400000, $200000,
                                    $100000, $80000, $40000, $20000,
                                    $10000, $8000, $4000, $2000,
                                    $1000, $800, $400, $200,
                                    $100, $80, $40, $20,
                                    $10, $8, $4, $2, $1);
