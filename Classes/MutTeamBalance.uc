/******************************************************************************
MutEvenMatch

Creation date: 2009-07-19 10:36
Last change: $Id$
Copyright (c) 2009, Wormbo
******************************************************************************/

class MutTeamBalance extends Mutator config;


var() const editconst string Build;


var config int ActivationDelay;
var config int MinDesiredRoundDuration;
var config bool bShuffleTeamsFromPreviousMatch;
var config bool bRandomlyStartWithSidesSwapped;
var config bool bConnectingPlayersBalanceTeams;
var config bool bAlwaysIgnoreTeamPreference;
var config bool bAnnounceTeamChange;
var config bool bIgnoreBotsForTeamSize;
var config float SmallTeamProgressThreshold;
var config int SoftRebalanceDelay;
var config int ForcedRebalanceDelay;
var config float SwitchToWinnerProgressLimit;
var config byte ValuablePlayerRankingPct;
var config byte MinPlayerCount;

var config bool bDebug;

var localized string lblActivationDelay, descActivationDelay;
var localized string lblMinDesiredRoundDuration, descMinDesiredRoundDuration;
var localized string lblShuffleTeamsFromPreviousMatch, descShuffleTeamsFromPreviousMatch;
var localized string lblRandomlyStartWithSidesSwapped, descRandomlyStartWithSidesSwapped;
var localized string lblConnectingPlayersBalanceTeams, descConnectingPlayersBalanceTeams;
var localized string lblAlwaysIgnoreTeamPreference, descAlwaysIgnoreTeamPreference;
var localized string lblAnnounceTeamChange, descAnnounceTeamChange;
var localized string lblIgnoreBotsForTeamSize, descIgnoreBotsForTeamSize;
var localized string lblSmallTeamProgressThreshold, descSmallTeamProgressThreshold;
var localized string lblSoftRebalanceDelay, descSoftRebalanceDelay;
var localized string lblForcedRebalanceDelay, descForcedRebalanceDelay;
var localized string lblSwitchToWinnerProgressLimit, descSwitchToWinnerProgressLimit;
var localized string lblValuablePlayerRankingPct, descValuablePlayerRankingPct;
var localized string lblMinPlayerCount, descMinPlayerCount;


var ONSOnslaughtGame Game;
var EvenMatchRules Rules;
var EvenMatchReplicationInfo RepInfo;
var int SoftRebalanceCountdown, ForcedRebalanceCountdown;

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

	Rules = Spawn(class'EvenMatchRules');
	Rules.Mut = Self;
	Game = ONSOnslaughtGame(Level.Game);
	RepInfo = Spawn(class'EvenMatchReplicationInfo');
	RepInfo.Mut = Self;
	RepInfo.SetTimer(0.2, true);
}

function bool MutatorIsAllowed()
{
	return Level.Game.IsA('ONSOnslaughtGame') && Super.MutatorIsAllowed();
}

function MatchStarting()
{
	SetTimer(1.0, true);
}


function bool IsBalancingActive()
{
	local int i, NumPlayers;

	for (i = 0; i < Level.GRI.PRIArray.Length && NumPlayers < MinPlayerCount; i++) {
		if (!Level.GRI.PRIArray[i].bOnlySpectator)
			NumPlayers++;
	}
	
	return Level.GRI.bMatchHasBegun && !Level.Game.bGameEnded && Game.ElapsedTime >= default.ActivationDelay && NumPlayers >= MinPlayerCount;
}


