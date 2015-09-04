/**
EvenMatch.SHA1Hash

Copyright (c) 2015, Wormbo

(1) This source code and any binaries compiled from it are provided "as-is",
without warranty of any kind. (In other words, if it breaks something for you,
that's entirely your problem, not mine.)
(2) You are allowed to reuse parts of this source code and binaries compiled
from it in any way that does not involve making money, breaking applicable laws
or restricting anyone's human or civil rights.
(3) You are allowed to distribute binaries compiled from modified versions of
this source code only if you make the modified sources available as well. I'd
prefer being mentioned in the credits for such binaries, but please do not make
it seem like I endorse them in any way.
*/

class SHA1Hash extends Object;


struct SHA1Result { var int A,B,C,D,E; };
var SHA1Result HashValue;
var array<byte> Data;
var int NextChunk;

/** @ignore */
var private SHA1Result StaticHashValue;
/** @ignore */
var private array<byte> StaticData;


//=============================================================================
// Instant hash functions - probably not suitable for long input data
//=============================================================================

static final function SHA1Result GetStringHash(string In)
{
	local int StrLen, i;
	
	StrLen = Len(In);
	default.StaticData.Length = StrLen;
	for (i = 0; i < StrLen; i++) {
		default.StaticData[i] = Asc(Mid(In, i, 1));
	}
	StaticProcessChunks();
	return default.StaticHashValue;
}

static final function string GetStringHashString(string In)
{
	local int StrLen, i;
	
	StrLen = Len(In);
	default.StaticData.Length = StrLen;
	for (i = 0; i < StrLen; i++) {
		default.StaticData[i] = Asc(Mid(In, i, 1));
	}
	StaticProcessChunks();
	return BigEndianToHex(default.StaticHashValue.A) $ BigEndianToHex(default.StaticHashValue.B) $ BigEndianToHex(default.StaticHashValue.C) $ BigEndianToHex(default.StaticHashValue.D) $ BigEndianToHex(default.StaticHashValue.E);
}

static final function SHA1Result GetArrayHash(array<byte> In)
{
	default.StaticData = In;
	StaticProcessChunks();
	return default.StaticHashValue;
}

static final function string GetArrayHashString(array<byte> In)
{
	default.StaticData = In;
	StaticProcessChunks();
	return BigEndianToHex(default.StaticHashValue.A) $ BigEndianToHex(default.StaticHashValue.B) $ BigEndianToHex(default.StaticHashValue.C) $ BigEndianToHex(default.StaticHashValue.D) $ BigEndianToHex(default.StaticHashValue.E);
}

static final function string GetHashString(SHA1Result Hash)
{
	return BigEndianToHex(Hash.A) $ BigEndianToHex(Hash.B) $ BigEndianToHex(Hash.C) $ BigEndianToHex(Hash.D) $ BigEndianToHex(Hash.E);
}


//=============================================================================
// Public methods
//=============================================================================

static final function string BigEndianToHex(int i)
{
	const hex = "0123456789abcdef";
	
	return Mid(hex, i >> 28 & 0xf, 1) $ Mid(hex, i >> 24 & 0xf, 1) $ Mid(hex, i >> 20 & 0xf, 1) $ Mid(hex, i >> 16 & 0xf, 1) $ Mid(hex, i >> 12 & 0xf, 1) $ Mid(hex, i >> 8 & 0xf, 1) $ Mid(hex, i >> 4 & 0xf, 1) $ Mid(hex, i & 0xf, 1);
}

final function SHA1Result GetResult()
{
	return HashValue;
}

final function string GetResultString()
{
	return BigEndianToHex(HashValue.A) $ BigEndianToHex(HashValue.B) $ BigEndianToHex(HashValue.C) $ BigEndianToHex(HashValue.D) $ BigEndianToHex(HashValue.E);
}

final function ResetContext()
{
	NextChunk = 0;
	HashValue.A = 0x67452301;
	HashValue.B = 0xEFCDAB89;
	HashValue.C = 0x98BADCFE;
	HashValue.D = 0x10325476;
	HashValue.E = 0xC3D2E1F0;
}

final function DataFromString(string str)
{
	local int DataLen, i;
	
	ResetContext();
	
	DataLen = Len(str);
	Data.Length = DataLen;
	for (i = 0; i < DataLen; i++) {
		Data[i] = Asc(Mid(str, i, 1));
	}
	PadData();
}

