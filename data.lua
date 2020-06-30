local HighlyDerivative = require('__HighlyDerivative__/library')
local rusty_locale = require("__rusty-locale__.locale")
local rusty_icons = require("__rusty-locale__.icons")
local ornodes = require("__OR-Nodes__/library").init()

local locale_of = rusty_locale.of
local icons_of = rusty_icons.of
local depend_on_all_recipe_ingredients = ornodes.depend_on_all_recipe_ingredients
local depend_on_item = ornodes.depend_on_item

local MOD_NAME = 'LoadedTurrets'
local PREFIX = MOD_NAME .. '-'
local FLUID_PER_BARREL = 50
local ENERGY_PER_EMPTY = 0.2

local HAVE_UNITURRET = mods['uniturret']

local function autovivify(table, key)
  local foo = table[key]
  if not foo then
    foo = {}
    table[key] = foo
  end
  return foo
end

local function add_to_technology(recipe, turret_item_name, ammo_name, ammo_type)
  local technologies = depend_on_all_recipe_ingredients(recipe, true)
  if not technologies then
    log(string.format("Couldn't determine technology to unlock filling %s with %s, so going with a best-effort guess.", turret_item_name, ammo_name))
    log("Trying to add recipe to technology for " .. turret_item_name)
    technologies = depend_on_item(turret_item_name, 'item', true)
    if not technologies or #technologies == 0 then
      log("Trying to add recipe to technology for " .. ammo_name)
      technologies = depend_on_item(ammo_name, ammo_type, true)
      if not technologies then return end
    end
  end

  -- recipe can be unlocked from the start.
  if #technologies == 0 then return end

  -- recipe needs to be unlocked by research
  recipe.enabled = false

  local technology = data.raw.technology[technologies[1]]

  local recipe_name = recipe.name

  local function add_recipe_to(tech)
    local effects = autovivify(tech, 'effects')
    effects[#effects+1] = {
      type = "unlock-recipe",
      recipe = recipe_name
    }
  end

  local normal = technology.normal
  local expensive = technology.expensive
  if normal or expensive then
    if normal then add_recipe_to(normal) end
    if expensive then add_recipe_to(expensive) end
  else
    add_recipe_to(technology)
  end
end

local create_group

