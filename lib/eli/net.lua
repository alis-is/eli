local fetchLoaded, _fetch = pcall(require, "lfetch") -- "lcurl.safe"
local io = require "io"
local util = require "eli.util"
local generate_safe_functions = util.generate_safe_functions
local merge_tables = util.merge_tables

local function _download(url, write_function, options)
   if not fetchLoaded then
      error("Networking not available!")
   end

   local flags = ""
   if type(options) == "table" then
      if options.verbose then
         flags = flags .. "v"
      end
      if type(options.verifyPeer) == "boolean" and not options.verifyPeer then
         flags = flags .. "p"
      end
      if type(options.additionalFlags) == "string" then
         flags = flags .. additionalFlags
      end
   end

   local _fetchIO, _error, _code = _fetch.get(url, flags)
   if _fetchIO == nil then
      return nil, _error, _code
   end

   while true do
      local _chunk, _error, _code = _fetchIO:read(1024)
      if _chunk == nil then
         return nil, _error, _code
      end
      if #_chunk == 0 then
         break
      end
      write_function(_chunk)
   end

   return true
end

local function _get_retry_limit(options)
   local _retryLimit = tonumber(os.getenv("ELI_TLS_HANDSHAKE_RETRY_LIMIT")) or 0
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

      local _ok, _error, _code = _download(url, _write, options)
      if _ok then 
         _df:close()
         break
      elseif (_tries >= _retryLimit or _code ~= 15) then -- 15 => FETCH_TIMEOUT
         error(_error)
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

      local _ok, _error, _code = _download(url, _write, options)
      if _ok then
         return _result
      elseif (_tries >= _retryLimit or _code ~= 15) then
         error(_error)
      end
      _tries = _tries + 1
   end
end

local net = {
   download_file = download_file,
   download_string = download_string
}

if type(_fetch.set_tls_option) ~= "function" then
   return generate_safe_functions(net)
end

local function _set_timeout(timeout)
   _fetch.set_tls_option("readTimeout", timeout)
end

local function _set_mtu(mtu)
   _fetch.set_tls_option("mtu", mtu)
end

local _mtu = tonumber(os.getenv("ELI_TLS_MTU")) or 0
local _tlsReadTimeout = tonumber(os.getenv("ELI_TLS_READ_TIMEOUT")) or 0
_set_timeout(_tlsReadTimeout)
_set_mtu(_mtu)

return generate_safe_functions(
   merge_tables(
      net,
      {
         set_tls_timeout = _set_timeout,
         set_tls_mtu = _set_mtu,
         OPTIONS_AVAILABLE = true
      }
   )
)
