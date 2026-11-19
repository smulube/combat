# Combat (Elixir edition)

An online two-player arcade battle game inspired by the Atari 2600 classic *Combat*,
built with **Elixir/OTP + Phoenix** on the server and a plain **JavaScript + `<canvas>`**
client in the browser.

This repository starts out empty on purpose. It's a learning project: the guides in
[`docs/`](docs/) walk you through building the game one step at a time, and you type
every line yourself.

## The guides

| # | Guide | You'll learn |
|---|-------|--------------|
| 00 | [Overview & architecture](docs/00-overview.md) | The big picture, the process tree, naming conventions |
| 01 | [Project setup](docs/01-project-setup.md) | `mix phx.new`, a tour of a Phoenix project, a canvas page |
| 02 | [Game core: data model](docs/02-game-core-data-model.md) | Structs, coordinates, 16-way rotation, first tests |
| 03 | [Movement & collision](docs/03-movement-and-collision.md) | Pure update functions, AABB collision, arenas as data |
| 04 | [Shells, hits & scoring](docs/04-shells-hits-and-scoring.md) | Projectiles, hit reactions, timers, game status |
| 05 | [The GenServer](docs/05-game-server.md) | GenServer callbacks, a fixed-rate tick loop |
| 06 | [Supervision & Registry](docs/06-supervision-and-registry.md) | Supervisors, DynamicSupervisor, Registry, restarts |
| 07 | [Channels & PubSub](docs/07-channels-and-pubsub.md) | Sockets, Channels, Phoenix.Token, PubSub, channel tests |
| 08 | [Canvas client](docs/08-canvas-client.md) | Keyboard input, a render loop, drawing snapshots |
| 09 | [Lobby & matchmaking](docs/09-lobby-and-matchmaking.md) | Room codes, Presence, countdown, rematches |
| 10 | [Game modes behaviour](docs/10-game-modes-behaviour.md) | Behaviours and `@callback`s, the refactor to `Unit` |
| 11 | [Biplanes](docs/11-biplanes.md) | Constant motion, screen wrap, clouds that hide planes |
| 12 | [Jets](docs/12-jets.md) | Squadrons, several units per side |
| 13 | [Netcode & polish](docs/13-netcode-and-polish.md) | Interpolation, ping, disconnects, sound, cleanup |
| 14 | [Deployment (optional)](docs/14-deployment.md) | Releases, hosting, clustering ideas |

Work through them in order. Each guide ends with a **Checkpoint**, so you know when it's safe
to move on.
