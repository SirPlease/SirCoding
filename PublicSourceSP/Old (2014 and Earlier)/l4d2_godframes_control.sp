#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4downtown>
#include <l4d2_direct>

#define CLASS_LENGTH		64

#define SI_FLAG_HUNTER	1
#define SI_FLAG_SMOKER	1
#define SI_FLAG_JOCKEY	1
#define SI_FLAG_CHARGER	1

//cvars
new Handle:	hHittable 				= INVALID_HANDLE;
new Handle:	hWitch 					= INVALID_HANDLE;
new Handle: hTank                   = INVALID_HANDLE;
new Handle:	hSpit					= INVALID_HANDLE;
new Handle:	hCommon					= INVALID_HANDLE;
new Handle:	hHunter 				= INVALID_HANDLE;
new Handle:	hSmoker 				= INVALID_HANDLE;
new Handle:	hJockey 				= INVALID_HANDLE;
new Handle:	hCharger 				= INVALID_HANDLE;
new Handle: hSpitFlags				= INVALID_HANDLE;
new Handle: hFFFlags				= INVALID_HANDLE;
new Handle: hCommonFlags			= INVALID_HANDLE;
new Handle: hFF                     = INVALID_HANDLE;

//fake godframes
new Float:	fFakeGodframeEnd[MAXPLAYERS + 1];
new			iLastSI			[MAXPLAYERS + 1];

public Plugin:myinfo = 
{
    name = "L4D2 Godframes Control (starring Austin Powers, Baby Yeah!)",
    author = "Stabby, CircleSquared",
    version = "0.2.4",
    description = "Allows for control of what gets godframed and what doesnt."
};

/*
* Slight edit by Sir;
* 
* - Added control for Friendly-Fire Godframes. (By default it's on and only covers Jockied/Pulled Survivors)
* - Added control for Tank-override on Godframes.
*/

public OnPluginStart()
{
    hHittable	= CreateConVar( "gfc_hittable_override",	"1",
    "Allow hittables to always ignore godframes.",
    FCVAR_PLUGIN, true, 0.0, true, 1.0 );
    hWitch		= CreateConVar( "gfc_witch_override", 		"1",
    "Allow witches to always ignore godframes.",
    FCVAR_PLUGIN, true,	0.0, true, 1.0 );
    hTank		= CreateConVar( "gfc_tank_override", 		"0",
    "Allow tanks to always ignore godframes.",
    FCVAR_PLUGIN, true,	0.0, true, 1.0 );
    hSpit		= CreateConVar( "gfc_spit_extra_time", 		"0.0",
    "Additional godframe time before spit damage is allowed.",
    FCVAR_PLUGIN, true,	0.0, true, 3.0 );
    hFF		    = CreateConVar( "gfc_ff_time", 		"0.8",
    "Additional godframe time before friendly fire damage is allowed.",
    FCVAR_PLUGIN, true,	0.0, true, 3.0 );
    hCommon		= CreateConVar( "gfc_common_extra_time", 	"0.0",
    "Additional godframe time before common damage is allowed.",
    FCVAR_PLUGIN, true,	0.0, true, 3.0 );	
    hHunter		= CreateConVar( "gfc_hunter_duration",		"2.0",
    "How long should godframes after a pounce last?",
    FCVAR_PLUGIN, true, 0.0, true, 3.0 );
    hJockey		= CreateConVar( "gfc_jockey_duration",		"2.0",
    "How long should godframes after a ride last?",
    FCVAR_PLUGIN, true, 0.0, true, 3.0 );
    hSmoker		= CreateConVar( "gfc_smoker_duration",		"2.0",
    "How long should godframes after a pull or choke last?",
    FCVAR_PLUGIN, true, 0.0, true, 3.0 );
    hCharger	= CreateConVar( "gfc_charger_duration",		"2.0",
    "How long should godframes after a pummel last?",
    FCVAR_PLUGIN, true, 0.0, true, 3.0 );
    hSpitFlags  = CreateConVar( "gfc_spit_zc_flags",     "0",
    "Which classes will be affected by extra spit protection time. 1 - Hunter. 2 - Smoker. 4 - Jockey. 8 - Charger.",
    FCVAR_PLUGIN, true,  0.0, true, 15.0 );
    hFFFlags  = CreateConVar( "gfc_ff_flags",     "6",
    "Which classes will be affected by extra FF protection time. 1 - Hunter. 2 - Smoker. 4 - Jockey. 8 - Charger.",
    FCVAR_PLUGIN, true,  0.0, true, 15.0 );
    hCommonFlags= CreateConVar( "gfc_common_zc_flags",     "6",
    "Which classes will be affected by extra common protection time. 1 - Hunter. 2 - Smoker. 4 - Jockey. 8 - Charger.",
    FCVAR_PLUGIN, true,  0.0, true, 15.0 );
    
    //Survivor Gets Released
    HookEvent("tongue_release", 		PostSurvivorRelease);
    HookEvent("pounce_end", 			PostSurvivorRelease);
    HookEvent("jockey_ride_end", 		PostSurvivorRelease);
    HookEvent("charger_pummel_end", 	PostSurvivorRelease);
    
    //Start
    HookEvent("round_start",			OnRoundStart);
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    for (new i = 1; i <= MaxClients; i++)	//clear both fake and real just because
    {
        fFakeGodframeEnd[i] = 0.0;
    }
}

