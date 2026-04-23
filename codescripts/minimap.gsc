/*
Call of Duty 2 Minimap Proof of Concept
Created by iBuddie(at) in April 2026
Requirements:
    libcod2 for some necessary non-stock script functions, built from the
    following commit or newer:
    https://github.com/ibuddieat/zk_libcod/commit/c19f94eeacfe6c7047bf7d5f4dd46414f21804ac
*/

clamp(value, min, max)
{
    if ( value < min )
        return min;
    if ( value > max )
        return max;
    return value;
}

getNearestPlayers(maxCount)
{
    players = getEntArray("player", "classname");

    valid = [];

    for ( i = 0; i < players.size; i++ )
    {
        p = players[i];

        if ( p == self || !isDefined(p.pers["team"]) || p.pers["team"] == "spectator" )
            continue;

        dist = distance(self.origin, p.origin);

        temp = [];
        temp[temp.size] = p;
        temp[temp.size] = distance(self.origin, p.origin);

        valid[valid.size] = temp;
    }

    // Sort by distance (simple bubble sort)
    for ( i = 0; i < valid.size; i++ )
    {
        for ( j = i + 1; j < valid.size; j++ )
        {
            if ( valid[j][1] < valid[i][1] )
            {
                tmp = valid[i];
                valid[i] = valid[j];
                valid[j] = tmp;
            }
        }
    }

    result = [];
    for ( i = 0; i < valid.size && i < maxCount; i++ )
    {
        result[result.size] = valid[i][0];
    }

    return result;
}

precache()
{
    // Stock cod2
    precacheShader("headicon_dead");

    // cod4 minimap_background.iwi but without border around box
    precacheShader("zk_minimap_background");

    // 2x cod4 minimap_tickertape.iwi in a single image
    precacheShader("zk_minimap_compass_tape");

    // cod4 compassping_enemyfiring.iwi but scaled to 16x16
    precacheShader("zk_minimap_enemy");

    // cod4 compassping_green_hollow_mp.iwi
    precacheShader("zk_minimap_friendly");
    precacheShader("zk_minimap_friendlyneedle");

    // cod4 compassping_green_mp.iwi
    // Not implemented
    //precacheShader("zk_minimap_friendly_firing");
    //precacheShader("zk_minimap_friendly_firingneedle");

    // Toujane map image with "infinity ward" logo in lower right corner
    // https://callofdutymaps.com/call-of-duty-2/toujane/
    precacheShader("zk_minimap_mp_toujane");
    precacheShader("zk_minimap_mp_toujaneneedle");

    // cod4 compassping_player.iwi
    precacheShader("zk_minimap_player");

    // cod4 compass_radarline.iwi but with the line exactly in the middle
    precacheShader("zk_minimap_radarline");
    precacheShader("zk_minimap_radarlineneedle");

    // Stencil buffer setting material
    precacheShader("zk_stencil_mask");
}

// Called from callbacks (CodeCallback_PlayerCommand)
updateZoomLevel()
{
    // Increase zoom level based on a fixed table
    self.zoomLevel++;
    if ( self.zoomLevel > 3 )
        self.zoomLevel = 1;

    switch ( self.zoomLevel )
    {
        case 1: self.zoom = 1.0; break;
        case 2: self.zoom = 1.9; break; // A scaling value of 2.0 or above would cause black shader
        case 3: self.zoom = 0.5; break;
    }
}

// Called from callbacks (CodeCallback_WeaponChange)
// Also: Must be called for the player on each spawn
monitorWeapon(weaponName)
{
    self endon("disconnect");

    self notify("end_weapon_monitor");
    self endon("end_weapon_monitor");

    if ( weaponName == "none" )
        return;

    // Duration of how long enemy markers are shown. Should be at least 1
    // because marker fading is hard-coded to 1s
    pingDuration = 3;

    // Wait until self getCurrentWeapon() matches with weaponName
    wait ( getWeaponRaiseTime(weaponName) / 1000 ) + 1 / getCvarInt("sv_fps");

    previousAmmo = self getCurrentWeaponClipAmmo();
    currentAmmo = previousAmmo;

    while ( isAlive(self) && self getCurrentWeapon() == weaponName )
    {
        currentAmmo = self getCurrentWeaponClipAmmo();
        if ( currentAmmo < previousAmmo )
        {
            self.detected = getTime() + pingDuration * 1000;
            self.detectedPos = (self.origin[0], self.origin[1], 0);
        }
        previousAmmo = currentAmmo;
        wait 1 / getCvarInt("sv_fps");
    }
}

