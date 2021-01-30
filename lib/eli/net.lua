local _curlLoaded , curl = pcall(require, "lcurl.safe")
local io = require "io"
local util = require "eli.util"
local generate_safe_functions = util.generate_safe_functions
local merge_tables = util.merge_tables
local _hjson = require"hjson"
local _exString = require"eli.extensions.string"

if not _curlLoaded then
   return nil
end

local function _download(url, write_function, options)
   if type(options) ~= "table" then
      options = {}
   end

   local followRedirects = options.followRedirects or false
   local verifyPeer = options.verifyPeer
   if verifyPeer == nil then
      verifyPeer = true
   end
   local _easy = curl.easy {
      url = url,
      writefunction = write_function
   }

   local _ok, _error
   _ok, _error = _easy:setopt(curl.OPT_FOLLOWLOCATION, followRedirects)
   assert(_ok, _error)
   _ok, _error = _easy:setopt(curl.OPT_SSL_VERIFYPEER, verifyPeer)
   assert(_ok, _error)
   _ok, _error = _easy:setopt(curl.OPT_TIMEOUT , options.timeout or 0)
   assert(_ok, _error)
   _ok, _error = _easy:perform()
   assert(_ok, _error)
   local code, _error = _easy:getinfo(curl.INFO_RESPONSE_CODE)
   assert(code, _error)
   _easy:close()
   if code ~= 200 and not options.ignoreHttpErrors then
      error("Request failed with code " .. tostring(code) .. "!")
   end
   return code
end

local function _get_retry_limit(options)
   local _retryLimit = tonumber(os.getenv("ELI_NET_RETRY_LIMIT")) or 0
   if type(options) == "table" then
      if type(options.retryLimit) == "number" and options.retryLimit > 0 then
         _retryLimit = options._retryLimit
      end
   end
   return _retryLimit
end

local function download_file(url, destination, options)
   local _tries = 0
   local _retryLimit = _get_retry_limit(options)

   while _tries <= _retryLimit do
      local _didOpenFile, _df = pcall(io.open, destination, "w+b")
      if not _didOpenFile then
         error(_df)
      end

      local _write = function(data)
         _df:write(data)
      end

      local _ok, _code = pcall(_download, url, _write, options)
      if _ok then
         return _code
      elseif (_tries >= _retryLimit) then
         error(_code)
      end

      _tries = _tries + 1
      _df:close()
   end
end

local function download_string(url, options)
   local _tries = 0
   local _retryLimit = _get_retry_limit(options)

   while _tries <= _retryLimit do
      local _result = ""
      local _write = function(data)
         _result = _result .. data
      end

      local _ok, _code = pcall(_download, url, _write, options)
      if _ok then
         return _result, _code
      elseif (_tries >= _retryLimit) then
         error(_code)
      end
      _tries = _tries + 1
   end
end


