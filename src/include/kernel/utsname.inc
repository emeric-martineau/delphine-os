{$IFNDEF __UTSNAME__}
{$DEFINE __UTSNAME__}

const
   _UTSNAME_LENGTH = 65;
   _UTSNAME_NODENAME_LENGTH = _UTSNAME_LENGTH;
   _UTSNAME_DOMAIN_LENGTH   = _UTSNAME_LENGTH;


type

   P_utsname = ^utsname;

   utsname = record
      { Name of the implementation of the operating system. }
      sysname : array[1.._UTSNAME_LENGTH] of char;
      { Name of this node on the network. }
      nodename : array[1.._UTSNAME_NODENAME_LENGTH] of char;
      { Current release level of this implementation. }
      release  : array[1.._UTSNAME_LENGTH] of char;
      { Current version level of this release. }
      version  : array[1.._UTSNAME_LENGTH] of char;
      { Name of the hardware type the system is running on. }
      machine  : array[1.._UTSNAME_LENGTH] of char;
      { Name of the domain of this node on the network. }
      domainname : array[1.._UTSNAME_DOMAIN_LENGTH] of char;
   end;

{$ENDIF}
