/**
A HUD overlay used for displaying EvenMatch's opinion of the game state.

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

class EvenMatchHudOverlay extends HudOverlay;


#exec Texture Import File=Textures\ProgressArrow.tga Alpha=1 UClampMode=Clamp VClampMode=Clamp LODSet=5


var() int ProgressMaxYaw;
var() float ProgressUpdateSpeed;
var() export Material ArrowExportDummy; // ensures the TexRotator subobject is generated again on export
var() HudBase.SpriteWidget ProgressArrowWidget;
var() HudBase.SpriteWidget ProgressBackgroundDisc;

var EvenMatchReplicationInfo EVRI;
var float DisplayedProgress;
var HudCTeamDeathMatch TeamHud;

function PreBeginPlay()
{
	EVRI = EvenMatchReplicationInfo(Owner);
	if (EVRI == None) {
		Destroy();
		return;
	}
}

function Tick(float DeltaTime)
{
	local float TargetProgress;
	local PlayerController PC;
	
	if (TeamHud == None) {
		PC = Level.GetLocalPlayerController();
		
		if (PC != None && HudCTeamDeathMatch(PC.MyHud) != None) {
			PC.MyHud.AddHudOverlay(Self);
			TeamHud = HudCTeamDeathMatch(Owner);
			
			// replace VS symbol with another background disc for the progress arrow
			TeamHud.VersusSymbol = ProgressBackgroundDisc;
		}
		else {
			return;
		}
	}
	
	TargetProgress = EVRI.Progress;
	if (DisplayedProgress > TargetProgress)
		DisplayedProgress = FMax(DisplayedProgress - ProgressUpdateSpeed * DeltaTime, TargetProgress);
	if (DisplayedProgress < TargetProgress)
		DisplayedProgress = FMin(DisplayedProgress + ProgressUpdateSpeed * DeltaTime, TargetProgress);
}

function Render(Canvas C)
{
	local color WidgetColor;
	
	// check conditions that prevent ShowTeamScorePassA from being called
	if (TeamHud.PlayerOwner == None || TeamHud.PawnOwner == None || TeamHud.PawnOwnerPRI == None || TeamHud.PlayerOwner.IsSpectating() && TeamHud.PlayerOwner.bBehindView) {
		// draw spectating HUD
		if (TeamHud.PlayerOwner == None || TeamHud.PlayerOwner.PlayerReplicationInfo == None || !TeamHud.PlayerOwner.PlayerReplicationInfo.bOnlySpectator)
			return;
	}
	else if (TeamHud.PawnOwner.bHideRegularHUD) {
		return;
	}
	
	if (TeamHud.bShowPoints) {
		TexRotator(ProgressArrowWidget.WidgetTexture).Rotation.Yaw = ProgressMaxYaw - (2 * ProgressMaxYaw) * DisplayedProgress;
		
		WidgetColor = FMin(6 * Abs(DisplayedProgress - 0.5), 1) * TeamHud.HudColorTeam[Round(DisplayedProgress)];
		WidgetColor.G += FClamp((1.0 - 5.0 * Abs(DisplayedProgress - 0.5)) * 160, 0, 255 - WidgetColor.G);
		WidgetColor.A = 255;
		ProgressArrowWidget.Tints[0] = WidgetColor;
		ProgressArrowWidget.Tints[1] = WidgetColor;
		
		C.ColorModulate.X = 1;
		C.ColorModulate.Y = 1;
		C.ColorModulate.Z = 1;
		C.ColorModulate.W = TeamHud.HudOpacity/255;
		TeamHud.DrawSpriteWidget(C, ProgressArrowWidget);
	}
}



//=============================================================================
// Default values
//=============================================================================

defaultproperties
{
	ProgressMaxYaw = 10240
	ProgressUpdateSpeed = 0.2
	DisplayedProgress = 0.5
	
	Begin Object Class=TexRotator Name=ProgressArrowRotator
		Material = Texture'ProgressArrow'
		UOffset = 64
		VOffset = 64
	End Object
	ArrowExportDummy = ProgressArrowRotator
	
	ProgressArrowWidget = (WidgetTexture=TexRotator'ProgressArrowRotator',PosX=0.5,PosY=0.0,OffsetX=0,OffsetY=50,DrawPivot=DP_UpperMiddle,RenderStyle=STY_Alpha,TextureCoords=(X1=0,Y1=0,X2=128,Y2=128),TextureScale=0.25,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(G=160,R=0,B=0,A=255),Tints[1]=(G=160,R=0,B=0,A=255))
	ProgressBackgroundDisc = (WidgetTexture=Texture'HudContent.Generic.HUD',PosX=0.5,PosY=0.0,OffsetX=0,OffsetY=15,DrawPivot=DP_UpperMiddle,RenderStyle=STY_Alpha,TextureCoords=(X1=119,Y1=258,X2=173,Y2=313),TextureScale=0.53,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(G=255,R=255,B=255,A=255),Tints[1]=(G=255,R=255,B=255,A=255))
}
