local test = TEST or require"u-test"
local ok, base64 = pcall(require, "base64")

if not ok then
	test["base64 available"] = function ()
		test.assert(false, "base64 not available")
	end
	if not TEST then
		test.summary()
		os.exit()
	else
		return
	end
end

test["base64 available"] = function ()
	test.assert(true)
end

test["base64.encode"] = function ()
	local data = "Hello, world!"
	local encodedData, err = base64.encode(data)
	assert(err == nil, "Error occurred while encoding data: " .. tostring(err))
	assert(encodedData == "SGVsbG8sIHdvcmxkIQ==", "Encoded data is incorrect")
end

test["base64.decode"] = function ()
	local encodedData = "SGVsbG8sIHdvcmxkIQ=="
	local decodedData, err = base64.decode(encodedData)
	assert(err == nil, "Error occurred while decoding data: " .. tostring(err))
	assert(decodedData == "Hello, world!", "Decoded data is incorrect")

	local encodedData = "SGVsbG8sIHdvc"
	local decodedData, err = base64.decode(encodedData)
	assert(err ~= nil, "Error occurred while decoding data: " .. tostring(err))
	assert(decodedData == nil, "Decoded data is incorrect")
	-- Test for invalid character
	encodedData = "SGVsbG8sIHdvcmxkIQ!@"
	decodedData, err = base64.decode(encodedData)
	assert(err ~= nil, "Invalid character not detected while decoding data")
	assert(decodedData == nil, "Decoded data should be nil when there is an error")
end



if not TEST then
	test.summary()
end
