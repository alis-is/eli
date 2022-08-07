local util = {}

function util.is_array(t)
   if type(t) ~= "table" then
      return false
   end
   local n = t.n
   local i = 0
   for k in pairs(t) do
      i = i + 1
      if k ~= "n" and i ~= k then
         return false
      end
   end
   -- arrays package with table.pack have n key describing count of elements. So actual number of array indexes is i - 1
   if type(n) == "number" then return n == i - 1 end
   return true
end

---#DES 'util.merge_arrays'
---@param t1 table
---@param t2 table
---@return table?, string?
function util.merge_arrays(t1, t2)
   if not util.is_array(t1) then
      return nil, "t1 is not an array"
   end
   if not util.is_array(t2) then
      return nil, "t2 is not an array"
   end
   local _result = { table.unpack(t1) }
   for _, v in ipairs(t2) do
      table.insert(_result, v)
   end
   return _result
end

---#DES 'util.merge_tables'
---@param t1 table
---@param t2 table
---@param overwrite? boolean
---@return table
function util.merge_tables(t1, t2, overwrite)
   if t1 == nil then
      return t2
   end
   if t2 == nil then
      return t1
   end
   local _result = {}
   if util.is_array(t1) and util.is_array(t2) then
      for _, v in ipairs(t1) do
         -- merge id based arrays
         if type(v.id) == "string" then
            for i = 1, #t2, 1 do
               local v2 = t2[i]
               if type(v2.id) == "string" and v2.id == v.id then
                  v = util.merge_tables(v, v2, overwrite)
                  table.remove(t2, i)
                  break
               end
            end
         end

         table.insert(_result, v)
      end

      for _, v in ipairs(t2) do
         table.insert(_result, v)
      end
   else
      for k, v in pairs(t1) do
         _result[k] = v
      end
      for k, v2 in pairs(t2) do
         local v1 = _result[k]
         if type(v1) == "table" and type(v2) == "table" then
            _result[k] = util.merge_tables(v1, v2, overwrite)
         elseif type(v1) == "nil" then
            _result[k] = v2
         elseif overwrite then
            _result[k] = v2
         end
      end
   end
   return _result
end

---#DES 'util.escape_magic_characters'
---@param s string
---@return string
function util.escape_magic_characters(s)
   if type(s) ~= "string" then
      return s
   end
   return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

---#DES 'util.generate_safe_functions'
---@generic T : table<string, function>
---@param fnTable T
---@return T
function util.generate_safe_functions(fnTable)
   if type(fnTable) ~= "table" then
      return fnTable
   end
   if util.is_array(fnTable) then
      return fnTable -- safe function can be generated only on dictionary
   end
   local res = {}

   for k, v in pairs(fnTable) do
      if type(v) == "function" and not k:match("^safe_") then
         res["safe_" .. k] = function(...)
            return pcall(v, ...)
         end
      end
   end
   return util.merge_tables(fnTable, res)
end

---@param t table
---@param prefix string?
local function _internal_print_table_deep(t, prefix)
   if type(t) ~= "table" then
      return
   end
   if prefix == nil then prefix = "\t" end
   for k, v in pairs(t) do
      if type(v) == "table" then
         print(prefix .. k .. ":")
         _internal_print_table_deep(v, prefix .. "\t")
      else
         print(prefix, k, v)
      end
   end
end

---#DES 'util.print_table'
---@param t table
---@param deep boolean?
function util.print_table(t, deep)
   if type(t) ~= "table" then
      return
   end
   for k, v in pairs(t) do
      if deep and type(v) == "table" then
         print(k .. ":")
         _internal_print_table_deep(v)
      else
         print(k, v)
      end

   end
end

---@type Logger? 
GLOBAL_LOGGER = GLOBAL_LOGGER or nil

---#DES 'util.global_log_factory'
---@param module string
---@param ... string
---@return fun(msg: string) ...
function util.global_log_factory(module, ...)
   ---@type fun(msg: string)[]
   local _result = {}
   if (type(GLOBAL_LOGGER) ~= "table" and type(GLOBAL_LOGGER) ~= "ELI_LOGGER") or getmetatable(GLOBAL_LOGGER).__type ~= "ELI_LOGGER" then
      GLOBAL_LOGGER = (require"eli.Logger"):new()
   end

   for _, lvl in ipairs({...}) do
      table.insert(
         _result,
         function(msg)
            if type(msg) ~= "table" then
               msg = {msg = msg}
            end
            msg.module = module
            return GLOBAL_LOGGER:log(msg, lvl)
         end
      )
   end
   return table.unpack(_result)
end

--- //TODO: Remove
---#DES 'util.remove_preloaded_lib'
-- this is provides ability to load not packaged eli from cwd
-- for debug purposes
function util.remove_preloaded_lib()
   for k, _ in pairs(package.loaded) do
      if k and k:match("eli%..*") then
         package.loaded[k] = nil
      end
   end
   for k, _ in pairs(package.preload) do
      if k and k:match("eli%..*") then
         package.preload[k] = nil
      end
   end
   print("eli.* packages unloaded.")
end

---#DES 'util.random_string'
---@param length number
---@param charset table?
---@return string
function util.random_string(length, charset)
   if type(charset) ~= "table" then
      charset = {}
      for c = 48, 57 do
         table.insert(charset, string.char(c))
      end
      for c = 65, 90 do
         table.insert(charset, string.char(c))
      end
      for c = 97, 122 do
         table.insert(charset, string.char(c))
      end
   end
   if not length or length <= 0 then
      return ""
   end
   math.randomseed(os.time())
   return util.random_string(length - 1) .. charset[math.random(1, #charset)]
end

---@param v any
---@param cache table?
---@param deep (boolean|number)?
local function _internal_clone(v, cache, deep)
   if type(deep) == "number" then deep = deep - 1 end
   local _go_deeper = deep == true or (type(deep) == 'number' and deep >= 0)

   cache = cache or {}
   if type(v) == 'table' then
       if cache[v] then
           return cache[v]
       else
           local _clone_fn = _go_deeper and _internal_clone or function (v) return v end
           local copy = {}
           cache[v] = copy
           for k, _v in next, v, nil do
               copy[_clone_fn(k, cache, deep)] = _clone_fn(_v, cache, deep)
           end
           setmetatable(copy, _clone_fn(getmetatable(v), cache, deep))
           return copy
       end
   else -- number, string, boolean, etc
      return v
   end
end

---#DES 'util.clone'
---@generic T
---@param v T
---@param deep (boolean|number)?
---@return T
function util.clone(v, deep)
   return _internal_clone(v, {}, deep)
end

---#DES 'util.equals'
---@param v any
---@param v2 any
---@param deep (boolean|number)?
function util.equals(v, v2, deep)
   if type(deep) == "number" then deep = deep - 1 end
   local _go_deeper = deep == true or (type(deep) == 'number' and deep >= 0)

   if type(v) == 'table' and type(v2) == "table" and _go_deeper then
      for k, _v in pairs(v) do
         local _result = util.equals(v2[k], _v, deep)
         if not _result then return false end
      end
      return true
  else -- number, string, boolean, etc
     return v == v2
  end
end

-- // TODO: map

return util
