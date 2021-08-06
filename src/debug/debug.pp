{******************************************************************************
 *  debug.pp
 *
 *  This file contains debug functions
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.3 - ??/??/2002 - GaLi - gestion de l'affichage des chiffres
 *                                    négatifs
 *
 *  version 0.2 - ??/??/2001 - GaLi - initial version
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


unit debug;


INTERFACE


{$I config.inc}
{$I fs.inc}
{$I lock.inc}
{$I major.inc}
{$I process.inc}
{$I sched.inc}
{$I tty.inc}


procedure disable_IRQ (irq : byte); external;
function  get_free_mem : dword; external;
function  get_total_mem : dword; external;
procedure outb (port : word ; val : byte); external;
procedure printk (format : string ; args : array of const); external;
procedure putc (car : char ; tty_index : byte); external;
procedure putchar (car : char); external;
procedure read_lock (rw : P_rwlock_t); external;
procedure read_unlock (rw : P_rwlock_t); external;
procedure schedule; external;



procedure delay;
procedure dump_dev;
procedure dump_mem;
procedure dump_mmap_req (t : P_task_struct);
procedure dump_task;
function  get_arg_addr (addr : dword ; t : P_task_struct) : pointer;
procedure panic (reason : string);
procedure print_args (t : P_task_struct);
procedure print_bochs (format : string ; args : array of const);
procedure print_byte (nb : byte ; tty : P_tty_struct);
procedure print_byte_bochs (nb : byte);
procedure print_byte_s (nb : byte ; tty : P_tty_struct);
procedure print_dec_byte (nb : byte ; tty : P_tty_struct);
procedure print_dec_dword (nb : dword ; tty : P_tty_struct);
procedure print_dec_dword_bochs (nb : dword);
procedure print_dec_word (nb : word ; tty : P_tty_struct);
procedure print_dword (nb : dword ; tty : P_tty_struct);
procedure print_dword_bochs (nb : dword);
procedure print_port (nb : word ; tty : P_tty_struct);
procedure print_port_bochs (nb : word);
procedure print_word (nb : word ; tty : P_tty_struct);
procedure print_word_bochs (nb : word);
procedure print_registers;



var
   chrdevs           	 : array[0..MAX_NR_CHAR_DEV] of device_struct; external name 'U_VFS_CHRDEVS';
   blkdevs           	 : array[0..MAX_NR_BLOCK_DEV] of device_struct; external name 'U_VFS_BLKDEVS';
   buffer_head_list  	 : array [1..1024] of P_buffer_head; external name 'U_BUFFER_BUFFER_HEAD_LIST';
   buffer_head_list_lock : rwlock_t; external name 'U_BUFFER_BUFFER_HEAD_LIST_LOCK';
   current_tty       	 : byte; external name 'U_TTY__CURRENT_TTY';
   first_task        	 : P_task_struct; external name 'U_PROCESS_FIRST_TASK';
   current           	 : P_task_struct; external name 'U_PROCESS_CURRENT';
   jiffies           	 : dword; external name 'U_TIME_JIFFIES';
   nr_tasks          	 : dword; external name 'U_PROCESS_NR_TASKS';
   nr_buffer_head        : dword; external name 'U_BUFFER_NR_BUFFER_HEAD';
   nr_buffer_head_dirty  : dword; external name 'U_BUFFER_NR_BUFFER_HEAD_DIRTY';
   nr_running            : dword; external name 'U_PROCESS_NR_RUNNING';
   shared_pages          : dword; external name 'U_MEM_SHARED_PAGES';
   ide_hd_nb_intr        : dword; external name 'U_IDE_HD_IDE_HD_NB_INTR';
   ide_hd_nb_sect_read   : dword; external name 'U_IDE_HD_IDE_HD_NB_SECT_READ';
   ide_hd_nb_sect_write  : dword; external name 'U_IDE_HD_IDE_HD_NB_SECT_WRITE';
   lookup_cache          : array[1..1024] of P_lookup_cache_entry; external name 'U__NAMEI_LOOKUP_CACHE';
   lookup_cache_entries  : dword; external name 'U__NAMEI_LOOKUP_CACHE_ENTRIES';
	tty                   : array[1..MAX_TTY] of P_tty_struct; external name 'U_TTY__TTY';



IMPLEMENTATION


{$I inline.inc}


const
   hex_char : array[0..15] of char = ('0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f');



{******************************************************************************
 * print_bochs
 *
 *****************************************************************************}
procedure print_bochs (format : string ; args : array of const); [public,alias : 'PRINT_BOCHS'];

var
   pos,tmp  : byte;
   num_args : dword;

begin

	pushfd();
	cli();

   pos      := 1;
   num_args := 0;

   while (format[pos] <> #0) do
   begin
		case (format[pos]) of
			'%':  begin
						pos += 1;
						case (format[pos]) of
							'c':	begin
										outb($e9, byte(args[num_args].Vchar));
										num_args += 1;
									end;
							'd':	begin
										print_dec_dword_bochs(args[num_args].Vinteger);
										num_args += 1;
									end;
							'h':	begin
										pos += 1;
										case (format[pos]) of
											'2':	begin
														print_byte_bochs(args[num_args].Vinteger);
													end;
											'3':	begin
														print_port_bochs(args[num_args].Vinteger);
													end;
											'4':	begin
														print_word_bochs(args[num_args].Vinteger);
													end;
											else
													begin
														print_dword_bochs(args[num_args].Vinteger);
														pos -= 1;
													end;
										end;
										num_args += 1;
									end;
							's':	begin
										tmp := 0;
										while (args[num_args].VString^[tmp] <> #0) do
										begin
											outb($e9, byte(args[num_args].VString^[tmp]));
											tmp += 1;
										end;
										num_args += 1;
									end;
							else
									outb($e9, byte('%'));
						end;
					end;
			'\':  begin
						pos += 1;
						if (format[pos] = 'n') then
							 outb($e9, byte(#10));
					end;
			else
				outb($e9, byte(format[pos]));
		end;
		pos += 1;
   end;

	popfd();

end;



{******************************************************************************
 * delay
 *
 * This procedure isn't used (well, I think so !!!)
 *****************************************************************************}
procedure delay; [public, alias : 'DELAY'];
begin
   asm
      mov   ecx, 600000
      @boucle:
         nop
			nop
	 		nop
	 		nop
	 		nop
	 		nop
      loop @boucle
   end;
end;



{******************************************************************************
 * print_dword
 *
 * Print a dword in hexa
 *****************************************************************************}
procedure print_dword (nb : dword ; tty : P_tty_struct); [public, alias : 'PRINT_DWORD'];

var
   car : char;
   i, decalage, tmp : byte;

begin

   putchar('0');
	putchar('x');

   for i := 7 downto 0 do

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

      putc(car, current_tty);

   end;
end;



{******************************************************************************
 * print_word
 *
 * Print in word in hexa
 *****************************************************************************}
procedure print_word (nb : word ; tty : P_tty_struct); [public, alias : 'PRINT_WORD'];

var
   car : char;
   i, decalage, tmp : byte;

begin

   putchar('0');
	putchar('x');

   for i := 3 downto 0 do

   begin

      decalage := i*4;

      asm
         mov   ax , nb
         mov   cl , decalage
	 		shr   ax , cl
	 		and   al , 0Fh
	 		mov   tmp, al
      end;

      car := hex_char[tmp];

      putc(car, current_tty);

   end;
end;



{******************************************************************************
 * print_port
 *
 * Print a I/O port in hexa (3 digits)
 *****************************************************************************}
procedure print_port (nb : word ; tty : P_tty_struct); [public, alias : 'PRINT_PORT'];

var
   car : char;
   i, decalage, tmp : byte;

begin

   putchar('0');
	putchar('x');

   for i := 2 downto 0 do

   begin

      decalage := i*4;

      asm
         mov   ax , nb
         mov   cl , decalage
	 		shr   ax , cl
	 		and   al , 0Fh
	 		mov   tmp, al
      end;

      car := hex_char[tmp];

      putc(car, current_tty);

   end;
end;



{******************************************************************************
 * print_byte
 *
 * Print a byte in hexa
 *****************************************************************************}
procedure print_byte (nb : byte ; tty : P_tty_struct); [public, alias : 'PRINT_BYTE'];

var
   car : char;
   i, decalage, tmp : byte;

begin

   putchar('0');
	putchar('x');

   for i := 1 downto 0 do

   begin

      decalage := i * 4;

      asm
         mov   al , nb
         mov   cl , decalage
	 		shr   al , cl
	 		and   al , 0Fh
	 		mov   tmp, al
      end;

      car := hex_char[tmp];

      putc(car, current_tty);

   end;
end;



{******************************************************************************
 * print_byte_s
 *
 * Print a byte in hexa (without printing '0x')
 *****************************************************************************}
procedure print_byte_s (nb : byte ; tty : P_tty_struct); [public, alias : 'PRINT_BYTE_S'];

var
   car : char;
   i, decalage, tmp : byte;

begin

   for i := 1 downto 0 do

   begin

      decalage := i * 4;

      asm
         mov   al , nb
         mov   cl , decalage
	 		shr   al , cl
	 		and   al , 0Fh
	 		mov   tmp, al
      end;

      car := hex_char[tmp];

      putc(car, current_tty);

   end;
end;



{******************************************************************************
 * print_dword_bochs
 *
 * Print a dword in hexa
 *****************************************************************************}
procedure print_dword_bochs (nb : dword); [public, alias : 'PRINT_DWORD_BOCHS'];

var
   car : char;
   i, decalage, tmp : byte;

begin

	outb($e9, byte('0'));
	outb($e9, byte('x'));

   for i := 7 downto 0 do

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

		outb($e9, byte(car));

   end;
end;



{******************************************************************************
 * print_word_bochs
 *
 * Print in word in hexa
 *****************************************************************************}
procedure print_word_bochs (nb : word); [public, alias : 'PRINT_WORD_BOCHS'];

var
   car : char;
   i, decalage, tmp : byte;

begin

	outb($e9, byte('0'));
	outb($e9, byte('x'));

   for i := 3 downto 0 do
   begin

      decalage := i*4;

      asm
         mov   ax , nb
         mov   cl , decalage
	 		shr   ax , cl
	 		and   al , 0Fh
	 		mov   tmp, al
      end;

      car := hex_char[tmp];

		outb($e9, byte(car));

   end;
end;



{******************************************************************************
 * print_port_bochs
 *
 * Print a I/O port in hexa (3 digits)
 *****************************************************************************}
procedure print_port_bochs (nb : word); [public, alias : 'PRINT_PORT_BOCHS'];

var
   car : char;
   i, decalage, tmp : byte;

begin

	outb($e9, byte('0'));
	outb($e9, byte('x'));

   for i := 2 downto 0 do

   begin

      decalage := i*4;

      asm
         mov   ax , nb
         mov   cl , decalage
	 		shr   ax , cl
	 		and   al , 0Fh
	 		mov   tmp, al
      end;

      car := hex_char[tmp];

		outb($e9, byte(car));

   end;
end;



{******************************************************************************
 * print_byte_bochs
 *
 * Print a byte in hexa
 *****************************************************************************}
procedure print_byte_bochs (nb : byte); [public, alias : 'PRINT_BYTE_BOCHS'];

var
   car : char;
   i, decalage, tmp : byte;

begin

	outb($e9, byte('0'));
	outb($e9, byte('x'));

   for i := 1 downto 0 do

   begin

      decalage := i * 4;

      asm
         mov   al , nb
         mov   cl , decalage
	 		shr   al , cl
	 		and   al , 0Fh
	 		mov   tmp, al
      end;

      car := hex_char[tmp];

		outb($e9, byte(car));

   end;
end;



{******************************************************************************
 * print_dec_dword
 *
 * Print a dword in decimal
 *****************************************************************************}
procedure print_dec_dword (nb : dword ; tty : P_tty_struct); [public, alias : 'PRINT_DEC_DWORD'];

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
		putchar('-');
	end;

   if (nb = 0) then
       putchar('0')
   else
   begin
		while (nb <> 0) do
		begin
			dec_str[i] := chr((nb mod 10) + $30);
			nb    := nb div 10;
			i     -= 1;
			compt += 1;
		end;

		if (compt <> 10) then
      begin
			dec_str[0] := chr(compt);
			for i := 1 to compt do
			begin
				dec_str[i] := dec_str[11-compt];
				compt := compt - 1;
			end;
		end
		else
			dec_str[0] := chr(10);

		for i := 1 to ord(dec_str[0]) do
			 putchar(dec_str[i]);
	end;
end;



{******************************************************************************
 * print_dec_word
 *
 * Print a word in decimal
 *****************************************************************************}
procedure print_dec_word (nb : word ; tty : P_tty_struct); [public, alias : 'PRINT_DEC_WORD'];

var
   i, compt : byte;
   dec_str  : string[5];

begin

   compt := 0;
   i     := 5;

   while (nb <> 0) do
	begin
		dec_str[i] := chr((nb mod 10) + $30);
		nb    := nb div 10;
		i     := i-1;
		compt := compt + 1;
	end;

   if (compt <> 5) then
	begin
		dec_str[0] := chr(compt);
		for i := 1 to compt do
		begin
			dec_str[i] := dec_str[6-compt];
			compt := compt - 1;
		end;
	end
   else
		dec_str[0] := chr(5);

   for i := 1 to ord(dec_str[0]) do
		 putchar(dec_str[i]);

end;



{******************************************************************************
 * print_dec_byte
 *
 * Print a byte in decimal
 *****************************************************************************}
procedure print_dec_byte (nb : byte ; tty : P_tty_struct); [public, alias : 'PRINT_DEC_BYTE'];

var
   i, compt : byte;
   dec_str  : string[3];

begin

   compt := 0;
   i     := 3;

   while (nb <> 0) do
	begin
		dec_str[i] := chr((nb mod 10) + $30);
		nb    := nb div 10;
		i     := i-1;
		compt := compt + 1;
	end;

   if (compt <> 3) then
	begin
		dec_str[0] := chr(compt);
		for i := 1 to compt do
		begin
			dec_str[i] := dec_str[4-compt];
			compt := compt - 1;
		end;
	end
   else
		dec_str[0] := chr(3);

   for i := 1 to ord(dec_str[0]) do
		 putchar(dec_str[i]);

end;



{******************************************************************************
 * print_dec_dword_bochs
 *
 * Print a dword in decimal
 *****************************************************************************}
procedure print_dec_dword_bochs (nb : dword); [public, alias : 'PRINT_DEC_DWORD_BOCHS'];

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
		outb($e9, byte('-'));
	end;

   if (nb = 0) then
       outb($e9, byte('0'))
   else
   begin
		while (nb <> 0) do
		begin
			dec_str[i] := chr((nb mod 10) + $30);
			nb    := nb div 10;
			i     -= 1;
			compt += 1;
		end;

		if (compt <> 10) then
      begin
			dec_str[0] := chr(compt);
			for i := 1 to compt do
			begin
				dec_str[i] := dec_str[11-compt];
				compt := compt - 1;
			end;
		end
		else
			dec_str[0] := chr(10);

		for i := 1 to ord(dec_str[0]) do
			 outb($e9, byte(dec_str[i]));
	end;
end;



{******************************************************************************
 * print_registers
 *
 * Print some registers
 * NOTE : it only works in kernel mode
 *****************************************************************************}
procedure print_registers; [public, alias : 'PRINT_REGISTERS'];

var
   r_cr3, r_esp, r_ebp : dword;
   r_cs, r_ds, r_es, r_fs, r_gs, r_ss: word;

begin
   asm
      mov   r_esp, esp
      mov   r_ebp, ebp
      mov   eax  , cr3
      mov   r_cr3, eax
      mov    ax  , cs
      mov   r_cs , ax
      mov    ax  , ds
      mov   r_ds , ax
      mov    ax  , es
      mov   r_es , ax
      mov    ax  , fs
      mov   r_fs , ax
      mov    ax  , gs
      mov   r_gs , ax
      mov    ax  , ss
      mov   r_ss , ax
   end;

   printk('\nCR3: %h  ESP: %h  EBP: %h\n', [r_cr3, r_esp, r_ebp]);
   printk('CS : %h4  SS : %h4  DS : %h4  ES : %h4\n', [r_cs,r_ss,r_ds,r_es]);
   printk('FS : %h4  GS : %h4\n\n', [r_fs, r_gs]);

end;



{******************************************************************************
 * dump_task
 *
 * Print infos about tasks on the system. This procedure is called when
 * someone use the 'F9' key
 *****************************************************************************}
procedure dump_task; [public, alias : 'DUMP_TASK'];
var
   task, first : P_task_struct;
   toto, save  : P_mmap_req;
	tty : byte;
   i   : dword;

begin

	pushfd();
	cli();

   asm
		mov   eax, [ebp + 92]
		mov   i  , eax
   end;

	print_bochs('\nEIP=%h\n', [i]);

   print_bochs('Running tasks: %d/%d  jiffies=%d\n', [nr_running, nr_tasks, jiffies]);

   print_bochs('Current: PID=%d\n', [current^.pid]);

   print_bochs('\n  PID PPID TTY   PAGES     BRK      STATE    TIME\n',[]);

   task  := first_task;
   first := first_task;

   repeat
      i   := 0;
		tty := 255;
		if (task^.file_desc[1] <> NIL) then
		begin
			if (task^.file_desc[1]^.inode^.rdev_maj = TTY_MAJOR) then
				 tty := task^.file_desc[1]^.inode^.rdev_min;
		end;

      print_bochs('  %d    %d    ', [task^.pid, task^.ppid]);

		if (tty = 255) then
			 print_bochs('?', [])
		else
			 print_bochs('%d', [tty]);

		print_bochs('      %d(%d)   %h  ', [task^.size, task^.real_size, task^.brk]);
	      
      case (task^.state) of
         TASK_RUNNING:         print_bochs('    R', []);
	 		TASK_INTERRUPTIBLE:   print_bochs('    S', []);
	 		TASK_UNINTERRUPTIBLE: print_bochs('    SU', []);
	 		TASK_STOPPED:         print_bochs('    s', []);
	 		TASK_ZOMBIE:          print_bochs('    Z', []);
      end;
      print_bochs('      %d  ', [task^.utime + task^.stime]);

{printk(' %h -> %h %h %h %h\n', [task, task^.prev_task, task^.next_task, task^.prev_run, task^.next_run]);}

{printk('  root: %d (%d)  pwd: %d (%d)\n', [task^.root^.ino, task^.root^.count, task^.pwd^.ino, task^.pwd^.count]);}

{      toto := task^.mmap;
      save := toto;
      if (save <> NIL) then
      begin
         repeat
            printk('%h -> %h -> %h\n',
				[toto^.prev, toto, toto^.next]);
	    i += 1;
	    toto := toto^.next;
         until (toto = save);
      end;

      print_bochs('  %d mmap requests\n\n', [i]);		}

		{ Print arguments }
		print_args(task);

      task := task^.next_task;
   until (task = first);

   print_bochs('\n', []);

	popfd();

end;



{******************************************************************************
 * dump_mmap_req
 *
 ******************************************************************************}
procedure dump_mmap_req (t : P_task_struct); [public, alias : 'DUMP_MMAP_REQ'];

var
	i : dword;
	toto, save : P_mmap_req;

begin

		print_bochs('mmap requests for PID %d\n', [t^.pid]);

		i := 0;

      toto := t^.mmap;
      save := toto;
      if (save <> NIL) then
      begin
         repeat
            print_bochs('%h -> %h -> %h\n',
				[toto^.prev, toto, toto^.next]);
	    		i += 1;
	    		toto := toto^.next;
         until (toto = save);
      end;

      print_bochs('%d mmap requests\n', [i]);
end;



{******************************************************************************
 * print_args
 *
 ******************************************************************************}
procedure print_args (t : P_task_struct);

var
	addr, nb, i : dword;
	res_addr 	: pointer;
	str_addr 	: pointer;

begin

	addr := longint(t^.arg_addr);
	res_addr := get_arg_addr(addr, t);

	nb := longint(res_addr^);

	for i := 1 to nb do
	begin

		addr += 4;
		res_addr := get_arg_addr(addr, t);

		str_addr := pointer(res_addr^);
		res_addr := get_arg_addr(longint(str_addr), t);

		print_bochs('%s ', [res_addr]);
	end;

	print_bochs('\n', []);

end;



{******************************************************************************
 * get_arg_addr
 *
 ******************************************************************************}
function get_arg_addr (addr : dword ; t : P_task_struct) : pointer;

var
   pt : P_pte_t;

begin

	pt := pointer(t^.cr3[addr div $400000] and $FFFFF000);

	result := pointer((pt[(addr and ($400000 - 1)) div 4096]) and $FFFFF000);

	result += addr and $fff;

end;



{******************************************************************************
 * dump_mem
 *
 * Print infos about memory. This procedure is called when someone use the
 * 'F10' key.
 ******************************************************************************}
procedure dump_mem;  [public, alias : 'DUMP_MEM'];

var
   i, nb : dword;

begin

	pushfd();
	cli();

   print_bochs('\nMemory: %dk/%dk - ',[get_free_mem(), get_total_mem()]);

   print_bochs('%d shared pages (%d bytes)\n', [shared_pages, shared_pages * 4096]);

   print_bochs('ide-hd: %d sectors read, %d sectors written (%d intr)\n',
					[ide_hd_nb_sect_read, ide_hd_nb_sect_write, ide_hd_nb_intr]);

   read_lock(@buffer_head_list_lock);
   nb := 0;
   for i := 1 to 1024 do
   begin
      if (buffer_head_list[i] <> NIL) then
      begin
      	 if (buffer_head_list[i]^.count <> 0) then
	     nb += 1;
      end;
   end;
   read_unlock(@buffer_head_list_lock);

   print_bochs('buffer_head_list: %d dirty, %d used, %d/%d buffers\n',
					[nr_buffer_head_dirty, nb, nr_buffer_head, BUFFER_HEAD_LIST_MAX_ENTRIES]);

   print_bochs('lookup_cache: %d/%d entries\n',
					[lookup_cache_entries, LOOKUP_CACHE_MAX_ENTRIES]);

{   for i := 1 to 1024 do
   begin
      if (lookup_cache[i] <> NIL) then
      	  printk('%d (%d)  %d (%d)\n', [lookup_cache[i]^.dir^.count,
	             	      	        lookup_cache[i]^.dir^.ino,
	             	      	        lookup_cache[i]^.res_inode^.count,
				        lookup_cache[i]^.res_inode^.ino]);
   end;}

	print_bochs('\n', []);

	popfd();

end;



{******************************************************************************
 * dump_dev
 *
 * Print infos about detected devices. This procedure is called when someone
 * use the '²' key.
 *****************************************************************************}
procedure dump_dev;  [public, alias : 'DUMP_DEV'];
var
   i : dword;

begin

	pushfd();
	cli();

   print_bochs('\n- Char Devices:\n',[]);
   for i := 0 to MAX_NR_CHAR_DEV do
      if chrdevs[i].name<>'' then
         begin
            print_bochs('   %d : %s ( ',[i, @chrdevs[i].name[1]]);
            if chrdevs[i].fops^.open <> NIL then
               print_bochs('open ',[]);
            if chrdevs[i].fops^.read <> NIL then
               print_bochs('read ',[]);
            if chrdevs[i].fops^.write <> NIL then
               print_bochs('write ',[]);
            if chrdevs[i].fops^.seek <> NIL then
               print_bochs('seek ',[]);
            if chrdevs[i].fops^.ioctl <> NIL then
               print_bochs('ioctl ',[]);
            print_bochs(')\n',[]);
         end;

   print_bochs('\n- Block Devices :\n',[]);
   for i := 0 to MAX_NR_BLOCK_DEV do
      if blkdevs[i].name<>'' then
         begin
            print_bochs('   %d : %s ( ',[i, @blkdevs[i].name[1]]);
            if blkdevs[i].fops^.open <> NIL then
               print_bochs('open ',[]);
            if blkdevs[i].fops^.read <> NIL then
               print_bochs('read ',[]);
            if blkdevs[i].fops^.write <> NIL then
               print_bochs('write ',[]);
            if blkdevs[i].fops^.seek <> NIL then
               print_bochs('seek ',[]);
            if blkdevs[i].fops^.ioctl <> NIL then
               print_bochs('ioctl ',[]);
            print_bochs(')\n',[]);
         end;

   print_bochs('\n', []);

	popfd();

end;



{******************************************************************************
 * panic
 *
 * Print a string and halt the kernel. Timer is stopped so that the scheduler
 * is not called. However, other IRQs are on.
 *****************************************************************************}
procedure panic (reason : string); [public, alias : 'PANIC'];
begin

	cli();

   printk('\n\nSystem halted (%s)', [@reason[1]]);
   disable_IRQ(0);   { Stop timer }
   asm
      sti
      @stop:
         nop
	 		nop
	 		nop
	 		nop
         hlt
      jmp @stop
   end;

end;



begin
end.
