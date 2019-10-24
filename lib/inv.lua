local tortusBase = require "tortus.tortusBase"

local invModule = {}

--- Searches the inventory for an item by ID.
---|
---|If the item is found will pass true along with the slot it was found in and a table with the item's details.
---@param searchFor string
---@return boolean
---@return number | nil
---@return table | nil
function invModule.has(searchFor)
    local itemDetails
    local itemSlot
    for i = 1, 16 do
        if tortusBase.inventory[i] and tortusBase.inventory[i].name == searchFor then
            itemDetails = tortusBase.inventory[i]
            itemSlot = i
            break
        elseif not tortusBase.inventory[i] and (searchFor == "empty" or searchFor == "minecraft:air") then
            itemDetails = {
                name = "minecraft:air",
                count = 0
            }
            itemSlot = i
            break
        end
    end
    if not itemSlot then
        return false
    else
        return true, itemSlot, itemDetails
    end
end



--- Evaluates if the given slot is empty or not.
---|
---|If no slot is given then uses the current selected slot.
---@param slot number
---@return boolean
---@overload fun():boolean
function invModule.isEmpty(slot)
    if slot then
        return type(tortusBase.inventory[slot]) == "table"
    else
        return type(tortusBase.inventory[tortusBase.currentSelectedSlot]) == "table"
    end
end



--- selects a slot in the turtle's inventory.
---|
---|Accepts either a slot number or item ID.
---@param slotRequested number|string
---@return boolean
function invModule.select(slotRequested)
    if type(slotRequested) == "number" then
        return tortusBase.turtle.select(slotRequested)
    else
        local is_available, selectSlot = invModule.has(slotRequested)
        if is_available then
            tortusBase.currentSelectedSlot = selectSlot
        end
        return is_available and tortusBase.turtle.select(selectSlot)
    end
end



--- Syntax sugar for select("empty").
---|
---|Selects the first available empty slot.
---@return boolean
function invModule.selectEmpty()
    return select("empty")
end



--- Syntax sugar for invModule.has("empty").
---|
---|returns true if there is an empty slot and the slot number if available.
---@return boolean
---@return number|nil
function getEmptySlot()
    local is_available, slotNumber = invModule.has("empty")
    return is_available, slotNumber
end



--------------------------------------------------
--[[
    internal logic for both equip functions
]]
local function internalEquip(side, slot, is_returnToSlot)
    local wasSelectedSlot = tortusBase.currentSelectedSlot
    if (not slot) or select(slot) then
        local item = tortusBase.inventory[tortusBase.currentSelectedSlot]
        if turtle["equip"..side]() then
            if is_returnToSlot then
                select(wasSelectedSlot)
            end
            foobar.equipment[toLower(side)] = item
            return true
        end
    end
    return false
end

local toolAliases = {
    pickaxe = "minecraft:diamond_pickaxe",
    hatchet = "minecraft:diamond_hatchet",
    workbench = "minecraft:crafting_table",
    hoe = "minecraft:diamond_hoe",
    shovel = "minecraft:diamond_shovel",
    advModem = "computercraft:wireless_modem_advanced",
    modem = "computercraft:wireless_modem_normal"
}
--




--- Attempts to equip a tool to the turtle's left side.
---|
---|Will use current selection or slot. Slot can be either the inventory number or item ID.
---|
---|If is_returnToSlot is true and slot is defined then the turtle will keep its original slot selected after equipping.
---@param slot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(slot:number|string):boolean
---@overload fun():boolean
function invModule.equipLeft(slot, is_returnToSlot)
    return internalEquip("Left", toolAliases[slot] or slot, is_returnToSlot)
end



--- Attempts to equip a tool to the turtle's right side.
---|
---|Will use current selection or slot. Slot can be either the inventory number or item ID.
---|
---|If is_returnToSlot is true and slot is defined then the turtle will keep its original slot selected after equipping.
---@param slot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(slot:number|string):boolean
---@overload fun():boolean
function invModule.equipRight(slot, is_returnToSlot)
    return internalEquip("Right", toolAliases[slot] or slot, is_returnToSlot)
end



---Returns the count of items in the slot.
---@param requestedSlot string|number
---@return number
---@overload fun():number
function invModule.getItemCount(requestedSlot)
    local slotNumber = tortusBase.currentSelectedSlot
    local is_available

    if type(slot) == "string" then
        is_available, slotNumber = invModule.has(requestedSlot)
        if not is_available then
            return 0
        end
    elseif type(slot) == "number" then
        slotNumber = tortusBase.currentSelectedSlot
    end

    return tortusBase.inventory[slotNumber].count
