#ifndef _UNISTD_
#define _UNISTD_

#include <sys/types.h>

#ifdef _POSIX_SOURCE


#define STDIN_FILENO   0;
#define STDOUT_FILENO  1;
#define STDERR_FILENO  2;

#define SEEK_SET = 0;   /* Set offset to 'offset' */
#define SEEK_CUR = 1;   /* Add 'offset' to current position */
#define SEEK_END = 2;   /* Add 'offset' to cuurent file size */



pid_t fork();
int   write(int fildes, const void *buf, unsigned int nbyte);
off_t lseek(int fildes, off_t offset, int whence);



#endif   /* _POSIX_SOURCE */

#endif   /* _UNISTD_ */
