{******************************************************************************
 *  floppy.pp
 * 
 *  Gestionnaire des lecteurs de disquette de DelphineOS 
 *
 *  CopyLeft 2002 Bubule
 *
 *  version 0.0.2a - 13/05/2002 - Bubule - correction d'un bug dû a une
 *                                         mauvaise valeur (quelle valeur ???)
 *                                       - modification de la présentation à
 *                                         l'écran (revue par GaLi parce que
 *                                         c'était n'importe quoi  :-)
 *
 *  version 0.0.2  - 30/04/2002 - Bubule - Ajout des procédures pour allumer/
 *                                         éteindre les moteurs d'un lecteur de
 *                                         disquette
 *                                       - Renomme les fonctions fd_in et
 *                                         fd_out en fd_send_byte et
 *                                         fd_get_byte
 *
 *  version 0.0.1  - 23/04/2002 - Bubule - Ajout des constantes pour l'accès
 *                                         aux ports/registres
 *                                       - Modification de la fonction fd_read
 *                                         pour qu'elle fonctionne
 *                                       - Détection des principaux lecteurs de
 *                                         disquettes
 *
 *  version 0.0    - ??/??/2001 - Gali
 *
 *  TODO : attente active->passive
 *
 *  Remerciement à Cornelis Frank (EduOS) qui pète du code de ouf mais en
 *  restant simple et compréhensible. Dommage que ce soit en C !
 *  Remerciement à Eran Rundstein (LittleOS).
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 ******************************************************************************}
unit fd;


INTERFACE


{$I blk.inc}
{$I fs.inc}
{$I floppy.inc}


procedure do_fd_request (major : byte);
function  fd_get_command_status : byte;

procedure printk (format : string ; args : array of const); external;
procedure outb (port : word ; val : byte); external;
procedure register_blkdev (nb : byte ; name : string[20] ; fops : P_file_operations); external;
function  inb (port : word) : byte; external;
function  btod (nb : byte) : dword; external;
procedure set_intr_gate (n : dword ; addr : pointer); external;
procedure enable_IRQ (n : byte); external;
procedure IO_delay; external;
function  get_value_counter : dword; external;


IMPLEMENTATION



