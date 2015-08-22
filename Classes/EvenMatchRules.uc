/******************************************************************************
EvenMatchRules

Creation date: 2009-07-19 10:58
Last change: $Id$
Copyright (c) 2009, Wormbo
******************************************************************************/

class EvenMatchRules extends GameRules config;


struct TPlayerPPH {
	var config string ID;
	var config float PPH;
	var config int TS;
};
var config array<TPlayerPPH> RecentPPH;

var ONSOnslaughtGame Game;
var MutTeamBalance Mut;
var int MinDesiredRoundDuration;
var bool bBalancing, bSaveNeeded;
var int FirstRoundResult;

var float LastRestartTime;
var PlayerController LastRestarter, PotentiallyLeavingPlayer;


function SaveRecentPPH()
{
	if (bSaveNeeded)
		SaveConfig();
	bSaveNeeded = False;
}

/**
Purge outdated PPH data and randomly swap sides if configured.
*/
function PreBeginPlay()
{
	local int i, Now, Diff;

	// remove obsolete entries
	Now = GetTS();
	for (i = RecentPPH.Length - 1; i >= 0; --i) {
		Diff = (10080 + Now - RecentPPH[i].TS) % 10080;
		if (Diff > 3000) {
			// older than about 2 days
			RecentPPH.Remove(i, 1);
			bSaveNeeded = True;
		}
	}

	Game = ONSOnslaughtGame(Level.Game);
	if (Game != None) {
		AddToPackageMap();
		MinDesiredRoundDuration = class'MutTeamBalance'.default.MinDesiredRoundDuration * 60;
		Game.AddGameModifier(Self);
		if (class'MutTeamBalance'.default.bRandomlyStartWithSidesSwapped && Rand(2) == 0)
			SwapSides();
	}
	else {
		Destroy();
	}
	
	SaveRecentPPH();
}


function AddGameRules(GameRules GR)
{
	if (GR != None && !GR.IsA('EvenMatchRules'))
		Super.AddGameRules(GR);
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
	class'MutTeamBalance'.static.FillPlayInfo(PlayInfo);
}


function SwapSides()
{
	local int i;
	
	for (i = 0; i < Game.PowerCores.Length; ++i) {
		if (Game.PowerCores[i].DefenderTeamIndex < 2) {
			Game.PowerCores[i].DefenderTeamIndex = 1 - Game.PowerCores[i].DefenderTeamIndex;
			if (Game.PowerCores[i].bFinalCore)
				Game.FinalCore[Game.PowerCores[i].DefenderTeamIndex] = i;
		}
	}
	// might cause problems on round restart if False
	Game.bSwapSidesAfterReset = True;
	Game.bSidesAreSwitched = True;
}


/**
Shuffle teams at match start, if configured.
*/
function MatchStarting()
{
	if (class'MutTeamBalance'.default.bShuffleTeamsFromPreviousMatch) {
		log("Shuffling teams from previous match...", Name);
		ShuffleTeams();
		BroadcastLocalizedMessage(class'UnevenMessage', -1);
	}
}


/**
Check team balance right before a player respawns.
*/
function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string IncomingName)
{
	if (Mut.IsBalancingActive() && PlayerController(Player) != None && (LastRestarter != Player || LastRestartTime != Level.TimeSeconds)) {
		LastRestarter = PlayerController(Player);
		LastRestartTime = Level.TimeSeconds;
		
		Mut.CheckBalance(LastRestarter, False);
	}
	return Super.FindPlayerStart(Player, InTeam, IncomingName);
}


/**
Returns the current timestamp.
*/
function int GetTS()
{
	return Level.Minute + Level.Hour * 60 + Level.DayOfWeek * 1440;
}


/**
Called at the end of the match if the first round was restarted due to heavy team imbalance.
*/
event Trigger(Actor Other, Pawn EventInstigator)
{
	if (Other == Level.Game && FirstRoundResult != 0)
		BroadcastLocalizedMessage(class'UnevenMessage', FirstRoundResult);
}

