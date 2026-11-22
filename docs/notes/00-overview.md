# Background and context

Some human notes to go along with the LLM generated tutorial docs.

Been wrestling with what it means to think of myself as a software engineer in
the LLM age.

This project is an attempt to discover if an LLM can be an effective tool to
help me (humble human) to learn something of which I have a little starting
knowledge.

The elephant in the room this project is expressly and deliberately ignoring is
whether it's even useful long term to try and jam some new knowledge into my
meat brain.

# Approach

My approach to this was to set up a new project, define a goal I want to
achieve, then have the LLM write itself a plan to strictly generate tutorial
style docs to help me learn while building the goal. As part of this the LLM is
strictly banned from actually generating any code - I told it I want to type
everything myself.

# The Aim

I think probably the first ever video game I played was called
[Combat](<https://en.wikipedia.org/wiki/Combat_(video_game)>) on the Atari 2600.

Feels like a core memory - still feels quite mesmerising to me as I peer back
through the mists of time.

Was a simple 2-player game where players competed across a set of different
arenas to defeat your opponent by firing a tiny pixelly shell across the screen
to hit them. The basic mode was a fight as a pair of tanks, where each tank
could move forwards or backwards, rotate left or right and fire a shell and the
fight took place in a simple rectangular arena with different configurations of
blocking walls getting in the way. There was also a couple of flight modes where
the planes continued forward at a fixed speed, but again had the goal of
shooting a shell to hit your opponent. That mode also featured clouds of various
configurations that obscured part of the screen allowing for some tricksy
manoeuvres under cover of cloud to catch out your opponent.

This is the game I want to build, but using Elixir as a backend so two players
can battle online, using a js canvas front end for the visible arena, and the
Elixir backend as the game engine synchronizing state.
