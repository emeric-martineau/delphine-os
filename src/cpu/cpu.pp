{***************************************************************************** 
 *  cpu.pp
 *
 *  CPU detection.
 *
 *  NOTE : Only Intel and AMD CPU are supported.
 *
 *  Copyleft 2002 GaLi
 *
 *  version 0.1 - ??/??/2001 - GaLi - Initial version
 *
 *  Mise en forme du code source : Bubule, GaLi
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}

unit cpu;


INTERFACE


function  inb  (port : word) : byte; external;
procedure outb (port : word ; val  : byte); external;
procedure printk (format : string ; args : array of const); external;


procedure cpuspeed;
procedure cpuinfo;


var
   fpu_present : boolean;



IMPLEMENTATION



const
   INTEL_STR = $756E6547;
   AMD_STR   = $68747541;


var
   id_str   : dword;
   family   : dword;
   features : dword;
   speed    : word;
   tenth    : word;



{******************************************************************************
 * check_fpu
 *****************************************************************************}
function check_fpu : boolean;

var
   val : byte;

begin

   outb($70, $14);
   val := inb($71);
   if (val and $02 <> $00) then
       result := TRUE
   else
       result := FALSE;

end;



{******************************************************************************
 * cpuspeed
 *
 * This function is taken from chkcpu v1.8 written by Jan Steunebrink
 * who told me I can use his source code. Source code has been modified so it
 * can run with DelphineOS.
 *
 * It determines CPU speed by measuring a loop execution time. If CPU is a 
 * Pentium, the Time Stamp Counter is used.
 *****************************************************************************}
procedure cpuspeed;

var
   count_lo, count_hi : dword;
   vendor : byte;

