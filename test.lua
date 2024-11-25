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

local all_tables = db:get_table_names()
for _,name in ipairs(all_tables) do
    print(name)
end
-- write everything to file
--db:sync()

-- create new table with a list of columns
local actor_rs = db:add_table("Actors", { "Label", "Name", "Spells", "Items" })
-- add a new row to the new actors resultset
local new_actor = actor_rs:add({
    Label = "hero_001",
    Name = "Polter the Grand",
    Spells = "1,2,3,4",
    Items = "1,2"
})

-- turn the spells field into a lua table, ie: "1,2,3,4" -> { 1, 2, 3, 4 }
local skills_as_arr = jade.as_array(new_actor.Spells)
print(new_actor.Name .. " has spells:")
for _,spell_id in ipairs(skills_as_arr) do
    -- fetch row with index spell_id from the spells table
    local spell = spells:fetch(spell_id)
    if spell then
        print(spell.Label)
    end
end