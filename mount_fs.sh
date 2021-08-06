#!/bin/bash

# Mount DelphineOS on /mnt/cdrom

losetup -o 32256 /dev/loop0 bochs/delphineOS.img
mount /dev/loop0 /mnt/cdrom
