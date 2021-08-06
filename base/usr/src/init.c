#include <fcntl.h>

int main() {

	int res;

	res = fork();

	if (res == 0) {
		close(0);
		close(1);
		close(2);
		open("/dev/tty2", O_RDWR);
		dup(0);
		dup(0);
		execl("/bin/sh", "-ksh", 0);
	} else {
		execl("/bin/sh", "-ksh", 0);
	}

	return 0;

}
