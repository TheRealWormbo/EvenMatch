/**
A team balancing mutator specifically designed for the Onslaught game mode.

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

class MutTeamBalance extends Mutator config;


var() const editconst string Build;


var config int ActivationDelay;
var config int MinDesiredFirstRoundDuration;
var config bool bShuffleTeamsAtMatchStart;
var config bool bRandomlyStartWithSidesSwapped;
var config bool bAssignConnectingPlayerTeam;
var config bool bIgnoreConnectingPlayerTeamPreference;
var config bool bAnnounceTeamChange;
var config bool bIgnoreBotsForTeamSize;
var config bool bBalanceTeamsBetweenRounds;
var config bool bBalanceTeamsWhilePlaying;
var config bool bBalanceTeamsDuringOvertime;
var config bool bBalanceTeamsOnPlayerRequest;
var config bool bBalanceTeamsOnAdminRequest;
var config bool bDisplayRoundProgressIndicator;
var config float SmallTeamProgressThreshold;
var config int SoftRebalanceDelay;
var config int ForcedRebalanceDelay;
var config float SwitchToWinnerProgressLimit;
var config byte ValuablePlayerRankingPct;
var config byte MinPlayerCount;
var config string TeamsCallString;
var config int DeletePlayerPPHAfterDaysNotSeen;

var config bool bDebug;

var localized string lblActivationDelay, descActivationDelay;
var localized string lblMinDesiredFirstRoundDuration, descMinDesiredFirstRoundDuration;
var localized string lblShuffleTeamsAtMatchStart, descShuffleTeamsAtMatchStart;
var localized string lblRandomlyStartWithSidesSwapped, descRandomlyStartWithSidesSwapped;
var localized string lblAssignConnectingPlayerTeam, descAssignConnectingPlayerTeam;
var localized string lblIgnoreConnectingPlayerTeamPreference, descIgnoreConnectingPlayerTeamPreference;
var localized string lblAnnounceTeamChange, descAnnounceTeamChange;
var localized string lblIgnoreBotsForTeamSize, descIgnoreBotsForTeamSize;
var localized string lblBalanceTeamsBetweenRounds, descBalanceTeamsBetweenRounds;
var localized string lblBalanceTeamsWhilePlaying, descBalanceTeamsWhilePlaying;
var localized string lblBalanceTeamsDuringOvertime, descBalanceTeamsDuringOvertime;
var localized string lblBalanceTeamsOnPlayerRequest, descBalanceTeamsOnPlayerRequest;
var localized string lblBalanceTeamsOnAdminRequest, descBalanceTeamsOnAdminRequest;
var localized string lblDisplayRoundProgressIndicator, descDisplayRoundProgressIndicator;
var localized string lblSmallTeamProgressThreshold, descSmallTeamProgressThreshold;
var localized string lblSoftRebalanceDelay, descSoftRebalanceDelay;
var localized string lblForcedRebalanceDelay, descForcedRebalanceDelay;
var localized string lblSwitchToWinnerProgressLimit, descSwitchToWinnerProgressLimit;
var localized string lblValuablePlayerRankingPct, descValuablePlayerRankingPct;
var localized string lblMinPlayerCount, descMinPlayerCount;
var localized string lblTeamsCallString, descTeamsCallString;
var localized string lblDeletePlayerPPHAfterDaysNotSeen, descDeletePlayerPPHAfterDaysNotSeen;


var ONSOnslaughtGame Game;
var EvenMatchRules Rules;
var EvenMatchReplicationInfo RepInfo;
var EvenMatchTeamsCallSpectator TeamsCallSpec;
var int SoftRebalanceCountdown, ForcedRebalanceCountdown;
var bool bBalancingRequested;
var int ForcedBalanceAttempt;

struct TRecentTeam {
	var PlayerController PC;
	var byte TeamNum, ForcedTeamNum;
	var float LastForcedSwitch;
};
var array<TRecentTeam> RecentTeams;


var Scoreboard PlayerSorter;


function PostBeginPlay()
{
	log(Class$" build "$Build, 'EvenMatch');

	Rules = Spawn(class'EvenMatchRules', Self);
	
	Game = ONSOnslaughtGame(Level.Game);
	if (bDisplayRoundProgressIndicator) {
		RepInfo = Spawn(class'EvenMatchReplicationInfo');
		RepInfo.EvenMatchMutator = Self;
		RepInfo.SetTimer(0.2, true);
	}
	if (Level.NetMode == NM_DedicatedServer && !PlatformIsWindows())
		ApplyLinuxDedicatedServerCrashFix();
}

function ApplyLinuxDedicatedServerCrashFix()
{
	local Actor A;
	
	log("Applying Emitter crash workaround for Linux dedicated servers...", 'EvenMatch');

	foreach AllActors(class'Actor', A) {
		if (A.bNoDelete && A.bNotOnDedServer) {
		
			// prevent engine from disabling bNoDelete and destroying the actor
			A.bNotOnDedServer = False;
			
			// hopefully retain some of the (probably neglible) performance gain intended by bNotOnDedServer
			A.bStasis = True;
		}
	}
}

function bool MutatorIsAllowed()
{
	return Level.Game.IsA('ONSOnslaughtGame') && Super.MutatorIsAllowed();
}

function MatchStarting()
{
	SetTimer(1.0, true);
	
	if (TeamsCallString != "") {
		TeamsCallSpec = Spawn(class'EvenMatchTeamsCallSpectator');
		if (TeamsCallSpec != None) {
			TeamsCallSpec.EvenMatchMutator = Self;
			TeamsCallSpec.TeamsCallString = TeamsCallString;
		}
	}
}

function Mutate(string MutateString, PlayerController Sender)
{
	if (MutateString ~= "teams") {
		HandleTeamsCall(Sender);
		return;
	}
	
	Super.Mutate(MutateString, Sender);
}

function HandleTeamsCall(PlayerController Sender)
{
	if (Sender != None && Sender.PlayerReplicationInfo != None) {
		if ((!Sender.PlayerReplicationInfo.bOnlySpectator && bBalanceTeamsOnPlayerRequest || bBalanceTeamsOnAdminRequest && (Sender.PlayerReplicationInfo.bAdmin || Level.Game.AccessControl != None && Level.Game.AccessControl.IsAdmin(Sender))) && SoftRebalanceCountdown != 0 && !bBalancingRequested && IsBalancingActive()) {
			if (RebalanceNeeded()) {
				bBalancingRequested = True;
				SoftRebalanceCountdown = 0;
				BroadcastLocalizedMessage(class'UnevenMessage', -2, Sender.PlayerReplicationInfo);
			}
			else {
				BroadcastLocalizedMessage(class'UnevenChatMessage', -4);
			}
		}
		else if (bBalanceTeamsOnPlayerRequest) {
			Sender.ReceiveLocalizedMessage(class'UnevenChatMessage', -3);
		}
	}
}

function bool IsBalancingActive()
{
	local int i, NumPlayers;

	for (i = 0; i < Level.GRI.PRIArray.Length && NumPlayers < MinPlayerCount; i++) {
		if (!Level.GRI.PRIArray[i].bOnlySpectator)
			NumPlayers++;
	}
	
	return Level.GRI.bMatchHasBegun && !Level.Game.bGameEnded && (bBalanceTeamsDuringOvertime || !Level.Game.bOverTime) && Game.ElapsedTime >= default.ActivationDelay && NumPlayers >= MinPlayerCount;
}


/**
Clear recent team number cache so players receive the team change notification
when they respawn at the start of the new round.
*/
function Reset()
{
	RecentTeams.Length = 0;
	
	if (bBalanceTeamsBetweenRounds)
		BalanceTeams();
}


