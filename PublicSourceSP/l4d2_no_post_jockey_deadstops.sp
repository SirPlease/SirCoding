#pragma semicolon 1

#include <sourcemod>
#include <left4downtown> // min v0.5.7

public Plugin:myinfo = 
{
	name = "L4D2 No Post-Jockeyed Shoves",
	author = "Sir",
	description = "L4D2 has a nasty bug which Survivors would exploit and this fixes that. (Holding out a melee and spamming shove, even if the jockey was behind you, would self-clear yourself after the Jockey actually landed.",
	version = "1.0",
	url = "nah"
};

public Action:L4D_OnShovedBySurvivor(shover, shovee, const Float:vector[3])
{
	if (!IsSurvivor(shover) || !IsJockey(shovee))
		return Plugin_Continue;
	
	if (IsJockeyed(shover)) return Plugin_Handled;
	return Plugin_Continue;
}

public Action:L4D2_OnEntityShoved(shover, shovee_ent, weapon, Float:vector[3], bool:bIsHunterDeadstop)
{
	if (!IsSurvivor(shover) || !IsJockey(shovee_ent))
		return Plugin_Continue;
	
	if (IsJockeyed(shover)) return Plugin_Handled;
	return Plugin_Continue;
}

stock bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

stock bool:IsJockey(client)  
{
	if (!IsInfected(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 5)
		return false;

	return true;
}

stock bool:IsJockeyed(client)
{
	return GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0;
}