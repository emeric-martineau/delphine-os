unit _init;



INTERFACE


{$I fs.inc}


function  dup (fildes : dword) : dword;
function  exec (path : string ; arg : array of const) : dword;
function  fork : dword;
function  lseek (fd, ofs, whence : dword) : dword;
procedure mount_root;
function  open (path : string ; flags, mode : dword) : dword;
procedure printf (format : string ; args : array of const);
function  read (fd : dword ; buffer : pointer ; count : dword) : dword;
function  write(fd : dword ; buffer : pointer ; count : dword) : dword;



IMPLEMENTATION



{******************************************************************************
 * init
 *
 * This procedure is the first process in user mode
 *****************************************************************************}
procedure init; [public, alias : 'INIT'];

var
   fd, res : dword;
   str     : dword;

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
	    end;
      end
   else
      begin
         mount_root;
	 fd := open('/dev/tty0', O_RDWR, 0);
	 if (fd = -1) then
             begin
                printf('Cannot open main console\n', []);
             end;
	 dup(fd);
	 dup(fd);
         exec('/test/test', []);
{	 str := $4748494A;
	 res := write(fd, @str, 4);
	 printf('write res: %d\n', [res]);
	 res := lseek(fd, 2, SEEK_CUR);
	 printf('seek res: %d\n', [res]); }
         while (true) do
            begin
            end;
       end;
end;



function  dup (fildes : dword) : dword; assembler;
asm
   mov   ebx, fildes
   mov   eax, 9
   int   $30
end;



function lseek (fd, ofs, whence : dword) : dword; assembler;
asm
   mov   edx, whence
   mov   ecx, ofs
   mov   ebx, fd
   mov   eax, 8
   int   $30
end;



function exec (path : string ; arg : array of const) : dword; assembler;
asm
   mov   edx, [ebp + 16]
   mov   ecx, arg
   mov   ebx, path
   mov   eax, 7
   int   $30
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



procedure mount_root; assembler;
asm
   mov   eax, 1
   int   $30
end;



function fork : dword; assembler;
asm
   mov   eax, 2
   int   $30
end;



function open (path : string ; flags, mode : dword) : dword; assembler;
asm
   mov   edx, mode
   mov   ecx, flags
   mov   ebx, path
   mov   eax, 6
   int   $30
end;



procedure printf (format : string ; args : array of const); assembler;
asm
   mov   edx, [ebp + 16]
   mov   ecx, args
   mov   ebx, format
   mov   eax, 10
   int   $30
end;



begin
end.
