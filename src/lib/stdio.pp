unit stdio;

{******************************************************************************
 *  stdio.pp
 * 
 *  DelphineOS stdio library. It has to define a lot of functions.
 *
 *  Functions defined (for the moment) :
 *
 *  - printf()  : NOT FINISHED
 *  - putchar() : NOT FINISHED
 *  - puts()    : NOT_FINISHED
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
{$I unistd.inc}


function printf (format : pointer ; args : array of const) : dword; cdecl;

procedure print_dec_dword (nb : dword);
procedure print_dword (nb : dword);


IMPLEMENTATION


const
   hex_char : array[0..15] of char = ('0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f');



{***********************************************************************************
 * is_digit
 *
 **********************************************************************************}
function is_digit (c : char) : boolean;
begin
   if (c >= '0') and (c <= '9') then
       result := TRUE
   else
       result := FALSE;
end;



{***********************************************************************************
 * putchar
 *
 * Writes a character to standard output
 *
 * OUTPUT : tha character written or EOF on error
 **********************************************************************************}
function putchar (c : char) : dword; cdecl;

var
   res : dword;

begin

   res := write(STDOUT_FILENO, @c, 1);
   if (res = 1) then
       result := ord(c)
   else
       result := 0;

end;



{***********************************************************************************
 * puts
 *
 * Writes a string to standard output
 *
 * OUTPUT : EOF on error; otherwise, a nonnegative value
 **********************************************************************************}
function puts (s : string) : dword; cdecl;

var
   res, nb_char, i : dword;

begin

   i       := 0;
   nb_char := 0;

   while (s[i] <> #0) do
      i += 1;

   res := write(STDOUT_FILENO, @s, nb_char);

   if (res = nb_char) then
       result := 1
   else
       result := 0;

end;



{***********************************************************************************
 * printf
 *
 * Input  : formart -> string
 *          args    -> Variables to be written
 *
 * Output : The number of characters written, or negative if an error occured
 *
 * 'format' is a character string that contains zero or more directives. Each
 * directive fetches zero or more arguments to printf(). Each directive starts with
 * the % character. After the %, the following appear in sequence :
 *
 * flags  : Zero or more of the following flags (in any order) :
 *
 *	-	Will cause this conversion to be left-justified. If the - flag is
 *              not used, the result will be rigth-justified.
 *
 *	+	The result of a signed conversion will always begin with a sign. If
 *		the + flag is not used, the result will begin with a sign only when
 *		negatives values are converted.
 *
 *	space	This is the same as + except a sapce is printed instead of a plus
 *		sign. If both the space and the + flags are used, the + wins.
 *
 *	#	The result is converted to an alternate form. The details are given
 *		below for each conversion.
 *
 * width  : An optional width field. The exact meaning depends on the conversion
 *	    being performed.
 *
 * prec   : An optional precision. The precision indicates how many digits will be
 *	    printed to the right of the decimal point. If the precision is present,
 *	    it is preceded by a decimal point (.). If the decimal point is given with
 *	    no precision, the precision is assumed to be zero. A precision argument
 *	    may be used only with the e, E, f, g, and G conversions.
 *
 * type   : An optional h, l or L. the h causes the argument to be converted to short
 *	    prior to printing. the l specifies that the argument is a long int. The L
 *	    specifies that the argument is a long double.
 *
 * format : A character that specifies the conversion to be performed.
 *
 * The conversion are given by the following table :
 *
 *         	Description			Meaning of width		Meaning of # flag
 *
 * i or d  	An int argument is      	Specifies the minimum		UNDEFINED
 *         	converted to a signed   	number of characters
 *         	decimal string          	to appear. If the value
 *				   		is smaller, padding is
 *				   		used.
 *				   		The default is 1.
 *				   		The result of printing
 *				   		zero with a width of
 *				   		zero is no characters.
 *
 * o		An unsigned int			Same as i.			Increase the precision
 *		argument is converted						to force the first digit
 *		to unsigned octal						to be zero.
 *
 * u		An unsigned int			Same as i.			UNDEFINED
 *		argument is converted
 *		to unsigned decimal
 *
 * x		An unsigned int			Same as i.			Prefix non-zero results
 *		argument is converted						with 0x.
 *		to unsigned hexadecimal.
 *		the letters abcdef are
 *		used.
 *
 * X		Same as x except the		Same as i.			Prefix non-zero results
 *		letters ABCDEF are						with 0x.
 *		used.
 *
 * f		A double argument is		Minimum number of		Print a decimal point
 *		converted to decimal		characters to appear.		even if no digits follow.
 *		notation in the			May be followed by a
 *		[-]ddd.ddd format.		period and the number
 *						of digits to print after
 *						the decimal point. If a
 *						decimal point is printed,
 *						at least one digit will
 *						appear to the left of
 *						the decimal.
 *
 * e		A double argument is		Same as f.			Same as f.
 *		converted in the style
 *		[-]ddd.ddde dd
 *		The exponent will
 *		always contain at least
 *		two digits. If the value
 *		is zero, the exponent is
 *		zero.
 *
 * E		Same as e except E is		Same as f.			Same as f.
 *		used instead of e.
 *
 * g		Same as f or e,			Same as f.			Same as f.
 *		depending on the value
 *		to be converted. The e
 *		style is used only if
 *		the exponent is less
 *		than -4 or greater than
 *		the precision.
 *
 * G		Same as g except an E		Same as f.			Same as f.
 *		is printed instead of e.
 *
 * c		An int argument is		UNDEFINED			UNDEFINED
 *		converted to an
 *		unsigned char and the
 *		resulting character is
 *		written.
 *
 * s		An int argument is		Specifies the maximum		UNDEFINED
 *		assumed to be char *.		number of characters
 *		Characters up to (but		to be written.
 *		not including) a
 *		terminating null are
 *		written.
 *
 * p		An argument must be a		UNDEFINED			UNDEFINED
 *		pointer to void. the
 *		pointer is converted to
 *		a sequence of printable
 *		characters in an
 *		implementation-defined
 *		manner. This is not very
 *		useful for a portable
 *		program.
 *
 * n		An argument should be		UNDEFINED			UNDEFINED
 *		a pointer to an integer
 *		which is written with
 *		the number of characters
 *		written to the output
 *		stream so far. Nothing
 *		is written to the output
 *		stream by this directive.
 *
 **********************************************************************************}
function printf (format : pointer ; args : array of const) : dword; cdecl;

var
   pos, digi_idx, arg : dword;
   print_arg : ^char;

begin

   pos       := 0;
   arg       := 0;
   digi_idx  := 0;
   print_arg := format;

   while (print_arg[pos] <> #0) do
   begin
      if (print_arg[pos] = '%') then
      begin
         pos += 1;
	 if (is_digit(print_arg[pos])) then
	 begin
	    digi_idx := ord(print_arg[pos]) - 48;
	    pos += 1;
	    while (is_digit(print_arg[pos])) do
	    begin
	       digi_idx := digi_idx * 10 + (ord(print_arg[pos]) - 48);
	       pos += 1;
	    end;
	 end;
	 case print_arg[pos] of
	 'c' : begin
	       end;
	 's' : begin
	       end;
	 'u' : begin
	       end;
	 'd' : begin
	       end;
	 'l' : begin
	       end;
	 'x' : begin
	       end;
	 #32 : begin
	       end;	       
	 else  begin
	       end;
	 end;
      end
      else
      begin
         if (print_arg[pos] <> '%') then
	 begin
	    digi_idx := 0;
	    putchar(print_arg[pos]);
	    pos += 1;
	 end;
      end;
   end;

end;



{******************************************************************************
 * print_dec_dword
 *
 * Print a dword in decimal
 *****************************************************************************}
procedure print_dec_dword (nb : dword);

var
   i, compt : byte;
   dec_str  : string[10];

begin

   compt := 0;
   i     := 10;

   if (nb and $80000000) = $80000000 then
      begin
         asm
	    mov   eax, nb
	    not   eax
	    inc   eax
	    mov   nb , eax
	 end;
	 {putchar('-');}
      end;

   if (nb = 0) then
      begin
         {putchar('0');}
      end
   else
      begin

         while (nb <> 0) do
            begin
               dec_str[i]:=chr((nb mod 10) + $30);
               nb    := nb div 10;
               i     := i-1;
               compt := compt + 1;
            end;

         if (compt <> 10) then
            begin
               dec_str[0] := chr(compt);
               for i:=1 to compt do
	          begin
	             dec_str[i] := dec_str[11-compt];
	             compt := compt - 1;
	          end;
            end
         else
            begin
               dec_str[0] := chr(10);
            end;

         for i:=1 to ord(dec_str[0]) do
            begin
               write(STDOUT_FILENO, @dec_str[i], 1);
            end;
      end;
end;



{******************************************************************************
 * print_dword
 *
 * Print a dword in hexa
 *****************************************************************************}
procedure print_dword (nb : dword);

var
   car : char;
   i, decalage, tmp : byte;
   test : dword;

begin

   test := $7830;
   write(STDOUT_FILENO, @test, 2);

   for i:=7 downto 0 do

   begin

      decalage := i*4;

      asm
         mov   eax, nb
         mov   cl , decalage
	 shr   eax, cl
	 and   al , 0Fh
	 mov   tmp, al
      end;

      car := hex_char[tmp];

      write(STDOUT_FILENO, @car, 1);

   end;
end;



begin
end.
