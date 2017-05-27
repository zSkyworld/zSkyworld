#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <regex>

/*
	zee
	zskyworld.com
	2017.05.23	initial
	2017.05.24	added PrintToGameText
	2017.05.25	added cvar, areas, csgo
	2017.05.27	added pause on jump (thanks bogroll <3)
*/

public Plugin myinfo = {
	name = "Speedometer",
	author = "z.",
	url = "http://zskyworld.com"
};

enum JumpState {
	JumpStateNo,
	JumpStateYes,
	JumpStateSaved
};

enum DisplayArea {
	DisplayAreaCenter,
	DisplayAreaHint,
	DisplayAreaTopLeft,
	DisplayAreaTopCenter,
	DisplayAreaTopRight,
	DisplayAreaCenterCenter,
	DisplayAreaBottomLeft,
	DisplayAreaBottomRight
};

enum DisplayType {
	DisplayTypeVelocityXY,
	DisplayTypeVelocityXYZ,
	DisplayTypeMPH,
	DisplayTypeKPH
};

DisplayArea g_ClientDisplayArea[MAXPLAYERS+1];
DisplayType g_ClientDisplayType[MAXPLAYERS+1];

bool   g_IsCSGO;
Handle g_Timer = INVALID_HANDLE;
Handle g_Regex = INVALID_HANDLE;

Handle g_MenuMain = INVALID_HANDLE;
Handle g_MenuArea = INVALID_HANDLE;
Handle g_MenuType = INVALID_HANDLE;

bool   g_ClientOnOff[MAXPLAYERS+1];
float  g_DisplayRate;
ConVar g_CvarDisplayRate;

bool   g_ClientJumpOnOff[MAXPLAYERS+1];
float  g_JumpTime[MAXPLAYERS+1];
float  g_JumpVel[MAXPLAYERS+1][3];
JumpState g_JumpState[MAXPLAYERS+1];

public OnPluginStart(){
	char sFolder[8];
	g_IsCSGO = (GetGameFolderName(sFolder, sizeof(sFolder)) > 0 && strcmp(sFolder, "csgo") == 0);
	g_Regex  = CompileRegex("^!speed", PCRE_CASELESS);

	g_MenuMain = CreateMenu(MenuMainHandler);
	SetMenuTitle(g_MenuMain, "Speedometer");
	AddMenuItem(g_MenuMain, "onoff", "Display On/Off");
	AddMenuItem(g_MenuMain, "area", "> Select Area");
	AddMenuItem(g_MenuMain, "type", "> Select Type");
	AddMenuItem(g_MenuMain, "jump", "Jump On/Off");

	g_MenuArea = CreateMenu(MenuAreaHandler);
	SetMenuTitle(g_MenuArea, "Speedometer: Area");
	SetMenuExitBackButton(g_MenuArea, true);
	AddMenuItem(g_MenuArea, "DisplayAreaCenter", "Center");
	AddMenuItem(g_MenuArea, "DisplayAreaHint", "Hint");
	AddMenuItem(g_MenuArea, "DisplayAreaTopLeft", "TopLeft");
	AddMenuItem(g_MenuArea, "DisplayAreaTopCenter", "TopCenter");
	if (!g_IsCSGO){
		AddMenuItem(g_MenuArea, "DisplayAreaTopRight", "TopRight");
	}
	AddMenuItem(g_MenuArea, "DisplayAreaCenterCenter", "CenterCenter");
	AddMenuItem(g_MenuArea, "DisplayAreaBottomLeft", "BottomLeft");
	if (!g_IsCSGO){
		AddMenuItem(g_MenuArea, "DisplayAreaBottomRight", "BottomRight");
	}

	g_MenuType = CreateMenu(MenuTypeHandler);
	SetMenuTitle(g_MenuType, "Speedometer: Type");
	SetMenuExitBackButton(g_MenuType, true);
	AddMenuItem(g_MenuType, "DisplayTypeVelocityXY", "XY");
	AddMenuItem(g_MenuType, "DisplayTypeVelocityXYZ", "XYZ");
	AddMenuItem(g_MenuType, "DisplayTypeMPH", "MPH");
	AddMenuItem(g_MenuType, "DisplayTypeKPH", "KPH");

	g_CvarDisplayRate = CreateConVar("speedometer_displayrate", "0.1", "Display update rate in seconds", 0, true, 0.01, true, 1.0);
	g_CvarDisplayRate.AddChangeHook(OnDisplayRateChanged);
	OnDisplayRateChanged(g_CvarDisplayRate, "", "");

	HookEvent("player_jump", OnPlayerJump);

	for (int client=1; client<=MaxClients; client++){
		if (IsClientInGame(client)){
			OnClientPutInServer(client);
		}
	}
}

public OnClientPutInServer(client){
	g_JumpState[client] = JumpStateNo;
	g_ClientOnOff[client] = false;
	g_ClientJumpOnOff[client] = false;
	g_ClientDisplayArea[client] = DisplayAreaCenter;
	g_ClientDisplayType[client] = DisplayTypeVelocityXY;
}

