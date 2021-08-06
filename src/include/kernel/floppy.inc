const
    FDC_VERSION = $10;

    FD_BASEIO = $3F0 ;

    { Registre A etat disque (PS/2) }
    FD_DSR_A = FD_BASEIO + $0;
        { Direction }
        FD_DSR_DIRECTION = $01;

        { Protection en ecriture }
        FD_DSR_WRITE_PROTECT = $02;

        { Index ???? }
        FD_DSR_INDEX = $04;

        { Tete 1 selectionnee }
        FD_DSR_HEAD_1 = $08;

        { Piste 0 }
        FD_DSR_TRACK_0 = $10;

        { Etape (step ???) }
        FD_DSR_STEP = $20;

        { Deuxieme disque present }
        FD_DSR_DSK_2 = $40;

        { Interrupt pending ??? }
        FD_DSR_IP = $80;

    { Registre B etat disque (PS/2) }
    FD_DSR_B = FD_BASEIO + $1;
        { Moteur lecteur 0 actif }
        FD_DSR_B_MOTOR_0 = $01;

        { Moteur lecteur 1 actif }
        FD_DSR_B_MOTOR_1 = $02;

        { Ecriture possible }
        FD_DSR_B_WRITE = $04;

        { lecture de donnees en cours (toggles w/positive transition in 
	  -RD DATA) }
        FD_DSR_READ = $08;

        { ecriture de donnees en cours (toggles w/positive transition 
in WD DATA) }
        FD_DSR_WRITE = $10;

        { Selectionne le lecteur ??? }
        FD_DSR_DRIVE_SELECT = $20;

    { Digital Output Register - Permet le control du lecteur }
    FD_DOR = FD_BASEIO + $2;
        { Constantes pour le DOR }
        { Acces lecteur }
        FD_DOR_FLOPPY_1 = $00;
        FD_DOR_FLOPPY_2 = $01;
        FD_DOR_FLOPPY_3 = $02; { PC/XT uniquement - reserve pour le 
PS/2 }
        FD_DOR_FLOPPY_4 = $03; { PC/XT uniquement - reserve pour le 
PS/2 }

        { activer le controleur de disquette }
        FD_DOR_RESET = $04; { si = 0, reset }

        { active le DMA et interface I/O }
        FD_DOR_DMA_IO   = $08; { si = 1, active }

        { Active (1) ou arreter (0) les moteurs }
        FD_DOR_MOTOR_FLOPPY_1 = $10;
        FD_DOR_MOTOR_FLOPPY_2 = $20;
        FD_DOR_MOTOR_FLOPPY_3 = $40; { PC/XT uniquement }
        FD_DOR_MOTOR_FLOPPY_4 = $80; { PC/XT uniquement }

    { Tape Drive Register }
    FD_TDR = FD_BASEIO + $3;

    { Registre d'etat principal  et registre de configuration du taux 
de
      transfert de donnees }
    FD_MSR = FD_BASEIO + $4;
        { Disque 0 en recherche ou occupe }
        FD_MSR_FLOPPY_0 = $1;
        { Disque 1 en recherche ou occupe }
        FD_MSR_FLOPPY_1 = $2;
        { Disque 2 en recherche ou occupe }
        FD_MSR_FLOPPY_2 = $4;
        { Disque 3 en recherche ou occupe }
        FD_MSR_FLOPPY_3 = $8;

        { En cours de commande lecture/ecriture }
        FD_MSR_RWC = $10;

        { Controleur de disquette en mode non-DMA }
        FD_MSR_NOT_DMA_MODE = $20;

        { Direction de l'entree/sortie }
        FD_MSR_IO_DIR = $40 ;
            { 1 = FDC -> CPU soit en mode lecture
              0 = CPU -> FDC soit en mode ecriture }

        { Registre de donnee pret pour une E/S vers/depuis le CPU }
        FD_MSR_REG_DATA_READY = $80;

    { Registre de données }
    FD_DATA_REGISTER = FD_BASEIO + $5 ;

    { Registre de status de commande 0 (c'est mal traduit !)  et 
registre de donnees }
    FD_CSR = FD_BASEIO + $5;
    FD_CSR_0 = FD_BASEIO + $5;
        { Acces lecteur }
        FD_CSR_0_FLOPPY_1 = $00;
        FD_CSR_0_FLOPPY_2 = $01;
        FD_CSR_0_FLOPPY_3 = $02; { PC/AT uniquement - reserve pour le 
PS/2 }
        FD_CSR_0_FLOPPY_4 = $03; { PC/AT uniquement - reserve pour le 
PS/2 }
            { - PS/2 utilise uniquement 0-1 pour les diques }

        { Tete declenchant l'interruption }
        FD_CSR_0_HEAD= $04; { 0 ou 1 }

        { not ready on read/write or SS access to head 1 }
        FD_CSR_0_NOT_READT_RW = $08;

        { equipement }
        FD_CSR_0_EQUIPMENT = $10 ;
            { - equipement fonctionne s'il y a un signal d'erreur ou 
que la
                piste 0 n'est ete trouve apres 77 commande de 
recalibration
            }

        { etat apres commande de positionement }
        FD_CSR_0_SEEK = $20; { = 1, commande executee }

        { ettat derniere operation }
        FD_CSR_0_LAST_CMD = $C0;
            { 00 commande termine et reussite
              01 commande demarrer mais terminee anormalement
              10 commande invalide
              11 commande interrompue due au changement dans l'etat du 
signal
                 Ready issue du controleur de disque (PS/2 uniquement)
            }

    { Registre de status de commande 1 (c'est mal traduit !) }
    FD_CSR_1 = FD_BASEIO + $5;
        { Impossible de trouver la marque d'adresse ID (voir reg2) }
        FD_CSR_1_ID = $01;

        { protection contre l'ecriture trouvee lors de l'ecriture }
        FD_CSR_1_WP = $02;

        { Impossible de trouver le secteur demande }
        FD_CSR_1_SEC_NOT_FND = $04;

        { Impossible d'executer la commande dans un temps raisonnable }
        FD_CSR_1_CMD_TO = $10;

        { Erreur de donnees (CRC) }
        FD_CSR_1_CRC = $20;

        { Secteur hors limit }
        FD_CSR_EOC = $80 ;

    { Registre de status de commande 2 (c'est mal traduit !) }
    FD_CSR_2 = FD_BASEIO + $5;
        { manque l'adresse dans le champ de donnee }
        FD_CSR_2_MAM = $01;

        { mauvais cylindre }
        FD_CSR_2_BC = $02;

        { secteur non trouve }
        FD_CSR_2_SNFND = $04;

        { scan command equal condition satisfied }
        FD_CSR_2_SCECS = $08;

        { mauvais cylindre detecte }
        FD_CSR_2_WCD = $10;

        { erreur CRC detecte dans un secteur }
        FD_CSR_2_CRC = $20;

        { secteur avec donne d'adresse de marque efface detecte }
        FD_CSR_2_SWDDAMD = $40;

    { Registre de status de commande 3 (c'est mal traduit !) }
    FD_CSR_3 = FD_BASEIO + $5;
        { Acces lecteur }
        FD_CSR_3_FLOPPY_1 = $00;
        FD_CSR_3_FLOPPY_2 = $01;
        FD_CSR_3_FLOPPY_3 = $02; { PC/AT uniquement - reserve pour le 
PS/2 }
        FD_CSR_3_FLOPPY_4 = $03; { PC/AT uniquement - reserve pour le 
PS/2 }

        { Tete selectionne }
        FD_CSR_3_HEAD = $04;

        { Double face }
        FD_CSR_3_DF = $08;

        { Piste 0 }
        FD_CSR_3_TZ = $10 ;

        { Lecteur pret }
        FD_CSR_3_READY = $20;

        { Protege en ecriture }
        FD_CSR_3_WP = $40;

        { Signal d'erreur }
        FD_CSR_3_FSS = $80;


    { Registre d'entree digitale }
    FD_DIR = FD_BASEIO + $7 ;
        { Haute densite presente }
        FD_DIR_HD = $1;

        { Changement de disque }
        FD_DIR_DSK_CHANGE = $80;


    { Configuration du registre de control }
    FD_CCR = FD_BASEIO + $7;
        { DRC1, DRC0 }
        FD_CCR_DCR_01 = $3;
            { DRC1 DRC0
                0   0    500000 bit par second
                0   1    reserve
                1   0    250000 bit par second
                1   1    reserve
            }

    { octets par secteur }
    FD_BPS_512 = 2;

    { Time out }
    FD_TIMEOUT = 2000; { nb de boucle maxi }
    FD_WAIT_DELAY = 1000 ; { en ms }

    { Taux de transfert }
    FD_DRATE_500KBPS = 0; { hight density }
    FD_DRATE_300KBPS = 1;
    FD_DRATE_250KBPS = 2; { double density }
    FD_DRATE_1MBPS = 3; { Disquette 2.88 Mo }

    { Declaration des structures }

    { Port pour l'acces au RTC/equipement... }
    RTCSEL      = $70;
        { Valeur a ecrire pour avoir l'equipement }
        RTCSEL_EQUIPMENT = $14;
            { Masque pour savoir ce que l'on veut }
            RTCSEL_EQUIPMENT_DISKETTE = $1;
            RTCSEL_EQUIPMENT_NB_DSKT  = $c0;

        { Valeur pour connaitre le type de disquette }
        RTCSEL_DISKETTE_TYPE = $10;

    RTCDATA     = $71;

    NVRAM_FD    = $10;

type
    Floppy_Disk_Parameter = record
        nbHead   : byte ;
        nbSector : byte ;
        nbTrack  : byte ;
        isMFM    : boolean ; { indique s'il s'agit d'un disque 
double-densite }
    end ;
