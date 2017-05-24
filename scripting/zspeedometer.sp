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
*/

public Plugin myinfo = {
	name = "Speedometer",
	author = "z.",
	url = "http://zskyworld.com"
};

enum DisplayArea {
	DisplayAreaCenter       = 0,
	DisplayAreaHint         = 1,
	DisplayAreaTopLeft      = 2,
	DisplayAreaTopRight     = 3,
	DisplayAreaBottomLeft   = 4,
	DisplayAreaBottomRight  = 5,
};

enum DisplayType {
	DisplayTypeVelocityXY   = 0,
	DisplayTypeVelocityXYZ  = 1,
	DisplayTypeMPH          = 2,
	DisplayTypeKPH          = 3,
};

bool g_ClientOnOff[MAXPLAYERS+1];
DisplayArea g_ClientDisplayArea[MAXPLAYERS+1];
DisplayType g_ClientDisplayType[MAXPLAYERS+1];

Handle g_MenuMain = INVALID_HANDLE;
Handle g_MenuArea = INVALID_HANDLE;
Handle g_MenuType = INVALID_HANDLE;

Handle g_Regex = INVALID_HANDLE;

public OnPluginStart(){
	g_Regex = CompileRegex("^!speed", PCRE_CASELESS);

	g_MenuMain = CreateMenu(MenuMainHandler);
	SetMenuTitle(g_MenuMain, "Speedometer");
	AddMenuItem(g_MenuMain, "onoff", "On/Off");
	AddMenuItem(g_MenuMain, "area", "Select Area");
	AddMenuItem(g_MenuMain, "type", "Select Type");

	g_MenuArea = CreateMenu(MenuAreaHandler);
	SetMenuTitle(g_MenuArea, "\x04[Speedometer]:\x01 Area");
	AddMenuItem(g_MenuArea, "DisplayAreaCenter", "DisplayAreaCenter");
	AddMenuItem(g_MenuArea, "DisplayAreaHint", "DisplayAreaHint");
	AddMenuItem(g_MenuArea, "DisplayAreaTopLeft", "DisplayAreaTopLeft");
	AddMenuItem(g_MenuArea, "DisplayAreaTopRight", "DisplayAreaTopRight");
	AddMenuItem(g_MenuArea, "DisplayAreaBottomLeft", "DisplayAreaBottomLeft");
	AddMenuItem(g_MenuArea, "DisplayAreaBottomRight", "DisplayAreaBottomRight");
	SetMenuExitBackButton(g_MenuArea, true);

	g_MenuType = CreateMenu(MenuTypeHandler);
	SetMenuTitle(g_MenuType, "\x04[Speedometer]:\x01 Type");
	AddMenuItem(g_MenuType, "DisplayTypeVelocityXY", "DisplayTypeVelocityXY");
	AddMenuItem(g_MenuType, "DisplayTypeVelocityXYZ", "DisplayTypeVelocityXYZ");
	AddMenuItem(g_MenuType, "DisplayTypeMPH", "DisplayTypeMPH");
	AddMenuItem(g_MenuType, "DisplayTypeKPH", "DisplayTypeKPH");
	SetMenuExitBackButton(g_MenuType, true);

	CreateTimer(0.1, OnTimer, _, TIMER_REPEAT);
}

public OnClientPutInServer(client){
	g_ClientOnOff[client] = false;
	g_ClientDisplayArea[client] = DisplayAreaCenter;
	g_ClientDisplayType[client] = DisplayTypeVelocityXY;
}