public Action OnClientSayCommand(client, const char[] cmd, const char[] args){
	if (client > 0 && MatchRegex(g_Regex, args) > 0){
		DisplayMenu(g_MenuMain, client, 30);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public MenuMainHandler(Handle menu, MenuAction action, param1, param2){
	if (action == MenuAction_Select && IsClientInGame(param1)){
		char sItem[32];
		GetMenuItem(menu, param2, sItem, sizeof(sItem));
		if (0 == strcmp(sItem, "onoff")){
			g_ClientOnOff[param1] = !g_ClientOnOff[param1];
			PrintToChat(param1, "\x04[Speedometer]:\x01 Display %s",
				g_ClientOnOff[param1]?"On":"Off");
		}
		else if (0 == strcmp(sItem, "jump")){
			g_ClientJumpOnOff[param1] = !g_ClientJumpOnOff[param1];
			g_ClientOnOff[param1] = true;
			PrintToChat(param1, "\x04[Speedometer]:\x01 Jump %s",
				g_ClientJumpOnOff[param1]?"On":"Off");
		}
		else if (0 == strcmp(sItem, "area")){
			DisplayMenu(g_MenuArea, param1, 30);
		}
		else if (0 == strcmp(sItem, "type")){
			DisplayMenu(g_MenuType, param1, 30);
		}
		else {
			DisplayMenu(menu, param1, 30);
		}
	}
}

public MenuAreaHandler(Handle menu, MenuAction action, param1, param2){
	if (action == MenuAction_Select && IsClientInGame(param1)){
		char sItem[32];
		GetMenuItem(menu, param2, sItem, sizeof(sItem));
		if (0 == strcmp(sItem, "DisplayAreaCenter")){
			g_ClientDisplayArea[param1] = DisplayAreaCenter;
		}
		else if (0 == strcmp(sItem, "DisplayAreaHint")){
			g_ClientDisplayArea[param1] = DisplayAreaHint;
		}
		else if (0 == strcmp(sItem, "DisplayAreaTopLeft")){
			g_ClientDisplayArea[param1] = DisplayAreaTopLeft;
		}
		else if (0 == strcmp(sItem, "DisplayAreaTopCenter")){
			g_ClientDisplayArea[param1] = DisplayAreaTopCenter;
		}
		else if (0 == strcmp(sItem, "DisplayAreaTopRight")){
			g_ClientDisplayArea[param1] = DisplayAreaTopRight;
		}
		else if (0 == strcmp(sItem, "DisplayAreaCenterCenter")){
			g_ClientDisplayArea[param1] = DisplayAreaCenterCenter;
		}
		else if (0 == strcmp(sItem, "DisplayAreaBottomLeft")){
			g_ClientDisplayArea[param1] = DisplayAreaBottomLeft;
		}
		else if (0 == strcmp(sItem, "DisplayAreaBottomRight")){
			g_ClientDisplayArea[param1] = DisplayAreaBottomRight;
		}
		else {
			DisplayMenu(menu, param1, 30);
			return;
		}
		g_ClientOnOff[param1] = true;
		PrintToChat(param1, "\x04[Speedometer]:\x01 Area set to %s", sItem);
		DisplayMenu(g_MenuMain, param1, 30);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1)){
		DisplayMenu(g_MenuMain, param1, 30);
	}
}

public MenuTypeHandler(Handle menu, MenuAction action, param1, param2){
	if (action == MenuAction_Select && IsClientInGame(param1)){
		char sItem[32];
		GetMenuItem(menu, param2, sItem, sizeof(sItem));
		if (0 == strcmp(sItem, "DisplayTypeVelocityXY")){
			g_ClientDisplayType[param1] = DisplayTypeVelocityXY;
		}
		else if (0 == strcmp(sItem, "DisplayTypeVelocityXYZ")){
			g_ClientDisplayType[param1] = DisplayTypeVelocityXYZ;
		}
		else if (0 == strcmp(sItem, "DisplayTypeMPH")){
			g_ClientDisplayType[param1] = DisplayTypeMPH;
		}
		else if (0 == strcmp(sItem, "DisplayTypeKPH")){
			g_ClientDisplayType[param1] = DisplayTypeKPH;
		}
		else {
			DisplayMenu(menu, param1, 30);
			return;
		}
		g_ClientOnOff[param1] = true;
		DisplayMenu(g_MenuMain, param1, 30);
		PrintToChat(param1, "\x04[Speedometer]:\x01 Type set to %s", sItem);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1)){
		DisplayMenu(g_MenuMain, param1, 30);
	}
}

