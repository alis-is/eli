local _curlLoaded , curl = pcall(require, "lcurl.safe")
local io = require "io"
local util = require "eli.util"
local generate_safe_functions = util.generate_safe_functions
local merge_tables = util.merge_tables

if not _curlLoaded then
   return nil
end

local function _download(url, write_function, options)
   if type(options) ~= "table" then
      options = {}
   end

   local followRedirects = options.followRedirects or false
   local verifyPeer = options.verify_peer
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

return generate_safe_functions({
   download_file = download_file,
   download_string = download_string
})