function bool CheckScore(PlayerReplicationInfo Scorer)
{
	local int i;
	
	if (bBalancing || Super.CheckScore(Scorer)) {
		SaveRecentPPH(); // store recent PPH values
		return true;
	}
	if (Level.GRI.ElapsedTime < MinDesiredRoundDuration && Level.GRI.Teams[0].Score + Level.GRI.Teams[1].Score > 0) {
		MinDesiredRoundDuration = 0; // one restart is enough
		bBalancing = True;
		if (Level.GRI.Teams[0].Score > 0)
			FirstRoundResult = 1;
		else
			FirstRoundResult = 2;
		Tag = 'EndGame';
		
		log("Quick first round, shuffling teams...", Name);
		ShuffleTeams();
		BroadcastLocalizedMessage(class'UnevenMessage', 0,,, Level.GRI.Teams[FirstRoundResult-1]);
		
		// force round restart
		if (Level.Game.GameStats != None) {
			if (Mut.bDebug) log("Resetting team score stats...", Name);
			if (Level.GRI.Teams[0].Score > 0)
				Level.Game.GameStats.TeamScoreEvent(0, -Level.GRI.Teams[0].Score, "reset");
			if (Level.GRI.Teams[1].Score > 0)
				Level.Game.GameStats.TeamScoreEvent(1, -Level.GRI.Teams[1].Score, "reset");
		}
		if (Mut.bDebug) log("Resetting team scores...", Name);
		Level.GRI.Teams[0].Score = 0;
		Level.GRI.Teams[1].Score = 0;
		
		bBalancing = False;
		SaveRecentPPH(); // store recent PPH values
		return true;
	}
	else {
		// just update recent PPH values
		for (i = 0; i < Level.GRI.PRIArray.Length; ++i) {
			if (Level.GRI.PRIArray[i] != None && !Level.GRI.PRIArray[i].bOnlySpectator)
				GetPointsPerHour(Level.GRI.PRIArray[i]);
		}
		SaveRecentPPH(); // store updated PPH values
	}
	return false;
}

/** Check if a player is becoming spectator. */
function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> damageType, vector HitLocation)
{
	if (DamageType == class'Suicided' && PlayerController(Killed.Controller) != None || DamageType == class'DamageType' && Killed.PlayerReplicationInfo != None && Killed.PlayerReplicationInfo.bOnlySpectator) {
		PotentiallyLeavingPlayer = PlayerController(Killed.Controller);
		SetTimer(0.01, false); // might be a player leaving, check right after all this whether it really is
	}
	return Super.PreventDeath(Killed, Killer, damageType, HitLocation);
}

// HACK: Mutator.NotifyLogout() doesn't seem to be called in all cases, so perform alternate check here
function Timer()
{
	if (PotentiallyLeavingPlayer == None || PotentiallyLeavingPlayer.PlayerReplicationInfo != None && PotentiallyLeavingPlayer.PlayerReplicationInfo.bOnlySpectator) {
		if (Mut.bDebug) {
			if (PotentiallyLeavingPlayer == None)
				log("DEBUG: a player disconnected", name);
			else
				log("DEBUG: " $ PotentiallyLeavingPlayer.GetHumanReadableName() $ " became spectator", name);
		}
		Mut.CheckBalance(PotentiallyLeavingPlayer, True);
	}
}


function ScoreKill(Controller Killer, Controller Killed)
{
	Super.ScoreKill(Killer, Killed);
	
	// update PPH for killer and killed
	if (Killer != None && Killer.PlayerReplicationInfo != None)
		GetPointsPerHour(Killer.PlayerReplicationInfo);
	if (Killed != None && Killed.PlayerReplicationInfo != None)
		GetPointsPerHour(Killed.PlayerReplicationInfo);
	// don't save right away, too much work to be done on every kill
}


