s = ./src
b = ./src/boot
flags =-Fi./src/include/kernel -Sh -Cn -Sc -S2 -OGr -Sm -Un -a -Aas -Rintel -vwnh
lib_flags =-Fi./src/include -Fi./src/include/sys -S2 -Sc -Rintel -CX -OGr -vwnh

kernel: ${b}/setup ${s}/kernel/main.o ${s}/kernel/start.o ${s}/kernel/dma.o \
        ${s}/kernel/init.o ${s}/kernel/time.o ${s}/kernel/fork.o ${s}/kernel/process.o \
	${s}/kernel/sched.o ${s}/debug/debug.o ${s}/asm/asm.o ${s}/asm/entry.o \
	${s}/mm/init_mem.o ${s}/mm/mem.o ${s}/cpu/cpu.o ${s}/gdt/gdt.o \
	${s}/drivers/char/tty.o ${s}/drivers/char/keyboard.o ${s}/drivers/char/com.o \
	${s}/drivers/char/lpt.o ${s}/drivers/block/ide.o ${s}/drivers/block/ide-hd.o \
	${s}/drivers/block/floppy.o ${s}/drivers/block/ll_rw_block.o ${s}/drivers/pci/pci.o \
	${s}/drivers/net/rtl8139.o ${s}/int/int.o ${s}/int/init_int.o \
	${s}/fs/init_vfs.o ${s}/fs/devices.o ${s}/fs/super.o ${s}/fs/open.o \
	${s}/fs/read_write.o ${s}/fs/exec.o ${s}/fs/inode.o ${s}/fs/buffer.o \
	${s}/fs/ext2/super.o ${s}/fs/ext2/file.o ${s}/fs/ext2/inode.o \
	${s}/lib/libpfpclib.a ${s}/lib/libpstdio.a ${s}/lib/libpunistd.a

	@echo Linking kernel ...
	@ld -s -o ${s}/kernel/tmpk ${s}/kernel/start.o ${s}/kernel/main.o \
         ${s}/drivers/char/tty.o ${s}/debug/debug.o ${s}/drivers/block/ide.o \
         ${s}/mm/init_mem.o ${s}/cpu/cpu.o ${s}/drivers/char/com.o \
	 ${s}/drivers/char/lpt.o ${s}/int/init_int.o ${s}/drivers/pci/pci.o \
	 ${s}/gdt/gdt.o ${s}/int/int.o ${s}/drivers/char/keyboard.o \
	 ${s}/mm/mem.o ${s}/drivers/block/floppy.o \
	 ${s}/drivers/net/rtl8139.o ${s}/fs/init_vfs.o ${s}/kernel/fork.o \
	${s}/fs/ext2/super.o ${s}/kernel/sched.o ${s}/fs/devices.o \
	${s}/fs/super.o ${s}/kernel/time.o ${s}/kernel/dma.o \
	${s}/asm/entry.o ${s}/fs/read_write.o ${s}/kernel/process.o \
	${s}/drivers/block/ide-hd.o ${s}/fs/open.o ${s}/fs/ext2/file.o \
	${s}/fs/buffer.o ${s}/drivers/block/ll_rw_block.o \
	${s}/fs/inode.o ${s}/fs/ext2/inode.o ${s}/asm/asm.o ${s}/fs/exec.o \
	${s}/kernel/init.o -T linkfile

	@cat ${b}/setup ${s}/kernel/tmpk > ${s}/kernel/kernel
	@rm ${s}/kernel/tmpk


${s}/kernel/main.o: ${s}/kernel/main.pp
	@echo Compiling kernel/main.pp
	@ppc386 $(flags) ${s}/kernel/main.pp
	@rm ppas.sh
	@rm link.res
	@fgrep -iv "FPC_INITIALIZEUNITS" ${s}/kernel/main.s > ${s}/kernel/tmp
	@fgrep -iv "SYSLINUX" ${s}/kernel/tmp > ${s}/kernel/k
	@fgrep -iv "FPC_DO_EXIT" ${s}/kernel/k > ${s}/kernel/tmp
	@fgrep -iv "OBJPAS" ${s}/kernel/tmp > ${s}/kernel/main.s
	@rm ${s}/kernel/tmp
	@rm ${s}/kernel/k
	@as -o ${s}/kernel/main.o ${s}/kernel/main.s

${b}/setup: ${b}/setup.S
	@echo Compiling boot/setup.S
	@a ${b}/setup.S

${s}/kernel/start.o: ${s}/kernel/start.S
	@echo Compiling boot/start.S
	@a -o ${s}/kernel/start.o ${s}/kernel/start.S -f elf

