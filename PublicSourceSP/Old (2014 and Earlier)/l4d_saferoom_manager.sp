/* Plugin Template generated by Pawn Studio */

#include <sourcemod>
#include <l4d2lib>
#include <l4d2util_tanks>
#include <sdktools>

/*
* Version 1.0
* - End Saferoom Door closes shut to prevent SI from Sneaking in there.
* - While Tank is up the End Saferoom Door can't be closed unless 50% of the Team is Dead/Incapped.
* > In 1v1 and 2v2 you're forced to kill the Tank.
* 
* Version 1.1
* - Implement a new method to hook onto End Saferoom Doors.
* - Now works in Custom Campaigns and L4D1 Maps.
* - Cleaned up Code.
///////////////////
******************/

//Checking & Saving Entities
new Door;
new TotalDoors;

//Has survivor made it to the saferoom? / How many made it to the saferoom?
new checkpointreached[MAXPLAYERS];
new checkpointtotal;

//CVars + Tracking
new Handle:g_hSafeEndClose = INVALID_HANDLE;
new Handle:g_hSafeEndTankBlock = INVALID_HANDLE;

new Handle:g_hSurvivorLimit = INVALID_HANDLE;
new IsIncapped[MAXPLAYERS+1];

new bool:bHasHooked;

//No Finals Please
new Handle:hFinalMapsTrie;
new bool:bCheckFinal;


public Plugin:myinfo = 
{
    name = "Saferoom Door Manager",
    author = "Sir",
    description = "Manages Saferoom Doors",
    version = "1.1",
    url = "https://github.com/SirPlease/SirCoding"
}

public OnPluginStart()
{
    //CVars
    g_hSafeEndClose = CreateConVar("safe_end_lock", "1", "Close end Saferoom Door on round start?");
    g_hSafeEndTankBlock = CreateConVar("safe_end_tank", "1", "Stop Survivors from closing saferoom during Tank when 50% or more is Alive");
    
    //Finals
    hFinalMapsTrie = FinalMaps();
    
    //Tracking
    g_hSurvivorLimit = FindConVar("survivor_limit");
    
    //Start!
    bHasHooked = false;
    HookEvent("round_start", Round_Start);
}

public Action:Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
    //Reset Clientside Tracking and Total.
    for(new i=1;i<=MaxClients;i++)
    {
        checkpointreached[i] = 0;
        IsIncapped[i] = 0;
    }
    checkpointtotal = 0;
    
    //Empty Storage
    Door = 0;
    TotalDoors = 0;
    bCheckFinal = false;
    
    //Map Check
    new String:sCurMap[64];
    GetCurrentMap(sCurMap, sizeof(sCurMap));
    GetTrieValue(hFinalMapsTrie, sCurMap, bCheckFinal);
}

public OnEntityCreated(entity, const String:classname[]) 
{
    if(StrEqual(classname, "prop_door_rotating_checkpoint")) //Saferoom Door
    {
        CreateTimer(1.0, DelayDoor, entity);
    }
}

public Action:DelayDoor(Handle:timer, any:entity)
{
    //Check both Model and Targetname
    decl String:sModel[128];
    decl String:sName[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
    GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
    
    if (StrEqual(sModel, "models/props_doors/checkpoint_door_02.mdl")
    || StrEqual(sModel, "models/props_doors/checkpoint_door_-02.mdl"))
    {
        //Store Doors for Recheck - Used for maps that don't trigger on the targetname check
        TotalDoors++;
        
        //Is targetname equal to these? - Triggers for most maps.
        if(StrEqual(sName, "checkpoint_entrance")
        || StrEqual(sName, "door_checkpoint"))
        {
            Door = entity;
            FoundYou();
        }
        // Found an End Saferoom door Model that's not assigned the correct targetname.
        else CreateTimer (1.0, NoDoors, entity);
    }
}

public Action:NoDoors(Handle:timer, any:entity)
{
    //There should only be one End Saferoom Model, check for it.
    if(TotalDoors == 1 && Door == 0)
    {
        Door = entity;
        FoundYou();
    }
}

FoundYou()
{
    //If map is a finale, return.
    if(bCheckFinal) return;
    
    //Close door if requested
    if (GetConVarBool(g_hSafeEndClose)) AcceptEntityInput(Door, "Close");
    
    //Hook/UnHook
    if(GetConVarBool(g_hSafeEndTankBlock)) Hook();
    else UnHook();
}

public Action:Player_Entered_Checkpoint(Handle:event, const String:name[], bool:dontBroadcast)
{
    new entered = GetClientOfUserId(GetEventInt(event,"userid"));
    new door = GetEventInt(event, "door")
    
    if (IsValidClient(entered))
    {
        //Is Actual End Saferoom?
        //Check if there are multiple "End Saferoom" Doors.
        if (door == Door)
        {
            //Survivor Entered
            if (GetClientTeam(entered) == 2) 
            {
                checkpointreached[entered] = 1;
                checkpointtotal++;
                
                //Check if we can Close.
                CanWeClose();
            }	
        }
    }
}

public Action:Player_Left_Checkpoint(Handle:event, const String:name[], bool:dontBroadcast)
{
    new left = GetClientOfUserId(GetEventInt(event,"userid"));
    
    if (IsValidClient(left) && checkpointreached[left] == 1)
    {
        //Survivor Left
        checkpointreached[left] = 0;
        checkpointtotal--;
        
        //Check if we can Close.
        if (checkpointtotal > 0) CanWeClose();
    }
}

public Action:OnRevive(Handle:event, const String:name[], bool:dontBroadcast)
{
    new revive = GetClientOfUserId(GetEventInt(event,"subject"));
    if (!IsValidClient(revive) || GetClientTeam(revive ) != 2) return;
    
    //Incapped, do a check.
    IsIncapped[revive] = 0;
    
    if (checkpointtotal > 0) CanWeClose();
}

public Action:OnDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new death = GetClientOfUserId(GetEventInt(event,"userid"));
    decl String:victim[64];
    GetEventString(event, "victimname", victim, sizeof(victim))
    
    if (!IsValidClient(death)) return;
    
    //Survivor Died.
    if(GetClientTeam(death) != 2 && checkpointreached[death] == 1)
    {
        checkpointreached[death] = 0;
        checkpointtotal--;
        
        if (checkpointtotal > 0) CanWeClose();
    }
    else if (StrEqual(victim, "tank", false)) CanWeClose();
}

