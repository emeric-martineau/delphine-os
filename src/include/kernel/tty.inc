{$IFNDEF __TTY__}
{$DEFINE __TTY__}

{$I lock.inc}
{$I wait.inc}

Const

    ESnormal      = 1;
    ESesc         = 2;
    ESsquare      = 3;
    ESgetpars     = 4;
    ESgotpars     = 5;
    ESfunckey     = 6;
    ESsetterm     = 7;
    ESsetgraph    = 8;
    NBPAR         = 15;

	 MAX_TTY 		= 8;
    MAX_BUFF_CLAV = 4095;
    Num_Lock      = 0;
    Caps_Lock     = 1;
    Scroll_Lock   = 2;

	 {* termios flags definition (from dietlibc include files) *}
	 ICANON			= 2;
	 ECHO 			= 8;

    NCCS          = 19;

    TCGETS        = $5401;
	 TCSETS        = $5402;
    TCSETSW       = $5403;

    TIOCGWINSZ    = $5413;

	 FIONREAD		= $541B;


Type 

	 P_tty_struct = ^tty_struct;
    P_termios = ^termios;
	 P_vesa_mode_info_t = ^vesa_mode_info_t;
	 P_vesa_pm_info_t = ^vesa_pm_info_t;
    P_vesa_info_t = ^vesa_info_t;
    
    vesa_info_t = record	{* 512 bytes *}
       signature     : dword;   { 0x41534556 = 'ASEV' (VESA) }
       version       : word;
       oemstr        : pointer;
       capabilities	: dword;
       modes         : pointer;
		 { Next fields only for VESA >= 2.0 }
       memory        	: word;	{ Number of 64kb memory blocks }
		 oem_software_rev : word;	{ VBE implementation Software revision }
		 oem_vendor_name	: pointer;
		 oem_product_name	: pointer;
		 oem_product_rev	: pointer;
       reserved      	: array [1..222] of byte; {* Reserved for VBE
		 															* implementation scratch
																	* area *}
		 oem_data			: array [1..256] of byte; { Data Area for OEM Strings }
    end;

	 vesa_mode_info_t = record 	{* 256 bytes *}
	    { Mandatory information for all VBE revisions }
	    mode_attributes		: word;  {* The ModeAttributes field is defined as
		 										 * follows:
												 *
												 * D0: Mode supported by hardware
												 *     configuration
												 *
												 * 0 = not supported
												 * 1 = supported
												 *
												 *
												 * D1: 1 (Reserved)
												 *
												 *
												 * D2: TTY Output functions supported by
												 *     BIOS
												 *
												 * 0 = not supported
												 * 1 = supported
												 *
												 *
												 * D3: Monochrome/color mode
												 *
												 * 0 = Monochrome
												 * 1 = Color
												 *
												 *
												 * D4: Mode type
												 *
												 * 0 = Text mode
												 * 1 = Graphics mode
												 *
												 *
												 * D5: VGA compatible mode
												 *
												 * 0 = Yes
												 * 1 = No
												 *
												 *
												 * D6: VGA compatible windowed memory mode
												 *     is available
												 *
												 * 0 = Yes
												 * 1 = No
												 *
												 *
												 * D7: Linear frame buffer mode is available
												 *
												 * 0 = No
												 * 1 = Yes
												 *
												 *
												 * D8: Double scan mode is available
												 *
												 * 0 = No
												 * 1 = Yes
												 *
												 *
												 * D9: Interlaced mode is available
												 *
												 * 0 = No
												 * 1 = Yes
												 *
												 *
												 * D10: Hardware triple buffering support
												 *
												 * 0 = No
												 * 1 = Yes
												 *
												 *
												 * D11: Hardware stereoscopic display
												 *      support
												 *
												 * 0 = No
												 * 1 = Yes
												 *
												 *
												 * D12: Dual display start address support
												 *
												 * 0 = No
												 * 1 = Yes
												 *
												 *
												 * D13-D15: Reserved
												 *}
		 winA_attributes		: byte;
		 winB_attributes		: byte;
		 win_granularity		: word;  {* specifies the smallest boundary, in KB,
		 										 * on which the window can be placed in
												 * the frame buffer memory. The value of
												 * this field is undefined if Bit D0 of the
												 * appropriate WinAttributes field is not
												 * set.*}

		 win_size				: word; {* specify the segment addresses where the
		 										* windows are located in the CPU address
												* space. Note that these values are real
												* mode segment values, so to convert the
												* real 32 bit physical address you need to
												* shift the values left 4 bits (ie: segment
												* A000h is physical address A0000h). Also
												* note that if the hardware has only linear
												* framebuffer modes available, the values
												* listed in here will be set to 0 indicating
												* the banked framebuffer is notavailable *}

		 winA_segment			: word;
		 winB_segment			: word;
		 win_func_ptr			: dword; {* real mode pointer to window function
		 										 *
												 * NOTE: src/boot/setup.S write some info
												 *       for init_tty() here *}
		 bytes_per_scan_line : word;

		 { Mandatory information for VBE 1.2 and above }
		 x_resolution			: word;
		 y_resolution			: word;
		 x_char_size			: byte;  { character cell width in pixels }
		 y_char_size			: byte;  { character cell height in pixels }
		 nb_of_planes			: byte;
		 bits_per_pixel		: byte;
		 nb_of_banks			: byte;
		 memory_model			: byte;  {*  specifies the general type of memory
		 										 * organization used in this mode. The
												 * following models have been defined:
												 *
												 * 00h = Text mode
												 * 01h = CGA Graphics
												 * 02h = Hercules graphics
												 * 03h = Planar
												 * 04h = Packed pixel
												 * 05h = Non-chain 4, 256 color
												 * 06h = Direct Color
												 * 07h = YUV
												 * 08h-0Fh = Reserved, to be defined by
												 *           VESA
												 * 10h-FFh = To be defined by OEM *}
		 bank_size				: byte;  { bank size in KB }
		 nb_of_image_pages	: byte;  { number of images }
		 reserved				: byte;  { reserved for page function }

		 { Direct Color fields (required for direct/6 and YUV/7 memory models) }
		 red_mask_size			: byte;  { size of direct color red mask in bits }
		 red_field_position	: byte;  { bit position of lsb of red mask }
		 green_mask_size		: byte;  { size of direct color green mask in bits }
		 green_field_position: byte;  { bit position of lsb of green mask }
		 blue_mask_size		: byte;  { size of direct color blue mask in bits }
		 blue_field_position	: byte;  { bit position of lsb of blue mask }
		 rsvd_mask_size		: byte;  { bit position of lsb of reserved mask }
		 direct_color_info	: byte;  { direct color mode attributes }

		 { Mandatory information for VBE 2.0 and above }
		 phys_base_ptr 		: pointer;  {* physical address for flat memory
		 											 * frame buffer *}
		 reserved1				: dword;
		 reserved2				: word;

		 { Mandatory information for VBE 3.0 and above }
		 lin_bytes_per_scan_line	: word;  {* bytes per scan line for linear
		 												 * modes *}

		 bnk_nb_image_pages			: byte;  { number of images for banked modes }
		 lin_nb_image_pages			: byte;  { number of images for linear modes }

		 lin_red_mask_size			: byte;  {* size of direct color red mask
		 												 * (linear modes) *}

		 lin_red_field_position 	: byte;  {* bit position of lsb of red mask
		 												 * (linear modes) *}

		 lin_green_mask_size			: byte;  {* size of direct color green mask
		 												 * (linear modes) *}

		 lin_green_field_position 	: byte;  {* bit position of lsb of green mask
		 												 * (linear modes) *}

		 lin_blue_mask_size			: byte;  {* size of direct color blue mask
		 												 * (linear modes) *}

		 lin_blue_field_position 	: byte;  {* bit position of lsb of blue mask
		 												 * (linear modes) *}

		 lin_rsvd_mask_size			: byte;  {* size of direct color reserved mask
		 												 * (linear modes) *}

		 lin_rsvd_field_position	: byte;  {* bit position of lsb of reserved
		 												 * mask (linear modes) *}

		 max_pixel_clock				: dword; {* maximum pixel clock (in Hz) for
		 												 * graphics mode *}

		 reserved3						: array [1..189] of byte;

	 end;

	 vesa_pm_info_t = record
	 	 signature	  : dword;   { 0x44494D50 = 'DIMP' (PMID) }
		 entry_point  : word;
		 
	 end;

    cc_t      = byte;    { typedef unsigned char cc_t; }
    speed_t   = dword;   { typedef unsigned int speed_t; }
    tcflag_t  = dword;   { typedef unsigned int	tcflag_t; }


    termios   = record
       c_iflag : tcflag_t;   {* Controls the processing of input data. There are
		 								* 11 flags defined by POSIX. There is only one,
										* ISTRIP, that may be of interest to a portable
										* application. This flag causes input characters
										* to be masked to seven bits *}

       c_oflag : tcflag_t;   {* Controls the processing of output data. The only
		 								* flag defined by POSIX, OPOST, causes
										* system-specific output processing. There are no
										* flags of interest to a portable application *}

       c_cflag : tcflag_t;   {* Controls information related to the hardware,
		 								* for example, the parity setting. There are seven
										* flags defined by POSIX, none of interest to a
										* portable application. *}

       c_lflag : tcflag_t;   {* Controls echoing and character processing. There
		 								* are nine flags defined by POSIX; four of these
										* flags may be modified by a portable application:
										*
										* - ECHO 	Turns on echoing.
										*
										* - ECHOE	If ECHOE and ICANON are both set, the
										*				ERASE character causes the terminal
										*				to erase the last character from the
										*				display, if possible.
										*
										* - ECHOK	If ECHOK and ICANON are both set, the
										*				KILL character erases the last line
										*				from the display. If the hardware does
										*				not allow the data to be erased, this
										*				flag is ignored.
										*
										* - ECHONL	If ECHONL and ICANON are both set, the
										*				'\n' character is echoed even if ECHO
										*				is not set.
										*
										* - ICANON	Turns on input processing.
										*
										* - ISIG 	Enables signals (INTR, QUIT, SUSP).
										*
										* - TOSTOP	Stops background process if they write
										*				to the controlling terminal. *}

       c_line  : cc_t;       { line discipline }

       c_cc    : array[0..NCCS - 1] of cc_t;   { control characters }
    end;


    tty_struct = record 
       x, y, attr, align	: byte;
       buffer_keyboard     : ^char;
       keyboard_wq         : P_wait_queue;
       next_c, last_c      : dword;
       depassement         : boolean;
       num_caps_scroll     : dword;
		 flags					: termios;
       npar		    			: dword;
		 count	    			: dword;
		 lock 					: rwlock_t;
       par                 : array[0..15] of dword;
    end;



{$ENDIF}
