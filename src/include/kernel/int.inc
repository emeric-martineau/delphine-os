const
    pic_mask  : array[0..7] of byte = (1, 2, 4, 8, 16, 32, 64, 128);
    idt_start = $100400;   { Adresse du debut de l'IDT }

type
    idt_desc = record
        base1 : word;   { Deplacament (0-15) }
        seg   : word;   { Selecteur de segment }
        attr  : word;   { Attributs }
        base2 : word;   { Deplacement (16-31) }
    end;
