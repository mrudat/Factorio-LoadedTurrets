local hd = require('__HighlyDerivative__/library').derive()

local function validString(str)
    if type(str) == "string" and string.len(str) > 0 then
        return true
    else
        return false
    end
end

local function validNumberGT0(num)
    if type(num) == "number" and num > 0 then
        return true
    else
        return false
    end
end

--https://rosettacode.org/wiki/Greatest_common_divisor#Lua
function gcd(a,b)
	if b ~= 0 then
		return gcd(b, a % b)
	else
		return math.abs(a)
	end
end

--[[
function createRecipeName(turretName, ammoName, amount, recipeType)
    return "filled-turret-"..turretName.."-from-"..recipeType.."-with-"..ammoName.."-"..tostring(amount)
end

function createItemName(turretName, ammoName, amount)
    return "filled-turret-"..turretName.."-with-"..ammoName.."-"..tostring(amount)
end

local function getLocalizedName(turretPrototype, ammoPrototype)
    if ammoPrototype.type == "fluid" then
        return {"item-name.loaded-turret", {"entity-name."..turretPrototype.name}, {"fluid-name."..ammoPrototype.name}}
    else
        return {"item-name.loaded-turret", {"entity-name."..turretPrototype.name}, {"item-name."..ammoPrototype.name}}
    end
end

local function getLocalizedDescription(turretPrototype, ammoPrototype)
    if ammoPrototype.type == "fluid" then
        return {"item-description.loaded-turret", {"entity-name."..turretPrototype.name}, {"fluid-name."..ammoPrototype.name}}
    else
        return {"item-description.loaded-turret", {"entity-name."..turretPrototype.name}, {"item-name."..ammoPrototype.name}}
    end
end

local function getRecipeIcons(turretPrototype, ammoPrototype)
    local icons = {}
    if turretPrototype.icon then
        table.insert(icons, {
              icon = turretPrototype.icon,
              scale = 1.0,
              shift = {0, 0}
            })
    elseif turretPrototype.icons then
        for _,icon in pairs(turretPrototype.icons) do
            table.insert(icons, icon)
        end
    else
        table.insert(icons, {
              icon = "__LoadedTurrets-0_17__/graphics/icons/questionmark.png",
              scale = 1.0,
              shift = {0, 0}
            })
    end
    if ammoPrototype.icon then
        table.insert(icons, {
            icon = ammoPrototype.icon,
            scale = 0.5,
            shift = {4, -8}
        })
    elseif ammoPrototype.icons then
        for _,icon in pairs(ammoPrototype.icons) do
            local scale = 0.5
            if icon.scale then scale = 0.5 * icon.scale end
            local shift = {4, -8}
            if icon.shift then shift = icon.shift end
            table.insert(icons, {
                icon = icon.icon,
                scale = scale,
                shift = shift
            })
        end
    end
    return icons
end
]]

--item: 1 turret + x items as input, 1 loaded turret output
--fluid: 1 turret + x fluid as input, 1 loaded turret output
--barrel: 1 barrel + turrets as input, 1 empty barrel + x loaded turrets output
--[[
local function createItemRecipe(turretPrototype, ammoPrototype, amount)
    data:extend(
    {
        {
            type = "recipe",
            name = createRecipeName(turretPrototype.name, ammoPrototype.name, amount, "item"),
            localised_name = getLocalizedName(turretPrototype, ammoPrototype),
            localised_description = getLocalizedDescription(turretPrototype, ammoPrototype),
            icons = getRecipeIcons(turretPrototype, ammoPrototype),
            icon_size = 32,
            subgroup = "filled-" .. turretPrototype.name,
            enabled = true,
            energy_required = 1,
            category = "crafting",
            ingredients =
            {
                {turretPrototype.name, 1},
                {ammoPrototype.name, amount},
            },
            result = createItemName(turretPrototype.name, ammoPrototype.name, amount)
        }
    })
end
]]