final function DataFromArray(array<byte> ar)
{
	ResetContext();
	Data = ar;
	PadData();
}

final function PadData()
{
	local int DataLen;
	
	DataLen = Data.Length;
	if (DataLen % 64 < 56)
		Data.Length = Data.Length + 64 - DataLen % 64;
	else
		Data.Length = Data.Length + 128 - DataLen % 64;
	Data[DataLen] = 0x80;
	Data[Data.Length - 5] = (DataLen >>> 29);
	Data[Data.Length - 4] = (DataLen >>> 21);
	Data[Data.Length - 3] = (DataLen >>> 13);
	Data[Data.Length - 2] = (DataLen >>>	5);
	Data[Data.Length - 1] = (DataLen <<	 3);
}

final function ProcessChunks()
{
	while (ProcessNextChunk());
}

final function bool ProcessNextChunk()
{
	local int i;
	local int A, B, C, D, E,temp;
	local array<int> w;
	
	if (NextChunk * 64 >= Data.Length)
		return false;
	
	w.Length = 80;
	for (i = 0; i < 16; i++) {
		w[i] = (Data[NextChunk * 64 + i * 4] << 24) | (Data[NextChunk * 64 + i * 4 + 1] << 16) | (Data[NextChunk * 64 + i * 4 + 2] << 8) | Data[NextChunk * 64 + i * 4 + 3];
	}
	for (i = 16; i < 80; i++) {
		temp = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16];
		w[i] = (temp << 1) | (temp >>> 31);
	}
	
	// initialize hash value for this chunk
	A = HashValue.A;
	B = HashValue.B;
	C = HashValue.C;
	D = HashValue.D;
	E = HashValue.E;
	
	// round 1
	E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[ 0] + 0x5A827999;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[ 1] + 0x5A827999;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[ 2] + 0x5A827999;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[ 3] + 0x5A827999;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[ 4] + 0x5A827999;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[ 5] + 0x5A827999;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[ 6] + 0x5A827999;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[ 7] + 0x5A827999;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[ 8] + 0x5A827999;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[ 9] + 0x5A827999;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[10] + 0x5A827999;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[11] + 0x5A827999;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[12] + 0x5A827999;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[13] + 0x5A827999;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[14] + 0x5A827999;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[15] + 0x5A827999;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[16] + 0x5A827999;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[17] + 0x5A827999;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[18] + 0x5A827999;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[19] + 0x5A827999;		C = (C << 30) | (C >>> -30);
	
	// round 2
	E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[20] + 0x6ED9EBA1;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[21] + 0x6ED9EBA1;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[22] + 0x6ED9EBA1;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[23] + 0x6ED9EBA1;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[24] + 0x6ED9EBA1;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[25] + 0x6ED9EBA1;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[26] + 0x6ED9EBA1;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[27] + 0x6ED9EBA1;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[28] + 0x6ED9EBA1;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[29] + 0x6ED9EBA1;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[30] + 0x6ED9EBA1;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[31] + 0x6ED9EBA1;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[32] + 0x6ED9EBA1;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[33] + 0x6ED9EBA1;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[34] + 0x6ED9EBA1;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[35] + 0x6ED9EBA1;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[36] + 0x6ED9EBA1;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[37] + 0x6ED9EBA1;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[38] + 0x6ED9EBA1;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[39] + 0x6ED9EBA1;		C = (C << 30) | (C >>> -30);
	
	// round 3
	E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[40] + 0x8F1BBCDC;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[41] + 0x8F1BBCDC;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[42] + 0x8F1BBCDC;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[43] + 0x8F1BBCDC;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[44] + 0x8F1BBCDC;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[45] + 0x8F1BBCDC;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[46] + 0x8F1BBCDC;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[47] + 0x8F1BBCDC;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[48] + 0x8F1BBCDC;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[49] + 0x8F1BBCDC;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[50] + 0x8F1BBCDC;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[51] + 0x8F1BBCDC;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[52] + 0x8F1BBCDC;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[53] + 0x8F1BBCDC;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[54] + 0x8F1BBCDC;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[55] + 0x8F1BBCDC;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[56] + 0x8F1BBCDC;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[57] + 0x8F1BBCDC;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[58] + 0x8F1BBCDC;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[59] + 0x8F1BBCDC;		C = (C << 30) | (C >>> -30);
	
	// round 4
	E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[60] + 0xCA62C1D6;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[61] + 0xCA62C1D6;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[62] + 0xCA62C1D6;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[63] + 0xCA62C1D6;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[64] + 0xCA62C1D6;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[65] + 0xCA62C1D6;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[66] + 0xCA62C1D6;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[67] + 0xCA62C1D6;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[68] + 0xCA62C1D6;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[69] + 0xCA62C1D6;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[70] + 0xCA62C1D6;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[71] + 0xCA62C1D6;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[72] + 0xCA62C1D6;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[73] + 0xCA62C1D6;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[74] + 0xCA62C1D6;		C = (C << 30) | (C >>> -30);
	
	E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[75] + 0xCA62C1D6;		B = (B << 30) | (B >>> -30);
	D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[76] + 0xCA62C1D6;		A = (A << 30) | (A >>> -30);
	C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[77] + 0xCA62C1D6;		E = (E << 30) | (E >>> -30);
	B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[78] + 0xCA62C1D6;		D = (D << 30) | (D >>> -30);
	A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[79] + 0xCA62C1D6;		C = (C << 30) | (C >>> -30);
	
	// add this chunk's hash to result so far
	HashValue.A += A;
	HashValue.B += B;
	HashValue.C += C;
	HashValue.D += D;
	HashValue.E += E;
	
	return ++NextChunk * 64 < Data.Length;
}


