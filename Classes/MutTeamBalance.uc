/******************************************************************************
MutEvenMatch

Creation date: 2009-07-19 10:36
Last change: $Id$
Copyright (c) 2009, Wormbo
******************************************************************************/

class MutTeamBalance extends Mutator config;


var config int ActivationDelay;
var config int MinDesiredRoundDuration;
var config bool bShuffleTeamsFromPreviousMatch;
var config bool bRandomlyStartWithSidesSwapped;
var config bool bConnectingPlayersBalanceTeams;
var config bool bAlwaysIgnoreTeamPreference;
var config bool bAnnounceTeamChange;
var config float SmallTeamProgressThreshold;
var config int SoftRebalanceDelay;
var config int ForcedRebalanceDelay;

var config bool bDebug;

var localized string lblActivationDelay, descActivationDelay;
var localized string lblMinDesiredRoundDuration, descMinDesiredRoundDuration;
var localized string lblShuffleTeamsFromPreviousMatch, descShuffleTeamsFromPreviousMatch;
var localized string lblRandomlyStartWithSidesSwapped, descRandomlyStartWithSidesSwapped;
var localized string lblConnectingPlayersBalanceTeams, descConnectingPlayersBalanceTeams;
var localized string lblAlwaysIgnoreTeamPreference, descAlwaysIgnoreTeamPreference;
var localized string lblAnnounceTeamChange, descAnnounceTeamChange;
var localized string lblSmallTeamProgressThreshold, descSmallTeamProgressThreshold;
var localized string lblSoftRebalanceDelay, descSoftRebalanceDelay;
var localized string lblForcedRebalanceDelay, descForcedRebalanceDelay;


var ONSOnslaughtGame Game;
var EvenMatchRules Rules;
var int SoftRebalanceCountdown, ForcedRebalanceCountdown;

struct TRecentTeam {
	var PlayerController PC;
	var byte TeamNum;
};
var array<TRecentTeam> RecentTeams;


function PostBeginPlay()
{
	Rules = Spawn(class'EvenMatchRules');
	Rules.Mut = Self;
	Game = ONSOnslaughtGame(Level.Game);
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
	return Level.GRI.bMatchHasBegun && !Level.Game.bGameEnded && Game.ElapsedTime >= default.ActivationDelay;
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
	local int RequestedTeam, SizeOffset;

	Super.ModifyLogin(Portal, Options);

	if (!bConnectingPlayersBalanceTeams && !bAlwaysIgnoreTeamPreference)
		return;

	RequestedTeam = Game.GetIntOption(Options, "team", 255);
	if (RequestedTeam == 255)
		return;

	if (RequestedTeam == 0)
		SizeOffset = 1; // player would join red
	else
		SizeOffset = -1; // player would join blue

	if (bAlwaysIgnoreTeamPreference || RebalanceNeeded(SizeOffset)) {
		// teams need balancing, player should join the smaller team
		Options = Repl(Options, "team="$RequestedTeam, "team=255");
	}
}


/**
Send notification after team change and remember the current team number.
*/
function ModifyPlayer(Pawn Other)
{
	local int i;
	local PlayerController PC;

	Super.ModifyPlayer(Other);

	PC = PlayerController(Other.Controller);
	if (PC != None) {
		// update cached team number for this player and potentially send team reminder
		for (i = 0; i < RecentTeams.Length && RecentTeams[i].PC != PC; ++i);
		if (i == RecentTeams.Length) {
			RecentTeams.Length = i + 1;
			RecentTeams[i].PC = PC;
			RecentTeams[i].TeamNum = 255;
		}
		if (bAnnounceTeamChange && RecentTeams[i].TeamNum != PC.GetTeamNum())
			PC.ReceiveLocalizedMessage(class'TeamSwitchNotification', PC.GetTeamNum());
		RecentTeams[i].TeamNum = PC.GetTeamNum();
	}
}


/**
Check if leaving player caused teams to become unbalanced.
*/
function NotifyLogout(Controller Exiting)
{
	Super.NotifyLogout(Exiting);

	if (PlayerController(Exiting) != None && Exiting.PlayerReplicationInfo != None && !Exiting.PlayerReplicationInfo.bOnlySpectator) {
		if (bDebug) log("DEBUG: " $ Exiting.GetHumanReadableName() $ " disconnected", name);
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

	if (Player != None && bIsLeaving) {
		if (Player.GetTeamNum() == 0)
			SizeOffset = -1;
		else if (Player.GetTeamNum() == 0)
			SizeOffset = +1;
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
					if ((!bIsLeaving || Candidates[i] != Player) && Candidates[i].GetTeamNum() == BiggerTeam) {
						Game.ChangeTeam(Candidates[i], 1 - BiggerTeam, true);
					}
					Candidates.Remove(i, 1);
				} until (Candidates.Length == 0 || !RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam));
			}
			if (Candidates.Length == 0 && RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
				// try to find other candidates currently waiting to respawn
				for (C = Level.ControllerList; C != None; C = C.NextController) {
					if ((!bIsLeaving || C != Player) && PlayerController(C) != None && C.Pawn == None && C.GetTeamNum() == BiggerTeam)
						Candidates[Candidates.Length] = PlayerController(C);
				}
				while (Candidates.Length > 0 && RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
					// try switching a random candidate to the smaller team
					i = Rand(Candidates.Length);
					Game.ChangeTeam(Candidates[i], 1 - BiggerTeam, true);
					Candidates.Remove(i, 1);
				}
			}
		}
		if (Candidates.Length == 0 && RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam)) {
			if (ForcedRebalanceCountdown < 0)
				ForcedRebalanceCountdown = ForcedRebalanceDelay;

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
	}
}


