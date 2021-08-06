{$IFNDEF __PROCESS__}
{$DEFINE __PROCESS__}

{$I fs.inc}
{$I mm.inc}
{$I signal.inc}


const

   { Flags used by waitpid() }
   WNOHANG   = 1;
   WUNTRACED = 2;


type

   P_tss_struct       = ^tss_struct;
   P_task_struct      = ^task_struct;
   P_pid_table_struct = ^pid_table_struct;

   tss_struct = record
      back_link, __blh   : word;
      esp0               : pointer;
      ss0, __ss0         : word;
      esp1               : dword;
      ss1, __ss1         : word;
      esp2               : dword;
      ss2, __ss2         : word;
      cr3                : pointer;
      eip                : pointer; 
      eflags             : dword;
      eax, ecx, edx, ebx : dword;
      esp, ebp           : pointer; 
      esi, edi           : dword;
      es, __es           : word;
      cs, __cs           : word;
      ss, __ss           : word;
      ds, __ds           : word;
      fs, __fs           : word;
      gs, __gs           : word;
      ldt, __ldt         : word;
      trace, bitmap      : word;
   end;

   task_struct = record
      pid            : dword;
      state          : byte;
      counter        : byte;      { Nb de ticks qu'il reste }
      tty            : byte;      { Console associée au processus ($FF si pas de console) }
      nop            : byte;
      ticks          : dword;     { Nb de ticks utilisés par le processus }
      utime, stime   : dword;
      tss_entry      : dword;     { Numero du descripteur de TSS }
      tss            : ^tss_struct;
      errno          : dword;
      ppid, uid, gid : dword;
      exit_code      : dword;
      brk            : dword;     { Last legal address for the process }
      size           : dword;     { Taille du processus en nombre de pages }
      cr3            : P_pte_t;   { Pointe vers le repertoire global de pages }
      page_table     : P_pte_t;   { Table de pages (4Mo) }
      mmap           : P_mmap_req;
      close_on_exec  : dword;     { Un bit par fichier }
      file_desc      : array[0..31] of P_file_t;
      root, pwd      : P_inode_t;
      cwd            : array[0..254] of char;
      signal         : sigset_t;  { Indique les signaux envoyés au processus }
      blocked        : sigset_t;  { Indique les signaux bloqués par le processus }
      signal_struct  : array[1..32] of sigaction;
      wait_queue     : P_wait_queue;
      p_pptr         : P_task_struct;   { Pointe sur le père }
      p_cptr         : P_task_struct;   { Pointe sur le plus jeune fils }
      p_ysptr        : P_task_struct;   { Pointe sur le processus créé APRES P par le père de P }
      p_osptr        : P_task_struct;   { Pointe sur le processus créé AVANT P par le père de P }
      next_task, prev_task : P_task_struct;
      next_run, prev_run   : P_task_struct;
   end;

   pid_table_struct = record
                         pid_nb       : array[1..1022] of ^task_struct;
			 nb_free_pids : dword;
			 next         : ^pid_table_struct;
                      end;

{$ENDIF}
