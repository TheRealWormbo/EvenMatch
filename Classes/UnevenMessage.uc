/**
Localizable HUD message about EvenMatch's actions and game state assessments.

Copyright (c) 2009-2015, Wormbo

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

class UnevenMessage extends CriticalEventPlus;


//=============================================================================
// Localization
//=============================================================================

var localized string QuickRoundBalanceString;
var localized string PrevMatchBalanceString;
var localized string FirstRoundWinnerString;
var localized string TeamsUnbalancedString;
var localized string SoftBalanceString;
var localized string ForcedBalanceString;
var localized string CallForBalanceString;
var localized string NoCallForBalanceNowString;
var localized string NoCallForBalanceEvenString;


//=============================================================================
// Announcements
//=============================================================================

var name QuickRoundAnnouncement[2];


static function ClientReceive(PlayerController P, optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	Super.ClientReceive(P, MessageSwitch, RelatedPRI_1, RelatedPRI_2, OptionalObject);

	if (TeamInfo(OptionalObject) != None && TeamInfo(OptionalObject).TeamIndex < 2) {
		switch (MessageSwitch) {
		case 0:
			P.QueueAnnouncement(default.QuickRoundAnnouncement[TeamInfo(OptionalObject).TeamIndex], 1, AP_NoDuplicates);
			break;
		}
	}
}


static function string GetString(optional int MessageSwitch, optional PlayerReplicationInfo RelatedPRI_1, optional PlayerReplicationInfo RelatedPRI_2, optional Object OptionalObject)
{
	switch (MessageSwitch) {
	case -4:
		return default.NoCallForBalanceEvenString;
	case -3:
		return default.NoCallForBalanceNowString;
	case -2:
		return Repl(default.CallForBalanceString, "%p", RelatedPRI_1.PlayerName);
	case -1:
		return default.PrevMatchBalanceString;
	case 0:
		return default.QuickRoundBalanceString;
	case 1:
	case 2:
		return Repl(default.FirstRoundWinnerString, "%t", class'TeamInfo'.default.ColorNames[MessageSwitch - 1]);
	case 3:
		return default.SoftBalanceString;
	case 4:
		return default.ForcedBalanceString;
	default:
		if (MessageSwitch > 3)
			return Repl(default.TeamsUnbalancedString, "%n", 10 * (MessageSwitch - 4));
	}
	return "";
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	QuickRoundBalanceString = "Quick round, restarting with balanced teams"
	PrevMatchBalanceString  = "Teams have been balanced based on last match results"
	FirstRoundWinnerString  = "%t won the first round"
	SoftBalanceString       = "Teams are uneven, respawning players may switch to balance"
	TeamsUnbalancedString   = "Teams are uneven, balance will be forced in %n seconds"
	ForcedBalanceString     = "Teams are uneven, balance will be forced now"
	CallForBalanceString    = "%p called for a team balance check"
	NoCallForBalanceNowString  = "You can't request a team balance check at this time."
	NoCallForBalanceEvenString = "Teams look even already, no apparent need for balancing."

	QuickRoundAnnouncement(0) = red_team_dominating
	QuickRoundAnnouncement(1) = blue_team_dominating

	Lifetime  = 5
	DrawColor = (B=0,G=255,R=255)
	StackMode = SM_Down
	PosY      = 0.6
	bIsUnique = False
	bIsPartiallyUnique = True
}