monitorBinoculars()
{
    self endon("disconnect");

    self.requestedRadar = false;

    while ( true )
    {
        self waittill("binocular_enter");
        self.requestedRadar = true;
    }
}

main()
{
    self endon("disconnect");

    // Images and map size specifiers are hard-coded for Toujane
    if ( getCvar("mapname") != "mp_toujane" )
        return;

    // Disable stock compass
    //self setClientCvar("cg_hudCompassSize", "0");

    // Bind M key to minimap zoom control
    self executeClientCommand("bind m openscriptmenu -1 binds:m");

    // Monitor binocular usage for radar
    self thread monitorBinoculars();

    // Only squares supported for sizes
    minimap_size = 128;
    minimap_border_thickness = 2;
    minimap_map_size = 512;
    minimap_position_x = 4;
    minimap_position_y = 88; // Covers chat!
    minimap_compass_size_x = minimap_size;
    minimap_compass_size_y = 12;
    minimap_compass_position_x = minimap_position_x;
    minimap_compass_position_y = minimap_position_y - minimap_compass_size_y - 2;
    minimap_compass_tape_width = 512;
    minimap_player_size = 16;
    minimap_other_players_size = 12;
    minimap_icons_max = 16;
    minimap_zoom_start = 1.0;

    self.zoom = minimap_zoom_start;
    self.zoomLevel = 1;

    self.mmIcons = [];

    for ( i = 0; i < minimap_icons_max; i++ )
    {
        icon = newClientHudElem(self);
        icon.alignX = "left";
        icon.alignY = "top";
        icon.horzAlign = "left";
        icon.vertAlign = "top";
        icon.x = 0;
        icon.y = 0;
        icon.alpha = 1;
        icon.hideWhenInMenu = true;
        icon.archived = true;
        icon.foreground = false;
        icon.color = (1, 1, 1);
        icon.sort = 6;
        
        icon.detected = false;
        icon.pinged = false;
        icon.detectedPos = (0, 0, 0);

        self.mmIcons[i] = icon;
    }

    mask_map                = newClientHudElem(self);
    mask_map.x              = minimap_position_x;
    mask_map.y              = minimap_position_y;
    mask_map.alignX         = "left";
    mask_map.alignY         = "top";
    mask_map.horzAlign      = "left";
    mask_map.vertAlign      = "top";
    mask_map.sort           = 0;
    mask_map.alpha          = 1;
    mask_map.hideWhenInMenu = true;
    mask_map.archived       = true;
    mask_map.foreground     = false;
    mask_map setShader("zk_stencil_mask", minimap_size, minimap_size);

    map                = newClientHudElem(self);
    map.x              = minimap_position_x;
    map.y              = minimap_position_y;
    map.alignX         = "left";
    map.alignY         = "top";
    map.horzAlign      = "left";
    map.vertAlign      = "top";
    map.sort           = 1;
    map.alpha          = 1;
    map.hideWhenInMenu = true;
    map.archived       = true;
    map.foreground     = false;
    self.map = map;

    radar                = newClientHudElem(self);
    radar.x              = minimap_position_x;
    radar.y              = minimap_position_y;
    radar.alignX         = "left";
    radar.alignY         = "top";
    radar.horzAlign      = "left";
    radar.vertAlign      = "top";
    radar.sort           = 2;
    radar.alpha          = 0;
    radar.hideWhenInMenu = true;
    radar.archived       = true;
    radar.foreground     = false;
    self.radarline = radar;

    border                = newClientHudElem(self);
    border.x              = minimap_position_x;
    border.y              = minimap_position_y;
    border.alignX         = "left";
    border.alignY         = "top";
    border.horzAlign      = "left";
    border.vertAlign      = "top";
    border.sort           = 3;
    border.alpha          = 1;
    border.hideWhenInMenu = true;
    border.archived       = true;
    border.foreground     = false;
    border setShader("zk_minimap_background", minimap_size, minimap_size);

    mask_compass                = newClientHudElem(self);
    mask_compass.x              = minimap_compass_position_x;
    mask_compass.y              = minimap_compass_position_y;
    mask_compass.alignX         = "left";
    mask_compass.alignY         = "top";
    mask_compass.horzAlign      = "left";
    mask_compass.vertAlign      = "top";
    mask_compass.sort           = 4;
    mask_compass.alpha          = 0.3; // Must be above 0 with this mask
    mask_compass.hideWhenInMenu = true;
    mask_compass.archived       = true;
    mask_compass.foreground     = false;
    mask_compass setShader("zk_stencil_mask", minimap_compass_size_x, minimap_compass_size_y);

    compass                = newClientHudElem(self);
    compass.x              = minimap_compass_position_x;
    compass.y              = minimap_compass_position_y;
    compass.alignX         = "left";
    compass.alignY         = "top";
    compass.horzAlign      = "left";
    compass.vertAlign      = "top";
    compass.sort           = 5;
    compass.alpha          = 1;
    compass.hideWhenInMenu = true;
    compass.archived       = true;
    compass.foreground     = false;
    compass setShader("zk_minimap_compass_tape", minimap_compass_tape_width, minimap_compass_size_y);
    self.compass = compass;

    // Sort 6 is all other objectives, entities etc. on the minimap

    playerindicator                = newClientHudElem(self);
    playerindicator.x              = int(minimap_size / 2) - int(minimap_player_size / 2);
    playerindicator.y              = int(minimap_size / 2) - int(minimap_player_size / 2);
    playerindicator.alignX         = "left";
    playerindicator.alignY         = "top";
    playerindicator.horzAlign      = "left";
    playerindicator.vertAlign      = "top";
    playerindicator.sort           = 7;
    playerindicator.alpha          = 1;
    playerindicator.hideWhenInMenu = true;
    playerindicator.archived       = true;
    playerindicator.foreground     = false;
    playerindicator.color          = (1, 1, 1);
    playerindicator setShader("zk_minimap_player", minimap_player_size, minimap_player_size);
    self.playerindicator = playerindicator;

    // World area covered by minimap image of mp_toujane:
    //  Upper-left corner: (-970, 3580)
    //  Upper-right corner: (4300, 3580)
    //  Lower-left corner: (-970, -460)
    //  Lower-right corner: (4300, -460)
    // In the optimal case, the area is a square
    minX = -970;
    maxX = 4300;
    minY = -460;
    maxY = 3580;

    sizeX = maxX - minX;
    sizeY = maxY - minY;

    while ( true )
    {
        playerX = self.origin[0];
        playerY = self.origin[1];

        // Normalize
        normX = (playerX - minX) / sizeX;
        normY = (maxY - playerY) / sizeY;

        mapSize = minimap_map_size * self.zoom;
        center  = mapSize * 0.5;

        // Unclamped position
        unclampedX = normX * mapSize;
        unclampedY = normY * mapSize;

        // Angle
        angle = self.angles[1] - 90;
        if ( angle <= 0 )
            angle += 360;

        cosA = cos(angle);
        sinA = sin(angle);

        // Rotation-aware clamp
        halfView = int(minimap_size / 2);

        absCos = abs(cosA);
        absSin = abs(sinA);

        marginX = halfView * absCos + halfView * absSin;
        marginY = halfView * absSin + halfView * absCos;

        clampedX = clamp(unclampedX, marginX, mapSize - marginX);
        clampedY = clamp(unclampedY, marginY, mapSize - marginY);

        // Offset from center (for map)
        dx = clampedX - center;
        dy = clampedY - center;

        // Rotate map
        rx = dx * cosA - dy * sinA;
        ry = dx * sinA + dy * cosA;

        self.map.x = minimap_position_x + int(minimap_size / 2) - center - rx;
        self.map.y = minimap_position_y + int(minimap_size / 2) - center - ry;

        // Player indicator offset calculation
        deltaX = clampedX - unclampedX;
        deltaY = clampedY - unclampedY;

        // Rotate delta into screen space
        playerindicatorOffsetX = deltaX * cosA - deltaY * sinA;
        playerindicatorOffsetY = deltaX * sinA + deltaY * cosA;

        // Apply to playerindicator
        self.playerindicator.x = minimap_position_x + (int(minimap_size / 2) - int(minimap_player_size / 2)) - playerindicatorOffsetX;
        self.playerindicator.y = minimap_position_y + (int(minimap_size / 2) - int(minimap_player_size / 2)) - playerindicatorOffsetY;

        // Clamp playerindicator inside minimap
        self.playerindicator.x = clamp(self.playerindicator.x, minimap_position_x + minimap_border_thickness - int(minimap_player_size / 2), minimap_position_x - minimap_border_thickness + minimap_size - int(minimap_player_size / 2));
        self.playerindicator.y = clamp(self.playerindicator.y, minimap_position_y + minimap_border_thickness - int(minimap_player_size / 2), minimap_position_y - minimap_border_thickness + minimap_size - int(minimap_player_size / 2));

        // Reset player indicator position if no clamping
        if ( deltaX == 0 && deltaY == 0 )
        {
            self.playerindicator.x = minimap_position_x + int(minimap_size / 2) - int(minimap_player_size / 2);
            self.playerindicator.y = minimap_position_y + int(minimap_size / 2) - int(minimap_player_size / 2);
        }

        // Apply rotation (with integer size + scaled clock)
        self.map setClock(angle * 1000, 360000, "zk_minimap_mp_toujane", int(mapSize), int(mapSize));

        // Update compass tape
        pixelsPerDegree = (minimap_compass_tape_width / 360.0) / 2;
        offset = int((angle + 90) * pixelsPerDegree) % minimap_compass_tape_width;
        self.offset = offset;
        self.compass.x = minimap_compass_position_x - minimap_compass_tape_width + offset + (minimap_compass_size_x / 2);

        // Update radar
        self updateRadar(minimap_size, minimap_position_x, minimap_position_y, minX, maxY, sizeX, sizeY, mapSize, clampedX, clampedY, cosA, sinA);

        // Update icons of other players & enemies
        nearest = self getNearestPlayers(minimap_icons_max);
        self updateMinimapIcons(nearest, minX, maxY, sizeX, sizeY, mapSize, clampedX, clampedY, cosA, sinA, minimap_position_x, minimap_position_y, minimap_size, minimap_other_players_size, minimap_border_thickness);

        wait 1 / getCvarInt("sv_fps");
    }
}

