#!/bin/bash

# Use to run e2fsck on bochs/delphineOS.img

dd if=bochs/delphineOS.img of=bochs/delphineOS_ext2.img bs=512 iseek=63 2>/dev/null
e2fsck -f bochs/delphineOS_ext2.img
dd if=bochs/delphineOS_ext2.img of=bochs/delphineOS.img bs=512 oseek=63 2>/dev/null
