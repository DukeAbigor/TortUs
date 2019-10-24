local daemon = require "daemon"

local tortusBase = {}
---localized turtle to prevent other scripts from changing dependencies
tortusBase.turtle = {}
---Functions and values returned when tortus library is required
tortusBase.library = {}

--------------------------------------------------
--[[
    Everything in this block is used internally by the API
    none of these should be exposed globally
]]

-- make a new local turtle table to prevent dependant functions from getting changed underneath us
for k, v in next, _G.turtle do
    tortusBase.turtle[k] = v
end

---A copy of the turtle library which is chainable.
tortusBase.chain = setmetatable({},{
	__index = function(t, k)
		return function(...)
			if tortusBase.library[k] then
				return t, tortusBase.library[k](...)
			else
				return t, tortusBase.turtle[k](...)
			end
		end
	end
})
table.insert(tortusBase.library, tortusBase.chain)

--[[
    we use this table throughout the program to always remember what direction is relative to which
    and how our grid position changes when we move relative to our current cardinal direction
    e.g. to get the left cardinal direction you would do tFacing[(ourCurrentDirection)]
]]

---Used to get cardinal directions relative to the current facing and their relative direction on the grid.
tortusBase.directionLookup = {
    east  = { left="north" , right="south" , back="west"  , forward="x" , multiplier =  1 },
	north = { left="west"  , right="east"  , back="south" , forward="z" , multiplier = -1 },
	south = { left="east"  , right="west"  , back="north" , forward="z" , multiplier =  1 },
	west  = { left="south" , right="north" , back="east"  , forward="x" , multiplier = -1 },
	up    = {                                               forward="y" , multiplier =  1 },
	down  = {                                               forward="y" , multiplier = -1 }
}

---@type fun():table[]
local function internalInventoryHandle()
	local output = {}
	for i = 1, 16 do
		output[i] = tortusBase.turtle.getItemDetail(i)
	end
	return output
end

---Turtle's current inventory.
tortusBase.inventory = internalInventoryHandle()

---Turtle's currently selected slot.
---@type number
tortusBase.currentSelectedSlot = tortusBase.turtle.getSelectedSlot()

-- this block will run on the first init of any system
if not fs.exists("tortus/.storage.db") then
    print("Initializing the TortUs database.\nThis should only happen on first run.")

    --let the user know early if we need fuel to init
    if tortusBase.turtle.getFuelLevel() == 0 then
        print("\nI will need fuel to figure out some initialization values.\nPlease place a fuel item in my currently selected slot")
    end

    local is_itemDropped
	for i = 1, 16 do
		if (not tortusBase.inventory[i]) or tortusBase.inventory[i].count == 0 then
			break
        end
        --if all inventory spaces are full just drop an item for now
		if i==16 then
			tortusBase.turtle.select(i)
            tortusBase.turtle.dropUp()
            is_itemDropped = true
		end
    end

    --recording whats currently equipped to the turtle
	tortusBase.turtle.equipLeft()
	local leftTool = tortusBase.turtle.getItemDetail()
	tortusBase.turtle.equipLeft()
	tortusBase.turtle.equipRight()
	local rightTool = tortusBase.turtle.getItemDetail()
    tortusBase.turtle.equipRight()

    if is_itemDropped then tortusBase.turtle.suckUp() end --littering is a crime

    local originalX, originalY, originalZ = gps.locate(2)
    local cardinalDirection

    --this block gathers the turtle's current position and rotation
    if originalX then --if we have gps signal

        local timesTurned = 0

        --find a direction we can move forward
		while not tortusBase.turtle.forward() do
			if not tortusBase.turtle.detect() and not tortusBase.turtle.attack() then
				tortusBase.turtle.refuel()
			else
				tortusBase.turtle.turnLeft()
				timesTurned = timesTurned + 1
			end
        end

        --figures out what direction we are facing based on how our coordinates change when we move
        local newX, _, newZ = gps.locate(2)
        local xDifference = newX - originalX
        local zDifference = newZ - originalZ

        if xDifference == 0 then
            if zDifference == -1 then
                cardinalDirection = "north"
            else
                cardinalDirection = "south"
            end
        elseif xDifference == -1 then
            cardinalDirection = "west"
        else
            cardinalDirection = "east"
        end

        --return to our original location
        if not tortusBase.turtle.back() then
            tortusBase.turtle.turnLeft()
            tortusBase.turtle.turnLeft()
            timesTurned = timesTurned + 2
            while not tortusBase.turtle.forward() do
                if not tortusBase.turtle.detect() and not tortusBase.turtle.attack() then
                    tortusBase.turtle.refuel()
                end
            end
        end

		for _ = 1, timesTurned%4 do
			tortusBase.turtle.turnRight()
			cardinalDirection = tortusBase.directionLookup[cardinalDirection].right
        end

	else --no gps so we must ask
		print("\nThere is no nearby GPS please set up a GPS and reboot or manually enter the required information\nPos: ")
		write("   X: ")
		originalX = tonumber(read())
		write("   Y: ")
		originalY = tonumber(read())
		write("   Z: ")
		originalZ = tonumber(read())
		write("Cardinal Direction: ")
		cardinalDirection = read()
		print("Thank you!\nIf this disrupted anything please just reboot the turtle\nWe shouldn't ask any of this again.")
	end

    --build database
	local database = fs.open("tortus/.storage.db" , "w")
	tortusBase.cache = {
		position = {x = originalX, y = originalY, z = originalZ},
		direction = cardinalDirection,
		equipment = {left = leftTool, right = rightTool},
		lastFuelLevel = tortusBase.turtle.getFuelLevel(),
		lastCardinalMovement = "none" ,
		movementLog = {},
	}
	database.write(textutils.serialize(tortusBase.cache):gsub("\10" , ""))
    database.close()

    --just in case we accidentally moved something during our checks
    tortusBase.inventory = internalInventoryHandle()
