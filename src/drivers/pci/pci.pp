{******************************************************************************
 *  pci.pp
 *
 *  Détection des périphériques PCI. Ce fichier est la traduction du fichier
 *  pci.c écrit par Jan-Michael Brummer qui est un des auteurs du système
 *  d'exploitation Tabos. Cependant, il ne fonctionnait pas correctement et je
 *  l'ai modifié afin qu'il fonctionne normalement.
 *  Les péripheriques PCI sont détectés suivant un numéro de fonction (en 
 *  autres choses compliquées). Le programme original ne testait que la 
 *  fonction 0, hors qu'il est possible que des périphériques répondent sur 
 *  d'autres numéros de fonctions. J'ai donc ajouté un peu de code pour faire
 *  cela.
 *
 *  Copyleft 2002 GaLi
 *
 *  version 0.1 - ??/??/2001 - GaLi
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

unit pci_init;


INTERFACE


{$I pci.inc}


{$DEFINE DEBUG}


{ External procedures and functions }

function  ind (port : word) : dword; external;
function  kmalloc (len : dword) : pointer; external;
procedure outd (port : word ; val : dword); external;
procedure printk (format : string ; args : array of const); external;


{ Exported variables }

var
   first_pci_device : P_pci_device;
   pci_devices      : P_pci_device; { Detected PCI devices list }
   nb_pci_devices   : dword;        { Number of detected devices }


{ Local procedures and functions }

procedure check_pci_devices;
function  pci_device_count (bus : dword) : dword;
function  pci_read_dword (bus, device, fonction, regnum : dword) : dword;
procedure scanpci (bus : dword);
procedure showvendor (id : dword);
procedure showclass (main_class, subclass : dword);


var
   actual_nb    : dword;


IMPLEMENTATION



{******************************************************************************
 * init_pci
 *
 * Check if a PCI BIOS is present by scanning the ROM from $E0000 to $100000.
 * If there is a PCI BIOS, call check_pci_devices().
 *
 * This procedure is only called during DelphineOS initialization.
 *****************************************************************************}
procedure init_pci; [public, alias : 'INIT_PCI'];

var
   base  : P_bios32;
	tmp   : ^byte;
	crc   : byte;
	i     : dword;
   found : boolean;

label again;

begin

   base           := pointer($E0000);
   found          := false;
   nb_pci_devices := 0;

   while ((found = false) and (base < pointer($100000))) do
	begin
		if (base^.magic = $5F32335F) then
		begin
			{ Verify crc }
			tmp := pointer(base);
			crc := 0;
			for i := 0 to ((base^.length * 16) - 1) do
			begin
				crc += byte(tmp^);
				tmp += 1;
			end;

			if (crc <> 0) then goto again;

			found := true;
			printk('PCI: BSD entry point at %h\n', [base^.phys_entry]);
			check_pci_devices();
			exit;
		end; { -> if }

again:
		base += 1;	{* <=> base := base + 16 bytes because base has type
						 * P_bios_32, it points to a 16 bytes structure *}

	end; { -> while }

{   printk('PCI: not on this machine !!!\n', []);}

end; { -> procedure }



{******************************************************************************
 * show_vendor
 *
 * Entrée : id
 *
 * Cherche id dans la liste des vendors et l'affiche à l'écran
 *****************************************************************************}
procedure showvendor (id : dword);

const
   nb = sizeof(vendors) div sizeof(vendor);

var
   i : dword;

begin

   for i := 1 to nb do
	begin
		if(vendors[i].id = id) then 
		begin
			printk(vendors[i].name, []);
			exit;
		end;
	end;

   printk('Unknown (%h) ', [id]);

end;



{******************************************************************************
 * showclass
 *
 * Entrée : classe, sous-classe
 *
 * Affiche la classe et la sous-classe d'un périphérique
 *****************************************************************************}
procedure showclass (main_class, subclass : dword);

const
   classes = sizeof(pci_classes) div sizeof(pci_class);
   storage_subclasses = sizeof(pci_storage_subclasses) div sizeof(pci_storage_subclass);
   network_subclasses = sizeof(pci_network_subclasses) div sizeof(pci_network_subclass);
   display_subclasses = sizeof(pci_display_subclasses) div sizeof(pci_display_subclass);
   multimedia_subclasses = sizeof(pci_multimedia_subclasses) div sizeof(pci_multimedia_subclass);
   memory_subclasses = sizeof(pci_memory_subclasses) div sizeof(pci_memory_subclass);
   bridge_subclasses = sizeof(pci_bridge_subclasses) div sizeof(pci_bridge_subclass);
   serial_subclasses = sizeof(pci_serial_subclasses) div sizeof(pci_serial_subclass);

var
   i, j : dword;

begin

   {$IFDEF DEBUG}
      printk('(class: %h2 %h2 ', [main_class, subclass]);
   {$ENDIF}

   for i := 1 to classes do
	begin
		if (pci_classes[i].id = main_class) then
		begin
			case (main_class) of
	       
			$01: { mass storage controller }
				begin
		      	for j := 1 to storage_subclasses do
		         begin
			   		if (pci_storage_subclasses[j].id = subclass) then
			      	begin
			         	printk(pci_storage_subclasses[j].name, []);
				 			exit;
			      	end;
					end;
					printk(pci_classes[i].name, []);
		   	end;

			$02: { network controller }
				begin
					for j := 1 to network_subclasses do
					begin
						if (pci_network_subclasses[j].id = subclass) then
						begin
							printk(pci_network_subclasses[j].name, []);
				 			exit;
			      	end;
					end;
					printk(pci_classes[i].name, []);
		   	end;

			$03: { display controller }
				begin
		      	for j := 1 to display_subclasses do
		         begin
			   		if (pci_display_subclasses[j].id = subclass) then
			      	begin
							printk(pci_display_subclasses[j].name, []);
				 			exit;
			      	end;
					end;
					printk(pci_classes[i].name, []);
		   	end;

			$04: { multimedia controller }
				begin
		      	for j := 1 to multimedia_subclasses do
		         begin
			   		if (pci_multimedia_subclasses[j].id = subclass) then
			      	begin
			         	printk(pci_multimedia_subclasses[j].name, []);
				 		exit;
			      	end;
					end;
					printk(pci_classes[i].name, []);
		   	end;

			$05: { memory controller }
				begin
		      	for j := 1 to memory_subclasses do
		         begin
			   		if (pci_memory_subclasses[j].id = subclass) then
			      	begin
			         	printk(pci_memory_subclasses[j].name, []);
				 			exit;
			      	end;
					end;
					printk(pci_classes[i].name, []);
		   	end;

			$06: { bridge controller }
				begin
		      	for j := 1 to bridge_subclasses do
		         begin
			   		if (pci_bridge_subclasses[j].id = subclass) then
			      	begin
			         	printk(pci_bridge_subclasses[j].name, []);
				 			exit;
			      	end;
					end;
		      	printk(pci_classes[i].name, []);
		   	end;

			$0C: { serial controller }
				begin
		      	for j := 1 to serial_subclasses do
		         begin
			   		if (pci_serial_subclasses[j].id = subclass) then
			      	begin
			         	printk(pci_serial_subclasses[j].name, []);
				 			exit;
			      	end;
					end;
					printk(pci_classes[i].name, []);
		   	end;

			else { -> Case }
				begin
		      	printk(pci_classes[i].name, []);
		   	end;
			end;
		end;
	end;
end;



{******************************************************************************
 * scanpci
 *
 * Entrée : bus
 *
 * Recherche les périphériques PCI sur le bus spécifié
 *
 * REMARQUE : Il se peut qu'un seul périphérique réponde pour toutes les
 * valeurs de func alors qu'il ne devrait répondre que pour une seule valeur.
 * La correction de ce bug est juste un bidouillage en attendant mieux (mais
 * ca marche pas mal et ca restera surement comme ca !!!)
 *****************************************************************************}
procedure scanpci (bus : dword);

var
   bug_tmp    : dword;
   dev, read  : dword;
   vendor_id  : dword;
   device_id  : dword;
   iobase, i  : dword;
   ipin, ilin : dword;
   func       : dword;
   main_class, sub_class : dword;

begin

   for dev := 0 to 31 do
	begin
		for func := 0 to 7 do
		begin
			read := pci_read_dword(bus, dev, func, PCI_CONFIG_VENDOR);
			vendor_id := read and $FFFF;
			device_id := read div 65536; { device_id := read shr 16 }

			{ Correction du bug }

			if (func = 0) then
				bug_tmp := device_id
			else if (device_id = bug_tmp) then
				break;

			{ Fin correction du bug }

			if ((vendor_id < $FFFF) and (vendor_id <> 0)) then
			begin
				{$IFDEF DEBUG}
					printk(' - ', []);
					showvendor(vendor_id);
				{$ENDIF}

				read := pci_read_dword(bus, dev, func, PCI_CONFIG_CLASS_REV);
				main_class := read div 16777216; { class := read shr 24 }
				sub_class := (read div 65536) and $FF;

				{$IFDEF DEBUG}
					showclass(main_class, sub_class);
				{$ENDIF}

				iobase := 0;

				for i := 0 to 5 do
				begin
		         read := pci_read_dword(bus, dev, func, PCI_CONFIG_BASE_ADDR_0 + i);
		         if (read and 1 = 1) then
					begin
			      	iobase := read and $FFFFFFFC;
			      	{$IFDEF DEBUG}
			         	printk(' %h', [iobase]);
			      	{$ENDIF}
			      	pci_devices^.io[i] := iobase;
			   	end;
				end;

				read := pci_read_dword(bus, dev, func, PCI_CONFIG_INTR);
				ipin := (read div 256) and $FF;
				ilin := read and $FF;
                  
				{$IFDEF DEBUG}
		   		if (ipin > 0) and (ipin < 5) and (ilin < 32) then
						printk(', irq %d', [ilin]);
				{$ENDIF}

				pci_devices^.nb         := actual_nb;
				pci_devices^.bus        := bus;
				pci_devices^.dev        := dev;
				pci_devices^.func       := func;
				pci_devices^.irq        := ilin;
				pci_devices^.vendor_id  := vendor_id;
				pci_devices^.device_id  := device_id;
				pci_devices^.main_class := main_class;
				pci_devices^.sub_class  := sub_class;

				actual_nb := actual_nb + 1;
				if (actual_nb = nb_pci_devices) then
				begin
					pci_devices^.next := NIL;
				end
				else
				begin
					pci_devices^.next := pci_devices + 1;
					pci_devices       := pci_devices + 1;
				end;

				{$IFDEF DEBUG}
					printk('\n', []);
				{$ENDIF}

			end;
		end;
	end;
end;



{******************************************************************************
 * pci_read_dword
 *
 * Entrée : bus, device, fonction, regnum
 *
 * Sortie : dword
 *
 * Lit un dword a partir d'un registre PCI
 *****************************************************************************}
function pci_read_dword (bus, device, fonction, regnum : dword) : dword;

var
   send : dword;

begin
   asm
      mov   eax, $80000000
      mov   ebx, bus
      shl   ebx, 16
      or    eax, ebx
      mov   ebx, device
      shl   ebx, 11
      or    eax, ebx
      mov   ebx, fonction
      shl   ebx, 8
      or    eax, ebx
      mov   ebx, regnum
      shl   ebx, 2
      or    eax, ebx
      mov   send, eax
   end;

   outd(PCI_CONF_PORT_INDEX, send);
   pci_read_dword := ind(PCI_CONF_PORT_DATA);

end;



{******************************************************************************
 * pci_device_count
 *
 * Entrée : bus
 *
 * Sortie : nombre de périphérique connectés sur le bus
 *
 *****************************************************************************}
function pci_device_count (bus : dword) : dword;

var
   vendor_id  : dword;
   device_id  : dword;
   dev, devs  : dword;
   func, read : dword;
   bug_tmp    : dword;

begin

   devs := 0;

   for dev := 0 to (PCI_SLOTS - 1) do
	begin
		for func := 0 to 7 do
	 	begin
			read := pci_read_dword(bus, dev, func, PCI_CONFIG_VENDOR);
	    	vendor_id := read and $FFFF;
	    	device_id := read div 65536;

	    	{ Correction du bug (voir procédure scanpci) }

	    	if (func = 0) then
				bug_tmp := device_id
	    	else if (device_id = bug_tmp) then
				break;

	    	{ Fin correction du bug }

	    	if ((vendor_id < $FFFF) and (vendor_id <> 0)) then devs += 1;
		end;
	end;

   pci_device_count := devs;

end;



{******************************************************************************
 * pci_lookup
 *
 * Input  : vendor id, device id
 *
 * Output : pci_device
 *
 * Look for a specific PCI device in the detected devices list.
 *****************************************************************************}
function pci_lookup (vendorid, deviceid : dword) : P_pci_device; [public, alias : 'PCI_LOOKUP'];

var
   dev : P_pci_device;

begin

   if (nb_pci_devices = 0 ) then
	begin
		pci_lookup := NIL;
	 	exit;
	end;

   dev := first_pci_device;

   repeat
      if ((vendorid = dev^.vendor_id) and (deviceid = dev^.device_id)) then
		begin
	    	pci_lookup := dev;
	    	exit;
	 	end;

      dev := dev^.next;

   until (dev^.next = NIL);

   pci_lookup := NIL;

end;



{******************************************************************************
 * check_pci_devices
 *
 * Detect PCI devices
 *
 * This procedure is only called during DelphineOS initialization
 *****************************************************************************}
procedure check_pci_devices;

var
   devices  : array[0..3] of dword;
   i        : dword;

begin

   for i := 0 to 3 do
	begin
		devices[i] := pci_device_count(i);
	 	nb_pci_devices := nb_pci_devices + devices[i];
	end;

   printk('PCI: ', []);

   first_pci_device := kmalloc(nb_pci_devices * sizeof(T_pci_device));
   pci_devices      := first_pci_device;
   actual_nb        := 0;

   for i := 0 to 3 do
	begin
		if (devices[i] > 0) then scanpci(i);
	end;

   printk('%d devices found\n', [actual_nb]);

end;



begin
end.
