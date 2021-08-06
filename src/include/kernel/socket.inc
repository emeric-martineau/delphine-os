{$IFNDEF __SOCKET__}
{$DEFINE __SOCKET__}


const

   NSYS_SOCKET      = 1;
   NSYS_BIND        = 2;
   NSYS_CONNECT     = 3;
   NSYS_LISTEN      = 4;
   NSYS_ACCEPT      = 5;
   NSYS_GETSOCKNAME = 6;
   NSYS_GETPEERNAME = 7;
   NSYS_SOCKETPAIR  = 8;
   NSYS_SEND        = 9;
   NSYS_RECV        = 10;
   NSYS_SENDTO      = 11;
   NSYS_RECVFROM    = 12;
   NSYS_SHUTDOWN    = 13;
   NSYS_SETSOCKOPT  = 14;
   NSYS_GETSOCKOPT  = 15;
   NSYS_SENDMSG     = 16;
   NSYS_RECVMSG     = 17;

   nargs : array [0..17] of dword = 
   ( 0, 3, 3, 3, 2, 3,
     3, 3, 4, 4, 4, 6,
     6, 2, 5, 5, 3, 3);


type

   P_sockaddr  = ^sockaddr;

   sa_family_t = word;

   sockaddr = record
      sa_family : sa_family_t;
      sa_data   : array[1..14] of char;
   end;


{$ENDIF}
