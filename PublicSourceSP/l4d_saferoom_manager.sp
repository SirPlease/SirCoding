/* Plugin Template generated by Pawn Studio */

#include <sourcemod>
#include <l4d2lib>
#include <l4d2util_tanks>
#include <sdktools>

/******************
///////////////////
////////Version 1.0
* 
* - End Saferoom Door closes shut to prevent SI from Sneaking in there.
* - While Tank is up the End Saferoom Door can't be closed unless 50% of the Team is Dead/Incapped.
* > In 1v1 and 2v2 you're forced to kill the Tank.
* 
* 
///////////////////
******************/

//Checking & Saving Entities
new Surv;
new Door1;
new Door2;
new DoorsFound;

//Save Entity Vectors
new Float:First[3]
new Float:Second[3]

//Survivor Spawn
new Float:SurvivorStart[3]

//Has survivor made it to the saferoom? / How many made it to the saferoom?
new checkpointreached[MAXPLAYERS];
new checkpointtotal;

//CVars + Tracking
new Handle:g_hSafeEndClose = INVALID_HANDLE;
new Handle:g_hSafeEndTankBlock = INVALID_HANDLE;

new Handle:g_hSurvivorLimit = INVALID_HANDLE;
new IsIncapped[MAXPLAYERS];

public Plugin:myinfo = 
{
    name = "Saferoom Door Manager",
    author = "Sir",
    description = "Manages Saferoom Doors",
    version = "1.0",
    url = "https://github.com/SirPlease/SirCoding"
}

public OnPluginStart()
{
    //CVars
    g_hSafeEndClose = CreateConVar("safe_end_lock", "1", "Close end Saferoom Door on round start?");
    g_hSafeEndTankBlock = CreateConVar("safe_end_tank", "1", "Stop Survivors from closing saferoom during Tank when 50% or more is Alive");
    
    //Tracking
    g_hSurvivorLimit = FindConVar("survivor_limit");
    
    //Saferoom Leaving and Entering
    HookEvent("player_entered_checkpoint", Player_Entered_Checkpoint);
    HookEvent("player_left_checkpoint", Player_Left_Checkpoint);
    
    //Setup the Doors
    HookEvent("round_start", Round_Start);
    
    //Incap or Death - Check Door.
    HookEvent("revive_success", OnRevive); 
    HookEvent("player_death", OnDeath);
    HookEvent("player_incapacitated", OnIncap);
}

public Action:Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
    //Reset Clientside Cvars and Total.
    for(new i=1;i<=MaxClients;i++)
    {
        checkpointreached[i] = 0;
        IsIncapped[i] = 0;
    }
    checkpointtotal = 0;
    
    //Empty Storage
    Door1 = -1;
    Door2 = -1;
    Surv = -1;
    SurvivorStart[0] = 0.0;
    First[0] = 0.0;
    Second[0] = 0.0;
    DoorsFound = 0;
    
    //Start Checking the Map
    CreateTimer(1.2, CheckMap); 
}

public Action:CheckMap(Handle:timer)
{
    //Find Survivor Spawn
    FindStart();
    
    //Saferoom Doors
    FindDoors();
}

public Action:CheckEnd(Handle:timer)
{
    if (!GetConVarBool(g_hSafeEndClose)) return;
    
    if (DoorsFound > 1)
    {
        //Checks distance between found "End Saferoom" Doors and takes furthest.
        if (GetVectorDistance(First, SurvivorStart) > GetVectorDistance(Second, SurvivorStart)) AcceptEntityInput(Door1, "Close");
        else AcceptEntityInput(Door2, "Close");  
    }
    else AcceptEntityInput(Door1, "Close"); 
}

FindStart()
{
    new Float:Location[3]
    while((Surv = Sub_FindEntityByClassname(Surv, "info_survivor_position")) != -1)
    {
        {
            GetEntPropVector(Surv, Prop_Send, "m_vecOrigin", Location)
            SurvivorStart = Location;
        }
    }
}

