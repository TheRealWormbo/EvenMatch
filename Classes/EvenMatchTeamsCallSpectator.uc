/**
EvenMatchV2a8.EvenMatchTeamsCallSpectator

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

class EvenMatchTeamsCallSpectator extends MessagingSpectator;


var string TeamsCallString;
var MutTeamBalance EvenMatchMutator;


function InitPlayerReplicationInfo()
{
	Super.InitPlayerReplicationInfo();
	PlayerReplicationInfo.PlayerName = "EvenMatch-TeamsListener";
}


function TeamMessage(PlayerReplicationInfo PRI, coerce string Message, name Type)
{
	if (EvenMatchMutator != None && Type == 'Say' && PRI != None && PlayerController(PRI.Owner) != None && Message ~= TeamsCallString)
		EvenMatchMutator.HandleTeamsCall(PlayerController(PRI.Owner));
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}
