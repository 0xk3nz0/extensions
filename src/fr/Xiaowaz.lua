-- {"id":1915581930,"ver":"1.0.2","libVer":"1.0.0","author":"unTanya"}

local baseURL = "https://xiaowaz.fr"

---@class Novel
---@field title string
---@field link string
---@field imageURL string
local Novel = Novel

local function ensureAbsolute(url)
    if not url or url == "" then return url end
    if url:match("^https?://") then return url end
    if url:sub(1,1) == "/" then
        return baseURL .. url
    else
        return baseURL .. "/" .. url
    end
end

--- Nettoie le contenu du chapitre
local function getPassage(chapterURL)
    local absURL = ensureAbsolute(chapterURL)
    local doc = GETDocument(absURL)
    local content = doc:selectFirst("div.entry-content")
    if not content then return "Chapter not found." end
    -- remove unwanted blocks
    content:select("div.wp-post-navigation"):remove()
    content:select("div.abh_box"):remove()
    return pageOfElem(content, true)
end

--- Listing depuis le flux RSS mais redirige vers la page série
local function latest(data)
    local page = data[PAGE] or 1
    local rssURL = baseURL .. "/index.php/feed/?paged=" .. page
    local rss = GETDocument(rssURL)
    local results = {}
    local items = rss:select("item")

    print("DEBUG latest: page="..page.." found "..items:size().." items")

    if items:size() == 0 then return {} end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local title = item:selectFirst("title"):text()
        local link  = item:selectFirst("guid"):text():gsub("%?utm_source.*","")

        -- aller chercher la page d’article
        local artDoc = GETDocument(link)
        local cat = artDoc:select("span.cat-links a")
        local seriesLink, seriesName = nil, nil
        for j=0,cat:size()-1 do
            local a = cat:get(j)
            local href = a:attr("href")
            if href:find("/articles/category/series/") then
                seriesLink = href
                seriesName = a:text()
                break
            end
        end

        if seriesLink then
            print("DEBUG latest: novel="..seriesName.." seriesLink="..seriesLink)

            local cover = "@icon/Xiaowaz.png"
            local coverImg = artDoc:selectFirst("img.attachment-post-thumbnail")
            if coverImg then cover = coverImg:attr("src") end

            table.insert(results, Novel {
                title = seriesName,
                link = seriesLink,
                imageURL = cover
            })
        else
            print("DEBUG latest: skipped article (no series) title="..title)
        end
    end

    return results
end

--- Parse la page série
local function parseNovel(novelURL)
    local url = ensureAbsolute(novelURL)
    print("DEBUG parseNovel: url="..url)

    local doc = GETDocument(url)
    local titleElem = doc:selectFirst("h1.entry-title")
    local title = titleElem and titleElem:text() or "Unknown series"

    local coverElem = doc:selectFirst("img.attachment-post-thumbnail")
    local cover = "@icon/Xiaowaz.png"
    if coverElem then
        local src = coverElem:attr("src")
        if src and src ~= "" then
            cover = src
        end
    end
    print("DEBUG parseNovel: cover="..cover)


    local chapters = {}
    local fairy = doc:selectFirst("div.fairy-content-area")
    if fairy then
        local articles = fairy:select("article")
        print("DEBUG parseNovel: found "..articles:size().." articles")
        for i=0, articles:size()-1 do
            local h2 = articles:get(i):selectFirst("h2.card_title a")
            if h2 then
                local chapTitle = h2:text()
                local chapLink  = h2:attr("href")
                print("DEBUG parseNovel: chapter["..i.."] "..chapTitle.." -> "..chapLink)
                table.insert(chapters, NovelChapter {
                    title = chapTitle,
                    link = chapLink
                })
            end
        end
    else
        print("DEBUG parseNovel: no fairy-content-area")
    end

    return NovelInfo {
        title = title,
        description = title,
        imageURL = cover,
        chapters = AsList(chapters)
    }
end

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

    shrinkURL = function(url,_)
        if not url or url == "" then return url end
        if url:sub(1,#baseURL) == baseURL then
            return url:gsub(baseURL.."/","")
        end
        return url
    end,

    expandURL = function(url,_)
        if url and url:match("^https?://") then return url end
        if url and url:sub(1,1) == "/" then return baseURL..url end
        return baseURL.."/"..(url or "")
    end,

    hasSearch = false,
}