function bool RebalanceNeeded(optional int SizeOffset, optional out float Progress, optional out byte BiggerTeam)
{
	if (!IsBalancingActive())
		return false;

	Progress = GetTeamProgress();
	return RebalanceStillNeeded(SizeOffset, Progress, BiggerTeam);
}


function bool RebalanceStillNeeded(int SizeOffset, float Progress, out byte BiggerTeam)
{
	local int SizeDiff;

	SizeDiff = Level.GRI.Teams[0].Size - Level.GRI.Teams[1].Size + SizeOffset;
	// > 0 if red is larger, < 0 if blue is larger
	if (SizeDiff == 0) {
		BiggerTeam = 255;
		return false; // same size, don't rebalance
	}
	BiggerTeam = byte(SizeDiff < 0); // 0 if red is larger, 1 if blue is larger

	return Abs(BiggerTeam - Progress) < SmallTeamProgressThreshold;
}


/**
Returns a value between 0 and 1, indicating which team has made more progress so far.
*/
function float GetTeamProgress()
{
	local int i;
	local float NodeValue, Progress[2];

	for (i = 0; i < Game.PowerCores.Length; ++i) {
		// includes powercores in the count
		if (Game.PowerCores[i].DefenderTeamIndex < 2 && (Game.PowerCores[i].CoreStage == 0 || Game.PowerCores[i].CoreStage == 2)) {
			// use relative health as default rating
			NodeValue = Game.PowerCores[i].Health / Game.PowerCores[i].DamageCapacity;

			if (Game.PowerCores[i].bFinalCore) {
				// power core is more important
				NodeValue *= 3;
			}
			else if (Game.PowerCores[i].CoreStage == 2) {
				// constructing node is less important
				NodeValue *= 0.5;
			}

			if (Game.PowerCores[i].bSevered) {
				// isolated node self-destructs over time
				NodeValue *= 0.3;
			}
			else if (!Game.PowerCores[i].PoweredBy(1 - Game.PowerCores[i].DefenderTeamIndex)) {
				// vulnerable node or core
				NodeValue *= 0.8;
			}
			else if (!Game.PowerCores[i].bFinalCore) {
				// shielded node, pretend it's undamaged
				NodeValue = 1.0;
			}

			Progress[Game.PowerCores[i].DefenderTeamIndex] += NodeValue;
		}
	}

	// scale overall team progress by powercore health if vulnerable
	for (i = 0; i < ArrayCount(Game.FinalCore); ++i) {
		if (Game.PowerCores[Game.FinalCore[i]].PoweredBy(1-i))
			Progress[i] *= Sqrt(float(Game.PowerCores[Game.FinalCore[i]].Health) / Game.PowerCores[Game.FinalCore[i]].DamageCapacity);
	}

	// return red team's share of total progress
	return Progress[1] / (Progress[0] + Progress[1]);
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

	P = C.Pawn;
	BestDist = 2000;
	TeamNum = C.GetTeamNum();
	for (i = 0; i < Game.PowerCores.Length; ++i) {
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
	PlayInfo.AddSetting(default.FriendlyName, "SmallTeamProgressThreshold", default.lblSmallTeamProgressThreshold, 0, 0, "Text", "4;0.0:1.0");
	PlayInfo.AddSetting(default.FriendlyName, "SoftRebalanceDelay", default.lblSoftRebalanceDelay, 0, 0, "Text", "3;0:999");
	PlayInfo.AddSetting(default.FriendlyName, "ForcedRebalanceDelay", default.lblForcedRebalanceDelay, 0, 0, "Text", "3;0:999");

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
	case "SmallTeamProgressThreshold":
		return default.descSmallTeamProgressThreshold;
	case "SoftRebalanceDelay":
		return default.descSoftRebalanceDelay;
	case "ForcedRebalanceDelay":
		return default.descForcedRebalanceDelay;
	default:
		return Super.GetDescriptionText(PropName);
	}
}


//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
     ActivationDelay=10
     MinDesiredRoundDuration=10
     bShuffleTeamsFromPreviousMatch=True
     bRandomlyStartWithSidesSwapped=True
     bConnectingPlayersBalanceTeams=True
     bAnnounceTeamChange=True
     SmallTeamProgressThreshold=0.500000
     SoftRebalanceDelay=10
     ForcedRebalanceDelay=30
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
     lblSmallTeamProgressThreshold="Small team progress threshold"
     descSmallTeamProgressThreshold="Switch players from the bigger team if the smaller team has less than this share of the total match progress."
     lblSoftRebalanceDelay="Soft rebalance delay"
     descSoftRebalanceDelay="If teams stay unbalanced longer than this this, respawning players are switched to achieve rebalance."
     lblForcedRebalanceDelay="Forced rebalance delay"
     descForcedRebalanceDelay="If teams stay unbalanced longer than this this, alive players are switched to achieve rebalance."
     FriendlyName="Team Balance (Onslaught-only)"
     Description="Special team balancing rules for public Onslaught matches."
}