local function createFluidRecipe(turretPrototype, ammoPrototype, amount)
    data:extend(
    {
        {
            type = "recipe",
            name = createRecipeName(turretPrototype.name, ammoPrototype.name, amount, "fluid"),
            localised_name = getLocalizedName(turretPrototype, ammoPrototype),
            localised_description = getLocalizedDescription(turretPrototype, ammoPrototype),
            icons = getRecipeIcons(turretPrototype, ammoPrototype),
            icon_size = 32,
            subgroup = "filled-" .. turretPrototype.name,
            enabled = true,
            energy_required = 1,
            category = "crafting-with-fluid",
            ingredients =
            {
                {turretPrototype.name, 1},
                {type="fluid", name=ammoPrototype.name, amount=amount}
            },
            result = createItemName(turretPrototype.name, ammoPrototype.name, amount)
        }
    })
end

local function createBarrelRecipe(turretPrototype, ammoPrototype, amount)

    local fluid_per_barrel = 50
    local currentGCD = gcd(fluid_per_barrel, amount)
    barrelsPerCraft = amount / currentGCD
    turretsPerCraft = fluid_per_barrel / currentGCD

    data:extend(
    {
        {
            type = "recipe",
            name = createRecipeName(turretPrototype.name, ammoPrototype.name, amount, "barrel"),
            localised_name = getLocalizedName(turretPrototype, ammoPrototype),
            localised_description = getLocalizedDescription(turretPrototype, ammoPrototype),
            icons = getRecipeIcons(turretPrototype, ammoPrototype),
            icon_size = 32,
            subgroup = "filled-" .. turretPrototype.name,
            enabled = true,
            energy_required = 1,
            category = "crafting",
            ingredients =
            {
                {ammoPrototype.name.."-barrel",barrelsPerCraft},
                {turretPrototype.name, turretsPerCraft},
            },
            results =
            {
                {
                    name = createItemName(turretPrototype.name, ammoPrototype.name, amount),
                    amount = turretsPerCraft
                },
                {
                    name = "empty-barrel",
                    amount = barrelsPerCraft
                }
            },
        }
    })
end

--[[
local function createGroupIfNeeded()
    if not data.raw["item-group"]["filled-turrets"] then
        data:extend({
            {
                type = "item-group",
                name = "filled-turrets",
                order = "da",--military is d, sort it after it
                icons = {
                    {
                        icon="__base__/graphics/technology/turrets.png",
                    },
                    {
                        icon="__base__/graphics/technology/physical-projectile-damage-1.png",
                        scale = 0.5,
                        shift = {16, 0}
                    }
                },
                icon_size = 128
            }
        })
    end
end
]]

--[[
local function createSubgroupIfNeeded(turretPrototype)
    createGroupIfNeeded()
    local subgroupName = "filled-" .. turretPrototype.name
    if not data.raw["item-subgroup"][subgroupName] then
        data:extend({
            {
                type = "item-subgroup",
                name = subgroupName,
                group = "filled-turrets",
                order = turretPrototype.order
            }
        })
    end
end
]]

--[[
local function getStacksizeOfFilledItem(turretPrototype)
    --first guess: try to see if an item of same name exists:
    if data.raw.item[turretPrototype.name] and data.raw.item[turretPrototype.name].place_result == turretPrototype.name then return data.raw.item[turretPrototype.name].stack_size end
    --fallback: do not assume that the item that places the turret has the same name as the turret. rather look for one that places the turrent, and take its stacksize.
    for _,item in pairs(data.raw.item) do
        if item.place_result == turretPrototype.name then
            if not item.stack_size or item.stack_size == 0 then return 1 else return item.stack_size end
        end
    end
end
]]

--[[
local function createFilledItem(turretPrototype, ammoPrototype, amount)
    data:extend({
        {
            type = "item",
            name = createItemName(turretPrototype.name, ammoPrototype.name, amount),
            localised_name = getLocalizedName(turretPrototype, ammoPrototype),
            localised_description = getLocalizedDescription(turretPrototype, ammoPrototype),
            icons = getRecipeIcons(turretPrototype, ammoPrototype),
            icon_size = 32,
            flags = {},
            subgroup = "filled-" .. turretPrototype.name,
            order = ammoPrototype.order,
            place_result = turretPrototype.name,
            stack_size = getStacksizeOfFilledItem(turretPrototype)
        }
    })
end
]]

