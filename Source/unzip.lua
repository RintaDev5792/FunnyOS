import("zzlib/zzlib") -- NOTE: replace with valid path to zzlib!

local pd <const> = playdate

---unzip zip file at path into directory dir. if dir is nil, extracts to data directory of application.
---requires zzlib.
---
---@param path any
---@param dir any
function unzip(path, dir)
  local function stringsplit(inputstr, sep)
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
      table.insert(t, str)
    end

    return t
  end

  local function makedirs(root, dir)
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

  dir = dir or ""

  if pd.file.exists(path) then
    local f, err = pd.file.open(path)

    if f then
      local data = f:read(pd.file.getSize(path))

      pd.file.mkdir(dir)

      for _, name, offset, size, packed, crc in zzlib.files(data) do
        if packed then
          makedirs(dir, name)

          local pf, err = pd.file.open(dir .. "/" .. name, pd.file.kFileWrite)

          if pf then
            pf:write(zzlib.unzip(data, offset, crc))

            pf:close()
          else
            return false, err
          end
        end
      end

      return true
    end

    return false, err
  end

  return false, "file not found"
end

