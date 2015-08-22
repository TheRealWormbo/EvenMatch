/**
Ensures team changes are properly replicated if they happen during respawn.

Copyright © 2010-2015, Wormbo

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
	Team = 255
}

