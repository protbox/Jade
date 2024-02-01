local Jade = {}
local Jade_mt = { __index = Jade }

-- private function to capitalize string
local function upper(str)
    return (str:gsub("^%l", string.upper))
end

-- private function to test for number
local function isNum(n) return tonumber(n) and true or false end

-- tiny helper method which just converts underscores to spaces
function Jade.str(s) return s:gsub("_", " ") end

-- create a brand new 2da file
-- createNew(filename, { label1, label2, label3, etc })
-- don't forget to sync afterwards
function Jade.createNew(fn, cols)
    local me = { data = {}, filename = fn }

    me.columns = cols
    return setmetatable(me, Jade_mt)
end

-- load a 2da file
function Jade.load(fn)
    local me = { data = {}, filename = fn }

    local file = io.open(fn, "r")
    if not file then
        error("Could not open file: " .. fn)
    end

    -- ensure we have the correct prologue
    local prologue = file:read("*line")
    -- strip leading and trailing whitespace
    prologue = prologue:match( "^%s*(.-)%s*$" )
    if not prologue or prologue ~= "2DA V2.0" then
        error("Invalid 2DA file format.")
    end

    -- mandatory empty line after the prologue
    file:read("*line")

    -- parse the column labels
    local labels = file:read("*line")
    me.columns = {}
    for label in labels:gmatch("%S+") do
        table.insert(me.columns, label)
    end

    -- parse the actual data
    for line in file:lines() do
        local values = {}
        local rowIndex

        -- extract first column as the index for the row
        local ri = line:match("(%S+)")
        rowIndex = isNum(ri) and tonumber(ri) or ri

        if rowIndex then
            local i = 1
            values["__id"] = rowIndex
            for value in line:gmatch("%S+") do
                if i > 1 and me.columns[i - 1] then
                    values[me.columns[i - 1]] = value == "****" and false or value
                    -- if it's a number, then uh.. convert it into one
                    if isNum(value) then
                        values[me.columns[i - 1]] = tonumber(value)
                    end
                end
                i = i + 1
            end

            -- set the values for this row
            me.data[rowIndex] = values
        end
    end

    file:close()

    return setmetatable(me, Jade_mt)
end

-- this method gets added to rows to follow a reference to another table
local function _ref(self, rs, label)
    if self[label] then
        return rs:fetch(self[label])
    else
        print("Can't find the key '" .. self[label] .. "' in the provided resultset")
        return false
    end
end

-- fetches a row specified by its key/id
function Jade:fetch(id)
    if self.data[id] then
        self.data[id].ref = _ref
        return self.data[id]
    end

    return false
end

-- simply dumps the records for the given id to stdout
-- no real use. Was using this to check output when working on the initial parsing.
function Jade:dump(id)
    if self.data[id] then
        print("")
        local label = "RECORDS FOR index (" .. id .. ")"
        print(label)
        for i=1,#label do
            io.write("-")
        end
        print("")
        for k,v in pairs(self.data[id]) do
            print(k .. " | " .. v)
        end
        print("")
    end

    return false
end

-- removes an item from the resultset
-- returns true on success, false on failure (id does not exist)
-- requires an item record
function Jade:remove(item)
    if self.data[item.__id] then
        self.data[item.__id] = nil
        return true
    end

    return false
end

-- adds a new record to the dataset
function Jade:add(key, tbl)
    --local res = {}
    local newIndex = isNum(key) and tonumber(key) or key
    self.data[newIndex] = { __id = newIndex }
    for _,v in ipairs(self.columns) do
        if tbl[v] then
            self.data[newIndex][v] = tbl[v]
        else
            self.data[newIndex][v] = "****"
        end
    end

    return self.data[newIndex]
end

function Jade:enumerate(fn)
    for _,row in pairs(self.data) do
        if type(row) ~= "function" then fn(row) end
    end
end

-- find is essentially just a shortcut for :search():first()
-- used when you are just expecting a single result
function Jade:find(tbl)
    local res = self:search(tbl)
    if #res > 0 then return res:first() end

    return false
end

-- private function for condition matching, if it wasn't obvious from the name
local function matchCondition(row, condition)
    for label, value in pairs(condition) do
        if value:sub(-1) == "%" then
            value = value:sub(1, -2)
            if not string.find(row[label], "^" .. value) then
                return false
            end
        else
            if row[label] ~= value then
                return false
            end
        end
    end
    return true
end

-- returns a resultset of any rows matching the specified conditions
function Jade:search(tbl)
    local results = {}

    if type(tbl[1]) == "table" then
        -- multiple conditions
        for index, row in pairs(self.data) do
            local match = true

            for _, condition in ipairs(tbl) do
                if not matchCondition(row, condition) then
                    match = false
                    break
                end
            end

            if match then
                local id = row.__id
                if id then
                    table.insert(results, self:fetch(id))
                end
            end
        end
    else
        -- single condition
        for index, row in pairs(self.data) do
            if matchCondition(row, tbl) then
                local id = row.__id
                if id then
                    table.insert(results, self:fetch(id))
                end
            end
        end
    end

    -- pick off the first result
    function results:first()
        local f = results[1]
        f.ref = _ref
        return f
    end

    -- iterate over each row. a little cleaner than doing a for loop yourself imho
    -- other benefit: this can also be chained onto the search resultset
    function results:enumerate(fn)
        for _,row in pairs(self) do
            if type(row) ~= "function" then fn(row) end
        end
    end

    function results:count() return #self end

    return results
end

-- sync will write the content of self.data to the filename given in .load
-- if you've made any changes to records you'd like to keep, you should do this
function Jade:sync()
    if not self.filename then
        print("Error: No filename specified for sync.")
        return
    end

    local file = io.open(self.filename, "w")
    if not file then
        print("Error: Could not open file for writing.")
        return
    end

    file:write("2DA V2.0\n\n")

    -- write labels
    local labels = " " .. table.concat(self.columns, " ")
    file:write(labels .. "\n")

    -- now the actual data rows
    for rowIndex, values in pairs(self.data) do
        -- Create a line for each row
        local line = values.__id
        for _, column in ipairs(self.columns) do
            line = line .. " " .. (values[column] or "****")
        end

        file:write(line .. "\n")
    end

    file:close()
end

return Jade