public Action OnClientSayCommand(client, const char[] cmd, const char[] args){
	if (client > 0 && MatchRegex(g_Regex, args) > 0){
		DisplayMenu(g_MenuMain, client, MENU_TIME_FOREVER);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public MenuMainHandler(Handle menu, MenuAction action, param1, param2){
	if (action == MenuAction_Select && IsClientInGame(param1)){
		char sMenuitem[32];
		GetMenuItem(menu, param2, sMenuitem, sizeof(sMenuitem));
		if (0 == strcmp(sMenuitem, "onoff")){
			g_ClientOnOff[param1] = !g_ClientOnOff[param1];
			PrintToChat(param1, "\x04[Speedometer]:\x01 %s",
				g_ClientOnOff[param1]?"On":"Off");
		}
		else if (0 == strcmp(sMenuitem, "area")){
			DisplayMenu(g_MenuArea, param1, MENU_TIME_FOREVER);
		}
		else if (0 == strcmp(sMenuitem, "type")){
			DisplayMenu(g_MenuType, param1, MENU_TIME_FOREVER);
		}
		else {
			DisplayMenu(menu, param1, MENU_TIME_FOREVER);
		}
	}
}

public MenuAreaHandler(Handle menu, MenuAction action, param1, param2){
	if (action == MenuAction_Select && IsClientInGame(param1)){
		char sMenuitem[32];
		GetMenuItem(menu, param2, sMenuitem, sizeof(sMenuitem));
		if (0 == strcmp(sMenuitem, "DisplayAreaCenter")){
			g_ClientDisplayArea[param1] = DisplayAreaCenter;
		}
		else if (0 == strcmp(sMenuitem, "DisplayAreaHint")){
			g_ClientDisplayArea[param1] = DisplayAreaHint;
		}
		else if (0 == strcmp(sMenuitem, "DisplayAreaTopLeft")){
			g_ClientDisplayArea[param1] = DisplayAreaTopLeft;
		}
		else if (0 == strcmp(sMenuitem, "DisplayAreaTopRight")){
			g_ClientDisplayArea[param1] = DisplayAreaTopRight;
		}
		else if (0 == strcmp(sMenuitem, "DisplayAreaBottomLeft")){
			g_ClientDisplayArea[param1] = DisplayAreaBottomLeft;
		}
		else if (0 == strcmp(sMenuitem, "DisplayAreaBottomRight")){
			g_ClientDisplayArea[param1] = DisplayAreaBottomRight;
		}
		else {
			DisplayMenu(menu, param1, MENU_TIME_FOREVER);
			return;
		}
		g_ClientOnOff[param1] = true;
		PrintToChat(param1, "\x04[Speedometer]:\x01 Area set to %s", sMenuitem);
		DisplayMenu(g_MenuMain, param1, MENU_TIME_FOREVER);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1)){
		DisplayMenu(g_MenuMain, param1, MENU_TIME_FOREVER);
	}
}

public MenuTypeHandler(Handle menu, MenuAction action, param1, param2){
	if (action == MenuAction_Select && IsClientInGame(param1)){
		char sMenuitem[32];
		GetMenuItem(menu, param2, sMenuitem, sizeof(sMenuitem));
		if (0 == strcmp(sMenuitem, "DisplayTypeVelocityXY")){
			g_ClientDisplayType[param1] = DisplayTypeVelocityXY;
		}
		else if (0 == strcmp(sMenuitem, "DisplayTypeVelocityXYZ")){
			g_ClientDisplayType[param1] = DisplayTypeVelocityXYZ;
		}
		else if (0 == strcmp(sMenuitem, "DisplayTypeMPH")){
			g_ClientDisplayType[param1] = DisplayTypeMPH;
		}
		else if (0 == strcmp(sMenuitem, "DisplayTypeKPH")){
			g_ClientDisplayType[param1] = DisplayTypeKPH;
		}
		else {
			DisplayMenu(menu, param1, MENU_TIME_FOREVER);
			return;
		}
		g_ClientOnOff[param1] = true;
		DisplayMenu(g_MenuMain, param1, MENU_TIME_FOREVER);
		PrintToChat(param1, "\x04[Speedometer]:\x01 Type set to %s", sMenuitem);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && IsClientInGame(param1)){
		DisplayMenu(g_MenuMain, param1, MENU_TIME_FOREVER);
	}
}

public Action OnTimer(Handle timer){
	float fVel[3];
	char sOutput[64];
	for (int client=1; client<=MaxClients; client++){
		if (IsClientInGame(client) && g_ClientOnOff[client]){
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);
			if (g_ClientDisplayType[client] == DisplayTypeVelocityXY){
				Format(sOutput, sizeof(sOutput), "%.1fxy",
					SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1])));
			}
			else if (g_ClientDisplayType[client] == DisplayTypeVelocityXYZ){
				Format(sOutput, sizeof(sOutput), "%.1fxyz",
					SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1]) + (fVel[2] * fVel[2])));
			}
			else if (g_ClientDisplayType[client] == DisplayTypeMPH){
				Format(sOutput, sizeof(sOutput), "%.1fmph",
					SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1]) + (fVel[2] * fVel[2])) / 26.0);
			}
			else if (g_ClientDisplayType[client] == DisplayTypeKPH){
				Format(sOutput, sizeof(sOutput), "%.1fkph",
					(SquareRoot((fVel[0] * fVel[0]) + (fVel[1] * fVel[1]) + (fVel[2] * fVel[2])) / 26.0) * 1.609);
			} else {
				continue;
			}
			if (g_ClientDisplayArea[client] == DisplayAreaCenter){
				PrintCenterText(client, sOutput);
			}
			else if (g_ClientDisplayArea[client] == DisplayAreaHint){
				PrintHintText(client, sOutput);
				StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
			}
			else if (g_ClientDisplayArea[client] == DisplayAreaTopLeft){
				PrintToGameText(client, sOutput, "0", "0");
			}
			else if (g_ClientDisplayArea[client] == DisplayAreaTopRight){
				PrintToGameText(client, sOutput, "1", "0");
			}
			else if (g_ClientDisplayArea[client] == DisplayAreaBottomLeft){
				PrintToGameText(client, sOutput, "0", "1");
			}
			else if (g_ClientDisplayArea[client] == DisplayAreaBottomRight){
				PrintToGameText(client, sOutput, "1", "1");
			}
		}
	}
}

public PrintToGameText(int client, char[] msg, char[] sx, char[] sy){
	int ent = CreateEntityByName("game_text");
	DispatchKeyValue(ent, "channel", "1");
	DispatchKeyValue(ent, "color", "255 255 255");
	DispatchKeyValue(ent, "color2", "0 0 0");
	DispatchKeyValue(ent, "effect", "0");
	DispatchKeyValue(ent, "fadein", "1.5");
	DispatchKeyValue(ent, "fadeout", "0.5");
	DispatchKeyValue(ent, "fxtime", "0.25");
	DispatchKeyValue(ent, "holdtime", "5.0");
	DispatchKeyValue(ent, "message", msg);
	DispatchKeyValue(ent, "spawnflags", "0");
	DispatchKeyValue(ent, "x", sx);
	DispatchKeyValue(ent, "y", sy);
	DispatchSpawn(ent);
	SetVariantString("!activator");
	AcceptEntityInput(ent,"display", client);
}
