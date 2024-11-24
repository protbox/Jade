local jade = require "Jade"
local db = jade.load("data/test.db")

-- get_table returns a JResultSet object
local spells = db:resultset("Spells")
local items = db:resultset("Items")

spells:enumerate(function(row)
    -- is it magic?
    if row.Mana then
        print(row.Label .. " (" .. row.Element .. "): " .. row.Value)
    end
end)

-- fetch a single row
-- you can search for a particular index, or search based on a field and value
-- local da_axe = items:fetch(3)
local da_axe = items:fetch("Label", "Big_Axe")
print(da_axe.Label .. " does " .. da_axe.Value .. " damage")

-- search performs a partial matching search and returns the results
-- as a JResultSet object
local potions = items:search("Label", "_potion")
potions:enumerate(function(row)
    print(row.Label)
end)

local just_health = potions:fetch("Label", "health_potion")
print(just_health.Label .. " heals for " .. just_health.Value .. " HP")

local foo = items:add({ Label = "foo", Type = "yep", Value = 7 })