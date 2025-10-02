-- {"id":1915581930,"ver":"1.0.2","libVer":"1.0.0","author":"unTanya"}

---@class Novel
---@field title string
---@field link string
---@field imageURL string
local Novel = Novel

-- Base URL of the website
local baseURL = "https://xiaowaz.fr"

--- Ensure an absolute URL (prefix baseURL when the input is relative like "?p=123" or "articles/...").
---@param url string
---@return string
local function ensureAbsolute(url)
    if not url or url == "" then return url end
    -- Already absolute (http/https)
    if url:match("^https?://") then return url end
    -- Join with baseURL (handles both "?p=..." and "path/..." cases)
    if url:sub(1,1) == "/" then
        return baseURL .. url
    else
        return baseURL .. "/" .. url
    end
end

--- Get passage (chapter content) from a given chapter URL
---@param chapterURL string @Can be absolute or relative ("?p=..."/"articles/...")
---@return string @Cleaned HTML text
local function getPassage(chapterURL)
    -- Always fetch using an absolute URL to avoid "Expected URL scheme" errors
    local absURL = ensureAbsolute(chapterURL)
    local doc = GETDocument(absURL):selectFirst("div.entry-content")
    if doc == nil then
        return "Chapter not found."
    end
    return pageOfElem(doc, true)
end

--- Listing latest chapters through the RSS feed with pagination
---@param data table @Shosetsu passes { [PAGE] = number }
---@return Novel[]
local function latest(data)
    local page = data[PAGE] or 1
    local rssURL = baseURL .. "/index.php/feed/?paged=" .. page
    local rss = GETDocument(rssURL)
    local results = {}
    local items = rss:select("item")

    print("DEBUG: page=" .. page .. " -> found " .. items:size() .. " items in RSS")

    -- Si 0 item → fin immédiate
    if items:size() == 0 then
        return {}
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local titleElem = item:selectFirst("title")
        local guidElem  = item:selectFirst("guid")

        local title = titleElem and titleElem:text() or "Untitled"
        local link  = guidElem and guidElem:text() or ""

        if link ~= "" then
            -- Nettoyage des UTM
            link = link:gsub("%?utm_source.*", "")

            -- Si relatif, normaliser
            if link:match("^%?p=") then
                link = baseURL .. "/articles/" .. link
            end

            -- Chercher la cover une seule fois par œuvre
            local cover = "@icon/Xiaowaz.png"
            local coverImg = GETDocument(link):selectFirst("img.attachment-post-thumbnail")
            if coverImg then
                cover = coverImg:attr("src")
            end

            table.insert(results, Novel {
                title = title,
                link = link,
                imageURL = cover
            })
        end
    end

    -- Si on a trouvé moins de 10 items → fin de pagination
    if items:size() < 10 then
        print("DEBUG: page=" .. page .. " is the last page (found only " .. items:size() .. " items)")
        return {}
    end

    return results
end





--- Parse a "novel" page (actually a single article on Xiaowaz)
---@param novelURL string @Can be absolute or relative
---@return NovelInfo
local function parseNovel(novelURL)
    -- Always expand to absolute before fetching
    local url = ensureAbsolute(novelURL)
    local doc = GETDocument(url)

    local titleElem = doc:selectFirst("h1.entry-title")
    local title = titleElem and titleElem:text() or "Chapter"

    -- Try to get a cover if present on the article page
    -- (class often used: "attachment-post-thumbnail size-post-thumbnail wp-post-image")
    local imgElem = doc:selectFirst("img.attachment-post-thumbnail")
    local cover = (imgElem and imgElem:attr("src") and imgElem:attr("src") ~= "") and imgElem:attr("src") or "@icon/Xiaowaz.png"

    return NovelInfo {
        title = title,
        description = title,
        imageURL = cover,
        chapters = AsList({
            NovelChapter {
                title = title,
                link = novelURL, -- keep original; getPassage will ensureAbsolute() before fetching
            }
        })
    }
end

-- Main extension export
return {
    id = 1915581930,
    name = "Xiaowaz",
    baseURL = baseURL,
    imageURL = "https://gitlab.com/shosetsuorg/extensions/-/raw/dev/icons/Xiaowaz.png",

    listings = {
        Listing("Latest Chapters", true, latest)
    },

    parseNovel = parseNovel,
    getPassage = getPassage,
    chapterType = ChapterType.HTML,

    -- Keep shrink/expand, but make them tolerant with absolute URLs.
    shrinkURL = function(url, _)
        if not url or url == "" then
            return url
        end
        if url:sub(1, #baseURL) == baseURL then
            return url:gsub(baseURL .. "/", "")
        end
        return url
    end,

    expandURL = function(url, _)
        -- If it's already absolute, return as-is
        if url and url:match("^https?://") then
            return url
        end
        -- Otherwise, prefix baseURL safely
        if url and url:sub(1, 1) == "/" then
            return baseURL .. url
        else
            return baseURL .. "/" .. (url or "")
        end
    end,

    hasSearch = false,
}