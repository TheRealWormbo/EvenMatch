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


struct TPlayerPPH {
	var config string ID;
	var config float PastPPH;
	var config float CurrentPPH;
	var config int TS;
};
var config array<TPlayerPPH> RecentPPH;

var ONSOnslaughtGame Game;
var MutTeamBalance EvenMatchMutator;
var int MinDesiredFirstRoundDuration;
var bool bBalancing, bSaveNeeded;
var int FirstRoundResult;
var int MatchStartTS;

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
	local int i, Diff;

	// remove obsolete entries
	MatchStartTS = GetTS();
	for (i = RecentPPH.Length - 1; i >= 0; --i) {
		Diff = MatchStartTS - RecentPPH[i].TS;
		if (Diff > 172800) {
			// older than 2 days
			RecentPPH.Remove(i, 1);
			bSaveNeeded = True;
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
		SaveRecentPPH(); // store recent PPH values
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
		if (EvenMatchMutator.bDebug) log("Removing " $ Game.NumBots $ " bots for shuffling", 'EvenMatchDebug');
		Game.KillBots(Game.NumBots);
	}
	// find PRIs of active players
	if (Level.GRI.PRIArray.Length > 0) {
		i = Level.GRI.PRIArray.Length - 1;
		do {
			PRI = Level.GRI.PRIArray[i];
			if (!PRI.bOnlySpectator && PlayerController(PRI.Owner) != None && PlayerController(PRI.Owner).bIsPlayer) {
				PPH = GetPointsPerHour(PRI);
				switch (PRI.Team.TeamIndex) {
					case 0:
						if (EvenMatchMutator.bDebug) log(PRI.PlayerName $ " is currently on red, " $ PPH $ " PPH", 'EvenMatchDebug');
						j = FindPPHSlot(RedPRIs, PPH);
						RedPRIs.Insert(j, 1);
						RedPRIs[j] = PRI;
						RedPPH += PPH;
						break;
					case 1:
						if (EvenMatchMutator.bDebug) log(PRI.PlayerName $ " is currently on blue, " $ PPH $ " PPH", 'EvenMatchDebug');
						j = FindPPHSlot(BluePRIs, PPH);
						BluePRIs.Insert(j, 1);
						BluePRIs[j] = PRI;
						BluePPH += PPH;
						break;
				}
			}
		} until (--i < 0);
	}
	if (EvenMatchMutator.bDebug) {
		log("Red team size " $ RedPRIs.Length $ ", combined PPH " $ RedPPH, 'EvenMatchDebug');
		log("Blue team size " $ BluePRIs.Length $ ", combined PPH " $ BluePPH, 'EvenMatchDebug');
	}
	// let the game re-add missing bots
	if (EvenMatchMutator.bDebug && OldNumBots > 0)
		log("Will re-add " $ OldNumBots $ " bots later", 'EvenMatchDebug');
	Game.RemainingBots = OldNumBots;
	Game.MinPlayers    = OldMinPlayers;

	// first balance team sizes
	if (EvenMatchMutator.bDebug) log("Balancing team sizes...", 'EvenMatchDebug');
	while (RedPRIs.Length > 0 && RedPRIs.Length - BluePRIs.Length > 1) {
		// move a random red player to the blue team
		i = Rand(RedPRIs.Length);
		PPH = GetPointsPerHour(RedPRIs[i]);
		j = FindPPHSlot(BluePRIs, PPH);
		BluePRIs.Insert(j, 1);
		BluePRIs[j] = RedPRIs[i];
		BluePPH += PPH;
		RedPRIs.Remove(i, 1);
		RedPPH -= PPH;
		if (EvenMatchMutator.bDebug) log("-" @ BluePRIs[j].PlayerName $ " will move to blue (" $ PPH $ " PPH)", 'EvenMatchDebug');
	}
	while (BluePRIs.Length > 0 && BluePRIs.Length - RedPRIs.Length > 1) {
		// move a random blue player to the red team
		i = Rand(BluePRIs.Length);
		PPH = GetPointsPerHour(BluePRIs[i]);
		j = FindPPHSlot(RedPRIs, PPH);
		RedPRIs.Insert(j, 1);
		RedPRIs[j] = BluePRIs[i];
		RedPPH += PPH;
		BluePRIs.Remove(i, 1);
		BluePPH -= PPH;
		if (EvenMatchMutator.bDebug) log("-" @ RedPRIs[j].PlayerName $ " will move to red (" $ PPH $ " PPH)", 'EvenMatchDebug');
	}
	if (EvenMatchMutator.bDebug) {
		log("Red team size " $ RedPRIs.Length $ ", combined PPH " $ RedPPH, 'EvenMatchDebug');
		log("Blue team size " $ BluePRIs.Length $ ", combined PPH " $ BluePPH, 'EvenMatchDebug');
	}
	// now balance team skill
	if (EvenMatchMutator.bDebug) log("Balancing team PPH...", 'EvenMatchDebug');
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
			if (EvenMatchMutator.bDebug) log("Swapping " $ RedPRIs[iBest].PlayerName $ " (red) and " $ BluePRIs[jBest].PlayerName $ " (blue), PPH diff. " $ BestDiff, 'EvenMatchDebug');
			PRI = RedPRIs[iBest];
			RedPRIs[iBest] = BluePRIs[jBest];
			BluePRIs[jBest] = PRI;
			RedPPH  -= BestDiff;
			BluePPH += BestDiff;
		}
	} until (!bFoundPair);
	if (EvenMatchMutator.bDebug) {
		log("Red team size " $ RedPRIs.Length $ ", combined PPH " $ RedPPH, 'EvenMatchDebug');
		log("Blue team size " $ BluePRIs.Length $ ", combined PPH " $ BluePPH, 'EvenMatchDebug');
	}
	// apply team changes
	if (EvenMatchMutator.bDebug) log("Applying team changes...", 'EvenMatchDebug');
	for (i = 0; i < RedPRIs.Length; ++i) {
		if (RedPRIs[i].Team.TeamIndex != 0) {
			if (EvenMatchMutator.bDebug) log("Moving " $ RedPRIs[i].PlayerName $ " to red", 'EvenMatchDebug');
			ChangeTeam(PlayerController(RedPRIs[i].Owner), 0);
		}
	}
	for (i = 0; i < BluePRIs.Length; ++i) {
		if (BluePRIs[i].Team.TeamIndex != 1) {
			if (EvenMatchMutator.bDebug) log("Moving " $ BluePRIs[i].PlayerName $ " to blue", 'EvenMatchDebug');
			ChangeTeam(PlayerController(BluePRIs[i].Owner), 1);
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


function float GetPointsPerHour(PlayerReplicationInfo PRI)
{
	local PlayerController PC;
	local string ID;
	local int Low, High, Middle;
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
	
	High = RecentPPH.Length;
	if (Low < High) do {
		Middle = (High + Low) / 2;
		if (RecentPPH[Middle].ID < ID)
			Low = Middle + 1;
		else
			High = Middle;
	} until (Low >= High);
	
	if (PRI.Score > 0 && Level.GRI.ElapsedTime - PRI.StartTime > 30) {
		// already scored, override score from earlier
		if (Low >= RecentPPH.Length || RecentPPH[Low].ID != ID) {
			RecentPPH.Insert(Low, 1);
			RecentPPH[Low].ID = ID;
			RecentPPH[Low].PastPPH = -1;
			RecentPPH[Low].CurrentPPH = PPH;
			RecentPPH[Low].TS = MatchStartTS;
			bSaveNeeded = True;
		}
		else {
			if (RecentPPH[Low].TS != MatchStartTS) {
				if (RecentPPH[Low].PastPPH == -1)
					RecentPPH[Low].PastPPH = RecentPPH[Low].CurrentPPH;
				else
					RecentPPH[Low].PastPPH = 0.5 * (RecentPPH[Low].PastPPH + RecentPPH[Low].CurrentPPH);
				RecentPPH[Low].TS = MatchStartTS;
				bSaveNeeded = True;
			}
			RecentPPH[Low].CurrentPPH = PPH;
			if (RecentPPH[Low].PastPPH != -1)
				PPH = 0.5 * (RecentPPH[Low].PastPPH + RecentPPH[Low].CurrentPPH);
		}
	}
	else if (Low < RecentPPH.Length && RecentPPH[Low].ID == ID) {
		// No score yet, use PPH from earlier
		PPH = RecentPPH[Low].PastPPH;
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
