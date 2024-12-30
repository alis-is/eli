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

function _util.get_ca_certs()
	local tmp = os.tmpname()
	-- // TODO: remove 'followRedirects' in the next version
	net.download_file("https://ccadb.my.salesforce-sites.com/mozilla/IncludedRootsPEMTxt?TrustBitsInclude=Websites", tmp,
		{ follow_redirects = true, followRedirects = true })
	local certs = {}
	local ca = fs.read_file(tmp)
	fs.remove(tmp)
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
	fs.remove(tmp)
	return certs
end

return _util