${s}/mm/init_mem.o: ${s}/mm/init_mem.pp
	@echo Compiling mm/init_mem.pp
	@ppc386 $(flags) -s ${s}/mm/init_mem.pp
	@rm ppas.sh
	@as -o ${s}/mm/init_mem.o ${s}/mm/init_mem.s

${s}/drivers/char/tty.o: ${s}/drivers/char/tty.pp
	@echo Compiling drivers/char/tty.pp
	@ppc386 $(flags) -s ${s}/drivers/char/tty.pp
	@rm ppas.sh
	@as -o ${s}/drivers/char/tty.o ${s}/drivers/char/tty.s

${s}/debug/debug.o: ${s}/debug/debug.pp
	@echo Compiling debug/debug.pp
	@ppc386 $(flags) -s ${s}/debug/debug.pp
	@rm ppas.sh
	@as -o ${s}/debug/debug.o ${s}/debug/debug.s

${s}/drivers/block/ide.o: ${s}/drivers/block/ide.pp
	@echo Compiling drivers/block/ide.pp
	@ppc386 $(flags) -s ${s}/drivers/block/ide.pp
	@rm ppas.sh
	@as -o ${s}/drivers/block/ide.o ${s}/drivers/block/ide.s

${s}/cpu/cpu.o: ${s}/cpu/cpu.pp
	@echo Compiling cpu/cpu.pp
	@ppc386 $(flags) -s ${s}/cpu/cpu.pp
	@rm ppas.sh
	@as -o ${s}/cpu/cpu.o ${s}/cpu/cpu.s

${s}/drivers/char/com.o: ${s}/drivers/char/com.pp
	@echo Compiling drivers/char/com.pp
	@ppc386 $(flags) -s ${s}/drivers/char/com.pp
	@rm ppas.sh
	@as -o ${s}/drivers/char/com.o ${s}/drivers/char/com.s

${s}/drivers/char/lpt.o: ${s}/drivers/char/lpt.pp
	@echo Compiling drivers/char/lpt.pp
	@ppc386 $(flags) -s ${s}/drivers/char/lpt.pp
	@rm ppas.sh
	@as -o ${s}/drivers/char/lpt.o ${s}/drivers/char/lpt.s

${s}/int/init_int.o: ${s}/int/init_int.pp
	@echo Compiling int/init_int.pp
	@ppc386 $(flags) -s ${s}/int/init_int.pp
	@rm ppas.sh
	@as -o ${s}/int/init_int.o ${s}/int/init_int.s

${s}/drivers/pci/pci.o: ${s}/drivers/pci/pci.pp
	@echo Compiling drivers/pci/pci.pp
	@ppc386 $(flags) -s ${s}/drivers/pci/pci.pp
	@rm ppas.sh
	@as -o ${s}/drivers/pci/pci.o ${s}/drivers/pci/pci.s

${s}/gdt/gdt.o: ${s}/gdt/gdt.pp
	@echo Compiling gdt/gdt.pp
	@ppc386 $(flags) -s ${s}/gdt/gdt.pp
	@rm ppas.sh
	@as -o ${s}/gdt/gdt.o ${s}/gdt/gdt.s

${s}/int/int.o: ${s}/int/int.pp
	@echo Compiling int/int.pp
	@ppc386 $(flags) -s ${s}/int/int.pp
	@rm ppas.sh
	@as -o ${s}/int/int.o ${s}/int/int.s

${s}/mm/mem.o: ${s}/mm/mem.pp
	@echo Compiling mm/mem.pp
	@ppc386 $(flags) -s ${s}/mm/mem.pp
	@rm ppas.sh
	@as -o ${s}/mm/mem.o ${s}/mm/mem.s

${s}/drivers/char/keyboard.o: ${s}/drivers/char/keyboard.pp
	@echo Compiling drivers/char/keyboard.pp ...
	@ppc386 $(flags) -s ${s}/drivers/char/keyboard.pp
	@rm ppas.sh
	@as -o ${s}/drivers/char/keyboard.o ${s}/drivers/char/keyboard.s

${s}/asm/asm.o: ${s}/asm/asm.pp
	@echo Compiling asm/asm.pp
	@ppc386 $(flags) -s ${s}/asm/asm.pp
	@rm ppas.sh
	@as -o ${s}/asm/asm.o ${s}/asm/asm.s

${s}/drivers/block/floppy.o: ${s}/drivers/block/floppy.pp
	@echo Compiling drivers/block/floppy.pp
	@ppc386 $(flags) -s ${s}/drivers/block/floppy.pp
	@rm ppas.sh
	@as -o ${s}/drivers/block/floppy.o ${s}/drivers/block/floppy.s

