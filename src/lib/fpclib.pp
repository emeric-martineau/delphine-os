unit fpclib;

{******************************************************************************
 *  stdio.pp
 * 
 *  DelphineOS fpc library. It has to define a lot of functions that are used
 *  by the Free Pascal Compiler.
 *
 *  Functions defined (for the moment) :
 *
 *  - FPC_SHORTSTR_COPY   : OK
 *  - FPC_INITIALIZEUNITS : NOT DONE
 *  - FPC_DO_EXIT         : NOT DONE
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0  - 24/12/2001  - GaLi - Initial version
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



IMPLEMENTATION



{***********************************************************************************
 * int_strcopy
 *
 * Input  : string length, pointer to source and destination strings
 * Output : None
 *
 * This procedure is ONLY used by the Free Pascal Compiler
 **********************************************************************************}
procedure int_strcopy (len : dword ; sstr, dstr : pointer); assembler; [public, alias : 'FPC_SHORTSTR_COPY'];
asm
   push   eax
   push   ecx
   cld

   mov    edi, dstr
   mov    esi, sstr
   mov    ecx, len
   rep    movsb

   pop    ecx
   pop    eax
end;



{******************************************************************************
 * init
 *
 * This procedure is ONLY used by the FreePascal Compiler
 *****************************************************************************}
procedure initialize_units; [public, alias : 'FPC_INITIALIZEUNITS'];
begin
end;



{******************************************************************************
 * do_exit
 *
 * This procedure is used by the FreePascal Compiler
 *****************************************************************************}
procedure do_exit; [public, alias : 'FPC_DO_EXIT'];
begin
end;



begin
end.
