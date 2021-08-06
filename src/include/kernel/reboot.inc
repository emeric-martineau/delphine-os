{$IFNDEF __REBOOT__}
{$DEFINE __REBOOT__}


{ Magic values required to use _reboot() system call. }

const
   LINUX_REBOOT_MAGIC1	= $fee1dead;
   LINUX_REBOOT_MAGIC2	= 672274793;
   LINUX_REBOOT_MAGIC2A	= 85072278;
   LINUX_REBOOT_MAGIC2B	= 369367448;


{*
 * Commands accepted by the _reboot() system call.
 *
 * RESTART     Restart system using default command and mode.
 * HALT        Stop OS and give system control to ROM monitor, if any.
 * CAD_ON      Ctrl-Alt-Del sequence causes RESTART command.
 * CAD_OFF     Ctrl-Alt-Del sequence sends SIGINT to init task.
 * POWER_OFF   Stop OS and remove all power from system, if possible.
 * RESTART2    Restart system using given command string.
 *}

LINUX_REBOOT_CMD_RESTART   = $01234567;
LINUX_REBOOT_CMD_HALT	   = $CDEF0123;
LINUX_REBOOT_CMD_CAD_ON    = $89ABCDEF;
LINUX_REBOOT_CMD_CAD_OFF   = $00000000;
LINUX_REBOOT_CMD_POWER_OFF = $4321FEDC;
LINUX_REBOOT_CMD_RESTART2  = $A1B2C3D4;


{$ENDIF}