function BalanceTeams()
{
	local PlayerReplicationInfo PRI;
	local int i, OldNumBots, OldMinPlayers;
	local int SizeDiff, TeamSizes[2];
	local byte BiggerTeam, LeadingTeam;

	for (i = 0; i < Level.GRI.PRIArray.Length; i++) {
		if (Level.GRI.PRIArray[i].Team != None && Level.GRI.PRIArray[i].Team.TeamIndex < 2 && (!bIgnoreBotsForTeamSize || !Level.GRI.PRIArray[i].bBot))
			TeamSizes[Level.GRI.PRIArray[i].Team.TeamIndex]++;
	}
	SizeDiff = TeamSizes[0] - TeamSizes[1];
	
	BiggerTeam = byte(SizeDiff < 0);
	LeadingTeam = byte(Level.GRI.Teams[0].Score <= Level.GRI.Teams[1].Score);
	
	if (SizeDiff == 0 || Abs(SizeDiff) == 1 && BiggerTeam != LeadingTeam)
		return; // no need to balance teams
	
	log("Teams are uneven at start of new round, rebalancing...", 'EvenMatch');
	
	OldNumBots = Game.NumBots + Game.RemainingBots;
	OldMinPlayers = Game.MinPlayers;
	Game.RemainingBots = 0;
	Game.MinPlayers    = 0;
	if (Game.NumBots > 0) {
		if (bDebug) log("Removing " $ Game.NumBots $ " bots for rebalancing", 'EvenMatchDebug');
		Game.KillBots(Game.NumBots);
	}
	
	SortPRIArray();
	if (SizeDiff < 0)
		SizeDiff = -SizeDiff;
	if (LeadingTeam != BiggerTeam)
		SizeDiff--; // smaller team did fine so far
	
	// find PRIs of active players
	for (i = Level.GRI.PRIArray.Length - 1; i >= 0; --i) {
		PRI = Level.GRI.PRIArray[i];
		if (!PRI.bOnlySpectator && PlayerController(PRI.Owner) != None && PlayerController(PRI.Owner).bIsPlayer) {
			if (PRI.Team.TeamIndex == BiggerTeam) {
				Rules.ChangeTeam(PlayerController(PRI.Owner), 1 - BiggerTeam);
				SizeDiff -= 2;
				if (SizeDiff <= 0)
					break;
			}
		}
	}
	
	// let the game re-add missing bots
	if (bDebug && OldNumBots > 0)
		log("Will re-add " $ OldNumBots $ " bots later", 'EvenMatchDebug');
	Game.RemainingBots = OldNumBots;
	Game.MinPlayers    = OldMinPlayers;
}


/**
Ensure new players balance teams if configured and rebalance is needed.
*/
function ModifyLogin(out string Portal, out string Options)
{
	local int RequestedTeam;
	local float Progress;
	local byte BiggerTeam, NewTeam;

	Super.ModifyLogin(Portal, Options);

	if (!bAssignConnectingPlayerTeam && !bIgnoreConnectingPlayerTeamPreference)
		return;

	RequestedTeam = Game.GetIntOption(Options, "team", 255);
	if (bAssignConnectingPlayerTeam) {
	
		if (!RebalanceNeeded(0, Progress, BiggerTeam) && !bIgnoreConnectingPlayerTeamPreference)
			return;
		
		if (BiggerTeam == 255)
			BiggerTeam = int(Progress >= 0.5);

		// force player to join the weaker team
		NewTeam = (1 - BiggerTeam);
	}
	else {
		// override team preference of the joining player
		NewTeam = 255;
	}
	
	if (RequestedTeam != NewTeam)
		log("Overriding player team preference team=" $ RequestedTeam $ " with team=" $ NewTeam, 'EvenMatch');
	
	// disable the player's team preference
	if (InStr(Locs(Options), "team="$RequestedTeam) != -1)
		Options = Repl(Options, "team="$RequestedTeam, "team="$NewTeam);
	else
		Options $= "?team="$NewTeam;
}


