unit unistd;

{******************************************************************************
 *  unistd.pp
 * 
 *  DelphineOS unistd library. It has to define a lot of functions.
 *
 *  Functions defined (for the moment) :
 *
 *  - lseek() : OK ?
 *  - write() : OK ?
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0  - 24/12/2001  - GaLi - Initial version (test)
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


INTERFACE


{$DEFINE _POSIX_SOURCE}

{$I sys/types.inc}


function  write (fildes : dword ; buf : pointer ; nbyte : dword) : dword; cdecl;
function  lseek (fildes : dword ; ofs : off_t ; whence : dword) : off_t; cdecl;



IMPLEMENTATION



{******************************************************************************
 * write
 *
 * This function writes nbyte bytes from the array pointed to by buf into the
 * file associated with fildes
 *****************************************************************************}
function write (fildes : dword ; buf : pointer ; nbyte : dword) : dword; cdecl; assembler;
asm
   mov   edx, nbyte
   mov   ecx, buf
   mov   ebx, fildes
   mov   eax, 4
   int   $30
end;



{******************************************************************************
 * lseek
 *
 *****************************************************************************}
function lseek (fildes : dword ; ofs : off_t ; whence : dword) : off_t; cdecl; assembler;
asm
   mov   edx, whence
   mov   ecx, ofs
   mov   ebx, fildes
   mov   eax, 8
   int   $30
end;



begin
end.
