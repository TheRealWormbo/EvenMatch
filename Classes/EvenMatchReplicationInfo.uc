/**
EvenMatchV2a7.EvenMatchReplicationInfo

Creation date: 2015-08-15 08:21
Last change: $Id$
Copyright (c) 2015, Wormbo
*/

class EvenMatchReplicationInfo extends ReplicationInfo;


var float Progress;
var MutTeamBalance Mut;


replication
{
	unreliable if (bNetInitial || bNetDirty)
		Progress;
}


simulated function PostNetBeginPlay()
{
	if (Level.NetMode != NM_DedicatedServer)
	{
		Spawn(class'EvenMatchHudOverlay', self);
	}
}


function Timer()
{
	local float NewProgress;
	
	if (Mut != None)
	{
		NewProgress = Mut.GetTeamProgress();
		if (Progress != NewProgress)
			Progress = NewProgress;
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
     Progress=0.500000
     NetUpdateFrequency=1.000000
}