end



---Returns the count of an item in the turtle's inventory.
---@param name string
---@return number
function invModule.getCountInInventory(name)
    local runningCount = 0
    for i = 1, 16 do
        if tortusBase.inventory[i].name == name then
            runningCount = runningCount + tortusBase.inventory[i].count
        end
    end
    return runningCount
end



---Returns the space left in the slot until a full stack.
---@param requestedSlot number|string
---@return number
function invModule.getItemSpace(requestedSlot)
    local selectSlot = tortusBase.currentSelectedSlot
    local is_available

    if type(requestedSlot) == "string" then
        is_available, selectSlot = invModule.has(requestedSlot)
        if not is_available then
            return -1
        end
    elseif type(requestedSlot) == "number" then
        selectSlot = tortusBase.currentSelectedSlot
    end

    return tortusBase.turtle.getItemSpace(selectSlot)
end



--------------------------------------------------
--[[
    internal logic for all suck functions
]]
local function internalSuck(suckDirection, dropDirection, unsortedWhitelist, unsortedBlacklist, is_returnToSlot)
    local wasSelectedSlot = tortusBase.currentSelectedSlot
    local dumpList = {}
    local pickedUpItem
    local is_suckedSomething

    local sortedBlacklist = {}
    for _, v in next, unsortedBlacklist do
        sortedBlacklist[v] = true
    end

    while select("empty") and turtle[suckDirection]() do
        local is_allowed
        pickedUpItem = tortusBase.turtle.getItemDetail()
        if not sortedBlacklist[pickedUpItem.name] then
            is_suckedSomething = true
            if #unsortedWhitelist == 0 then
                is_allowed = true
            else
                for i, sortedWhitelist in next, unsortedWhitelist do
                    if sortedWhitelist.name == pickedUpItem.name then
                        is_allowed = true

                        if unsortedWhitelist[i].count then
                            unsortedWhitelist[i].count = unsortedWhitelist[i].count - pickedUpItem.count

                            if unsortedWhitelist[i].count < 0 then
                                table.insert(dumpList, {count = math.abs(unsortedWhitelist[i].count), slot = tortusBase.currentSelectedSlot})
                                pickedUpItem.count = pickedUpItem.count + unsortedWhitelist[i].count
                                unsortedWhitelist[i].count = 0
                            end
                        end
                    end
                end
            end
        end
        if not is_allowed then
            table.insert(dumpList, {count = pickedUpItem.count, slot = tortusBase.currentSelectedSlot})
        end
    end

    for _, trash in next, dumpList do
        tortusBase.turtle.select(trash.slot)
        turtle[dropDirection](trash.count)
    end

    for i = #unsortedWhitelist, 1, -1 do
        if (not unsortedWhitelist[i].count) or unsortedWhitelist[i].count <= 0 then
            table.remove(unsortedWhitelist, i)
        end
    end

    if is_returnToSlot then
        select(wasSelectedSlot)
    end

    if #unsortedWhitelist > 0 then
        return false, unsortedWhitelist
    else
        return is_suckedSomething
    end
end
--



---Sucks items from the ground or container in front of the turtle and puts them into its inventory.
---|
---|Returns false if no items were sucked up at all or if any whitelist indexes have a count and did not reach that total.
---|
---|Returns a table of the counts that failed to be grabbed in the latter case.
---@param whitelist table
---@param blacklist table
---@param is_returnToSlot boolean
---@return boolean
---@return table|nil
---@overload fun(whitelist:table, blacklist:table):boolean, table|nil
---@overload fun(whitelist:table):boolean, table|nil
function invModule.filteredSuck(whitelist, blacklist, is_returnToSlot)
    return internalSuck("suck", "drop", whitelist, blacklist, is_returnToSlot)
end



---Sucks items from the ground or container above the turtle and puts them into its inventory.
---|
---|Returns false if no items were sucked up at all or if any whitelist indexes have a count and did not reach that total.
---|
---|Returns a table of the counts that failed to be grabbed in the latter case.
---@param whitelist table
---@param blacklist table
---@param is_returnToSlot boolean
---@return boolean
---@return table|nil
---@overload fun(whitelist:table, blacklist:table):boolean, table|nil
---@overload fun(whitelist:table):boolean, table|nil
function invModule.filteredSuckUp(whitelist, blacklist, is_returnToSlot)
    return internalSuck("suckUp", "dropUp", whitelist, blacklist, is_returnToSlot)
