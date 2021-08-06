{$IFNDEF __AR__}
{$DEFINE __AR__}


type
   ar_hdr = record   { Definition taken from ar.h in from GNU/Linux }
      ar_name : array[0..15] of char;   { Member file name, sometimes / terminated. }
      ar_date : array[0..11] of char;   { File date, decimal seconds since Epoch. }
      ar_uid, ar_gid : array[0..5] of char;   { User and group IDs, in ASCII decimal. }
      ar_mode : array[0..7] of char;   { File mode, in ASCII octal. }
      ar_size : array[0..9] of char;   { File size, in ASCII decimal. }
      ar_fmag : array[0..1] of char;   { Always contains ARFMAG. }
   end;


{$ENDIF}
