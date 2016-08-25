#include <sourcemod>
#include <sdktools>
#include <colors>

/*
* Version 1.0:
*
* - Setup the Basics
* 
* > Keep Track of Deaths, if Round Is Live and broadcast Deaths or if the Entire team has failed.
* > Give StartRound Items.
* > Give Rewards on Medals.
* 
* Version 1.1:
*
* - Code Improval & Fixes
*
* > Replaced Bot Ammo Timer with a simple Event Hook + Check
* > Fixed Errors caused by unvalid Clients on the Death Event.
* > Created a function rather than re-doing the code over and over again.
* > Give the Players items on Survival Round Start instead of Spawn.
*
* TODO:
*
* - Add Ideas for Improving Bots.
* - Add Storage System for Items.
* - Add Difficulty System.
* - Add more "OfficialNess", by tricking the game that you actually got a new existing medal.
* - Deal with Pauses.
* - Fix Maps that were modded in V1.0 to work with Survival, but broken by Valve afterwards.
*/

public Plugin:myinfo = 
{
    name = "SurvivalHC",
    author = "Sir",
    description = "Survival Hardcore's core Plugin",
    version = "1.1",
}

//Welcome
new Handle:WelcomeTimers[MAXPLAYERS+1];

//Survival Medals
new Handle:g_hBronze = INVALID_HANDLE;
new Handle:g_hSilver = INVALID_HANDLE;
new Handle:g_hGold = INVALID_HANDLE;
new Handle:g_hDiamond = INVALID_HANDLE;
new Handle:g_hMasterful = INVALID_HANDLE;
new Handle:g_hGodlike = INVALID_HANDLE;

new RoundEnd;

public OnPluginStart()
{
    HookEvent("player_death", Death);
    HookEvent("survival_round_start", Start);
    HookEvent("round_end", End);
    HookEvent("total_ammo_below_40", AlmostOut);
}

public OnClientPutInServer(client)
{
    WelcomeTimers[client] = CreateTimer(1.0, WelcomePlayer, client);
}

public Action:WelcomePlayer(Handle:timer, any:client)
{
    CPrintToChat(client, "{default}[{blue}SurvivalHC{default}] Vote to change map by typing {olive}!mapvote");
    CPrintToChat(client, "{default}[{blue}SurvivalHC{default}] Spectate by typing: {olive}!spectate");
    CPrintToChat(client, "{default}[{blue}SurvivalHC{default}] Play by typing: {olive}!join");
}

public Start(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_hBronze = CreateTimer(240.0, Bronze, _, TIMER_FLAG_NO_MAPCHANGE);
    g_hSilver = CreateTimer(420.0, Silver, _, TIMER_FLAG_NO_MAPCHANGE);
    g_hGold = CreateTimer(600.0, Gold, _, TIMER_FLAG_NO_MAPCHANGE);
    g_hDiamond = CreateTimer(750.0, Diamond, _, TIMER_FLAG_NO_MAPCHANGE);
    g_hMasterful = CreateTimer(900.0, Masterful, _, TIMER_FLAG_NO_MAPCHANGE);
    g_hGodlike = CreateTimer(1200.0, Godlike, _, TIMER_FLAG_NO_MAPCHANGE);

    rewardClients(true, true, true, false, "{default}[{blue}SurvivalHC{default}] Good Luck!");
    RoundEnd = 0;
}

public AlmostOut(Handle:event, const String:name[], bool:dontBroadcast)
{
    new player = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsValidClient(player) && IsFakeClient(player))
    {
        new flags = GetCommandFlags("give");    
        SetCommandFlags("give", flags & ~FCVAR_CHEAT);

        FakeClientCommand(player, "give ammo");

        SetCommandFlags("give", flags|FCVAR_CHEAT);
    }
}