end



---Sucks items from the ground or container below the turtle and puts them into its inventory.
---|
---|Returns false if no items were sucked up at all or if any whitelist indexes have a count and did not reach that total.
---|
---|Returns a table of the counts that failed to be grabbed in the latter case.
---@param whitelist table
---@param blacklist table
---@param is_returnToSlot boolean
---@return boolean
---@return table|nil
---@overload fun(whitelist:table, blacklist:table):boolean, table|nil
---@overload fun(whitelist:table):boolean, table|nil
function invModule.filteredSuckUp(whitelist, blacklist, is_returnToSlot)
    return internalSuck("suckDown", "dropDown", whitelist, blacklist, is_returnToSlot)
end



--------------------------------------------------
--[[
    internal logic for all drop functions
]]
function internalDrop(dropDirection, count, slot, is_returnToSlot)
    local wasSelectedSlot = tortusBase.currentSelectedSlot

    if slot and not select(slot) then
        return false
    end

    local is_success = count and turtle[dropDirection](count) or turtle[dropDirection]()

    if is_returnToSlot then
        select(wasSelectedSlot)
    end

    return is_success
end
--



---Drops items from the turtle's inventory to the ground/container in front of it.
---@param count number
---@param slot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(count:number,slot:number|string):boolean
---@overload fun(count:number):boolean
---@overload fun():boolean
function invModule.drop(count, slot, is_returnToSlot)
    return internalDrop("drop", count, slot, is_returnToSlot)
end



---Drops items from the turtle's inventory to the ground/container above it.
---@param count number
---@param slot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(count:number,slot:number|string):boolean
---@overload fun(count:number):boolean
---@overload fun():boolean
function invModule.dropUp(count, slot, is_returnToSlot)
    return internalDrop("dropUp", count, slot, is_returnToSlot)
end



---Drops items from the turtle's inventory to the ground/container below it.
---@param count number
---@param slot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(count:number,slot:number|string):boolean
---@overload fun(count:number):boolean
---@overload fun():boolean
function invModule.dropDown(count, slot, is_returnToSlot)
    return internalDrop("dropDown", count, slot, is_returnToSlot)
end



--------------------------------------------------
--[[
    internal logic for all compare functions
]]
function internalCompare(direction, slot, is_returnToSlot)
    wasSelectedSlot = tortusBase.currentSelectedSlot

    if slot and not select(slot) then
        return false
    end

    local is_comparable = turtle[direction]()

    if is_returnToSlot then
        select(wasSelectedSlot)
    end

    return is_comparable
end
--



---Compare an item in the turtle's inventory to the block in front of the turtle.
---@param slot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(slot:number|string):boolean
---@overload fun():boolean
function invModule.compare(slot, is_returnToSlot)
    return internalCompare("compare", slot, is_returnToSlot)
end



---Compare an item in the turtle's inventory to the block above the turtle.
---@param slot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(slot:number|string):boolean
---@overload fun():boolean
function invModule.compareUp(slot, is_returnToSlot)
    return internalCompare("compareUp", slot, is_returnToSlot)
end



---Compare an item in the turtle's inventory to the block below the turtle.
---@param slot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(slot:number|string):boolean
---@overload fun():boolean
function invModule.compareDown(slot, is_returnToSlot)
    return internalCompare("compareDown", slot, is_returnToSlot)
end



---Compares two items in the turtle's inventory with each other.
---@param firstSlot number|string
---@param secondSlot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(firstSlot:number|string, secondSlot:number|string):boolean
---@overload fun(firstSlot:number|string):boolean
function invModule.compareTo(firstSlot, secondSlot, is_returnToSlot)
    local wasSelectedSlot = tortusBase.currentSelectedSlot
    local is_comparable

    if secondSlot and (not select(secondSlot)) then
        return false
    end

    if type(firstSlot) == "string" then
        local is_success, slotNumber = invModule.has(firstSlot)
       is_comparable = is_success and tortusBase.turtle.compareTo(slotNumber)
    else
        is_comparable = tortusBase.turtle.compareTo(firstSlot)
    end

    if is_returnToSlot then
        select(wasSelectedSlot)
    end

    return is_comparable
