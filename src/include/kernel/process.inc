{$IFNDEF __PROCESS__}
{$DEFINE __PROCESS__}

{$I fs.inc}
{$I mm.inc}
{$I signal.inc}


const

   MAX_ARG_PAGES = 32;

   { Flags used by waitpid() }
   WNOHANG   = 1;
   WUNTRACED = 2;

   BASE_ADDR = $C0400000;
	TASK_SIZE = 1024 * 1024 * 1024;   { 1 Go }

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
      pid            	: dword;
      state, nop     	: byte;

		first_time_slice	: byte;
		time_slice			: byte;

      utime, stime   	: dword; 	 { Nb de ticks utilisés par le processus }

      tss_entry      	: dword;     { Numero du descripteur de TSS }
      tss            	: ^tss_struct;

      ppid, uid, gid 	: dword;

      exit_code      	: dword;

      end_code       	: dword; 	  { Those values are... }
      end_data       	: dword; 	  { ...page-aligned }

		arg_addr 			: pointer;	 { Process arguments address }

      brk            	: dword;     { Process last legal address + 1 }
      first_size     	: dword;     { Original nb of pages the process uses }
		real_size			: dword; 	 { Current nb of pages the process uses }
      size           	: dword;     { Current nb of pages the process uses }
      cr3            	: P_pte_t;   { Pointe vers le repertoire global de pages }

      mmap           	: P_mmap_req;

      close_on_exec  	: dword;     { One bit for each file descriptor }
      umask          	: dword;
      file_desc      	: array[0..31] of P_file_t;
      root, pwd      	: P_inode_t;
      cwd            	: array[0..254] of char;

      signal         	: sigset_t;  { Indique les signaux envoyés au processus }
      blocked        	: sigset_t;  { Indique les signaux bloqués par le processus }
      signal_struct  	: array[1..32] of sigaction;

      executable     	: P_inode_t;

      timeout        	: longint;   { Number of ticks we have to sleep }
      alarm          	: dword;

      wait_queue     	: P_wait_queue;

      p_pptr         	: P_task_struct;   { Pointe sur le père }
      p_cptr         	: P_task_struct;   { Pointe sur le plus jeune fils }
      p_ysptr        	: P_task_struct;   { Pointe sur le processus créé APRES P par le père de P }
      p_osptr        	: P_task_struct;   { Pointe sur le processus créé AVANT P par le père de P }

      next_task, prev_task : P_task_struct;
      next_run, prev_run   : P_task_struct;

   end;

   pid_table_struct = record
		pid_nb       : array[1..1022] of ^task_struct;
		nb_free_pids : dword;
		next         : ^pid_table_struct;
	end;

{$ENDIF}