begin
   
   speed := 0;
   tenth := 0;

   if ((features and $10) = $10)
   then begin
   { We're going to use Time Stamp Counter }
       asm
           in    al , 61h
           push  es
           pop   es              { I/O Delay }
           and   al , 0FEh       { Stop timer (gate bit off) }
           out   61h, al
           push  es
           pop   es
           mov   al , 0B0h       { Timer 2 command, mode 0 }
           out   43h, al         { Send command }
           push  es
           pop   es
           mov   al , 0FFh       { Timer set to FFFFh }
           out   42h, al         { Send LSB }
           push  es
           pop   es
           out   42h, al         { Send MSB }
           push  es
           pop   es

           { Start timer and wait 3M/6M CPU cycles }
           in    al , 61h
           push  es
           pop   es
           or    al , 1          { Start timer (gate bit on) }
           out   61h, al
           push  es
           pop   es
           rdtsc                 { Get the Time Stamp Counter }
           add   eax, 3000000
           adc   edx, 0
           cmp   family, 6
           jb    @TIMER1
           add   eax, 3000000
           adc   edx, 0

         @TIMER1:
           mov   count_lo, eax   { Save value }

           mov   count_hi, edx

         @TIMER2:
           rdtsc
           cmp   edx, count_hi   { Test if counter beyond 3M/6M }
           jb    @TIMER2
           cmp   eax, count_lo
           jb    @TIMER2         { If not, loop }

           { TSC is beyond 3M/6M, cleaning and calculate CPU speed }

           in    al , 61h
           push  es
           pop   es
           and   al , 0FEh       { Stop timer }
           out   61h, al
           push  es
           pop   es
           mov   al , 80h        { latch output timer 2 }
           out   43h, al
           push  es
           pop   es
           in    al , 42h        { Get LSB }
           push  es
           pop   es
           mov   dl , al
           in    al , 42h        { Get MSB }
           push  es
           pop   es
           mov   dh , al         { DX = timer 2 value }

           mov   cx , -1
           sub   cx , dx         { CX = duration }
           xor   ax , ax
           xor   dx , dx
           cmp   cx , 110
           jb    @CPUS_SKP
           mov   ax , 11932
           mov   bx , 300
           cmp   family, 6
           jb    @TIMER3
           add   bx , 300

        @TIMER3:
           mul   bx
           div   cx

           push  ax
           push  bx
           mov   ax , dx
           mov   bx , 10
           mul   bx
           div   cx
           mov   dx , ax
           pop   bx
           pop   ax

        @CPUS_SKP:
           mov   speed, ax
           mov   tenth, dx
       end ; { -> asm }

       printk('at %d', [speed]);

       if (tenth <> 0)
       then begin
           printk('.%d', [tenth]) ;
       end ;

       printk(' Mhz', []);
   end { -> then }
   else begin
       case (id_str) of
           INTEL_STR : vendor := 1 ;
           AMD_STR   : vendor := 2 ;
           else        vendor := 0 ;
       end ; { -> case }

       asm
           jmp   @begin_chk

           { Unknown CPU timing (0) }
           @type0:   dw     1, 10848    { 8088 - loop duration, factor adjust }
                     dw     1, 10848    { 80186 (5Mhz = ~8345 ticks) }
                     dw     2, 3234     { 80286 (12Mhz = ~1035 ticks) }
                     dw    10, 16200    { 80386 (33Mhz = ~1917 ticks) }
                     dw    10, 16550    { 80486 (33Mhz = ~2006 ticks) }
                     dw    20, 34318    { Pentium (60 Mhz = ~2269 tick) }
                     dw    40, 61775    { PentiumPro/II/III (300Mhz = ~823 ticks) }
                     dw    15, 60900    { Pentium 4 (1400Mhz = ~174 ticks) }
        
           { Intel CPU timing (1) }
           @type1:   dw     1, 10848    { 8088 - loop duration, factor adjust }
                     dw     1, 10848    { 80186 (5Mhz = ~8345 ticks) }
                     dw     2, 3234     { 80286 (12Mhz = ~1035 ticks) }
                     dw    10, 16200    { 80386 (33Mhz = ~1917 ticks) }
                     dw    10, 16550    { 80486 (33Mhz = ~2006 ticks) }
                     dw    20, 34318    { Pentium (60 Mhz = ~2269 ticks) }
                     dw    40, 61775    { PentiumPro/II/III (300Mhz = ~823 ticks) }
                     dw    15, 60900    { Pentium 4 (1400Mhz = ~174 ticks) }

           { AMD CPU timing (2) }
           @type2:   dw     1, 10848    { 8088 - loop duration, factor adjust }
                     dw     1, 10848    { 80186 (5Mhz = ~8345 ticks) }
                     dw     2, 3234     { 80286 (12Mhz = ~1035 ticks) }
                     dw    10, 16200    { 80386 (33Mhz = ~1917 ticks) }
                     dw    10, 16550    { Am486/5x86 (33Mhz = ~2006 ticks) }
                     dw    20, 34318    { K5 (60 Mhz = ~2269 ticks) }
                     dw    40, 35182    { K6 & K6-2/III (300Mhz = ~468 ticks) }
                     dw    40, 63200    { K7 (600Mhz = ~422 ticks) }

           @begin_chk:
               xor   eax, eax
               mov   ah , 32      { Size of one table (8*4) }
               mov   al , vendor
               mul   ah           { AX = table index }
               lea   esi, @type0  { Values adress }
               add   esi, eax

               mov   eax, family
               xor   ah , ah
               shl   ax , 1
               shl   ax , 1
               add   esi, eax
               xor   dx , dx      { Set decimal value to zero.. }
               mov   ax , word [esi]   { ..if timing is unknown }

               cmp   ax , 0       { Timing inconnu ? }
               je    @CPUS_SKP

               { Now, configure timer 2 to calculate execution speed } 

               mov   al , 0B0h    { Timer 2 command, mode 0 }
               out   43h, al      { Send command }
               push  es
               pop   es
               mov   al , 0FFh    { Counter = 0FFFFh }
               out   42h, al      { Send LSB to counter }
               push  es
               pop   es
               out   42h, al      { Send MSB to counter }
               push  es
               pop   es

               in    al , 61h
               push  es
               pop   es
               or    al , 1       { Set gate bit on }
               out   61h, al      { Start timer }
               xor   dx , dx
               mov   bx , 1
               mov   ax , word [esi]

               { This loop executes some divides (slow instruction) }

            @CPUS_LOOP1:
               mov   cx , 10h     { Loop 32 times }

               @CPUS_LOOP2:
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
                   div   bx
               loop  @CPUS_LOOP2
               dec   ax
               jnz   @CPUS_LOOP1

               { When loop is done, timer is stopped }

               in    al , 61h
               push  es
               pop   es
               and   al , 0FEh    { Set gate bit off }
               out   61h, al

               { Now, read timer }

               mov   al , 80h     { latch output command }
               out   43h, al      { Send command }
               push  es
               pop   es
               in    al , 42h     { Get LSB from counter }
               push  es
               pop   es
               mov   dl , al
               in    al , 42h     { Get MSB from counter }
               mov   dh , al      { DX = counter }
               mov   ax , 0FFFFh
               sub   ax , dx      { AX = duration }
               mov   cx , ax
               mov   bx , ax      { Save AX }
               mov   ax , cx
               cmp   word ptr [esi+2], 0    { No factor ajust ? }
               je    @CPUS_SKP

               mov   ax , word [esi+2]     { Get factor ajust }
               xor   dx , dx
               shl   ax , 1
               rcl   dx , 1
               shl   ax , 1
               rcl   dx , 1       { Factor * 4 }
               div   cx
           
               push  ax
               push  bx
               mov   ax , dx
               mov   bx , 10
               mul   bx
               div   cx
               mov   dx , ax
               pop   bx
               pop   ax

            @CPUS_SKP:
               mov   speed, ax
               mov   tenth, dx
       end ; { -> asm } 

       printk('at %d', [speed]);

       if (tenth <> 0)
       then begin
           printk('.%d', [tenth]) ;
       end ;

       printk(' Mhz', []) ;
   end ; { -> if }
end ; { -> procedure }



{******************************************************************************
 * cpuinfo
 *
 * CPU detection. This procedure is called during DelphineOS initialization.
 *****************************************************************************}
procedure cpuinfo; [public, alias : 'CPUINFO']; 

{ Code inspiré par celui de Bubule }

var
   cpuid_OK        : boolean;
   p6              : dword;
   cpu_type, model : dword;
   stepping        : word;

begin
   {* Determines if ID flag (bit flag) can be set to 1 or 0. If yes,
    * execute CPUID instruction *}

   fpu_present := check_fpu;

   printk('CPU: ', []);

   asm
      pushfd
      pop   eax              { Get Eflags register in EAX }
      mov   ecx, eax         { Save EAX in ECX }
      or    eax, 200000h     { Invert ID bit in Eflags }
      push  eax
      popfd
      pushfd
      pop   eax
      xor   eax,ecx
      je    @no_cpuid        { ID bit can't be changed -> can't CPUID }

      mov   byte cpuid_OK, 1
      jmp   @fin_test_cpuid

      @no_cpuid:
         mov byte cpuid_OK, 0

      @fin_test_cpuid:
   end ; { -> asm }

   if (cpuid_OK)
   then begin
       asm
           xor   eax, eax
           cpuid            { CPUID level 0 }
           mov   id_str, ebx

           xor   eax, eax
           inc   eax
           cpuid            { CPUID level 1 }
           mov   features, edx
           mov   p6 , ebx
           push  eax
           and   eax, 7000h
           shr   eax, 12
           mov   cpu_type, eax
           pop   eax
           push  eax
           and   eax, 0F00h
           shr   eax, 8
           mov   family, eax
           pop   eax
           push  eax
           and   eax, 0F0h
           shr   eax, 4
           mov   model, eax
           pop   eax
           and   eax, 0Fh
           mov   stepping, ax
       end ; { -> asm }

       if (id_str = INTEL_STR)
       then begin
           printk('Intel ', []);

           if (family = 4)
           then begin
               case (model) of
                   0 : printk('486DX ', []);
                   1 : printk('486DX 50 Mhz ', []);
                   2 : printk('486SX ', []);
                   3 : printk('486 DX/2 ', []);
                   4 : printk('486 ', []);
                   5 : printk('486 SX/2 ', []);
                   7 : printk('486 DX/2 ', []);
                   8 : printk('486 DX/4 ', []);
                   9 : printk('486 DX/4 ', []);
               end ; { -> case }
           end ; { -> then }

           if (family = 5)
           then begin
               printk('Pentium ', []);
               if ((features and $800000) = $800000)
               then begin
                   printk('MMX ', []);
               end ; { -> then }
           end; { -> then }

           if (family = 6)
           then begin
               case (p6) of
                   1  : printk('Celeron ', []);
                   2  : printk('Pentium III ', []);
                   3  : printk('Pentium III Xeon ', []);
                   8  : printk('Pentium IV ', []);
                   $E : printk('Pentium IV Xeon ', []);
               end; { -> case }
           end; { -> then }
       end; { -> then }

       if (id_str = AMD_STR)
       then begin
           printk('AMD ', []);

           if (family = 4)
           then begin
               case (model) of
                   3  : printk('486 DX/2 ', []);
                   7  : printk('486 DX/2 ', []);
                   8  : printk('486 DX/4 ', []);
                   9  : printk('486 DX/4 ', []);
                   $E : printk('586 ', []);
                   $F : printk('586 ', []);
               end; { -> case }
          end; { -> then }

          if (family = 5)
          then begin
               case (model) of
                   0  : printk('SSA5 ', []);  { ??? }
                   1  : printk('586 ', []);
                   2  : printk('586 ', []);
                   3  : printk('586 ', []);
                   6  : printk('K6 ', []);
                   7  : printk('K6 ', []);
                   8  : printk('K6-II ', []);
                   9  : printk('K6-III ', []);
                   $D : printk('K6-II+ ', []);
               end; { -> case }
           end; { -> then }

           if (family = 6)
           then begin
               case (model) of
                   1  : printk('Athlon ', []);
                   2  : printk('Athlon ', []);
                   3  : printk('Duron ', []);
                   4  : printk('Athlon ', []);
                   6  : printk('Athlon ', []);
                   7  : printk('Athlon ', []);
               end; { -> case }
           end; { -> then }
       end; { if (id_str = INTEL_STR) }

       { It's an unkown CPU (nor Intel, nor AMD) }
       if (id_str <> INTEL_STR) and (id_str <> AMD_STR)
       then begin
           printk('Mysterious (%h) ', [id_str]) ;
       end ;

       cpuspeed;      { Print CPU speed }

   end { -> if (cpuid_OK) }
   else begin
       printk('CPUID instruction not supported !!! ', []);
     
       { FIXME: if CPUID instruction isn't supported we could get CPU info with the good old tests }
     
   end;

   if (fpu_present) then
       printk(' (coprocessor detected)\n', [])
   else
       printk('\n', []);

end; { -> procedure }



{ L'astuce ! }
begin
end.