function ShuffleTeams()
{
	local PlayerReplicationInfo PRI;
	local array<PlayerReplicationInfo> RedPRIs, BluePRIs; // sorted by points per hour
	local int i, j, OldNumBots, OldMinPlayers, iBest, jBest;
	local float PPH, PPH2, RedPPH, BluePPH, PPHDiff, BestDiff;
	local bool bFoundPair;
	
	OldNumBots = Game.NumBots + Game.RemainingBots;
	OldMinPlayers = Game.MinPlayers;
	Game.RemainingBots = 0;
	Game.MinPlayers    = 0;
	if (Game.NumBots > 0) {
		if (Mut.bDebug) log("Removing " $ Game.NumBots $ " bots for shuffling", Name);
		Game.KillBots(Game.NumBots);
	}
	// find PRIs of active players
	for (i = 0; i < Level.GRI.PRIArray.Length; ++i) {
		PRI = Level.GRI.PRIArray[i];
		if (!PRI.bOnlySpectator && PlayerController(PRI.Owner) != None && PlayerController(PRI.Owner).bIsPlayer) {
			PPH = GetPointsPerHour(PRI);
			if (PRI.Team.TeamIndex == 0) {
				if (Mut.bDebug) log(PRI.PlayerName $ " is currently on red, " $ PPH $ " PPH", Name);
				for (j = 0; j < RedPRIs.Length && GetPointsPerHour(RedPRIs[j]) > PPH; ++j);
				RedPRIs.Insert(j, 1);
				RedPRIs[j] = PRI;
				RedPPH += PPH;
			}
			else if (PRI.Team.TeamIndex == 1) {
				if (Mut.bDebug) log(PRI.PlayerName $ " is currently on blue, " $ PPH $ " PPH", Name);
				for (j = 0; j < BluePRIs.Length && GetPointsPerHour(BluePRIs[j]) > PPH; ++j);
				BluePRIs.Insert(j, 1);
				BluePRIs[j] = PRI;
				BluePPH += PPH;
			}
		}
	}
	if (Mut.bDebug) {
		log("Red team size " $ RedPRIs.Length $ ", combined PPH " $ RedPPH, Name);
		log("Blue team size " $ BluePRIs.Length $ ", combined PPH " $ BluePPH, Name);
	}
	// let the game re-add missing bots
	if (Mut.bDebug && OldNumBots > 0)
		log("Will re-add " $ OldNumBots $ " bots later", Name);
	Game.RemainingBots = OldNumBots;
	Game.MinPlayers    = OldMinPlayers;
	
	// first balance team sizes
	if (Mut.bDebug) log("Balancing team sizes...", Name);
	while (RedPRIs.Length > 0 && RedPRIs.Length - BluePRIs.Length > 1) {
		// move a random red player to the blue team
		i = Rand(RedPRIs.Length);
		PPH = GetPointsPerHour(RedPRIs[i]);
		for (j = 0; j < BluePRIs.Length && GetPointsPerHour(BluePRIs[j]) > PPH; ++j);
		BluePRIs.Insert(j, 1);
		BluePRIs[j] = RedPRIs[i];
		BluePPH += PPH;
		RedPRIs.Remove(i, 1);
		RedPPH -= PPH;
		if (Mut.bDebug) log("-" @ BluePRIs[j].PlayerName $ " will move to blue (" $ PPH $ " PPH)", Name);
	}
	while (BluePRIs.Length > 0 && BluePRIs.Length - RedPRIs.Length > 1) {
		// move a random blue player to the red team
		i = Rand(BluePRIs.Length);
		PPH = GetPointsPerHour(BluePRIs[i]);
		for (j = 0; j < RedPRIs.Length && GetPointsPerHour(RedPRIs[j]) > PPH; ++j);
		RedPRIs.Insert(j, 1);
		RedPRIs[j] = BluePRIs[i];
		RedPPH += PPH;
		BluePRIs.Remove(i, 1);
		BluePPH -= PPH;
		if (Mut.bDebug) log("-" @ RedPRIs[j].PlayerName $ " will move to red (" $ PPH $ " PPH)", Name);
	}
	if (Mut.bDebug) {
		log("Red team size " $ RedPRIs.Length $ ", combined PPH " $ RedPPH, Name);
		log("Blue team size " $ BluePRIs.Length $ ", combined PPH " $ BluePPH, Name);
	}
	// now balance team skill
	if (Mut.bDebug) log("Balancing team PPH...", Name);
	do {
		PPHDiff = RedPPH - BluePPH;
		bFoundPair = False;
		BestDiff = 0;
		for (i = 0; i < RedPRIs.Length; ++i) {
			PPH = GetPointsPerHour(RedPRIs[i]);
			for (j = 0; j < BluePRIs.Length; ++j) {
				PPH2 = GetPointsPerHour(BluePRIs[j]);
				if (Abs(PPHDiff - 2 * BestDiff) > Abs(PPHDiff - 2 * (PPH - PPH2))) {
					bFoundPair = True;
					iBest = i;
					jBest = j;
					BestDiff = PPH - PPH2;
				}
			}
		}
		if (bFoundPair) {
			if (Mut.bDebug) log("Swapping " $ RedPRIs[iBest].PlayerName $ " (red) and " $ BluePRIs[jBest].PlayerName $ " (blue), PPH diff. " $ BestDiff, Name);
			PRI = RedPRIs[iBest];
			RedPRIs[iBest] = BluePRIs[jBest];
			BluePRIs[jBest] = PRI;
			RedPPH  -= BestDiff;
			BluePPH += BestDiff;
		}
	} until (!bFoundPair);
	if (Mut.bDebug) {
		log("Red team size " $ RedPRIs.Length $ ", combined PPH " $ RedPPH, Name);
		log("Blue team size " $ BluePRIs.Length $ ", combined PPH " $ BluePPH, Name);
	}
	// apply team changes
	if (Mut.bDebug) log("Applying team changes...", Name);
	for (i = 0; i < RedPRIs.Length; ++i) {
		if (RedPRIs[i].Team.TeamIndex != 0) {
			if (Mut.bDebug) log("Moving " $ RedPRIs[i].PlayerName $ " to red", Name);
			ChangeTeam(PlayerController(RedPRIs[i].Owner), 0);
		}
	}
	for (i = 0; i < BluePRIs.Length; ++i) {
		if (BluePRIs[i].Team.TeamIndex != 1) {
			if (Mut.bDebug) log("Moving " $ BluePRIs[i].PlayerName $ " to blue", Name);
			ChangeTeam(PlayerController(BluePRIs[i].Owner), 1);
		}
	}
	if (Mut.bDebug) log("Teams shuffled.", Name);
}


