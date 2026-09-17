local _util = {}

---@param data string
---@return string
function _util.compress_string_to_c_bytes(data)
	local _byteArray = table.map(
		table.filter(table.pack(string.byte(lz.compress_string(data), 1, -1)),
			function (k)
				return type(k) == "number"
			end
		),
		function (b)
			return string.format("0x%02x", b)
		end
	)
	return string.join(",", _byteArray)
end

local CA_BUNDLE_URL = "https://ccadb.my.salesforce-sites.com/mozilla/IncludedRootsPEMTxt?TrustBitsInclude=Websites"

function _util.download_ca_bundle(destination)
	local code, err = net.download_file(CA_BUNDLE_URL, destination, {
		follow_redirects = true, followRedirects = true,
		connect_timeout = 30000, read_timeout = 30000,
	})
	if code ~= 200 then
		return false, err or "CA bundle download failed with HTTP " .. tostring(code)
	end
	return true
end

function _util.get_ca_certs(bundle_path)
	local temporary = bundle_path == nil
	bundle_path = bundle_path or os.tmpname()
	if temporary then
		local ok, err = _util.download_ca_bundle(bundle_path)
		assert(ok, err)
	end
	local certs = {}
	local ca = assert(fs.read_file(bundle_path), "failed to read CA bundle " .. bundle_path)
	if temporary then fs.remove(bundle_path) end
	for cert in ca:gmatch"%-%-%-%-%-BEGIN CERTIFICATE%-%-%-%-%-.-%-%-%-%-%-END CERTIFICATE%-%-%-%-%-" do
		local tmp = os.tmpname()
		local resultFile = os.tmpname()
		fs.write_file(tmp, cert .. "\n")
		if not os.execute("openssl x509 -outform der -in " .. tmp .. " -out " .. resultFile) then
			error"Failed to convert certificate to der!"
		end
		local certData = fs.read_file(resultFile)
		table.insert(certs, certData)
		fs.remove(tmp)
		fs.remove(resultFile)
	end
	return certs
end

return _util
