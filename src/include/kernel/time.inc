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