/**
Clear recent team number cache so players receive the team change notification
when they respawn at the start of the new round.
*/
function Reset()
{
	RecentTeams.Length = 0;
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

	if (!bConnectingPlayersBalanceTeams && !bAlwaysIgnoreTeamPreference)
		return;

	RequestedTeam = Game.GetIntOption(Options, "team", 255);
	if (bConnectingPlayersBalanceTeams) {
	
		if (!RebalanceNeeded(0, Progress, BiggerTeam) && !bAlwaysIgnoreTeamPreference)
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

	log("Forced team change: " $ PC.GetHumanReadableName() @ PC.GetTeamNum() @ Reason, 'EvenMatch');
	Level.Game.BroadcastHandler.Broadcast(PC, "Forced team change by EvenMatch", 'EvenMatch');

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

	if (SoftRebalanceCountdown == 0)
		CheckBalance(None, False);
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
Check team balance and potentially move
*/
function CheckBalance(PlayerController Player, bool bIsLeaving)
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
		}
	}
	if (!bFound && !bIsLeaving && Player != None) {
		RecentTeams.Length = i + 1;
		RecentTeams[i].PC = Player;
		RecentTeams[i].TeamNum = 255; // consider the new player for team changes until respawn
		Candidates[Candidates.Length] = Player;
	}

	if (RebalanceNeeded(SizeOffset, Progress, BiggerTeam)) {
		if (SoftRebalanceCountdown < 0) {
			log("Teams have become uneven, soft balance in " $ SoftRebalanceDelay $ "s", 'EvenMatch');
			SoftRebalanceCountdown = SoftRebalanceDelay;
			ForcedRebalanceCountdown = -1; // not yet!
		}
		if (SoftRebalanceCountdown == 0) {
			if (ForcedRebalanceCountdown < 0 && ForcedRebalanceDelay > 0) {
				BroadcastLocalizedMessage(class'UnevenChatMessage', 3);
			}
			if (Candidates.Length > 0) {
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
			if (Candidates.Length == 0 && RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
				// try to find other candidates currently waiting to respawn
				for (C = Level.ControllerList; C != None; C = C.NextController) {
					if ((!bIsLeaving || C != Player) && PlayerController(C) != None && C.Pawn == None && C.GetTeamNum() == BiggerTeam && !IsRecentBalancer(Candidates[i]))
						Candidates[Candidates.Length] = PlayerController(C);
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
		}
		if (Candidates.Length == 0 && RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
			if (ForcedRebalanceCountdown < 0) {
				log("Teams are uneven, forced balance in " $ ForcedRebalanceDelay $ "s", 'EvenMatch');
				ForcedRebalanceCountdown = ForcedRebalanceDelay;
			}
			
			if (ForcedRebalanceCountdown % 10 == 0)
				BroadcastLocalizedMessage(class'UnevenChatMessage', ForcedRebalanceCountdown / 10 + 4);

			if (ForcedRebalanceCountdown == 0) {
				// time is up, random alive players on the bigger team will be switched to the smaller team
				for (C = Level.ControllerList; C != None; C = C.NextController) {
					if ((!bIsLeaving || C != Player) && PlayerController(C) != None && C.GetTeamNum() == BiggerTeam && !IsKeyPlayer(C))
						Candidates[Candidates.Length] = PlayerController(C);
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
			}
		}
		else if (SoftRebalanceCountdown >= 0) {
			SoftRebalanceCountdown   = -1;
			ForcedRebalanceCountdown = -1;
		}
	}
	else if (SoftRebalanceCountdown >= 0) {
		SoftRebalanceCountdown   = -1;
		ForcedRebalanceCountdown = -1;

		// no rebalance needed, but check if players changed to winning team
		if (SwitchToWinnerProgressLimit < 1.0 && !bIsLeaving) {
			// Candidates[] contains team switchers who didn't respawn yet
			while (Candidates.Length > 0) {
				i = Rand(Candidates.Length);
				SizeOffset = 4 * Candidates[i].GetTeamNum() - 2; // red -2, blue +2
				if (!IsRecentBalancer(Candidates[i]) && Abs(Candidates[i].GetTeamNum() - Progress) > SwitchToWinnerProgressLimit && !RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
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

	for (i = 0; i < Level.GRI.PRIArray.Length; i++) {
		if (Level.GRI.PRIArray[i].Team == C.PlayerReplicationInfo.Team) {
			if (!bFound)
				rank++;
			if (!bIgnoreBotsForTeamSize || !Level.GRI.PRIArray[i].bBot)
				teamsize++;
		}
		if (Level.GRI.PRIArray[i] == C.PlayerReplicationInfo) {
			bFound = True;
		}
	}
	return 100 * rank / teamsize >= ValuablePlayerRankingPct;
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
	return i >= 0 && Level.TimeSeconds - RecentTeams[i].LastForcedSwitch < 60 && RecentTeams[i].ForcedTeamNum == C.GetTeamNum();
}

function bool IsKeyPlayer(Controller C)
{
	local Pawn P;
	local int i;
	local float Dist, BestDist;
	local ONSPowerCore BestNode;
	local byte TeamNum;

	if (C == None || C.Pawn == None || C.Pawn.Health <= 0)
		return false;

	if (Vehicle(C.Pawn) != None && (Vehicle(C.Pawn).ImportantVehicle() || Vehicle(C.Pawn).HasOccupiedTurret()))
		return true; // driving a tank or other large vehicle or has passenger

	P = C.Pawn;
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

	return BestNode != None && (BestNode.DefenderTeamIndex == 1 - TeamNum || BestNode.bUnderAttack);
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
	PlayInfo.AddSetting(default.FriendlyName, "MinDesiredRoundDuration", default.lblMinDesiredRoundDuration, 0, 0, "Text", "3;0:999");
	PlayInfo.AddSetting(default.FriendlyName, "bShuffleTeamsFromPreviousMatch", default.lblShuffleTeamsFromPreviousMatch, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bRandomlyStartWithSidesSwapped", default.lblRandomlyStartWithSidesSwapped, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bConnectingPlayersBalanceTeams", default.lblConnectingPlayersBalanceTeams, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bAlwaysIgnoreTeamPreference", default.lblAlwaysIgnoreTeamPreference, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bAnnounceTeamChange", default.lblAnnounceTeamChange, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "bIgnoreBotsForTeamSize", default.lblIgnoreBotsForTeamSize, 0, 0, "Check");
	PlayInfo.AddSetting(default.FriendlyName, "SmallTeamProgressThreshold", default.lblSmallTeamProgressThreshold, 0, 0, "Text", "4;0.0:1.0");
	PlayInfo.AddSetting(default.FriendlyName, "SoftRebalanceDelay", default.lblSoftRebalanceDelay, 0, 0, "Text", "3;0:999");
	PlayInfo.AddSetting(default.FriendlyName, "ForcedRebalanceDelay", default.lblForcedRebalanceDelay, 0, 0, "Text", "3;0:999");
	PlayInfo.AddSetting(default.FriendlyName, "SwitchToWinnerProgressLimit", default.lblSwitchToWinnerProgressLimit, 0, 0, "Text", "4;0.0:1.0");
	PlayInfo.AddSetting(default.FriendlyName, "ValuablePlayerRankingPct", default.lblValuablePlayerRankingPct, 0, 0, "Text", "2;0:90");

	PlayInfo.AddSetting(default.FriendlyName, "MinPlayerCount", default.lblMinPlayerCount, 0, 0, "Text", "2;1:32");

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
	case "MinDesiredRoundDuration":
		return default.descMinDesiredRoundDuration;
	case "bShuffleTeamsFromPreviousMatch":
		return default.descShuffleTeamsFromPreviousMatch;
	case "bRandomlyStartWithSidesSwapped":
		return default.descRandomlyStartWithSidesSwapped;
	case "bConnectingPlayersBalanceTeams":
		return default.descConnectingPlayersBalanceTeams;
	case "bAlwaysIgnoreTeamPreference":
		return default.descAlwaysIgnoreTeamPreference;
	case "bAnnounceTeamChange":
		return default.descAnnounceTeamChange;
	case "bIgnoreBotsForTeamSize":
		return default.descIgnoreBotsForTeamSize;
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
	default:
		return Super.GetDescriptionText(PropName);
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
     Build="2015-08-16 15:01"
     ActivationDelay=10
     MinDesiredRoundDuration=10
     bShuffleTeamsFromPreviousMatch=True
     bRandomlyStartWithSidesSwapped=True
     bConnectingPlayersBalanceTeams=True
     bAnnounceTeamChange=True
     bIgnoreBotsForTeamSize=True
     SmallTeamProgressThreshold=0.500000
     SoftRebalanceDelay=10
     ForcedRebalanceDelay=30
     SwitchToWinnerProgressLimit=0.700000
     ValuablePlayerRankingPct=75
     MinPlayerCount=2
     lblActivationDelay="Activation delay"
     descActivationDelay="Team balance checks only start after this number of seconds elapsed in the match."
     lblMinDesiredRoundDuration="Minimum desired round length (minutes)"
     descMinDesiredRoundDuration="If the first round is shorter than this number of minutes, scores are reset and the round is restarted with shuffled teams."
     lblShuffleTeamsFromPreviousMatch="Shuffle teams from previous match"
     descShuffleTeamsFromPreviousMatch="Shuffle players based on PPH from the previous match to achieve even teams."
     lblRandomlyStartWithSidesSwapped="Randomly start with sides swapped"
     descRandomlyStartWithSidesSwapped="Randomly swap team bases at match startup already."
     lblConnectingPlayersBalanceTeams="Connecting players balance teams"
     descConnectingPlayersBalanceTeams="Override the team preference of a connecting player if teams are uneven."
     lblAlwaysIgnoreTeamPreference="Always ignore team preference"
     descAlwaysIgnoreTeamPreference="Completely ignore connecting players' team preference, always putting them on the smaller team."
     lblAnnounceTeamChange="Announce team change"
     descAnnounceTeamChange="Players receive a message whenever they respawn in a different team."
     lblIgnoreBotsForTeamSize="Ignore bots for team size"
     descIgnoreBotsForTeamSize="Don't count bots when comparing team sizes."
     lblSmallTeamProgressThreshold="Small team progress threshold"
     descSmallTeamProgressThreshold="Switch players from the bigger team if the smaller team has less than this share of the total match progress."
     lblSoftRebalanceDelay="Soft rebalance delay"
     descSoftRebalanceDelay="If teams stay unbalanced longer than this this, respawning players are switched to achieve rebalance."
     lblForcedRebalanceDelay="Forced rebalance delay"
     descForcedRebalanceDelay="If teams stay unbalanced longer than this this, alive players are switched to achieve rebalance."
     lblSwitchToWinnerProgressLimit="Switch to winner progress limit"
     descSwitchToWinnerProgressLimit="Only allow players to switch teams if their new team has less than this share of the total match progress. (1.0: no limit)"
     lblValuablePlayerRankingPct="Valuable player ranking %"
     descValuablePlayerRankingPct="If a player ranks among this top percentage of the team, he is considered too valuable to be switched during soft rebalancing."
     lblMinPlayerCount="Minimum player count"
     descMinPlayerCount="Minimum player count required before doing any kind of balancing."
     bAddToServerPackages=True
     FriendlyName="Team Balance (Onslaught-only)"
     Description="Special team balancing rules for public Onslaught matches."
}
