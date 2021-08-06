#!/bin/bash

# Use to run e2fsck on bochs/delphineOS.img

losetup -o 32256 /dev/loop0 bochs/delphineOS.img
e2fsck -f /dev/loop0
#dumpe2fs /dev/loop0
losetup -d /dev/loop0
