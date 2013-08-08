#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <sdkhooks>
#include <smlib>
#include <colors> 

// - Enable/Disable "Fixes"
new Handle:g_hServerCVar             = INVALID_HANDLE;
new Handle:g_hPubBlock               = INVALID_HANDLE;

// - PubBlocker
new bool: bHandled = false;
new Handle: hTimer = INVALID_HANDLE;

//<<<<<<<<<<<<<<<<<<<<< TICKRATE FIXES >>>>>>>>>>>>>>>>>>
//// ------- Fast Pistols ---------
// ***************************** 
//Cvars
new Handle:g_hPistolDelayDualies = INVALID_HANDLE;
new Handle:g_hPistolDelaySingle = INVALID_HANDLE;
new Handle:g_hPistolDelayIncapped = INVALID_HANDLE;

//Floats
new Float:g_fNextAttack[MAXPLAYERS + 1];
new Float:g_fPistolDelayDualies = 0.1;
new Float:g_fPistolDelaySingle = 0.2;
new Float:g_fPistolDelayIncapped = 0.3;

new Float:tickInterval;
new Float:tickRRate;

//Cvar Check & Adjust
new Handle: g_hCvarGravity       = INVALID_HANDLE;
//*****************************************************************************
//*****************************************************************************
//-----------------------------------------------------------------------------

/*
* Version 1.0
* - Prevent Server CVar change Spam on Server Load.
* 
* Version 1.1
* - Integrated PubBlocker
* > Checks for l4d_ready_enabled cvar to decide whether to "activate"
* 
* - Added CVar Toggles for Functions
* 
* Version 1.2
* - Integrated Tickrate Fixes
* - Fixes are applied if Tickrate appears to be 60 or higher.
* 
* Version 1.3
* - Implemented a fix for an issue that causes SI to survive a melee attack (ZC 1-5)
* 
* Version 1.4
* - Removed two basic functions. 
* > Door Speed is replaced by a Stripper:Source Fix 
* > SI Melee Damage has turned into a seperate Plugin: l4d2_melee_fix)
* 
* - Cleaned up Code
*
* */

public Plugin:myinfo = 
{
    name = "L4D2 Game/Server Tweaks&Fixes",
    author = "Sir, Thrawn, Griffin",
    description = "What Name says",
    version = "1.4",
	url = "https://github.com/SirPlease/SirCoding"
}

public OnPluginStart()
{
    //CVars.
    g_hServerCVar = CreateConVar("GSTF_ServerCVar", "1", "Block Server CVar Changes being Broadcasted?");
    g_hPubBlock = CreateConVar("GSTF_BlockPub", "1", "Only allow Competitive Games on Server?");
    
    //Server CVar
    HookEvent("server_cvar", Event_ServerCvar, EventHookMode_Pre);
    
    //Is Server 40+ Tick?
    tickInterval = GetTickInterval();
    if(0.0 < tickInterval) tickRRate = 1.0/tickInterval;
    if(tickRRate >= 40)
    {
        //Hook Pistols
        for (new client = 1; client <= MaxClients; client++)
        {
            if (!IsClientInGame(client)) continue;
            SDKHook(client, SDKHook_PostThinkPost, Hook_OnPostThinkPost);
        }
        g_hPistolDelayDualies = CreateConVar("l4d_pistol_delay_dualies", "0.1", "Minimum time (in seconds) between dual pistol shots",
        FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);
        g_hPistolDelaySingle = CreateConVar("l4d_pistol_delay_single", "0.2", "Minimum time (in seconds) between single pistol shots",
        FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);
        g_hPistolDelayIncapped = CreateConVar("l4d_pistol_delay_incapped", "0.3", "Minimum time (in seconds) between pistol shots while incapped",
        FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY, true, 0.0, true, 5.0);
        
        UpdatePistolDelays();
        
        HookConVarChange(g_hPistolDelayDualies, Cvar_PistolDelay);
        HookConVarChange(g_hPistolDelaySingle, Cvar_PistolDelay);
        HookConVarChange(g_hPistolDelayIncapped, Cvar_PistolDelay);
        HookEvent("weapon_fire", Event_WeaponFire);
        
        //Gravity
        g_hCvarGravity = FindConVar("sv_gravity");
        if (GetConVarInt(g_hCvarGravity) != 750) SetConVarInt(g_hCvarGravity, 750);
    }
    
    bHandled = false;
}

public OnClientPutInServer(client)
{
    if(tickRRate >= 40)
    {
        SDKHook(client, SDKHook_PreThink, Hook_OnPostThinkPost);
        g_fNextAttack[client] = 0.0;
    }
}

public OnClientPostAdminCheck(client)
{   
    if(!GetConVarBool(g_hPubBlock) || GetConVarBool(FindConVar("l4d_ready_enabled"))) return;
    
    if (bHandled)
    {
        if (IsAdminHere() > 0) Handled();
        return;
    }
    
    if(!GetConVarBool(g_hPubBlock) || bHandled || GetConVarBool(FindConVar("l4d_ready_enabled")) || IsAdminHere() > 0 || !CheckMaps()) return;
    
    if(IsValidClient(client) && !IsFakeClient(client))
    {
        bHandled = true;
        CreateTimer(25.0, NotifyPubs, _, TIMER_REPEAT);
        hTimer = CreateTimer(300.0, KickPubs);
    }
}

public OnClientDisconnect(client)
{
    SDKUnhook(client, SDKHook_PreThink, Hook_OnPostThinkPost);
}

public Cvar_PistolDelay(Handle:convar, const String:oldValue[], const String:newValue[])
{
    UpdatePistolDelays();
}

