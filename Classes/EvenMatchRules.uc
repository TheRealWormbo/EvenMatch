/**
Implements team shuffling on match start and after a quick first round and
various GameRules-only hooks to trigger mid-round balancing.

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

class EvenMatchRules extends GameRules config(EvenMatchPPH) parseconfig;


const SECONDS_PER_DAY = 86400;


var EvenMatchPPH Recent, RecentMap;

var ONSOnslaughtGame Game;
var MutTeamBalance EvenMatchMutator;
var int MinDesiredFirstRoundDuration;
var bool bBalancing, bSaveNeeded;
var int FirstRoundResult;
var int MatchStartTS;

var float LastRestartTime;
var PlayerController LastRestarter, PotentiallyLeavingPlayer;
var array<string> CachedPlayerIDs;


replication
{
	reliable if (bNetInitial)
		MatchStartTS;
}


function SaveRecentPPH()
{
	if (bSaveNeeded) {
		if (EvenMatchMutator.bDebug)
			log(Level.TimeSeconds$ " Saving PPH data...", 'EvenMatchDebug');
		Recent.SaveConfig();
		RecentMap.SaveConfig();
	}
	bSaveNeeded = False;
}

/**
Purge outdated PPH data and randomly swap sides if configured.
*/
function PreBeginPlay()
{
	local int i, j, Diff;
	
	EvenMatchMutator = MutTeamBalance(Owner);
	
	if (!Level.Game.bEnableStatLogging || !Level.Game.bLoggingGame)
		RemoteRole = ROLE_SimulatedProxy;

	// remove obsolete entries
	MatchStartTS = GetTS();
	// generic part of PPH database
	Recent = new(None, "EvenMatchPPHDatabase") class'EvenMatchPPH';
	while (Recent.MyReplacementStatsID.Length > 0 && Recent.MyReplacementStatsID[0] == "") {
		// just a little cleanup from older EvenMatch versions
		Recent.MyReplacementStatsID.Remove(0, 1);
	}
	if (Recent.PPH.Length == 0) {
		// always create DB file
		bSaveNeeded = True;
	}
	else {
		// look for outdated entries
		for (i = Recent.PPH.Length - 1; i >= 0; --i) {
			Diff = MatchStartTS - Recent.PPH[i].TS;
			if (Diff / SECONDS_PER_DAY > EvenMatchMutator.DeletePlayerPPHAfterDaysNotSeen) {
				// older than X days
				Recent.PPH.Remove(i, 1);
				bSaveNeeded = True;
			}
		}
	}
	// map-specific part of PPH database
	RecentMap = new(None, string(Level.Outer)) class'EvenMatchPPH';
	if (RecentMap.PPH.Length == 0) {
		// always create map-specific entry
		bSaveNeeded = True;
	}
	else {
		// doesn't make sense to have map-specific data and no generic data for a particular player,
		// so discard all entries not matching a player in the generic PPH list
		for (i = RecentMap.PPH.Length - 1; i >= 0; --i) {
			j = Recent.FindPPHSlot(RecentMap.PPH[i].ID);
			if (j >= Recent.PPH.Length || RecentMap.PPH[i].ID != Recent.PPH[j].ID) {
				// not found
				RecentMap.PPH.Remove(i, 1);
				bSaveNeeded = True;
			}
		}
	}

	Game = ONSOnslaughtGame(Level.Game);
	if (Game != None) {
		AddToPackageMap();
		MinDesiredFirstRoundDuration = class'MutTeamBalance'.default.MinDesiredFirstRoundDuration * 60;
		Game.AddGameModifier(Self);
		if (class'MutTeamBalance'.default.bRandomlyStartWithSidesSwapped && Rand(2) == 0)
			SwapSides();
	}
	else {
		Destroy();
	}

	SaveRecentPPH();
}

