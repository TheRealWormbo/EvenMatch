/**
Displays a message and plays an announcement that tells the player about his or
her new team membership, e.g. after a forced team switch.

Copyright (c) 2010-2015, Wormbo

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

class TeamSwitchNotification extends CriticalEventPlus;


//=============================================================================
// Imports
//=============================================================================

#exec audio import file=Sounds\YouAreOnRed.wav
#exec audio import file=Sounds\YouAreOnBlue.wav


//=============================================================================
// Localization
//=============================================================================

var localized string YouAreOnTeam;


//=============================================================================
// Announcements
//=============================================================================

var Sound TeamChangeAnnouncement[2];


static function ClientReceive(PlayerController P, optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	Super.ClientReceive(P, MessageSwitch, RelatedPRI_1, RelatedPRI_2, OptionalObject);

	if (UnrealPlayer(P) != None)
		UnrealPlayer(P).ClientDelayedAnnouncement(default.TeamChangeAnnouncement[MessageSwitch], 5 + 10 * int(OptionalObject != None));
}

static function string GetString(optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	return Repl(default.YouAreOnTeam, "%t", class'TeamInfo'.default.ColorNames[MessageSwitch]);
}


static function color GetColor(optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2)
{
	switch (MessageSwitch) {
	case 0:
		return class'HUD'.default.RedColor;
	case 1:
		return class'HUD'.default.BlueColor;
	default:
		return Default.DrawColor;
	}
}



//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	YouAreOnTeam = "You are on %t"
	
	TeamChangeAnnouncement(0) = Sound'YouAreOnRed'
	TeamChangeAnnouncement(1) = Sound'YouAreOnBlue'
	
	bIsConsoleMessage = False
	Lifetime  = 3
	StackMode = SM_Down
	PosY      = 0.8
}
