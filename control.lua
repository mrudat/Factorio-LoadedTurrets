local ERROR_COLOR = {r=1}
local WARNING_COLOR = {r=1,g=0.749}

local function autovivify(table, key)
  local foo = table[key]
  if not foo then
    foo = {}
    table[key] = foo
  end
  return foo
end

local TurretLookup
local EntitiesToWatch

-- TODO only consider turrets that when placed can be be upgraded.
local function build_turret_lookup()
  local ammo_ingredient_filter = {
    filter = "has-ingredient-item",
    mode = "and",
    elem_filters = {{ filter = "type", type = "ammo" }}
  }

  local fluid_turret_filter = {
    filter = "has-product-item",
    mode = "or",
    elem_filters = {
      {
        filter = "place-result",
        elem_filters = {{ filter = "type", type = "fluid-turret" }}
      }
    }
  }

  local recipe_filters = {
    {
      filter = "has-product-item",
      elem_filters = {
        {
          filter = "place-result",
          elem_filters = {{ filter = "type", type = "ammo-turret" }}
        }
      }
    },
    ammo_ingredient_filter,

    {
      filter = "has-product-item",
      mode = "or",
      elem_filters = {
        {
          filter = "place-result",
          elem_filters = {{ filter = "type", type = "artillery-turret" }}
        }
      }
    },
    ammo_ingredient_filter,

    fluid_turret_filter,
    {
      filter = "has-ingredient-fluid",
      mode = "and"
    },

    fluid_turret_filter,
    {
      filter = "has-ingredient-item",
      mode = "and",
      elem_filters = {{ filter = "type", type = "item" }}
    }
  }

  local barrel_name_to_barrel_data
  local function build_barrel_name_to_barrel_data()
    local barrel_recipe_filters = {
      { filter = "has-ingredient-fluid" },
      { filter = "has-ingredient-item", mode = "and" },
      { filter = "has-product-item", mode = "and" },
      { filter = "has-product-fluid", mode = "and", invert = true },

      { filter = "has-product-fluid", mode = "or" },
      { filter = "has-product-item", mode = "and", },
      { filter = "has-ingredient-item", mode = "and" },
      { filter = "has-ingredient-fluid", mode = "and", invert = true }
    }

    local recipes = game.get_filtered_recipe_prototypes(barrel_recipe_filters)

    barrel_name_to_barrel_data = {}

    for recipe_name, recipe in pairs(recipes) do
      local ingredients = recipe.ingredients
      local products = recipe.products
      local ingredient_count = #ingredients
      local product_count = #products

      local full_barrel
      local fluid
      local empty_barrel
      local direction

      if ingredient_count == 1 and product_count == 2 then
        local ingredient = ingredients[1]
        if ingredient.type ~= "item" then goto next_recipe end
        full_barrel = ingredient
        for _,result in ipairs(products) do
          if result.type == "fluid" then
            fluid = result
          else
            empty_barrel = result
          end
        end
        direction = 'empty'
      elseif ingredient_count == 2 and product_count == 1 then
        local result = products[1]
        if result.type ~= "item" then goto next_recipe end
        full_barrel = result
        for _,ingredient in ipairs(ingredients) do
          local ingredient_type = ingredient.type
          if ingredient_type == "fluid" then
            fluid = ingredient
          else
            empty_barrel = ingredient
          end
        end
        direction = 'fill'
      end

      if not full_barrel then goto next_recipe end
      if not fluid then goto next_recipe end
      if not empty_barrel then goto next_recipe end

      local fluid_amount = fluid.amount
      if not fluid_amount then goto next_recipe end

      local barrel_amount = full_barrel.amount
      if not barrel_amount then goto next_recipe end

      local empty_barrel_amount = empty_barrel.amount
      if not empty_barrel_amount then goto next_recipe end

      if barrel_amount ~= empty_barrel_amount then goto next_recipe end

      local barrel_data = autovivify(barrel_name_to_barrel_data, full_barrel.name)
      if barrel_data.not_a_barrel then goto next_recipe end

      local fluid_per_barrel = fluid_amount / barrel_amount
      local empty_barrel_name = empty_barrel.name

      local old_fluid_per_barrel = barrel_data.fluid_per_barrel
      if old_fluid_per_barrel then
        if old_fluid_per_barrel ~= fluid_per_barrel then
          barrel_data.not_a_barrel = true
          goto next_recipe
        end
      end

      local old_empty_barrel = barrel_data.empty_barrel
      if old_empty_barrel then
        if old_empty_barrel ~= empty_barrel_name then
          barrel_data.not_a_barrel = true
          goto next_recipe
        end
      end

      barrel_data.fluid_name = fluid.name
      barrel_data.fluid_per_barrel = fluid_per_barrel
      barrel_data.empty_barrel = empty_barrel_name

      local recipe_name_list = autovivify(barrel_data, direction)

      recipe_name_list[#recipe_name_list+1] = recipe_name

      ::next_recipe::
    end

    for barrel_name, barrel_data in pairs(barrel_name_to_barrel_data) do
      if barrel_data.not_a_barrel then
        barrel_name_to_barrel_data[barrel_name] = nil
      end
      if not barrel_data.fill or not barrel_data.empty then
        barrel_name_to_barrel_data[barrel_name] = nil
      end
    end
  end

  local recipes = game.get_filtered_recipe_prototypes(recipe_filters)

  local item_name_to_turret = {}
  local item_name_to_ammo = {}
  local fluid_name_to_fluid = {}

  local game_item_prototypes = game.item_prototypes
  local game_fluid_prototypes = game.fluid_prototypes

  for _, recipe in pairs(recipes) do
    local product = recipe.main_product
    if product.type ~= 'item' then
      goto next_recipe
    end

    local created_turret_item_count = product.amount
    if not created_turret_item_count then
      created_turret_item_count = product.probability * ((product.amount_min + product.amount_max) / 2)
    end
    -- Boldly assume that an effective amount < 1.0 is a chance of failure
    if created_turret_item_count < 1 then created_turret_item_count = 1 end

    -- the is should be name of the item that places turret.
    local turret_item_name = product.name

    local turret = item_name_to_turret[turret_item_name]
    if not turret then
      if turret == false then goto next_recipe end
      turret = game_item_prototypes[turret_item_name]
      if not turret then
        item_name_to_turret[turret_item_name] = false
        goto next_recipe
      end
      turret = turret.place_result
      if not turret then
        item_name_to_turret[turret_item_name] = false
        goto next_recipe
      end
      item_name_to_turret[turret_item_name] = turret
    end

    local real_turret = turret.next_upgrade
    if not real_turret then goto next_recipe end

    local turret_name = turret.name
    local turret_type = turret.type

    if turret_type == 'ammo-turret' or turret_type == 'artillery-turret' then
      -- there should be exactly two ingredients; the turret and the ammo
      local ingredients = recipe.ingredients
      local ammo_amount
      local ammo_name
      local ammo
      local found_ammo = 0
      for _, ingredient in ipairs(ingredients) do
        local ingredient_type = ingredient.type
        if ingredient_type ~= 'item' then goto next_ingredient end

        local item_name = ingredient.name
        local item
        item = item_name_to_ammo[item_name]
        if not item then
          if item == false then goto next_ingredient end
          item = game_item_prototypes[item_name]
          if not item then
            item_name_to_ammo[item_name] = false
            goto next_ingredient
          end
          if item.type ~= 'ammo' then
            item_name_to_ammo[item_name] = false
            goto next_ingredient
          end
          item_name_to_ammo[item_name] = item
        end

        ammo_name = item_name
        ammo = item

        ammo_amount = ingredient.amount
        found_ammo = found_ammo + 1
        ::next_ingredient::
      end

      if found_ammo ~= 1 then
        -- no ammo? not touching this one.
        -- two ammo ingredients for the one turret? not touching this one.
        goto next_recipe
      end

      local ammo_per_turret = ammo_amount / created_turret_item_count
      local ammo_per_turret_ceil = math.ceil(ammo_per_turret)
      if ammo_per_turret_ceil ~= ammo_per_turret then
        game.print(
          {
            "LoadedTurrets.adjusted-recipe",
            ammo_per_turret_ceil,
            ammo.localised_name,
            turret.localised_name,
            ammo_per_turret,
            recipe.localised_name
          },
          WARNING_COLOR
        )
        ammo_per_turret = ammo_per_turret_ceil
      end

      EntitiesToWatch[turret_name] = true

      TurretLookup[turret_name] = {
        name = ammo_name,
        count = ammo_per_turret,
        real_turret_name = real_turret.name
      }
    elseif turret_type == 'fluid-turret' then
      -- there should be exactly two ingredients; the turret and the ammo
      if not barrel_name_to_barrel_data then
        build_barrel_name_to_barrel_data()
      end
      local ingredients = recipe.ingredients
      local ammo_fluid_name
      local fluid_amount
      local found_ammo = 0
      for _, ingredient in ipairs(ingredients) do
        local ingredient_type = ingredient.type
        if ingredient_type == 'fluid' then
          local fluid
          local fluid_name
          fluid_name = ingredient.name
          fluid = fluid_name_to_fluid[fluid_name]
          if not fluid then
            if fluid == false then goto next_ingredient end
            fluid = game_fluid_prototypes[fluid_name]
            if not fluid then
              fluid_name_to_fluid[fluid_name] = false
              goto next_ingredient
            end
            fluid_name_to_fluid[fluid_name] = fluid
          end

          ammo_fluid_name = fluid_name
          fluid_amount = ingredient.amount

          found_ammo = found_ammo + 1
        else
          local barrel_name = ingredient.name
          local barrel_data = barrel_name_to_barrel_data[barrel_name]
          if not barrel_data then goto next_ingredient end

          ammo_fluid_name = barrel_data.fluid_name
          fluid_amount = barrel_data.fluid_amount * ingredient.count

          found_ammo = found_ammo + 1
        end
        ::next_ingredient::
      end

      if found_ammo ~= 1 then
        -- no ammo? not touching this one.
        -- two ammo ingredients for the one turret? not touching this one.
        goto next_recipe
      end

      local fluid_per_turret = fluid_amount / created_turret_item_count

      EntitiesToWatch[turret_name] = true

      TurretLookup[turret_name] = {
        name = ammo_fluid_name,
        amount = fluid_per_turret,
        real_turret_name = real_turret.name
      }
    end

    ::next_recipe::
  end
end

local defines_inventory_turret_ammo = defines.inventory.turret_ammo

local function new_turret(fake_turret)
--  local entity = event.created_entity
  local force = fake_turret.force

  local fake_turret_name = fake_turret.name

  local turret_data = TurretLookup[fake_turret_name]
  if not turret_data then return end

  local real_turret_name = turret_data.real_turret_name

  local surface = fake_turret.surface

  local position = fake_turret.position
  local direction = fake_turret.direction
  local player = fake_turret.last_user

  local real_turret = surface.create_entity{
    name = real_turret_name,
    position = position,
    direction = direction,
    force = force,
    player = player,
    -- fast_replace = false,
    raise_built = true,
    create_build_effect_smoke = false
  }

  if not real_turret then
    error("Couldn't replace " .. fake_turret_name .. " with " .. real_turret_name .. "!")
  end

  -- TODO don't count building fake_turret, instead count real_turret?
  --[[
  local flow_stats = force.entity_build_count_statistics
  local buildings_constructed = flow_stats.input_counts
  buildings_constructed[fake_turret_name] = (buildings_constructed[fake_turret_name] or 0) - 1
  log(buildings_constructed[fake_turret_name])
  flow_stats.on_flow(real_turret_name, 1)
  ]]

  local entity_type = real_turret.type
  if entity_type == 'ammo-turret' or entity_type == 'artillery-turret' then
    local item_count = turret_data.count
    local inventory = real_turret.get_inventory(defines_inventory_turret_ammo)
    if inventory then
      local inserted = inventory.insert(turret_data)
      item_count = item_count - inserted
    end
    if item_count > 0 then -- shouldn't happen for one of ours, but someone else might get the numbers wrong.
      force.print({"LoadedTurrets.turret-full"}, WARNING_COLOR)
      surface.spill_item_stack(
        position,
        {
          name = turret_data.name,
          count = item_count
        },
        nil,
        force,
        false
      )
    end
    local old_inventory = fake_turret.get_inventory(defines_inventory_turret_ammo)
    if old_inventory and not old_inventory.is_empty() then
      old_inventory.sort_and_merge()
      for i = 1,#old_inventory do
        local old_stack = old_inventory[i]
        for j = 1,#inventory do
          local new_stack = inventory[j]
          if new_stack.transfer_stack(old_stack) then
            goto stack_empty
          end
        end
        if old_stack.count > 0 then
          surface.spill_item_stack(
            position,
            old_stack,
            nil,
            force,
            false
          )
        end
        ::stack_empty::
      end
    end
  elseif entity_type == 'fluid-turret' then
    local amount_to_add = turret_data.amount
    local amount_added = real_turret.insert_fluid(turret_data)
    if amount_added < amount_to_add then
      force.print({"LoadedTurrets.fluid-turret-full"}, ERROR_COLOR)
    end

  end
  fake_turret.destroy()
  return real_turret
end

local function turret_built(event)
  event.created_entity = new_turret(event.created_entity)
end

local function turret_built_by_script(event)
  event.entity = new_turret(event.entity)
end

local function turret_cloned(event)
  event.destination = new_turret(event.destination)
end

local function on_load()
  TurretLookup = global.ItemLookup
  EntitiesToWatch = global.EntitiesToWatch

  local entity_filter = {}

  for entity_name in pairs(EntitiesToWatch) do
    entity_filter[#entity_filter+1] = {
      filter = "name",
      name = entity_name
    }
  end

  local defines_events = defines.events

  -- on_built_entity
  script.on_event(defines_events.on_robot_built_entity, turret_built, entity_filter)
  script.on_event(defines_events.on_built_entity, turret_built, entity_filter)
  script.on_event(defines_events.script_raised_built, turret_built_by_script, entity_filter)
  script.on_event(defines_events.script_raised_revive, turret_built_by_script, entity_filter)
  script.on_event(defines_events.on_entity_cloned, turret_cloned, entity_filter)
end

local function on_init()
  global.ItemLookup = {}
  global.EntitiesToWatch = {}
  TurretLookup = global.ItemLookup
  EntitiesToWatch = global.EntitiesToWatch
  build_turret_lookup()
  on_load()
end

-- register handlers

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_init)