function create_group(new_things)
  local filled_turret_name = PREFIX .. "filled-turrets"
  table.insert(new_things,
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
  )
  create_group = function(_) return filled_turret_name end
  return create_group(new_things)
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
  ammo_type,
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

  -- TODO build entity for the benefit of construction robots.

  if not turret_items then
    turret_items = HighlyDerivative.find_items_that_place(turret)
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
    turret_locale = locale_of(turret_locale_target)
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
    ammo_locale = locale_of(ammo)
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

  local ammo_amount
  local barrel_name
  local barrel_count
  local crafting_category = 'crafting'

  if ammo_type == 'item' then
    local inventory_size = turret.inventory_size
    local stack_size = ammo.stack_size or 1
    local ammo_stack_limit = turret.ammo_stack_limit
    if ammo_stack_limit then
      if ammo_stack_limit > stack_size then
        stack_size = ammo_stack_limit
      end
    end
    local automated_ammo_count = turret.automated_ammo_count
    ammo_amount = math.min(automated_ammo_count, stack_size * inventory_size)
  elseif ammo_type == 'fluid' then
    crafting_category = 'crafting-with-fluid'
    local fluid_buffer_size = turret.fluid_buffer_size
    local activation_buffer_ratio = turret.activation_buffer_ratio
    ammo_amount = math.ceil(fluid_buffer_size * math.min(1,activation_buffer_ratio*2))
    local auto_barrel = ammo.auto_barrel
    if not auto_barrel == false then
      barrel_name = ammo_name .. '-barrel'
      barrel_count = math.ceil(ammo_amount / FLUID_PER_BARREL)
      ammo_amount = barrel_count * FLUID_PER_BARREL
    end
  else
    -- shouldn't happen.
    return
  end

  local new_turret_name = HighlyDerivative.derive_name(PREFIX, "turret", turret_name, ammo_type, ammo_name)

  if mods['debugadapter'] then
    log("Creating " .. new_turret_name)
  end

  local subgroup_name = HighlyDerivative.derive_name(PREFIX, "filled-turret", turret_name)

  create_subgroup(new_things, subgroup_name, turret.order)

  -- add these to the recipes for the benefit of add_to_technology
  local icons = util.combine_icons(
    turret_icons,
    ammo_icons,
    {
      scale = 0.5,
      shift = {4,-8}
    }
  )

  local localised_name  = {
    "item-name.loaded-turret",
    turret_locale.name,
    ammo_locale.name
  }

  local localised_description = {
    "item-description.loaded-turret",
    turret_locale.name,
    ammo_locale.name
  }

  local fast_replaceable_group = turret.fast_replaceable_group
  if not fast_replaceable_group then
    fast_replaceable_group = turret_name
    turret.fast_replaceable_group = fast_replaceable_group
  end

  local new_turret = table.deepcopy(turret)
  new_turret.name = new_turret_name
  new_turret.localised_name = localised_name
  new_turret.localised_description = localised_description
  new_turret.icons = icons
  new_turret.icon = nil
  new_turret.icon_size = nil
  new_turret.icon_mipmaps = nil
  new_turret.placeable_by = nil
  new_turret.minable = {
    mining_time = 0,
    result = new_turret_name
  }

  -- store the name of the original turret in next_upgrade so we can get at it in control.
  new_turret.next_upgrade = turret_name

  do
    local new_turret_flags = new_turret.flags
    for i = 1,#new_turret_flags do
      local flag = new_turret_flags[i]
      if flag == 'not-upgradable' then
        new_turret_flags[i] = new_turret_flags[#new_turret_flags]
        new_turret_flags[#new_turret_flags] = nil
        goto found_flag
      end
    end
    ::found_flag::
  end

  table.insert(new_things, new_turret)



  local new_item = {
    type = "item",
    name = new_turret_name,
    localised_name = localised_name,
    localised_description = localised_description,
    icons = icons,
    subgroup = subgroup_name,
    order = ammo.order,
    place_result = new_turret_name,
    stack_size = 1
  }
  HighlyDerivative.mark_final(new_item)
  table.insert(new_things, new_item)

  local stack_sizes = {}

  for _, turret_item_data in pairs(turret_items) do
    local turret_item = turret_item_data[1]
    local turret_item_count = turret_item_data[2]
    local turret_item_name = turret_item.name

    local recipe_name = HighlyDerivative.derive_name(PREFIX, "recipe", turret_name, ammo_type, ammo_name, turret_item_name)

    local turret_item_ingredient = {
      type = 'item',
      name = turret_item_name,
      amount = turret_item_count,
      catalyst_amount = turret_item_count
    }

    local turret_result = {
      type = 'item',
      name = new_turret_name,
      amount = 1,
      catalyst_amount = 1
    }

    local new_recipe = {
      type = "recipe",
      name = recipe_name,
      localised_name = localised_name,
      localised_description = localised_description,
      icons = icons,
      ingredients = {
        turret_item_ingredient,
        {
          type = ammo_type,
          name = ammo_name,
          amount = ammo_amount,
          catalyst_amount = ammo_amount
        }
      },
      results = { turret_result },
      main_product = new_turret_name,
      category = crafting_category
    }
    table.insert(new_things, new_recipe)
    add_to_technology(new_recipe, turret_item_name, ammo_name, ammo_type)

    if barrel_count then
      local barrel_recipe_name = HighlyDerivative.derive_name(PREFIX, "recipe", turret_name, 'item', barrel_name, turret_item_name)

      local barrel_recipe = {
        type = "recipe",
        name = barrel_recipe_name,
        localised_name = localised_name,
        localised_description = localised_description,
        icons = icons,
        ingredients = {
          turret_item_ingredient,
          {
            type = 'item',
            name = barrel_name,
            amount = barrel_count,
            catalyst_amount = barrel_count
          }
        },
        results = {
          turret_result,
          {
            type = 'item',
            name = "empty-barrel",
            amount = barrel_count,
            catalyst_amount = barrel_count
          }
        },
        energy_required = 0.5 + ENERGY_PER_EMPTY * barrel_count,
        main_product = new_turret_name,
        category = crafting_category
      }
      table.insert(new_things, barrel_recipe)
      add_to_technology(barrel_recipe, turret_item_name, barrel_name, 'item')
    end

    stack_sizes[#stack_sizes+1] = math.max(
      math.floor((turret_item.stack_size) / turret_item_count),
      1
    )
  end

  -- be friendly and pick the largest stack size.
  new_item.stack_size = math.max(table.unpack(stack_sizes))
end

local AmmoList = {}
local AmmoTurretList = {}
local ArtilleryTurretList = {}

local function derive_ammo(new_things, ammo, ammo_name)
  if not HighlyDerivative.can_be_made(ammo) then return end

  local ammo_type = ammo.ammo_type
  if not ammo_type then return end

  local ammo_category = ammo_type.category
  if not ammo_category then return end

  local ammo_locale = locale_of(ammo)
  if not ammo_locale then return end

  local ammo_icons = icons_of(ammo, true)
  if not ammo_icons then return end

  local ammo_list = autovivify(AmmoList, ammo_category)
  ammo_list[#ammo_list + 1] = ammo_name

  local turret_list = AmmoTurretList[ammo_category]
  if turret_list then
    local data_raw_ammo_turret = data.raw['ammo-turret']

    for _, turret_name in ipairs(turret_list) do
      local turret = data_raw_ammo_turret[turret_name]
      if not turret then
        error("Someone deleted ammo-turret." .. turret_name .. "!")
      end
      derive_from_turret_and_ammo(
        new_things,
        'item',
        ammo,
        ammo_locale,
        ammo_icons,
        turret
      )
    end
  end

  turret_list = ArtilleryTurretList[ammo_category]
  if turret_list then
    local data_raw_artillery_turret = data.raw['artillery-turret']

    for _, turret_name in ipairs(turret_list) do
      local turret = data_raw_artillery_turret[turret_name]
      if not turret then
        error("Someone deleted artillery-turret." .. turret_name .. "!")
      end
      derive_from_turret_and_ammo(
        new_things,
        'item',
        turret,
        ammo,
        ammo_locale,
        ammo_icons
      )
    end
  end
end

local function derive_ammo_turret(new_things, turret, turret_name)
  if HAVE_UNITURRET and turret_name:sub(1,9) == 'uniturret' then
    -- uniturrets can't be created directly, instead the item places a 1-stack chest, you fill that with ammo, and then the actual turret is created based on the ammo you supplied.
    if turret_name:sub(-6) == 'locked' then return end
  else
    if not HighlyDerivative.can_be_made(turret) then return end
  end

  local ammo_count = turret.automated_ammo_count
  if not ammo_count then return end

  local attack_parameters = turret.attack_parameters
  if not attack_parameters then return end

  local ammo_category = attack_parameters.ammo_category
  if not ammo_category then return end

  local turret_items = HighlyDerivative.find_items_that_place(turret)
  if not next(turret_items) then return end

  local locale_target
  if #turret_items == 1 then
    locale_target = turret_items[1][1]
  else
    locale_target = turret
  end

  local turret_locale = locale_of(locale_target)
  if not turret_locale then return end

  local turret_icons = icons_of(locale_target, true)
  if not turret_icons then return end

  local turret_list = autovivify(AmmoTurretList, ammo_category)
  turret_list[#turret_list+1] = turret_name

  local ammo_list = autovivify(AmmoList, ammo_category)

  local data_raw_ammo = data.raw['ammo']

  for _, ammo_name in ipairs(ammo_list) do
    local ammo = data_raw_ammo[ammo_name]
    if not ammo then
      error("Some mod deleted ammo." .. ammo_name .. "!")
    end
    derive_from_turret_and_ammo(
      new_things,
      'item',
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

local function derive_artillery_turet(new_things, turret, turret_name)
  if not HighlyDerivative.can_be_made(turret) then return end

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

  local turret_items = HighlyDerivative.find_items_that_place(turret)
  if not next(turret_items) then return end

  local locale_target
  if #turret_items == 1 then
    locale_target = turret_items[1][1]
  else
    locale_target = turret
  end

  local turret_locale = locale_of(locale_target)
  if not turret_locale then return end

  local turret_icons = icons_of(locale_target, true)
  if not turret_icons then return end

  local turret_list = autovivify(ArtilleryTurretList, ammo_category)
  turret_list[#turret_list+1] = turret_name

  local ammo_list = autovivify(AmmoList, ammo_category)

  local data_raw_ammo = data.raw['ammo']

  for _, ammo_name in ipairs(ammo_list) do
    local ammo = data_raw_ammo[ammo_name]
    if not ammo then
      error("Some mod deleted ammo." .. ammo_name .. "!")
    end
    derive_from_turret_and_ammo(
      new_things,
      'item',
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

local FluidTurretList = {}

local function derive_fluid_turret(new_things, turret, turret_name)
  if not HighlyDerivative.can_be_made(turret) then return end

  local attack_parameters = turret.attack_parameters
  if not attack_parameters then return end

  local fluids = attack_parameters.fluids
  if not fluids then return end

  local fluid_buffer_size = turret.fluid_buffer_size
  if not fluid_buffer_size then return end

  local activation_buffer_ratio = turret.activation_buffer_ratio
  if not activation_buffer_ratio then return end

  local turret_items = HighlyDerivative.find_items_that_place(turret)
  if not next(turret_items) then return end

  local locale_target
  if #turret_items == 1 then
    locale_target = turret_items[1][1]
  else
    locale_target = turret
  end

  local turret_locale = locale_of(locale_target)
  if not turret_locale then return end

  local turret_icons = icons_of(locale_target, true)
  if not turret_icons then return end

  local data_raw_fluid = data.raw['fluid']

  for _, fluid_data in pairs(fluids) do
    local fluid_name = fluid_data.type
    local turret_list = autovivify(FluidTurretList, fluid_name)
    turret_list[#turret_list+1] = turret_name

    local fluid = data_raw_fluid[fluid_name]
    if not fluid then
      log("fluid." .. fluid_name .. " doesn't exist (yet), hopefully it will be defined later...")
      goto next_fluid
    end

    derive_from_turret_and_ammo(
      new_things,
      'fluid',
      fluid,
      nil,
      nil,
      turret,
      turret_items,
      turret_locale,
      turret_icons
    )
    ::next_fluid::
  end
end

local function derive_fluid(new_things, fluid, fluid_name)
  local turret_list = FluidTurretList[fluid_name]
  if not turret_list then return end

  local fluid_locale = locale_of(fluid)
  if not fluid_locale then return end

  local fluid_icons = icons_of(fluid, true)
  if not fluid_icons then return end

  local data_raw_fluid_turret = data.raw['fluid-turret']

  for _, turret_name in ipairs(turret_list) do
    local turret = data_raw_fluid_turret[turret_name]
    if not turret then
      error("Some mod deleted fluid-turret." .. turret_name .. "!")
    end
    derive_from_turret_and_ammo(
      new_things,
      'fluid',
      fluid,
      fluid_locale,
      fluid_icons,
      turret,
      nil,
      nil,
      nil
    )
  end
end

HighlyDerivative.register_derivation('ammo', derive_ammo)
HighlyDerivative.register_derivation('ammo-turret', derive_ammo_turret)
HighlyDerivative.register_derivation('artillery-turret', derive_artillery_turet)
HighlyDerivative.register_derivation('fluid', derive_fluid)
HighlyDerivative.register_derivation('fluid-turret', derive_fluid_turret)
