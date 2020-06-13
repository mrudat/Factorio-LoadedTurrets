local hd = require('__HighlyDerivative__/library')
local rusty_locale = require("__rusty-locale__.locale")
local rusty_icons = require("__rusty-locale__.icons")

local locale_of = rusty_locale.of
local icons_of = rusty_icons.of

local MOD_NAME = 'LoadedTurrets'
local PREFIX = MOD_NAME .. '-'
local PREFIX_LENGTH = PREFIX:len()

local function autovivify(table, key)
  local foo = table[key]
  if not foo then
    foo = {}
    table[key] = foo
  end
  return foo
end

local create_group

function create_group(new_things)
  local filled_turret_name = hd.derive_name(PREFIX, "filled-turrets")
  table.insert(new_things,{
    {
      type = "item-group",
      name = filled_turret_name,
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
  create_group = function() return filled_turret_name end
  return create_group()
end

local function create_subgroup(new_things, subgroup_name, order)
  if data.raw['item-subgroup'][subgroup_name] then return end
  local new_subgroup = {
    type = "item-subgroup",
    name = subgroup_name,
    group = create_group(new_things),
    order = order
  }
  table.insert(new_things, new_subgroup)
end

local function derive_from_turret_and_ammo(
  new_things,
  ammo,
  ammo_locale,
  ammo_icons,
  turret,
  turret_items,
  turret_locale,
  turret_icons
)
  local turret_name = turret.name

  local ammo_name = ammo.name

  if not turret_items then
    turret_items = hd.find_items_that_place(turret)
    if not next(turret_items) then
      log("Can no longer find items that place " .. turret_name)
      return
    end
  end

  local turret_locale_target

  local function set_locale_target()
    if #turret_items == 1 then
      turret_locale_target = turret_items[1][1]
    else
      turret_locale_target = turret
    end
  end

  if not turret_locale then
    set_locale_target()
    turret_locale = locale_of(turret_locale_target, true)
    if not turret_locale then
      log("Can no longer find the name of " .. turret_name)
      return
    end
  end

  if not turret_icons then
    set_locale_target()
    turret_icons = icons_of(turret_locale_target, true)
    if not turret_icons then
      log("Can no longer find the icons of " .. turret_name)
      return
    end
  end

  if not ammo_locale then
    ammo_locale = locale_of(ammo, true)
    if not ammo_locale then
      log("Can no longer find the name of " .. ammo_name)
      return
    end
  end

  if not ammo_icons then
    ammo_icons = icons_of(ammo, true)
    if not ammo_icons then
      log("Can no longer find the icons of " .. ammo_name)
      return
    end
  end

  log("Could derive new thing from " .. turret_name .. " and " .. ammo_name)

  local ammo_amount = math.min(turret.automated_ammo_count, ammo.stack_size or 1)

  local new_item_name = hd.derive_name(PREFIX, "turret", turret_name, ammo_name)

  local subgroup_name = hd.derive_name(PREFIX, "filled-turret", turret_name)

  create_subgroup(new_things, subgroup_name, turret.order)

  local stack_sizes = {}

  for _, turret_item_data in pairs(turret_items) do
    local turret_item = turret_item_data[1]
    local turret_item_count = turret_item_data[2]
    local turret_item_name = turret_item.name

    local recipe_name = hd.derive_name(PREFIX, "recipe", turret_name, ammo_name, turret_item_name)

    local new_recipe = {
      type = "recipe",
      name = recipe_name,
      ingredients = {
        { turret_item_name, turret_item_count },
        { ammo_name, ammo_amount },
      },
      result = new_item_name
    }

    stack_sizes[#stack_sizes+1] = math.max(
      math.floor((turret_item.stack_size) / turret_item_count),
      1
    )

    table.insert(new_things, new_recipe)
  end

  -- be friendly and pick the largest stack size.
  local stack_size = math.max(table.unpack(stack_sizes))

  local new_item = {
    type = "item",
    name = new_item_name,
    localised_name = {
      "item-name.loaded-turret",
      turret_locale.name,
      ammo_locale.name
    },
    localised_description = {
      "item-description.loaded-turret",
      turret_locale.name,
      ammo_locale.name
    },
    icons = util.combine_icons(
      turret_icons,
      ammo_icons,
      {
        scale = 0.5,
        shift = {4,-8}
      }
    ),
    subgroup = subgroup_name,
    order = ammo.order,
    place_result = turret_name,
    stack_size = stack_size
  }
  hd.mark_final(new_item)
  table.insert(new_things, new_item)
end

local AmmoList = {}
local AmmoTurretList = {}
local ArtilleryTurretList = {}

hd.register_derivation('ammo', function(new_things, ammo, ammo_name)
  local ammo_type = ammo.ammo_type
  if not ammo_type then return end

  local ammo_category = ammo_type.category
  if not ammo_category then return end

  local ammo_locale = locale_of(ammo, true)
  if not ammo_locale then return end

  local ammo_icons = icons_of(ammo, true)
  if not ammo_icons then return end

  local ammo_list = autovivify(AmmoList, ammo_category)
  ammo_list[#ammo_list + 1] = ammo_name

  local turret_list = autovivify(AmmoTurretList, ammo_category)

  local data_raw_ammo_turret = data.raw['ammo-turret']

  for _, turret_name in ipairs(turret_list) do
    local turret = data_raw_ammo_turret[turret_name]
    derive_from_turret_and_ammo(
      new_things,
      turret,
      ammo,
      ammo_locale,
      ammo_icons
    )
  end
end)

hd.register_derivation('ammo-turret', function(new_things, turret, turret_name)
  local ammo_count = turret.automated_ammo_count
  if not ammo_count then return end

  local attack_parameters = turret.attack_parameters
  if not attack_parameters then return end

  local ammo_category = attack_parameters.ammo_category
  if not ammo_category then return end

  local turret_items = hd.find_items_that_place(turret)
  if not next(turret_items) then return end

  local locale_target
  if #turret_items == 1 then
    locale_target = turret_items[1]
  else
    locale_target = turret
  end

  local turret_locale = locale_of(locale_target, true)
  if not turret_locale then return end

  local turret_icons = icons_of(locale_target, true)
  if not turret_icons then return end

  local turret_list = autovivify(AmmoTurretList, ammo_category)
  turret_list[#turret_list+1] = turret_name

  local ammo_list = autovivify(AmmoList, ammo_category)

  local data_raw_ammo = data.raw['ammo']

  for _, ammo_name in ipairs(ammo_list) do
    local ammo = data_raw_ammo[ammo_name]
    derive_from_turret_and_ammo(
      new_things,
      ammo,
      nil,
      nil,
      turret,
      turret_items,
      turret_locale,
      turret_icons
    )
  end
end)

hd.register_derivation('artillery-turret', function(new_things, turret, turret_name)
  local ammo_count = turret.automated_ammo_count
  if not ammo_count then return end

  local gun = turret.gun
  if not gun then return end

  gun = data.raw.gun[gun]
  if not gun then return end

  local attack_parameters = gun.attack_parameters
  if not attack_parameters then return end

  local ammo_category = attack_parameters.ammo_category
  if not ammo_category then return end

  local turret_items = hd.find_items_that_place(turret)
  if not next(turret_items) then return end

  local locale_target
  if #turret_items == 1 then
    locale_target = turret_items[1]
  else
    locale_target = turret
  end

  local turret_locale = locale_of(locale_target, true)
  if not turret_locale then return end

  local turret_icons = icons_of(locale_target, true)
  if not turret_icons then return end

  local turret_list = autovivify(ArtilleryTurretList, ammo_category)
  turret_list[#turret_list+1] = turret_name

  local ammo_list = autovivify(AmmoList, ammo_category)

  local data_raw_ammo = data.raw['ammo']

  for _, ammo_name in ipairs(ammo_list) do
    local ammo = data_raw_ammo[ammo_name]
    derive_from_turret_and_ammo(
      new_things,
      ammo,
      nil,
      nil,
      turret,
      turret_items,
      turret_locale,
      turret_icons
    )
  end
end)

local FluidTurretList = {}
local FluidList = {}

local foo
hd.register_derivation('fluid-turret', function(new_things, turret, turret_name)
  if not foo then return end
  local ammo_count = turret.automated_ammo_count
  if not ammo_count then return end

  local attack_parameters = turret.attack_parameters
  if not attack_parameters then return end

  local fluids = attack_parameters.fluids
  if not fluids then return end

  local turret_items = hd.find_items_that_place(turret)
  if not next(turret_items) then return end

  local locale_target
  if #turret_items == 1 then
    locale_target = turret_items[1]
  else
    locale_target = turret
  end

  local turret_locale = locale_of(locale_target, true)
  if not turret_locale then return end

  local turret_icons = icons_of(locale_target, true)
  if not turret_icons then return end

  for _, fluid in pairs(fluids) do
    local turret_list = autovivify(FluidTurretList, fluid)
    turret_list[#turret_list+1] = turret_name

    local fluid_list = autovivify(FluidList, fluid)

    local data_raw_fluid = data.raw['fluid']

    for _, fluid_name in ipairs(fluid_list) do
      local ammo = data_raw_fluid[fluid_name]
      -- TODO
      derive_from_turret_and_ammo(
        new_things,
        ammo,
        nil,
        nil,
        turret,
        turret_items,
        turret_locale,
        turret_icons
      )
    end
  end
end)
-- TODO fluid-turret

hd.derive()
