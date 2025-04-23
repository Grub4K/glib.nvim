local M = {}

---@param list string[] The list to convert to an iterable
---@return fun():string?
local function iter_list(list)
    local index = 0
    local count = #list
    return function()
        index = index + 1
        return index <= count and list[index] or nil
    end
end

---@param candidates fun():string? The current candidates
---@param pattern string The filter string to search for
---@param file? boolean Additionally filter by directory
---@return fun():string?
local function gen_candidates(candidates, pattern, file)
    local opts = {}
    local filter_func = nil
    local return_candidate = false
    local is_recursive = pattern:gmatch("%*%*")() ~= nil

    if is_recursive then
        if pattern ~= "**" then
            error("glob: invalid pattern: "..pattern, 4)
        end
        if file then
            error("glob: cannot use ** as final item")
        end

        opts.depth = math.huge
        filter_func = function(_, ftype)
            return ftype == "directory"
        end
        return_candidate = true
    else
        local matcher = vim.glob.to_lpeg(pattern)
        filter_func = function(name, ftype)
            if (ftype == "directory") == file then
                return false
            end
            return matcher:match(name) ~= nil
        end
    end

    local candidate = nil
    local iter = function() return nil end
    return function()
        while true do
            local name, ftype = iter()
            if name == nil or ftype == nil then
                candidate = candidates()
                if candidate == nil then
                    return nil
                end
                iter = vim.fs.dir(candidate, opts)
                if return_candidate then
                    return candidate
                end
            elseif filter_func(name, ftype) then
                return ("%s/%s%s"):format(
                    candidate == "/" and "" or candidate,
                    name,
                    (not is_recursive and file == false) and "/" or "")
            end
        end
    end
end

---Iterate a glob
---If the glob ends with a `/`, it will only match directories.
---
---The following special syntax for path segments is implemented:
--- - `?`: matches any one character
--- - `*`: matches any number of characters, including none
--- - `**`: matches any number of path segments, including none
--- - `{,}`: matches each comma separated literal, eg. `{a,b}` matches both `a` and `b`
--- - `[]`: matches a range of characters, e.g. `[0-9]` matches `0`, `1`, `2`, ...
--- - `[!]`: matches anything but a range of characters, eg. `[!0-9]` matches `a`, `b` but not `0`
---
---See also: https://neovim.io/doc/user/lua.html#_lua-module:-vim.glob
---@param glob string The glob to find items for
---@return fun():string?
function M.iter(glob)
    local items = vim.iter(glob:gmatch("([^/]+)")):totable()
    if #items < 1 then
        return function () return nil end
    end

    local candidates = iter_list({ vim.startswith(glob, "/") and "/" or "." })

    for filter in vim.iter(items):rskip(1) do
        candidates = gen_candidates(candidates, filter)
    end

    return gen_candidates(candidates, items[#items], not vim.endswith(glob, "/"))
end

return M

