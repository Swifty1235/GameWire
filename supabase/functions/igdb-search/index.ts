// GameWire game search: the app sends {"q": "zelda"}, this asks IGDB (with our Twitch secret, which must
// never be inside the app) and returns a short list of games with box art and platforms.
//
// Secrets (Supabase dashboard → Edge Functions → Secrets): TWITCH_CLIENT_ID, TWITCH_CLIENT_SECRET.
// Deploy with JWT verification off; the app only sends the project's public key.

const clientID = Deno.env.get("TWITCH_CLIENT_ID") ?? "";
const clientSecret = Deno.env.get("TWITCH_CLIENT_SECRET") ?? "";

/** IGDB "game types" that are real games (main game, standalone expansion, remake, remaster,
 * expanded game, port), not DLC, bundles, mods, or episodes. */
const gameTypes = new Set([0, 4, 8, 9, 10, 11]);
/** IGDB's id for Steam in external_games. */
const steamSource = 1;

// Twitch app token, kept between requests while this function instance stays warm (~60 days valid).
let token: { value: string; expires: number } | null = null;

async function accessToken(): Promise<string> {
  if (token && Date.now() < token.expires) return token.value;
  const url = new URL("https://id.twitch.tv/oauth2/token");
  url.search = new URLSearchParams({
    client_id: clientID,
    client_secret: clientSecret,
    grant_type: "client_credentials",
  }).toString();
  const response = await fetch(url, { method: "POST" });
  if (!response.ok) throw new Error(`Twitch token: ${response.status} ${await response.text()}`);
  const body = await response.json();
  token = { value: body.access_token, expires: Date.now() + (body.expires_in - 300) * 1000 };
  return token.value;
}

interface IGDBGame {
  id: number;
  name: string;
  cover?: { image_id: string };
  first_release_date?: number;
  platforms?: { abbreviation?: string; name: string }[];
  external_games?: { uid?: string; external_game_source?: number; category?: number }[];
  game_type?: number | { id: number };
  category?: number;
  version_parent?: number;
  total_rating_count?: number;
  hypes?: number;
}

/** What the app gets back for each game. */
interface Game {
  igdbID: number;
  name: string;
  coverImageID: string | null;
  year: number | null;
  platforms: string[];
  steamAppID: number | null;
}

const fields = `fields name, cover.image_id, first_release_date, platforms.abbreviation, platforms.name,
  external_games.uid, external_games.external_game_source, external_games.category,
  game_type, category, version_parent, total_rating_count, hypes;`;

/** Three IGDB searches run at the same time, because its own search alone misses big games:
 * - popular: names containing the words, most-rated first (finds the famous ones)
 * - upcoming: names containing the words, released in the last 2 years or not out yet, most
 *   anticipated first (finds new and unreleased games, which have few ratings)
 * - fuzzy: IGDB's own search, which also knows nicknames ("gta") and alternative names */
async function fetchCandidates(text: string): Promise<IGDBGame[]> {
  const contains = `name ~ *"${text}"* & cover != null & version_parent = null`;
  const twoYearsAgo = Math.floor(Date.now() / 1000) - 2 * 365 * 24 * 3600;
  const queries = [
    `${fields} where ${contains}; sort total_rating_count desc; limit 30;`,
    `${fields} where ${contains} & (first_release_date > ${twoYearsAgo} | first_release_date = null); sort hypes desc; limit 15;`,
    `search "${text}"; ${fields} where cover != null; limit 30;`,
  ];
  const token = await accessToken();
  const results = await Promise.all(queries.map(async (body) => {
    const response = await fetch("https://api.igdb.com/v4/games", {
      method: "POST",
      headers: { "Client-ID": clientID, Authorization: `Bearer ${token}` },
      body,
    });
    if (!response.ok) throw new Error(`IGDB: ${response.status} ${await response.text()}`);
    return await response.json() as IGDBGame[];
  }));

  const byID = new Map<number, IGDBGame>();
  for (const result of results) for (const game of result) byID.set(game.id, game);
  return [...byID.values()];
}

/** Higher = shown first. Mostly popularity (ratings, plus hype for unreleased games), nudged up for
 * names that match what you typed and for new games. Examples it gets right: "zelda" → Tears of the
 * Kingdom / Breath of the Wild before the 1989 Game & Watch "Zelda"; "helldivers" → Helldivers 2 first. */
function score(game: IGDBGame, text: string, now: number): number {
  const popularity = (game.total_rating_count ?? 0) + 3 * (game.hypes ?? 0);
  const name = game.name.toLowerCase();
  const match = name === text ? 0.7 : name.startsWith(text) ? 0.4 : name.includes(text) ? 0.25 : 0;
  const twoYears = 2 * 365 * 24 * 3600;
  const recent = !game.first_release_date || now - game.first_release_date < twoYears ? 0.5 : 0;
  return Math.log10(1 + popularity) + match + recent;
}

async function search(query: string): Promise<Game[]> {
  const text = query.replaceAll('"', "").replaceAll("*", "").slice(0, 80).toLowerCase();
  const now = Date.now() / 1000;
  const games = await fetchCandidates(text);

  return games
    // Real games only: no editions of another game (version_parent), DLC, bundles, mods…
    .filter((g) => g.version_parent == null)
    .filter((g) => {
      const type = typeof g.game_type === "object" ? g.game_type?.id : g.game_type ?? g.category;
      return type == null || gameTypes.has(type);
    })
    .map((g) => ({ g, score: score(g, text, now) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 20)
    .map(({ g }) => {
      const steam = g.external_games?.find(
        (e) => (e.external_game_source ?? e.category) === steamSource && e.uid,
      );
      return {
        igdbID: g.id,
        name: g.name,
        coverImageID: g.cover?.image_id ?? null,
        year: g.first_release_date ? new Date(g.first_release_date * 1000).getUTCFullYear() : null,
        platforms: [...new Set((g.platforms ?? []).map((p) => p.abbreviation ?? p.name))],
        steamAppID: steam?.uid ? Number(steam.uid) || null : null,
      };
    });
}

// Recent searches, so people typing the same thing don't each hit IGDB (limit: 4 requests/second).
const cache = new Map<string, { games: Game[]; expires: number }>();
const cacheTime = 60 * 60 * 1000;

Deno.serve(async (request) => {
  try {
    const { q } = await request.json();
    if (typeof q !== "string" || q.trim().length < 2) return Response.json([]);

    const key = q.trim().toLowerCase();

    const cached = cache.get(key);
    if (cached && Date.now() < cached.expires) return Response.json(cached.games);

    const games = await search(q.trim());
    if (cache.size > 500) cache.clear();
    cache.set(key, { games, expires: Date.now() + cacheTime });
    return Response.json(games);
  } catch (error) {
    console.error(error);
    return Response.json({ error: "Search is unavailable right now." }, { status: 502 });
  }
});
