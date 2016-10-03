/**
This damage type is used to kill players who are being switching to another
team, so everyone can see what's going on.

Copyright (c) 2015-2016, Wormbo

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

class DamTypeTeamChange extends Suicided abstract;



//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	DeathString="%o was forced to auto-switch teams."
	MaleSuicide="%o was forced to auto-switch teams."
	FemaleSuicide="%o was forced to auto-switch teams."
}