end



---Moves items from the current slot to a new slot.
---@param toSlot number|string
---@param count number
---@param fromSlot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(toSlot:number|string, count:number, fromSlot:number|string):boolean
---@overload fun(toSlot:number|string, count:number):boolean
---@overload fun(toSlot:number|string):boolean
function invModule.transferTo(toSlot, count, fromSlot, is_returnToSlot)
    local wasSelectedSlot = tortusBase.currentSelectedSlot

    if type(toSlot) == "string" then
        local is_success
        is_success, slotToNum = invModule.has(toSlot)
        if not is_success then
            return false
        end
    else
        slotToNum = toSlot
    end

    if type(fromSlot) == "string" then
        local is_success
        is_success, slotFromNum = invModule.has(fromSlot)
        if not is_success then
            return false
        else
            invModule.select(fromSlot)
        end
    elseif fromSlot then
        invModule.select(fromSlot)
    end

    local is_transferrable = count and tortusBase.turtle.transferTo(slot, count) or tortusBase.turtle.transferTo(slot)
    
    if is_returnToSlot then
        invModule.select(wasSelectedSlot)
    end

    return is_transferrable
end



---Moves items from the given slot to current one.
---@param slot number|string
---@param count number|nil
---@return boolean
function invModule.transferFrom(slot, count)
    local wasSelectedSlot = tortusBase.currentSelectedSlot
    
    if not select(slot) then
        return false
    end

    if not invModule.transferTo(wasSelectedSlot, count) then
        select(wasSelectedSlot)
        return false
    end

    select(wasSelectedSlot)
    return true
end



---Swaps two stacks in the turtle's inventory.
---@param toSlot number|string
---@param fromSlot number|string
---@param is_returnToSlot boolean
---@return boolean
---@overload fun(toSlot:number|string, fromSlot:number|string):boolean
---@overload fun(toSlot:number|string, is_returnToSlot:boolean):boolean
---@overload fun(toSlot:number|string):boolean
function invModule.swapStacks(toSlot, fromSlot, is_returnToSlot)
    if type(fromSlot) == "boolean" then
        is_returnToSlot = fromSlot
        fromSlot = nil
    end

    local is_empty, emptySlot = invModule.has("empty")
    local wasSelectedSlot = tortusBase.currentSelectedSlot
    local toSlotNum, fromSlotNum

    if type(toSlot) == "string" then
        local is_available
        is_available, toSlotNum = invModule.has(toSlot)

        if not is_available then
            return false
        end
    else
        toSlotNum = toSlot
    end

    if type(fromSlot) == "string" then
        local is_available
        is_available, fromSlotNum = invModule.has(fromSlot)

        if not is_available then
            return false
        end
    elseif type(fromSlot) == "number" then
        fromSlotNum = fromSlot
    else
        fromSlotNum = tortusBase.currentSelectedSlot
    end

    if not is_empty or toSlotNum > 16 or fromSlotNum > 16 then
        return false
    end

    tortusBase.chain.transferTo(emptySlot)
                    .select(toSlot)
                    .transferTo(fromSlot)
                    .select(emptySlot)
                    .transferTo(toSlot)

    if is_returnToSlot then
        tortusBase.turtle.select(wasSelectedSlot)
    end
end



---Consumes an item to refuel the turtle.
---@param count number|nil
---@param slot number|string|nil
---@return boolean
---@return number
function invModule.refuel(count, slot)
    if slot and not select(slot) then
        return false, tortusBase.turtle.getFuelLevel()
    end

    tortusBase.updatePosition()

	if (count and tortusBase.turtle.refuel(count)) or tortusBase.turtle.refuel() then
		tortusBase.cache.lastFuelLevel = tortusBase.turtle.getFuelLevel()
		return true, tortusBase.cache.lastFuelLevel
	end
	return false, tortusBase.turtle.getFuelLevel()
end



---Returns the turtle's left equipped tool.
---@return table
function invModule.getLeftEquipped()
    return tortusBase.cache.equipment.left
end



---Returns the turtle's right equipped tool.
---@return table
function invModule.getRightEquipped()
    return tortusBase.cache.equipment.right
end



---Returns a table of all items in the turtle's inventory.
---@return table
function invModule.getInventory()
    return tortusBase.inventory
end



for k, v in next, invModule do
    tortusBase.library[k] = v
end

return invModule