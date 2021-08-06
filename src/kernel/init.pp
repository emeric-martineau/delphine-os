unit _init;



INTERFACE


{$I fs.inc}


function  close (fildes : dword) : dword;
function  dup (fildes : dword) : dword;
function  exec (path : string ; arg : array of const) : dword;
function  fork : dword;
procedure mount_root;
function  open (path : string ; flags, mode : dword) : dword;
function  pause : dword;
function  waitpid (pid : dword ; status : pointer ; options : dword) : dword;
function  write (fd : dword ; buf : string ; count : dword) : dword;


function  read (fd : dword ; buf : pointer ; count : dword) : dword;


IMPLEMENTATION


const

   WNOHANG = 1;


{******************************************************************************
 * init
 *
 * This procedure is the first user mode process written in pascal
 *****************************************************************************}
procedure init; [public, alias : 'INIT'];

var
   fd  : dword;
   res : longint;
   str : dword;   { For keyboard debugging }

begin

   asm
      mov   eax, $2B
      mov   ds , ax
      mov   es , ax
      mov   fs , ax
      mov   gs , ax
   end;

   if (fork > 0) then
   { This is the idle process }
      begin
	 while (true) do
	    begin
	       res := waitpid(-1, NIL, WNOHANG);
	       if (res > 0) then
	       begin
	          {write(fd, 'INIT: a zombie was killed.'#10, 27);}
	       end;
	       pause();
	    end;
      end
   else
      begin
         mount_root();
         open('/dev/keyb', O_RDONLY, 0);
         fd := open('/dev/tty0', O_WRONLY, 0);
         dup(fd);
	 {read(0, @str, 2000);}   { For keyboard debugging }
         exec('/sbin/init', [NIL]);
	 write(fd, #10'Can''t find /sbin/init. System halted.', 38);
         while (true) do
            begin
            end;
       end;
end;



function  close (fildes : dword) : dword; assembler;
asm
   mov   ebx, fildes
   mov   eax, 6
   int   $30
end;



function  dup (fildes : dword) : dword; assembler;
asm
   mov   ebx, fildes
   mov   eax, 41
   int   $30
end;



function exec (path : string ; arg : array of const) : dword; assembler;
asm
   lea   edx, [ebp + 16]   { No environment varibales }
   lea   ecx, [ebp + 16]   { No arguments }
   mov   ebx, path
   inc   ebx
   mov   eax, 11
   int   $30
end;



procedure mount_root; assembler;
asm
   mov   eax, 0
   int   $30
end;



function fork : dword; assembler;
asm
   mov   eax, 2
   int   $30
end;



function  read (fd : dword ; buf : pointer ; count : dword) : dword; assembler;
asm
   mov   edx, count
   mov   ecx, buf
   inc   ecx
   mov   ebx, fd
   mov   eax, 3
   int   $30
end;



function  write (fd : dword ; buf : string ; count : dword) : dword; assembler;
asm
   mov   edx, count
   mov   ecx, buf
   inc   ecx
   mov   ebx, fd
   mov   eax, 4
   int   $30
end;



function open (path : string ; flags, mode : dword) : dword; assembler;
asm
   mov   edx, mode
   mov   ecx, flags
   mov   ebx, path
   inc   ebx
   mov   eax, 5
   int   $30
end;



function waitpid (pid : dword ; status : pointer ; options : dword) : dword; assembler;
asm
   mov   edx, options
   mov   ecx, status
   mov   ebx, pid
   mov   eax, 7
   int   $30
end;



function pause : dword; assembler;
asm
   mov   eax, 29
   int   $30
end;



begin
end.
