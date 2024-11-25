local Jade = {}
local Jade_mt = { __index = Jade }

-- little helper function to trim whitespace
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- parses the filename supplied and parses it, turning it into lua tables
function Jade.load(filename, replace_underscores_with_spaces)
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
                local has_label = false
                table_data.columns = {}
                for col in line:gmatch("%S+") do
                    if col == "Label" then has_label = true end
                    table.insert(table_data.columns, col)
                end

                -- not sure if I'll keep this
                -- but essentially this means tables REQUIRE a Label field
                -- I think it's a good thing to have a consistent field to refer to
                if not has_label then
                    error("Table '" .. current_table .. "' is missing Label")
                end
            elseif line:find("%S") then
                -- parse row data
                if #table_data.columns == 0 then
                    error("No columns defined for table '" .. current_table .. "'")
                end

                local row = {}
                local i = 1
                for value in line:gmatch("%S+") do
                    local col_name = table_data.columns[i]
                    if not col_name then
                        error("Mismatch between columns and row data in table '" .. current_table .. "'")
                    end

                    -- we need to convert strings to valid lua types
                    if value == "****" then
                        value = nil
                    elseif value == "true" or value == "false" then
                        value = value == "true"
                    elseif tonumber(value) then
                        value = tonumber(value)
                    end

                    -- do not convert Label field
                    if replace_underscores_with_spaces and col_name ~= "Label" then
                        if type(value) == "string" then value = value:gsub("_", " ") end
                    end

                    row[col_name] = value
                    i = i + 1
                end

                -- finally, append the row to the table
                table.insert(table_data.rows, row)
            end
        end
    end

    return setmetatable(db, Jade_mt)
end

-- syncs the data in memory back to the database file
-- WARNING: will overwrite everything, so make sure this is what you want to do
function Jade:sync()
    local str = ""
    
    for name, t in pairs(self.tables) do
        -- write table name
        str = str .. "@" .. name .. "\n\n"
        
        -- determine column widths for padding
        local col_widths = {}
        for i, col in ipairs(t.columns) do
            local max_width = #col
            for _, row in ipairs(t.rows) do
                local val = row[col] or "****"
                max_width = math.max(max_width, #tostring(val))
            end
            col_widths[i] = max_width
        end

        -- write col names
        for i, col in ipairs(t.columns) do
            str = str .. col .. string.rep(" ", col_widths[i] - #col + 1)
        end
        str = str .. "\n"

        -- write row vals
        for _, row in ipairs(t.rows) do
            for i, col in ipairs(t.columns) do
                local val = row[col] or "****"
                val = tostring(val)
                val = val:gsub("%s+", "_")
                str = str .. val .. string.rep(" ", col_widths[i] - #val + 1)
            end
            str = str .. "\n"
        end

        -- end table
        str = str .. "\n"
    end

    -- write to file
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

    if not has_label then
        error("add_table expects a Label column")
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
            if col == "Label" and type(val) == "string" then val = val:gsub(" ", "_") end
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
-- if only one argument is present, it will attempt to fetch its index
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
        if self.rows[key] then
            return self.rows[key]
        else
            return false
        end
    end
end

-- searches the resultset for any rows matching key = val
-- returns a resultset
function JResultSet:search(key, val)
    local results = {}
    for _,row in ipairs(self.rows) do
        if row[key] then
            --if val == row[key] then
            if row[key]:find(val, 1, true) then
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