local function _request(method, url, options, data)
   assert(type(url) == "string", "URL has to be a string!")
   assert(type(method) == "string", "METHOD has to be a string!")
   local _result = ""
   local _write = function(data)
      _result = _result .. data
   end
   if type(options.write_function) == "function" then
      _write = options.write_function
   end

   local _headers = util.merge_tables(options.headers or {}, {
      ['Content-Type'] = options.contentType
   })

   print("url:", url)

   local _easy = curl.easy{
      url = url,
      httpheader = _headers,
      writefunction = _write,
      [curl.OPT_CUSTOMREQUEST] = method,
   }

   local _mime = util.get(_headers, 'Content-Type')
   local _encode = util.get(options, { _mime, "encode" })
   if type(_encode) == "function" then
      data = _encode(data)
   end

   -- // TODO: fix headers
   local _headers2 = {}
   for k,v in pairs(_headers) do
      local _sep = k[#k] == ":" and "" or ":"
      table.insert(_headers2, k .. ":" .. v)
   end

   _easy:setopt{ httpheader = _headers2 }

   if getmetatable(data) == getmetatable(curl.form()) then
      _easy:setopt_httppost(data)
   elseif getmetatable(data) == getmetatable(_easy:mime()) then
      _easy:setopt{ mimepost = data }
   elseif getmetatable(data) == getmetatable(io.stdout) then
      _easy:setopt{ upload = true }
      _easy:setopt_readfunction(data.read, data)
   else
      _easy:setopt{ postfields = data }
   end

   local _ok, err = _easy:perform()
   if _ok then
      local code, url, content =  _easy:getinfo_effective_url(),
      _easy:getinfo_response_code(), _result
      print(code, url, content)
   else
      print(err)
   end
   _easy:close()
end

local RestClient = {}
RestClient.__index = RestClient

-- https://gist.github.com/liukun/f9ce7d6d14fa45fe9b924a3eed5c3d99
local function _encodeURIComponent(url)
   if url == nil then
     return
   end
   url = url:gsub("\n", "\r\n")
   url = url:gsub("([^%w _%%%-%.~])",  function(c)
      return string.format("%%%02X", string.byte(c))
   end)
   url = url:gsub(" ", "+")
   return url
end

local function encodeQueryParams(data)
   local _result = "";
   for k,v in pairs(data) do
      _result = _result .. _encodeURIComponent(k) .. "=" .. _encodeURIComponent(v) .. "&"
   end
   return _result:sub(1, #_result - 1);
end

function RestClient:new(hostOrId, parentOrOptions, options)
   local _restClient = {
      host = nil,
      __resources = {},
      __shortcuts = {},
      __is_child = false,
      __parent = nil,
      __id = nil
   }
   if options == nil then
      options = {}
   end

   if type(parentOrOptions) == "table" and tostring(parentOrOptions) == "ELI_REST_CLIENT" then
      _restClient.__is_child = true
      _restClient.__parent = parentOrOptions
      _restClient.__id = hostOrId
      _restClient.options = util.merge_tables(options, util.clone(parentOrOptions.options))
   else
      options = parentOrOptions
      _restClient.host = hostOrId
      _restClient.options = util.merge_tables(options, {
         followRedirects = true,
         verifyPeer = true,
         trailing = '',
         shortcut = true,
         shortcutRules = {},
         contentType = 'application/json',
         ['application/x-www-form-urlencoded'] = { encode = _encodeURIComponent },
         ['application/json'] = {encode = _hjson.stringify_to_json, decode = _hjson.parse}
      })
   end

   _restClient.__type = "ELI_REST_CLIENT"
   _restClient.__tostring = function() return "ELI_REST_CLIENT" end
   setmetatable(_restClient, self)
   self.__index = function(t, k)
      local _result = rawget(self, k)
      if _result == nil then
         -- // TODO:
         --return RestClient:new(k, _restClient)
      end
      return _result
   end
   return _restClient
end

function RestClient:get_url()
   if not self.__is_child then
      return self.host
   end
   local _url = self.__parent:get_url()
   if type(self.__id) == "string" then
      local _sep = _url[#_url] == "/" and "" or "/"
      _url = _url .. _sep .. self.__id
   end
   return _url
end

function RestClient:conf(options)
   if options == nil then
      return self.options
   end
   self.options = util.merge_tables(options, self.options)
   return self.options
end

function RestClient:res(resources, options)
   if options == nil then
      options = {}
   end
   local _shortcut = options.shortcut
   if _shortcut == nil then
      _shortcut = self.options.shortcut
   end

   local function makeResource(name)
      if self.__resources[name] then
         return self.__resources[name]
      end

      local _result = RestClient:new(name, self, options)
      self.__resources = _result
      if _shortcut then
         self.__shortcuts[name] = _result
         self[name] = _result
         for _, rule in ipairs(util.get(self, { "options", "shortcutRules" }, {})) do
            if type(rule) == "function" then
               local _customShortcut = rule(name);
               if type(_customShortcut) == "string" then
                  self.__shortcuts[_customShortcut] = _result
                  self[_customShortcut] = _result
               end
            end
         end
      end
      return _result
   end

   if type(resources) == "string" then
      return makeResource(resources)
   end

   if util.is_array(resources) then
      return util.map(resources, makeResource)
   end

   if type(resources) == "table" then
      local _result = {}
      for k, v in pairs(resources) do
         local _resource = makeResource(k)
         if resources[k] then
            _resource.res(resources[k])
         end
         _result[k] = _resource
      end
      return _result
   end
end

local function _get_request_url_n_options(client, pathOrOptions, pathOrOptions, options)
   local _path = ""
   if type(pathOrOptions) == "table" then
      options = pathOrOptions
   elseif type(pathOrOptions) == "string" then
      _path = pathOrOptions
   end 
   if type(options) ~= "table" then
      options = {}
   end
   local _url = #_path > 0 and _exString.join("/", client:get_url(), _path) or client:get_url()
   if util.is_array(options.params) and #options.params > 1 then
      local _query = _exString.join("&", table.unpack(util.map(options.params, encodeQueryParams)))
      if type(_query) == "string" then
         _url = _url .. '?' .. _query
      end
   end
   return _url, util.merge_tables(options, client.options)
end

function RestClient:get(pathOrOptions, options)
   local _url, options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('GET', _url, options)
end

function RestClient:post(data, pathOrOptions, options)
   local _url, options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('POST', _url, options, data)
end

function RestClient:put(data, pathOrOptions, options)
   local _url, options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('PUT', _url, options, data)
end

function RestClient:patch(data, pathOrOptions, options)
   local _url, options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('PATCH', _url, options, data)
end

function RestClient:delete(pathOrOptions, options)
   local _url, options = _get_request_url_n_options(self, pathOrOptions, options)
   return _request('DELETE', _url, options)
end

print"jere"
print(RestClient)

return generate_safe_functions({
   download_file = download_file,
   download_string = download_string,
   RestClient = RestClient
})