procedure mount_root; external;
function  fork : dword; external;
function  read (fd : dword ; buffer : pointer ; count : dword) : dword; external;
function  write (fd : dword ; buffer : pointer ; count : dword) : dword; external;
function  getpid : dword; external;

procedure printf (format : string ; args : array of const); external;
