InitStructs()
{
    level.xenon = false;
	level.struct = [];

    level thread codescripts\minimap::precache();

    level thread ClientConnect();
}

CreateStruct()
{
	struct = SpawnStruct();
	level.struct[level.struct.size] = struct;

	return struct;
}

ClientConnect()
{
    for ( ;; )
    {
        level waittill("connected", player);

        if ( player isBot() )
            continue;

        player thread codescripts\minimap::main();
    }
}