# 01 — Project setup

## Goal

By the end of this guide you'll have a running Phoenix app with a `/play/:match_id` page. The
page shows an empty, black, pixel-scaled `<canvas>` that a tiny JavaScript module draws a test
rectangle on.

## Concepts

### What `mix phx.new` gives you

Phoenix is "just" an OTP application with a web layer bolted on. After generation you get two
top-level namespaces:

- `lib/combat/` holds **your domain**: business logic and processes. The game core and game
  servers live here. This code should never need to know about HTTP.
- `lib/combat_web/` holds **the web interface**: router, controllers, templates, channels. It
  calls into `Combat.*`, but never the other way round.

Keep that boundary in mind. Every time you're about to call `CombatWeb.*` from `lib/combat/`,
stop and look for another way (usually PubSub).

### The request pipeline in 30 seconds

```
HTTP request ─► CombatWeb.Endpoint (plugs: static files, parsers, session)
             ─► CombatWeb.Router   (pipelines :browser / :api, then routes)
             ─► a Controller action ─► a HEEx template via the *HTML module
```

WebSocket connections take a different route. They go `Endpoint` → `socket "/socket", ...` →
`UserSocket` → `GameChannel`. That's covered in guide 07.

### Assets

Phoenix uses **esbuild** (bundling JS) and **Tailwind** (CSS), downloaded as standalone binaries,
so no `npm install` is needed for the basics. `assets/js/app.js` is the entry point. Anything you
`import` from it ends up in `priv/static/assets/app.js`.

## Steps

### 1. Update the Phoenix generator

You have `phx_new 1.7.18` installed. These guides assume **Phoenix 1.8**:

```sh
mix local.hex --force
mix archive.install hex phx_new
mix help phx.new | head -5   # confirm the version
```

### 2. Generate the project *into the current directory*

This directory already contains `README.md` and `docs/`. From **inside** it, run:

```sh
mix phx.new . --app combat --no-ecto --no-mailer --no-dashboard --no-gettext
```

What the flags remove, and why:

- `--no-ecto`: there's no database. Matches live in memory and vanish when they end.
- `--no-mailer`, `--no-dashboard`, `--no-gettext`: less generated code to read. You can add
  LiveDashboard later (it's lovely for watching processes) as a stretch goal.

If it asks whether to overwrite `README.md`, answer **no**. Say **yes** to fetching dependencies.

### 3. Take the tour

Before writing anything, open and read these files. Note in a scratch file what each one does:

- `mix.exs`: the dependencies and `aliases` (look at what `mix setup` runs).
- `lib/combat/application.ex`: **the root supervisor's child list.** You'll come back here
  in guides 06 and 09.
- `lib/combat_web/endpoint.ex`: the plug pipeline. Find the `socket "/live", ...` line.
- `lib/combat_web/router.ex`: pipelines and routes.
- `lib/combat_web/controllers/page_controller.ex` and `page_html/home.html.heex`.
- `lib/combat_web/components/layouts.ex` (and the `layouts/` folder): the page chrome.
- `assets/js/app.js`: note that it sets up a LiveView socket. We won't use LiveView for the game,
  but leave it in place (it's harmless and powers the flash messages).
- `config/dev.exs`: find the `watchers` that run esbuild/tailwind for you.

Then run it:

```sh
mix phx.server     # or: iex -S mix phx.server  (gives you a shell inside the running app)
```

Visit http://localhost:4000. Get used to starting with **`iex -S mix phx.server`**, because
inspecting the running system from the shell is half the fun of Elixir.

### 4. Add a game page

Create a controller that renders a page containing the canvas.

- **Route:** in the `"/"` scope of `router.ex`, add `get "/play/:match_id", GameController, :show`.
- **`lib/combat_web/controllers/game_controller.ex`** (`CombatWeb.GameController`): a `show/2`
  action that takes `%{"match_id" => match_id}` from params, upcases it, and renders `:show`,
  assigning `match_id`.
- **`lib/combat_web/controllers/game_html.ex`** (`CombatWeb.GameHTML`): `use CombatWeb, :html` and
  `embed_templates "game_html/*"`. Mirror how `PageHTML` does it.
- **`lib/combat_web/controllers/game_html/show.html.heex`** should contain:
  - a heading showing the match id
  - `<canvas id="game-canvas" width="160" height="100" data-match-id={@match_id}></canvas>`
  - a `<div id="game-status">` for messages ("Waiting for opponent…") later

The canvas's *drawing buffer* is the logical world size, 160 × 100. CSS will stretch it to fill
the screen, and `image-rendering: pixelated` keeps it chunky. Add this to `assets/css/app.css`:

```css
#game-canvas {
  width: 100%;
  max-width: 960px;
  aspect-ratio: 160 / 100;
  image-rendering: pixelated;
  background: #000;
}
```

<details><summary>Hint: why not make the canvas 960×600 and scale in JS?</summary>

You could, and guide 08 discusses it. Starting at 160×100 means one canvas unit is exactly one
world unit, so drawing code needs no scale factor. The trade-off is that rotated shapes are
blurrier at low resolution. If that bothers you later, switch to a bigger buffer and call
`ctx.setTransform(scale, 0, 0, scale, 0, 0)` once per frame.
</details>

### 5. A first JavaScript module

- Create `assets/js/game/index.js` that exports a function `startGame()`. It should:
  - find `#game-canvas`, and return early if there isn't one (this module will be loaded on every
    page)
  - get a `2d` context and fill a small coloured rectangle at `(10, 10)` so you can see it works
- In `assets/js/app.js`, `import { startGame } from "./game"` and call it once the DOM is ready.
  A `defer`-loaded script can call it directly. Check how the layout loads `app.js`.

## Checkpoint

- `mix phx.server` starts with no warnings.
- http://localhost:4000/play/abcd shows heading "ABCD" and a black box with a small coloured,
  visibly pixelated square in the corner.
- The browser console has no errors.
- Bonus: run `:observer.start()` in `iex -S mix phx.server` and look at the *Applications* tab
  to find `Combat.Supervisor` and its children. (If observer isn't available in your OTP build,
  `Supervisor.which_children(Combat.Supervisor)` does the same job in text.)

## Stretch goals

- Initialise a git repository and commit. Do this at every checkpoint from now on.
- Add a link from the home page to `/play/TEST`.

Next: [02 — Game core: data model](02-game-core-data-model.md)
