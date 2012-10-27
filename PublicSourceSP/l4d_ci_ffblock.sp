/* Plugin Template generated by Pawn Studio */

#include <sourcemod>
#include <sdkhooks>

// Plugin is made because common should not die in one hit (L4D1 needs 5 scratches)
// This nullifies a lot of potential damage when enemies are swarmed and an SI wants to go for a scratch as well.


// I didn't see the need to put cvars in this.
// Could eventually be integrated with l4d2_si_ffblock, potentially even add witch protection.

static const String:CLASSNAME_INFECTED[]  	= "infected";

public Plugin:myinfo = 
{
	name = "SI - CI FF Block",
	author = "Sir",
	description = "Blocks FF from SI (Except Tank) to CI",
	version = "1.0",
	url = "https://github.com/SirPlease/SirCoding"
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
	//Check if Damage has to be corrected - Intensively tested on both 30 and 60 Tick. Server performance does not decrease.
	//Still in need of testing on 100 Tick Servers.
	if (!inflictor || !attacker || !victim || !IsValidEdict(victim) || !IsValidEdict(inflictor) || GetClientTeam(attacker) != 3) return Plugin_Continue;
	else if (GetEntProp(attacker, Prop_Send, "m_zombieClass") == 8) return Plugin_Continue;
	return Plugin_Handled;
}