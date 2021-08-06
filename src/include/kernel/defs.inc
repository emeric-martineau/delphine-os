
{ Déclaration des fonctions utilisées par le noyau }

{$I mm.inc}
{$I process.inc}

procedure init_tty; external;
procedure cpuinfo; external;
procedure init_mm; external;
procedure init_ide; external;
procedure init_pci; external;
procedure init_com; external;
procedure init_lpt; external;
procedure init_idt; external;
procedure init_gdt; external;
procedure init_keyboard; external;
procedure init_fd; external;
procedure init_vfs; external;
procedure init_sched; external;
procedure init_rtl8139_pci; external;
procedure init_rtl8139_isa; external;
procedure init_ne_isa; external;

procedure init_tss (tss : P_tss_struct); external;
procedure printk (format : string ; args : array of const); external;
procedure kernel_thread (adr : pointer); external;
procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
function  kmalloc (len : dword) : pointer; external;
function  get_new_pid : dword; external;
function  get_free_page : pointer; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;



{ Les définitions suivantes sont juste pour des tests }

procedure init; external;
