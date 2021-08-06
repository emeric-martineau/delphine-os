
{$IFNDEF __IDE__}
{$DEFINE __IDE__}


const

   MAX_NR_PART = 10;   { Number of partitions accepted by DelphineOS }

   IDE0_MAJ    = 3;
   IDE1_MAJ    = 4;
   IDE2_MAJ    = 5;
   IDE3_MAJ    = 6;


type

   partition = record
      p_type  : byte;  { Partition type }
      res1    : byte;
      res2    : byte;
      res3    : byte;
      p_begin : dword; { Partition first logical sector }
      p_size  : dword; { Partition size (number of sectors) }
   end;


   { ide_struct registers drives information }

   ide_struct = record
      ide_type    : byte;
      IO_base     : word;
      irq         : byte;     { IDE controller IRQ }
      ide_sem     : byte;     { Semaphore (not used) }
      cyls        : word;     { Nb de cylindres }
      heads       : word;     { Nb de têtes }
      sectors     : word;     { Nb de secteurs par piste }
      lba_sectors : dword;    { Nb de secteurs adressables avec le LBA }
      part        : array[1..MAX_NR_PART] of partition; 
      { Infos sur les partitions }
   end;

   { ide_struct details :

     - ide_type :   FFh -> No drive
                    82h -> Hard drive using LBA
                    05h -> CD-ROM or DVD-ROM
                    02h -> Hard drive without LBA
                    01h -> IDE TAPE
                    00h -> IDE FLOPPY (zip drive)

     cyls, heads and sectors are initialized only if drive has type 2.
  
     lba_sectors is initialized only if drive has type $82
   }

   partition_entry = record
      boot          : byte;   { Indicates if partition is bootable }
      begin_head    : byte;   { Partition first head }
      begin_sec_cyl : word;   { Partition first sector and cylinder }
      type_part     : byte;   { Partition type }
      end_head      : byte;   { Partition last head }
      end_sec_cyl   : word;   { Partition last sector and cylinder }
      dist_sec      : dword;  { 1st sector distance }
      taille_part   : dword;  { Partition size (number of sectors) }
   end;

   partition_table = record
      nop        : array[0..445] of byte;
      entry      : array[1..4]   of partition_entry;
      magic_word : word;
   end;

   { The following structure (drive_id) has been taken from Linux hdreg.h,
     it registers information returned by IDE drives 'identify' command
     (ATA-2 standard) }

   drive_id = record
      config         : word;    { obselete }
      cyls           : word;    { cylindres "physique" }
      reserved2      : word;    { reseve (word 2) }
      heads          : word;    { tetes "physique" }
      track_bytes    : word;    { octets non-formates par piste }
      sector_bytes   : word;    { octets non-formates par secteur }
      sectors        : word;    { nb de secteurs "pysique" par piste }
      vendor0        : word;    { vendor unique }
      vendor1        : word;    { vendor unique }
      vendor2        : word;    { vendor unique }
      serial_no      : array[1..20] of char;   { numero de serie. 0 = non
                                                 specifie }
      buf_type       : word;    { type du buffer }
      buf_size       : word;    { 512 byte increments; 0 = not_specified }
      ecc_bytes      : word;    { pour les commandes de lecture/ecriture
                                  longues ; 0 = non specifie }
      fw_rev         : array[1..8] of char;      { version de la firmware 
                                                   0 = non specifie }
      model          : array[1..40] of char;     { 0 = non specifie }
      max_mulsect    : byte;    { 0 = not_implemented }
      vendor3        : byte;    { vendor unique }
      dword_io       : word;    { 0 = not_implemented; 1 = implemented }
      vendor4        : byte;    { vendor unique }
      capability     : byte;    { bits 0:DMA 1:LBA 2:IORDYsw 3:IORDYsup }
      reserved50     : word;    { reserved (word 50) }
      vendor5        : byte;    { vendor unique }
      tPIO           : byte;    { 0=slow, 1=medium, 2=fast }
      vendor6        : byte;    { vendor unique }
      tDMA           : byte;    { vitesse du DMA ; 0=slow, 1=medium, 2=fast }
      field_valid    : word;    { bits 0:cur_ok 1:eide_ok }
      cur_cyls       : word;    { cylindres logiques }
      cur_heads      : word;    { tetes logique }
      cur_sectors    : word;    { secteur logique par piste }
      cur_capacity0  : word;    { nombre total de secteur logique }
      cur_capacity1  : word;    { 2 words, misaligned int }
      multsect       : byte;    { compteur secteur multiple courrant }
      multsect_valid : byte;    { quand (bit0==1) multsect is ok }
      lba_capacity   : dword;   { nombre total de secteur }
      dma_1word      : word;    { informations sur le DMA single-word}
      dma_mword      : word;    { multiple-word dma info }
      eide_pio_modes : word;    { bits 0:mode3 1:mode4 }
      eide_dma_min   : word;    { min mword dma cycle time (ns) }
      eide_dma_time  : word;    { recommended mword dma cycle time (ns) }
      eide_pio       : word;    { min cycle time (ns), no IORDY }
      eide_pio_iordy : word;    { min cycle time (ns), with IORDY }
      word69         : word;
      word70         : word;
      word71         : word;
      word72         : word;
      word73         : word;
      word74         : word;
      word75         : word;
      word76         : word;
      word77         : word;
      word78         : word;
      word79         : word;
      word80         : word;
      word81         : word;
      command_sets   : word;    { bits 0:Smart 1:Security 2:Removable 3:PM }
      word83         : word;    { bits 14:Smart Enabled 13:0 zero }
      word84         : word;
      word85         : word;
      word86         : word;
      word87         : word;
      dma_ultra      : word;
      word89         : word;
      word90         : word;
      word91         : word;
      word92         : word;
      word93         : word;
      word94         : word;
      word95         : word;
      word96         : word;
      word97         : word;
      word98         : word;
      word99         : word;
      word100        : word;
      word101        : word;
      word102        : word;
      word103        : word;
      word104        : word;
      word105        : word;
      word106        : word;
      word107        : word;
      word108        : word;
      word109        : word;
      word110        : word;
      word111        : word;
      word112        : word;
      word113        : word;
      word114        : word;
      word115        : word;
      word116        : word;
      word117        : word;
      word118        : word;
      word119        : word;
      word120        : word;
      word121        : word;
      word122        : word;
      word123        : word;
      word124        : word;
      word125        : word;
      word126        : word;
      word127        : word;
      security       : word;    { bits 0:support 1:enable 2:locked 3:frozen }
      reserved       : array[1..127] of word;
   end;

const

   MASTER = 0;
   SLAVE  = 1;

   { IDE drives commands }

   WIN_READ       = $20;
   ATA_IDENTIFY   = $EC;
   ATAPI_IDENTIFY = $A1;

   { IDE I/O ports }

   DATA_REG       = $00;
   ERR_REG        = $01;   { Read only }
   FEATURES_REG   = $01;   { Write only }
   NRSECT_REG     = $02;
   SECTOR_REG     = $03;
   CYL_LSB_REG    = $04;
   CYL_MSB_REG    = $05;
   DRIVE_HEAD_REG = $06;
   STATUS_REG     = $07;
   CMD_REG        = $07;

   { State register bits }

   ERR_STAT   = $01;
   INDEX_STAT = $02;
   ECC_STAT   = $04;
   DRQ_STAT   = $08;
   SEEK_STAT  = $10;
   WRERR_STAT = $20;
   READY_STAT = $40;
   BUSY_STAT  = $80;

{$ENDIF}
