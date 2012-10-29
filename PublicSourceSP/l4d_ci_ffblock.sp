/* Plugin Template generated by Pawn Studio */

#include <sourcemod>
#include <sdkhooks>

/*
* Version 1.0
* - Blocks Damage to CI from SI (Except Tank)
* 
* Version 1.1
* - Added CVar that controls how many hits common need to die. (Default is L4D1 Style - 5 Scratches/Punches)
* - Added a check for common health in case a CFG adjusts it.
*/

static const String:CLASSNAME_INFECTED[]  	= "infected";

//In case a CFG uses a different Common Health, adjust to it.
new Handle: g_hCvarCommonHealth       = INVALID_HANDLE;
//Cvar to determine how many hits would cause the common to die.
new Handle:g_hCvarDamage              = INVALID_HANDLE;

public Plugin:myinfo = 
{
    name = "SI - CI FF Block",
    author = "Sir",
    description = "Modifies FF from SI (Except Tank) to CI",
    version = "1.1",
    url = "https://github.com/SirPlease/SirCoding"
}

public OnPluginStart()
{
    //CVars.
    g_hCvarCommonHealth = FindConVar("z_health");
    g_hCvarDamage = CreateConVar("common_hits", "5", "Hits needed from SI before a common dies - 0 = Block FF, 5 = L4D1 Style (5Hits)");
}

public OnEntityCreated(entity, const String:classname[])
{
    if (StrEqual(classname, CLASSNAME_INFECTED, false))
    {
        //Hook Common Infected
        SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
    //Check if Damage has to be corrected - Intensively tested on both 30, 60 and 100 Tick. Server performance does not decrease.
    if (!inflictor || !attacker || !victim || !IsValidEdict(victim) || !IsValidEdict(inflictor) || GetClientTeam(attacker) != 3 || IsTank(attacker)) return Plugin_Continue;
    else if(GetConVarInt(g_hCvarDamage) > 0)
    {
        damage = float(GetConVarInt(g_hCvarCommonHealth) / GetConVarInt(g_hCvarDamage));
        return Plugin_Changed;
    }
    return Plugin_Handled;
}

stock bool:IsTank(client)
{
    return (IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}