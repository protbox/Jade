# What is Jade?
Jade a TSV (Tab-Separated Values) database, of sorts. The main goal of Jade was creating a small and fast database format that could easily be edited by hand. It maps the data returned into objects for convenience, and when you write your changes to file it will align everything neatly for clarity

```
@Spells

Label    	Type 	Value 	Mana 	Element 
cut      	atk  	2     	**** 	****    
slash    	atk  	1     	**** 	****    
aegis    	def  	1     	**** 	****    
leech    	life 	2     	3    	soul    
Fireball	atk  	3     	4    	fire    

@Items

Label         	Type   	Consumable 	Value 
health_potion 	life   	true       	5     
mana_potion   	mana   	true       	10    
Big_Axe       	weapon 	****       	60 

```

Tables are defined with @TableName. Then a newline is required. Following this, are the fields (or columns), then below them are the rows (values). It's a very simple design that makes it a cinch to hand edit, which is why I created it. Just remember that it uses tab stops as delimeters. Any other whitespace will not work!

# Usage

For starters, we load Jade. I'll just assume Jade.lua is in a directory called `lib`

```lua
local jade = require "lib.Jade"
```

Now we need to load the database file

```lua
local db = jade.load("data/test.db")

```

Now you'll want to get some data out of it. This library maps data into objects called a ResultSet. It can easily be achieved like so:

```lua
local item_rs = db:resultset("Items")
```

This stores all the contents of the Items table into a lua object. We can now do stuff with it.

## Fetching results

There's two main ways to fetch results. Using `fetch` or `search`. `fetch` returns just one row, while `search` is designed to retrieve multiple as a ResultSet, and even allows for partial matching.

Fetch can have two arguments. If you just supply one, it will fetch the row based on its Label. If you supply two, it will try to find a row that matches Key = Value.
For example

```lua
local row = item_rs:fetch("hero_001") -- gets the row where Label = "hero_001"
local row = item_rs:fetch("Type", "chair") -- fetches the first row that the column "Type" has a value of "chair"

-- you can now use it as you would any other lua table
print(row.Label, row.Type)
```

Search requires 3 arguments. A column name, an expression and value
```lua
-- performs a partial match search
local rs = item_rs:search("Label", "%=", "_potion")
```

Other expressions include `==`, `>`, `>=`, `<`, `<=`

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
local axe = item_rs:fetch("Big_Axe")
-- maybe we want to make it little axe
axe.Label = "Little_Axe"

-- add a new weapon to items
item_rs:add({ Label = "Staff", Value = 25, Type = "weapon" })
```
So far, we've just changed it in memory, so it's still available to use but isn't physically written anywhere. Once we call `db:sync()`, Jade will rewrite the entire file with all your adjustments. SO BE CAREFUL, ESCPECIALLY WHEN CHANGING VALUES. If you want to make a temporary change, store the value of the row into a local variable instead of overwriting the original.

# Creating new tables

Yep, we can do that too. Simply call `db:add_table(table_name, {fields})`. Keep in mind Jade requires at least a Label field to use as a primary key. If you don't include it in `{fields}`, don't worry, Jade will push it to the front for you.

```lua
local db = jade.load("data/test.db")
local my_cool_table = db:add_table("CoolTable", {"Label", "Name"})

-- we've got the new resultset, now let's add some data to it
local new_row = my_cool_table:add({ Label = "cool_test_001", Name = "Really Cool Test" })
print(new_row.Label .. ": " .. new_row.Name)

-- when you're ready to write it to file
db:sync()
```