function float GetPointsPerHour(PlayerReplicationInfo PRI)
{
	local PlayerController PC;
	local string ID;
	local int i;
	local float PPH;
	
	PC = PlayerController(PRI.Owner);
	if (PC != None) {
		// generate an ID from IP and first part of GUID
		ID = PC.GetPlayerNetworkAddress();
		ID = Left(ID, InStr(ID, ":"));
		ID @= Left(PC.GetPlayerIDHash(), 8);
	}
	// calculate current PPH
	PPH = 3600 * FMax(PRI.Score, 0.1) / Max(Level.GRI.ElapsedTime - PRI.StartTime, 10);
	for (i = 0; i < RecentPPH.Length; ++i) {
		if (RecentPPH[i].ID == ID)
			break;
	}
	if (PRI.Score != 0) {
		// already scored, override score from earlier
		if (i >= RecentPPH.Length)
			RecentPPH.Length = i + 1;
		
		bSaveNeeded = bSaveNeeded || RecentPPH[i].PPH != PPH;
		
		RecentPPH[i].ID  = ID;
		RecentPPH[i].PPH = PPH;
		RecentPPH[i].TS  = GetTS();
	}
	else if (i < RecentPPH.Length) {
		// No score yet, try finding PPH from earlier
		PPH = RecentPPH[i].PPH;
	}
	return PPH;
}


function ChangeTeam(PlayerController Player, int NewTeam)
{
	Player.PlayerReplicationInfo.Team.RemoveFromTeam(Player);
	if (Level.GRI.Teams[NewTeam].AddToTeam(Player)) {
		Player.ReceiveLocalizedMessage(class'TeamSwitchNotification', NewTeam);
		ONSOnslaughtGame(Level.Game).GameEvent("TeamChange", string(NewTeam), Player.PlayerReplicationInfo);
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
}
