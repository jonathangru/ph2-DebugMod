# ph2-DebugMod
Debug mod for Perfect Heist 2.

COMMAND USAGE<br>
Type "!" (or your own prefix, see below) followed by the command name and arguments, if needed.
Arguments are separated by spaces. All command names are case insensitive.<br>
Example: !loadclass className

ALIASES<br>
Most commands have aliases associated with them that you can use instead of the normal command name. Have a look at them if you want to add your own commands.

INDICES<br>
Some commands accept an index instead of coordinates. These include teleport, duplicate and spawn commands. 
These indices refer to saved locations (see SAVED LOCATIONS).
Indices start at 1.

--------------------------------------
CUSTOMIZATIONS<br>

COMMAND PREFIX<br>
The default command prefix is "!". If this interferes with your own commands, you can change it in the code (around line 5).
Special characters are handled automatically. Only escape "\\" and "\"" by prefixing them with "\\".

PING IMAGE<br>
You can put a png in /Assets and the file name in the code (around line 9) to use a different ping image.

SAVED LOCATIONS<br>
You can put locations in the code (around line 21) that you want to use for teleporting, duplicating or spawning.<br>
Example:<br>
```lua
local savedLocations = {
    {X=0, Y=0, Z=0}
}
```
You can also dynamically save them using saveactorloc, savemyloc and saveloc [x] [y] [z].
To use them in commands, just type the index number, that you got while saving, instead of the coordinates.

--------------------------------------
COMMON COMMANDS<br>
```!load [tag]             → load actor by tag
!loadclass [class]         → load actor by class
!tpme x y z                → teleport yourself
!setloc x y z              → teleport loaded actor
!duplicate [tag] x y z     → duplicate actor
!spawn [class] x y z [tag] → spawn actor
!back                      → undo last teleport
!repeat                    → repeat last command
```
--------------------------------------

ALL COMMANDS<br>

### 1. LOGIC COMMANDS<br>
**1.1.** "lc [id]"<br>
Prints the state of the logic channel with the provided id.<br>


**1.2.** "setlc [id] [newstate]"<br>
Sets the logic channel with the provided id to the provided state.<br>
Example: !setlc 10 true<br>


### 2. ROUND AND PLAYER CONTROLS<br>
**2.1.** "restart"<br>
Restarts the round.<br>

**2.2.** "time [seconds]"<br>
Sets the round timer to the provided amount of seconds.<br>

**2.3** "pause"<br>
Pauses the round timer.

**2.4.** "unpause"<br>
Unpauses the round timer.

**2.5.** "kill"<br>
Kills the player who ran the command (with respawning).<br>

**2.7.** "killnorespawn"<br>
Kills the player who ran the command (without respawning) which can end the round.<br>

**2.8.** "respawn" or "respawn [index]" or "respawn [x] [y] [z]"<br>
Respawns the player who ran the command at the provided location (coordinates or index; 0 0 0 if left unspecified).<br>

**2.9.** "healme [(opt) hp]"<br>
Sets the player's hp to 100 or the specified number.<br>

**2.10.** "tpme [X] [Y] [Z]" or "tpme [index]"<br>
Teleports the player who ran the command to world coordinates.<br>
You can provide a location or an index of the saved locations.<br>
Examples: !tpme 0 0 0 or !tpme 1<br>

**2.11.** "tpmerel [x] [y] [z]" or "tpmerel [index]"<br>
Teleports the player who ran the command RELATIVE to their position.<br>
You can provide an offset or an index of the saved locations, which will be treated as an offset.<br>

**2.12.** "setclass [className]"<br>
Sets the player's class. Names are as follows:<br>
Robber: insider, heavy, tech, demo, ninja, sniper, agent, doctor, distractor, scout, engineer, madman, geek, poison, mafiaboss, mechanic, crypto, armsdealer, pickpocket, fedchairman, vaultcracker, joker, hitman, micro, gymbuddy, masterthief, actor, einstein, marx, capone, artist, deaddrop<br>
Cop: officer, spy, swat, fbi, riotcontrol, detective, combatmedic, sergeant, cyberpolice, hornet, developer, manager, sheriff, firefighter, reinforcer, inventor, fedagent, vigil, trafficcop, backup, bodyguard, pilot, janitor, canine, curie, caesar, surge, swarmdrones, swarm<br>

**2.13.** "money [amount]"<br>
Sets the money the player is carrying.<br>

**2.14.** "weapon [name]"<br>
Gives the player the specified weapon. All weapon names are one word, for example "tshirtcannon".<br>

**2.15.** "mytags"<br>
Prints the tags the player has.<br>

**2.16.** "start"<br>
Forces the round to start, even if some players have not pressed ready.<br>

**2.17.** "myloc"<br>
Prints the current location of the player.<br>


### 3. ACTORS (general)<br>
**3.1.** "tag [tag]"<br>
Prints the amount of actors with the specified tag. If there is exactly one, its class is printed.<br>

**3.2** "spawn [class] [x] [y] [z] or "spawn [index]"<br>
Spawns an actor of the provided class at the provided location (coordinates or saved index). If a tag is provided, it will be added to the new actor.<br>
Example: !spawn AI_VIP 3 mytag<br>
Would spawn a VIP at saved location 3 with tag "mytag" (class name is case insensitive).


