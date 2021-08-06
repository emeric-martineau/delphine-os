{******************************************************************************
 *  rtl8139.pp
 * 
 *  Gestion des cartes réseaux équipée du chipset Realtek 8139
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0 - ??/??/2001 - GaLi
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


unit rtl8139;



INTERFACE



type

   T_pci_device = record
      nb        : dword;
      bus       : dword;
      dev       : dword;
      func      : dword;
      irq       : dword;
      io        : array[0..5] of dword;
      vendor_id : dword;
      device_id : dword;
      next      : ^T_pci_device;
   end;

   P_pci_device = ^T_pci_device;


function  pci_lookup (vendorid, deviceid : dword) : P_pci_device; external;
procedure printk (format : string ; args : array of const); external;
procedure outb (port : dword ; val : byte); external;



IMPLEMENTATION



{******************************************************************************
 * init_rtl8139
 *
 * Initialise les cartes réseaux Realtek 8139. Appelée uniquement lors de
 * l'initialisation de DelphineOS.
 *****************************************************************************}
procedure init_rtl8139; [public, alias : 'INIT_RTL8139'];

var
   dev     : P_pci_device;
   io_base : dword;

begin

   dev := pci_lookup($10EC, $8139);

   if (dev = NIL) then
      begin
         exit;
      end;

   io_base := dev^.io[0];

   printk('RTL8139: %h4', [io_base]);
end;



begin
end.
