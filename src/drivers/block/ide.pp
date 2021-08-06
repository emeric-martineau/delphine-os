{******************************************************************************
 *  ide.pp
 * 
 *  ATA/ATAPI devices detection
 *
 *  CopyLeft 2003 GaLi
 *
 *  version 0.6 - 27/09/2003 - GaLi - Lots of clean up   :-)
 *
 *  version 0.5 - 23/11/2002 - GaLi - Add support for really old hard drives
 *
 *  version 0.4 - 26/10/2002 - GaLi - Better partitions and drives detection
 *
 *  version 0.3 - ??/??/2001 - GaLi - initial version
 *
 *  NOTE: special (very limited) support for Promise 20262 PCI mass storage
 *    	  controller (because this is what I have)   :-)
 *
 *  Major number stands for the IDE interface on which the device is.
 *  Minor number stands for device partition.
 *
 *  You must specify both major and minor numbers when calling a procedure or
 *  a function.
 *
 *  Major numbers :
 *      - hda, hdb : IDE0_MAJOR (3)
 *      - hdc, hdd : IDE1_MAJOR (4)
 *      - hde, hdf : IDE2_MAJOR (5)
 *      - hdg, hdh : IDE3_MAJOR (6)
 * 
 *  Minor numbers :
 *      - 0        : Master device itself (no filesystem support)
 *      - 1 a 4    : Master drive primary partitions
 *      - 5 a 63   : Master drive extended partitions
 *      - 64       : Slave drive itself (no filesystem support)
 *      - 65 a 68  : Slave drive primary partitions
 *      - 69 a 128 : Slave drive extended partitions
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


unit ide_init;



INTERFACE



{$I blk.inc}
{$I buffer.inc}
{$I fs.inc}
{$I ide.inc}
{$I major.inc}
{$I process.inc}
{$I pci.inc}



{DEFINE DEBUG}
{DEFINE SHOW_PART_TYPE}



{ External procedures }

procedure delay; external;
procedure do_hd_request (major : byte); external;
procedure enable_IRQ (irq : byte); external;
procedure hd_intr; external;
procedure hd_log_to_chs (major, minor : byte ; log : dword ; var c : word ; var h,s : byte); external;
function  hd_open (inode : P_inode_t ; fichier : P_file_t) : dword; external;
function  inb (port : word) : byte; external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure outb (port : word ; val : byte); external;
procedure printk (format : string ; args : array of const); external;
procedure register_blkdev (nb : byte ; name : string[20] ; fops : P_file_operations); external;
procedure set_intr_gate (n : dword ; addr : pointer); external;
procedure unexpected_hd_intr; external;


{ External variables }
var
   blk_dev : array [0..MAX_NR_BLOCK_DEV] of blk_dev_struct; external name 'U_RW_BLOCK_BLK_DEV';
   first_pci_device : P_pci_device; external name 'U_PCI_INIT_FIRST_PCI_DEVICE';
   nb_pci_devices : dword; external name 'U_PCI_INIT_NB_PCI_DEVICES';
   
   ide_hd_nb_intr       : dword; external name 'U_IDE_HD_IDE_HD_NB_INTR';
   ide_hd_nb_sect_read  : dword; external name 'U_IDE_HD_IDE_HD_NB_SECT_READ';
   ide_hd_nb_sect_write : dword; external name 'U_IDE_HD_IDE_HD_NB_SECT_WRITE';


{ Exported variables }
var
   drive_info    : array[IDE0_MAJOR..IDE3_MAJOR, MASTER..SLAVE] of ide_struct;
   do_hd         : pointer;



procedure detect_drive (major, minor : byte);
function  drive_busy (major, minor : byte) : boolean;
procedure extended_part (major, minor : byte ; p_begin : dword);
procedure init_ide;
function  lba_capacity_is_ok (id : P_drive_id) : boolean;
procedure partition_check (major, minor : byte);
procedure print_ide_info (command : byte ; major, minor : byte);
procedure select_drive (major, minor : byte);



IMPLEMENTATION



