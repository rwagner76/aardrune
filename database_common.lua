function execute_in_transaction(db, operations)
    local query = "BEGIN TRANSACTION;" .. table.concat(operations, "") .. "COMMIT;"
    db:exec(query)
end

function bindQs(s)
   -- Give a comma-seperated list, receive a list of ? instead!
   -- For DB prepare statements
   local t = string.split(s,',')
   local qs = {}
   for i,v in ipairs(t) do
      table.insert(qs,"?")
   end
   return table.concat(qs,',')
end

function querytoTable(db,q)
   local t = {}
   for r in db:nrows(q) do table.insert(t,r) end
   return t
end

function queryToNestedTable(db, sql, key_column)
    local result = {}
    
    for row in db:nrows(sql) do
        local key = row[key_column]
        if key then
            -- Exclude the key from the inner table if desired, or leave it
            local entry = {}
            for k, v in pairs(row) do
                if k ~= key_column then
                    entry[k] = v
                end
            end
            result[key] = entry
        else
            print("Warning: row missing key column '" .. key_column .. "'")
        end
    end

    return result
end

function querytoArray(db,q)
   local a = {}
   local rc = 0
   for r in db:rows(q) do
     table.insert(a,r[1])
   end
   return a
end

function countQuery(db,q)
   for r in db:rows(q) do
      return r[1]
   end
end