	.file "socket.pp"

.text
	.balign 16
.globl	sys_getpeername
	.type	sys_getpeername,@function
sys_getpeername:
.globl	SYS_GETPEERNAME
	.type	SYS_GETPEERNAME,@function
SYS_GETPEERNAME:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$8,%esp
	pushl	%edi
	pushl	%esi
	pushl	%ebx
	movl	%esp,-8(%ebp)
	movl	$-88,-4(%ebp)
	movl	-4(%ebp),%eax
	movl	-8(%ebp),%esp
	popl	%ebx
	popl	%esi
	popl	%edi
	leave
	ret
.Le0:
	.size	sys_getpeername, .Le0 - sys_getpeername
	.balign 16
.globl	sys_socketcall
	.type	sys_socketcall,@function
sys_socketcall:
.globl	SYS_SOCKETCALL
	.type	SYS_SOCKETCALL,@function
SYS_SOCKETCALL:
	pushl	%ebp
	movl	%esp,%ebp
	subl	$44,%esp
	pushl	%edi
	pushl	%esi
	pushl	%ebx
	movl	%esp,-44(%ebp)
	pushl	$-1
	leal	-40(%ebp),%edi
	pushl	%edi
	pushl	$.L15
	call	PRINTK
	sti
	movl	8(%ebp),%eax
	cmpl	$1,%eax
	jl	.L16
	jmp	.L18
.L18:
	movl	8(%ebp),%eax
	cmpl	$17,%eax
	jg	.L16
	jmp	.L17
.L16:
	movl	$-22,%eax
	jmp	.L8
.L17:
	movl	12(%ebp),%eax
	cmpl	$-4194304,%eax
	jl	.L21
	jmp	.L22
.L21:
	movl	$-14,%eax
	jmp	.L8
.L22:
	movl	$-38,-32(%ebp)
	movl	8(%ebp),%eax
	movl	TC__SOCKET$$_NARGS(,%eax,4),%eax
	shll	$2,%eax
	pushl	%eax
	leal	-28(%ebp),%eax
	pushl	%eax
	pushl	12(%ebp)
	call	MEMCPY
	movl	8(%ebp),%eax
	cmpl	$7,%eax
	jl	.L34
	subl	$7,%eax
	jz	.L9
	jmp	.L34
.L9:
	pushl	-20(%ebp)
	pushl	-24(%ebp)
	pushl	-28(%ebp)
	call	sys_getpeername
	addl	$12,%esp
	movl	%eax,-32(%ebp)
	jmp	.L33
.L34:
	movl	8(%ebp),%edi
	movl	%edi,-36(%ebp)
	movl	$0,-40(%ebp)
	pushl	$0
	leal	-40(%ebp),%edi
	pushl	%edi
	pushl	$.L47
	call	PRINTK
.L33:
	movl	-32(%ebp),%edi
	movl	%edi,-4(%ebp)
	movl	-4(%ebp),%eax
.L8:
	movl	-44(%ebp),%esp
	popl	%ebx
	popl	%esi
	popl	%edi
	leave
	ret
.Le1:
	.size	sys_socketcall, .Le1 - sys_socketcall
	.balign 16
.globl	SOCKET_init
	.type	SOCKET_init,@function
SOCKET_init:
.globl	INIT$$SOCKET
	.type	INIT$$SOCKET,@function
INIT$$SOCKET:
	pushl	%ebp
	movl	%esp,%ebp
	leave
	ret
.Le2:
	.size	SOCKET_init, .Le2 - SOCKET_init
	.balign 16

.data
	.balign 4
.globl	TC__SOCKET$$_BITMAP
	.type	TC__SOCKET$$_BITMAP,@object
TC__SOCKET$$_BITMAP:
	.long	16777215,268435455,1073741823,0,65535,8388607,268435455,1073741823,2147483647
	.balign 4
.globl	TC__SOCKET$$_BITMAP2
	.type	TC__SOCKET$$_BITMAP2,@object
TC__SOCKET$$_BITMAP2:
	.long	4064,4080,4088,0,0,0,0,0,0
	.balign 4
.globl	TC__SOCKET$$_NARGS
	.type	TC__SOCKET$$_NARGS,@object
TC__SOCKET$$_NARGS:
	.long	0,3,3,3,2,3,3,3,4,4,4,6,6,2,5,5,3,3

.data
.L15:
	.ascii	"'WARNING: sys_socketcall always failed\\n\000"
.L47:
	.ascii	",WARNING sys_socketcall called with call=%d\\n\000"

.data

.bss

