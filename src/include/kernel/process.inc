
{$IFNDEF __PROCESS__}
{$DEFINE __PROCESS__}

{$I fs.inc}
{$I mm.inc}

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
      state        : byte;
      counter      : byte;      { Nb de ticks qu'il reste }
      tty          : byte;      { Console associée au processus }
      nop          : byte;
      ticks        : dword;     { Nb de ticks utilisés par le processus }
      tss_entry    : dword;     { Numero du descripteur de TSS }
      tss          : ^tss_struct;
      errno        : dword;
      pid          : dword;
      ppid         : dword;     { PID du processus père }
      uid          : dword;
      gid          : dword;
      size         : dword;     { Taille du processus en nombre de pages }
      cr3          : P_pte_t;   { Pointe vers le repertoire global de pages }
      page_table   : P_pte_t;   { Table de pages (4Mo) }
      file_desc    : array[0..31] of P_file_t;
      root, pwd    : P_inode_t;
      next_task    : P_task_struct;
      prev_task    : P_task_struct;
      next_run     : P_task_struct;
      prev_run     : P_task_struct;
   end;

   pid_table_struct = record
                         pid_nb       : array[1..1022] of ^task_struct;
			 nb_free_pids : dword;
			 next         : ^pid_table_struct;
                      end;

{$ENDIF}
