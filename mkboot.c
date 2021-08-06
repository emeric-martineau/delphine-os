
/* Je tiens à préciser que ce programme s'inspire très largement de 'nuni' et
 * qu'il est donc sous GPL. GaLi */

#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>


struct stat st;
unsigned char major, minor;
div_t calc;
int blocks_to_read, fd, kinode_block, kinode_offset;
FILE* outfile;



int main (int argc, char *argv[])
{

	char 					superbloc[128];
	unsigned int* 		ipg = (unsigned int*)&superbloc[40];
	unsigned int* 		blk_size = (unsigned int*)&superbloc[24];
	unsigned short*	magic = (unsigned short*)&superbloc[56];
	short 				drive, ipb, partition_ofs, nb_sec, blocks_to_64k;
	short 				max_kernel_blocs;

   if (argc != 3) {
      puts("\nmkboot : You must specify device and kernel file ...");
      puts("Ex : mkboot /dev/hda1 /mnt/kernel\n");
      return -1;
   }

   if (stat(argv[2], &st) != 0) {   
      perror("mkboot: stat");
      return -1;
   }

   major = st.st_dev >> 8;
   minor = st.st_dev & 0xFF;

   if ((major == 2) && (minor == 0)) {
      drive = 0;
      partition_ofs = 0;
   }
   
   if ((major == 2) && (minor == 1)) {
      drive = 1;
      partition_ofs = 0;
   }

   if (major == 3) {
      drive = 0x80;
      if ( minor == 1 ) {
	 partition_ofs = 0x1BE;
      }
      if ( minor == 2 ) {
	 partition_ofs = 0x1CE;
      }
      if ( minor == 3 ) {
	 partition_ofs = 0x1DE;
      }
      if ( minor == 4 ) {
	 partition_ofs = 0x1EE;
      }
   }

   if (major == 7) {
      drive = 0x80;
      partition_ofs = 0x1BE;
   }

   if ((major == 3) && (minor > 64)) {
      drive = 0x81;
   }

/* FIXME */
drive = 0x80;
partition_ofs = 0x1BE;

   if ((fd = open(argv[1], O_RDONLY)) < 0) {
      printf("\nmkboot: Can't open device !!!\n\n");
      return(-1);
   }

/* On va lire le superbloc pour avoir le nombre d'inodes par bloc */

   if (lseek(fd, 0x400, SEEK_SET) != 0x400) {
		perror("\n\nfseek");
      printf("mkboot: Can't open device (1) !!!\n\n");
      return(-1);
   }

   if (read(fd, superbloc, 128) != 128) {
      perror("\n\nread");
		printf("mkboot: Can't read device (2) !!!\n\n");
      return(-1);
   }

/* On ne gère (pour l'instant) que le 1er groupe de blocs. On va vérifier si
 * l'inode à lire fait partie du 1er groupe de blocs */
   
   if ( st.st_ino > *ipg ) {
      printf("\nmkboot: Inode number must be < %d\n\n",*ipg);
      return(-1);
   }
   
   switch (*blk_size) {

    case 0:
		*blk_size = 1;
      break;

    case 1:
		*blk_size = 2;
		break;

    case 2:
		*blk_size = 4;
		break;
   }

   ipb = ( *blk_size * 1024 ) / 128;   

   /* Calcul du nombre de bloc à lire */
         
   calc = div(st.st_size, ( *blk_size * 1024 ));
   blocks_to_read = calc.quot;
   if (calc.rem != 0) {
      blocks_to_read++;
   }
      
   if ( *blk_size == 1 ) {
      *blk_size = 1024;
      nb_sec = 2;
      blocks_to_64k = 64;
      max_kernel_blocs = 512;
   }
   
   if ( *blk_size == 2 ) {
      *blk_size = 2048;
      nb_sec = 4;
      blocks_to_64k = 32;
      max_kernel_blocs = 256;
   }
   
   if ( *blk_size == 4 ) {
      *blk_size = 4096;
      nb_sec = 8;
      blocks_to_64k = 16;
      max_kernel_blocs = 128;
   }
   
/* On va créer un fichier avec les infos collectées pour l'inclure dans le
 * source du boot loader */
   
   if ( blocks_to_read > max_kernel_blocs ) {
      printf("\nmkboot: Kernel too big for actual loader !!!\n\n");
      return(-1);
   }

   if ((outfile = fopen("./src/boot/boot.dat","w")) == NULL) {
      perror("mkboot: Can't create data file ");
      return(-1);
   }

   calc = div(st.st_ino, ipb);
   kinode_block = calc.quot;
   kinode_offset = (calc.rem * 128) - 128;
	/* On commence à compter les inodes à partir de 1 et non pas à partir
	 * de 0 !!! */
   
   fprintf(outfile, "drive EQU %d\n", drive);
   fprintf(outfile, "partition_ofs EQU %d\n", partition_ofs);
   fprintf(outfile, "kernel_inode EQU %d\n", st.st_ino);
   fprintf(outfile, "blocks_to_read EQU %d\n",blocks_to_read);
   fprintf(outfile, "blk_size EQU %d\n",*blk_size);
   fprintf(outfile, "kinode_block EQU %d\n",kinode_block);
   fprintf(outfile, "kinode_offset EQU %d\n",kinode_offset);
   fprintf(outfile, "nb_sec EQU %d\n",nb_sec);
   fprintf(outfile, "blocks_to_64k EQU %d\n",blocks_to_64k);
   fclose(outfile);

}
