# GameWire — handoff notes

iOS gaming-news app (SwiftUI). The owner's first App Store app; free, no monetization. The owner is new to
iOS development: explain in plain language, keep answers short, show ASCII mockups for UI choices.

## Working with the owner
- **Owner commits and pushes himself** (Xcode → Integrate). Don't commit or push unless asked; draft commit
  messages when a feature is done. Repo: https://github.com/Swifty1235/GameWire (branch `main`).
- He runs the app on his own iPhone. Build + simulator checks are still worth doing before saying "done".
- Ignore `~/Documents/GameWire` — an unused Xcode template. The real project is `~/Developer/GameWire`.

## Project
- Xcode 27.2, deployment target iOS 18.0, iPhone only, Swift 5 mode.
- Project uses **file-system synchronized groups**: new files under `GameWire/` are picked up automatically.
- Bundle ID `com.pedroromero.GameWire`.
- Build: `xcodebuild -project GameWire.xcodeproj -scheme GameWire -destination "id=73502E65-08BF-41D8-849A-4A2CC6B094DA" -derivedDataPath build build`
  (simulator = iPhone 18 Pro, iOS 27.2; app id `com.pedroromero.GameWire`).

## Design decisions (owner chose these — don't revert)
- Clean native iOS look, light + dark mode. **No** neon/"gamer" styling.
- Accent **orange #FF7A00** (`Assets → AccentColor`, `Theme.accent`).
- Header: bold italic **GAME**WIRE logo ("WIRE" orange) + gear button; no date. Nav bar hidden on Home.
- Home = **Reddit-style feeds** (no sections inside a feed). Post: source logo · name · time / orange type label
  ("News", "Patch notes") / title / image / Save · Share · ⋯ (hide source).
- Website-only posts: link-preview card (image + "🧭 site.com ↗" bar) and a dark **"Web" badge on the image**
  (no orange outline — owner removed it).
- Source logos as small white rounded tiles. Tabs: Home (built), My Games / Releases / Deals (placeholders).
- Home has two top tabs as **two slim pills splitting the width in half** (selected = filled orange, white
  text; other = light gray). Switching = instant color swap (0.1s fade) + selection haptic; owner found the
  sliding pill ugly/slow. Pinned, but **hide while scrolling down, reappear on scroll up** (`onScrollGeometryChange`): **Discover** (default; all news +
  popular games, followed games boosted) and **My Games** (only followed games: their Steam posts + outlet
  headlines naming them). Owner chose the name "My Games" even though the bottom tab shares it; may rename
  the bottom tab later. Empty My Games → "No games yet" + orange **Find Games** button.
- Following: ⋯ menu on a game's Steam post → Follow/Unfollow; `FindGamesView` sheet (from Home) =
  search + popular games. Follow/Following capsule = `FollowButton`.
- **My Games tab** (`Views/MyGames/MyGamesView`): box art grid, 3 per row, newest follow first; search bar
  always visible ("Add a game"); long-press cover → Unfollow; empty → "No games yet" + Add Games (focuses
  search). Later: tap a game → game page + notification settings (owner wants notifications set here).

## How the feed works (`Services/`)
- `Sources.swift`: 8 outlets (RSS) + 6 `popularGames` (shown in Discover even when not followed).
  `[SteamGame].anyAbout(post)` = the game's own post or a headline naming it (whole words, aliases).
- `Models/Game.swift`: any-platform game (igdbID?, steamAppID?, coverImageID, year, platforms, aliases).
  Decodes old saved follows (`appID` key). `isSame(as:)` matches IGDB id, then Steam id, then name.
  `coverURL` = IGDB `t_cover_big_2x` or Steam `library_600x900_2x.jpg`. `headlineNames` = how headlines name
  games: no leading "The", Roman numerals → numbers (GTA VI → 6; not "X"), short forms (GTA, CoD, WoW, CS,
  FF), long subtitles ("Tears of the Kingdom"), and the main title when the subtitle is an edition
  ("Minecraft: Java Edition" → "Minecraft"). Bug found on device: "Grand Theft Auto VI" matched 0 "GTA 6"
  headlines before this. Newly followed Steam games are fetched immediately (`fetchNewlyFollowedGames`). Only Steam games get Steam news.
