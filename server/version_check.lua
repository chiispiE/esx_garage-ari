--[[
    ari_garage — server/version_check.lua
    Version: 1.15.3-ari

    Compares the local resource version (from fxmanifest.lua) against the
    latest published release on GitHub and prints a colored message in the
    server console.

    FiveM console color codes:
        ^1 red    ^2 green   ^3 yellow   ^5 cyan   ^6 magenta   ^7 reset
--]]

local RESOURCE  = GetCurrentResourceName()
local LOCAL_VER = GetResourceMetadata(RESOURCE, 'version', 0) or '0.0.0'

-- ─── helpers ──────────────────────────────────────────────────────────────────
local function tag(msg)      return ('^5[%s]^7 %s'):format(RESOURCE, msg) end
local function logInfo(m)    print(tag(m)) end
local function logOk(m)      print(tag('^2' .. m .. '^7')) end
local function logWarn(m)    print(tag('^3' .. m .. '^7')) end

-- Strip suffixes like "-ari", "-beta", "v" prefix → returns { major, minor, patch }
local function parseSemver(v)
    if type(v) ~= 'string' then return { 0, 0, 0 } end
    local clean = v:lower():gsub('^v', ''):gsub('%-.*$', '')
    local maj, min, pat = clean:match('^(%d+)%.(%d+)%.?(%d*)$')
    if not maj then
        maj, min = clean:match('^(%d+)%.(%d+)$')
        pat = '0'
    end
    return {
        tonumber(maj) or 0,
        tonumber(min) or 0,
        tonumber(pat) or 0,
    }
end

-- 1 if a > b, -1 if a < b, 0 if equal
local function compareSemver(a, b)
    local pa, pb = parseSemver(a), parseSemver(b)
    for i = 1, 3 do
        if pa[i] > pb[i] then return  1 end
        if pa[i] < pb[i] then return -1 end
    end
    return 0
end

local function pickRemoteVersion(body)
    if not body or body == '' then return nil end
    local ok, data = pcall(json.decode, body)
    if not ok or type(data) ~= 'table' then return nil end

    if data.tag_name or data.name then
        local v = data.name
        if not v or v == '' then v = data.tag_name end
        return v, data.html_url
    end

    if data[1] and data[1].name then
        local cfg = Config.VersionCheck
        return data[1].name, ('https://github.com/%s/%s/releases/tag/%s'):format(
            cfg.Owner, cfg.Repo, data[1].name)
    end

    return nil
end

local function report(remote, link)
    local cfg = Config.VersionCheck
    if not remote then
        logWarn('Could not parse version from GitHub response.')
        return
    end

    local cmp = compareSemver(remote, LOCAL_VER)
    if cmp > 0 then
        logWarn(('A new version is available: ^3%s^7 (you are running ^3%s^7)'):format(remote, LOCAL_VER))
        if link then logInfo('Release notes: ^5' .. link .. '^7') end
    elseif cmp < 0 then
        if cfg.Verbose then
            logOk(('You are AHEAD of the upstream release (local %s > github %s).'):format(LOCAL_VER, remote))
        end
    else
        if cfg.Verbose then
            logOk(('Up to date (v%s).'):format(LOCAL_VER))
        end
    end
end

local httpHeaders = {
    ['User-Agent'] = RESOURCE,
    ['Accept']     = 'application/vnd.github+json',
}

local function fetch(url, cb)
    PerformHttpRequest(url, function(status, body)
        cb(status, body)
    end, 'GET', '', httpHeaders)
end

local function check()
    do return end -- GitHub API Rate Limit (HTTP 403) fix: Desactivamos la comprobación de versión forzosamente.

    local cfg = Config.VersionCheck
    if not cfg or not cfg.Enabled then return end

    local base = ('https://api.github.com/repos/%s/%s'):format(cfg.Owner, cfg.Repo)
    local releaseUrl = base .. '/releases/latest'
    local tagsUrl    = base .. '/tags'
    local primary    = (cfg.Endpoint == 'tags') and tagsUrl or releaseUrl

    fetch(primary, function(status, body)
        if status == 200 then
            local remote, link = pickRemoteVersion(body)
            report(remote, link)
            return
        end

        -- 404 typically means "no releases published yet" → try /tags
        if status == 404 and primary == releaseUrl then
            fetch(tagsUrl, function(s2, b2)
                if s2 ~= 200 then
                    logWarn(('Version check failed (HTTP %s).'):format(tostring(s2)))
                    return
                end
                local remote, link = pickRemoteVersion(b2)
                report(remote, link)
            end)
            return
        end

        logWarn(('Version check failed (HTTP %s).'):format(tostring(status)))
    end)
end

-- ─── boot ─────────────────────────────────────────────────────────────────────
CreateThread(function()
    -- Small delay so the banner does not get buried by the rest of the boot log
    Wait(2000)
    check()

    local minutes = tonumber(Config.VersionCheck and Config.VersionCheck.IntervalMinutes) or 0
    if minutes > 0 then
        while true do
            Wait(minutes * 60 * 1000)
            check()
        end
    end
end)

-- Manual re-check from the server console: `ari_garage_version`
RegisterCommand('ari_garage_version', function(source)
    if source ~= 0 then return end -- console only
    logInfo(('Local version: ^3%s^7'):format(LOCAL_VER))
    check()
end, true)
