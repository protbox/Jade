local Jade = {}
local Jade_mt = { __index = Jade }

-- little helper function to trim whitespace
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- converts a string to a lua type
local function convert(str)
    if tonumber(str) then return tonumber(str)
    elseif str == "****" then return nil
    elseif str == "true" then return true
    elseif str == "false" then return false
    else return str end
end

-- reads the file supplied and parses it, turning it into lua tables
function Jade.load(filename)
    local db = { tables = {}, filename = filename }
    local current_table = nil

    for line in io.lines(filename) do
        line = trim(line)

        if line:sub(1, 1) == "@" then
            -- start a new table & extract table name
            current_table = line:sub(2):match("%S+")
            db.tables[current_table] = { columns = {}, rows = {} }
        elseif current_table then
            local table_data = db.tables[current_table]

            if not next(table_data.columns) and line:find("%S") then
                -- define the column headers
                table_data.columns = {}
                for col in line:gmatch("[^\t]+") do
                    table.insert(table_data.columns, col)
                end

                -- ensure the table has a Label column
                -- labels are used as primary keys, so they can be really useful
                if not table_data.columns[1] or table_data.columns[1] ~= "Label" then
                    error("Table '" .. current_table .. "' is missing Label")
                end
            elseif line:find("%S") then
                -- parse row data using tabs as delimiters
                if #table_data.columns == 0 then
                    error("No columns defined for table '" .. current_table .. "'")
                end

                local row = {}
                local i = 1
                for value in line:gmatch("[^\t]+") do
                    local col_name = table_data.columns[i]
                    if not col_name then
                        error("Mismatch between columns and row data in table '" .. current_table .. "'")
                    end

                    -- convert value to Lua types
                    value = convert(value)

                    row[col_name] = value
                    i = i + 1
                end

                -- finally, add row to the table
                table.insert(table_data.rows, row)
            end
        end
    end

    return setmetatable(db, Jade_mt)
end

-- returns a list of table names
function Jade:get_table_names()
    local tbls = {}
    for name,_ in pairs(self.tables) do
        table.insert(tbls, name)
    end

    return tbls
end

-- converts a value like apples, oranges, pineapple
-- to a lua table
function Jade.as_array(inp)
    local t = {}
    for str in string.gmatch(inp, "([^,]+)") do
        str = convert(str)
        table.insert(t, str)
    end

    return t
end

function Jade.as_blob(inp)
    local str = inp:gsub("\\n", "\r\n")
    return str
end

-- syncs the data in memory back to the database file
-- will beautify it, making it easier to edit by hand, which is the whole point of Jade
-- WARNING: will overwrite everything, so make sure this is what you want to do
function Jade:sync()
    local str = ""

    for name, t in pairs(self.tables) do
        -- write the table name
        str = str .. "@" .. name .. "\n\n"

        -- calculate the required tabs for each column
        local tab_stops = {}
        for i, col in ipairs(t.columns) do
            local max_width = #col
            for _, row in ipairs(t.rows) do
                local val = row[col] or "****"
                max_width = math.max(max_width, #tostring(val))
            end
            -- convert width to the number of tabs required
            -- I'm assuming 4 characters per tab for simplicity
            tab_stops[i] = math.ceil((max_width + 1) / 4)
        end

        -- write column names with alignment
        for i, col in ipairs(t.columns) do
            str = str .. col
            local tabs_needed = tab_stops[i] - math.ceil((#col + 1) / 4)
            str = str .. string.rep("\t", tabs_needed + 1)
        end
        str = str .. "\n"

        -- write rows with alignment
        for _, row in ipairs(t.rows) do
            for i, col in ipairs(t.columns) do
                local val = row[col] or "****"
                val = tostring(val)
                str = str .. val
                local tabs_needed = tab_stops[i] - math.ceil((#val + 1) / 4)
                str = str .. string.rep("\t", tabs_needed + 1)
            end
            str = str .. "\n"
        end

        -- end of table
        str = str .. "\n"
    end

    -- finally, write the string output back to the file
    local fh = io.open(self.filename, "w")
    fh:write(str)
    fh:close()
end

-- the ResultSet object (multiple rows)
local JResultSet = {}
local JResultSet_mt = { __index = JResultSet }

function JResultSet.new(tbl)
    return setmetatable(tbl, JResultSet_mt)
end

function Jade:add_table(name, fields)
    local has_label = false
    for _,col in ipairs(fields) do
        if col == "Label" then
            has_label = true
        end
    end

    -- if no Label column was specified, prepend it
    if not has_label then
        table.insert(fields, 1, "Label")
    end

    self.tables[name] = { columns = fields, rows = {} }

    return JResultSet.new(self.tables[name])
end

-- shortcut for looping through rows
function JResultSet:enumerate(fn)
    for _,row in ipairs(self.rows) do
        fn(row)
    end
end

-- grabs the first row
function JResultSet:first()
    return self.rows[1]
end

function JResultSet:count() return #self.rows end

-- adds a new row to the resultset
-- rs:add({ Label = "Foo", Type = "Blah"})
-- you don't need to supply every column, so don't worry
function JResultSet:add(tbl)
    local newrow = {}
    local newentries = 0
    for _,col in ipairs(self.columns) do
        if tbl[col] then
            -- if value contains a space, convert it to underscores
            local val = tbl[col]
            --if col == "Label" and type(val) == "string" then val = val:gsub(" ", "_") end
            newrow[col] = val
            newentries = newentries + 1
        else
            newrow[col] = nil
        end
    end

    if newentries > 0 then
        table.insert(self.rows, newrow)
        return newrow
    end

    return false
end

-- fetches a single row from a resultset
-- if only one argument is present, it will attempt to fetch based on Label
-- if two arguments are supplied it will search based on key = value
function JResultSet:fetch(key, val)
    if val then
        for _,row in ipairs(self.rows) do
            if row[key] == val then
                return row
            end
        end

        return false
    else
        for _,row in ipairs(self.rows) do
            if row.Label and row.Label == key then
                return row
            end
        end

        return false
    end
end

-- searches the resultset for any rows matching key = val
-- returns a resultset
function JResultSet:search(key, exp, val)
    local results = {}
    for _,row in ipairs(self.rows) do
        if row[key] then
                -- perform expression check
            if exp == ">" then
                if row[key] and row[key] > val then
                    match = true
                end
            elseif exp == ">=" then
                if row[key] and row[key] >= val then
                    match = true
                end
            elseif exp == "<" then
                if row[key] and row[key] < val then
                    match = true
                end
            elseif exp == "<=" then
                if row[key] and row[key] <= val then
                    match = true
                end
            elseif exp == "==" then
                if not row[key] and val == "NULL" then
                    match = true
                elseif row[key] and row[key] == val then
                    match = true
                end
            elseif exp == "%=" then
                if row[key] and row[key]:find(val, 1, true) then
                    match = true
                end
            end

            --if val == row[key] then
            if match then
                table.insert(results, row)
            end
        end
    end

    return #results > 0 and JResultSet.new({ rows = results}) or false
end

-- retrieve a table by name and return a resultset
function Jade:resultset(table_name)
    return JResultSet.new(self.tables[table_name])
end

return Jade