updateRadar(minimap_size, minimap_position_x, minimap_position_y, minX, maxY, sizeX, sizeY, mapSize, clampedX, clampedY, cosA, sinA)
{
    // Time how long the radar sweep takes in total
    duration = 3;

    // Duration of how long enemy markers are shown. Should be at least 1
    // because marker fading is hard-coded to 1s
    pingDuration = 3;

    // Duration of delay between one radar sweep finished and another one
    // can be started. Should not be lower than pingDuration
    cooldownTime = pingDuration;

    // Initialize stuff
    if ( !isDefined(self.radar) )
    {
        self.radar = spawnStruct();
        self.radar.active = false;
        self.radar.step = 0;
        self.radar.endTime = 0;
        self.radar.cooldownTime = 0;
        self.radar.angle = 0;
        self.radar.vector = undefined;
        self.radar.pos = undefined;
        self.radar.threshold = 0;
    }

    // Is there already a radar active? Might also want to set a level variable
    if ( self.radar.endTime >= getTime() )
    {
        self.radar.active = true;
    }
    else
    {
        self.radar.active = false;
        if ( self.requestedRadar && self.radar.cooldownTime < getTime() )
        {
            self.requestedRadar = false;
            self.radar.active = true;
            self.radar.step = 0;
            self.radar.endTime = getTime() + duration * 1000;
            self.radar.cooldownTime = self.radar.endTime + cooldownTime * 1000;
            self.radar.angle = randomInt(360);
            self.radar.vector = undefined;

            players = getEntArray("player", "classname");
            for ( i = 0; i < players.size; i++ )
            {
                p = players[i];

                if ( p == self )
                    continue;

                p.detected = 0; // Assumes only one radar can be used at a time
            }
        }
    }

    // Shader visibility
    if ( self.radar.active )
    {
        self.radarline.alpha = 1;
    }
    else
    {
        self.radarline.alpha = 0;
        return;
    }

    // Translate random rotation and position relative to minimap
    radarSize = minimap_size * 1.4142;
    maxDist = radarSize;
    steps = duration / (1 / getCvarInt("sv_fps"));
    stepTime = duration / steps;
    t = self.radar.step / steps;
    offset = (t * 2 - 1) * maxDist;
    angleDisplay = self.radar.angle + self.angles[1];
    dirX = cos(angleDisplay);
    dirY = sin(angleDisplay);
    perpX = dirY * -1;
    perpY = dirX;
    centerX = minimap_position_x + minimap_size / 2;
    centerY = minimap_position_y + minimap_size / 2;
    lineX = centerX + perpX * offset;
    lineY = centerY + perpY * offset;

    self.radarline.x = lineX - radarSize / 2;
    self.radarline.y = lineY - radarSize / 2;

    // Adjust angle to be valid for setClock
    while ( angleDisplay <= 0 )
        angleDisplay += 360;
    while ( angleDisplay > 360 )
        angleDisplay -= 360;
    
    self.radarline setClock((angleDisplay + 90) * 1000, 360000, "zk_minimap_radarline", int(radarSize), int(radarSize));

    // Screen-space detection
    // Track the sweep line center in screen pixels to auto-calibrate the
    // per-frame detection threshold (must exceed 1 frame of icon movement)
    if ( !isDefined(self.radar.pos) )
    {
        self.radar.pos = (lineX, lineY, 0);
    }
    else
    {
        if ( self.radar.threshold == 0 )
        {
            tdx = lineX - self.radar.pos[0];
            tdy = lineY - self.radar.pos[1];
            self.radar.threshold = sqrt(tdx * tdx + tdy * tdy);
        }
    }

    // Project every player through the same world to screen transform used by
    // updateMinimapIcons so detection always matches the visual sweep exactly,
    // at every zoom level and rotation
    players = getEntArray("player", "classname");
    for ( i = 0; i < players.size; i++ )
    {
        p = players[i];

        if ( p == self )
            continue;

        if ( !isDefined(p.detected) )
        {
            p.detected = 0;
            p.detectedPos = (0, 0, 0);
        }

        // Skip already detected players
        if ( p.detected >= getTime() )
            continue;

        // World to normalised to zoom-aware map-pixel
        otherNormX = (p.origin[0] - minX) / sizeX;
        otherNormY = (maxY - p.origin[1]) / sizeY;
        otherMapX  = otherNormX * mapSize;
        otherMapY  = otherNormY * mapSize;

        // Offset from the player-centred (edge-clamped) minimap origin
        odx = otherMapX - clampedX;
        ody = otherMapY - clampedY;

        // Rotate into screen space (identical to the map shader rotation)
        orx = odx * cosA - ody * sinA;
        ory = odx * sinA + ody * cosA;

        // Absolute screen position of this player's icon (unclamped)
        iconX = centerX + orx;
        iconY = centerY + ory;

        // Perpendicular distance from the icon to the sweep line.
        // Line passes through (lineX, lineY) with unit direction (dirX, dirY);
        // perpendicular distance = |2D cross product of relative vector and dir|
        relX = iconX - lineX;
        relY = iconY - lineY;
        dist = abs(relX * dirY - relY * dirX);

        if ( dist < self.radar.threshold )
        {
            p.detected = getTime() + pingDuration * 1000;
            p.detectedPos = (p.origin[0], p.origin[1], 0);
        }
    }

    self.radar.step += 1;
}


