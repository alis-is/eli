local test = TEST or require"u-test"
local socket = require"socket"

test["TLS CA certificate options accept multiple entries"] = function ()
	local certificates = {}
	for i = 1, 100 do
		certificates[i] = "invalid certificate"
	end
	local connection, err = socket.connect("127.0.0.1", 1, "tls", {
		ca_certificates = certificates,
		connect_timeout = 100,
		use_bundled_root_certificates = false,
	})
	test.assert(connection == nil and type(err) == "string", tostring(err))
end

if not TEST then
	test.summary()
end
