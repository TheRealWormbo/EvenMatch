/******************************************************************************
TeamSwitchNotification

Creation date: 2010-02-06 23:28
Last change: $Id$
Copyright (c) 2010, Wormbo
******************************************************************************/

class TeamSwitchNotification extends CriticalEventPlus;


//=============================================================================
// Imports
//=============================================================================

#exec audio import file=YouAreOnRed.wav
#exec audio import file=YouAreOnBlue.wav


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
		UnrealPlayer(P).ClientDelayedAnnouncement(default.TeamChangeAnnouncement[MessageSwitch], 5);
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
     YouAreOnTeam="You are on %t"
     TeamChangeAnnouncement(0)=Sound'YouAreOnRed'
     TeamChangeAnnouncement(1)=Sound'YouAreOnBlue'
     bIsConsoleMessage=False
     StackMode=SM_Down
     PosY=0.800000
}
