/**
EvenMatchV2a7.EvenMatchHudOverlay

Creation date: 2015-08-15 08:21
Last change: $Id$
Copyright (c) 2015, Wormbo
*/

class EvenMatchHudOverlay extends HudOverlay;


#exec Texture Import File=ProgressArrow.tga Alpha=1 UClampMode=Clamp VClampMode=Clamp LODSet=5


var() int ProgressMaxYaw;
var() float ProgressUpdateSpeed;
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
	Begin Object Class=TexRotator Name=ProgressArrowRotator
		Material = Texture'ProgressArrow'
		UOffset = 64
		VOffset = 64
	End Object
	
     ProgressMaxYaw=10240
     ProgressUpdateSpeed=0.200000
     ProgressArrowWidget=(WidgetTexture=TexRotator'ProgressArrowRotator',RenderStyle=STY_Alpha,TextureCoords=(X2=128,Y2=128),TextureScale=0.250000,DrawPivot=DP_UpperMiddle,PosX=0.500000,OffsetY=50,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(G=160,A=255),Tints[1]=(G=160,A=255))
     ProgressBackgroundDisc=(WidgetTexture=Texture'HUDContent.Generic.HUD',RenderStyle=STY_Alpha,TextureCoords=(X1=119,Y1=258,X2=173,Y2=313),TextureScale=0.530000,DrawPivot=DP_UpperMiddle,PosX=0.500000,OffsetY=15,ScaleMode=SM_Right,Scale=1.000000,Tints[0]=(B=255,G=255,R=255,A=255),Tints[1]=(B=255,G=255,R=255,A=255))
     DisplayedProgress=0.500000
}
