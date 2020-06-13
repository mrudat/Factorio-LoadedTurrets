local function init_globals()

    global.version = "0.1.1"

end

script.on_init(function()
    init_globals()
end)

local function updateModVersion()
    --nothing to update yet
end

script.on_configuration_changed(function()
    updateModVersion()
end)

local function checkCreatedEntity(entity, playerBuild, playerIndex, robot, itemStack, tick)

    local fillPrefixString = "filled-turret-"..entity.name.."-with-"

    if not itemStack then return end
    if not itemStack.valid then return end
    if not itemStack.valid_for_read then return end

    if string.sub(itemStack.prototype.name, 1, #fillPrefixString) == fillPrefixString then
        local nameAndAmount = string.sub(itemStack.prototype.name,#fillPrefixString + 1)
        local seperatorPos = string.find(nameAndAmount, "-[^-]*$")
        local name = string.sub(nameAndAmount,1,seperatorPos-1)
        local amount = tonumber(string.sub(nameAndAmount,seperatorPos+1))
        if name and amount and string.len(name) > 0 and amount > 0 then
            if (entity.type == "ammo-turret" or entity.type == "artillery-turret") and entity.get_inventory(defines.inventory.turret_ammo) then
                entity.get_inventory(defines.inventory.turret_ammo).insert({name=name, count=amount})
            end
            if entity.type == "fluid-turret" and #entity.fluidbox > 0 then
                for i = 1,#entity.fluidbox do
                    entity.fluidbox[i] = {name=name, amount=amount/#entity.fluidbox}
                end
            end
        end
    end
end

script.on_event(defines.events.on_built_entity, function(event)
    checkCreatedEntity(event.created_entity, true, event.player_index, nil, event.stack, event.tick)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    checkCreatedEntity(event.created_entity, false, nil, event.robot, event.stack, event.tick)
end)