end

--the following makes it so that every time a value in our cache is changed the database gets updated as well
local function nestedTableHandle(tbl, key)
	return {
		__newindex = function(t, k, v)
			rawset(t.handle, k, v)
			tbl[key] = t.handle
		end;
		__index = function(t, k)
			if type(t.handle[k]) =="table" then
				return setmetatable({handle = t.handle[k]}, nestedTableHandle(t, k))
            else
                return t.handle[k]
            end
		end;
	}
end

local cacheMeta = {
	__newindex = function(t, k, v)
		rawset(t.handle,k,v)
		file = fs.open("tortus/.storage.db" , "w")
		file.write(textutils.serialize(t.handle):gsub("\10" , ""))
		file.close()
	end;
	__index = function(t, k)
		if type(rawget(t.handle,k)) == "table" then
			return setmetatable({handle = rawget(t.handle,k)}, nestedTableHandle(t, k)) --tables are hard
		else
			return rawget(t.handle, k)
		end
	end;
}

file = fs.open("tortus/.storage.db" , "r")

---@class cache
---@field public position table
---@field public direction string
---@field public equipment table
---@field public lastCardinalMovement string
---@field public movementLog table
---@field public lastFuelLevel number
tortusBase.cache = setmetatable({handle=textutils.unserialize(file.readLine())}, cacheMeta)
file.close()

--establishes a daemon to monitor our inventory
local function monitorInventory()
	while true do
		os.pullEventRaw("turtle_inventory")
		tortusBase.inventory = internalInventoryHandle()
	end
end
daemon.add(monitorInventory)

---updates the turtle's currently recorded position
---@return nil
function tortusBase.updatePosition()
	if tortusBase.cache.lastCardinalMovement~="none" then
		local lastCardinalDirection = tortusBase.directionLookup[tortusBase.cache.lastCardinalMovement]
		tortusBase.cache.position[lastCardinalDirection.forward] = tortusBase.cache.position[lastCardinalDirection.forward] + (lastCardinalDirection.multiplier * (tortusBase.cache.lastFuelLevel - tortusBase.turtle.getFuelLevel()))
		tortusBase.cache.lastFuelLevel = tortusBase.turtle.getFuelLevel()
	end
end

return tortusBase