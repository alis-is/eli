local ipc_core = require"ipc.core"
local signal = require"os.signal"
local table_extensions = require"eli.extensions.table"

---@class IPCSocketReadOptions
---@field timeout number? @timeout in milliseconds
---@field buffer_size number? @size of the buffer in bytes

---@class IPCSocket
---@field write fun(self: IPCSocket, data: string): boolean
---@field read fun(self: IPCSocket, options: IPCSocketReadOptions): string
---@field close fun(self: IPCSocket)
---@field is_nonblocking fun(self: IPCSocket): boolean
---@field set_nonblocking fun(self: IPCSocket, nonblocking: boolean)
---@field get_peer_name fun(self: IPCSocket): string

---#DES 'IPCServer'
---
---@class IPCServer
---@field process_events fun(self: IPCServer, handlers: IPCHandlers, options?: IPCServerOptions): boolean
---@field close fun(self: IPCServer, closeClients: boolean?)
---@field get_clients fun(self: IPCServer): IPCSocket[]
---@field get_client_limit fun(self: IPCServer): number

---@class IPCServerOptions
---@field max_clients number? @maximum number of clients
---@field buffer_size number? @size of the buffer in bytes
---@field timeout number? @timeout in milliseconds
---@field is_stop_requested (fun(): boolean)? @function that returns true if stop is requested

---#DES 'IPCHandlers'
---
---@class IPCHandlers
---@field data fun(socket: IPCSocket, msg: string)?
---@field accept fun(socket: IPCSocket)?
---@field error fun(source: string, err: any, socket?: IPCSocket)?
---@field disconnected fun(socket: IPCSocket)?

---#DES 'ipc.core.listen'
---
---@param path string
---@param options IPCServerOptions?
---@return IPCServer

---#DES 'ipc.core.connect'
---
---@param path string
---@return IPCSocket

local ipc = {}

---#DES 'ipc.listen'
---
--- Listens for incoming connections on the given path and calls the handlers
---@param path string @path to the socket on linux or name of the pipe on windows
---@param handlers IPCHandlers
---@param options IPCServerOptions?
---@return boolean, string?
function ipc.listen(path, handlers, options)
	local _, is_main_thread = coroutine.running()

	local server, err = ipc_core.listen(path, options)
	if not server then
		return false, err
	end

	signal.handle(signal.SIGPIPE, signal.IGNORE_SIGNAL) -- ignore SIGPIPE, ignore works even if signal isnt defined on the platform - no-op

	coroutine.yield(server)

	local is_stop_requested = table_extensions.get(options --[[@as table]], "is_stop_requested",
		function () return false end) --[[@as fun(): boolean]]

	while not is_stop_requested() do
		local ok, err = server:process_events(handlers, options)
		if not is_main_thread then
			coroutine.yield(ok, err)
		elseif not ok then
			if type(handlers.error) == "function" then
				handlers.error("internal", err)
			end
		end
	end
end

---#DES 'ipc.connect'
---
--- Connects to the given path and returns the socket
---@param path string @path to the socket on linux or name of the pipe on windows
---@return IPCSocket?, string?
function ipc.connect(path)
	local client, err = ipc_core.connect(path)
	if not client then
		return nil, err
	end
	return client
end

return ipc