public Action:OnIncap(Handle:event, const String:name[], bool:dontBroadcast)
{
    new incap = GetClientOfUserId(GetEventInt(event,"userid"));
    if (!IsValidClient(incap) || GetClientTeam(incap) != 2) return;
    
    //Incapped, do a check.
    IsIncapped[incap] = 1;
    
    if (checkpointtotal > 0) CanWeClose();
}

CanWeClose()
{
    if(!CheckClose()) DispatchKeyValue(Door, "spawnflags", "32768");
    else DispatchKeyValue(Door, "spawnflags", "8192");
}

bool:CheckClose()
{
    if(TankUp())
    {
        //Block 1v1 and 2v2 Tank Rushes
        if (GetConVarInt(g_hSurvivorLimit) <= 2) return false;
        
        // More than 50%? Block. (2 of 3) && (3+ of 4)
        if ((((float(checkpointtotal) + float(FindSurvivors())) / float(GetConVarInt(g_hSurvivorLimit))) * 100) > 50)
        {
            return false;
        }
    }
    return true;
}

bool:TankUp()
{
    for (new t = 1; t <= MaxClients; t++)
    {
        if (!IsClientInGame(t) 
            || GetClientTeam(t) != 3 
        || !IsPlayerAlive(t) 
        || GetEntProp(t, Prop_Send, "m_zombieClass") != 8)
        continue;
        
        return true; // Found tank, return
    }
    return false;
}

FindSurvivors()
{
    new Outsiders = 0;
    
    for (new outsider = 1; outsider <= MaxClients; outsider++)
    {
        if (IsValidClient(outsider) 
            && GetClientTeam(outsider) == 2
        && !checkpointreached[outsider]  
        && IsPlayerAlive(outsider) 
        && !IsIncapped[outsider]) 
        
        Outsiders++;
    }
    return Outsiders;
}

Hook()
{
    //Hooked Events Already.
    if (bHasHooked) return;
    bHasHooked = true;
    
    //Saferoom Leaving and Entering
    HookEvent("player_entered_checkpoint", Player_Entered_Checkpoint);
    HookEvent("player_left_checkpoint", Player_Left_Checkpoint);
    
    //Incap or Death - Check Door.
    HookEvent("revive_success", OnRevive); 
    HookEvent("player_death", OnDeath);
    HookEvent("player_incapacitated", OnIncap);
}

UnHook()
{
    //No Events to Unhook
    if(!bHasHooked) return;
    bHasHooked = false;
    
    //Saferoom Leaving and Entering
    UnhookEvent("player_entered_checkpoint", Player_Entered_Checkpoint);
    UnhookEvent("player_left_checkpoint", Player_Left_Checkpoint);
    
    //Incap or Death - Check Door.
    UnhookEvent("revive_success", OnRevive); 
    UnhookEvent("player_death", OnDeath);
    UnhookEvent("player_incapacitated", OnIncap);
}

Handle:FinalMaps()
{
    new Handle: trie = CreateTrie();
    
    SetTrieValue(trie, "c1m4_atrium", true);
    SetTrieValue(trie, "c2m5_concert", true);
    SetTrieValue(trie, "c3m4_plantation", true);
    SetTrieValue(trie, "c4m5_milltown_escape", true);
    SetTrieValue(trie, "c5m5_bridge", true);
    SetTrieValue(trie, "c6m3_port", true);
    SetTrieValue(trie, "c7m3_port", true);
    SetTrieValue(trie, "c8m5_rooftop", true);
    SetTrieValue(trie, "c9m2_lots", true);
    SetTrieValue(trie, "c10m5_houseboat", true);
    SetTrieValue(trie, "c11m5_runway", true);
    SetTrieValue(trie, "c12m5_cornfield", true);
    SetTrieValue(trie, "c13m4_cutthroatcreek", true);
    
    return trie;    
}

bool:IsValidClient(client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    return true;
}