- `FollowStore.swift`: `@Observable`, followed `[Game]` saved as JSON in UserDefaults (`followedGames`);
  injected with `.environment` in `GameWireApp`.
- **Game search** (all platforms) = IGDB via a **Supabase Edge Function** (`supabase/functions/igdb-search`,
  TypeScript): holds the Twitch Client ID/Secret as Supabase secrets (never in the app), caches searches
  in memory (IGDB limit 4 req/s), filters out DLC/editions, ranks exact/prefix matches then popularity,
  returns {igdbID, name, coverImageID, year, platforms, steamAppID}. App side: `GameSearch.swift`
  (`SupabaseConfig.url` / `publicKey` = publishable key — public by design).
  Supabase project ref `rvxucodpumyiuqffbvwo` (GameWire, us-west-2, free plan; JWT verification OFF for
  igdb-search). Secrets: `TWITCH_CLIENT_ID`, `TWITCH_CLIENT_SECRET`. **Deploys are run by the owner**
  (Claude's auto mode blocks production deploys): ask them to run
  `! cd ~/Developer/GameWire && npx supabase functions deploy igdb-search --project-ref rvxucodpumyiuqffbvwo --no-verify-jwt --use-api --yes`.
  Claude can test with curl (POST {"q": "..."}) and read `npx supabase secrets list` / `functions list`. IGDB requires visible credit → "Game data from
  IGDB.com" under results. IGDB is free for non-commercial use; commercial needs a partnership.
  Owner chose Supabase (also planned for push notifications: device tokens + follows + cron).
- `HomeView.load()` fetches outlets + (followed ∪ popular) games once via `NewsService.fetchAll`, then
  builds both feeds with FeedMixer. Unfollowing filters My Games in place; following rebuilds it.
  Discover keeps its order until refresh.
- `NewsService.swift`: fetches everything in parallel (returns unordered; HomeView builds feeds). Keeps
  **30 days** (`historyAge`), ≤20 Steam posts per game. `discoverPosts()` = Discover's view: ≤7 days, ≤30 per
  outlet. **My Games feed is mixed with FeedMixer (owner: "do not make it linear in time")**: past week,
  or past month if the week has <20 posts (owner wanted leniency for people who follow few games). Feed depth measured Nov 2026: IGN/Kotaku/
  Polygon RSS reach back only 5–12 h, PC Gamer ~2.5 d, Eurogamer/RPS ~10 d; Steam goes back months.
  VG247's feed had nothing newer than 7 days (stale?). Real history for outlets would need the server to
  archive feeds (future Supabase cron).
  Steam = official `ISteamNews/GetNewsForApp` (feeds=steam_community_announcements); patch notes via
  `patchnotes` tag or title regex. Game icons via `ICommunityService/GetApps` (32px only).
- `FeedMixer.swift`: weighted shuffle, new every open/refresh (owner chose "keep it random", no learning
  from taps yet). Tickets per post: freshness (half every 48h) × 2 if about a followed game (Steam posts, or
  outlet headline naming the game/alias in `SteamGame.aliases`) × big-story boost (+50% per other outlet,
  max 3×). Next source drawn by its best post's tickets; within a source, best first with 0.5–1 jitter;
  never the same source twice in a row. Once a story is shown, other outlets' copies drop to 0.5×
  (owner wants all copies shown, just not clumped).
- `StoryMatcher.swift`: "same story" = different outlets, ≤36h apart, ≥2 shared *specific* headline words
  (stop words, years, aliases like GTA/WoW handled). A word is a "topic", not specific, if one outlet uses it
  in 3+ headlines or total uses > 1.5× outlets using it (stops Ocarina guides counting as one story).
  Tuned on real feeds (Nov 2026): ~12 true stories, no junk. Known miss: stories whose only shared words
  are topic words (e.g. "WoW: Forever smooth launch").
- `HomeView`: shows 10 posts, loads 10 more when the bottom spinner appears, ends with "You're all caught up".
- Full text vs teaser: ≥150 words in the feed → in-app reader; otherwise opens site in SFSafariViewController
  (Reader mode). IGN, PC Gamer, GameSpot, Steam = full text; Kotaku, Polygon, Eurogamer, RPS, VG247 = teasers.
- Outlet logos are bundled in `Assets.xcassets/Logos` (sites block/rename icon URLs).

## Article reader
- `ArticleDetailView` → `ArticleWebView` (WKWebView) showing `ArticleHTML.page(for:)`: our CSS around the feed's HTML.
- `ArticleHTML.swift` handles: Steam BBCode → HTML (incl. `\[` escapes, `[previewyoutube="ID;full"]`,
  `[dynamiclink]` → YouTube embed / Steam store card / link card); IGN `data-transform` placeholders
  (ignvideo → official IGN embed player, slideshow → link card with og:image cover via `LinkPreview`,
  image-with-caption, quoteBox, divider); PC Gamer fixes (`data-lazy-src` iframes, `vanilla-image-block`
  padding gap, empty `min-height` boxes); social embeds (loads official X/Instagram/Reddit/Bluesky/TikTok
  scripts only when present); carousel script groups 2+ adjacent images into a swipeable carousel.
- Links: http(s) → in-app Safari; other schemes (steam://) → `UIApplication.open`.

## Policy decisions already made
- Don't scrape sites beyond feeds/official embeds (e.g. no pulling IGN gallery images from page data).
- Apple guideline 4.2.2 (aggregators): app needs native value (following games, patch notes, releases, deals).
- Social embeds load third-party scripts → mention in App Store privacy details at submission.

## Testing tricks used
- To screenshot a specific article: temporarily add an env-var hook (e.g. `debugOpen`) in `HomeView.load()`
  and launch with `SIMCTL_CHILD_debugOpen=… xcrun simctl launch …`; then `xcrun simctl io <id> screenshot`.
  **Always remove temp hooks afterwards** (they were marked `// TEMP-DEBUG`).
- Parser/mixer logic can be tested with a standalone `swiftc` harness + a stub `NewsItem`. For the mixer:
  download the real feeds, run `FeedMixer.mix` ~2000 times, check median age / big stories / Steam posts in
  the top 10 and "same story twice in top 10" (should be ~0).

## Known gaps
- Save / hide-source are in memory only (reset on relaunch). Follows do persist.
- My Games feed relies on headline matching for non-Steam games, so it's empty when no outlet mentions
  your games that week (true for Minecraft/Valorant/TotK on Nov 5 2026 — checked).
- IGDB `/v4/multiquery` returned `[]` for our queries, so the function sends 3 parallel `/v4/games`
  requests instead (contains-match by rating, contains-match recent/upcoming by hypes, fuzzy `search`),
  merges, and ranks by log10(ratings + 3×hypes) + name-match + recency bonuses. Verified Nov 2026:
  zelda → BotW/OoT/TotK, mario kart → World/8/8DX, gta → VI/V, helldivers → 2 first.
- Load-more paging and image carousels were only verified in code/simulation, not by real scrolling.
- Bluesky/TikTok embeds untested (none in feeds at the time).

## Where we left off
Uncommitted on `main`: source logos, FeedMixer + paging, 7-day limit, link-preview cards + Web badge,
orange type labels, PC Gamer gap fix, weighted feed ranking (FeedMixer + StoryMatcher), and following
(FollowStore, Discover/My Games tabs, Find Games sheet). Agreed next steps for following: game search
(Steam store search, plus "follow by name" for non-Steam games), the bottom My Games tab (list + game
page), onboarding, Settings → Sources toggles (replacing in-memory hide). Other Home ideas:
- **YouTube** (channel RSS `youtube.com/feeds/videos.xml?channel_id=…`: 15 latest, thumbnail, views; filter
  Shorts; play via youtube-nocookie embed). Owner was interested.
- Free games (GamerPower API), live Steam player counts (`ISteamUserStats/GetNumberOfCurrentPlayers`),
  deals (CheapShark), release reminders. Twitch needs a server for keys; Reddit skipped (API terms).
Later roadmap: My Games tab (follow games, game page), Releases (week-by-week rows of covers), Free & Deals
(SteamDB-sales-like list via CheapShark), onboarding (platforms, games, outlets), settings, persistence,
notifications, widgets.
