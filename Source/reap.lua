-- reap: a simple manual update-based zip file extractor by nanobot567
-- v1.0
--
-- depends on a slightly modified version of zzlib (available at https://github.com/zerkman/zzlib)

import "CoreLibs/object"
import "zzlib/zzlib" -- NOTE: replace with valid path to modified zzlib!

local pd <const> = playdate

---@class Reap
Reap = {}
class("Reap").extends()

local function stringsplit(inputstr, sep)
  print("stringsplit")
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end

  return t
end

local function bytes_to_int(str, endian) -- from https://stackoverflow.com/questions/5241799/lua-dealing-with-non-ascii-byte-streams-byteorder-change
  print("bytes_to_int")
  local t = { str:byte(1, -1) }
  if endian ~= "big" then
    local tt = {}
    for k = 1, #t do
      tt[#t - k + 1] = t[k]
    end
    t = tt
  end
  local n = 0
  for k = 1, #t do
    n = (n << 8) | t[k]
  end
  return n
end

local function makedirs(root, dir)
  print("makedirs")
  local spl = stringsplit(dir, "/")

  table.remove(spl, #spl)

  for i, v in ipairs(spl) do
    local ns = ""

    for d = 1, i do
      ns = ns .. "/" .. spl[d]
    end

    pd.file.mkdir(root .. "/" .. ns)
  end
end

local function hexencode(str)
  print("hexencode")
  return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
end

local function readZipEOCD(path)
  print("readzipeocd")
  local f = pd.file.open(path)
  local fsize = pd.file.getSize(path)

  f:read(4)
  local zip_version = bytes_to_int(f:read(2))

  f:seek(fsize - 10, pd.file.kSeekSet) -- jump to nearly the end of the file to find EOCD information

  local eocdSize = bytes_to_int(f:read(4))
  local eocdOffset = bytes_to_int(f:read(4))

  f:seek(fsize - eocdOffset, pd.file.kSeekSet)

  -- local eocdData = f:read(eocdSize)

  local files = {}
  local readingEOCD = true

  f:seek(eocdOffset, pd.file.kSeekSet)

  -- TODO: there may be some more zip versions that haven't been accounted for!

  if zip_version == 788 then
    f:seek(-1, pd.file.kSeekFromCurrent) -- this is so dumb.. but for some reason eocdOffset - 1 doesn't work in f:seek()
  end

  -- if zip_version == 20 then -- NOTE: i must not be accounting for something if this sort of stuff is needed.. same for the header length modifications at the bottom
  --   f:seek(1, pd.file.kSeekFromCurrent)
  -- end

  -- TODO: doesn't work if comments are placed at the end of zip file

  while readingEOCD do
    print("loopingEOCD")
    local tmp = {}
    local header = f:read(4) -- read header

    if header == "\x50\x4b\x05\x06" then -- end of actual EOCD block
      readingEOCD = false
    elseif header == "\x50\x4b\x01\x02" then -- file metadata block, good to go :thumbsup:
      tmp.version_made = bytes_to_int(f:read(2)) -- version made
      tmp.version_extract = bytes_to_int(f:read(2)) -- version extract (extract with this version in mind)

      local v = tmp.version_extract

      tmp.flags = f:read(1) -- various flags
      tmp.flags2 = f:read(1) -- various flags 2.0 (the sequel)
      tmp.compression_method = bytes_to_int(f:read(2)) -- compression method, there are many of these but only none (0) and DEFLATE (8) are supported i believe
      tmp.last_modified_time = f:read(2) -- file last modified time
      tmp.last_modified_date = f:read(2) -- file last modified date
      tmp.crc32 = f:read(4) -- crc32
      tmp.compressed_file_size = bytes_to_int(f:read(4)) -- compressed file size
      tmp.uncompressed_file_size = bytes_to_int(f:read(4)) -- uncompressed file size
      tmp.file_name_length = bytes_to_int(f:read(2)) -- file name length
      tmp.extra_field_length = bytes_to_int(f:read(2)) -- extra field length
      tmp.file_comment_length = bytes_to_int(f:read(2)) -- file comment length
      tmp.disk_number = bytes_to_int(f:read(2)) -- disk number
      tmp.internal_file_attributes = f:read(2) -- internal file attributes
      tmp.external_file_attributes = f:read(4) -- external file attributes
      tmp.file_offset = bytes_to_int(f:read(4)) -- file offset
      tmp.file_name = f:read(tmp.file_name_length) -- file name
      f:read(tmp.extra_field_length) -- can skip all of the extra fields, as they won't really matter-

      tmp.header_length = 34 + tmp.file_name_length + tmp.extra_field_length

      if zip_version == 20 then
        tmp.header_length = tmp.header_length - 4
      end

      for k, v in pairs(tmp) do
        if type(v) == "string" and k ~= "file_name" then
          tmp[k] = bytes_to_int(v)
        end
      end

      table.insert(files, table.deepcopy(tmp))
    else
      print("invalid header: " .. hexencode(header))
      return nil
    end
  end
  print("doneLoopingEOCD")
  return files
end


function Reap:init(path, dir, chunkSize)
  print("reapinit")
  dir = dir or ""
  chunkSize = chunkSize or 10000

  self.path = path
  self.dir = dir
  self.chunkSize = chunkSize

  self.names = {}
  self.offsets = {}
  self.packeds = {}
  self.crcs = {}
  self.sizes = {}

  self.currentDataOffset = 0

  self.step = 1

  self.totalFiles = 0

  self.done = false

  if pd.file.exists(path) then
    local f, err = pd.file.open(path)

    if f then
      self.EOCD = readZipEOCD(path)

      pd.file.mkdir(dir)
    end
  end
end

local cur

-- call once every update cycle
function Reap:update()
  print("reapUpdate")
  if not self.done then
    if not self.EOCD then return false,"BAD HEADER" end
    cur = self.EOCD[self.step]

    if cur.compression_method == 8 then
      makedirs(self.dir, cur.file_name)

      local f, err = pd.file.open(self.path)
      local pf, err = pd.file.open(self.dir .. "/" .. cur.file_name, pd.file.kFileWrite)

      f:seek(cur.file_offset, pd.file.kSeekSet)
      local data = f:read(cur.compressed_file_size + cur.header_length)
      f:close()

      if pf then
        pf:write(zzlib.unzip(data, cur.header_length + 1, cur.crc32))

        pf:close()
      else
        return false, err
      end
    end

    self.step += 1

    if self.step == #self.EOCD then
      self.done = true
      return true
    end
  end
end

-- returns completion status as a percentage (0-100)
function Reap:getPercentComplete()
  print("reapgetpercentcomplete")
  if self.step and self.EOCD then
    return (self.step / #self.EOCD) * 100
  end

  return 0
end

-- returns progress step, then total
function Reap:getProgress()
  print("reapgetprogress")
  if self.step and self.EOCD then
    return self.step, #self.EOCD
  end

  return 0, 0
end