local function AddToTurretTechnology(turretPrototype, ammoPrototype, amount, recipeType)
    local recipeName = createRecipeName(turretPrototype.name, ammoPrototype.name, amount, recipeType)
    local foundOne = false
    for _,tech in pairs(data.raw.technology) do
        if tech.effects then
            local unlocksTurret = false
            for _, effect in pairs(tech.effects) do
                if effect.type == "unlock-recipe" and validString(effect.recipe) then
                    --if it is a recipe which produces the desired turret...
                    if data.raw.recipe[effect.recipe].result == turretPrototype.name then
                        foundOne = true
                        unlocksTurret = true
                    else
                        if data.raw.recipe[effect.recipe].results then
                            for _,res in pairs(data.raw.recipe[effect.recipe].results) do
                                if res.name == turretPrototype.name then
                                    foundOne = true
                                    unlocksTurret = true
                                end
                            end
                        end
                    end
                end
            end
            if unlocksTurret then
                table.insert(tech.effects, {
                    type = "unlock-recipe",
                    recipe = recipeName
                })
            end
        end
    end
    --by default the recipe is enabled. disable it if the turret is not available from the start.
    if foundOne then data.raw.recipe[recipeName].enabled = false end
end

--[[
for _,turret in pairs(data.raw["ammo-turret"]) do
    if turret.attack_parameters and validString(turret.attack_parameters.ammo_category) and validNumberGT0(turret.automated_ammo_count) then
        local ammoCategory = turret.attack_parameters.ammo_category
        for _,ammo in pairs(data.raw.ammo) do
            if ammo.ammo_type and ammo.ammo_type.category == ammoCategory and validNumberGT0(ammo.stack_size) then
                local amountToUse = math.min(turret.automated_ammo_count, ammo.stack_size)
                createItemRecipe(turret, ammo, amountToUse)
                createSubgroupIfNeeded(turret)
                createFilledItem(turret, ammo, amountToUse)
                AddToTurretTechnology(turret, ammo, amountToUse, "item")
            end
        end
    end
end
]]

--[[
for _,turret in pairs(data.raw["artillery-turret"]) do
    if validString(turret.gun) and data.raw.gun[turret.gun] and data.raw.gun[turret.gun].attack_parameters and validString(data.raw.gun[turret.gun].attack_parameters.ammo_category)
    and validNumberGT0(turret.automated_ammo_count) then
        local ammoCategory = data.raw.gun[turret.gun].attack_parameters.ammo_category
        for _,ammo in pairs(data.raw.ammo) do
            if ammo.ammo_type and ammo.ammo_type.category == ammoCategory and validNumberGT0(ammo.stack_size) then
                local amountToUse = math.min(turret.automated_ammo_count, ammo.stack_size)
                createItemRecipe(turret, ammo, amountToUse)
                createSubgroupIfNeeded(turret)
                createFilledItem(turret, ammo, amountToUse)
                AddToTurretTechnology(turret, ammo, amountToUse, "item")
            end
        end
    end
end
]]

for _,turret in pairs(data.raw["fluid-turret"]) do
    if turret.attack_parameters and turret.attack_parameters.fluids then
        for _,fluid in pairs(turret.attack_parameters.fluids) do
            if validString(fluid.type) and data.raw.fluid[fluid.type] then
                --fluid turrets ignore automated_ammo_count. instead use more than fluid_buffer_size*activation_buffer_ratio, otherwise they don't turn on. (equal is not enough)
                --multiplied by 2 for better ratios.
                local amountToUse = math.ceil(turret.fluid_buffer_size*(math.min(1.0, 2*turret.activation_buffer_ratio)))
                createFluidRecipe(turret, data.raw.fluid[fluid.type], amountToUse)
                createBarrelRecipe(turret, data.raw.fluid[fluid.type], amountToUse)
                createSubgroupIfNeeded(turret)
                createFilledItem(turret, data.raw.fluid[fluid.type], amountToUse)
                AddToTurretTechnology(turret, data.raw.fluid[fluid.type], amountToUse, "fluid")
                AddToTurretTechnology(turret, data.raw.fluid[fluid.type], amountToUse, "barrel")
            end
        end
    end
end
