{******************************************************************************
 *  ide-hd.pp
 * 
 *  IDE hard drives management
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.1 - 17/08/2002 - GaLi - hd_log_to_chs() doesn't use global 
 *                                    variables.
 *
 *  version 0.0 - 26/07/2002 - GaLi - initial version
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit ide_hd;


INTERFACE


{$I blk.inc}
{$I buffer.inc}
{$I fs.inc}
{$I ide.inc}
{$I process.inc}


{DEFINE DEBUG}


{ External procedures and functions }

procedure printk (format : string ; args : array of const); external;
procedure outb (port : word ; val : byte); external;
procedure schedule; external;
procedure sleep_on (wait : PP_wait_queue); external;
procedure wake_up (wait : PP_wait_queue); external;
procedure end_request (major : byte ; uptodate : boolean); external;
function  inb (port : word) : byte; external;
function  drive_busy (major, minor : byte) : boolean; external;


var
   drive_info : array[3..6, 0..1] of ide_struct; external name 'U_IDE_INIT_DRIVE_INFO';
   do_hd      : pointer; external name 'U_IDE_INIT_DO_HD';
   blk_dev    : array [0..MAX_NR_BLOCK_DEV] of blk_dev_struct; external name 'U_RW_BLOCK_BLK_DEV';

   ide_hd_nb_intr : dword;
   ide_hd_nb_sect : dword;


procedure do_hd_request (major : byte);
procedure hd_intr;
procedure hd_log_to_chs (major, minor : byte ; log : dword ; var c : word; var h,s : byte);
function  hd_open (inode : P_inode_t ; fichier : P_file_t) : dword;
procedure hd_out (major, minor : byte ; block, nsect : dword ; cmd : byte ; intr_adr : pointer);
procedure hd_read_intr;
procedure unexpected_hd_intr;



IMPLEMENTATION



const
   drive   : array[0..1] of byte = ($A0, $B0);
   hd_str  : array[3..6, 0..1] of string[4] = (('hda' + #0, 'hdb' + #0),
                                               ('hdc' + #0, 'hdd' + #0),
                                               ('hde' + #0, 'hdf' + #0),
					       ('hdg' + #0, 'hdh' + #0));


var
   cur_hd_req : P_request;



{******************************************************************************
 * hd_log_to_chs
 *
 * Entrée : numéro majeur et mineur du disque, secteur logique, variables à
 *          initialiser.
 *
 * Retour : Les variables c, h et s passées en paramètres sont initialisées.
 *
 * Convertit un numéro de secteur logique en triplet cylindre/tête/secteur
 * Uniquement utilisée pour les disques qui ne gère pas le LBA
 *****************************************************************************}
procedure hd_log_to_chs (major, minor : byte ; log : dword ; var c : word ; var h,s : byte); [public, alias : 'HD_LOG_TO_CHS'];

var
   tmp : dword;

begin

   minor := minor div 64;   {* Permet de savoir si on a à faire au disque
                             * maître ou esclave *}

   tmp := drive_info[major, minor].sectors * drive_info[major, minor].heads;

   c := log div tmp;

   tmp  := log div drive_info[major, minor].sectors;
   h := tmp mod drive_info[major, minor].heads;

   s := 1 + (log mod drive_info[major, minor].sectors);

end;




{******************************************************************************
 * hd_open
 *
 * Entrée : 
 * Retour : 0 si tout c'est bien passé et -1 en cas d'erreur
 *
 * Appelée a chaque fois qu'un appel systeme 'open' vise un disque ATA/ATAPI.
 * On vérifie juste si le périphérique existe.
 *****************************************************************************}
function hd_open (inode : P_inode_t ; fichier : P_file_t) : dword; [public, alias : 'HD_OPEN'];

var
   major, minor, drv : byte;

begin

   major := inode^.rdev_maj;
   minor := inode^.rdev_min;
   drv   := minor div 64;

   if (drive_info[major, drv].ide_type <> $FF) and
      (drive_info[major, drv].part[minor].p_type <> $00) then
   begin
      fichier^.pos := 0;
      result := 0;
   end
   else
      result := -1;

end;



{******************************************************************************
 * hd_intr
 *
 * Gestionnaire d'interruption pour les disques ATA/ATAPI
 *****************************************************************************}
procedure hd_intr; assembler; interrupt; [public, alias : 'HD_INTR'];
asm

   mov eax, ide_hd_nb_intr
   inc eax
   mov ide_hd_nb_intr, eax

   sti
   mov   eax, do_hd
   call  eax
   mov   al , $20
   out   $A0, al
   nop
   nop
   nop
   out   $20, al
end;



{******************************************************************************
 * unexpected_hd_intr
 *
 * Cette procédure est appelée par le gestionnaire d'interruption IDE
 * lorsqu'une interruption non prévue intervient.
 *****************************************************************************}
procedure unexpected_hd_intr; [public, alias : 'UNEXPECTED_HD_INTR'];

var
   i : dword;

begin
   printk('IDE: unexpected interrupt\n', []);

   for i := 3 to 6 do
   begin
      {* On lit le registre d'état de toutes les interfaces IDE afin de faire
       * croire que l'interruption a été traitée *}
      inb(drive_info[i, MASTER].IO_base + STATUS_REG);
   end;
end;



{******************************************************************************
 * hd_read_intr
 *
 * Cette procédure est appelée par hd_intr() afin de gérer une requête de
 * lecture.
 *
 * REMARQUE: les interruptions ont été réactivées par hd_intr().
 *****************************************************************************}
procedure hd_read_intr;

var
   status, major, minor : byte;
   reg, base     : word;
   buf           : pointer;

begin

   major  := cur_hd_req^.major;
   minor  := cur_hd_req^.minor;
   base   := drive_info[major, 0].IO_base;
   status := inb(base + STATUS_REG);

   {$IFDEF DEBUG}
      printk('hd_read_intr: status = %h2\n', [status]);
   {$ENDIF}

   if ((status and (BUSY_STAT or READY_STAT or DRQ_STAT or ECC_STAT or
                   ERR_STAT)) = (READY_STAT or DRQ_STAT)) then
      begin
	 { No errors, we are going to read data. }
	 reg := base + DATA_REG;
	 buf := cur_hd_req^.buffer;
	 if (drive_info[major, minor].dword_io <> 0) then
	 begin
	    asm
	       pushfd
	       cli
	       mov   ecx, 128
	       mov   edi, buf
	       xor   edx, edx
	       mov   dx , reg
	       @read_loop:
	          in    eax, dx
	          stosd
	       loop @read_loop
	       popfd
	    end;
	 end
	 else
	 begin
	    asm
	       pushfd
	       cli
	       mov   ecx, 256
	       mov   edi, buf
	       xor   edx, edx
	       mov   dx , reg
	       @read_loop:
	          in    ax , dx
	          stosw
	       loop @read_loop
	       popfd
	    end;
	 end;
	 cur_hd_req^.errors := 0;
	 cur_hd_req^.buffer += 512;
	 cur_hd_req^.sector += 1;
	 cur_hd_req^.nr_sectors -= 1;
	 if (cur_hd_req^.nr_sectors = 0) then
	 { Il n'y a plus de secteurs à lire. La requête est terminée }
	     begin
	        asm
		   pushfd
		   cli
		end;
		do_hd := @unexpected_hd_intr;
		asm
		   popfd
		end;
	        end_request(major, TRUE);
	     end
      end
   else
      begin
         if (status and $01) = $01 then
            begin
               printk('hd_read_intr: error register = %h2\n', [inb(base + ERR_REG)]);
               printk('hd_read_intr: %h2 %h2 %h2 %h2 %h2\n', [inb(base + NRSECT_REG), inb(base + SECTOR_REG),
      		inb(base + CYL_LSB_REG), inb(base + CYL_MSB_REG), inb(base + DRIVE_HEAD_REG)]);

	       end_request(major, FALSE);
            end;

      end;
end;



{******************************************************************************
 * hd_out
 *
 * Envoie à une interface IDE les octets nécessaires pour éxécuter une requête
 * de lecture/écriture.
 *
 * REMARQUE: Ici, les interruptions sont ACTIVES
 *****************************************************************************}
procedure hd_out (major, minor : byte; block, nsect : dword; cmd : byte; intr_adr : pointer);

var
   drive, drv, cyl_LSB, cyl_MSB : byte;
   lba1, lba2, lba3, lba4       : byte;
   cylindre, base               : word;
   tete, secteur                : byte;

begin

   drive := minor div 64;
   base  := drive_info[major, drive].IO_base;

   if (drive = 0) then
      drv := $A0   { On va s'adresser au maître }
   else
      drv := $B0;  { On va s'adresser à l'esclave }

   if not drive_busy(major, minor) then
   begin
      asm
         pushfd
	 cli   { Section critique }
      end;
      do_hd := intr_adr;   { intr_adr is a parameter from hd_out() }

      if (drive_info[major, drive].lba_sectors <> 0) then
      { Drive uses LBA }
         begin
	    asm
	       mov   eax , block
	       mov   lba1, al
	       mov   lba2, ah
	       shr   eax , 16
	       mov   lba3, al
	       and   ah  , $0F
	       mov   lba4, ah
	    end;
	    { Registers initialization }
	    outb(base + NRSECT_REG, nsect);
	    outb(base + SECTOR_REG, lba1);
	    outb(base + CYL_LSB_REG, lba2);
	    outb(base + CYL_MSB_REG, lba3);
	    outb(base + DRIVE_HEAD_REG, (lba4 or drv or $40));
	 end
      else
         { Drive doesn't use LBA }
         begin
	    hd_log_to_chs(major, minor, block, cylindre, tete, secteur);
	    asm
	       mov   ax, cylindre
	       mov   cyl_LSB, al
	       mov   cyl_MSB, ah
	       mov   al , tete
	       and   al, $0F
	       mov   tete, al
	    end;
	    { Registers initialization }
	    outb(base + NRSECT_REG, nsect);
	    outb(base + SECTOR_REG, secteur);
	    outb(base + CYL_LSB_REG, cyl_LSB);
	    outb(base + CYL_MSB_REG, cyl_MSB);
	    outb(base + DRIVE_HEAD_REG, drv or tete);
	 end;

      { Send command }
      {$IFDEF DEBUG}
         printk('hd_out: sending command\n', []);
      {$ENDIF}
      {printk('hd_out: %h2 %h2 %h2 %h2 %h2\n', [inb(base + NRSECT_REG), inb(base + SECTOR_REG),
      		inb(base + CYL_LSB_REG), inb(base + CYL_MSB_REG), inb(base + DRIVE_HEAD_REG)]);}

      outb(base + CMD_REG, cmd);

      asm
         popfd   { Fin section critique }
      end;

      {schedule;}

   end
   else
   begin
      printk('ide-hd: drive is busy.\n', []);
      end_request(major, FALSE);
      exit;
   end;
end;



{******************************************************************************
 * do_hd_request
 *
 * Prépare l'éxécution d'une requête.
 *
 * REMARQUE: Ici, les interruptions sont ACTIVES.
 *****************************************************************************}
procedure do_hd_request (major : byte); [public, alias : 'DO_HD_REQUEST'];

var
   block, nsect : dword;
   drive, minor : byte;

begin

   {$IFDEF DEBUG}
      printk('do_hd_request (%d): going to execute a request\n', [current^.pid]);
   {$ENDIF}

   asm
      pushfd
      cli   { Section critique }
   end;
   cur_hd_req := blk_dev[major].current_request;
   asm
      popfd   { Fin section critique }
   end;

   minor   := cur_hd_req^.minor;
   drive   := minor div 64;

   { On vérifie si les paramètres de la requête sont valides }

   if (major < 3) or (major > MAX_NR_BLOCK_DEV)then
      begin
         printk('ide-hd: major number %d is not a hard drive.\n', [major]);
         end_request(major, FALSE);
	 exit;
      end
   else if (minor > 128) then
      begin
         printk('ide-hd: minor number %d is too big.\n', [minor]);
	 end_request(major, FALSE);
	 exit;
      end
   else if (drive_info[major, drive].part[minor].p_type = 0) then
      begin
         printk('ide-hd: partition %d does not exists on dev %d:%d.\n', [minor, major, minor]);
	 end_request(major, FALSE);
	 exit;
      end
   else if (cur_hd_req^.sector > drive_info[major, drive].part[minor].p_size) then
      begin
         printk('ide-hd: asking sector %d but dev %d:%d has only %d sectors.\n', [cur_hd_req^.sector, major, minor, drive_info[major, drive].part[minor].p_size]);
	 end_request(major, FALSE);
	 exit;
      end;

   block := cur_hd_req^.sector + drive_info[major, drive].part[minor].p_begin;
   nsect := cur_hd_req^.nr_sectors;

   case (cur_hd_req^.cmd) of
      READ:  begin
                ide_hd_nb_sect += nsect;
                hd_out(major, minor, block, nsect, WIN_READ, @hd_read_intr);
             end;
      WRITE: begin
                printk('do_hd_request: cannot write for the moment. Sorry.\n', []);
             end
      else
             begin
	        printk('unknown hd_command\n', []);
	     end;
   end;

   {$IFDEF DEBUG}
      printk('do_hd_request: exiting\n', []);
   {$ENDIF}

end;



begin
end.