//=============================================================================
// Internal stuff for static instant hashing functions
//=============================================================================

private static final function StaticProcessChunks()
{
	local int i, chunk, temp;
	local int A, B, C, D, E;
	local array<int> w;
	
	i = default.StaticData.Length;
	if (i % 64 < 56)
		default.StaticData.Length = default.StaticData.Length + 64 - i % 64;
	else
		default.StaticData.Length = default.StaticData.Length + 128 - i % 64;
	default.StaticData[i] = 0x80;
	default.StaticData[default.StaticData.Length - 5] = (i >>> 29);
	default.StaticData[default.StaticData.Length - 4] = (i >>> 21);
	default.StaticData[default.StaticData.Length - 3] = (i >>> 13);
	default.StaticData[default.StaticData.Length - 2] = (i >>>	5);
	default.StaticData[default.StaticData.Length - 1] = (i <<	 3);
	
	default.StaticHashValue.A = 0x67452301;
	default.StaticHashValue.B = 0xEFCDAB89;
	default.StaticHashValue.C = 0x98BADCFE;
	default.StaticHashValue.D = 0x10325476;
	default.StaticHashValue.E = 0xC3D2E1F0;
	
	while (chunk * 64 < default.StaticData.Length) {
		w.Length = 80;
		for (i = 0; i < 16; i++) {
			w[i] = (default.StaticData[chunk * 64 + i * 4] << 24) | (default.StaticData[chunk * 64 + i * 4 + 1] << 16) | (default.StaticData[chunk * 64 + i * 4 + 2] << 8) | default.StaticData[chunk * 64 + i * 4 + 3];
		}
		for (i = 16; i < 80; i++) {
			temp = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16];
			w[i] = (temp << 1) | (temp >>> 31);
		}
		
		// initialize hash value for this chunk
		A = default.StaticHashValue.A;
		B = default.StaticHashValue.B;
		C = default.StaticHashValue.C;
		D = default.StaticHashValue.D;
		E = default.StaticHashValue.E;
		
		// round 1
		E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[ 0] + 0x5A827999;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[ 1] + 0x5A827999;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[ 2] + 0x5A827999;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[ 3] + 0x5A827999;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[ 4] + 0x5A827999;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[ 5] + 0x5A827999;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[ 6] + 0x5A827999;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[ 7] + 0x5A827999;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[ 8] + 0x5A827999;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[ 9] + 0x5A827999;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[10] + 0x5A827999;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[11] + 0x5A827999;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[12] + 0x5A827999;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[13] + 0x5A827999;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[14] + 0x5A827999;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + (D ^ (B & (C ^ D))) + w[15] + 0x5A827999;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (C ^ (A & (B ^ C))) + w[16] + 0x5A827999;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (B ^ (E & (A ^ B))) + w[17] + 0x5A827999;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (A ^ (D & (E ^ A))) + w[18] + 0x5A827999;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (E ^ (C & (D ^ E))) + w[19] + 0x5A827999;		C = (C << 30) | (C >>> -30);
		
		// round 2
		E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[20] + 0x6ED9EBA1;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[21] + 0x6ED9EBA1;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[22] + 0x6ED9EBA1;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[23] + 0x6ED9EBA1;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[24] + 0x6ED9EBA1;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[25] + 0x6ED9EBA1;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[26] + 0x6ED9EBA1;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[27] + 0x6ED9EBA1;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[28] + 0x6ED9EBA1;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[29] + 0x6ED9EBA1;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[30] + 0x6ED9EBA1;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[31] + 0x6ED9EBA1;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[32] + 0x6ED9EBA1;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[33] + 0x6ED9EBA1;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[34] + 0x6ED9EBA1;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[35] + 0x6ED9EBA1;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[36] + 0x6ED9EBA1;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[37] + 0x6ED9EBA1;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[38] + 0x6ED9EBA1;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[39] + 0x6ED9EBA1;		C = (C << 30) | (C >>> -30);
		
		// round 3
		E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[40] + 0x8F1BBCDC;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[41] + 0x8F1BBCDC;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[42] + 0x8F1BBCDC;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[43] + 0x8F1BBCDC;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[44] + 0x8F1BBCDC;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[45] + 0x8F1BBCDC;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[46] + 0x8F1BBCDC;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[47] + 0x8F1BBCDC;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[48] + 0x8F1BBCDC;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[49] + 0x8F1BBCDC;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[50] + 0x8F1BBCDC;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[51] + 0x8F1BBCDC;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[52] + 0x8F1BBCDC;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[53] + 0x8F1BBCDC;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[54] + 0x8F1BBCDC;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + ((B & C) | (D & (B | C))) + w[55] + 0x8F1BBCDC;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + ((A & B) | (C & (A | B))) + w[56] + 0x8F1BBCDC;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + ((E & A) | (B & (E | A))) + w[57] + 0x8F1BBCDC;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + ((D & E) | (A & (D | E))) + w[58] + 0x8F1BBCDC;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + ((C & D) | (E & (C | D))) + w[59] + 0x8F1BBCDC;		C = (C << 30) | (C >>> -30);
		
		// round 4
		E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[60] + 0xCA62C1D6;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[61] + 0xCA62C1D6;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[62] + 0xCA62C1D6;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[63] + 0xCA62C1D6;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[64] + 0xCA62C1D6;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[65] + 0xCA62C1D6;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[66] + 0xCA62C1D6;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[67] + 0xCA62C1D6;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[68] + 0xCA62C1D6;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[69] + 0xCA62C1D6;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[70] + 0xCA62C1D6;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[71] + 0xCA62C1D6;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[72] + 0xCA62C1D6;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[73] + 0xCA62C1D6;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[74] + 0xCA62C1D6;		C = (C << 30) | (C >>> -30);
		
		E += ((A << 5) | (A >>> -5)) + (B ^ C ^ D) + w[75] + 0xCA62C1D6;		B = (B << 30) | (B >>> -30);
		D += ((E << 5) | (E >>> -5)) + (A ^ B ^ C) + w[76] + 0xCA62C1D6;		A = (A << 30) | (A >>> -30);
		C += ((D << 5) | (D >>> -5)) + (E ^ A ^ B) + w[77] + 0xCA62C1D6;		E = (E << 30) | (E >>> -30);
		B += ((C << 5) | (C >>> -5)) + (D ^ E ^ A) + w[78] + 0xCA62C1D6;		D = (D << 30) | (D >>> -30);
		A += ((B << 5) | (B >>> -5)) + (C ^ D ^ E) + w[79] + 0xCA62C1D6;		C = (C << 30) | (C >>> -30);
		
		// add this chunk's hash to result so far
		default.StaticHashValue.A += A;
		default.StaticHashValue.B += B;
		default.StaticHashValue.C += C;
		default.StaticHashValue.D += D;
		default.StaticHashValue.E += E;
		
		chunk++;
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}