/**
Send notification after team change and remember the current team number.
*/
function ModifyPlayer(Pawn Other)
{
	local int i;
	local PlayerController PC;
	local Object AnnouncementDelayIndicator;

	Super.ModifyPlayer(Other);
	
	// send an optional object to delay team color announcement
	if (Level.GRI.ElapsedTime < 2)
		AnnouncementDelayIndicator = Level.GRI;

	PC = PlayerController(Other.Controller);
	if (PC != None) {
		// update cached team number for this player and potentially send team reminder
		for (i = 0; i < RecentTeams.Length && RecentTeams[i].PC != PC; ++i);
		if (i == RecentTeams.Length) {
			// add new player
			RecentTeams.Length = i + 1;
			RecentTeams[i].PC = PC;
			RecentTeams[i].TeamNum = 255;
		}
		if (RecentTeams[i].TeamNum != PC.GetTeamNum()) {
			Spawn(class'TeamChangeReplicationInfo', Other);
			if (bAnnounceTeamChange)
				PC.ReceiveLocalizedMessage(class'TeamSwitchNotification', PC.GetTeamNum(),,, AnnouncementDelayIndicator);
		}
		RecentTeams[i].TeamNum = PC.GetTeamNum();
	}
}


function RememberForcedSwitch(PlayerController PC, string Reason)
{
	local int i, Low, High, Middle;
	local TRecentTeam Entry;

	log("Forced team change: " $ PC.GetHumanReadableName() @ PC.PlayerReplicationInfo.Team.GetHumanReadableName() @ Reason, 'EvenMatch');
	PC.ReceiveLocalizedMessage(class'UnevenMessage', -5);

	// find entry
	for (i = 0; i < RecentTeams.Length && RecentTeams[i].PC != PC; ++i);

	if (i == RecentTeams.Length) {
		log("Not remembering " $ PC.GetHumanReadableName(), 'EvenMatch');
		return; // not found, nothing to update
	}

	Entry = RecentTeams[i];
	RecentTeams.Remove(i, 1);
	Entry.ForcedTeamNum = PC.GetTeamNum();
	Entry.LastForcedSwitch = Level.TimeSeconds;

	Low = 0;
	High = RecentTeams.Length;
	while (Low < High) {
		Middle = (High + Low) / 2; // the engine would crash long before this overflows
		if (RecentTeams[Middle].LastForcedSwitch > Entry.LastForcedSwitch)
			Low = Middle + 1;
		else
			High = Middle;
	}
	// found insert location
	RecentTeams.Insert(Low, 1);
	RecentTeams[Low] = Entry;
}


/**
Check if leaving player caused teams to become unbalanced.
*/
function NotifyLogout(Controller Exiting)
{
	Super.NotifyLogout(Exiting);

	if (PlayerController(Exiting) != None && Exiting.PlayerReplicationInfo != None && !Exiting.PlayerReplicationInfo.bOnlySpectator) {
		if (bDebug) log("DEBUG: " $ Exiting.GetHumanReadableName() $ " disconnected", 'EvenMatchDebug');
		Rules.SetTimer(0.0, false);
		CheckBalance(PlayerController(Exiting), True);
	}
}


/**
Check for soft or forced team rebalancing.
*/
function Timer()
{
	if (SoftRebalanceCountdown > 0)
		SoftRebalanceCountdown--;

	if (ForcedRebalanceCountdown > 0)
		ForcedRebalanceCountdown--;

	if (bBalancingRequested || SoftRebalanceCountdown == 0)
		ActuallyCheckBalance(None, False);
	else
		ForcedBalanceAttempt = 0;
	
	bBalancingRequested = False;
}


function SortPRIArray()
{
	local PlayerController PC;
	local class<Scoreboard> ScoreboardClass;

	if (PlayerSorter == None) {
		// if dedicated server, spawn a scoreboard that will sort players, otherwise use the existing scoreboard
		PC = Level.GetLocalPlayerController();
		if (PC != None && PC.MyHud != None && PC.MyHud.Scoreboard != None) {
			PlayerSorter = PC.MyHud.Scoreboard;
		}
		else {
			// find a player controller, any with a GRI reference will do
			foreach AllActors(class'PlayerController', PC) {
				if (PC.GameReplicationInfo != None)
					break;
			}
			ScoreboardClass = class<Scoreboard>(DynamicLoadObject(Level.Game.ScoreBoardType, class'Class'));
			if (ScoreboardClass != None)
				PlayerSorter = Spawn(ScoreboardClass, PC);

			if (PlayerSorter != None && PlayerSorter.GRI == None)
				PlayerSorter.GRI = Level.GRI;
		}
	}

	if (PlayerSorter != None)
		PlayerSorter.SortPRIArray();
}


/**
Check team balance and potentially switch players.
*/
function CheckBalance(PlayerController Player, bool bIsLeaving)
{
	if (!bBalanceTeamsWhilePlaying || Level.Game.bOverTime && !bBalanceTeamsDuringOvertime)
		return;

	ActuallyCheckBalance(Player, bIsLeaving);
}

