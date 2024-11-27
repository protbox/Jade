local jade = require "Jade"
local db = jade.load("data/test.db")

-- grab the People table and return a ResultSet
local people = db:resultset("People")

-- add a new row
people:add({ Label = "person_02", Name = "Princess Peach", Town = "Mushroom Kingdom", Loves = "Link"})

-- fetch the row where Label = person_02 and print their name
print(people:fetch("person_02").Name)

-- add a new row
people:add({ Label = "person_03", Name = "Link", Town = "Kokori Forest"})

-- loop through the People table
people:enumerate(function(row)
    print(row.Label .. ": " .. row.Name .. " is from " .. row.Town)
end)

-- add a new table
-- Label is already created, but it's fine if you pass it as a field too
local powerups = db:add_table("Powerups", { "Name", "Action" })

-- add some rows to our new table
powerups:add({ Label = "mushroom", Name = "Super Mushroom", Action = "Grow" })
powerups:add({ Label = "fire_flower", Name = "Fire Flower", Action = "Shoot" })
powerups:add({ Label = "poison_mushroom", Name = "Poison Mushroom", Action = "Hurt" })

-- search for everyone who loves Link and return a resultset
local linklover_rs = people:search("Loves", "==", "Link")
print(linklover_rs:count() .. " people love Link")

-- loop over the search results to see who loves Link
linklover_rs:enumerate(function(row)
	print(row.Name .. " loves Link")
end)

-- everything we have done so far is just in memory
-- we're happy with the results, so let's write it to file
db:sync()