public Action OnTimer(Handle timer){
	float fVel[3];
	char sOutput[64];
	for (int client=1; client<=MaxClients; client++){
		if (IsClientInGame(client) && g_ClientOnOff[client]){
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);

			switch (g_JumpState[client]){
				case JumpStateSaved:
				{
					if (GetEngineTime() > g_JumpTime[client] + 2.0){
						g_JumpState[client] = JumpStateNo;
					}
				}
				case JumpStateNo:
				{
				}
				case JumpStateYes:
				{
					g_JumpState[client] = JumpStateSaved;
					g_JumpVel[client] = fVel;
				}
			}

			switch (g_ClientDisplayType[client]){
				case DisplayTypeVelocityXY:
				{
					if (g_ClientJumpOnOff[client] && g_JumpState[client] == JumpStateSaved){
						Format(sOutput, sizeof(sOutput), "%.1f\n%.1f",
							SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1])),
							SquareRoot((g_JumpVel[client][0] * g_JumpVel[client][0]) + (g_JumpVel[client][1] * g_JumpVel[client][1])));
					}
					else {
						Format(sOutput, sizeof(sOutput), "%.1f",
							SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1])));
					}
				}
				case DisplayTypeVelocityXYZ:
				{
					if (g_ClientJumpOnOff[client] && g_JumpState[client] == JumpStateSaved){
						Format(sOutput, sizeof(sOutput), "%.1f\n%.1f",
							SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1]) + (fVel[2] * fVel[2])),
							SquareRoot((g_JumpVel[client][0] * g_JumpVel[client][0]) + (g_JumpVel[client][1] * g_JumpVel[client][1]) + (g_JumpVel[client][2] * g_JumpVel[client][2])));
					}
					else {
						Format(sOutput, sizeof(sOutput), "%.1f",
							SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1]) + (fVel[2] * fVel[2])));
					}
				}
				case DisplayTypeMPH:
				{
					if (g_ClientJumpOnOff[client] && g_JumpState[client] == JumpStateSaved){
						Format(sOutput, sizeof(sOutput), "%.1f\n%.1f",
							(SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1]) + (fVel[2] * fVel[2])) / 26.0),
							(SquareRoot((g_JumpVel[client][0] * g_JumpVel[client][0]) + (g_JumpVel[client][1] * g_JumpVel[client][1]) + (g_JumpVel[client][2] * g_JumpVel[client][2])) / 26.0));
					}
					else {
						Format(sOutput, sizeof(sOutput), "%.1f",
							SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1]) + (fVel[2] * fVel[2])) / 26.0);
					}
				}
				case DisplayTypeKPH:
				{
					if (g_ClientJumpOnOff[client] && g_JumpState[client] == JumpStateSaved){
						Format(sOutput, sizeof(sOutput), "%.1f\n%.1f",
							((SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1]) + (fVel[2] * fVel[2])) / 26.0) * 1.609),
							((SquareRoot((g_JumpVel[client][0] * g_JumpVel[client][0]) + (g_JumpVel[client][1] * g_JumpVel[client][1]) + (g_JumpVel[client][2] * g_JumpVel[client][2])) / 26.0) * 1.609));
					}
					else {
						Format(sOutput, sizeof(sOutput), "%.1f",
							(SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1]) + (fVel[2] * fVel[2])) / 26.0) * 1.609);
					}
				}
				default:
				{
					continue;
				}
			}

			switch (g_ClientDisplayArea[client]){
				case DisplayAreaCenter:
				{
					PrintCenterText(client, sOutput);
				}
				case DisplayAreaHint:
				{
					PrintHintText(client, sOutput);
					if (!g_IsCSGO){
						StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
					}
				}
				case DisplayAreaTopLeft:
				{
					PrintToGameText(client, sOutput, 0.0, 0.0);
				}
				case DisplayAreaTopCenter:
				{
					PrintToGameText(client, sOutput, -1.0, 0.0);
				}
				case DisplayAreaTopRight:
				{
					PrintToGameText(client, sOutput, 1.0, 0.0);
				}
				case DisplayAreaCenterCenter:
				{
				PrintToGameText(client, sOutput, -1.0, -1.0);
				}
				case DisplayAreaBottomLeft:
				{
					PrintToGameText(client, sOutput, 0.0, 1.0);
				}
				case DisplayAreaBottomRight:
				{
					PrintToGameText(client, sOutput, 1.0, 1.0);
				}
			}
		}
	}
}

public PrintToGameText(int client, char[] msg, float sx, float sy){
	SetHudTextParams(
		sx, sy, g_DisplayRate,
		255, // r
		255, // g
		255, // b
		255, // a
		0, 0.0, 0.0, 0.0);
	ShowHudText(client, -1, msg);
}

public void OnDisplayRateChanged(ConVar convar, char[] oldValue, char[] newValue){
	g_DisplayRate = convar.FloatValue;
	if (g_Timer != INVALID_HANDLE){
		KillTimer(g_Timer);
	}
	g_Timer = CreateTimer(g_DisplayRate, OnTimer, _, TIMER_REPEAT);
}

public Action OnPlayerJump(Handle event, char[] name, bool dontBroadcast){
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients){
		g_JumpTime[client] = GetEngineTime();
		g_JumpState[client] = JumpStateYes;
	}
	return Plugin_Continue;
}