simulated function PostNetBeginPlay()
{
	local PlayerController PC;
	
	if (Level.NetMode == NM_Client)
	{
		PC = Level.GetLocalPlayerController();
		if (PC == None)
			return;
		
		// we're here because the server doesn't know the player's stats identifier
		if (PC.StatsUsername != "" && PC.StatsPassword != "") {
			// player configured a stats name and password, use that,
			// as it will be the same when the server enables stats at some point
			PC.Mutate("EvenMatch SetPlayerId " $ MatchStartTS @ class'SHA1Hash'.static.GetStringHashString(Super(GameStats).GetStatsIdentifier(PC)));
		}
		else {
			// player hasn't configured stats, use a replacement ID,
			// which will be persisted until the player decides to configure stats
			Recent = new(None, "EvenMatchPPHDatabase") class'EvenMatchPPH';
			Recent.MyReplacementStatsID.Length = 1;
			if (Recent.MyReplacementStatsID[0] == "") {
				// no persisted replacement ID available, create a reasonably unique one
				Recent.MyReplacementStatsID[0] = "NoStats-"$class'SHA1Hash'.static.GetStringHashString(PC.GetPlayerIDHash() @ Level.Year @ Level.Month @ Level.Day @ Level.Hour @ Level.Minute @ Level.Second @ Level.Millisecond @ Rand(MaxInt));
				Recent.SaveConfig();
			}
			PC.Mutate("EvenMatch SetPlayerId " $ MatchStartTS @ Recent.MyReplacementStatsID[0]);
		}
	}
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
	local ONSPowerCore C;
	
	log("Using swapped sides...", 'EvenMatch');

	// This happens before ONSOnslaughtGame.PowerCores[] is set up!
	foreach AllActors(class'ONSPowerCore', C) {
		if (C.DefenderTeamIndex < 2) {
			C.DefenderTeamIndex = 1 - C.DefenderTeamIndex;
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
	if (class'MutTeamBalance'.default.bShuffleTeamsAtMatchStart) {
		log("Shuffling teams based on previous known PPH...", 'EvenMatch');
		ShuffleTeams();
		BroadcastLocalizedMessage(class'UnevenMessage', -1);
	}
}


/**
Check team balance right before a player respawns.
*/
function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string IncomingName)
{
	if (PlayerController(Player) != None && (LastRestarter != Player || LastRestartTime != Level.TimeSeconds) && EvenMatchMutator.IsBalancingActive()) {
		LastRestarter = PlayerController(Player);
		LastRestartTime = Level.TimeSeconds;

		if (EvenMatchMutator.bDebug) log(Level.TimeSeconds @ Player.GetHumanReadableName() $ " switched to " $ Player.PlayerReplicationInfo.Team.GetHumanReadableName(), 'EvenMatchDebug');
		EvenMatchMutator.CheckBalance(LastRestarter, False);
	}
	return Super.FindPlayerStart(Player, InTeam, IncomingName);
}


/**
Returns the current timestamp.
*/
function int GetTS()
{
	local int mon, year;

	mon = Level.Month - 2;
	year = Level.Year;
	if (mon <= 0) {    /* 1..12 -> 11,12,1..10 */
		mon += 12;    /* Puts Feb last since it has leap day */
		year -= 1;
	}
	return ((((year/4 - year/100 + year/400 + 367*mon/12 + Level.Day) + year*365 - 719499
				)*24 + Level.Hour /* now have hours */
			)*60 + Level.Minute  /* now have minutes */
		)*60 + Level.Second; /* finally seconds */
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
		if (!bBalancing) {
			// just update recent PPH values
			for (i = 0; i < Level.GRI.PRIArray.Length; ++i) {
				if (Level.GRI.PRIArray[i] != None && !Level.GRI.PRIArray[i].bOnlySpectator)
					GetPointsPerHour(Level.GRI.PRIArray[i]);
			}
		}
		return true;
	}
	if (Level.GRI.ElapsedTime < MinDesiredFirstRoundDuration && Level.GRI.Teams[0].Score + Level.GRI.Teams[1].Score > 0) {
		MinDesiredFirstRoundDuration = 0; // one restart is enough
		bBalancing = True;
		if (Level.GRI.Teams[0].Score > 0)
			FirstRoundResult = 1;
		else
			FirstRoundResult = 2;
		Tag = 'EndGame';

		log("Quick first round, shuffling teams...", 'EvenMatch');
		ShuffleTeams();
		BroadcastLocalizedMessage(class'UnevenMessage', 0,,, Level.GRI.Teams[FirstRoundResult-1]);

		// force round restart
		if (Level.Game.GameStats != None) {
			if (EvenMatchMutator.bDebug) log("Resetting team score stats...", 'EvenMatchDebug');
			if (Level.GRI.Teams[0].Score > 0)
				Level.Game.GameStats.TeamScoreEvent(0, -Level.GRI.Teams[0].Score, "reset");
			if (Level.GRI.Teams[1].Score > 0)
				Level.Game.GameStats.TeamScoreEvent(1, -Level.GRI.Teams[1].Score, "reset");
		}
		if (EvenMatchMutator.bDebug) log("Resetting team scores...", 'EvenMatchDebug');
		Level.GRI.Teams[0].Score = 0;
		Level.GRI.Teams[1].Score = 0;

		bBalancing = False;
		return true;
	}
	else {
		// just update recent PPH values
		for (i = 0; i < Level.GRI.PRIArray.Length; ++i) {
			if (Level.GRI.PRIArray[i] != None && !Level.GRI.PRIArray[i].bOnlySpectator)
				GetPointsPerHour(Level.GRI.PRIArray[i]);
		}
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
		if (EvenMatchMutator.bDebug) {
			if (PotentiallyLeavingPlayer == None)
				log("DEBUG: a player disconnected", 'EvenMatchDebug');
			else
				log("DEBUG: " $ PotentiallyLeavingPlayer.GetHumanReadableName() $ " became spectator", 'EvenMatchDebug');
		}
		EvenMatchMutator.CheckBalance(PotentiallyLeavingPlayer, True);
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
	local PlayerReplicationInfo PRI, PRI2;
	local array<PlayerReplicationInfo> PRIs, RedPRIs, BluePRIs;
	local array<float> PPHs;
	local int Index, OldNumBots, OldMinPlayers;
	local int Low, High, Middle;
	local float PPH, PPH2, RedPPH, BluePPH, TotalPPH;

	// complexity below documented in terms of n players and m stored PPH values
	
	OldNumBots = Game.NumBots + Game.RemainingBots;
	OldMinPlayers = Game.MinPlayers;
	Game.RemainingBots = 0;
	Game.MinPlayers    = 0;
	if (Game.NumBots > 0) {
		if (EvenMatchMutator.bDebug)
			log("Removing " $ Game.NumBots $ " bots for shuffling", 'EvenMatchDebug');
		Game.KillBots(Game.NumBots);
	}
	// find PRIs of active players and sort ascending by PPH
	if (Level.GRI.PRIArray.Length > 0) {
		Index = Level.GRI.PRIArray.Length - 1;
		do {
			PRI = Level.GRI.PRIArray[Index];
			if (!PRI.bOnlySpectator && PlayerController(PRI.Owner) != None && PlayerController(PRI.Owner).bIsPlayer) {
			
				PPH = GetPointsPerHour(PRI); // binary search O(log m)
				TotalPPH += PPH;
				if (EvenMatchMutator.bDebug)
					log(PRI.PlayerName @ PPH $ " PPH, currently on " $ PRI.Team.GetHumanReadableName(), 'EvenMatchDebug');
				
				// binary search O(log n)
				Low = 0;
				High = PRIs.Length;
				if (Low < High) do {
					Middle = (High + Low) / 2;
					if (PPHs[Middle] < PPH) // ascending by PPH
						Low = Middle + 1;
					else
						High = Middle;
				} until (Low >= High);
				
				// Insert can be considered O(1) here due to huge contant overhead and small actual n
				PRIs.Insert(Low, 1);
				PRIs[Low] = PRI;
				PPHs.Insert(Low, 1);
				PPHs[Low] = PPH;
			}
		} until (--Index < 0);
	} // entire if: O(n * (log n + log m))
	
	if (EvenMatchMutator.bDebug)
		log(PRIs.Length $ " players, combined PPH " $ TotalPPH $ ", balance target PPH per team " $ 0.5 * TotalPPH, 'EvenMatchDebug');
	
	// let the game re-add missing bots
	if (EvenMatchMutator.bDebug && OldNumBots > 0)
		log("Will re-add " $ OldNumBots $ " bots later", 'EvenMatchDebug');
	Game.RemainingBots = OldNumBots;
	Game.MinPlayers    = OldMinPlayers;

	// first balance team sizes
	if (EvenMatchMutator.bDebug) log("Balancing team sizes and PPH...", 'EvenMatchDebug');
	if (PPHs.Length > 0) {
		Index = PPHs.Length;
		if ((Index & 1) != 0) {
			PRI = PRIs[0];
			PPH = PPHs[0];
			if (Rand(2) == 0) {
				if (EvenMatchMutator.bDebug)
					log("Odd player count, randomly assigning " $ PRI.PlayerName $ " to red (" $ PPH $ " PPH)", 'EvenMatchDebug');
				
				RedPRIs[RedPRIs.Length] = PRI;
				RedPPH += PPH;
			}
			else {
				if (EvenMatchMutator.bDebug)
					log("Odd player count, randomly assigning " $ PRI.PlayerName $ " to blue (" $ PPH $ " PPH)", 'EvenMatchDebug');
				
				BluePRIs[BluePRIs.Length] = PRI;
				BluePPH += PPH;
			}
		}
	
		while (Index > 1) {
			PRI = PRIs[--Index];
			PPH = PPHs[Index];
			PRI2 = PRIs[--Index];
			PPH2 = PPHs[Index];
			// ascending sort, so PPH >= PPH2
			
			if (EvenMatchMutator.bDebug)
				log("Assigning " $ PRI.PlayerName $ " (" $ PPH $ " PPH) and " $ PRI2.PlayerName $ " (" $ PPH2 $ " PPH)", 'EvenMatchDebug');
			
			if (RedPPH > BluePPH) {
				RedPRIs[RedPRIs.Length] = PRI2;
				RedPPH += PPH2;
				BluePRIs[BluePRIs.Length] = PRI;
				BluePPH += PPH;
				
				if (EvenMatchMutator.bDebug)
					log(PRI.PlayerName $ " will be on blue (now " $ BluePPH $ " PPH), " $ PRI2.PlayerName $ " will be on red (now " $ RedPPH $ " PPH)", 'EvenMatchDebug');
			}
			else {
				RedPRIs[RedPRIs.Length] = PRI;
				RedPPH += PPH;
				BluePRIs[BluePRIs.Length] = PRI2;
				BluePPH += PPH2;
				
				if (EvenMatchMutator.bDebug)
					log(PRI.PlayerName $ " will be on red (now " $ RedPPH $ " PPH), " $ PRI2.PlayerName $ " will be on blue (now " $ BluePPH $ " PPH)", 'EvenMatchDebug');
			}
		}
	} // entire if: O(n)
	
	if (EvenMatchMutator.bDebug) {
		log("Red team size " $ RedPRIs.Length $ ", combined PPH " $ RedPPH, 'EvenMatchDebug');
		log("Blue team size " $ BluePRIs.Length $ ", combined PPH " $ BluePPH, 'EvenMatchDebug');
	}
	
	// apply team changes
	if (EvenMatchMutator.bDebug) log("Applying team changes...", 'EvenMatchDebug');
	for (Index = 0; Index < RedPRIs.Length; ++Index) {
		if (RedPRIs[Index].Team.TeamIndex != 0) {
			if (EvenMatchMutator.bDebug) log("Moving " $ RedPRIs[Index].PlayerName $ " to red", 'EvenMatchDebug');
			ChangeTeam(PlayerController(RedPRIs[Index].Owner), 0);
		}
	}
	for (Index = 0; Index < BluePRIs.Length; ++Index) {
		if (BluePRIs[Index].Team.TeamIndex != 1) {
			if (EvenMatchMutator.bDebug) log("Moving " $ BluePRIs[Index].PlayerName $ " to blue", 'EvenMatchDebug');
			ChangeTeam(PlayerController(BluePRIs[Index].Owner), 1);
		}
	}
	if (EvenMatchMutator.bDebug) log("Teams shuffled.", 'EvenMatchDebug');
}


function int FindPPHSlot(array<PlayerReplicationInfo> PRIs, float PPH)
{
	local int Low, High, Middle;

	Low = 0;
	High = PRIs.Length;
	if (Low < High) do {
		Middle = (High + Low) / 2;
		if (GetPointsPerHour(PRIs[Middle]) > PPH)
			Low = Middle + 1;
		else
			High = Middle;
	} until (Low >= High);
	
	return Low;
}

function ReceivedReplacementStatsId(PlayerController PC, string ReplacementID)
{
	if (!Level.Game.bEnableStatLogging || !Level.Game.bLoggingGame) {
		if (PC.PlayerReplicationInfo != None && (CachedPlayerIDs.Length <= PC.PlayerReplicationInfo.PlayerID || CachedPlayerIDs[PC.PlayerReplicationInfo.PlayerID] == "")) {
			CachedPlayerIDs[PC.PlayerReplicationInfo.PlayerID] = ReplacementID;
		}
	}
}

function float GetPointsPerHour(PlayerReplicationInfo PRI)
{
	local PlayerController PC;
	local string ID;
	local int Index, IndexMap;
	local float PPH, CurrentPPH, PastPPH, PastPPHMap;

	PC = PlayerController(PRI.Owner);
	if (PC != None) {
		// ID is SHA1 hash of stats identifier
		if (PC.PlayerReplicationInfo == None || CachedPlayerIDs.Length <= PC.PlayerReplicationInfo.PlayerID || CachedPlayerIDs[PC.PlayerReplicationInfo.PlayerID] == "") {
			ID = class'SHA1Hash'.static.GetStringHashString(Super(GameStats).GetStatsIdentifier(PC));
			if (PC.PlayerReplicationInfo != None)
				CachedPlayerIDs[PC.PlayerReplicationInfo.PlayerID] = ID;
		}
		else {
			ID = CachedPlayerIDs[PC.PlayerReplicationInfo.PlayerID];
		}
	}
	// calculate current PPH
	CurrentPPH = 3600 * FMax(PRI.Score, 0.1) / Max(Level.GRI.ElapsedTime - PRI.StartTime, 10);
	PastPPH = -1;
	PastPPHMap = -1;
	
	Index = Recent.FindPPHSlot(ID);
	IndexMap = RecentMap.FindPPHSlot(ID);
	
	if (Level.GRI.bMatchHasBegun && PRI.Score > EvenMatchMutator.PlayerMinScoreBeforeStoringPPH && Level.GRI.ElapsedTime - PRI.StartTime > EvenMatchMutator.PlayerGameSecondsBeforeStoringPPH) {
		PPH = CurrentPPH;
		
		// already scored, override score from earlier
		if (Index >= Recent.PPH.Length || Recent.PPH[Index].ID != ID) {
			Recent.PPH.Insert(Index, 1);
			Recent.PPH[Index].ID = ID;
			Recent.PPH[Index].PastPPH = -1;
			Recent.PPH[Index].CurrentPPH = PPH;
			Recent.PPH[Index].TS = MatchStartTS;
			bSaveNeeded = True;
		}
		else {
			if (Recent.PPH[Index].TS != MatchStartTS) {
				if (Recent.PPH[Index].PastPPH == -1)
					Recent.PPH[Index].PastPPH = Recent.PPH[Index].CurrentPPH;
				else // adjust generic PPH slower than map-specific
					Recent.PPH[Index].PastPPH = 0.32 * (2.125 * Recent.PPH[Index].PastPPH + Recent.PPH[Index].CurrentPPH);
				Recent.PPH[Index].TS = MatchStartTS;
				bSaveNeeded = True;
			}
			Recent.PPH[Index].CurrentPPH = PPH;
			if (Recent.PPH[Index].PastPPH != -1)
				PastPPH = Recent.PPH[Index].PastPPH;
		}
		
		// also update map-specific PPH
		if (IndexMap >= RecentMap.PPH.Length || RecentMap.PPH[IndexMap].ID != ID) {
			RecentMap.PPH.Insert(IndexMap, 1);
			RecentMap.PPH[IndexMap].ID = ID;
			RecentMap.PPH[IndexMap].PastPPH = -1;
			RecentMap.PPH[IndexMap].CurrentPPH = PPH;
			RecentMap.PPH[IndexMap].TS = MatchStartTS;
			bSaveNeeded = True;
		}
		else {
			if (RecentMap.PPH[IndexMap].TS != MatchStartTS) {
				if (RecentMap.PPH[IndexMap].PastPPH == -1)
					RecentMap.PPH[IndexMap].PastPPH = RecentMap.PPH[IndexMap].CurrentPPH;
				else
					RecentMap.PPH[IndexMap].PastPPH = 0.5 * (RecentMap.PPH[IndexMap].PastPPH + RecentMap.PPH[IndexMap].CurrentPPH);
				RecentMap.PPH[IndexMap].TS = MatchStartTS;
				bSaveNeeded = True;
			}
			RecentMap.PPH[IndexMap].CurrentPPH = PPH;
			if (RecentMap.PPH[IndexMap].PastPPH != -1)
				PastPPHMap = RecentMap.PPH[IndexMap].PastPPH;
		}
	}
	else {
		PPH = -1;
		if (Index < Recent.PPH.Length && Recent.PPH[Index].ID == ID) {
			// No score yet, use PPH from earlier
			PastPPH = Recent.PPH[Index].PastPPH;
		}
		if (IndexMap < RecentMap.PPH.Length && RecentMap.PPH[IndexMap].ID == ID) {
			// No score yet, use PPH from earlier
			PastPPHMap = RecentMap.PPH[IndexMap].PastPPH;
		}
	}
	
	// combine current and past PPH values in a meaningful way
	switch (int(PPH == -1) + 2 * int(PastPPH == -1) + 4 * int(PastPPHMap == -1)) {
		case 0: // all three PPH values available
			return 0.4 * (PPH + PastPPHMap + 0.5 * PastPPH);
			
		case 1: // no current (meaningful) score yet, but both past PPH available
			return 0.8 * (PastPPHMap + 0.25 * PastPPH);
			
		case 2: // no past generic PPH (should not be possible)
			return 0.5 * (PPH + PastPPHMap);
			
		case 3: // only past map-specific PPH (should not be possible either)
			return PastPPHMap;
			
		case 4: // no past map-specific PPH
			return 0.5 * (PPH + PastPPHMap);
			
		case 5: // only past generic PPH
			return PastPPH;
			
		case 6: // only current PPH (new player)
			return PPH;
			
		default: // none of the above (should not be possible)
			return CurrentPPH;
	}
}


function ChangeTeam(PlayerController Player, int NewTeam)
{
	Player.PlayerReplicationInfo.Team.RemoveFromTeam(Player);
	if (Level.GRI.Teams[NewTeam].AddToTeam(Player)) {
		Player.ReceiveLocalizedMessage(class'TeamSwitchNotification', NewTeam);
		ONSOnslaughtGame(Level.Game).GameEvent("TeamChange", string(NewTeam), Player.PlayerReplicationInfo);
	}
	
	EvenMatchMutator.PendingVoiceChatRoomChecks[EvenMatchMutator.PendingVoiceChatRoomChecks.Length] = Player;
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	bNetTemporary = True;
}