function ActuallyCheckBalance(PlayerController Player, bool bIsLeaving)
{
	local int i, SizeOffset;
	local bool bFound;
	local byte BiggerTeam;
	local array<PlayerController> Candidates;
	local Controller C;
	local float Progress;
	
	SortPRIArray();

	if (Player != None && bIsLeaving) {
		switch (Player.GetTeamNum()) {
		case 0:
			SizeOffset = -1;
			break;
		case 1:
			SizeOffset = +1;
		}
	}

	// check if player changed team
	for (i = 0; i < RecentTeams.Length; ++i) {
		if (RecentTeams[i].PC == Player) {
			bFound = True;
		}
		if (RecentTeams[i].PC == None || bIsLeaving && RecentTeams[i].PC == Player || RecentTeams[i].PC.PlayerReplicationInfo != None && RecentTeams[i].PC.PlayerReplicationInfo.bOnlySpectator) {
			// player left the game
			RecentTeams.Remove(i--, 1);
		}
		else if (RecentTeams[i].PC.GetTeamNum() != RecentTeams[i].TeamNum) {
			RecentTeams[i].TeamNum = 255; // keep considering the player until respawn
			Candidates[Candidates.Length] = RecentTeams[i].PC;
			if (bDebug) log(Level.TimeSeconds $ " Initial balancing candidate: " $ RecentTeams[i].PC.GetHumanReadableName(), 'EvenMatchDebug');
		}
	}
	if (!bFound && !bIsLeaving && Player != None) {
		RecentTeams.Length = i + 1;
		RecentTeams[i].PC = Player;
		RecentTeams[i].TeamNum = 255; // consider the new player for team changes until respawn
		Candidates[Candidates.Length] = Player;
		if (bDebug) log(Level.TimeSeconds $ " Additional initial balancing candidate: " $ Player.GetHumanReadableName() $ " (triggered the check)", 'EvenMatchDebug');
	}

	if (RebalanceNeeded(SizeOffset, Progress, BiggerTeam)) {
		if (SoftRebalanceCountdown < 0) {
			log("Teams have become uneven, soft balance in " $ SoftRebalanceDelay $ "s", 'EvenMatch');
			SoftRebalanceCountdown = SoftRebalanceDelay;
			ForcedRebalanceCountdown = -1; // not yet!
		}
		if (Candidates.Length > 0 && (SoftRebalanceCountdown == 0 || Abs(1 - BiggerTeam - Progress) > SwitchToWinnerProgressLimit)) {
			// there are players who switched teams but have not yet respawned
			do {
				// try switching a random team changer to the smaller team
				i = Rand(Candidates.Length);
				if ((!bIsLeaving || Candidates[i] != Player) && Candidates[i].GetTeamNum() == BiggerTeam && !IsRecentBalancer(Candidates[i])) {
					Game.ChangeTeam(Candidates[i], 1 - BiggerTeam, true);
					RememberForcedSwitch(Candidates[i], "soft-balance by undoing team switch");
				}
				Candidates.Remove(i, 1);
			} until (Candidates.Length == 0 || !RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam));
		}
		
		if (SoftRebalanceCountdown == 0) {
			if (ForcedRebalanceCountdown < 0 && ForcedRebalanceDelay > 0) {
				BroadcastLocalizedMessage(class'UnevenChatMessage', 3);
			}
			if (Candidates.Length == 0 && RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
				// try to find other candidates currently waiting to respawn
				if (bDebug) log(Level.TimeSeconds $ " Not enough soft balancing candidates", 'EvenMatchDebug');
				for (C = Level.ControllerList; C != None; C = C.NextController) {
					if ((!bIsLeaving || C != Player) && PlayerController(C) != None && C.Pawn == None && C.GetTeamNum() == BiggerTeam && !IsRecentBalancer(C)) {
						Candidates[Candidates.Length] = PlayerController(C);
						if (bDebug) log(Level.TimeSeconds $ " Additional soft balancing candidate: " $ C.GetHumanReadableName(), 'EvenMatchDebug');
					}
				}
				while (Candidates.Length > 0 && RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
					// try switching a random candidate to the smaller team
					i = Rand(Candidates.Length);
					if (!IsValuablePlayer(Candidates[i])) {
						Game.ChangeTeam(Candidates[i], 1 - BiggerTeam, true);
						RememberForcedSwitch(Candidates[i], "soft-balance at respawn");
					}
					Candidates.Remove(i, 1);
				}
			}
			if (Candidates.Length == 0 && RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
				if (ForcedRebalanceCountdown < 0) {
					log("Teams are uneven, forced balance in " $ ForcedRebalanceDelay $ "s", 'EvenMatch');
					ForcedRebalanceCountdown = ForcedRebalanceDelay;
				}
				
				if (ForcedRebalanceCountdown % 10 == 0 && ForcedRebalanceCountdown < ForcedRebalanceDelay)
					BroadcastLocalizedMessage(class'UnevenChatMessage', ForcedRebalanceCountdown / 10 + 4);

				if (ForcedRebalanceCountdown == 0) {
					// time is up, random alive players on the bigger team will be switched to the smaller team
					for (C = Level.ControllerList; C != None; C = C.NextController) {
						if ((!bIsLeaving || C != Player) && PlayerController(C) != None && C.GetTeamNum() == BiggerTeam && !IsKeyPlayer(C)) {
							Candidates[Candidates.Length] = PlayerController(C);
							if (bDebug) log(Level.TimeSeconds $ " Forced balancing candidate: " $ C.GetHumanReadableName(), 'EvenMatchDebug');
						}
					}
					while (Candidates.Length > 0 && RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
						// try switching a random candidate to the smaller team
						i = Rand(Candidates.Length);
						Game.ChangeTeam(Candidates[i], 1 - BiggerTeam, true);
						RememberForcedSwitch(Candidates[i], "forced balance");
						if (Candidates[i].Pawn != None) {
							if (Vehicle(Candidates[i].Pawn) != None && Vehicle(Candidates[i].Pawn).Driver != None)
								Vehicle(Candidates[i].Pawn).Driver.Died(None, class'DamTypeTeamChange', Vehicle(Candidates[i].Pawn).Driver.Location);
							else if (XPawn(Candidates[i].Pawn) != None)
								Candidates[i].Pawn.Died(None, class'DamTypeTeamChange', Candidates[i].Pawn.Location);
							else // maybe also do special handling for redeemer?
								Candidates[i].Pawn.PlayerChangedTeam();
						}
						Candidates.Remove(i, 1);
					}
					ForcedBalanceAttempt++;
				}
			}
			else if (SoftRebalanceCountdown >= 0) {
				SoftRebalanceCountdown   = -1;
				ForcedRebalanceCountdown = -1;
				ForcedBalanceAttempt     =  0;
			}
		}
	}
	else if (SoftRebalanceCountdown >= 0) {
		SoftRebalanceCountdown   = -1;
		ForcedRebalanceCountdown = -1;
		ForcedBalanceAttempt     =  0;

		// no rebalance needed, but check if players changed to winning team
		if (SwitchToWinnerProgressLimit < 1.0 && !bIsLeaving) {
			// Candidates[] contains team switchers who didn't respawn yet
			while (Candidates.Length > 0) {
				i = Rand(Candidates.Length);
				SizeOffset = 4 * Candidates[i].GetTeamNum() - 2; // red -2, blue +2
				if (!IsRecentBalancer(Candidates[i]) && Abs(1 - Candidates[i].GetTeamNum() - Progress) > SwitchToWinnerProgressLimit && !RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
					// try switching the team changer back to his previous team
					Game.ChangeTeam(Candidates[i], 1 - Candidates[i].GetTeamNum(), true);
					RememberForcedSwitch(Candidates[i], "undoing switch to winning team");
				}
				Candidates.Remove(i, 1);
			}
		}
	}
}


