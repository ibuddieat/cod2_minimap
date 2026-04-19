//	Callback Setup
//	This script provides the hooks from code into script for the gametype callback functions.

//=============================================================================
// Code Callback functions

/*================
Called by code after a player issued a command (e.g., a chat message).
Requires self processClientCommand to be executed for the command to be processed as usual.
================*/
CodeCallback_PlayerCommand(args)
{
	// Process custom binds
	if ( args.size == 4 && args[0] == "mr" )
	{
		menu = args[2];
		response = args[3];
		if ( menu == "-1" )
		{
            values = strTok(response, ":");
            if ( values.size > 1 )
			{
				menu = values[0];
				response = values[1];

				if ( menu == "binds" )
                	self thread codescripts\minimap::updateZoomLevel();
            }
		}
	}

    self processClientCommand();
}

/*================
Called by code after a player switches between weapons (including to "none").
Not called on player spawn.
Not called when the player drops weapons.
================*/
CodeCallback_WeaponChange(weaponIndex, weaponName)
{
    self thread codescripts\minimap::monitorWeapon(weaponName);
}

/*================
Called by code after the level's main script function has run.
================*/
CodeCallback_StartGameType()
{
	// If the gametype has not beed started, run the startup
	if(!isDefined(level.gametypestarted) || !level.gametypestarted)
	{
		[[level.callbackStartGameType]]();

		level.gametypestarted = true; // so we know that the gametype has been started up
	}
}

/*================
Called when a player begins connecting to the server.
Called again for every map change or tournement restart.

Return undefined if the client should be allowed, otherwise return
a string with the reason for denial.

Otherwise, the client will be sent the current gamestate
and will eventually get to ClientBegin.

firstTime will be qtrue the very first time a client connects
to the server machine, but qfalse on map changes and tournement
restarts.
================*/
CodeCallback_PlayerConnect()
{
    self endon("disconnect");
    [[level.callbackPlayerConnect]]();
}

/*================
Called when a player drops from the server.
Will not be called between levels.
self is the player that is disconnecting.
================*/
CodeCallback_PlayerDisconnect()
{
	self notify("disconnect");
	[[level.callbackPlayerDisconnect]]();
}

/*================
Called when a player has taken damage.
self is the player that took damage.
================*/
CodeCallback_PlayerDamage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset)
{
	self endon("disconnect");
	[[level.callbackPlayerDamage]](eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset);
}

/*================
Called when a player has been killed.
self is the player that was killed.
================*/
CodeCallback_PlayerKilled(eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, timeOffset, deathAnimDuration)
{
	self endon("disconnect");
	[[level.callbackPlayerKilled]](eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, timeOffset, deathAnimDuration);
}

//=============================================================================

/*================
Setup any misc callbacks stuff like defines and default callbacks
================*/
SetupCallbacks()
{
	SetDefaultCallbacks();
	
	// Set defined for damage flags used in the playerDamage callback
	level.iDFLAGS_RADIUS			= 1;
	level.iDFLAGS_NO_ARMOR			= 2;
	level.iDFLAGS_NO_KNOCKBACK		= 4;
	level.iDFLAGS_NO_TEAM_PROTECTION	= 8;
	level.iDFLAGS_NO_PROTECTION		= 16;
	level.iDFLAGS_PASSTHRU			= 32;
}

/*================
Called from the gametype script to store off the default callback functions.
This allows the callbacks to be overridden by level script, but not lost.
================*/
SetDefaultCallbacks()
{
	level.default_CallbackStartGameType = level.callbackStartGameType;
	level.default_CallbackPlayerConnect = level.callbackPlayerConnect;
	level.default_CallbackPlayerDisconnect = level.callbackPlayerDisconnect;
	level.default_CallbackPlayerDamage = level.callbackPlayerDamage;
	level.default_CallbackPlayerKilled = level.callbackPlayerKilled;
}

/*================
Called when a gametype is not supported.
================*/
AbortLevel()
{
	println("Aborting level - gametype is not supported");

	level.callbackStartGameType = ::callbackVoid;
	level.callbackPlayerConnect = ::callbackVoid;
	level.callbackPlayerDisconnect = ::callbackVoid;
	level.callbackPlayerDamage = ::callbackVoid;
	level.callbackPlayerKilled = ::callbackVoid;
	
	setcvar("g_gametype", "dm");

	exitLevel(false);
}

/*================
================*/
callbackVoid()
{
}
