# EvenMatch

A UT2004 mutator that provides special team balancing rules for public Onslaught matches.

## Features
Team balance can be affected in many different ways:
- Teams can be shuffled at match start in a way that tries to balance the potential team skill on both sides by aiming for only little difference in combined points per hour (PPH) for the players on each team
- Particularly short first rounds (e.g. caused by skilled players joining shortly after match start) can be reset with another team shuffling and PPH balancing
- After each round of a multi-round match, teams can be rebalanced to equal size
- Players that join the match can be put specifically on the team that needs additional players
- Players attempting to switch to the winning team can be forced to switch back to their original team
- If teams get uneven during the match (e.g. due to leaving players), rebalancing by size can be triggered either automatically or on player request

## Configuration
INI setting | Name in webadmin | Default value | Description
------------|------------------|---------------|-------------
`ActivationDelay` | Activation delay | 10 | Team balance checks only start after this number of seconds elapsed in the match.
`MinDesiredFirstRoundDuration` | Minimum desired first round length (minutes) | 5 | If the first round is shorter than this number of minutes, scores are reset and the round is restarted with shuffled teams.
`bShuffleTeamsAtMatchStart` | Shuffle teams at match start | True | Initially assign players to teams based on PPH from the previous matches to achieve even teams.
`bRandomlyStartWithSidesSwapped` | Randomly start with sides swapped | True | Initially swap team bases randomly in 50% of matches.
`bAssignConnectingPlayerTeam` | Assign connecting player's team | True | Override the team preference of a connecting player to balance team sizes.
`bIgnoreConnectingPlayerTeamPreference` | Ignore connecting player team preference | True | Ignore player preferences for a team color, allowing the game or Even Match to pick a team.
`bAnnounceTeamChange` | Announce team change | True | Players receive a reminder message of their team color whenever they respawn in a different team.
`bIgnoreBotsForTeamSize` | Ignore bots for team size | True | Don't count bots when comparing team sizes.
`bBalanceTeamsBetweenRounds` | Balance teams between rounds | True | Balance team sizes when a new round starts.
`bBalanceTeamsWhilePlaying` | Automatically balance teams while playing | True | Apply balancing during a round if the game becomes one-sided due to team size differences.
`bBalanceTeamsDuringOvertime` | Allow balance teams during overtime | False | Whether to allow team balancing after overtime started. Applies to automatic and player-requested balancing.
`bBalanceTeamsOnPlayerRequest` | Allow balance teams on player request | True | Whether to allow players to balance teams via 'mutate teams' or the configured teams call chat text.
`bBalanceTeamsOnAdminRequest` | Allow balance teams on admin request | True | Whether to allow admins to balance teams via 'mutate teams' or the configured teams call chat text.
`bDisplayRoundProgressIndicator` | Display round progress indicator | False | Displays a HUD gauge indicating, how close to victory either team seems to be. (This isn't a team balance indicator!)
`SmallTeamProgressThreshold` | Small team progress threshold | 0.3 | Switch players from the bigger team if the smaller team has less than this share of the total match progress.
`SoftRebalanceDelay` | Soft rebalance delay | 10 | If teams stay unbalanced longer than this this, respawning players are switched to achieve rebalance.
`ForcedRebalanceDelay` | Forced rebalance delay | 30 | If soft balancing is unsuccessful for longer than this this, alive players are switched to achieve rebalance.
`SwitchToWinnerProgressLimit` | Switch to winner progress limit | 0.6 | Only allow players to switch teams if their new team has less than this share of the total match progress. (1.0: no limit)
`ValuablePlayerRankingPct` | Valuable player ranking % | 50 | If players rank higher than percentage of the team (not counting bots), they are considered too valuable to be switched during rebalancing.
`RecentBalancingPlayerTime` | Recent balancing player time | 120 | A player who was assigned to a new team by the balancer will be considered a 'recent balancer' for this number of seconds.
`MinPlayerCount` | Minimum player count | 2 | Minimum player count required before doing any kind of balancing.
`TeamsCallString` | Teams call chat text | *(empty)* | Players can 'say' this text in the chat to manually trigger a team balance check as alternative to the console command 'mutate teams'.
`DeletePlayerPPHAfterDaysNotSeen` | Delete a player's PPH after X days inactivity | 30 | To keep PPH data from piling up indefinitely and affecting performance, delete PPH of players who have not been seen in this number of days.

## Participating
If you are a member of the Omnipotents or CEONSS communities, you can participate directly in the corresponding forums. Each of them has an Even Match thread in the [Mappers' Corner](http://forum.omnipotents.com/forumdisplay.php?f=47) and [The Creative Corner](http://ceonss.net/viewforum.php?f=14), respectively. Of course you are also free to contribute code via pull requests or report issues via [Github's issue tracker](https://github.com/TheRealWormbo/EvenMatch/issues).

One final thing: If you are going to build your own version from source, please use a unique package name so it won't interfere with the "official" version. Colliding package names may cause a Version Mismatch error for players who come in contact with both versions. I recommend modifying Build\ProjectName.cfg in your fork to include a specific suffix identifying your builds.

To build your copy of the mutator, simply clone the repository (or check out the trunk via Subversion, if you prefer that) to any folder you like and run `make.cmd`. It will automatically attempt to locate your copy of UT2004 and create the necessary folder structure to compile the package. If you installed UT2004 somewhere in the Program Files folder, you will probably have to run the build script as administrator. (It is generally recommended to install Unreal Engine 1 and 2 games in a path without spaces that can be written to without adminsitrator privileges.)
