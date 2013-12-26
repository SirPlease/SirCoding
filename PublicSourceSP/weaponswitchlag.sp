#include <sourcemod>
#include <sdkhooks>
#include <l4d2util>
#include <colors>

new Handle:hCvarSwitchlagUpdrate;
new Handle:hCvarSwitchlagLerp;
new Handle:gConf;
new Float:tickInterval;
new Float:tickRate;
new String:sSwitchlagUpdrate[4];
new String:sSwitchlagLerp[4];
new String:ServerTick[4];
new iSwitchlagUpdrate;
new iSwitchlagLerp;

new bool:iLag[MAXPLAYERS+1];
new Handle:iSpam[MAXPLAYERS+1];

public Plugin:myinfo = 
{
    name = "Weapon Switch Lag Fix",
    author = "Visor, Sir",
    description = "Fixes the freeze issue caused on clients by switching weapons.",
    version = "1.0.1",
    url = "<- URL ->"
}

public OnPluginStart()
{
    gConf = LoadGameConfigFile("l4d2_nexus");
    
    tickInterval = GetTickInterval();
    if(0.0 < tickInterval) tickRate = 1.0/tickInterval;
    
    hCvarSwitchlagUpdrate = CreateConVar("rm_switchlag_updrate", "30", "cl_updaterate to set to a client on weapon switch(-1:off)", FCVAR_PLUGIN);
    hCvarSwitchlagLerp = CreateConVar("rm_switchlag_interp", "0", "cl_interp_ratio set to 0 to prevent interp setting change", FCVAR_PLUGIN);
    
    iSwitchlagUpdrate = GetConVarInt(hCvarSwitchlagUpdrate);
    iSwitchlagLerp = GetConVarInt(hCvarSwitchlagLerp);
    IntToString(iSwitchlagUpdrate, sSwitchlagUpdrate, sizeof(sSwitchlagUpdrate));
    IntToString(RoundToFloor(tickRate), ServerTick, sizeof(ServerTick));
    IntToString(iSwitchlagLerp, sSwitchlagLerp, sizeof(sSwitchlagLerp));
    
    HookConVarChange(hCvarSwitchlagUpdrate, cvarChanged_SwitchlagUpdrate);
    HookConVarChange(hCvarSwitchlagLerp, cvarChanged_SwitchlagLerp);

    RegConsoleCmd("sm_lag", Lag_Cmd, "Help, I lag during weapon switch!");
}

public Action:Lag_Cmd(client, args)
{
    if (!iLag[client])
    {
        iLag[client] = true;
        SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
        CPrintToChat(client, "{blue}[{default}Weapon Switch Lag Fix {olive}({default}BETA{olive}){blue}]{default}: {olive}Enabled");
        CPrintToChat(client, "{blue}[{default}Weapon Switch Lag Fix {olive}({default}BETA{olive}){blue}]{default}: Type {blue}!lag {default}again for Disabling");
        SetClientInfo(client, "cl_updaterate", "100");
    }
    else 
    {
        iLag[client] = false;
        SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
        CPrintToChat(client, "{blue}[{default}Weapon Switch Lag Fix {olive}({default}BETA{olive}){blue}]{default}: {olive}Disabled");
        SetClientInfo(client, "cl_updaterate", "30");
    }
    return Plugin_Handled;
}

public OnClientDisconnect(client)
{
    if (iLag[client]) SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
}

public Action:OnWeaponSwitch(client, weapon)
{
    // Basic checks
    if (!IsSurvivor(client) || !IsPlayerAlive(client) || IsFakeClient(client))
        return Plugin_Continue;

    // WeaponEquip spams here
    if (IsImmobilized(client) || IsOnLadder(client)) return Plugin_Continue;

    SetClientInfo(client, "cl_interp_ratio", sSwitchlagLerp);
    SetClientInfo(client, "cl_updaterate", sSwitchlagUpdrate);

    // Prevent setting back Updaterate if client is switching weapons pretty fast
    if (iSpam[client] == INVALID_HANDLE) iSpam[client] = CreateTimer(0.2, FixRate, client);
    
    return Plugin_Continue;
}

public Action:FixRate(Handle:timer, any:client)
{
    SetClientInfo(client, "cl_updaterate", ServerTick);
    iSpam[client] = INVALID_HANDLE;
}

public cvarChanged_SwitchlagUpdrate(Handle:cvar, const String:oldValue[], const String:newValue[]) 
{
    iSwitchlagUpdrate = GetConVarInt(hCvarSwitchlagUpdrate);
    IntToString(iSwitchlagUpdrate, sSwitchlagUpdrate, sizeof(sSwitchlagUpdrate));
}

public cvarChanged_SwitchlagLerp(Handle:cvar, const String:oldValue[], const String:newValue[]) 
{
    iSwitchlagLerp = GetConVarInt(hCvarSwitchlagLerp);
    IntToString(iSwitchlagLerp, sSwitchlagLerp, sizeof(sSwitchlagLerp));
}

/**
* Checks whether a Survivor(may work on Infected too though, needs testing) is currently immobilized
*
* @param client        Client id to perform the check on
* @return              True if Survivor is immobilized, false otherwise or if an error occured during call
* @error               Unable to prepare SDK call
*/
stock bool:IsImmobilized(client)
{
    static Handle:thisSDKCall = INVALID_HANDLE;
    
    if (thisSDKCall == INVALID_HANDLE)
    {
        StartPrepSDKCall(SDKCall_Player);
        
        if (!PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "CTerrorPlayer::IsImmobilized"))
        {
            return false;
        }
        
        PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
        PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
        thisSDKCall = EndPrepSDKCall();
        
        if (thisSDKCall == INVALID_HANDLE)
        {
            return false;
        }
    }
    
    return bool:SDKCall(thisSDKCall, client, 0);
}

stock bool:IsOnLadder(entity)
{
    return GetEntityMoveType(entity) == MOVETYPE_LADDER;
}