updateMinimapIcons(nearest, minX, maxY, sizeX, sizeY, mapSize, clampedX, clampedY, cosA, sinA, minimap_position_x, minimap_position_y, minimap_size, minimap_other_players_size, minimap_border_thickness)
{
    for ( i = 0; i < self.mmIcons.size; i++ )
    {
        if ( i >= nearest.size )
        {
            self.mmIcons[i].alpha = 0;
            continue;
        }

        p = nearest[i];

        if ( !isDefined(p.detected) )
        {
            p.detected = 0;
            p.detectedPos = (0, 0, 0);
        }
        
        if ( !isDefined(p.pinged) )
            p.pinged = false;

        otherX = p.origin[0];
        otherY = p.origin[1];

        // First default everything to invisible
        self.mmIcons[i].alpha = 0;

        if ( isDefined(p.pers["team"]) )
        {
            team = p.pers["team"];

            if ( team != "spectator" )
            {
                self.mmIcons[i].color = (1, 1, 1);

                // Direction of other player
                angle = p.angles[1] - 90;
                dirX = cos(angle);
                dirY = sin(angle);

                // Rotate into minimap space (same as map)
                rx = dirX * cosA + dirY * sinA;
                ry = dirX * sinA - dirY * cosA;

                // Convert back to angle
                iconAngle = atan2(ry, rx) * 57.2958;

                while ( iconAngle <= 0 )
                    iconAngle += 360;
                while ( iconAngle > 360 )
                    iconAngle -= 360;

                if ( isAlive(p) )
                {
                    if ( p.detected < getTime() )
                    {
                        // Not in radar
                        p.pinged = false;

                        if ( team != self.pers["team"] )
                        {
                            self.mmIcons[i].alpha = 0;
                            self.mmIcons[i].color = (1, 0, 0);
                        }
                        else
                        {
                            self.mmIcons[i].alpha = 1;
                            self.mmIcons[i].color = (1, 1, 1);
                            self.mmIcons[i] setClock(iconAngle * 1000, 360000, "zk_minimap_friendly", minimap_other_players_size, minimap_other_players_size);
                        }
                    }
                    else
                    {
                        // In radar
                        if ( team != self.pers["team"] )
                        {
                            if ( !p.pinged )
                            {
                                if ( isAlive(p) )
                                {
                                    otherX = p.detectedPos[0];
                                    otherY = p.detectedPos[1];
                                    self.mmIcons[i] setShader("zk_minimap_enemy", minimap_other_players_size, minimap_other_players_size);
                                    p.pinged = true;
                                    self.mmIcons[i].alpha = 1;
                                }
                            }
                            else
                            {
                                otherX = p.detectedPos[0];
                                otherY = p.detectedPos[1];
                                self.mmIcons[i] setShader("zk_minimap_enemy", minimap_other_players_size, minimap_other_players_size);
                                if ( p.detected < getTime() + 1000 )
                                {
                                    // Cannot use fadeOverTime here as it would be overriden by setShader
                                    self.mmIcons[i].alpha = (p.detected - getTime()) / 1000;
                                }
                                else
                                {
                                    self.mmIcons[i].alpha = 1;
                                }
                            }
                        }
                        else
                        {
                            self.mmIcons[i].alpha = 1;
                            self.mmIcons[i] setClock(iconAngle * 1000, 360000, "zk_minimap_friendly", minimap_other_players_size, minimap_other_players_size);
                        }
                    }
                }
                else
                {
                    p.pinged = false;
                    p.detected = 0;
                    self.mmIcons[i].alpha = 1;
                    self.mmIcons[i] setShader("headicon_dead", minimap_other_players_size, minimap_other_players_size);
                    if ( team == self.pers["team"] )
                        self.mmIcons[i].color = (0, 1, 0);
                    else
                        self.mmIcons[i].color = (1, 0, 0);
                }
            }
            else
            {
                self.mmIcons[i].alpha = 0;
            }
        }
        else
        {
            self.mmIcons[i].alpha = 0;
        }

        // Normalize
        normX = (otherX - minX) / sizeX;
        normY = (maxY - otherY) / sizeY;

        // Map space
        px = normX * mapSize;
        py = normY * mapSize;

        dx = px - clampedX;
        dy = py - clampedY;

        // Rotate (same as map)
        rx = dx * cosA - dy * sinA;
        ry = dx * sinA + dy * cosA;

        // Convert to minimap screen space
        screenX = minimap_position_x + int(minimap_size / 2) + rx - int(minimap_other_players_size / 2);
        screenY = minimap_position_y + int(minimap_size / 2) + ry - int(minimap_other_players_size / 2);

        // Clamp to minimap window
        screenX = clamp(screenX, minimap_position_x + minimap_border_thickness - int(minimap_other_players_size / 2), minimap_position_x - minimap_border_thickness + minimap_size - int(minimap_other_players_size / 2));
        screenY = clamp(screenY, minimap_position_y + minimap_border_thickness - int(minimap_other_players_size / 2), minimap_position_y - minimap_border_thickness + minimap_size - int(minimap_other_players_size / 2));

        self.mmIcons[i].x = screenX;
        self.mmIcons[i].y = screenY;
    }
}