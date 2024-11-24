# What is Jade?
Originally Jade started out as a simple 2DA file reader/writer. It became cumbersome managing multiple files, so I overhauled its design, allowing for multiple tables in a single file.
If you're too lazy to look in the data/test.db, the format of a Jade database looks like this

```
@Spells

Label    Type Value Mana Element 
cut      atk  2     **** ****    
slash    atk  1     **** ****    
aegis    def  1     **** ****    
leech    life 2     3    soul    
Fireball atk  3     4    fire    

@Items

Label         Type   Consumable Value 
health_potion life   true       5     
mana_potion   mana   true       10    
Big_Axe       weapon ****       60 

```

Tables are defined with @TableName. Then a newline is required. Following this, are the fields (or columns), then below them are the rows (values). It's a very simple design that makes it a cinch to hand edit, which is why I created it.
The biggest downside is whitespace is reserved to denote the end of a field, so you'll need to use underscores instead. You can use `jade.to_str()` to replace underscores with spaces for a more readable string if you wish.

# Usage

For starters, we load Jade. I'll just assume Jade.lua is in a directory called `lib`

```lua
local jade = require "lib.Jade"
```

Now we need to load the database file

```lua
local db = jade.load("data/test.db")

-- optionally, you can pass true to load which will replace underscores with spaces
-- except in the Label field
local db = jade.load("data/test.db", true)
```

Now you'll want to get some data out of it. This library maps data into objects called a ResultSet. It can easily be achieved like so:

```lua
local item_rs = db:resultset("Items")
```

This stores all the contents of the Items table into a lua object. We can now do stuff with it.

## Fetching results

There's two main ways to fetch results. Using `fetch` or `search`. `fetch` returns just one row, while `search` is designed to retrieve multiple as a ResultSet, and even allows for partial matching.

Fetch can have two arguments. If you just supply one, it will fetch the row based on its index. If you supply two, it will try to find a row that matches Key = Value.
For example

```lua
local row = item_rs:fetch(2) -- gets the row with index 2
local row = item_rs:fetch("Type", "chair") -- fetches the first row that the column "Type" has a value of "chair"

-- you can now use it as you would any other lua table
print(row.Label, row.Type)
```

Search requires 2 arguments. A column name and value (or partial value)
```lua
-- grab all rows where their column values contain the string _potion
local rs = item_rs:search("Label", "_potion")
```

## What can I do with a ResultSet?

Well, we've seen searching already. You can loop over them with enumerate.

```lua
rs:enumerate(function(row)
    print(row.Label, row.Value, row.Type)
end)
```

Or, if you wish, add a brand new row to the resultset

```lua
rs:add({ Label = "Foo", Value = 7 })
```
Any columns you missed will be saved as `****` which is `nil` in Lua. Don't worry, your results in Lua will be converted to proper Lua types. It's only stored like that in the database file.

# Syncing

If you've made any changes or added new rows, you may want to write it to file. You can do that with `db:sync()`

```lua
local db = jade.load("data/test.db")
local item_rs = db:resultset("Items")

-- grab the row with Big_Axe
local axe = item_rs:fetch("Label", "Big_Axe")
-- maybe we want to make it little axe
axe.Label = "Little_Axe"

-- add a new weapon to items
item_rs:add({ Label = "Staff", Value = 25, Type = "weapon" })
```
So far, we've just changed it in memory, so it's still available to use but isn't physically written anywhere. Once we call `db:sync()`, Jade will rewrite the entire file with all your adjustments. SO BE CAREFUL, ESCPECIALLY WHEN CHANGING VALUES. If you want to make a temporary change, store the value of the row into a local variable instead of overwriting the original.

# Creating new tables

Yep, we can do that too. Simply call `db:add_table(table_name, {fields})`. Keep in mind Jade requires at least a Label field to use as a primary key.

```lua
local db = jade.load("data/test.db")
local my_cool_table = db:add_table("CoolTable", {"Label", "Name"})

-- we've got the new resultset, now let's add some data to it
local new_row = my_cool_table:add({ Label = "cool_test_001", Name = "Really Cool Test" })
print(new_row.Label .. ": " .. new_row.Name)

-- when you're ready to write it to file
db:sync()
```