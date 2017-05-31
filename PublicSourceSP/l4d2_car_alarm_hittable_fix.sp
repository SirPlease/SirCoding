#pragma semicolon 1

#include <sourcemod> 
#include <sdkhooks> 
#include <sdktools> 

public Plugin:myinfo = 
{
	name = "L4D2 Car Alarm Hittable Fix",
	author = "Sir",
	description = "Disables the Car Alarm when a Tank hittable hits the alarmed car.",
	version = "1.0",
	url = "nah"
};

public OnEntityCreated(entity, const String:classname[]) 
{
	// Hook Alarmed Cars.
	if(!StrEqual(classname, "prop_car_alarm")) return; 
	SDKHook(entity, SDKHook_Touch, OnAlarmCarTouch); 
}

public OnAlarmCarTouch(car, entity) 
{ 
	// You never know.. ;D
	if(!IsValidEntity(entity)) return;

	new String:eClassname[64];
	GetEdictClassname(entity, eClassname, sizeof(eClassname));

	if(StrEqual(eClassname, "prop_physics"))
	{
		// This returns 1 on every hittable at all times.
		if (GetEntProp(entity, Prop_Send, "m_hasTankGlow") > 0)
		{
			// Disable the Car Alarm
			AcceptEntityInput(car, "Disable");

			// Fake damage to Car to stop the glass from still blinking, delay it to prevent issues.
			CreateTimer(0.3, DisableAlarm, car);

			// Unhook car, we don't need it anymore.
			SDKUnhook(car, SDKHook_Touch, OnAlarmCarTouch);
		}
	}
}

public Action:DisableAlarm(Handle:timer, any:car)
{
	new Tank = GetTank();
	if (Tank != -1) SDKHooks_TakeDamage(car, Tank, Tank, 0.0);
}

stock GetTank()
{
	new Tank = -1;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidTank(i))
		{
			Tank = i;
			break;
		}
	}
	return Tank;
}

bool:IsValidTank(client) { 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client)) return false;
    return (IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8); 
}  