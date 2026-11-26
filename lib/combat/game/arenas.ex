defmodule Combat.Game.Arenas do
  @moduledoc """
  Arenas exposes functions for building playable maps (arenas).
  """
  alias Combat.Game.Arena

  @cell_size 10.0

  @open_field_layout """
  ################
  #..............#
  #..............#
  #..............#
  #.1..........2.#
  #..............#
  #..............#
  #..............#
  #..............#
  ################
  """

  @maze_layout """
  ################
  #..............#
  #......##......#
  #...#..#...#...#
  #.1.#......#...#
  #...#......#.2.#
  #.......#......#
  #..#...##...#..#
  #..............#
  ################
  """

  @doc """
  Returns the simplest starting map (an open area with border walls only, player
  1 spawns in the middle left facing east and player 2 spawns on middle right
  facing west).
  """
  @spec open_field() :: Arena.t()
  def open_field do
    from_ascii(@open_field_layout)
  end

  @spec maze() :: Arena.t()
  def maze do
    from_ascii(@maze_layout)
  end

  @spec from_ascii(String.t()) :: Arena.t()
  def from_ascii(grid) do
    rows = extract_rows(grid)
    longest_row = Enum.max_by(rows, fn row -> String.length(row) end)

    spawns =
      rows
      |> extract_spawns()
      |> Enum.group_by(fn {char, _, _} -> char end, fn {_, col, row} -> {col, row} end)

    %Arena{
      width: String.length(longest_row) * @cell_size,
      height: length(rows) * @cell_size,
      walls: build_walls(rows),
      spawns: build_spawns(spawns)
    }
  end

  defp extract_rows(plan) do
    String.split(plan, "\n", trim: true)
  end

  defp extract_spawns(rows) do
    for {line, row} <- Enum.with_index(rows),
        {char, col} <- Enum.with_index(String.graphemes(line)),
        char == "1" or char == "2",
        do: {char, col, row}
  end

  defp build_walls(rows) do
    for {line, row} <- Enum.with_index(rows),
        [{"#", col} | _] = chunk <-
          line |> String.graphemes() |> Enum.with_index() |> Enum.chunk_by(fn {c, _} -> c end) do
      run_to_rect(row, col, length(chunk))
    end
  end

  defp build_spawns(%{"1" => [{col_1, row_1}], "2" => [{col_2, row_2}]}) do
    %{
      p1: {spawn_centre(col_1), spawn_centre(row_1), 0},
      p2: {spawn_centre(col_2), spawn_centre(row_2), 8}
    }
  end

  defp spawn_centre(val) do
    val * @cell_size + @cell_size / 2.0
  end

  defp run_to_rect(row, start_col, len) do
    %{x: start_col * @cell_size, y: row * @cell_size, w: len * @cell_size, h: @cell_size}
  end
end
