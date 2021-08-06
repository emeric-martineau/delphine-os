{******************************************************************************
 *  lock.pp
 *
 *  Locks management
 *
 *  Copyleft (C) 2003
 *
 *  version 0.0 - 21/11/2003 - GaLi - Initial version
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


unit lock;


INTERFACE


{$I lock.inc}


{* Local macros *}

{DEFINE DEBUG_READ_lOCK}
{DEFINE DEBUG_READ_UNlOCK}
{DEFINE DEBUG_WRITE_lOCK}
{DEFINE DEBUG_WRITE_UNlOCK}


{* External procedure and functions *}

procedure print_bochs (format : string ; args : array of const); external;
procedure printk (format : string ; args : array of const); external;
procedure schedule; external;


{* External variables *}


{* Exported variables *}


{* Procedures and functions defined in this file *}

procedure init_lock (rw : P_rwlock_t);
procedure read_lock (rw : P_rwlock_t);
procedure read_unlock (rw : P_rwlock_t);
procedure write_lock (rw : P_rwlock_t);
procedure write_unlock (rw : P_rwlock_t);



IMPLEMENTATION


{* Constants only used in THIS file *}


{* Types only used in THIS file *}


{* Variables only used in THIS file *}



{******************************************************************************
 * init_lock
 *
 * 
 *****************************************************************************}
procedure init_lock (rw : P_rwlock_t); [public, alias : 'INIT_LOCK'];
begin

	rw^.lock := 0;

end;



{******************************************************************************
 * read_lock
 *
 * 
 *****************************************************************************}
procedure read_lock (rw : P_rwlock_t); [public, alias : 'READ_LOCK'];
begin

   {$IFDEF DEBUG_READ_lOCK}
      print_bochs('read_lock: trying to lock %h (lock=%h)\n', [rw, rw^.lock]);
   {$ENDIF}

   asm
      cli
      mov   eax, rw
      inc   dword [eax]
      jns   @ok      	   { Is 'rw' write-locked ??? If not, goto @ok }
      dec   dword [eax]
      @again:
sti
call schedule
cli
      cmp   dword [eax], 0
      js    @again
      @ok:
      sti
   end;

   {$IFDEF DEBUG_READ_lOCK}
      print_bochs('read_lock: BYE (lock=%h)\n', [rw^.lock]);
   {$ENDIF}

end;



{******************************************************************************
 * read_unlock
 *
 * 
 *****************************************************************************}
procedure read_unlock (rw : P_rwlock_t); [public, alias : 'READ_UNLOCK'];
begin

   asm
      mov   eax, rw
      dec   dword [eax]
   end;

   {$IFDEF DEBUG_READ_UNlOCK}
      print_bochs('read_unlock: rw unlocked (lock=%h)\n', [rw^.lock]);
   {$ENDIF}

end;



{******************************************************************************
 * write_lock
 *
 *****************************************************************************}
procedure write_lock (rw : P_rwlock_t); [public, alias : 'WRITE_LOCK'];

{$IFDEF DEBUG_WRITE_lOCK}
var
	addr : dword;
{$ENDIF}

begin

	asm
		{$IFDEF DEBUG_WRITE_lOCK}
			mov   eax, [ebp + 4]
			mov   addr, eax
		{$ENDIF}
	end;

   {$IFDEF DEBUG_WRITE_lOCK}
      print_bochs('write_lock: trying to lock %h (lock=%h) %h\n',
						[rw, rw^.lock, addr]);
   {$ENDIF}

   asm
      cli
      mov   eax, rw
      @restart:
      bts   dword [eax], 31
      jc    @again
      test  dword [eax], $7FFFFFFF
      je    @ok
      btr   dword [eax], 31
      @again:
sti
call schedule
cli
      cmp   dword [eax], 0
      jne   @again
      jmp   @restart
      @ok:
      sti
   end;

   {$IFDEF DEBUG_WRITE_lOCK}
      print_bochs('write_lock: BYE (lock=%h)\n', [rw^.lock]);
   {$ENDIF}

end;



{******************************************************************************
 * write_unlock
 *
 *****************************************************************************}
procedure write_unlock (rw : P_rwlock_t); [public, alias : 'WRITE_UNLOCK'];

{$IFDEF DEBUG_WRITE_UNLOCK}
var
	addr : dword;
{$ENDIF}

begin

   asm
		{$IFDEF DEBUG_WRITE_UNLOCK}
			mov   eax, [ebp + 4]
			mov   addr, eax
		{$ENDIF}
      mov   eax, rw
      btr   dword [eax], 31
   end;

   {$IFDEF DEBUG_WRITE_UNLOCK}
      print_bochs('write_unlock: rw unlocked (lock=%h) %h\n', [rw^.lock, addr]);
   {$ENDIF}

end;



begin
end.
