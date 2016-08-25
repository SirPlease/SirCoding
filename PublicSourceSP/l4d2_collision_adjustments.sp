#include <sourcemod>
#include <collisionhook>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))

new bool:isPulled[MAXPLAYERS + 1] = false;

//Cvars
new Handle:hRockFix;
new Handle:hPullThrough;
new bool:bRockFix;
new bool:bPullThrough;

//Strings to dump stuff in
new String:sEntityCName[20];
new String:sEntityCNameTwo[20];



public Plugin:myinfo =
{
	name = "L4D2 Collision Adjustments",
	author = "Sir",
	version = "1.0",
	description = "Takes care of Tank Rocks getting stuck on Common Infected",
	url = "https://github.com/SirPlease/SirCoding"
};

public OnPluginStart()
{
	// Smokers
	HookEvent("tongue_grab", Event_SurvivorPulled);
	HookEvent("tongue_release", Event_PullEnd);

	//Cvars
	hRockFix = CreateConVar("collision_tankrock_common", "1", "Will Rocks go through Common Infected (and also kill them) instead of possibly getting stuck on them?")
	hPullThrough = CreateConVar("collision_smoker_common", "1", "Will Pulled Survivors go through Common Infected?")
	bRockFix = GetConVarBool(hRockFix);
	bPullThrough = GetConVarBool(hPullThrough)

	//Cvar Changes
	HookConVarChange(hRockFix, cvarChanged);
	HookConVarChange(hPullThrough, cvarChanged);
}

public Action:CH_PassFilter(ent1, ent2, &bool:result)
{
	GetEdictClassname(ent1, sEntityCName, 20);
	GetEdictClassname(ent2, sEntityCNameTwo, 20);

	if (StrEqual(sEntityCName, "infected"))
	{
		if (bRockFix && StrEqual(sEntityCNameTwo, "tank_rock"))
		{
			result = false;
			return Plugin_Handled;
		}

		if (bPullThrough && StrEqual(sEntityCNameTwo, "player") && IS_VALID_SURVIVOR(ent2) && isPulled[ent2])
		{
			result = false;
			return Plugin_Handled;			
		}
	}
	else if (StrEqual(sEntityCNameTwo, "infected"))
	{
		if (bRockFix && StrEqual(sEntityCName, "tank_rock"))
		{
			result = false;
			return Plugin_Handled;
		}

		if (bPullThrough &&  StrEqual(sEntityCName, "player") && IS_VALID_SURVIVOR(ent1) && isPulled[ent1])
		{
			result = false;
			return Plugin_Handled;			
		}
	}
	return Plugin_Continue;
}

public Event_SurvivorPulled(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	isPulled[victim] = true;
}

public Event_PullEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	isPulled[victim] = false;
}

public cvarChanged(Handle:cvar, const String:oldValue[], const String:newValue[])
{
	bRockFix = GetConVarBool(hRockFix);
	bPullThrough = GetConVarBool(hPullThrough);
}