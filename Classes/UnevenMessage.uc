/******************************************************************************
UnevenMessage

Creation date: 2009-07-19 11:46
Last change: $Id$
Copyright (c) 2009, Wormbo
******************************************************************************/

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
     QuickRoundBalanceString="Quick round, restarting with balanced teams"
     PrevMatchBalanceString="Teams have been balanced based on last match results"
     FirstRoundWinnerString="%t won the first round"
     TeamsUnbalancedString="Teams are uneven, balance will be forced in %n seconds"
     SoftBalanceString="Teams are uneven, respawning players will switch to balance"
     ForcedBalanceString="Teams are uneven, balance will be forced now"
     QuickRoundAnnouncement(0)="red_team_dominating"
     QuickRoundAnnouncement(1)="blue_team_dominating"
     bIsUnique=False
     bIsPartiallyUnique=True
     Lifetime=5
     DrawColor=(B=0,G=255,R=255)
     StackMode=SM_Down
     PosY=0.600000
}
