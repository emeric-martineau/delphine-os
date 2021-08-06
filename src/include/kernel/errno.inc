{ POSIX error codes

  Definitions taken from the POSIX programmer's guide }

{$IFNDEF __ERRNO__}
{$DEFINE __ERRNO__}

const

   MAX_ERROR = 38;

   E2BIG     = 2;   { The number of bytes used by the new process image's
                      argument list and environment list is greater than the
		      system limit of ARG_MAX bytes. }

   EACCESS   = 3; { Search permission is denied for a directory in a file's path
                    prefix }

   EAGAIN    = 4; { The O_NONBLOCK flag is set for a file descriptor and the
                    process would be delayed in the I/O operation }

   EBADF     = 5; { Invalid file descriptor }

   ENOENT    = 6; { A file or directory does not exist }

   EMFILE    = 7; { Too many file descriptors are in use by this process }

   EBUSY     = 8; { The directory is in use }

   ECHILD    = 9; { There are no children or a process group number does not
                    specify a child for this process }

   EDEADLK   = 10; { An fcntl() with function F_SETLKW would cause a deadlock }

   EDOM      = 11; { An input argument was outside the defined domain of a
                     mathematical function }

   EEXIST    = 12; { The named file already exists }

   EFAULT    = 13; { The system detected an invalid address in attempting to
                     use an argument of a function call }

   EFBIG     = 14; { An attempt was made to write to a file that exceeds the
                     maximum file size }

   EINTR     = 15; { Function was interrupted by a signal }

   EINVAL    = 16; { Invalid argument }

   EIO       = 17; { Input or output error }

   EISDIR    = 18; { Attempt to open a directory for writing or to rename a file
                     to be a directory }

   EMLINK    = 19; { The number of links would exceed LINK_MAX }

   ENFILE    = 20; { Too many files are currently open in the system }

   ENODEV    = 21; { No such device }

   ENOEXEC   = 22; { An attempt was made to execute a file that is not in the
                     correct format }

   ENOLCK    = 23; { No locks available }

   ENOMEM    = 24; { No memory available }

   ENOSPC    = 25; { No space left on disk }

   ENOSYS    = 26; { Function not implemented }

   ENOTDIR   = 27; { A component of the specified pathname was not a directory
                     when a directory was expected }

   ENOTEMPTY = 28; { Attempt to delete or rename a non-empty directory }

   ENOTTY    = 29; { Terminal control function attempted for a file that is
                     not a terminal }

   ENXIO     = 30; { No such device. This error may also occur when a device
                     is not ready, for example, a tape drive is off-line }

   EPERM     = 31; { Operation is not permitted. Process does not have the
                     appropriate privileges or permissions to perform the
		     requested operation }

   EPIPE     = 32; { Attempt to write to a pipe or FIFO with no reader }

   ERANGE    = 33; { Result is too large }

   EROFS     = 34; { Read-only file system }

   ESPIPE    = 35; { An lseek() was issued on a pipe or FIFO }

   ESRCH     = 36; { No such process }

   EXDEV     = 37; { Attempt to link a file to another file system }

   ENAMETOOLONG = 38; { Length of a filename string exceeds PATH_MAX and
                        _POSIX_NO_TRUNC is in effect }

{$ENDIF}
