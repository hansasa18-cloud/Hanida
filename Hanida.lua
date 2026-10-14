local SAE = "https://raw.githubusercontent.com/tienkhanh1/Chilli-Hub-Script/refs/heads/main/StealAnEgg"

local byGameId = {
    [10563114921] = SAE,
}

local byPlaceId = {
    [107778070777162] = SAE,
}

local gameId = game.GameId
while gameId == 0 and game.PlaceId == 0 do
    task.wait()
    gameId = game.GameId
end

local url = byGameId[gameId] or byPlaceId[game.PlaceId]
if not url then
    return
end

for _ = 1, 3 do
    local ok, source = pcall(game.HttpGet, game, url)
    if ok and type(source) == "string" and source ~= "" then
        local chunk = loadstring(source)
        if chunk then
            chunk()
        end
        return
    end
    task.wait(0.5)
end