function bool IsValuablePlayer(Controller C)
{
	local int i;
	local int rank, teamsize;
	local bool bFound;

	if (C.PlayerReplicationInfo == None)
		return false;

	// if successive attempts fail, consider more players
	rank = -ForcedBalanceAttempt;
	for (i = 0; i < Level.GRI.PRIArray.Length; i++) {
		if (Level.GRI.PRIArray[i].Team == C.PlayerReplicationInfo.Team) {
			if (!bFound && !Level.GRI.PRIArray[i].bBot)
				rank++;
			if (!bIgnoreBotsForTeamSize || !Level.GRI.PRIArray[i].bBot)
				teamsize++;
		}
		if (Level.GRI.PRIArray[i] == C.PlayerReplicationInfo) {
			bFound = True;
		}
	}
	return 100 * rank >= ValuablePlayerRankingPct * teamsize;
}


function bool RebalanceNeeded(optional int SizeOffset, optional out float Progress, optional out byte BiggerTeam)
{
	Progress = GetTeamProgress();
	return RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam) && IsBalancingActive();
}


function bool RebalanceStillNeeded(int SizeOffset, float Progress, optional out byte BiggerTeam)
{
	local int SizeDiff, TeamSizes[2];
	local int i;

	if (bIgnoreBotsForTeamSize) {
		for (i = 0; i < Level.GRI.PRIArray.Length; i++) {
			if (Level.GRI.PRIArray[i].Team != None && Level.GRI.PRIArray[i].Team.TeamIndex < 2 && (!bIgnoreBotsForTeamSize || !Level.GRI.PRIArray[i].bBot))
				TeamSizes[Level.GRI.PRIArray[i].Team.TeamIndex]++;
		}
		SizeDiff = TeamSizes[0] - TeamSizes[1];
	}
	else {
		SizeDiff = Level.GRI.Teams[0].Size - Level.GRI.Teams[1].Size + SizeOffset;
	}

	// > 0 if red is larger, < 0 if blue is larger
	if (SizeDiff == 0) {
		BiggerTeam = 255;
		return false; // same size, don't rebalance
	}
	BiggerTeam = byte(SizeDiff < 0); // 0 if red is larger, 1 if blue is larger

	return Abs(BiggerTeam - Progress) < SmallTeamProgressThreshold ** Sqrt(1 / Abs(SizeDiff));
}