public End(Handle:event, const String:name[], bool:dontBroadcast)
{
    RoundEnd++;
    if (RoundEnd > 1) return;

    PrintHintTextToAll("Survivor Team has failed.");
    if (g_hBronze != INVALID_HANDLE)
    {
        KillTimer(g_hBronze);
        g_hBronze = INVALID_HANDLE;
    }
    if (g_hSilver != INVALID_HANDLE)
    {
        KillTimer(g_hSilver);
        g_hSilver = INVALID_HANDLE;
    }
    if (g_hGold != INVALID_HANDLE)
    {
        KillTimer(g_hGold);
        g_hGold = INVALID_HANDLE;
    }
    if (g_hDiamond != INVALID_HANDLE)
    {
        KillTimer(g_hDiamond);
        g_hDiamond = INVALID_HANDLE;
    }
    if (g_hMasterful != INVALID_HANDLE)
    {
        KillTimer(g_hMasterful);
        g_hMasterful = INVALID_HANDLE;
    }
    if (g_hGodlike != INVALID_HANDLE)
    {
        KillTimer(g_hGodlike);
        g_hGodlike = INVALID_HANDLE;
    }
}

public Action:Bronze(Handle:Timer)
{
    rewardClients(false, false, false, false, "{default}[{blue}SurvivalHC{default}] {olive}Bronze Medal {default}Achieved")
    g_hBronze = INVALID_HANDLE;
    return Plugin_Continue;
}

public Action:Silver(Handle:Timer)
{
    rewardClients(true, false, true, false, "{default}[{blue}SurvivalHC{default}] {olive}Silver Medal {default}Achieved")
    g_hSilver = INVALID_HANDLE;
    return Plugin_Continue;
}

public Action:Gold(Handle:Timer)
{
    rewardClients(true, true, true, false, "{default}[{blue}SurvivalHC{default}] {olive}Gold Medal {default}Achieved")
    g_hGold = INVALID_HANDLE;
    return Plugin_Continue;
}

public Action:Diamond(Handle:Timer)
{
    rewardClients(true, true, true, true, "{default}[{blue}SurvivalHC{default}] {olive}Diamond Medal {default}Achieved")
    g_hDiamond = INVALID_HANDLE;
    return Plugin_Continue;
}

public Action:Masterful(Handle:Timer)
{
    rewardClients(true, true, true, true, "{default}[{blue}SurvivalHC{default}] {olive}Masterful Medal {default}Achieved")
    g_hMasterful = INVALID_HANDLE;
    return Plugin_Continue;
}

public Action:Godlike(Handle:Timer)
{
    rewardClients(true, true, true, true, "{default}[{blue}SurvivalHC{default}] {olive}Godlike Medal {default}Achieved")
    g_hGodlike = INVALID_HANDLE;
    return Plugin_Continue;
}

public Death(Handle:event, const String:name[], bool:dontBroadcast)
{
    //Get Client from User ID and then get Team from Client retrieved.
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    {
        //Team 2 = Survivors.
        if(IsValidClient(victim) && GetClientTeam(victim)==2)
        {	
            PrintHintTextToAll("%N has been slaughtered", victim);
        }
    }
}

rewardClients(bool:pills, bool:medkit, bool:throwable, bool:health, String:sText[])
{
    //Allow us to quickly use cheats, used to give items!
    new flags = GetCommandFlags("give");    
    SetCommandFlags("give", flags & ~FCVAR_CHEAT);

    //For loops, my favorite :)
    for (new i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i)==2 && IsPlayerAlive(i))
        {
            //Check player Inventories for Items
            new iThrow = GetPlayerWeaponSlot(i, 2);
            new iKit = GetPlayerWeaponSlot(i, 3);
            new iPills = GetPlayerWeaponSlot(i, 4);

            CPrintToChat(i, "%s", sText);
            if (pills)
            {
                // If the Player already has pills, store these for later use!
                if(iPills == -1) FakeClientCommand(i, "give pain_pills");
                else {}
            }
            if (medkit)
            {
                if(iKit == -1) FakeClientCommand(i, "give first_aid_kit");
                else {}
            }
            if (throwable)
            {
                if(iThrow == -1)
                {
                    switch (GetRandomInt(0, 2))
                    {
                        case 0: FakeClientCommand(i, "give pipe_bomb");
                        case 1: FakeClientCommand(i, "give molotov");
                        case 2: FakeClientCommand(i, "give vomitjar");
                    }
                }
                else {}
            }
            if (health)
            {
                FakeClientCommand(i, "give health")
            }
        }
    }

    //No more Cheats Please!
    SetCommandFlags("give", flags|FCVAR_CHEAT);
}

bool:IsValidClient(client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    return true;
}