local signal = require"os.signal"

signal.handle(2, function ()
	os.exit(0)
end)
signal.reset(2)

signal.raise(2)
