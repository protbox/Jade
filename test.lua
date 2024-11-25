local jade = require "Jade"
-- passing true to load will convert all underscores to spaces
-- with the exception of the Label field, as this is used as a primary key
local db = jade.load("data/test.db", true)

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
print(da_axe.Name .. " does " .. da_axe.Value .. " damage")

-- search performs a partial matching search and returns the results
-- as a JResultSet object
local potions = items:search("Label", "_potion")
potions:enumerate(function(row)
    print(row.Label)
end)

local just_health = potions:fetch("Label", "health_potion")
print(just_health.Name .. " heals for " .. just_health.Value .. " HP")

local foo = items:add({ Label = "foo nugget", Type = "something", Name = "Lil' Foo Nugget", Value = 7 })
print(foo.Label .. ": " .. foo.Name)

-- add a whole new table
-- returns a JResultSet
local new_tbl = db:add_table("Test", { "Label", "Name" })
-- add some rows to our new table
new_tbl:add({ Label = "foo_bar", Name = "Foo to the bar" })
-- count should return 1
print(new_tbl:count())

-- write everything to file
--db:sync()