${s}/drivers/net/rtl8139.o: ${s}/drivers/net/rtl8139.pp
	@echo Compiling drivers/net/rtl8139.pp
	@ppc386 $(flags) -s ${s}/drivers/net/rtl8139.pp
	@rm ppas.sh
	@as -o ${s}/drivers/net/rtl8139.o ${s}/drivers/net/rtl8139.s

${s}/fs/init_vfs.o: ${s}/fs/init_vfs.pp
	@echo Compiling fs/init_vfs.pp
	@ppc386 $(flags) -s ${s}/fs/init_vfs.pp
	@rm ppas.sh
	@as -o ${s}/fs/init_vfs.o ${s}/fs/init_vfs.s

${s}/fs/ext2/super.o: ${s}/fs/ext2/super.pp
	@echo Compiling fs/ext2/super.pp
	@ppc386 $(flags) -s ${s}/fs/ext2/super.pp
	@rm ppas.sh
	@as -o ${s}/fs/ext2/super.o ${s}/fs/ext2/super.s

${s}/kernel/sched.o: ${s}/kernel/sched.pp
	@echo Compiling kernel/sched.pp
	@ppc386 $(flags) -s ${s}/kernel/sched.pp
	@rm ppas.sh
	@as -o ${s}/kernel/sched.o ${s}/kernel/sched.s

${s}/kernel/fork.o: ${s}/kernel/fork.pp
	@echo Compiling kernel/fork.pp
	@ppc386 $(flags) -s ${s}/kernel/fork.pp
	@rm ppas.sh
	@as -o ${s}/kernel/fork.o ${s}/kernel/fork.s

${s}/fs/devices.o: ${s}/fs/devices.pp
	@echo Compiling fs/devices.pp
	@ppc386 $(flags) -s ${s}/fs/devices.pp
	@rm ppas.sh
	@as -o ${s}/fs/devices.o ${s}/fs/devices.s

${s}/fs/super.o: ${s}/fs/super.pp
	@echo Compiling fs/super.pp
	@ppc386 $(flags) -s ${s}/fs/super.pp
	@rm ppas.sh
	@as -o ${s}/fs/super.o ${s}/fs/super.s

${s}/kernel/init.o: ${s}/kernel/init.pp
	@echo Compiling kernel/init.pp
	@ppc386 $(flags) -s ${s}/kernel/init.pp
	@rm ppas.sh
	@as -o ${s}/kernel/init.o ${s}/kernel/init.s

${s}/kernel/time.o: ${s}/kernel/time.pp
	@echo Compiling kernel/time.pp
	@ppc386 $(flags) -s ${s}/kernel/time.pp
	@rm ppas.sh
	@as -o ${s}/kernel/time.o ${s}/kernel/time.s

${s}/asm/entry.o: ${s}/asm/entry.pp
	@echo Compiling asm/entry.pp
	@ppc386 $(flags) -s ${s}/asm/entry.pp
	@rm ppas.sh
	@as -o ${s}/asm/entry.o ${s}/asm/entry.s

${s}/fs/read_write.o: ${s}/fs/read_write.pp
	@echo Compiling fs/read_write.pp
	@ppc386 $(flags) -s ${s}/fs/read_write.pp
	@rm ppas.sh
	@as -o ${s}/fs/read_write.o ${s}/fs/read_write.s

${s}/kernel/process.o: ${s}/kernel/process.pp
	@echo Compiling kernel/process.pp
	@ppc386 $(flags) -s ${s}/kernel/process.pp
	@rm ppas.sh
	@as -o ${s}/kernel/process.o ${s}/kernel/process.s

${s}/drivers/block/ide-hd.o: ${s}/drivers/block/ide-hd.pp
	@echo Compiling drivers/block/ide-hd.pp
	@ppc386 $(flags) -s ${s}/drivers/block/ide-hd.pp
	@rm ppas.sh
	@as -o ${s}/drivers/block/ide-hd.o ${s}/drivers/block/ide-hd.s

${s}/sys/libpuser.a: ${s}/sys/user.pp
	@echo Compiling sys/user.pp
	@ppc386 -CX -S2 -Og -Rintel ${s}/sys/user.pp

${s}/kernel/dma.o: ${s}/kernel/dma.pp
	@echo Compiling kernel/dma.pp
	@ppc386 $(flags) -s ${s}/kernel/dma.pp
	@rm ppas.sh
	@as -o ${s}/kernel/dma.o ${s}/kernel/dma.s

${s}/fs/buffer.o: ${s}/fs/buffer.pp
	@echo Compiling fs/buffer.pp
	@ppc386 $(flags) -s ${s}/fs/buffer.pp
	@rm ppas.sh
	@as -o ${s}/fs/buffer.o ${s}/fs/buffer.s