const
   drive   : array[MASTER..SLAVE] of byte = ($A0, $B0);
   hd_str  : array[IDE0_MAJOR..IDE3_MAJOR, MASTER..SLAVE] of string[4] = (('hda' + #0, 'hdb' + #0),
                                             			          ('hdc' + #0, 'hdd' + #0),
                                               				  ('hde' + #0, 'hdf' + #0),
					       				  ('hdg' + #0, 'hdh' + #0));

var
   ata_buffer : drive_id;
   ext_no     : dword;
   hd_fops    : file_operations;



{******************************************************************************
 * lba_capacity_is_ok
 *
 * Performs a sanity check on the claimed "lba_capacity" value for a drive.
 *
 * Returns: 1 if lba_capacity looks sensible
 *    	    0 otherwise
 *
 * NOTE: Code from Linux 2.4.22 (drivers/ide/ide-disk.c)
 *****************************************************************************}
function lba_capacity_is_ok (id : P_drive_id) : boolean;

var
   lba_sects, chs_sects, head, tail : dword;

begin

   if (((id^.command_set_2 and $400) = $400) and
       ((id^.cfs_enable_2 and $400) = $400)) then
   begin
      { 48-bit Drive. Not supported by DelphineOS }
      printk('48-bit Drive (not supported) ', []);
      result := FALSE;
      exit;
   end;

   {*
    * The ATA spec tells large drives to return
    * C/H/S = 16383/16/63 independent of their size.
    * Some drives can be jumpered to use 15 heads instead of 16.
    * Some drives can be jumpered to use 4092 cyls instead of 16383.
    *}
   if (((id^.cyls = 16383) or ((id^.cyls = 4092) and (id^.cur_cyls = 16383)))
      and (id^.sectors = 63) and ((id^.heads = 15) or (id^.heads = 16))
      and (id^.lba_capacity >= 16383*63*id^.heads)) then
   begin
      result := TRUE;
      exit;
   end;

   lba_sects := id^.lba_capacity;
   chs_sects := id^.cyls * id^.heads * id^.sectors;

   {* perform a rough sanity check on lba_sects:  within 10% is OK *}
   if ((lba_sects - chs_sects) < chs_sects div 10) then
   begin
      result := TRUE;
      exit;
   end;

   {* some drives have the word order reversed *}
   asm
      mov   eax, lba_sects
      shr   eax, 16
      and   eax, $FFFF
      mov   head, eax	{ head = ((lba_sects >> 16) & 0xffff); }
   end;
   tail := lba_sects and $FFFF;
   asm
      mov   eax, tail
      shl   eax, 16
      or    eax, head
      mov   lba_sects, eax
   end;
   if ((lba_sects - chs_sects) < chs_sects div 10) then
   begin
      id^.lba_capacity := lba_sects;
      result := TRUE;
      exit;   {* lba_capacity is (now) good *}
   end;

   result := FALSE;   {* lba_capacity value may be bad *}

end;



{******************************************************************************
 * select_drive
 *
 *****************************************************************************}
procedure select_drive (major, minor : byte);

var
   base : word;
   drive_nb : byte;

begin

   base     := drive_info[major, minor div 64].IO_base;
   drive_nb := drive[minor div 64];
   outb(base + DRIVE_HEAD_REG, drive_nb);

end;



{******************************************************************************
 * drive_busy
 *
 * Input  : major and minor number
 * Output : TRUE or FALSE
 *
 * Return TRUE if device is busy (or if there is no device) and FALSE if device
 * is ready. 
 *****************************************************************************}
function drive_busy (major, minor : byte) : boolean; [public, alias : 'DRIVE_BUSY'];

var
   i    : dword;
   base : word;

begin

   base   := drive_info[major, minor div 64].IO_base;
   result := TRUE;

   for i := 1 to 70000 do
   begin
      if (inb(base + STATUS_REG) and BUSY_STAT) = 0 then
      begin
      	 result := FALSE;
	 exit;
      end;
   end;

end;




{******************************************************************************
 * data_ready
 *
 * Input  : major and minor number
 * Output : TRUE or FALSE
 *
 * Return TRUE if data can be transferred
 *****************************************************************************}
function data_ready (major, minor : byte) : boolean; [public, alias : 'DATA_READY'];

var
   i    : dword;
   base : word;

begin

   base   := drive_info[major, minor div 64].IO_base;
   result := FALSE;

   for i := 1 to 70000 do
   begin
      if (inb(base + STATUS_REG) and (DRQ_STAT or BUSY_STAT)) = DRQ_STAT then
      begin
         result := TRUE;
	 exit;
      end;
   end;

end;



{******************************************************************************
 * drive_error
 *
 * Input  : major and minor number
 * Output : TRUE or FALSE
 *
 * Return TRUE if an error occured
 *****************************************************************************}
function drive_error (major, minor : byte) : boolean;

var
   base : word;

begin

   base := drive_info[major, minor div 64].IO_base;

   if (inb(base + STATUS_REG) and ERR_STAT) = ERR_STAT then
       result := TRUE
   else
       result := FALSE;

end;



{******************************************************************************
 * extended_part
 *
 * Input : major, minor number and partition's first logical sector
 *
 * Register some informations about extended partitions
 *****************************************************************************}
procedure extended_part (major, minor : byte ; p_begin : dword);

var
   cyl_LSB, cyl_MSB   : byte;
   buffer             : partition_table;
   buf_adr            : pointer;
   port, base         : word;
   a, min             : byte;
   i                  : dword;
   cylindre           : word;
   tete, secteur, drv : byte;

begin

   min := minor div 64;
   drv := drive[min];

   if (drive_info[major, min].lba_sectors <> 0) then
   begin
      asm
        mov   eax, p_begin
	mov   secteur, al
	mov   cyl_LSB, ah
	shr   eax, 16
	mov   cyl_MSB, al
	and   ah, $0F
	or    ah, $40
	mov   tete, ah
      end;
   end
   else
   begin
      hd_log_to_chs(major, minor, p_begin, cylindre, tete, secteur);
      asm
         mov   ax , cylindre
         mov   cyl_LSB, al
         mov   cyl_MSB, ah
      end;
   end;

   base := drive_info[major, min].IO_base;
   outb(base + NRSECT_REG, 1);          { Read 1 sector }
   outb(base + SECTOR_REG, secteur);    { Sector number }
   outb(base + CYL_LSB_REG, cyl_LSB);   { Cylinder number (LSB) }
   outb(base + CYL_MSB_REG, cyl_MSB);   { Cylinder number (MSB) }
   outb(base + DRIVE_HEAD_REG, tete or drv);   { Head }
   outb(base + CMD_REG, WIN_READ);             { Read sector command }

   if (not drive_error(major, minor)) and
       data_ready(major, minor) then 
   begin
      { Data are there, no error }
      port    := base;
      buf_adr := addr(buffer);

      asm
         mov   edi, buf_adr
         mov   dx , port
         mov   ecx, 256
         cld
         @read_data_loop:
            in    ax , dx
            stosw
         loop @read_data_loop
      end; { -> asm }
   end
   else
      printk('\nextended_part: cannot read sector\n', []);

   if (buffer.magic_word) <> $AA55 then
       printk('!', []);

   for i := 1 to 4 do
   begin
      if (buffer.entry[i].type_part <> 0) then
      begin
         case (buffer.entry[i].type_part) of
	    $5: extended_part(major, minor, buffer.entry[i].dist_sec + p_begin);
	    $F: extended_part(major, minor, buffer.entry[i].dist_sec + p_begin);
	    else
	    begin
	       if (buffer.entry[i].type_part <> 0) then
	       begin
	          drive_info[major, min].part[ext_no].p_type  := buffer.entry[i].type_part;
	          drive_info[major, min].part[ext_no].p_begin := buffer.entry[i].dist_sec + p_begin;
		  drive_info[major, min].part[ext_no].p_size  := buffer.entry[i].taille_part;
		  printk(hd_str[major, min], []);
		  printk('%d ', [ext_no]);
		  {$IFDEF SHOW_PART_TYPE}
		     printk('(%h2 (%d Mo) ', [buffer.entry[i].type_part, ((buffer.entry[i].taille_part *
		     512) div 1024) div 1024]);
		  {$ENDIF}
		  ext_no += 1;
	       end;
	    end;
	 end;
      end;
   end;
end;



{******************************************************************************
 * partition_check
 *
 * Entrée : major et minor number
 *
 * Print and registers some informations about device's partitions
 *****************************************************************************}
procedure partition_check (major, minor : byte);

var
   i, a    : byte;
   port    : word;
   buf_adr : pointer;
   index   : byte;
   base    : word;

   { This variables are going to contain informations about analysed 
     partition }
   boot      : byte;    { 00:not active, 80h:boot partition }
   part_type : byte;    {* Partition type (Linux, DOS, Zindows, etc ...
                         * -> May be DelphineOS ! Bubule *}
   size      : dword;   { Number of sectors in this partition }
   min       : byte;
   buffer    : partition_table;

begin

   printk(' Partition check: ', []);

   { First read the first sector to get the partition table }

   min := minor div 64;

   base := drive_info[major, min].IO_base;
   outb(base + NRSECT_REG, 1);    { Read 1 sector }
   outb(base + SECTOR_REG, 1);    { Sector number }
   outb(base + CYL_LSB_REG, 0);   { Cylinder number (LSB) }
   outb(base + CYL_MSB_REG, 0);   { Cylinder number (MSB) }
   outb(base + DRIVE_HEAD_REG, drive[min]);    { Head 0 }
   outb(base + CMD_REG, WIN_READ);             { Read sector command }

   if (not drive_error(major, minor))
       and data_ready(major, minor) then
   begin
      { Data is ready, no error }
      port    := base;
      buf_adr := addr(buffer);

      asm
         mov   edi, buf_adr
         mov   dx , port
         mov   ecx, 256
         cld
         @read_data_loop:
             in    ax , dx
             stosw
         loop @read_data_loop
      end; { -> asm }
   end
   else
      printk('partition_check: cannot read sector\n', []);

   { Verify 'magic word' to know if the partition table is valid }
   if (buffer.magic_word = $AA55) then
   begin
      for i := 1 to 4 do
      begin
         if (buffer.entry[i].type_part <> 0) then
	 begin
	    drive_info[major, min].part[i].p_begin := buffer.entry[i].dist_sec;
	    drive_info[major, min].part[i].p_size  := buffer.entry[i].taille_part;
            drive_info[major, min].part[i].p_type  := buffer.entry[i].type_part;
	    printk(hd_str[major, min], []);
            printk('%d ', [i]);
	    {$IFDEF SHOW_PART_TYPE}
      	       printk('(%h2 (%d Mo)) ', [buffer.entry[i].type_part, ((buffer.entry[i].taille_part *
      	       512) div 1024) div 1024]);
	    {$ENDIF}

            case (buffer.entry[i].type_part) of
               $5 : begin
	               printk('< ', []);
		       extended_part(major, minor, drive_info[major, min].part[i].p_begin);
		       printk('> ', []);
		    end;
               $F : begin
		       printk('< ', []);
		       extended_part(major, minor, drive_info[major, min].part[i].p_begin);
		       printk('> ', []);
		    end;
            end; { case }
         end; { -> then }

      end; { -> for }

   end { -> then }
   else
   begin
      printk('bad partition table', []);
   end; { if (buffer.magic_word = $AA55) }

   printk('\n', []);

end; { -> procedure }




{******************************************************************************
 * print_ide_info
 *
 * Input : command, major and minor number
 *
 * Print some informations about the device.
 * Parameter 'command' is here to know if it is an ATA or an ATAPI device so
 * that we can register infos in the right place.
 *****************************************************************************}
procedure print_ide_info(command : byte ; major, minor : byte);

var
   b : dword;
   a : word;
   i : byte;
   j : char;
   LBA_disk : boolean;
   min : byte;

begin
    { First print the device name }
    for i := 1 to 40 do
    begin
        j := ata_buffer.model[i+1];
        ata_buffer.model[i+1] := ata_buffer.model[i];
        ata_buffer.model[i] := j;
        i += 1; { Step is 2 }
    end;

    i   := 1;
    min := minor div 64;

    while (ata_buffer.model[i] <> ' ') do
    begin
        printk('%c', [ata_buffer.model[i]]);
        i += 1;
    end;

    while (ata_buffer.model[i] = ' ') or (i = 40) do
           i += 1;

    if (i < 40) then
        printk('%c', [#32]);

    while (ata_buffer.model[i] <> ' ') and (i < 40) do
    begin
        printk('%c', [ata_buffer.model[i]]);
        i += 1;
    end;

{ FIXME: we could use ata_buffer.max_mulsect to make read and write operations faster }
{ printk('  %d  ', [ata_buffer.max_mulsect]); }

    {* If it is an ATA device, we suppose it's a hard drive and we give it
     * type 2 *}

    if (command = ATA_IDENTIFY) then
    begin
        printk(', DISK drive', []);
        blk_dev[major].request_fn := @do_hd_request;
        drive_info[major, min].ide_type := 2;
        printk(', ', []);

        { Print hard drive size }

        { Does it support LBA ? }

        if ((ata_buffer.capability and 2) = 2) and
	     lba_capacity_is_ok(@ata_buffer) then
	begin
            { Device supports LBA }
            drive_info[major, min].ide_type := drive_info[major, min].ide_type or $80;
            printk('%d', [ata_buffer.lba_capacity div 2048]);
            printk('Mb ', []);
            drive_info[major, min].lba_sectors := ata_buffer.lba_capacity;
	    drive_info[major, min].cyls        := ata_buffer.cur_cyls;
	    drive_info[major, min].heads       := ata_buffer.cur_heads;
	    drive_info[major, min].sectors     := ata_buffer.cur_sectors;

            if (ata_buffer.buf_size <> 0) then
                printk('w/%dk cache ', [ata_buffer.buf_size div 2]);

            printk('using LBA ', []);
        end { -> then }
        else
	begin
            { Device doesn't support LBA. Et ch'a ch'est balot }
	    if (ata_buffer.cur_cyls = 0) then
	    begin
	        b := (ata_buffer.cyls *
		      ata_buffer.heads *
		      ata_buffer.sectors) div 2048;
		drive_info[major, min].cyls    := ata_buffer.cyls;
		drive_info[major, min].heads   := ata_buffer.heads;
		drive_info[major, min].sectors := ata_buffer.sectors;
	    end
	    else
	    begin
                b := (ata_buffer.cur_cyls *
                      ata_buffer.cur_heads *
                      ata_buffer.cur_sectors)
                      div 2048;
		drive_info[major, min].cyls    := ata_buffer.cur_cyls;
		drive_info[major, min].heads   := ata_buffer.cur_heads;
		drive_info[major, min].sectors := ata_buffer.cur_sectors;
	    end;
                  
            printk('%dMb', [b]);

            if (ata_buffer.buf_size <> 0) then
                printk(' w/%dk cache', [ata_buffer.buf_size div 2]);

            printk(', CHS=%d/%d/%d ', [drive_info[major, min].cyls,
                                       drive_info[major, min].heads,
                                       drive_info[major, min].sectors]);
        end; { -> if.. then.. else...}

        { Does it support 32bits I/O ? }
	if (ata_buffer.dword_io <> 0) then
	begin
	   drive_info[major, min].dword_io := 1;
	   printk('(32bits)\n', []);
	end
	else
	begin
	   drive_info[major, min].dword_io := 0;
	   printk('\n', []);
	end;

        partition_check(major, minor);

    end
    else
    begin
        {* If it is an ATAPI device, we get his type :
         * 5 : CD-ROM or DVD-ROM
         * 1 : IDE TAPE
         * 0 : IDE FLOPPY (ZIP drive) *}

        drive_info[major, min].ide_type := (ata_buffer.config shr 8) and $1F;

	case (drive_info[major, min].ide_type) of
	   0: printk(', FLOPPY drive ', []);
	   1: printk(', TAPE drive ', []);
	   5: printk(', CD/DVD-ROM drive ', []);
	   else printk(', UNKNOW drive (type=%d) ', [drive_info[major, min].ide_type]);
	end;

        if (ata_buffer.buf_size <> 0) then
            printk('w/%dk cache ', [ata_buffer.buf_size div 2]);

        { Does it support 32bits I/O ? }
	if (ata_buffer.dword_io <> 0) then
	begin
	   drive_info[major, min].dword_io := 1;
	   printk('(32bits)\n', []);
	end
	else
	begin
	   drive_info[major, min].dword_io := 0;
	   printk('\n', []);
	end;
    end;

end; { -> procedure }




{******************************************************************************
 * detect_drive
 *
 * Input : major and minor number
 *
 * Detect IDE devices
 *****************************************************************************}
procedure detect_drive (major, minor : byte);

var
   min, a     : byte;
   port, base : word;
   buf_addr   : pointer;

begin

   ext_no := 5;
   min    := minor div 64;
   base   := drive_info[major, min].IO_base;

   select_drive(major, minor);

   {$IFDEF DEBUG}
      printk('Trying to find dev %d:%d at io %h4\n', [major, minor, base]);
   {$ENDIF}

   if not drive_busy(major, minor) then
   begin
      { Send 'ATA identify' command }
      outb(base + CMD_REG, ATA_IDENTIFY);
      if not drive_busy(major, minor) then
      begin
         if (data_ready(major, minor) and not drive_error(major, minor)) then
	 { Data is ready, no error }
	 begin
	    printk(hd_str[major, min], []);
	    printk(': ', []);
	    { Get data }
	    port := base;
	    buf_addr := addr(ata_buffer);

	    asm
	       mov   edi, buf_addr
	       mov   dx , port
	       mov   ecx, 256     { Read 256 words (512 bytes) }
	       cld

	       @read_data_loop:
	          in    ax , dx
	          stosw
	       loop @read_data_loop
	    end;
		     
	    register_blkdev(major, 'hd', NIL);
	    print_ide_info(ATA_IDENTIFY, major, minor);

	 end
	 else
	 begin
	    { Send 'ATAPI identify' command }
	    outb(base + CMD_REG, ATAPI_IDENTIFY);
	    if not drive_busy(major, minor) then
	    begin
	       if (data_ready(major, minor) and not drive_error(major, minor)) then
	       begin
	          { Data is ready, no error }
	          printk(hd_str[major, min], []);
	          printk(': ', []);
		  { Get data }
		  port := base;
		  buf_addr := addr(ata_buffer);

		  asm
		     mov   edi, buf_addr
		     mov   dx , port
		     mov   ecx, 256
		     cld

		     @read_data_loop:
		        in    ax , dx
		        stosw
		     loop @read_data_loop
		  end;

		  print_ide_info(ATAPI_IDENTIFY, major, minor);

	       end;
	    end;
	 end;
      end;
   end
   else
   begin
      {$IFDEF DEBUG}
         printk('dev %d:%d is busy\n', [major, minor]);
      {$ENDIF}
   end;
end;



{******************************************************************************
 * probe_controller
 *
 * Input : ide controller base I/O address
 *
 * Output : TRUE if the controller responds else FALSE
 *
 * Function taken from Tabos written by Jan-Michael Brummer
 *****************************************************************************}
function probe_controller (io : word) : boolean;
begin

   if (io = $00) then
   begin
      result := FALSE;
      exit;
   end;

   {$IFDEF DEBUG}
      printk('Try to find an IDE controller at %h4\n', [io]);
   {$ENDIF}

   outb(io + NRSECT_REG, $55);
   outb(io + SECTOR_REG, $AA);

   asm
      nop
      nop
      nop
      nop
   end;

   if ((inb(io + NRSECT_REG) = $55) and (inb(io + SECTOR_REG) = $AA)) then
	result := TRUE
   else
        result := FALSE;

end;



{******************************************************************************
 * init_pci_ide
 *
 * Check if there is a non standard mass storage controller in the PCI devices
 * list.
 *****************************************************************************}
procedure init_pci_ide;

var
   maj             : byte;
   i, j            : dword;
   high_16         : word;
   pci_devices     : P_pci_device;
   udma_speed_flag : byte;

begin

   maj := 5;

   pci_devices := first_pci_device;
   for i := 1 to nb_pci_devices do
   begin
      if ((pci_devices^.main_class = $01) and
          (pci_devices^.sub_class  = $80)) then
      begin
         if (pci_devices^.vendor_id = $105A) and (pci_devices^.device_id = $4D38) then
	 begin
	    drive_info[maj, MASTER].IO_base := pci_devices^.io[0];
	    drive_info[maj, MASTER].irq     := pci_devices^.irq;
	    drive_info[maj, SLAVE].IO_base  := pci_devices^.io[0];
	    drive_info[maj, SLAVE].irq      := pci_devices^.irq;
	    maj += 1;
	    drive_info[maj, MASTER].IO_base := pci_devices^.io[2];
	    drive_info[maj, MASTER].irq     := pci_devices^.irq;
	    drive_info[maj, SLAVE].IO_base  := pci_devices^.io[2];
	    drive_info[maj, SLAVE].irq      := pci_devices^.irq;
	    { Try to init pdc202xx controller. Code from Linux }
	    {* high_16 := lo(pci_devices^.io[4]);
	     * udma_speed_flag := inb(high_16 + $001F);
	     * outb(high_16 + $001F, udma_speed_flag or $10);
	     * delay;
	     * outb(high_16 + $001F, udma_speed_flag and (not $10));
	     * delay;
	     * delay; *}
	    exit;
	 end
	 else
	 begin
            for j := 0 to 5 do
	    begin
	       if (probe_controller(pci_devices^.io[j])) then
	       begin
	          drive_info[maj, MASTER].IO_base := pci_devices^.io[j];
	          drive_info[maj, MASTER].irq     := pci_devices^.irq;
		  drive_info[maj, SLAVE].IO_base  := pci_devices^.io[j];
		  drive_info[maj, SLAVE].irq      := pci_devices^.irq;
		  exit;
		  {maj += 1;
		  if (maj > 6) then
		     exit;}
	       end;
	    end;
	    exit;
	 end;
      end;
      pci_devices := pci_devices^.next;
   end;
end;



{******************************************************************************
 * init_ide
 *
 * Initialize and detect IDE devices. This procedure is only called during
 * DelphineOS initialization
 *****************************************************************************}
procedure init_ide; [public, alias : 'INIT_IDE'];

var
   i, j : dword;

begin

   ide_hd_nb_intr       := 0;
   ide_hd_nb_sect_read  := 0;
   ide_hd_nb_sect_write := 0;

   memset(@drive_info, 0, sizeof(drive_info));
   drive_info[IDE0_MAJOR, MASTER].IO_base := $1F0;
   drive_info[IDE0_MAJOR, MASTER].irq     := 14;
   drive_info[IDE0_MAJOR, SLAVE].IO_base  := $1F0;
   drive_info[IDE0_MAJOR, SLAVE].irq      := 14;
   drive_info[IDE1_MAJOR, MASTER].IO_base := $170;
   drive_info[IDE1_MAJOR, MASTER].irq     := 15;
   drive_info[IDE1_MAJOR, SLAVE].IO_base  := $170;
   drive_info[IDE1_MAJOR, SLAVE].irq      := 15;
   drive_info[IDE2_MAJOR, MASTER].IO_base := $00;
   drive_info[IDE2_MAJOR, SLAVE].IO_base  := $00;
   drive_info[IDE3_MAJOR, MASTER].IO_base := $00;
   drive_info[IDE3_MAJOR, SLAVE].IO_base  := $00;

   init_pci_ide();

   do_hd := @unexpected_hd_intr;

   { We give all devices type FFh (no drive), it will be modified if a drive
     is detected }
   for i := IDE0_MAJOR to IDE3_MAJOR do
   begin
      drive_info[i, MASTER].ide_type := $FF;
      drive_info[i, SLAVE].ide_type  := $FF;
      drive_info[i, MASTER].ide_sem  := $01;
      drive_info[i, SLAVE].ide_sem   := $01;
   end;

   { Check IDE interfaces 0 and 1 (standard interfaces) }
   for i := IDE0_MAJOR to IDE1_MAJOR do
   begin
      if (probe_controller(drive_info[i, MASTER].IO_base)) then
      begin
         {$IFDEF DEBUG}
            printk('ide%d: controller at %h4, irq %d\n', [i - 3, drive_info[i, MASTER].IO_base, drive_info[i, MASTER].irq]);
	 {$ENDIF}
         detect_drive(i, 0);
	 detect_drive(i, 64);
      end;
   end;

   { Check IDE interfaces 2 and 3 (if PCI IDE controllers detected) }
   for i := IDE2_MAJOR to IDE3_MAJOR do
   begin
      if (drive_info[i, MASTER].IO_base <> 0) then
      begin
         {$IFDEF DEBUG}
            printk('ide%d: controller at %h4, irq %d\n', [i - 3, drive_info[i, MASTER].IO_base, drive_info[i, MASTER].irq]);
	 {$ENDIF}
         detect_drive(i, 0);
         detect_drive(i, 64);
       end;
    end;

   { Register detected devices }

   memset(@hd_fops, 0, sizeof(file_operations));
   hd_fops.open  := @hd_open;

   for i := IDE0_MAJOR to IDE3_MAJOR do
   begin
      if (drive_info[i, MASTER].ide_type <> $FF)
      or (drive_info[i, SLAVE].ide_type  <> $FF) then
      begin
         {$IFDEF DEBUG}
	    printk('Registering IDE controller at %h4, irq %d\n', [drive_info[i, MASTER].IO_base, drive_info[i, MASTER].irq]);
	 {$ENDIF}
         register_blkdev(i, 'hd', @hd_fops);
	 set_intr_gate(drive_info[i, MASTER].irq + 32, @hd_intr);
	 enable_IRQ(drive_info[i, MASTER].irq);
      end;
   end;

{ May be we have to reset all the controllers (software reset). Don't know. }

{   outb($3F6, 4);
   drive_busy(4, 0);
   outb($3F6, 0);
   drive_busy(4, 0);}

end; { -> procedure }



begin
end.