/**
Returns a value between 0 and 1, indicating which team has made more progress so far.
*/
function float GetTeamProgress()
{
	local int TeamNum, i;
	local int MinEnemyCoreDist[2];
	local int NumNodes[2];
	local float CoreHealth[2];
	local float NodeHealth[2];
	local float Progress[2];
	local ONSPowerCore Node;
	
	for (TeamNum = 0; TeamNum < 2; TeamNum++) {
		Node = Game.PowerCores[Game.FinalCore[TeamNum]];
		MinEnemyCoreDist[TeamNum] = Node.FinalCoreDistance[1 - TeamNum];
		CoreHealth[TeamNum] = float(Node.Health) / Node.DamageCapacity;
		
		//log(Level.TimeSeconds @ TeamNum $ " - Core dist: " $ MinEnemyCoreDist[TeamNum] $ " Core health: " $ CoreHealth[TeamNum]);
	}
	
	for (i = 0; i < Game.PowerCores.Length; ++i) {
		Node = Game.PowerCores[i];
		if (!Node.bFinalCore && Node.DefenderTeamIndex < 2) {
			if (Node.CoreStage == 0 && !Node.bSevered) {
				NumNodes[Node.DefenderTeamIndex]++;
				
				MinEnemyCoreDist[Node.DefenderTeamIndex] = Min(MinEnemyCoreDist[Node.DefenderTeamIndex], Node.FinalCoreDistance[1 - Node.DefenderTeamIndex]);
			}
			
			if (Node.CoreStage == 0 && !Node.bSevered && !Node.PoweredBy(1 - Node.DefenderTeamIndex)) {
				NodeHealth[Node.DefenderTeamIndex] += 1.0; // ignore actual health if node is save
			}
			else {
				NodeHealth[Node.DefenderTeamIndex] += float(Node.Health) / Node.DamageCapacity;
			}
		}
	}
	
	
	for (TeamNum = 0; TeamNum < 2; TeamNum++) {
		//log(Level.TimeSeconds @ TeamNum $ " - Num nodes: " $ NumNodes[TeamNum] $ " Node health: " $ NodeHealth[TeamNum] $ " Min core dist: " $ MinEnemyCoreDist[TeamNum]);
		
		Progress[TeamNum] = CoreHealth[TeamNum] * Sqrt(MinEnemyCoreDist[1 - TeamNum]);
		Progress[TeamNum] += (NumNodes[TeamNum] + 0.5 * NodeHealth[TeamNum]) / MinEnemyCoreDist[TeamNum];
		
		if (Game.bOverTime || MinEnemyCoreDist[1 - TeamNum] == 1)
			Progress[TeamNum] *= CoreHealth[TeamNum];
		
		if (MinEnemyCoreDist[TeamNum] == 1)
			Progress[TeamNum] /= CoreHealth[1 - TeamNum];
	}
	
	//log(Level.TimeSeconds $ " - Total progress: " $ Progress[0] @ Progress[1] @ Progress[1] / (Progress[0] + Progress[1]));

	// return red team's share of total progress
	return Progress[1] / (Progress[0] + Progress[1]);
}


function bool IsRecentBalancer(Controller C)
{
	local int i;

	i = (RecentTeams.Length + 2) / 3;
	if (i > 0) {
		do {} until (--i < 0 || RecentTeams[i].PC == C);
	}
	else {
		i--;
	}
	return i >= 0 && RecentTeams[i].LastForcedSwitch > 0 && Level.TimeSeconds - RecentTeams[i].LastForcedSwitch < 60 && RecentTeams[i].ForcedTeamNum == C.GetTeamNum();
}

function bool IsKeyPlayer(Controller C)
{
	local Pawn P;
	local int i;
	local float Dist, BestDist;
	local ONSPowerCore BestNode;
	local byte TeamNum;

	if (ForcedBalanceAttempt < 7 && IsValuablePlayer(C))
		return true; // is a top scorer
	
	P = C.Pawn;
	if (P == None || P.Health <= 0)
		return false; // is dead, so not a key player

	if (ForcedBalanceAttempt < 2 && P.HasUDamage() && (xPawn(P) == None || xPawn(P).UDamageTime > 5))
		return true;
		
	if (ForcedBalanceAttempt < 3 && HasSuperWeapon(P))
		return true;
	
	if (ForcedBalanceAttempt < 4 && LinkGun(P.Weapon) != None && LinkGun(P.Weapon).Linking)
		return true; // is healing stuff
	
	if (Vehicle(P) != None) {
		if (ForcedBalanceAttempt < 5 && Vehicle(P).HasOccupiedTurret())
			return true; // driving vehicle with passenger
			
		if (ForcedBalanceAttempt < 6 && Vehicle(P).ImportantVehicle())
			return true; // driving a tank or other important vehicle
	}

	if (ForcedBalanceAttempt < 1) {
		BestDist = 2000;
		TeamNum = C.GetTeamNum();
		for (i = 0; i < Game.PowerCores.Length; ++i) {
			if (Level.TimeSeconds - Game.PowerCores[i].LastAttackTime < 1.0 && Game.PowerCores[i].LastAttacker == C.Pawn)
				return true; // player is currently attacking this node/core

			if (Level.TimeSeconds - Game.PowerCores[i].HealingTime < 0.5 && Game.PowerCores[i].LastHealedBy == C)
				return true; // player currently heals a node

			Dist = VSize(P.Location - Game.PowerCores[i].Location);
			if (Dist < BestDist && IsNodeRelevantTo(TeamNum, Game.PowerCores[i])) {
				BestDist = Dist;
				BestNode = Game.PowerCores[i];
			}
		}
	}
	return BestNode != None && (BestNode.DefenderTeamIndex == 1 - TeamNum || BestNode.bUnderAttack);
}

function bool HasSuperWeapon(Pawn P)
{
	local Inventory Inv;
	
	for (Inv = P.Inventory; Inv != None; Inv = Inv.Inventory) {
		if (Weapon(Inv) != None && Weapon(Inv).InventoryGroup == 0 && Weapon(Inv).HasAmmo())
			return true;
	}
	
	return false;
}

function bool IsNodeRelevantTo(byte TeamNum, ONSPowerCore Node)
{
	if (Node.CoreStage == 255)
		return false; // disabled node

	if (!Node.PoweredBy(TeamNum) && Node.DefenderTeamIndex != TeamNum)
		return false; // node neither owned nor attackable by team

	// relevant if node is vulnerable or not yet constructed
	return Node.PoweredBy(1 - TeamNum) || Node.CoreStage != 0;
}


