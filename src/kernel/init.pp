unit _init;



INTERFACE


{$I fs.inc}


function  dup (fildes : dword) : dword;
function  exec (path : string ; arg : array of const) : dword;
function  fork : dword;
procedure mount_root;
function  open (path : string ; flags, mode : dword) : dword;



IMPLEMENTATION



{******************************************************************************
 * init
 *
 * This procedure is the first process in user mode
 *****************************************************************************}
procedure init; [public, alias : 'INIT'];

var
   fd  : dword;
   str : dword;

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
	 open('/dev/keyb', O_RDONLY, 0);
	 fd := open('/dev/tty0', O_WRONLY, 0);
	 dup(fd);
         exec('/sash', [NIL]);
         while (true) do
            begin
            end;
       end;
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



function open (path : string ; flags, mode : dword) : dword; assembler;
asm
   mov   edx, mode
   mov   ecx, flags
   mov   ebx, path
   inc   ebx
   mov   eax, 5
   int   $30
end;



begin
end.
