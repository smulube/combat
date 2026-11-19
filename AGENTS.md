# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, Copilot and similar) working in this
repository.

## This is a learning project

The point of this repository is for the human to learn Elixir, OTP and Phoenix by building the
game **themselves**, following the guides in [`docs/`](docs/). Every line of application code is
meant to be typed by the learner. If an agent writes it, the project has lost its point.

## What agents must NOT do

- **Do not write, generate, edit or delete application code.** This covers everything under
  `lib/`, `test/`, `assets/`, `config/`, `priv/`, `mix.exs` and any other source or build
  files, even when asked casually ("just fix this", "fill in this function").
- Do not run generators or commands that create or change code for the learner, such as
  `mix phx.new`, `mix phx.gen.*`, `mix format` on their files or `mix deps.update`.
- Do not paste complete, ready-to-run solutions into chat in place of the code the learner is
  writing. A snippet that only shows the shape of an API is fine; a finished implementation of
  the exercise is not.

If the learner explicitly asks for code anyway, remind them of this file and offer a hint,
an explanation or a pointer to the docs instead. Only go further if they clearly confirm they
want to override this rule for that specific case.

## What agents SHOULD do

- **Maintain the guides.** Edit, correct and extend the Markdown in `docs/`, `README.md` and
  this file when asked: fix errors, clarify explanations, keep the guides consistent with
  each other and with current versions of Elixir and Phoenix.
- **Explain.** Answer questions about Elixir, OTP, Phoenix, the guides and the learner's own
  code. Point to the relevant guide section or HexDocs page.
- **Review, don't rewrite.** When the learner shares code or an error, read it, explain what is
  wrong and why, and suggest a direction or a hint. Let them make the change.
- **Run read-only commands** when they help diagnose a problem: `mix test`, `mix compile`,
  `git status`, `git diff`, reading files and logs.
- Prefer the guides' teaching style: hints in `<details>` blocks, checkpoints the learner can
  verify themselves, and stretch goals rather than finished answers.

## Guide conventions

- Guides are numbered `docs/NN-topic.md` and listed in the table in `README.md`. Keep that
  table in sync when adding or renaming a guide.
- Building guides follow the shape **Goal**, **Concepts**, **Steps**, **Checkpoint**,
  **Stretch goals**, then a link to the next guide. Exceptions: `00-overview.md` is reference
  material, and `13-netcode-and-polish.md` splits its steps into lettered parts (Part A, B, …).
  Follow whichever shape the guide you're editing already uses.
- Steps describe _what_ to build (module names, function signatures, behaviour), not full
  implementations.
- The guides assume Phoenix 1.8 with no Ecto, mailer or gettext, and with LiveDashboard
  enabled in development.
