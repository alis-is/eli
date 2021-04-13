local function _is_array(t)
   if type(t) ~= "table" then
      return false
   end
   local i = 0
   for k in pairs(t) do
      i = i + 1
      if i ~= k then
         return false
      end
   end
   return true
end
---#DES 'util.merge_tables'
---@param t1 table
---@param t2 table
---@param overwrite boolean
---@return table
local function _merge_tables(t1, t2, overwrite)
   if t1 == nil then
      return t2
   end
   if t2 == nil then
      return t1
   end
   local _result = {}
   if _is_array(t1) and _is_array(t2) then
      for _, v in ipairs(t1) do
         -- merge id based arrays
         if type(v.id) == "string" then
            for i = 1, #t2, 1 do
               local v2 = t2[i]
               if type(v2.id) == "string" and v2.id == v.id then
                  v = _merge_tables(v, v2, overwrite)
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
            _result[k] = _merge_tables(v1, v2, overwrite)
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
local function _escape_magic_characters(s)
   if type(s) ~= "string" then
      return
   end
   return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

---#DES 'util.generate_safe_functions'
---@generic T : table<string, function>
---@param fnTable T
---@return T
local function _generate_safe_functions(fnTable)
   if type(fnTable) ~= "table" then
      return fnTable
   end
   if _is_array(fnTable) then
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
   return _merge_tables(fnTable, res)
end

---comment
---@param t table
---@param prefix string|nil
local function _internal_print_table_deep(t, prefix)
   if type(t) ~= "table" then
      return
   end
   if prefix == nil then prefix = "\t" end
   for k, v in pairs(t) do
      if type(v) == "table" then
         print(k .. ":")
         _internal_print_table_deep(v, prefix .. "\t")
      else
         print(prefix, k, v)
      end
   end
end

---#DES 'util.print_table'
---@param t table
---@param deep boolean
local function _print_table(t, deep)
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

---#DES 'util.global_log_factory'
---@param module string
local function _global_log_factory(module, ...)
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
local function _remove_preloaded_lib()
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
---@param charset table
local function _random_string(length, charset)
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
   return _random_string(length - 1) .. charset[math.random(1, #charset)]
end

---#DES 'util._internal_clone'
---@param v any
---@param cache table
---@param deep boolean
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
---@param deep boolean
---@return T
local function _clone(v, deep)
   return _internal_clone(v, {}, deep)
end

---#DES 'util.equals'
---@param v any
---@param v2 any
---@param deep boolean
local function _equals(v, v2, deep)
   if type(deep) == "number" then deep = deep - 1 end
   local _go_deeper = deep == true or (type(deep) == 'number' and deep >= 0)

   if type(v) == 'table' and type(v2) == "table" and _go_deeper then
      for k, _v in pairs(v) do
         local _result = _equals(v2[k], _v, deep)
         if not _result then return false end
      end
      return true
  else -- number, string, boolean, etc
     return v == v2
  end
end

return {
   generate_safe_functions = _generate_safe_functions,
   is_array = _is_array,
   escape_magic_characters = _escape_magic_characters,
   merge_tables = _merge_tables,
   print_table = _print_table,
   global_log_factory = _global_log_factory,
   remove_preloaded_lib = _remove_preloaded_lib,
   random_string = _random_string,
   clone = _clone,
   equals = _equals
}