${s}/drivers/block/ll_rw_block.o: ${s}/drivers/block/ll_rw_block.pp
	@echo Compiling drivers/block/ll_rw_block.pp
	@ppc386 $(flags) -s ${s}/drivers/block/ll_rw_block.pp
	@rm ppas.sh
	@as -o ${s}/drivers/block/ll_rw_block.o ${s}/drivers/block/ll_rw_block.s

${s}/fs/inode.o: ${s}/fs/inode.pp
	@echo Compiling fs/inode.pp
	@ppc386 $(flags) -s ${s}/fs/inode.pp
	@rm ppas.sh
	@as -o ${s}/fs/inode.o ${s}/fs/inode.s

${s}/fs/ext2/inode.o: ${s}/fs/ext2/inode.pp
	@echo Compiling fs/ext2/inode.pp
	@ppc386 $(flags) -s ${s}/fs/ext2/inode.pp
	@rm ppas.sh
	@as -o ${s}/fs/ext2/inode.o ${s}/fs/ext2/inode.s

${s}/fs/open.o: ${s}/fs/open.pp
	@echo Compiling fs/open.pp
	@ppc386 $(flags) -s ${s}/fs/open.pp
	@rm ppas.sh
	@as -o ${s}/fs/open.o ${s}/fs/open.s

${s}/fs/ext2/file.o: ${s}/fs/ext2/file.pp
	@echo Compiling fs/ext2/file.pp
	@ppc386 $(flags) -s ${s}/fs/ext2/file.pp
	@rm ppas.sh
	@as -o ${s}/fs/ext2/file.o ${s}/fs/ext2/file.s

${s}/fs/exec.o: ${s}/fs/exec.pp
	@echo Compiling fs/exec.pp
	@ppc386 $(flags) -s ${s}/fs/exec.pp
	@rm ppas.sh
	@as -o ${s}/fs/exec.o ${s}/fs/exec.s

${s}/lib/libpfpclib.a: ${s}/lib/fpclib.pp
	@echo Compiling DelphineOS FPC library
	@ppc386 $(lib_flags) ${s}/lib/fpclib.pp

${s}/lib/libpstdio.a: ${s}/lib/stdio.pp
	@echo Compiling DelphineOS stdio library
	@ppc386 $(lib_flags) ${s}/lib/stdio.pp

${s}/lib/libpunistd.a: ${s}/lib/unistd.pp
	@echo Compiling DelphineOS unistd library
	@ppc386 $(lib_flags) ${s}/lib/unistd.pp

clean:
	@rm -f *~ mkboot mkbochs bochs/boot.img bochs/ext.img bochs/delphine.img
	@rm -f src/*~
	@rm -f src/boot/*~ src/boot/boot src/boot/setup src/boot/boot.dat
	@rm -f src/cpu/*.o src/cpu/*~ src/cpu/*.ppu src/cpu/*.s
	@rm -f src/debug/*.o src/debug/*~ src/debug/*.ppu src/debug/*.s
	@rm -f src/drivers/char/*.o src/drivers/char/*~
	@rm -f src/drivers/char/*.ppu src/drivers/char/*.s
	@rm -f src/drivers/block/*.o src/drivers/block/*~
	@rm -f src/drivers/block/*.ppu src/drivers/block/*.s
	@rm -f src/drivers/pci/*.o src/drivers/pci/*.ppu 
	@rm -f src/drivers/pci/*~ src/drivers/pci/*.s
	@rm -f src/drivers/net/*.o src/drivers/net/*.ppu
	@rm -f src/drivers/net/*~ src/drivers/net/*.s
	@rm -f src/kernel/*.o src/kernel/*~ src/kernel/kernel
	@rm -f src/kernel/*.s src/kernel/*.ppu
	@rm -f src/mm/*.o src/mm/*~ src/mm/*.ppu src/mm/*.s
	@rm -f src/gdt/*.o src/gdt/*~ src/gdt/*.ppu src/gdt/*.s
	@rm -f src/int/*.o src/int/*~ src/int/*.ppu src/int/*.s
	@rm -f src/asm/*.o src/asm/*~ src/asm/*.ppu src/asm/*.s
	@rm -f src/sys/*.o src/sys/*~ src/sys/*.ppu src/sys/*.s src/sys/*.a
	@rm -f src/fs/*.o src/fs/*~ src/fs/*.ppu src/fs/*.s
	@rm -f src/fs/ext2/*.o src/fs/ext2/*~ src/fs/ext2/*.ppu src/fs/ext2/*.s
	@rm -f src/include/*~
	@rm -f src/include/kernel/*~
	@rm -f src/include/sys/*~
	@rm -f src/lib/*~ src/lib/*.o src/lib/*.a src/lib/*.ppu