### 4. ACTORS (specific)<br>
**4.1.** "load [tag]"<br>
Saves a list of actors with the specified tag and saves the tag itself. The first actor in the list will be loaded. Use this to run actor specific commands on it.<br>

**4.2.** "loadclass [class]"<br>
Saves a list of actors with the specified class and saves the class itself. The first actor in the list will be loaded. Use this to run actor specific commands on it.<br>

**4.3.** "update"<br>
Updates the saved actors by searching for the latest class or tag someone loaded. Might also change the loaded actor.<br>

**4.4.** "next"<br>
Loads the next actor in the list.<br>

**4.5.** "prev"<br>
Loads the previous actor in the list.<br>

**4.6.** "index [(opt) i]"<br>
Loads the actor at the provided index. If no index is provided, it prints the current index instead.<br>

**4.7.** "tags"<br>
Prints the tags of the loaded actor.<br>

**4.8.** "amountoftags"<br>
Prints the amount of tags that the loaded actor has.<br>

**4.9.** "add [tag]"<br>
Adds the provided tag to the loaded actor.<br>

**4.10.** "remove [tag]"<br>
Removes the provided tag from the loaded actor.<br>

**4.11.** "class"<br>
Prints the class of the loaded actor.<br>

**4.12.** "hp"
Prints the HP of the loaded actor.

**4.13.** "sethp [hp]"
Sets the HP of the loaded actor to the provided amount.

**4.14.** "loc"<br>
Prints the current location of the loaded actor.<br>

**4.15.** "setloc [X] [Y] [Z]" or "setloc [index]"<br>
Teleports the loaded actor to the provided location or the location saved under the provided index.<br>

**4.16.** "setlocrel [X] [Y] [Z]" or "setlocrel [index]"<br>
Teleports the loaded actor RELATIVE to its current location.<br>
You can provide an offset or an index of the saved locations, which will be treated as an offset.<br>

**4.17** "move [x] [y] [z] [t]" or "move [i] [t]"<br>
Smoothly moves the loaded actor to the provided location (coordinates or index, absolute world location) in t seconds.<br>

**4.18.** "moverel [x] [y] [z] [t]" or "moverel [i] [t]"<br>
Smoothly moves the loaded actor to the provided location (coordinates or index, RELATIVE to current location) in t seconds.<br>

**4.19.** "scale [x] [y] [z]"<br>
Scales the loaded actor to the provided scale (absolute).<br>

**4.20.** "scalerel [x] [y] [z]"<br>
Scales the loaded actor relative to its current scale.<br>

**4.21.** "getscale"<br>
Prints the scale of the loaded actor.<br>

**4.22.** "check"<br>
Prints the status of the loaded actor. Checks if the actor still exists.<br>

**4.23.** "duplicate [tag] [X] [Y] [Z]" or "duplicate [tag] [index]"<br>
Duplicates the loaded actor and adds the provided tag to it.<br>
You must always provide the tag argument if you want to specify a location. If you do not want to assign a tag, use "nil" as the tag.<br>
Examples:<br>
!duplicate nil 0 0 0<br>
!duplicate mytag 1<br>
If you want to spawn it in place and add no tag, you can also type the command without any arguments.
The location where the duplicate will spawn can be provided as three numbers or as one index of the saved locations (always after the tag).<br>

By default, duplicates are deleted at the end of the round. Commands ending with "persist" prevent this behavior:<br>
Example: !duplicatepersist mytag 0 0 0<br>

**4.24.** "duplicaterel [tag] [X] [Y] [Z]" or "duplicaterel [tag] [index]"<br>
Same functionality as duplicate, but the location is calculated RELATIVE to the actor.
Coordinates and saved locations will be treated as offsets.<br>

By default, duplicates are deleted at the end of the round. Commands ending with "persist" prevent this behavior:<br>
Example: !duplicaterelpersist mytag 0 0 0<br>

**4.25.** "ping"<br>
Pings the loaded actor. You can add a custom ping image, see PING IMAGE for more information.<br>

**4.26.** "destroy"<br>
Destroys the loaded actor. Does not work on Lua Spawners, level editor props and player chars (to destroy them, see below).<br>

**4.27.** "forcedestroy"<br>
Destroys the loaded actor regardless of its class.<br>
Warning: If the actor is a Lua spawner or a level editor prop, it will be permanently and irrecoverably deleted from the server. If you need it back, you'll have to restart the server. If the actor is a player, they will have to rejoin.


### 5. OTHER COMMANDS<br>
**5.1.** "myloc"<br>
Prints the current location of the user that ran the command.<br>

**5.2** "saveactorloc"<br>
Saves the current location of the loaded actor.<br>

**5.3.** "savemyloc"<br>
Saves the current location of the player that ran the command.<br>

**5.4.** "saveloc [x] [y] [z]"<br>
Saves the provided location.<br>

**5.5** "event [name]"<br>
Triggers the provided event by its name. This is case sensitive!<br>



### 6. QOL COMMANDS<br>
**6.1.** "repeat"<br>
Repeats the player's last command with the same arguments.<br>

**6.2.** "back"<br>
Undoes the most recent teleport performed by the specific player.
