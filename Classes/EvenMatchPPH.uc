/**
EvenMatch.EvenMatchPPH

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

class EvenMatchPPH extends Object config(EvenMatchPPH) perobjectconfig parseconfig;


struct TPlayerPPH {
	var config string ID;
	var config float PastPPH;
	var config float CurrentPPH;
	var config int TS;
};

var config array<string> MyReplacementStatsID;
var config array<TPlayerPPH> PPH;



function int FindPPHSlot(string ID)
{
	local int High, Low, Middle;

	High = PPH.Length;
	if (Low < High) do {
		Middle = (High + Low) / 2;
		if (PPH[Middle].ID < ID)
			Low = Middle + 1;
		else
			High = Middle;
	} until (Low >= High);
	
	return Low;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}