UpdatePistolDelays()
{
    g_fPistolDelayDualies = GetConVarFloat(g_hPistolDelayDualies);
    if (g_fPistolDelayDualies < 0.0) g_fPistolDelayDualies = 0.0;
    else if (g_fPistolDelayDualies > 5.0) g_fPistolDelayDualies = 5.0;
    
    g_fPistolDelaySingle = GetConVarFloat(g_hPistolDelaySingle);
    if (g_fPistolDelaySingle < 0.0) g_fPistolDelaySingle = 0.0;
    else if (g_fPistolDelaySingle > 5.0) g_fPistolDelaySingle = 5.0;
    
    g_fPistolDelayIncapped = GetConVarFloat(g_hPistolDelayIncapped);
    if (g_fPistolDelayIncapped < 0.0) g_fPistolDelayIncapped = 0.0;
    else if (g_fPistolDelayIncapped > 5.0) g_fPistolDelayIncapped = 5.0;
}

public Hook_OnPostThinkPost(client)
{
    // Human survivors only
    if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2) return;
    new activeweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEdict(activeweapon)) return;
    decl String:weaponname[64];
    GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));
    if (strcmp(weaponname, "weapon_pistol") != 0) return;
    
    new Float:old_value = GetEntPropFloat(activeweapon, Prop_Send, "m_flNextPrimaryAttack");
    new Float:new_value = g_fNextAttack[client];
    
    // Never accidentally speed up fire rate
    if (new_value > old_value)
    {
        // PrintToChatAll("Readjusting delay: Old=%f, New=%f", old_value, new_value);
        SetEntPropFloat(activeweapon, Prop_Send, "m_flNextPrimaryAttack", new_value);
    }
}

public Action:Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2) return;
    new activeweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEdict(activeweapon)) return;
    decl String:weaponname[64];
    GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));
    if (strcmp(weaponname, "weapon_pistol") != 0) return;
    // new dualies = GetEntProp(activeweapon, Prop_Send, "m_hasDualWeapons");
    if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
    {
        g_fNextAttack[client] = GetGameTime() + g_fPistolDelayIncapped;
    }
    // What is the difference between m_isDualWielding and m_hasDualWeapons ?
    else if (GetEntProp(activeweapon, Prop_Send, "m_isDualWielding"))
    {
        g_fNextAttack[client] = GetGameTime() + g_fPistolDelayDualies;
    }
    else
    {
        g_fNextAttack[client] = GetGameTime() + g_fPistolDelaySingle;
    }
}

//Server Cvar
//-----------

public Action:Event_ServerCvar(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(GetConVarBool(g_hServerCVar)) return Plugin_Handled;
    return Plugin_Continue;
}

//Block Non-Competitive Games
//---------------------------

public OnClientDisconnect_Post(client)
{
    if(GetRealClientCount() == 0) Handled();
    else
    {
        if(!GetConVarBool(g_hPubBlock) || bHandled || GetConVarBool(FindConVar("l4d_ready_enabled")) || IsAdminHere() > 0 || !CheckMaps()) return;
        
        if(IsValidClient(client) && !IsFakeClient(client))
        {
            bHandled = true;
            CreateTimer(25.0, NotifyPubs, _, TIMER_REPEAT);
            hTimer = CreateTimer(150.0, KickPubs);
        }
    }	    
}

public Action:NotifyPubs(Handle:timer)
{
    if(!bHandled) return Plugin_Stop;
    
    CPrintToChatAll("{default}<{blue}PubBlocker{default}> {blue}Only use this server for {default}Competitive Play");
    CPrintToChatAll("{default}<{blue}PubBlocker{default}> {blue}Everyone will be kicked unless a {default}!match {blue}config is loaded");
    return Plugin_Continue;
}

public Action:KickPubs(Handle:timer)
{
    ServerCommand("sm_kick @all Only Competitive Play on this Server");
    Handled();
}

//Stocks and such
//------------------------------

bool:IsValidClient(client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
    return true;
}

GetRealClientCount() 
{
    new clients = 0;
    for (new i = 1; i <= GetMaxClients(); i++) 
    {
        if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i)) clients++;
    }
    return clients;
}

IsAdminHere()
{
    new clients = 0;
    for (new i = 1; i <= GetMaxClients(); i++) 
    {
        if(IsClientConnected(i) && Client_IsAdmin(i)) clients++;
    }
    return clients;
}

Handled()
{
    bHandled = false;
    if (hTimer != INVALID_HANDLE)
    {
        KillTimer(hTimer);
        hTimer = INVALID_HANDLE;
    }
}

// Check if Config has to be loaded - Makes exception for Custom Map play.
// Sloppy, but effective.
CheckMaps()
{
    decl String:mapname[128];
    GetCurrentMap(mapname, sizeof(mapname));
    
    if (strncmp(mapname, "c1", 2) == 0
    || strncmp(mapname, "c2", 2) == 0
    || strncmp(mapname, "c3", 2) == 0
    || strncmp(mapname, "c4", 2) == 0
    || strncmp(mapname, "c6", 2) == 0
    || strncmp(mapname, "c7", 2) == 0
    || strncmp(mapname, "c8", 2) == 0
    || strncmp(mapname, "c9", 2) == 0
    || strncmp(mapname, "c10", 3) == 0
    || strncmp(mapname, "c11", 3) == 0
    || strncmp(mapname, "c12", 3) == 0
    || strncmp(mapname, "c13", 3) == 0) return true;
    else if (strncmp(mapname, "c5", 2) == 0)
    {
        if (strncmp(mapname, "c5m1_dark", 9) != 0
        && strncmp(mapname, "c5m2_dark", 9) != 0
        && strncmp(mapname, "c5m3_dark", 9) != 0
        && strncmp(mapname, "c5m4_dark", 9) != 0
        && strncmp(mapname, "c5m5_dark", 9) != 0) return true;
    }
    
    return false; 
}
