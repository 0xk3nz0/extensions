-- {"id":99001,"ver":"1.0.0","libVer":"1.0.0","author":"k3nz0","repo":"","dep":[]}

local baseURL = "https://free.kolnovel.com"

local id = 99001
local name = "kolnovel"
local imageURL = "https://i.pinimg.com/736x/08/7c/59/087c5951d512a407871ee330e5222554.jpg"
local hasSearch = true
local isSearchIncrementing = true
local chapterType = ChapterType.HTML
local startIndex = 1

-- helpers
local function getHiddenClasses(doc)
    local classes = {}
    local styles = doc:select("style")
    for i = 0, styles:size() - 1 do
        local s = styles:get(i)
        if s:html():find("text%-indent: %-99999px") then
            local line = s:html():match("\n([^\n]+)\n")
            if line then
                for cls in line:gmatch("%.([a-z0-9]+)") do
                    classes[cls] = true
                end
            end
            break
        end
    end
    return classes
end

local function getVisibleParagraphs(doc, hiddenClasses)
    local result = {}
    local paragraphs = doc:select("#kol_content p")
    for i = 0, paragraphs:size() - 1 do
        local p = paragraphs:get(i)
        local cls = p:attr("class")
        if cls == "" or not hiddenClasses[cls] then
            table.insert(result, p:text())
        end
    end
    return result
end

-- must be before parseNovel and listings
local function shrinkURL(url, type)
    return url:gsub(baseURL, "")
end

local function expandURL(url, type)
    return baseURL .. url
end

local function getPassage(chapterURL)
    local doc = GETDocument(expandURL(chapterURL, KEY_CHAPTER_URL))
    local hiddenClasses = getHiddenClasses(doc)
    local paragraphs = getVisibleParagraphs(doc, hiddenClasses)
    local html = ""
    for _, text in ipairs(paragraphs) do
        if not text:find("kolnovel") and not text:find("إقرأ") then
            html = html .. "<p>" .. text .. "</p>"
        end
    end
    return html
end

local function parseNovel(novelURL)
    local doc = GETDocument(expandURL(novelURL, KEY_NOVEL_URL))
    
    local title = doc:selectFirst(".entry-title"):text()
    local cover = doc:selectFirst(".ts-post-image"):attr("src")
    local author = doc:selectFirst(".sertoauth .serl:nth-child(3) .serval"):text()
    local status = doc:selectFirst(".sertostat"):text()
    local description = doc:selectFirst(".sersys p"):text()

    local chapters = {}
    local items = doc:select(".ts-chl-collapsible-content li a")
    for i = 0, items:size() - 1 do
        local a = items:get(i)
        table.insert(chapters, NovelChapter {
            title = a:selectFirst(".epl-title"):text(),
            link = shrinkURL(a:attr("href")),
            order = i,
        })
    end

    local reversed = {}
    for i = #chapters, 1, -1 do
        table.insert(reversed, chapters[i])
    end

    return NovelInfo {
        title = title,
        imageURL = cover,
        authors = { author },
        status = NovelStatus(status),
        description = description,
        chapters = reversed,
    }
end

local function search(data)
    local page = data[PAGE]
    local query = data[QUERY]
    local doc = GETDocument(baseURL .. "/series/?page=" .. page .. "&s=" .. query)
    local novels = {}
    local cards = doc:select(".listupd article")
    for i = 0, cards:size() - 1 do
        local card = cards:get(i)
        local a = card:selectFirst("a")
        local img = card:selectFirst("img")
        local title = card:selectFirst("h2[itemprop=headline]")
        table.insert(novels, Novel {
            title = title:text(),
            imageURL = img:attr("src"),
            link = shrinkURL(a:attr("href")),
        })
    end
    return novels
end

local listings = {
    Listing("الأحدث", true, function(data)
        local page = data[PAGE]
        local doc = GETDocument(baseURL .. "/series/?page=" .. page)
        local novels = {}
        local cards = doc:select(".listupd article")
        for i = 0, cards:size() - 1 do
            local card = cards:get(i)
            local a = card:selectFirst("a")
            local img = card:selectFirst("img")
            local title = card:selectFirst("h2[itemprop=headline]")
            table.insert(novels, Novel {
                title = title:text(),
                imageURL = img:attr("src"),
                link = shrinkURL(a:attr("href")),
            })
        end
        return novels
    end)
}

return {
    id = id,
    name = name,
    baseURL = baseURL,
    imageURL = imageURL,
    hasSearch = hasSearch,
    isSearchIncrementing = isSearchIncrementing,
    chapterType = chapterType,
    startIndex = startIndex,
    listings = listings,
    getPassage = getPassage,
    parseNovel = parseNovel,
    search = search,
    shrinkURL = shrinkURL,
    expandURL = expandURL,
}