FindDoors()
{
    new Safe = -1;
    while((Safe = Sub_FindEntityByClassname(Safe, "prop_door_rotating_checkpoint")) != -1)
    {
        //Only Affects end Saferoom
        decl String:sModel[128];
        GetEntPropString(Safe, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
        
        if (StrEqual(sModel, "models/props_doors/checkpoint_door_02.mdl")
        || StrEqual(sModel, "models/props_doors/checkpoint_door_-02.mdl"))
        {
            //Store Entities
            DoorsFound++
            
            //If multiple entities have the "End Saferoom" Model seperate them and check them later.
            if (DoorsFound == 1)
            {
                Door1 = Safe;
                GetEntPropVector(Safe, Prop_Send, "m_vecOrigin", First)
                
                //Check Timer
                CreateTimer(2.0, CheckEnd);
            }
            else 
            {
                Door2 = Safe;
                GetEntPropVector(Safe, Prop_Send, "m_vecOrigin", Second)
            }	
        }
    }
}

public Sub_FindEntityByClassname(StartEntity, const String:ClassName[])
{
    while (StartEntity > -1 && !IsValidEntity(StartEntity))
    {
        StartEntity--;
    }
    
    return FindEntityByClassname(StartEntity, ClassName);
}  

public Action:Player_Entered_Checkpoint(Handle:event, const String:name[], bool:dontBroadcast)
{
    new entered = GetClientOfUserId(GetEventInt(event,"userid"));
    new door = GetEventInt(event, "door")
    
    if (IsValidClient(entered))
    {
        //Is Actual End Saferoom?
        //Check if there are multiple "End Saferoom" Doors.
        if ((DoorsFound == 1 && Door1 == door)  || Door2 == door)
        {
            //Survivor Entered
            if (GetClientTeam(entered) == 2) 
            {
                checkpointreached[entered] = 1;
                checkpointtotal++;
                
                //Check
                if (GetConVarBool(g_hSafeEndTankBlock)) CanWeClose();
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
        
        //Check
        if (GetConVarBool(g_hSafeEndTankBlock) && checkpointtotal > 0) CanWeClose();
    }
}

public Action:OnRevive(Handle:event, const String:name[], bool:dontBroadcast)
{
    new revive = GetClientOfUserId(GetEventInt(event,"subject"));
    if (!IsValidClient(revive) || GetClientTeam(revive ) != 2) return
    
    //Incapped, do a check.
    IsIncapped[revive] = 0;
    
    if (GetConVarBool(g_hSafeEndTankBlock) && checkpointtotal > 0) CanWeClose();
}

public Action:OnDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new death = GetClientOfUserId(GetEventInt(event,"userid"));
    if (!IsValidClient(death) || GetClientTeam(death) != 2) return;
    
    //You're dead, you didn't make it.
    if (checkpointreached[death] == 1)
    {
        checkpointreached[death] = 0;
        checkpointtotal--;
    }
    
    //Need a recheck
    if (GetConVarBool(g_hSafeEndTankBlock) && checkpointtotal > 0) CanWeClose();
}

public Action:OnIncap(Handle:event, const String:name[], bool:dontBroadcast)
{
    new incap = GetClientOfUserId(GetEventInt(event,"userid"));
    if (!IsValidClient(incap) || GetClientTeam(incap) != 2) return;
    
    //Incapped, do a check.
    IsIncapped[incap] = 1;
}

//Doesn't trigger if Tank turns AI and gets kicked.
public L4D2_OnTankDeath()
{
    if (GetConVarBool(g_hSafeEndTankBlock)) CanWeClose();
}

CanWeClose()
{
    if(!CheckClose())
    {
        if (DoorsFound > 1) DispatchKeyValue(Door2, "spawnflags", "32768");
        else DispatchKeyValue(Door1, "spawnflags", "32768");
    }
    else
    {
        if (DoorsFound > 1)DispatchKeyValue(Door2, "spawnflags", "8192");
        else DispatchKeyValue(Door1, "spawnflags", "8192");
    }
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

bool:IsValidClient(client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    return true;
}