const
   INTERVAL = 10;             { en ms }
   PIT_COMPTEUR_16BITS = 0;
   PIT_COMPTEUR_MODE_3 = 6;   { envoie les poids faibles, puis les poids forts }
   PIT_CONTROL_MODE_LH = $30; { On selectionne le mode 3 du compteur car il
                                genere automatiquement les signaux. Il n'y a
				pas besoin d'intervention }
   PIT_COMPTEUR0 = 0;         { Choisi le compteur 0 (genere a partir de la
                                date) }
   PIT_COMPTEUR2    = $80;    { PC-Speaker }
   PIT_COUNTER0_REG = $40;
   PIT_COUNTER2_REG = $42;
   PIT_CONTROL_REG  = $43;


type

   P_tm = ^tm;

   tm = record
      tm_sec    : dword;     { Seconds after a minute }
      tm_min    : dword;     { Minutes after an hour }
      tm_hour   : dword;     { Hours after midnight }
      tm_mday   : dword;     { Day of the month }
      tm_mon    : dword;     { Months since January }
      tm_year   : dword;     { Years since 1900 }
      tm_wday   : dword;     { Days since sunday }
      tm_yday   : dword;     { Days since january 1st }
      tm_isdst  : dword;     { DST. [-1/0/1] }
      tm_gmtoff : dword;     { Seconds east of UTC }
      tm_zone   : pointer;   { Timezone abbreviation }
   end;