static function FillPlayInfo(PlayInfo PlayInfo)
{
	if (AlreadyIsInPlayInfo(PlayInfo))
		return;

	Super.FillPlayInfo(PlayInfo);

	PlayInfo.AddSetting(default.FriendlyName, "ActivationDelay", default.lblActivationDelay, 0, 0, "Text", "3;0:999");
	PlayInfo.AddSetting(default.FriendlyName, "MinDesiredFirstRoundDuration", default.lblMinDesiredFirstRoundDuration, 0, 0, "Text", "3;0:999");
	PlayInfo.AddSetting(default.FriendlyName, "bShuffleTeamsAtMatchStart", default.lblShuffleTeamsAtMatchStart, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bRandomlyStartWithSidesSwapped", default.lblRandomlyStartWithSidesSwapped, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bAssignConnectingPlayerTeam", default.lblAssignConnectingPlayerTeam, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bIgnoreConnectingPlayerTeamPreference", default.lblIgnoreConnectingPlayerTeamPreference, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bAnnounceTeamChange", default.lblAnnounceTeamChange, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bIgnoreBotsForTeamSize", default.lblIgnoreBotsForTeamSize, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bBalanceTeamsBetweenRounds", default.lblBalanceTeamsBetweenRounds, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bBalanceTeamsWhilePlaying", default.lblBalanceTeamsWhilePlaying, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bBalanceTeamsDuringOvertime", default.lblBalanceTeamsDuringOvertime, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bBalanceTeamsOnPlayerRequest", default.lblBalanceTeamsOnPlayerRequest, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bBalanceTeamsOnAdminRequest", default.lblBalanceTeamsOnAdminRequest, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bDisplayRoundProgressIndicator", default.lblDisplayRoundProgressIndicator, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "SmallTeamProgressThreshold", default.lblSmallTeamProgressThreshold, 0, 0, "Text", "4;0.0:1.0");
	PlayInfo.AddSetting(default.FriendlyName, "SoftRebalanceDelay", default.lblSoftRebalanceDelay, 0, 0, "Text", "3;0:999");
	PlayInfo.AddSetting(default.FriendlyName, "ForcedRebalanceDelay", default.lblForcedRebalanceDelay, 0, 0, "Text", "3;0:999");
	PlayInfo.AddSetting(default.FriendlyName, "SwitchToWinnerProgressLimit", default.lblSwitchToWinnerProgressLimit, 0, 0, "Text", "4;0.0:1.0");
	PlayInfo.AddSetting(default.FriendlyName, "ValuablePlayerRankingPct", default.lblValuablePlayerRankingPct, 0, 0, "Text", "2;0:90");
	PlayInfo.AddSetting(default.FriendlyName, "MinPlayerCount", default.lblMinPlayerCount, 0, 0, "Text", "2;1:32");
	PlayInfo.AddSetting(default.FriendlyName, "TeamsCallString", default.lblTeamsCallString, 0, 0, "Text", "40");
	PlayInfo.AddSetting(default.FriendlyName, "DeletePlayerPPHAfterDaysNotSeen", default.lblDeletePlayerPPHAfterDaysNotSeen, 0, 0, "Text", "3;1:999");

	PlayInfo.PopClass();
}

static final function bool AlreadyIsInPlayInfo(PlayInfo PlayInfo)
{
	local int i;

	if (PlayInfo != None) {
		for (i = 0; i < PlayInfo.InfoClasses.Length; ++i) {
			if (PlayInfo.InfoClasses[i] == default.Class)
				return true;
		}
	}
	return false;
}

/**
Returns a description text for the specified property.
*/
static event string GetDescriptionText(string PropName)
{
	switch (PropName) {
	case "ActivationDelay":
		return default.descActivationDelay;
	case "MinDesiredFirstRoundDuration":
		return default.descMinDesiredFirstRoundDuration;
	case "bShuffleTeamsAtMatchStart":
		return default.descShuffleTeamsAtMatchStart;
	case "bRandomlyStartWithSidesSwapped":
		return default.descRandomlyStartWithSidesSwapped;
	case "bAssignConnectingPlayerTeam":
		return default.descAssignConnectingPlayerTeam;
	case "bIgnoreConnectingPlayerTeamPreference":
		return default.descIgnoreConnectingPlayerTeamPreference;
	case "bAnnounceTeamChange":
		return default.descAnnounceTeamChange;
	case "bIgnoreBotsForTeamSize":
		return default.descIgnoreBotsForTeamSize;
	case "bBalanceTeamsBetweenRounds":
		return default.descBalanceTeamsBetweenRounds;
	case "bBalanceTeamsWhilePlaying":
		return default.descBalanceTeamsWhilePlaying;
	case "bBalanceTeamsDuringOvertime":
		return default.descBalanceTeamsDuringOvertime;
	case "bBalanceTeamsOnPlayerRequest":
		return default.descBalanceTeamsOnPlayerRequest;
	case "bBalanceTeamsOnAdminRequest":
		return default.descBalanceTeamsOnAdminRequest;
	case "bDisplayRoundProgressIndicator":
		return default.descDisplayRoundProgressIndicator;
	case "SmallTeamProgressThreshold":
		return default.descSmallTeamProgressThreshold;
	case "SoftRebalanceDelay":
		return default.descSoftRebalanceDelay;
	case "ForcedRebalanceDelay":
		return default.descForcedRebalanceDelay;
	case "SwitchToWinnerProgressLimit":
		return default.descSwitchToWinnerProgressLimit;
	case "ValuablePlayerRankingPct":
		return default.descValuablePlayerRankingPct;
	case "MinPlayerCount":
		return default.descMinPlayerCount;
	case "TeamsCallString":
		return default.descTeamsCallString;
	case "DeletePlayerPPHAfterDaysNotSeen":
		return default.descDeletePlayerPPHAfterDaysNotSeen;
	default:
		return Super.GetDescriptionText(PropName);
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	Build = "%%%%-%%-%% %%:%%"
	FriendlyName = "Team Balance (Onslaught-only)"
	Description  = "Special team balancing rules for public Onslaught matches."
	bAddToServerPackages = True

	ActivationDelay                       = 10
	MinDesiredFirstRoundDuration          = 5
	bShuffleTeamsAtMatchStart             = True
	bRandomlyStartWithSidesSwapped        = True
	bAssignConnectingPlayerTeam           = True
	bIgnoreConnectingPlayerTeamPreference = True
	bAnnounceTeamChange                   = True
	bIgnoreBotsForTeamSize                = True
	bBalanceTeamsBetweenRounds            = True
	bBalanceTeamsWhilePlaying             = True
	bBalanceTeamsDuringOvertime           = False
	bBalanceTeamsOnPlayerRequest          = True
	bBalanceTeamsOnAdminRequest           = True
	bDisplayRoundProgressIndicator        = False
	SmallTeamProgressThreshold            = 0.3
	SoftRebalanceDelay                    = 10
	ForcedRebalanceDelay                  = 30
	SwitchToWinnerProgressLimit           = 0.6
	ValuablePlayerRankingPct              = 50
	MinPlayerCount                        = 2
	TeamsCallString                       = ""
	DeletePlayerPPHAfterDaysNotSeen       = 30
	
	bDebug = True
	
	SoftRebalanceCountdown   = -1
	ForcedRebalanceCountdown = -1

	lblActivationDelay  = "Activation delay"
	descActivationDelay = "Team balance checks only start after this number of seconds elapsed in the match."

	lblMinDesiredFirstRoundDuration  = "Minimum desired first round length (minutes)"
	descMinDesiredFirstRoundDuration = "If the first round is shorter than this number of minutes, scores are reset and the round is restarted with shuffled teams."

	lblShuffleTeamsAtMatchStart  = "Shuffle teams at match start"
	descShuffleTeamsAtMatchStart = "Initially assign players to teams based on PPH from the previous match to achieve even teams."

	lblRandomlyStartWithSidesSwapped  = "Randomly start with sides swapped"
	descRandomlyStartWithSidesSwapped = "Initially swap team bases randomly in 50% of matches."

	lblAssignConnectingPlayerTeam  = "Assign connecting player's team"
	descAssignConnectingPlayerTeam = "Override the team preference of a connecting player to balance team sizes."

	lblIgnoreConnectingPlayerTeamPreference  = "Ignore connecting player team preference"
	descIgnoreConnectingPlayerTeamPreference = "Ignore player preferences for a team color, allowing the game or Even Match to pick a team."

	lblAnnounceTeamChange  = "Announce team change"
	descAnnounceTeamChange = "Players receive a reminder message of their team color whenever they respawn in a different team."

	lblIgnoreBotsForTeamSize  = "Ignore bots for team size"
	descIgnoreBotsForTeamSize = "Don't count bots when comparing team sizes."

	lblBalanceTeamsBetweenRounds  = "Balance teams between rounds"
	descBalanceTeamsBetweenRounds = "Balance team sizes when a new round starts."

	lblBalanceTeamsWhilePlaying  = "Automatically balance teams while playing"
	descBalanceTeamsWhilePlaying = "Apply balancing during a round if the game becomes one-sided due to team size differences."

	lblBalanceTeamsDuringOvertime  = "Allow balance teams during overtime"
	descBalanceTeamsDuringOvertime = "Whether to allow team balancing after overtime started. Applies to automatic and player-requested balancing."

	lblBalanceTeamsOnPlayerRequest  = "Allow balance teams on player request"
	descBalanceTeamsOnPlayerRequest = "Whether to allow players to balance teams via 'mutate teams' or the configured teams call chat text."

	lblBalanceTeamsOnAdminRequest  = "Allow balance teams on admin request"
	descBalanceTeamsOnAdminRequest = "Whether to allow admins to balance teams via 'mutate teams' or the configured teams call chat text."

	lblDisplayRoundProgressIndicator  = "Display round progress indicator"
	descDisplayRoundProgressIndicator = "Displays a HUD gauge indicating, how close to victory either team seems to be. (This isn't a team balance indicator!)"

	lblSmallTeamProgressThreshold  = "Small team progress threshold"
	descSmallTeamProgressThreshold = "Switch players from the bigger team if the smaller team has less than this share of the total match progress."

	lblSoftRebalanceDelay  = "Soft rebalance delay"
	descSoftRebalanceDelay = "If teams stay unbalanced longer than this this, respawning players are switched to achieve rebalance."

	lblForcedRebalanceDelay  = "Forced rebalance delay"
	descForcedRebalanceDelay = "If teams stay unbalanced longer than this this, alive players are switched to achieve rebalance."

	lblSwitchToWinnerProgressLimit  = "Switch to winner progress limit"
	descSwitchToWinnerProgressLimit = "Only allow players to switch teams if their new team has less than this share of the total match progress. (1.0: no limit)"

	lblValuablePlayerRankingPct  = "Valuable player ranking %"
	descValuablePlayerRankingPct = "If players rank higher than percentage of the team (not counting bots), they are considered too valuable to be switched during rebalancing."

	lblMinPlayerCount  = "Minimum player count"
	descMinPlayerCount = "Minimum player count required before doing any kind of balancing."

	lblTeamsCallString  = "Teams call chat text"
	descTeamsCallString = "Players can 'say' this text in the chat to manually trigger a team balance check as alternative to the console command 'mutate teams'."

	lblDeletePlayerPPHAfterDaysNotSeen  = "Delete a player's PPH after X days inactivity"
	descDeletePlayerPPHAfterDaysNotSeen = "To keep PPH data from piling up indefinitely and affecting performance, delete PPH of players who have not been seen in this number of days."
}
