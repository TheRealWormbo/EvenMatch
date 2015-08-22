/******************************************************************************
Ensures team changes are properly replicated if they happen during respawn.

Creation date: 2010-11-17 14:07
Last change: $Id$
Copyright © 2010, Wormbo
Website: http://www.koehler-homepage.de/Wormbo/
Feel free to reuse this code. Send me a note if you found it helpful or want
to report bugs/provide improvements.
Please ask for permission first, if you intend to make money off reused code.
******************************************************************************/

class TeamChangeReplicationInfo extends ReplicationInfo;


var xPawn P;
var byte Team;

replication
{
	reliable if (bNetInitial)
		P, Team;
}


function PreBeginPlay()
{
	local xPlayerReplicationInfo PRI;
	
	P = XPawn(Owner);
	if (P != None) {
		PRI = xPlayerReplicationInfo(P.PlayerReplicationInfo);
		if (PRI == None && P.DrivenVehicle != None)
			PRI = xPlayerReplicationInfo(P.DrivenVehicle.PlayerReplicationInfo);
		
		if (PRI != None && PRI.Team != None)
			Team = PRI.Team.TeamIndex;
	}
}

simulated function Tick(float DeltaTime)
{
	local xPlayerReplicationInfo PRI;
	
	if (Role == ROLE_Authority) {
		if (P == None)
			Destroy();
	}
	else  {	
		if (Team == 255 || P == None || P.TeamSkin == Team || !P.bAlreadySetup || P.Species == None)
			return;
		
		PRI = xPlayerReplicationInfo(P.PlayerReplicationInfo);
		if (PRI == None && P.DrivenVehicle != None)
			PRI = xPlayerReplicationInfo(P.DrivenVehicle.PlayerReplicationInfo);
		
		if (PRI == None || P.Species == None || PRI.Rec.DefaultName == "")
			return;
		P.Species.static.SetTeamSkin(P, PRI.Rec, Team);
		Disable('Tick');
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
     Team=255
}
