local function keys(t)
   local _keys = {}
   for k, _ in pairs(t) do
      table.insert(_keys, k)
   end
   return _keys
end

local function values(t)
   local vals = {}
   for _, v in pairs(t) do
      table.insert(vals, v)
   end
   return vals
end

local function _to_array(t)
   local arr = {}
   local _keys = {}
   for k in pairs(t) do table.insert(_keys, k) end
   table.sort(_keys)

   for _, k in ipairs(_keys) do
      table.insert(arr, {key = k, value = t[k]})
   end
   return arr
end

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

local function merge_tables(t1, t2, overwrite)
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
                  v = merge_tables(v, v2, overwrite)
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
            _result[k] = merge_tables(v1, v2, overwrite)
         elseif type(v1) == "nil" then
            _result[k] = v2
         elseif overwrite then
            _result[k] = v2
         end
      end
   end
   return _result
end

local function _escape_magic_characters(s)
   if type(s) ~= "string" then
      return
   end
   return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"))
end

local function filter_table(t, _filter)
   if type(_filter) ~= "function" then
      return t
   end
   local isArray = _is_array(t)

   local res = {}
   for k, v in pairs(t) do
      if _filter(k, v) then
         if isArray then
            table.insert(res, v)
         else
            res[k] = v
         end
      end
   end
   return res
end

local function generate_safe_functions(functions)
   if type(functions) ~= "table" then
      return functions
   end
   if _is_array(functions) then
      return functions -- safe function can be generated only on dictionary
   end
   local res = {}

   for k, v in pairs(functions) do
      if type(v) == "function" and not k:match("^safe_") then
         res["safe_" .. k] = function(...)
            return pcall(v, ...)
         end
      end
   end
   return merge_tables(functions, res)
end

local function print_table(t)
   if type(t) ~= "table" then
      return
   end
   for k, v in pairs(t) do
      print(k, v)
   end
end

local function _global_log_factory(module, ...)
   local _result = {}
   for _, lvl in ipairs({...}) do
      if type(GLOBAL_LOGGER) ~= "table" or GLOBAL_LOGGER.__type ~= "ELI_LOGGER" then
         table.insert(
            _result,
            function()
            end
         )
      else
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
   end
   return table.unpack(_result)
end

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

local function _clone(v, deep)
   return _internal_clone(v, {}, deep)
end

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

local function _base_get(obj, path)
   if type(obj) ~= "table" then
      return nil
   end
   if type(path) == "string" then
      return obj[path]
   elseif _is_array(path) then
      return _base_get(obj[table.remove(path)], path)
   else
      return nil
   end
end

local function _get(obj, path, default)
   local _result = _base_get(obj, path)
   if _result == nil then
      return default
   end
end

local function _set(obj, path, value)
   if type(obj) ~= "table" then
      return obj
   end
   if type(path) == "string" then
      obj[path] = value
   elseif _is_array(path) then
      _set(obj[table.remove(path)], path, value)
   end
   return obj
end

return {
   keys = keys,
   values = values,
   to_array = _to_array,
   generate_safe_functions = generate_safe_functions,
   is_array = _is_array,
   escape_magic_characters = _escape_magic_characters,
   filter_table = filter_table,
   merge_tables = merge_tables,
   print_table = print_table,
   global_log_factory = _global_log_factory,
   remove_preloaded_lib = _remove_preloaded_lib,
   random_string = _random_string,
   clone = _clone,
   equals = _equals,
   get = _get,
   set = _set
}
