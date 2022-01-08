local hjson = require"hjson"
local config = hjson.parse(fs.read_file("config.hjson"))
local log_success, log_info = util.global_log_factory("download", "success", "info")

fs.mkdirp(config.cache_dir)
local _clean = os.getenv("CLEAN") or config.auto_clean

log_info"Downloading dependencies..."

for _, download in ipairs(config.downloads) do 
   if not fs.exists(download.destination) or _clean or download.force then
      log_info("Downloading " .. download.id .. "...")
      local _cached = path.combine(config.cache_dir, download.id .. ".zip")
      local url = download.url
      if not url and download.repository then
         url = "https://github.com/" .. download.repository .. "/archive/" .. download.version .. ".zip"
      end
      net.download_file(url, _cached, { followRedirects = true })
      log_info("Extracting "..  download.id .. " to " .. download.destination .. "...")
      if type(download.clean) == "nil" or download.clean == true then
         fs.remove(download.destination, { recurse = true, followRedirects = false })
      end
      fs.mkdirp(download.destination)
      zip.extract(_cached, download.destination, { flattenRootDir = download.omitRoot })
      if download.cmakelists then
         log_info("Copying " .. path.combine("tools/cmake_files", download.cmakelists.source) .. " to " .. download.cmakelists.destination)
         fs.copy_file(path.combine("tools/cmake_files", download.cmakelists.source), download.cmakelists.destination)
      end
      log_success("Download of " .. download.id .. " completed.")
   end
end

log_success"Dependencies downloaded."