var

    { Variables globales }
    piste, face, secteur : byte;

    { indique si une opération est en cours comme la lecture d'une piste }
    operation_en_cours : boolean ;

    do_fd      : pointer;
    fd_fops    : file_operations;
    cur_fd_req : P_request;

    { time.pp }
    compteur : dword; external name 'U_TIME_COMPTEUR';
    blk_dev  : array [0..MAX_NR_BLOCK_DEV] of blk_dev_struct; external name 'U_RW_BLOCK_BLK_DEV';



{******************************************************************************
 * fd_reset
 *
 * Reset le contrôleur du lecteur de disquettes
 *****************************************************************************}
procedure fd_reset;
var
    i : dword;

begin
    {le reset se fait à l'état bas donc le bit à la position ?? doit être a 0 }
    outb(FD_DOR, 0);
    { Réactive le contrôleur }
    outb(FD_DOR, (FD_DOR_DMA_IO or FD_DOR_RESET)); 

    for i := 1 to FD_TIMEOUT do
    begin
        {* Si vous avez l'impression qu'il manque du code, c'est normal. S'il
	 * n'y en a pas, c'est normal aussi. Bubule *}
    end;
end;



{******************************************************************************
 * fd_chs_to_log
 *
 * Entrée : piste, face, secteur
 *
 * Convertit un triplet piste/face/secteur en un numéro de bloc logique
 *****************************************************************************}
function fd_chs_to_log (p, f, s : dword) : dword;
begin
    {* exposant du logarithme de l'intégrale cosinus... Beurk, j'aime pas les
     * maths !!! Bubule *}
    result := (s - 1) + (f * 18) + (p * 36);
end;



{******************************************************************************
 * fd_log_to_chs
 *
 * Entrée : secteur logique
 *
 * Convertit un numéro de bloc logique en un triplet piste/face/secteur
 *****************************************************************************}
procedure fd_log_to_chs (log : dword);

begin
    { Aaah ! Ca ressemble plus à quelque chose }
    piste   := log div 36;
    face    := (log div 18) mod 2;
    secteur := 1 + (log mod 18);
end;



{******************************************************************************
 * fd_send
 *
 * Entrée : octet à envoyer
 *
 * Ecrit un octet vers le command status register 0
 *****************************************************************************}
procedure fd_send_byte (val : byte);
var
    c, r : dword;
begin
    c := FD_TIMEOUT;

    repeat
        r := (inb(FD_MSR) and (FD_MSR_REG_DATA_READY or FD_MSR_IO_DIR));

        { Périphérique prêt }
        if (r = FD_MSR_REG_DATA_READY)
        then
            break;

        c := c - 1;
    until (c = 0);

    if (c = 0)
    then
        printk('\nfd_get_byte: timeout\n', [])
    else
        outb(FD_CSR, val);
end;



{******************************************************************************
 * fd_get_byte
 *
 * Retour : l'octet de donnée
 *
 * Recupere un octet de donnée
 *****************************************************************************}
function fd_get_byte : byte;
var
    c, r : dword;
begin
    c := FD_TIMEOUT ;

    repeat
        { voir s'il faut vérifier qu'on est en cours de commande }
        r := (inb(FD_MSR) and (FD_MSR_REG_DATA_READY  or FD_MSR_IO_DIR));

        { Périphérique prêt }
        if (r = (FD_MSR_REG_DATA_READY  or FD_MSR_IO_DIR))
        then
            break;

        IO_delay ;

        c := c - 1;
    until (c = 0);

    if (c = 0)
    then
        Result := 0
    else
        Result := inb(FD_CSR);
end;



{******************************************************************************
 * fd_get_command_status
 *
 * Retour : valeur du command status register
 *
 * Récupère la valeur du command status register
 *****************************************************************************}
function fd_get_command_status : byte;
begin
    result := inb(FD_CSR);
end;



{******************************************************************************
 * fd_read
 *
 * Entree : secteur logique, le buffer
 * Sortie : le buffer
 * Retour : état de l'opération
 *
 * Lit le secteur logique log
 *****************************************************************************}
function fd_read (log : dword) : dword;
begin
    fd_log_to_chs(log); { Initialise les variables piste, face et secteur }
   
    outb(FD_DOR, (FD_DOR_MOTOR_FLOPPY_1 or FD_DOR_DMA_IO or FD_DOR_RESET));
    outb($3F5, $46);
    outb($3F5, $00);
    outb($3F5, piste);   { Piste }
    outb($3F5, face);    { Tête }
    outb($3F5, secteur); { Secteur }
    outb($3F5, $02);
    outb($3F5, 18);
    outb($3F5, $2A);
    outb($3F5, $00);
   
    outb(FD_DOR, 00);

    {* si avec ça on n'est pas IN(1)
     * 
     * (1) : explication pour les gens qui lirais ça dans quelques années. En
     *     2002, on dit de quelqu'un qui est IN, quelqu'un qui est dans le
     *     coup. Quelqu'un qu'on dira ringard les années suivantes. *}

    Result := 1 ;
end;



{******************************************************************************
 * unexpected_fd_intr
 *
 * Cette procédure est appelée lorsqu'une interruption non prévue intervient.
 *****************************************************************************}
procedure unexpected_fd_intr;
begin
   printk('FD: unexpected interrupt !!!\n', []);
end;



{******************************************************************************
 * fd_intr
 *
 * Cette procédure s'éxécute quand le floppy envoie une interruption
 *****************************************************************************}
procedure fd_intr; assembler; interrupt;
asm
   {* Seul le PIC maître est remis à zéro car le lecteur de disquette est 
    * branché sur l'IRQ6. Seul le PIC maître est donc concerné. *}
   sti
   mov   eax, do_fd
   call  eax
   mov   al , $20
   out   $20, al
   nop
   nop
   nop
end;



{******************************************************************************
 * fd_motor_on
 *
 * Entrée : numéro du lecteur (0=1er...)
 *
 * Met le moteur du lecteur en route
 *****************************************************************************}
procedure fd_motor_on(lecteur : word) ;
begin
    outb(FD_DOR, (1 shl (4 + lecteur)) or FD_DOR_DMA_IO or FD_DOR_RESET or lecteur) ;
end ;



{******************************************************************************
 * fd_motor_off
 *
 * Entrée : numéro du lecteur (0=1er...)
 *
 * Arrête le moteur du lecteur
 *****************************************************************************}
procedure fd_motor_off(lecteur : word) ;
begin
    outb(FD_DOR, FD_DOR_DMA_IO or FD_DOR_RESET or lecteur) ;
end ;



{******************************************************************************
 * fd_wait
 *
 * Retour : true ou false
 *
 * Attend qu'il n'y ait plus d'opération en cours. ATTENTION ! Attente active
 *****************************************************************************}
function fd_wait : boolean ;
var
    ancien_compteur : dword ;
begin
    ancien_compteur := get_value_counter ;

    while (operation_en_cours and ((ancien_compteur + FD_WAIT_DELAY) > get_value_counter)) do ;

    Result := not operation_en_cours ;
end ;



{******************************************************************************
 * do_fd_request
 *
 * REMARQUE: Les interruptions sont ACTIVES
 *****************************************************************************}
procedure do_fd_request (major : byte);
begin

   if (major <> 2) then
   begin
      printk('FLOPPY: bad major number\n', [major]);
      exit;
   end;

   cur_fd_req := blk_dev[major].current_request;

end;



{******************************************************************************
 * fd_read_intr
 *
 *****************************************************************************}
procedure fd_read_intr;
begin
end;



{******************************************************************************
 * init_fd
 *
 * Initialise les lecteurs de disquette (seulement appelée au démarrage de
 * DelphineOS)
 *****************************************************************************}
procedure init_fd; [public, alias : 'INIT_FD'];

var
    version   : byte;
    c         : dword;
    cmos_type : byte;
    fd_type   : byte;
    dec       : byte;
    nb_floppy_disk : integer ;
    i : integer ;

begin
    set_intr_gate(38, @fd_intr);
    enable_IRQ(6);
    do_fd := @unexpected_fd_intr;
    fd_fops.open  := NIL;
    fd_fops.read  := NIL;
    fd_fops.write := NIL;
    fd_fops.seek  := NIL;
    register_blkdev(2, 'fd', @fd_fops);

    { Regarde s'il y a au moins un lecteur present }
    outb(RTCSEL, RTCSEL_EQUIPMENT) ;

    { Utilise la variable version pour économiser des variables }
    version := inb(RTCDATA) ;

    { Si il y a un contrôleur de disquette }
    if ((version and RTCSEL_EQUIPMENT_DISKETTE) <> 0)
    then begin
        { 0 -> 1 lecteur, 1 -> 2 lecteurs. Les autres valeurs sont reservées }
        nb_floppy_disk := ((version and RTCSEL_EQUIPMENT_NB_DSKT) shr 6);

        printk('FDC: ', []) ;

        { Affiche le contrôleur }
        fd_reset;
        fd_send_byte(FD_CSR_0_EQUIPMENT);
        version := fd_get_byte;

        case (version) of
            $00: printk('** WARNING ** TIMEOUT, CHECK YOUR CONTROLER.\n', []);
            $80: printk('Nec765A compatible controller\n', []);
            $90: printk('Nec765B compatible controller\n', []);
            else printk('unknown controller\n', []);
        end;

        if (version <> 0)
        then begin
            {* Lire les caractéristiques pour chaque lecteur - Seul 2 lecteurs
	     * sont supportés avec le PC/AT (i386 oblige) *}
            for i := 0 to nb_floppy_disk do
            begin

                printk('fd%d: ', [i]) ;
                { Regarde de quel type de lecteur il s'agit }
                outb(RTCSEL, RTCSEL_DISKETTE_TYPE) ;
                cmos_type := inb(RTCDATA) ;

                asm
                    mov   al , cmos_type
                    mov   cl , dec
                    shr   al , cl
                    and   al , $F
                    mov   fd_type, al
                end;

                cmos_type := (cmos_type shr ((1 - i)*4)) and $0F ;

                case (cmos_type) of
                    $00 : printk('no floppy drive connected\n', []) ;
                    $01 : printk('360Kb\n', []) ;
                    $02 : printk('1.2Mb\n', []) ;
                    $03 : printk('720Kb\n', []) ;
                    $04 : printk('1.44Mb\n', []) ;
                    {* Quelqu'un sur terre a-t-il un lecteur de disquette 
		     * 2.88 ? *}
                    $05 : printk('2.88Mo (AMI BIOS ?)\n', []) ;
                    $06 : printk('2.88Mo\n', []);
                    else  printk('your floppy drive is too old or too new !!!\n', []) ;
                end ;
            end ;
        end
        else
            printk('** WARNING ** NO FLOPPY CONTROLER FOUND !\n', []);
    end ;
end;



begin
end.
