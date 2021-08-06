

const

	EXT2_DIR_PAD	= 4;
	EXT2_DIR_ROUND = (EXT2_DIR_PAD - 1);


function EXT2_DIR_REC_LEN (len : dword) : dword; inline;
begin

	result := (len + 8 + EXT2_DIR_ROUND) and (not EXT2_DIR_ROUND);

end;
