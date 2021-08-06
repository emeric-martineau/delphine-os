{******************************************************************************
 *
 *  DelphineOS kernel initialization
 *
 *  CopyLeft (C) 2003
 *
 *  version 0.0.0a - ??/??/2001 - Bubule, Edo, GaLi - initial version
 *
 *****************************************************************************}


{$I-}


{$M 1024, 4096}


{* Todo   :-)
 * - APM Bios
 * - Mouse (COM, PS/2, USB)
 * - PCMCIA
 * - Ethernet cards
 * - Sound cards
 * - Video cards (VESA modes) *}


{$I defs.inc}
{$I mm.inc}
{$I process.inc}
{$I sched.inc }
{$I signal.inc}
{$I tty.inc}


{ External variables }

var
   pid_table   : P_pid_table_struct; external name 'U_PROCESS_PID_TABLE';
   first_task  : P_task_struct; external name 'U_PROCESS_FIRST_TASK';
   current     : P_task_struct; external name 'U_PROCESS_CURRENT';
   nr_tasks    : dword; external name 'U_PROCESS_NR_TASKS';
   nr_running  : dword; external name 'U_PROCESS_NR_RUNNING';
	first_tty   : tty_struct; external name 'U_TTY__FIRST_TTY';


var
   cr3_init, new_stack3, pt, stack_pt : P_pte_t;
   init_desc   : pointer;
   init_struct : P_task_struct;
   tss_init    : P_tss_struct;


const
	user    : ansistring = {$I%USER%};
	ktime   : ansistring = {$I%TIME%};
	target  : ansistring = {$I%FPCTARGET%};
	fpc_ver : ansistring = {$I%FPCVERSION%};


begin

   { Hardware and kernel data initialization }

   init_tty();       { Console : OK }

	printk('Compiled by %s at %s with FPC v%s (%s)\n', [user, ktime, fpc_ver, target]);

   cpuinfo();        { CPU : OK }
   init_mm();        { Memory : OK }
   init_gdt();       { GDT initialization : OK }
   init_idt();       { IDT initialization : OK }
   init_vfs();       { VFS initialization : * }
   init_pci();       { PCI detection : OK }
   init_com();       { COM ports : OK }
   init_lpt();       { LPT ports : OK }
   init_fd();        { Floppy disk : * }
   init_ide();       { IDE initialization : ~OK }
   init_keyboard();  { Keyboard initialization : OK }

   init_rtl8139_pci();   { Just for tests }
   init_rtl8139_isa();   { Just for tests }
   init_ne_isa();        { Just for tests }

   init_sched();     { Scheduler initialization : OK }

	print_bochs('\n', []);

	{* Finish first_tty initialization *}
	first_tty.buffer_keyboard := get_free_page();
	if (first_tty.buffer_keyboard = NIL) then
		 panic('cannot initialize tty1');

	memset(first_tty.buffer_keyboard, 0, 4096);


   {* We're going to launch the first task : init
    * We have to initialize all the structures 'by hand' because we are not
    * yet in user mode *}

   asm
      mov   eax, $08   { init TSS descriptor }
      ltr   ax
   end;

   nr_tasks    := 1;
   nr_running  := 1;

   new_stack3  := get_free_page();   { init user stack }
   pt          := get_free_page();
   stack_pt    := get_free_page();
   init_desc   := get_free_page();   { init we'll be loaded in this page }
   init_struct := kmalloc(sizeof(task_struct));

   if ((new_stack3 = NIL) or (pt = NIL) or (stack_pt = NIL) or
       (init_desc = NIL) or (init_struct = NIL)) then
   begin
      printk('\nNot enough memory to create init task\n', []);
      panic('kernel panic');
   end;

   { Fill init TSS }

   asm
      mov   eax, cr3        { CR3 has been initialized by init_paging() }
      mov   cr3_init, eax   { see src/mm/init_mem.pp }
   end;

   tss_init := pointer($100590);   { see devel.txt }
   init_tss(tss_init);
   tss_init^.esp0 := $2000;        { see devel.txt }
   tss_init^.esp  := $C0400000;    { see devel.txt }
   tss_init^.cr3  := cr3_init;

   { Process descriptor initialization }
   memset(init_struct, 0, sizeof(task_struct));
   init_struct^.state         := TASK_RUNNING;
   init_struct^.tss_entry     := $08;
   init_struct^.tss           := tss_init;
   init_struct^.real_size     := 1;    { Pages used by init }
   init_struct^.first_size    := 1;
   init_struct^.brk           := $C0401000;
   init_struct^.cr3           := cr3_init;
   init_struct^.exit_code     := $FFFFFFFF;

   { Set all signals to their default action }
   memset(@init_struct^.signal_struct, 0, 32 * sizeof(sigaction));

   current := init_struct;

   { Set all file descriptors as 'unused' }
   memset(@init_struct^.file_desc, 0, OPEN_MAX * sizeof(P_file_t));

   {* On va maintenant mettre à jour le répertoire global de page afin de
    * pouvoir utiliser des adresses virtuelles dans init *}

   memcpy(@init, init_desc, 4096);
   cr3_init[769] := longint(pt) or USER_PAGE;
   cr3_init[768] := longint(stack_pt) or USER_PAGE;
   memset(pt, 0, 4096);
   memset(stack_pt, 0, 4096);
   stack_pt[1023] := longint(new_stack3) or USER_PAGE;
   pt[0]          := longint(init_desc) or USER_PAGE;

   { On initialise pid_table et on enregistre init 'à la main' dans la liste
     des tâches }
   
   pid_table := get_free_page();
   memset(pid_table, 0, 1022 * 4);
   pid_table^.nb_free_pids := 1022;
   pid_table^.next         := NIL;

   first_task            := init_struct;
   first_task^.next_task := init_struct;
   first_task^.prev_task := init_struct;
   first_task^.next_run  := init_struct;
   first_task^.prev_run  := init_struct;

   init_struct^.pid      := get_new_pid();   { Returns 1 }
   pid_table^.pid_nb[1]  := init_struct;


   { We are going to launch init. We jump to user mode here }

   asm
      mov   eax, cr3
      mov   cr3, eax          { Vide le TLB du processeur }

      push  dword $00
      popfd                   { Just to be careful }

      push  dword $2B         { SS }
      push  dword BASE_ADDR   { ESP }
      push  dword $200        { EFlags }
      push  dword $23         { CS }

      sti                     {* Obligatoire sinon le 'iret' na marche pas, à
                               * moins de mettre les flags à 0
								       * C'est quand même bizarre !!! *}

      push  dword BASE_ADDR   { Virtual address at which init begins }

      iret
   end;

end.
