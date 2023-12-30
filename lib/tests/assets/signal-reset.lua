local signal = require"os.signal"

signal.handle(10, function ()
	os.exit(0)
end)
signal.reset(10)

signal.raise(10)
