local jade = require "Jade"
local spells = jade.load("data/spells.2da")
local items = jade.load("data/items.2da")

--[[local gem = items:find({ Label = "Gem_of_Ice" })
local spell = gem:ref(spells, "spell")

print(spell.Duration)]]

items:search({ Type = "gem%" })
    :enumerate(function(row)
        local sp = row:ref(spells, "Spell")
        if sp then
            print(jade.str(row.Label) .. ": " .. sp.Type)
        end
    end)

--[[items:enumerate(function(row)
    print(row.__id, row.Label)
end)]]

local spell_row = items:fetch("fire_gem"):ref(spells, "Spell")
print(spell_row.Type)