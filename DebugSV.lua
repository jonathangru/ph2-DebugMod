LogMessage("Loaded script: DebugSV.lua")

-- CUSTOMIZATIONS

-- Change this if the commands interfere with your own. You do not need to escape special characters, the code handles them by itself (except if you want to use \ or " then put a \ in front of it).
local COMMAND_PREFIX = "!"


-- Change this if you want to use a different image to ping the loaded actor (put it in /Assets).
local PING_FILE_NAME = "ping.png"
--Image credit: sbed on game-icons.net

--[[ You can put locations here that you want to use for teleporting, duplicating or spawning.
Example:
local savedLocations = {
    {X=0, Y=0, Z=0}
}
You can also dynamically save them using saveactorloc, savemyloc and saveloc [x] [y] [z].
To use them in commands, just type the index number, that you got while saving, instead of the coordinates.
]]
local savedLocations = {

}
local savedLocationsIndex = #savedLocations

------------------------------------
--HELPER FUNCTIONS

local AI_CLASSES = {
    AI_Customer = true,
    AI_Employee = true,
    AI_VIP = true,
    AI_KitchenStaff = true,
    PlayerAI_Cop = true,
    PlayerAI_Rob = true
}

local roundTimeAtPause
local paused = false

local ERROR_NOT_A_NUMBER = "Error, \"%s\" is not a number."

--Gets the current game state.
local function GS()
    return GetGameState()
end

--Gets the current game mode.
local function GM()
    return GetGameMode()
end

local commands = {}
--Registers a function and its aliases as commands.
local function Register(cmd, fn, aliases)
    commands[cmd] = fn
    if aliases then
        for _, a in ipairs(aliases) do
            commands[a] = fn
        end
    end
end

--Prints the message to all chat.
local function SendServerMessage(message)
    GS():AllMessage(message, 0, nil)
end

--Returns true / false for valid logic channel states (string!), nil otherwise.
local function ParseBool(value)
    if not value then return end
    value = value:lower()
    if value == "true" or value == "on" then return true end
    if value == "false" or value == "off" then return false end
end

--Converts a string to a number, prints error message otherwise.
local function ParseNumber(value)
    local n = tonumber(value)
    if n == nil then
        SendServerMessage(ERROR_NOT_A_NUMBER:format(value))
    end
    return n
end

local ZERO_VECTOR = {X=0, Y=0, Z=0}
--Adds two 3d vectors.
local function AddVectors(a, b)
    return {X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z}
end

--Substracts two 3d vectors. (a-b)
local function SubVectors(a, b)
    return {X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z}
end

--Deep copies the vector.
local function CopyVector(v)
    if not v then return end
    local x, y, z = v.X, v.Y, v.Z
    if x == nil or y == nil or z == nil then return end
    return {X=x, Y=y, Z=z}
end

--Copies a table.
local function CopyTable(t)
    local new = {}
    for i, v in ipairs(t) do new[i] = v end
    return new
end


local ERROR_ROUND_NOT_STARTED = "Error, round has not started yet."
local function CheckRoundLive()
    local live = GS().roundLive
    if not live then
        SendServerMessage(ERROR_ROUND_NOT_STARTED)
    end
    return live
end


--Helper functions actor loading

local INVALID_ACTOR = "InvalidActor"
local loadedActor
local loadedTag
local loadedClass
local ERROR_NOT_LOADED = "Error, actor was never loaded or does not exist anymore."
local ERROR_NO_TAG_PROVIDED = "Error, no tag provided."
local ERROR_ONLY_ONE_ACTOR = "Error, only one actor was loaded. To update the actors with tag \"%s\" type %supdate"
local loadedActorsList = {}
local loadedActorsIndex

--Checks if the provided actor (still) exists.
local function Exists(actor)
    if not actor then return false end
    local name = GetActorName(actor)
    return name ~= nil and name ~= INVALID_ACTOR
end

--Returns false and prints an error message if the provided (or loaded) actor does not exist.
local function CheckActorExistence(actor)
    actor = actor or loadedActor
    local existence = Exists(actor)
    if not existence then
        SendServerMessage(ERROR_NOT_LOADED)
    end
    return existence
end

--Returns the identifier name "Class" or "Tag" for printing outputs.
local function GetIdentifierName(isClass)
    return isClass and "Class" or "Tag"
end

--Loads a new list of actors with the specified identifier, which can be a tag or a class depending on isClass. Returns true, if at least one actor was found.
local function LoadActorsList(identifier, isClass)
    if not identifier then
        SendServerMessage("Error, no class or tag provided.")
        return false
    end
    local actors = isClass and GetAllActorsOfClass(identifier) or GetAllActorsWithTag(identifier)
    if not actors or #actors == 0 then
        SendServerMessage(("Error, no actor found. %s was not saved."):format(GetIdentifierName(isClass)))
        return false
    end
    loadedActorsList = actors
    if not isClass then
        loadedTag = identifier
        loadedClass = nil
        SendServerMessage(("Updated the list of loaded actors (size %d) and saved tag \"%s\"."):format(#loadedActorsList, identifier))
    else
        loadedTag = nil
        loadedClass = identifier
        SendServerMessage(("Updated the list of loaded actors (size %d) and saved class \"%s\"."):format(#loadedActorsList, identifier))
    end
    return true
end

--Loads the actor at loadedActorsList[index].
local function LoadActorFromList(index)
    if not loadedActorsList[index] then
        SendServerMessage(("Error, index \"%d\" out of bounds for list of size %d."):format(index, #loadedActorsList))
        return
    end
    loadedActor = loadedActorsList[index]
    loadedActorsIndex = index
    SendServerMessage(("Loaded actor with class \"%s\" at index \"%d\". To load a different (already saved) actor, type %snext or %sprev or %sindex [i]. To update the list of actors using the same identifier, type %supdate."):format(GetActorClassName(loadedActor), loadedActorsIndex, COMMAND_PREFIX, COMMAND_PREFIX, COMMAND_PREFIX, COMMAND_PREFIX))
end


--Helper functions teleporting

local ERROR_TOO_FEW_COORDINATES = "Error, not enough coordinates provided."
--Extracts the 3d coordinates from the first three elements of an array. Returns false and prints error message if invalid.
local function GetCoordinates(args)
    if not args[1] or not args[2] or not args[3] then
        SendServerMessage(ERROR_TOO_FEW_COORDINATES)
        return false
    end
    local location = {
        X=ParseNumber(args[1]),
        Y=ParseNumber(args[2]),
        Z=ParseNumber(args[3])
    }
    if not location.X or not location.Y or not location.Z then
        return false
    end
    return location
end

--Saves last teleport coordinates so that it can be undone.
local lastTeleportOrigin = {}
local lastTeleportedActor = {}
local TELEPORT_BACK_MESSAGE = ("You can tp back by typing \"%sback\" (available until your next teleport)."):format(COMMAND_PREFIX)
local ERROR_NO_LOCATION_AT_INDEX = "Error, no location saved in index %d"

--Saves and prints the provided location.
local function SaveLocation(location)
    local locationCopy = CopyVector(location)
    if not locationCopy then
        SendServerMessage("Error, location is invalid and was not saved.")
        return
    end
    savedLocationsIndex = savedLocationsIndex + 1
    savedLocations[savedLocationsIndex] = locationCopy
    SendServerMessage(("Saved location (rounded) X=%.2f, Y=%.2f, Z=%.2f at index %d."):format(locationCopy.X, locationCopy.Y, locationCopy.Z, savedLocationsIndex))
end

--Saves the location of the provided actor.
local function SaveActorLocation(targetActor)
    if not CheckActorExistence(targetActor) then return end
    local location = targetActor:GetActorLocation()
    SaveLocation(location)
end

--Teleports the player to the target location and saves the old location.
local function teleportPlayer(targetLocation, originLocation, playerActor)
    if targetLocation and originLocation and playerActor then
        local name = playerActor.PlayersName
        lastTeleportOrigin[name] = originLocation
        lastTeleportedActor[name] = playerActor
        playerActor:SetActorLocation(targetLocation)
        SendServerMessage(("Teleported player \"%s\". %s"):format(name, TELEPORT_BACK_MESSAGE))
    end
end

--Returns the location saved at the provided index (string or number), prints an error message otherwise.
local function GetLocationFromIndex(i)
    i = ParseNumber(i)
    if not i then return end
    i = math.floor(i)
    local loc = savedLocations[i]
    if not loc then
        SendServerMessage(ERROR_NO_LOCATION_AT_INDEX:format(i))
        return
    end
    return CopyVector(loc)
end

--Helper functions duplicating
local WILL_BE_DELETED_TAG = "duplicatewillbedeleted"
--Duplicates the loaded actor. args can contain tag and coordinates.
--If isRelative then coordinates are relative to the actor, otherwise they are world coordinates.
--If willBeDeleted then the duplicate will reset at round end.
local function Duplicate(args, isRelative, persistRounds)
    if not CheckActorExistence() then return end
    local className = GetActorClassName(loadedActor)
    local tag
    local coords
    local index
    if args and #args > 0 then
        if args[1] ~= "nil" then
            tag = args[1]
        end
        if #args == 2 then
            index = ParseNumber(args[2])
            if not index then return end
            coords = GetLocationFromIndex(index)
            if not coords then return end
        elseif #args == 4 then
            coords = GetCoordinates({table.unpack(args, 2)})
            if not coords then return end
        elseif #args == 3 or #args == 1 then
            SendServerMessage("Error, invalid amount of arguments. You must provide a tag and then an index or three coordinates.")
            return
        end
    end
    if coords == nil then
        coords = ZERO_VECTOR
    end
    local base = loadedActor:GetActorLocation()
    local offset = {X=0, Y=0, Z=0}
    local ai = AI_CLASSES[className]
    if not ai then
        if isRelative then
            offset = coords
        else
            offset = SubVectors(coords, base)
        end
    else
        if isRelative then
            offset = AddVectors(base, coords)
        else
            offset = coords
        end
    end
    local dup = SpawnActorDuplicate(loadedActor, offset)
    local finalLocation = isRelative and AddVectors(base, offset) or offset
    if tag then
        AddActorTag(dup, tag)
    end
    if persistRounds ~= true then
        AddActorTag(dup, WILL_BE_DELETED_TAG)
    end
    if isRelative and ai then
        finalLocation = SubVectors(finalLocation, base)
    elseif not isRelative and not ai then
        finalLocation = coords
    end
    SendServerMessage(("Duplicated loaded actor to world position X=%.2f, Y=%.2f, Z=%.2f."):format(finalLocation.X, finalLocation.Y, finalLocation.Z))
end


--Helper Functions to make actors moveable

local RESET_TAG = "needsreset"
local RESET_NUMBER_TAG_PREFIX = "resetno"
local ERROR_RESET_ACTOR = "Error, failed to move teleported actor of class \"%s\" back, it will stay at its current position for every round. %s"
local savedOrigins = {}
local savedOriginsIndex = 0

--Extracts the reset number from the actor.
local function FindResetNumberTag(targetActor)
    local tags = GetActorTags(targetActor)
    for _, tag in ipairs(tags) do
        local match = tag:match(RESET_NUMBER_TAG_PREFIX .. "(.+)")
        if match then
            return match
        end
    end
end

--Makes the actor moveable, saves its origin position and adds the necessary tags.
local function MakeMoveable(targetActor)
    local alreadySavedTag = FindResetNumberTag(targetActor)
    if alreadySavedTag then
        if savedOrigins[alreadySavedTag] then
            return
        else
            RemoveActorTag(targetActor, RESET_NUMBER_TAG_PREFIX .. alreadySavedTag)
        end
    end
    local root = targetActor:GetRootComponent()
    if not root then
        LogMessage("i got no roots")
        return
    end
    root:SetMobility(2) -- 0=Static, 1=Stationary, 2=Movable
    local loc = targetActor:GetActorLocation()
    local locCopy = CopyVector(loc)
    savedOriginsIndex = savedOriginsIndex + 1
    local resetNumberTag = RESET_NUMBER_TAG_PREFIX .. tostring(savedOriginsIndex)
    savedOrigins[resetNumberTag] = locCopy
    AddActorTag(targetActor, RESET_TAG)
    AddActorTag(targetActor, resetNumberTag)
end

--Teleports the actor back to its origin. Prints an error message if there is no origin associated with the actor.
local function ResetActorLocation(targetActor, resetNumber)
    local resetNumberTag = RESET_NUMBER_TAG_PREFIX .. resetNumber
    if not savedOrigins[resetNumberTag] then
        SendServerMessage(ERROR_RESET_ACTOR:format(GetActorClassName(targetActor), "(FAIL origin)"))
        return
    end
    targetActor:SetActorLocation(savedOrigins[resetNumberTag])
    RemoveActorTag(targetActor, RESET_TAG)
    RemoveActorTag(targetActor, resetNumberTag)
end

--Handles the resetting of all (still exisiting) actors
local function ResetAll()
    local actors = GetAllActorsWithTag(RESET_TAG)
    for _, actor in ipairs(actors) do
        local number = FindResetNumberTag(actor)
        if not number then
            SendServerMessage(ERROR_RESET_ACTOR:format(GetActorClassName(actor), "(FAIL numbertag)"))
        else
            ResetActorLocation(actor, number)
        end
    end
end

--Deletes all duplicates that were not explicitly created to persist rounds.
local function DeleteDuplicates()
    local duplicates = GetAllActorsWithTag(WILL_BE_DELETED_TAG)
    for _, dup in ipairs(duplicates) do
        GS():LuaDestroyActor(dup)
    end
end

local restartFlag = false
--Teleport moved actors back and delete duplicates at round end.
ListenToEvent("RoundFinished", function()
    ResetAll()
    DeleteDuplicates()
    if restartFlag == true then
        SetTimer(0.01, "RestartRoundLUA", GM())
    end
end)


------------------------------------

--COMMANDS


--LOGIC

local channels = {}
--Prints the state of the provided logic channel.
Register("lc", function (args)
    local channel = args[1]
    if not channel then
        SendServerMessage("Error, no channel id provided.")
        return
    end
    local channelID = ParseNumber(channel)
    if not channelID then return end
    channelID = math.floor(channelID)
    local state = channels[channelID]
    if state == nil then
        SendServerMessage(("State of channel %d is false (default)"):format(channelID))
    else
        SendServerMessage(("State of channel %d is %s"):format(channelID, tostring(state)))
    end
end, {"channel", "logicchannel"})

--Sets the state of a logic channel.
Register("setlc", function (args)
    if not args[1] or not args[2] then
        SendServerMessage(("Error, no id or bool provided. Usage: %ssetlc [id] [state]"):format(COMMAND_PREFIX))
        return
    end
    local id = ParseNumber(args[1])
    if not id then return end
    local state = ParseBool(args[2])
    if state == nil then
        SendServerMessage(("Error, \"%s\" is not a valid state. Use true or false."):format(args[2]))
        return
    end
    GS():UpdateChannel(math.floor(id), state)
    SendServerMessage(("Set channel %d to %s"):format(id, tostring(state)))
end, {"setlogicchannel", "setchannel", "setlogic"})


--CONTROL

--Restarts the round and also fires RoundFinished.
ListenToEvent("RestartRoundLUA", function (gm)
    gm:RestartHeistGame()
end)
Register("restart", function ()
    SendServerMessage("Restarting round...")
    local gm = GM()
    restartFlag = true
    SetTimer(0.01, "RoundFinished", gm) --will also trigger restart since flag is set.
end, {"restartround", "roundrestart", "resetround", "roundreset"})


--Sets the round timer in seconds. You can freeze the timer by setting the time to 0 or lower.
Register("time", function (args)
    if not args[1] then
        SendServerMessage("Error, no time (in s) provided.")
        return
    end
    local seconds = ParseNumber(args[1])
    if not seconds then return end
    if seconds <= 0 then
        SendServerMessage(("Error, time must be greater than zero. If you want to pause the timer, use %spause."):format(COMMAND_PREFIX))
        return
    end
    GS():UpdateRoundTimerSV(seconds)
    SendServerMessage(("Set round timer to %.2f seconds."):format(seconds))
end, {"timer", "settimer", "settime", "roundtimer", "roundtime", "setroundtime", "setroundtimer"})

--Pauses the round timer and saves its current time.
Register("pause", function ()
    if not CheckRoundLive() then return end
    if paused then
        SendServerMessage("Error, timer is already paused.")
        return
    end
    paused = true
    roundTimeAtPause = GS().RoundTimer
    GS():UpdateRoundTimerSV(0)
    SendServerMessage(("Time paused at %d seconds. To resume, type %sunpause."):format(roundTimeAtPause, COMMAND_PREFIX))
end, {"pausetime", "pausetimer"})

--Unpauses the round timer.
Register("unpause", function ()
    if not paused then
        SendServerMessage("Error, round timer is not paused.")
        return
    end
    GS():UpdateRoundTimerSV(roundTimeAtPause)
    paused = false
    SendServerMessage(("Timer unpaused at %d seconds."):format(roundTimeAtPause))
end, {"unpausetime", "unpausetimer"})


--Kills the player that runs the command (automatic respawn).
Register("kill", function (_, playerActor)
    playerActor:PlayerDiedCl()
    playerActor:PlayerDiedSv()
    SendServerMessage("Killed player " .. playerActor.PlayersName)
end)

--Kills the player that runs the command and does not respawn them.
Register("killnorespawn", function (_, playerActor)
    if not CheckRoundLive() then return end
    playerActor:PlayerDiedSvNoRespawn(false, false)
    SendServerMessage("Killed (no respawn) player " .. playerActor.PlayersName)
    local players = GetAllActorsOfClass("PlayerChar")
    local robberAlive = false
    local copAlive = false
    local robberExists = false
    local copExists = false
    for _, player in ipairs(players) do
        if not player.dead then
            if player.robber then
                robberAlive = true
            else
                copAlive = true
            end
        end
        if player.robber then
            robberExists = true
        else
            copExists = true
        end
    end
    local isRobber = playerActor.robber
    if #players == 1 then
        local wonReason = isRobber == false and 1 or 2 --1 = cops died; 2 = robbers died; 0 = stole money
        GM():RoundWon_GM(isRobber == false, wonReason)
    elseif not robberAlive and copExists and isRobber == true then
        GM():RoundWon_GM(false, 2)
    elseif not copAlive and robberExists and isRobber == false then
        GM():RoundWon_GM(true, 1)
    end
end)

--Respawns the player that runs the command. (Does currently not work as intended)
--SupriseRespawnSV 	loc: FVector, HP: float -- SupriseRespawnCl
Register("respawn", function (_, playerActor)
    GM():RespawnPlayer(playerActor, false)
    playerActor:PlayerRespawnedCl()
    playerActor:PlayerRespawnedSv()
    SendServerMessage("Respawned player " .. playerActor.PlayersName)
end)


--Sets the player hp to the provided number (default 100)
Register("healme", function (args, playerActor)
    local hp = tonumber(args[1]) or 100
    playerActor.HP = hp
end, {"myhp", "setmyhp"})


--Teleports the player that runs the command to the specified coordinates.
Register("tpme", function (args, playerActor)
    local index
    local location
    if args and #args == 1 then
        index = ParseNumber(args[1])
        if not index then return end
        index = math.floor(index)
        location = GetLocationFromIndex(index)
    else
        location = GetCoordinates(args)
    end
    if not location then return end
    teleportPlayer(location, playerActor:GetActorLocation(), playerActor)
end, {"teleportme"})

--Teleports the player that runs the command relative to their current position.
Register("tpmerel", function (args, playerActor)
    local index
    local location
    if args and #args == 1 then
        index = ParseNumber(args[1])
        if not index then return end
        index = math.floor(index)
        location = GetLocationFromIndex(index)
    else
        location = GetCoordinates(args)
    end
    if not location then return end
    local currentLocation = playerActor:GetActorLocation()
    teleportPlayer(AddVectors(location, currentLocation), currentLocation, playerActor)
end, {"tpmerelative", "teleportmerelative", "teleportmerel"})

--Sends a help message about teleporting.
Register("tp", function ()
    SendServerMessage(("To teleport yourself, use %stpme. To teleport the loaded actor, use %stpactor"):format(COMMAND_PREFIX, COMMAND_PREFIX))
end, {"teleport"})


--Forces the round to start immediately
Register("start", function ()
    local players = GetAllActorsOfClass("PlayerChar")
    for _, player in ipairs(players) do
        player:SetReadyCl(true)
    end
end, {"ready", "startround"})


--ACTORS

--Prints the amount of actors with the tag. If there is exactly one, its class is printed.
Register("tag", function (args)
    local tag = args[1]
    if not tag then
        SendServerMessage(ERROR_NO_TAG_PROVIDED)
        return
    end
    local amount = #GetAllActorsWithTag(tag)
    SendServerMessage(("Amount of actors with tag \"%s\" is %d"):format(tag, amount))
    if amount == 1 then
        SendServerMessage("Class is " .. GetActorClassName(GetActorWithTag(tag)))
    end
end, {"howmanyactors", "amountofactors", "actorswithtag", "totaltag"})

local SPAWN_MESSAGE = "Spawned actor of class \"%s\"%s."
--Spawns an actor with the provided class at the provided location.
--Usage: !spawn [class] [loc] [(opt) tag] with loc being three coordinates or an index.
Register("spawn", function (args)
    if not args or #args < 2 then
        SendServerMessage(("Error, not anought arguments provided. Usage \"%sspawn [class] [loc]\"."):format(COMMAND_PREFIX))
        return
    end
    local className = args[1]
    local loc
    local tag
    local size = #args
    if size == 2 then
        loc = GetLocationFromIndex(args[2])
    elseif size == 3 then
        loc = GetLocationFromIndex(args[2])
        tag = args[3]
    elseif size == 4 then
        loc = GetCoordinates({table.unpack(args, 2)})
    elseif size == 5 then
        loc = GetCoordinates({table.unpack(args, 2)})
        tag = args[5]
    else
        SendServerMessage(("Error, invalid amount of args. Usage \"%sspawn [class] [loc]\"."):format(COMMAND_PREFIX))
    end
    if not loc then return end
    local actor = SpawnActor(className, loc)
    if not actor then
        SendServerMessage("Spawn failed.")
        return
    end
    className = GetActorClassName(actor)
    if tag then
        AddActorTag(actor, tag)
        SendServerMessage(SPAWN_MESSAGE:format(className, " and added tag \"" .. tag .. "\""))
    else
        SendServerMessage(SPAWN_MESSAGE:format(className, ""))
    end
end)


--Load an actor to access its commands


--Loads a new list of actors with the specified tag.
Register("load", function (args)
    local tag = args[1]
    if not tag then
        SendServerMessage(ERROR_NO_TAG_PROVIDED)
        return
    end
    if LoadActorsList(tag, false) then
        LoadActorFromList(1)
    end
end, {"loadactor", "loadtag", "loadactortag", "loadfromtag"})

--Loads a new list of actors with the specified class.
Register("loadclass", function (args)
    local class = args[1]
    if not class then
        SendServerMessage("Error, no class provided.")
        return
    end
    if LoadActorsList(class, true) then
        LoadActorFromList(1)
    end
end, {"loadclassname", "loadactorclass", "loadfromclass"})


--Updates the saved actors by searching for the saved tag.
Register("update", function ()
    if not loadedTag and not loadedClass then
        SendServerMessage("Error, no tag or class loaded.")
        return
    end
    local isClass = loadedClass ~= nil
    local identifierName = GetIdentifierName(isClass)
    if not LoadActorsList(isClass and loadedClass or loadedTag, isClass) then
        SendServerMessage(("Error, no actors found with %s \"%s\"."):format(identifierName, isClass and loadedClass or loadedTag))
        return
    end
    SendServerMessage(("Updated the actors list using %s \"%s\"."):format(identifierName, loadedClass))
    LoadActorFromList(1)
end, {"refresh"})


--Switching between loaded actors found by the same tag or class

--Loads the next actor in the list.
Register("next", function ()
    if #loadedActorsList == 1 then
        SendServerMessage(ERROR_ONLY_ONE_ACTOR:format(loadedTag, COMMAND_PREFIX))
        return
    end
    loadedActorsIndex = loadedActorsIndex + 1
    if loadedActorsIndex > #loadedActorsList then
        loadedActorsIndex = 1
    end
    LoadActorFromList(loadedActorsIndex)
end, {"nxt"})

--Loads the previous actor in the list.
Register("prev", function ()
    if #loadedActorsList == 1 then
        SendServerMessage(ERROR_ONLY_ONE_ACTOR:format(loadedTag, COMMAND_PREFIX))
        return
    end
    loadedActorsIndex = loadedActorsIndex - 1
    if loadedActorsIndex < 1 then
        loadedActorsIndex = #loadedActorsList
    end
    LoadActorFromList(loadedActorsIndex)
end, {"previous"})

--Loads the actor at the provided index. If no index is provided, it prints the current index instead.
Register("index", function (args)
    if not args[1] then
        if loadedActorsIndex ~= nil then
            SendServerMessage(("Currently loaded index is %d. To change it type %sindex [i]"):format(loadedActorsIndex, COMMAND_PREFIX))
            return
        else
            SendServerMessage("Error, no actors loaded.")
            return
        end
    end
    local index = ParseNumber(args[1])
    if not index then return end
    LoadActorFromList(math.floor(index))
end, {"setindex", "loadindex"})


--Tags of the loaded actor

--Prints the tags of the loaded actor.
Register("tags", function ()
    if not CheckActorExistence() then return end
    local tags = GetActorTags(loadedActor)
    if #tags == 0 then
        SendServerMessage("Loaded actor has no tags.")
    else
        SendServerMessage(table.concat(tags, ", "))
    end
end, {"tagsofactor", "actortags", "tagsactor"})


--Prints the amount of tags of the loaded actor.
Register("amountoftags", function ()
    if not CheckActorExistence() then return end
    local amount = #GetActorTags(loadedActor)
    SendServerMessage(("Loaded actor has %d tags"):format(amount))
end, {"amounttags"})

--Adds the provided tag to the loaded actor.
Register("add", function (args)
    if not args[1] then
        SendServerMessage(ERROR_NO_TAG_PROVIDED)
        return
    end
    if not CheckActorExistence() then return end
    local tag = args[1]
    AddActorTag(loadedActor, tag)
    SendServerMessage(("Added tag \"%s\" to the loaded actor."):format(tag))
end, {"addtag", "addactortag"})

--Removes the provided tag from the loaded actor.
Register("remove", function (args)
    if not args[1] then
        SendServerMessage(ERROR_NO_TAG_PROVIDED)
        return
    end
    if not CheckActorExistence() then return end
    local tag = args[1]
    RemoveActorTag(loadedActor, tag)
    SendServerMessage(("Removed tag \"%s\" from the loaded actor."):format(tag))
end, {"rmv", "removetag", "rmvtag", "removeactortag"})


--Prints the class of the loaded actor.
Register("class", function ()
    if CheckActorExistence() then
        SendServerMessage(("Class of loaded actor is \"%s\""):format(GetActorClassName(loadedActor)))
    end
end, {"actorclass"})

local ERROR_NO_HP = "Error, loaded actor does not have HP."
Register("hp", function ()
    if not CheckActorExistence() then return end
    local hp = loadedActor.HP
    if hp == nil then
        SendServerMessage(ERROR_NO_HP)
        return
    end
    SendServerMessage(("Loaded actor HP is %.2f."):format(hp))
end)

--Sets the loaded actor's HP to the provided number (if it has HP).
Register("sethp", function (args)
    if not CheckActorExistence() then return end
    local currentHP = loadedActor.HP
    if currentHP == nil then
        SendServerMessage(ERROR_NO_HP)
        return
    end
    local newHP = ParseNumber(args[1])
    if newHP == nil then return end
    loadedActor.HP = newHP
    SendServerMessage(("Set loaded actor HP to %.2f."):format(newHP))
end)

--Prints the location of the loaded actor.
Register("loc", function ()
    if not CheckActorExistence() then return end
    local loc = loadedActor:GetActorLocation()
    SendServerMessage(("Location of loaded actor is X=%.2f, Y=%.2f, Z=%.2f"):format(loc.X, loc.Y, loc.Z))
end, {"location", "getloc", "getlocation", "getactorlocation", "pos", "position", "getpos", "getposition", "getactorposition"})

--Teleports the loaded actor to the provided location.
Register("setloc", function (args, playerActor)
    if not CheckActorExistence() then return end
    local index
    local location
    if not args or #args == 0 then
        SendServerMessage("Error, no location or index provided.")
        return
    end
    if #args == 1 then
        index = ParseNumber(args[1])
        if not index then return end
        index = math.floor(index)
        location = GetLocationFromIndex(index)
    else
        location = GetCoordinates(args)
    end
    if not location then return end
    MakeMoveable(loadedActor)
    local name = playerActor.PlayersName
    lastTeleportOrigin[name] = loadedActor:GetActorLocation()
    lastTeleportedActor[name] = loadedActor
    loadedActor:SetActorLocation(location)
    local class = GetActorClassName(loadedActor)
    if class == "Lua_Actor_Spawner" then
        SendServerMessage(("Please note - you have teleported a Lua spawner, not an actual lua actor. %s"):format(TELEPORT_BACK_MESSAGE))
    else
        SendServerMessage(("Teleported loaded actor. %s"):format(TELEPORT_BACK_MESSAGE))
    end
end, {"setlocation", "setposition", "setpos", "tpactor", "teleportactor", "tploaded", "teleportloaded", "setactorlocation"})

--Teleports the loaded actor relative to its current location.
Register("setlocrel", function (args, playerActor)
    if not CheckActorExistence() then return end
    local index
    local location
    if args and #args == 1 then
        index = ParseNumber(args[1])
        if not index then return end
        index = math.floor(index)
        location = GetLocationFromIndex(index)
    else
        location = GetCoordinates(args)
    end
    if not location then return end
    local name = playerActor.PlayersName
    lastTeleportOrigin[name] = loadedActor:GetActorLocation()
    lastTeleportedActor[name] = loadedActor
    loadedActor:SetActorLocation(AddVectors(location, lastTeleportOrigin[name]))
    local class = GetActorClassName(loadedActor)
    if class == "Lua_Actor_Spawner" then
        SendServerMessage(("Please note - you have teleported a Lua spawner, not an actual lua actor. %s"):format(TELEPORT_BACK_MESSAGE))
    else
        SendServerMessage(("Teleported loaded actor. %s"):format(TELEPORT_BACK_MESSAGE))
    end
end, {"setlocrelative", "setlocationrel", "setlocationrelative", "tpactorrel", "tpactorrelative", "tploadedrel", "tploadedrelative", "teleportloadedrel", "teleportloadedrelative", "teleportactorrel", "teleportactorrelative", "setactorlocationrel", "setactorlocationrelative"})


--Checks the status of the currently loaded actor.
Register("check", function ()
    if loadedActor == nil then
        SendServerMessage("Currently no actor loaded.")
    else
        if not Exists(loadedActor) then
            SendServerMessage("Loaded actor does not exist anymore.")
        else
            SendServerMessage(("Currently loaded actor is \"%s\" at index %d."):format(GetActorName(loadedActor), loadedActorsIndex))
        end
    end
    if loadedTag == nil then
        SendServerMessage("Tag was unloaded or never provided.")
    else
        SendServerMessage(("Currently loaded tag is \"%s\""):format(loadedTag))
    end
end, {"checkactor", "checkloaded"})


--Duplicates the loaded actor and gives it the tag if provided. Position is world coordinates.
Register("duplicate", function (args)
    Duplicate(args, false, false)
end)

--Duplicates the loaded actor and gives it the tag if provided. Position is relative to the loaded actor.
Register("duplicaterel", function (args)
    Duplicate(args, true, false)
end, {"duplicaterelative"})

--Like duplicate, but the duplicate will not be deleted.
Register("duplicatepersist", function (args)
    Duplicate(args, false, true)
end)

--Like duplicaterel, but the duplicate will not be deleted.
Register("duplicaterelpersist", function (args)
    Duplicate(args, true, true)
end, {"duplicaterelativepersist"})

--Pings the loadedActor.
Register("ping", function ()
    if not CheckActorExistence() then return end
    GS():SpawnLuaPingSV(PING_FILE_NAME, loadedActor:GetActorLocation())
end, {"pingactor"})

--Destroys the loaded actor except for Lua Spawners, player chars and level editor props since they will not respawn.
--Use forcedestroy if you want to destroy it regardless.
Register("destroy", function ()
    if not CheckActorExistence() then return end
    local className = GetActorClassName(loadedActor)
    if className == "Lua_Actor_Spawner" then
        SendServerMessage(("Error, loaded actor is a lua spawner. If you really want to destroy it permanently, use %sforcedestroy."):format(COMMAND_PREFIX))
        return
    elseif className == "SM_Act" then
        SendServerMessage(("Error, loaded actor is a level editor prop. If you want to destroy it permanently, use %sforcedestroy. It is recommended to teleport it instead which will be reset automatically at round end."):format(COMMAND_PREFIX))
        return
    elseif className == "PlayerChar" then
        SendServerMessage(("Error, loaded actor is a player char. If you really want to destroy it (will break the game for that player) use %sforcedestroy"):format(COMMAND_PREFIX))
        return
    end
    GS():LuaDestroyActor(loadedActor)
    SendServerMessage("Destroyed loaded lua actor.")
end, {"destroyactor", "luadestroy", "luadestroyactor", "destroylua", "destroyluactor"})

--Destroys the loaded actor.
--WARNING: destroying a Lua_Actor_Spawner or an editor prop will permanently delete it from the server.
--Destroying a player actor will force them to rejoin.
Register("forcedestroy", function ()
    if not CheckActorExistence() then return end
    local className = GetActorClassName(loadedActor)
    GS():LuaDestroyActor(loadedActor)
    if className == "BP_LuaActor" then
        SendServerMessage("Destroyed loaded lua actor.")
    else
        SendServerMessage(("Destroyed loaded actor of class \"%s\". Might be permanent."):format(className))
    end
end)


--OTHER COMMANDS

Register("myloc", function (_, playerActor)
    local loc = playerActor:GetActorLocation()
    SendServerMessage(("Your location is X=%.2f, Y=%.2f, Z=%.2f."):format(loc.X, loc.Y, loc.Z))
end, {"mylocation", "mypos", "myposition"})

--Saves the current location of the loaded actor.
Register("saveactorloc", function ()
    SaveActorLocation(loadedActor)
end, {"saveloadedloc", "saveactorpos", "saveactorposition", "saveactorlocation"})

--Saves the current location of the player that ran the command.
Register("savemyloc", function (_, playerActor)
    SaveActorLocation(playerActor)
end, {"savemylocation", "savemypos", "savemyposition"})

--Saves the provided coordinates.
Register("saveloc", function (args)
    local coords = GetCoordinates(args)
    if coords then
        SaveLocation(coords)
    end
end)


--QOL

local lastCommands = {}
local lastArgs = {}
local repeatFlag
--Repeats the player's last command using the same arguments.
Register("repeat", function (_, playerActor)
    local name = playerActor.PlayersName
    if not lastCommands[name] then
        SendServerMessage("Error, you have not run a command before.")
        return
    end
    repeatFlag = true
    lastCommands[name](lastArgs[name], playerActor)
end)

--Teleports the last teleported actor to the origin position, different for each player.
Register("back", function (_, playerActor)
    local name = playerActor.PlayersName
    local actor = lastTeleportedActor[name]
    if not CheckActorExistence(actor) then return end
    local loc = lastTeleportOrigin[name]
    if not loc then
        SendServerMessage("Error, could not find last location.")
        return
    end
    actor:SetActorLocation(loc)
    SendServerMessage(("Teleported actor of class %s back."):format(GetActorClassName(actor)))
end, {"tpback", "teleportback"})



------------------------------------


--Logic channel tracking
ListenToEvent("LogicChannelChanged", function (channelID, newState)
    channels[channelID] = newState
end)

--Welcome message
ListenToEvent("TeamSelectionStarted", function()
    SendServerMessage(("Debug mod enabled. Your command prefix is \"%s\". All commands are case insensitive."):format(COMMAND_PREFIX))
end)


-----------------------------------
--Command Handling
local VANILLA_COMMANDS = {
    yes = true,
    no = true
}

--Escapes special characters in the command prefix.
local function EscapePattern(s)
    return s:gsub("([%%%^%$%(%)%%.%[%]%*%+%-%?])", "%%%1")
end

local function HandleMessage(message, teamID, playerActor)
    local commandMatch = EscapePattern(COMMAND_PREFIX) .. "%s*(.+)"
    local commandString = message:match(commandMatch)
    if commandString and teamID ~= 0 then
        local words = {}
        for word in string.gmatch(commandString:lower(), "%S+") do
            table.insert(words, word)
        end
        local command = words[1]
        if not command then return end
        table.remove(words, 1)
        local fn = commands[command]
        if fn then
            fn(words, playerActor)
            if not repeatFlag then
                local name = playerActor.PlayersName
                if name then
                    lastCommands[name] = fn
                    lastArgs[name] = CopyTable(words)
                end
            end
            repeatFlag = false
        elseif not VANILLA_COMMANDS[command] then
            SendServerMessage(("Error, unknown debug command \"%s\"."):format(command))
        end
    end
end

ListenToEvent("AllMessage", function (message, teamID, playerActor)
    HandleMessage(message, teamID, playerActor)
end)

ListenToEvent("TeamMessage", function (message, teamID, playerActor)
    HandleMessage(message, teamID, playerActor)
end)
