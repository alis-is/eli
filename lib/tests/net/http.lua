local test = TEST or require"u-test"

test["http request options"] = function ()
	local loaded_http = package.loaded["eli.net.http"]
	local loaded_corehttp = package.loaded.corehttp
	local captured
	local response = {
		headers = function () return {} end,
		http_status_code = function () return 200 end,
		status_code = function () return 0 end,
		read_content = function () return "ok" end,
	}
	local corehttp = {
		HEADERS_METATABLE = {},
		new_client = function (scheme, host)
			return {
				endpoint = function () return scheme .. "://" .. host end,
				request = function (_, _, _, options)
					captured = options
					return response
				end,
			}
		end,
	}

	package.loaded.corehttp = corehttp
	package.loaded["eli.net.http"] = nil
	local http = require"eli.net.http"
	local client = assert(http.RestClient:new("https://example.com"))
	local result, err = client:post("raw", {
		drgb_seed = "test-seed",
		use_bundled_root_certificates = false,
		headers = { ["Content-Type"] = "application/octet-stream" },
	})

	package.loaded["eli.net.http"] = loaded_http
	package.loaded.corehttp = loaded_corehttp

	test.assert(result, err)
	test.equal(captured.drgb_seed, "test-seed")
	test.is_false(captured.use_bundled_root_certificates)
	test.equal(captured.body, "raw")

	http.set_default_buffer_capacity(1)
	result, err = client:get()
	test.assert(result, err)
	test.equal(captured.buffer_size, 1024)
end

if not TEST then test.summary() end