public PostSurvivorRelease(Handle:event, const String:name[], bool:dontBroadcast)
{	
    new victim = GetClientOfUserId(GetEventInt(event,"victim"));
    
    if (!IsClientAndInGame(victim))	{ return; }	//just in case
    
    //sets fake godframe time based on cvars for each ZC
    if (StrContains(name, "tongue") != -1)
    {
        fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hSmoker);
        iLastSI[victim] = 2;
        return;
    }
    else if (StrContains(name, "pounce") != -1)
    {
        fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hHunter);
        iLastSI[victim] = 1;
        return;
    }
    else if (StrContains(name, "jockey") != -1)
    {
        fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hJockey);
        iLastSI[victim] = 4;
        return;
    }
    else if (StrContains(name, "charger") != -1)
    {
        fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hCharger);
        iLastSI[victim] = 8;
        return;
    }
    return;	
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
    if (GetClientTeam(victim) != 2 || !IsValidEdict(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor)) { return Plugin_Continue; }
    
    new CountdownTimer:cTimerGod = L4D2Direct_GetInvulnerabilityTimer(victim);
    if (cTimerGod != CTimer_Null) { CTimer_Invalidate(cTimerGod); }
    
    decl String:sClassname[CLASS_LENGTH];
    GetEntityClassname(inflictor, sClassname, CLASS_LENGTH);
    
    new Float:fTimeLeft = fFakeGodframeEnd[victim] - GetGameTime();
    
    if (StrEqual(sClassname, "infected") && (iLastSI[victim] & GetConVarInt(hCommonFlags)))		//common infected
    {
        fTimeLeft += GetConVarFloat(hCommon);
    }
    else if (StrEqual(sClassname, "insect_swarm") && (iLastSI[victim] & GetConVarInt(hSpitFlags)))	//spit
    {
        fTimeLeft += GetConVarFloat(hSpit);
    }
    else if (GetClientTeam(attacker) == 2 && (iLastSI[victim] & GetConVarInt(hFFFlags))) //friendly-fire
    {
        fTimeLeft += GetConVarFloat(hFF);
    }
    
    if (fTimeLeft > 0.0)	//means fake god frames are in effect
    {
        if (StrEqual(sClassname, "prop_physics"))	//hittables
        {
            if (GetConVarBool(hHittable))		{ return Plugin_Continue; }
        }
        
        if (StrEqual(sClassname, "witch"))		//witches
        {
            if (GetConVarBool(hWitch)) 		{ return Plugin_Continue; }
        }
        
        if (IsTank(attacker))		//tanks
        {
            if (GetConVarBool(hTank)) 		{ return Plugin_Continue; }
        }
        return Plugin_Handled;
    }
    else
    {
        iLastSI[victim] = 0;
    }
    return Plugin_Continue;
}

stock IsClientAndInGame(client)
{
    if (0 < client && client < MaxClients)
    {
        return IsClientInGame(client);
    }
    return false;
}

stock bool:IsTank(client)
{
    if (IsClientAndInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8) return true;
    return false;
}