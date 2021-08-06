{*
 * Debug symbols
 *
 * NOTE: Every symbol defined here will print some info ONLY through Bochs
 *       console (using port 0xe9)
 *
 * NOTE2: Do not forget to 'make clean' before recompiling DelphineOS kernel if
 *        you modify this file.
 *
 *}



{********************}
{* Kernel constants *}
{********************}
const
	LOOKUP_CACHE_MAX_ENTRIES		= 1024;
	BUFFER_HEAD_LIST_MAX_ENTRIES	= 1024;

	FREE_BUFFER_MAX					= 400;   {* Number of buffers we want to free
														 * when calling free_buffers() *}

	FREE_LOOKUP_CACHE_MAX			= 400;   {* Number of lookup cache entries we
														 * want to free when calling
														 * free_lookup_cache() *}

	KFLUSHD_SLEEP_INTERVAL			= 120;	{* kflushd() will wake up every
														 * KFLUSHD_SLEEP_INTERVAL seconds *}

	KFLUSHD_BUFFER_SYNC_MAX			= 10;		{* Number of dirty buffers we write
														 * to disk each time kflushd() is
														 * running *}

	KFLUSHD_INODE_SYNC_MAX			= 10;		{* Number of dirty inodes we write
														 * to disk each time kflushd() is
														 * running *}


{************************************************}
{*  USE_MEMSET  											*}
{*              											*}
{* Clean memory chunks allocated by kmalloc() 	*}
{************************************************}
{$DEFINE USE_MEMSET}   {* FIXME: one day, we'll have to unset this
      	             	* 20/09/2003: it seems that everything is
								* ok when I undef USE_MEMSET. *}


{*************************************************}
{* KMALLOC_WARNING										 *}
{*              											 *}
{* Will print a warning if kmalloc(4096) is used *}
{* because it's faster to call get_free_page()	 *}
{*************************************************}
{$DEFINE KMALLOC_WARNING}


{***************************************************}
{* DEBUG_SYSTEM_CALL										   *}
{*              											   *}
{* Show which system calls are used (slow down OS) *}
{***************************************************}
{DEFINE DEBUG_SYSTEM_CALL}



{****************}
{*  EXT2 DEBUG  *}
{****************}
{DEFINE DEBUG_EXT2_NEW_BLOCK}
{DEFINE DEBUG_EXT2_READDIR}
{DEFINE DEBUG_EXT2_ADD_LINK}
{$DEFINE DEBUG_EXT2_DELETE_ENTRY}
{DEFINE DEBUG_EXT2_FIND_ENTRY}
{DEFINE DEBUG_EXT2_GET_REAL_BLOCK}
{DEFINE DEBUG_EXT2_FILE_READ}
{DEFINE DEBUG_EXT2_FILE_WRITE}
{DEFINE DEBUG_FIND_GROUP}
{DEFINE DEBUG_EXT2_NEW_INODE}
{DEFINE DEBUG_EXT2_FREE_INODE}
{DEFINE DEBUG_EXT2_LOOKUP}
{DEFINE DEBUG_EXT2_FREE_DATA}
{DEFINE DEBUG_EXT2_READ_INODE}
{DEFINE DEBUG_EXT2_WRITE_INODE}
{DEFINE DEBUG_EXT2_DELETE_INODE}
{DEFINE DEBUG_EXT2_CREATE}
{$DEFINE DEBUG_EXT2_UNLINK}
{DEFINE DEBUG_EXT2_READ_SUPER}
{DEFINE REVISION_WARNING}
{DEFINE DEBUG_EXT2_GET_GROUP_DESC}
{DEFINE DEBUG_EXT2_MKDIR}
{DEFINE DEBUG_EXT2_EMPTY_DIR}


{*****************}
{* Debug symbols *}
{*****************}
{DEFINE DEBUG_SYS_SYNC}
{DEFINE DEBUG_KFLUSHD}
{DEFINE DEBUG_KERNEL_THREAD}
