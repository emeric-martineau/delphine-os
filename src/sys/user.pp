unit user;

{ Define user mode functions which use systeme calls }


INTERFACE


procedure printf (format : string ; args : array of const);



IMPLEMENTATION



procedure mount_root; assembler;
asm
   mov   eax, 1
   int   $30
end;



function fork : dword;

begin
   asm
      mov   eax, 2
      int   $30
      mov   [ebp-4], eax
   end;
end;



function read (fd : dword ; buffer : pointer ; count : dword) : dword; assembler;
asm
   mov   edx, count
   mov   ecx, buffer
   mov   ebx, fd
   mov   eax, 3
   int   $30
end;



function write (fd : dword ; buffer : pointer ; count : dword) : dword; assembler;
asm
   mov   edx, count
   mov   ecx, buffer
   mov   ebx, fd
   mov   eax, 4
   int   $30
end;



function getpid : dword; assembler;
asm
   mov   eax, 5
   int   $30
end;



function  open (path : string ; flags, mode : dword) : dword; assembler;
asm
   mov   edx, mode
   mov   ecx, flags
   mov   ebx, path
   mov   eax, 6
   int   $30
end;



function  exec (path : string ; arg : array of const) : dword; assembler;
asm
   mov   ecx, arg
   mov   ebx, path
   mov   eax, 7
   int   $30
end;



function  lseek (fd, ofs, whence : dword) : dword; assembler;
asm
   mov   edx, whence
   mov   ecx, ofs
   mov   ebx, fd
   mov   eax, 8
   int   $30
end;



procedure printf (format : string ; args : array of const); assembler;
asm
   mov   edx, [ebp+16]
   mov   ecx, args
   mov   ebx, format
   mov   eax, 9
   int   $30
end;



procedure show_registers;

var
   r_ss, r_cs, r_ds, r_es, r_fs, r_gs : word;
   r_esp, r_ebp : dword;

begin

   asm
      mov   ax , cs
      mov   r_cs, ax
      mov   ax , ds
      mov   r_ds, ax
      mov   ax , es
      mov   r_es, ax
      mov   ax , fs
      mov   r_fs, ax
      mov   ax , gs
      mov   r_gs, ax
      mov   ax , ss
      mov   r_ss, ax
      mov   eax, esp
      mov   r_esp, eax
      mov   eax, ebp
      mov   r_ebp, eax
   end;

   printf('\nSS: %h4  ESP: %h   EBP: %h\n', [r_ss, r_esp, r_ebp]);
   printf('CS: %h4  DS: %h4  ES: %h4  FS: %h4  GS: %h4\n', [r_cs, r_ds, r_es, r_fs, r_gs]);
end;



begin
end.
