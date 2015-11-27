[DamTypeTeamChange]
DeathString="%o a été contraint de changer d'équipe."
FemaleSuicide="%o a été contraint de changer d'équipe."
MaleSuicide="%o a été contraint de changer d'équipe."

[MutTeamBalance]
lblActivationDelay="Délai d'activation"
descActivationDelay="Les contrôles d'équilibre des équipes ne commencent qu'après l'écoulement de ce nombre de secondes dans le match."
lblMinDesiredFirstRoundDuration="Durée minimum souhaitée du premier tour (minutes)"
descMinDesiredFirstRoundDuration="Si le premier tour est plus court que ce nombre de minutes, les scores sont remis à zéro et le tour est redémarré avec des équipes mélangées."
lblShuffleTeamsAtMatchStart="Mélange des équipes au début du match"
descShuffleTeamsAtMatchStart="Attribution initiale des joueurs à des équipes basées sur le PPH des matchs précédents pour constituer des équipes uniformes."
lblRandomlyStartWithSidesSwapped="Commencer de manière aléatoire par les parties échangées"
descRandomlyStartWithSidesSwapped="Échange initial des bases de l'équipe au hasard dans 50% des matchs."
lblAssignConnectingPlayerTeam="Attribuer l'équipe rejointe par le joueur"
descAssignConnectingPlayerTeam="Remplacer la préférence d'équipe d'un joueur relié pour équilibrer les tailles des équipes."
lblIgnoreConnectingPlayerTeamPreference="Ignorer la préférence d'équipe du joueur relié"
descIgnoreConnectingPlayerTeamPreference="Ignorer les préférences de couleur d'une équipe en permettant au jeu ou à EvenMatch de choisir une équipe."
lblAnnounceTeamChange="Annoncer le changement d'équipe"
descAnnounceTeamChange="Les joueurs reçoivent un message de rappel de la couleur de leur équipe quand ils réapparaissent dans une équipe différente."
lblIgnoreBotsForTeamSize="Ignorer les bots pour la taille de l'équipe"
descIgnoreBotsForTeamSize="Ne pas compter les bots en comparant la taille des équipes."
lblBalanceTeamsBetweenRounds="Équilibrer les équipes entre les tours"
descBalanceTeamsBetweenRounds="Équilibrer les tailles des équipes quand un nouveau tour commence."
lblBalanceTeamsWhilePlaying="Équilibrer automatiquement les équipes au cours du jeu"
descBalanceTeamsWhilePlaying="Appliquer l'équilibre pendant un tour si le jeu devient unilatéral en raison des différences de taille des équipes."
lblBalanceTeamsDuringOvertime="Permettre l'équilibre des équipes pendant la prolongation"
descBalanceTeamsDuringOvertime="À savoir si permettre l'équilibrage de l'équipe après le début de la prolongation. S'applique à l'équilibrage automatique et demandé par le joueur."
lblBalanceTeamsOnPlayerRequest="Permettre l'équilibre des équipes sur demande du joueur"
descBalanceTeamsOnPlayerRequest="Que ce soit pour permettre aux joueurs d'équilibrer les équipes via 'muter les équipes' ou l'appel des équipes configurées par dialogue en ligne."
lblBalanceTeamsOnAdminRequest="Permettre l'équilibre des équipes sur demande de l'administrateur"
descBalanceTeamsOnAdminRequest="Que ce soit pour permettre aux administrateurs d'équilibrer les équipes via 'muter les équipes' ou l'appel des équipes configurées par dialogue en ligne."
lblDisplayRoundProgressIndicator="Afficher l'indicateur de progression du tour"
descDisplayRoundProgressIndicator="Affiche l'indicateur HUD indiquant à quel point l'une ou l'autre équipe semble être proche de la victoire. (Ce n'est pas un indicateur de l'équilibre de l'équipe !)"
lblSmallTeamProgressThreshold="Petit seuil de progrès de l'équipe"
descSmallTeamProgressThreshold="Changer les joueurs de la plus grande équipe si la petite équipe a moins de cette part de la progression totale du match."
lblSoftRebalanceDelay="Délai de rééquilibrage progressif"
descSoftRebalanceDelay="Si les équipes restent déséquilibrées pendant une période plus longue, les joueurs qui réapparaissent sont activés pour effectuer le rééquilibrage."
lblForcedRebalanceDelay="Délai de rééquilibrage forcé"
descForcedRebalanceDelay="Si l'équilibrage progressif ne peut se faire pendant une période plus longue, les joueurs en lice sont activés pour effectuer le rééquilibrage."
lblSwitchToWinnerProgressLimit="Passer à la limite de progression du gagnant"
descSwitchToWinnerProgressLimit="Ne permettre aux joueurs de changer d'équipe que si leur nouvelle équipe a moins de cette part de la progression totale du match. (1.0 : pas de limite)"
lblValuablePlayerRankingPct="Classement fiable du joueur %"
descValuablePlayerRankingPct="Si le classement des joueurs est plus élevé que le pourcentage de l'équipe (pas les bots de comptabilisation), ils sont considérés comme trop précieux pour être échangés en cours du rééquilibrage."
lblRecentBalancingPlayerTime="Temps récent d'équilibrage des joueurs"
descRecentBalancingPlayerTime="Un joueur qui a été affecté à une nouvelle équipe par l'équilibreur sera considéré comme un "équilibreur récent" pour ce nombre de secondes."
lblUndoSwitchCheckTime="Annuler le changement de l'heure de vérification"
descUndoSwitchCheckTime="Un joueur ne sera généralement pas autorisé à annuler un changement d'équipe forcé par EvenMatch pendant ce nombre de secondes."
lblMinPlayerCount="Nombre minimum de joueurs"
descMinPlayerCount="Nombre de joueurs minimum requis avant de procéder à toute sorte d'équilibrage."
lblTeamsCallString="Appel des équipes par dialogue en ligne"
descTeamsCallString="Les joueurs peuvent 'dire' ce texte dans le chat pour déclencher manuellement un équilibrage de l'équipe comme autre solution que la commande de la console 'muter les équipes'."
lblDeletePlayerPPHAfterDaysNotSeen="Supprimer le PPH d'un joueur après X jours d'inactivité"
descDeletePlayerPPHAfterDaysNotSeen="Pour conserver les données du PPH accumulées indéfiniment et affectant les performances, supprimer le PPH des joueurs qui n'ont pas été vus pendant ce nombre de jours."
FriendlyName="Équilibrage de l'équipe (Onslaught seulement)"
Description="Règles spéciales d'équilibrage de l'équipe pour les matches publics Onslaught."

[TeamSwitchNotification]
YouAreOnTeam="Vous êtes actif %t"

[UnevenMessage]
QuickRoundBalanceString="Tour rapide, en redémarrant avec des équipes équilibrées"
PrevMatchBalanceString="Les équipes ont été équilibrées en fonction de l'estimation des compétences du joueur"
FirstRoundWinnerString="%t a remporté le premier tour"
TeamsUnbalancedString="Les équipes sont inégales, l'équilibre sera forcé dans quelques %n secondes"
SoftBalanceString="Les équipes sont inégales, les joueurs qui réapparaissent peuvent être placés dans l'équilibrage"
ForcedBalanceString="Les équipes sont inégales, l'équilibre sera forcé maintenant"
CallForBalanceString="%p appelé pour une vérification de l'équilibre de l'équipe"
NoCallForBalanceNowString="Vous ne pouvez pas demander une vérification de l'équilibre de l'équipe en ce moment."
NoCallForBalanceEvenString="Les équipes semblent déjà prêtes, aucun besoin apparent d'équilibrage."
YouWereSwitchedString="Changement d'équipe forcé par EvenMatch"
PlayerWasSwitchedString="%p a été changé %t par EvenMatch"
