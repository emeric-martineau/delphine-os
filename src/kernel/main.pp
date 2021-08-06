{******************************************************************************
 *
 *  DelphineOS kernel initialization
 *
 *  CopyLeft (C) 2002
 *
 *  version 0.0.0a - ??/??/2001 - Bubule, Edo, GaLi - initial version
 *
 *****************************************************************************}


{$I-}


{$M 1024, 4096}


{* Todo   :-)
 * - APM Bios
 * - Mouse (COM + PS/2)
 * - PCMCIA
 * - Ethernet cards
 * - Sound cards
 * - Video cards *}


{$I defs.inc}
{$I mm.inc}
{$I process.inc}
{$I sched.inc }


{$DEFINE UTS_RELEASE:='0.0.0d'}


{ External variables }

var
   pid_table   : P_pid_table_struct; external name 'U_PROCESS_PID_TABLE';
   first_task  : P_task_struct; external name 'U_PROCESS_FIRST_TASK';
   current     : P_task_struct; external name 'U_PROCESS_CURRENT';
   nr_tasks    : dword; external name 'U_PROCESS_NR_TASKS';
   nr_running  : dword; external name 'U_PROCESS_NR_RUNNING';


var
   cr3_init, new_stack3, page_table : P_pte_t;
   init_desc   : pointer;
   init_struct : P_task_struct;
   tss_init    : P_tss_struct;
   i           : dword;


begin

   { Hardware and kernel data initialization }

   init_tty;       { Console : OK }
   cpuinfo;        { CPU : OK }
   init_mm;        { Memory : OK }
   init_gdt;       { GDT initialization : OK }
   init_idt;       { IDT initialization : OK }
   init_vfs;       { VFS initialization : * }
   init_pci;       { PCI detection : OK }
   init_com;       { COM ports : OK }
   init_lpt;       { LPT ports : OK }
   init_fd;        { Floppy disk : * }
   init_ide;       { IDE initialization : ~OK }
   init_keyboard;  { Keyboard initialization : * }
   init_sched;     { Scheduler initialization : OK }

   printk('\nDelphineOS version %s\n\n', [UTS_RELEASE]);

   {* We're going to launch the first task : init
    * We have to initialize all the structures 'by hand' because we are not
    * yet in user mode *}

   asm
      mov   eax, $08   { init TSS descriptor }
      ltr   ax
   end;

   nr_tasks    := 1;
   nr_running  := 1;

   new_stack3  := get_free_page;   { init user stack }
   page_table  := get_free_page;
   init_desc   := get_free_page;   { init we'll be loaded in this page }
   init_struct := kmalloc(sizeof(task_struct));

   if ((new_stack3 = NIL) or (page_table = NIL) or (init_desc = NIL) or (init_struct = NIL)) then
      begin
         printk('\nNot enough memory to create init task !!!\n', []);
	 panic('kernel panic');
      end;

   { Fill init TSS }

   asm
      mov   eax, cr3        { CR3 has been initialized by init_paging() }
      mov   cr3_init, eax   { see src/mm/init_mem.pp }
   end;

   tss_init := pointer($100590);   { see readme.txt }
   init_tss(tss_init);
   tss_init^.esp0 := $2000;        { see readme.txt }
   tss_init^.esp  := $FFC01000;    { see readme.txt }
   tss_init^.cr3  := cr3_init;

   { Process descriptor initialization }
   init_struct^.state      := TASK_RUNNING;
   init_struct^.counter    := 20;   { not used }
   init_struct^.ticks      := 0;
   init_struct^.tty        := 0;    { Console used by init }
   init_struct^.tss_entry  := $08;
   init_struct^.tss        := tss_init;
   init_struct^.errno      := 0;
   init_struct^.size       := 1;    { Pages used by init }
   init_struct^.uid        := 0;
   init_struct^.gid        := 0;
   init_struct^.ppid       := 0;
   init_struct^.cr3        := cr3_init;
   init_struct^.page_table := page_table;

   current := init_struct;

   { Set all file descriptors as 'unused' }
   for i := 0 to 31 do
      begin
         init_struct^.file_desc[i] := NIL;
      end;

   {* On va maintenant mettre à jour le répertoire global de page afin de
    * pouvoir utiliser des adresses virtuelles dans init *}

   memcpy(@init, init_desc, 4096);
   cr3_init[1023] := longint(page_table) or USER_PAGE;
   page_table[0]  := longint(new_stack3) or USER_PAGE;
   page_table[1]  := longint(init_desc) or USER_PAGE;

   { On initialise pid_table et on enregistre init 'à la main' dans la liste
     des tâches }
   
   pid_table := get_free_page;
   for i := 1 to 1022 do
       pid_table^.pid_nb[i] := NIL;

   pid_table^.nb_free_pids := 1022;
   pid_table^.next         := NIL;

   first_task            := init_struct;
   first_task^.next_task := init_struct;
   first_task^.prev_task := init_struct;
   first_task^.next_run  := init_struct;
   first_task^.prev_run  := init_struct;

   init_struct^.pid      := get_new_pid;   { Return 1 }
   pid_table^.pid_nb[1]  := init_struct;

   { On va lancer init. C'est ici que l'on passe au niveau utilisateur }

   asm
      mov   eax, cr3
      mov   cr3, eax   { Vide le TLB du processeur }

      push  dword $00
      popfd            { Simple mesure de précaution }

      push  dword $2B         { SS }
      push  dword $FFC01000   { ESP }
      push  dword $200        { EFlags }
      push  dword $23         { CS }
      sti                     {* Obligatoire sinon le 'iret' na marche pas, à
                               * moins de mettre les flags à 0
			       *
			       * C'est quand même bizarre !!! *}

      push  dword $FFC01000   { Adresse virutelle ou commence init }

      iret
   end;

end.
