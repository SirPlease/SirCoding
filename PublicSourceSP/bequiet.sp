#include <sourcemod>

public Plugin:myinfo = 
{
	name = "BeQuiet",
	author = "Sir",
	description = "Please be Quiet!",
	version = "1.33.7",
	url = "https://github.com/SirPlease/SirCoding"
}

public OnPluginStart()
{
	AddCommandListener(Say_Callback, "say");
	AddCommandListener(TeamSay_Callback, "say_team");

	//Server CVar
	HookEvent("server_cvar", Event_ServerDontNeedPrint, EventHookMode_Pre);
	HookEvent("player_changename", Event_NameDontNeedPrint, EventHookMode_Pre);
}

public Action:Say_Callback(client, const String:command[], argc)
{
	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(sayWord[0] == '!' || sayWord[0] == '/')
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:TeamSay_Callback(client, const String:command[], argc)
{
	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));
	
	if(sayWord[0] == '!' || sayWord[0] == '/')
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Event_ServerDontNeedPrint(Handle:event, const String:name[], bool:dontBroadcast)
{
    return Plugin_Handled;
}

public Action:Event_NameDontNeedPrint(Handle:event, const String:name[], bool:dontBroadcast)
{
	return Plugin_Handled;
}