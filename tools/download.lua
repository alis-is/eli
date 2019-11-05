local fs = require"eli.fs"
local mkdirp = fs.mkdirp
local readfile = fs.readfile
local copyfile = fs.copyfile
local delete = fs.delete

local downloadfile = require"eli.net".downloadfile
local extract = require"eli.zip".extract
local separator = require"eli.path".default_sep()
local hjson = require"hjson"

local configFile = readfile("config.hjson")
local config = hjson.parse(configFile)

local os = require"os"

lfs.mkdir(config.cache_dir)
clean = os.getenv("CLEAN") or config.auto_clean

for _, download in ipairs(config.downloads) do 
   if lfs.attributes(download.destination) == nil or clean then
      print("Downloading " .. download.id .. "...")
      local cached = config.cache_dir .. separator .. download.id .. ".zip"
      local url = download.url
      if not url and download.repository then
         url = "https://github.com/" .. download.repository .. "/archive/" .. download.version .. ".zip"
      end
      downloadfile(url, cached, { follow_redirects = true })
      print("Extracting " .. download.id .. "...")
      delete(download.destination, true)
      mkdirp(download.destination)
      extract(cached, download.destination, download.omitRoot)
      if download.cmakelists then
         copyfile("cmake_files" .. separator .. download.cmakelists.source, download.cmakelists.destination)
      end
      print("Download of " .. download.id .. " completed.")
   end
end

