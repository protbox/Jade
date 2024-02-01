# What is 2DA?
Two-dimensional Array (or 2DA) is a format used in Bioware games, such as SWTOR, Jade Empire, NWN, etc. It's generally a plain text file with 
a very simple structure, so it's easy to manually edit/create. The only downside is there's no spaces in strings as spaces are used to denote the end of a field.
A typical 2DA will look like this

```
2DA V2.0

                Type    DamageNum   Duration
fire_storm      Flame   20          2
winter_storm    Ice     5           6

```

First line is the prologue which says which version to use. Currently Jade only supports 2.0. A blank line follows, then it moves onto the columns. The first column must be blank, as that's where the id/key for each row will be held. Each word after that is the column heading or label.
Following that is your row data. As mentioned, you add the id/key first, then the values for each field. That's all there is to it! Think of it like a spreadsheet.

You can use Jade to modify bioware games (many items/abilities and appearances are located in these 2da files, so you can modify the game to some extent). It can also be used for your own game as a small database

# Usage

For starters, we load Jade. I'll just assume Jade.lua is in a directory called `lib`

```lua
local jade = require "lib.Jade"
```

Now we need to load the table we want

```lua
local items = jade.load("data/items.2da")
```

It's possible to just loop over every row in the table. The following snippet uses `enumerate` to iterate over the table and expose a row. It will then print the Label field of each row.

```lua
items:enumerate(function(row)
    print(row.Label)
end)
```

## Searching

If you know specifically which row you want, you can fetch it using its id/key

```lua
local item = items:fetch("fire_gem")
```

However, we don't always know what the user wants, so we can use `search` to narrow it down based on the field(s) and values they are looking for.

```lua
local item_rs = items:search({ Label = "Gem_of_Fire" })

-- we can search for more than one field
local item_rs = items:search({ Type = "gems", Cost = 5 })
```

Jade also allows for partial matching. Simply add a % at the end of the value string

```lua
local item_rs = items:search({ Type = "gem%" })

-- you can use :count or simply #item_rs to get the number of results found
print("Found " .. item_rs:count() .. " result(s)")
```

If you're expecting a single result, you can use find. It will perform a search then return `:first()` which plucks out the first result.

```lua
local item = items:find({ Label = "Gem_of_Fire" })
```

# Modifying tables

You can create a new file, add new rows and remove rows from a 2DA file with Jade.
To create a new file we simply:

```lua
local newfile = jade.createNew("data/filename.2da", { "Field1", "Field2", "Field3" })
```

It's not much use without rows, so let's add some:

```lua
newfile:add("key", { Field1 = "value1", Field2 = "value2" })
```

If the number of values don't match the number of columns, don't worry. It will replace any empty values with `****`, which is basically nil in 2da world.
Removing a row is a simple matter of calling `:remove(key)` on the file

```lua
items:remove("fire_gem")
```

It's important to note that, while the changes are saved in memory, they are not saved in the file itself. To write everything we've changed, call `sync`

```lua
newfile:sync()
```

**NOTE:** If you modify any rows and call sync, it will save them to the file as well. For example:

```lua
local item = items:fetch("some_id")
item.Label = "Bazinga"
items:sync()
```
This will write some_id's new Label field as Bazinga in the items file.

# Referencing other tables

Sometimes you may want a way to link two tables together. For example, you may have an item table, but you want the enchantment effect in a separate table. The `ref` method attached to rows offers such an ability.

```lua
-- enchantments will be located in spells
local spells = jade.load("data/spells.2da")
local items = jade.load("data/items.2da")

-- first grab your row using fetch/find/search
local gem = items:fetch("ice_gem")

-- ref has two parameters. first is the table you wish to reference, the second is the field name where the reference key resides in the active table
local spell = gem:ref(spells, "Spell")
```

That's it! `ref` will attempt to find a row in the spells table that matches the key located in the Spell field of our gem row. If you're still confused, please check out the example 2das in the data directory.

# Chaining

The beauty of Jade (imho) is the ability to chain methods onto each other. Let's fix up an example using everything we've learned so far, but with chaining.

```lua
items:search({ Type = "gem%" })
    :enumerate(function(row)
        local sp = row:ref(spells, "Spell")
        if sp then
            print(row.Label .. ": " .. sp.Type)
        end
    end)
```

What this does is perform a partial matching search for any "Type" field that begins with the value "gem". It then loops over each of the rows it finds and grabs the spell reference. If it finds one, it will print out the label of the current row and its corresponding spell type from the spells table.

# Conclusion

While using other formats, such as json/lua tables may make more sense, Jade offers a far simpler format with useful search features.
