defmodule Issues do
  @moduledoc """
  The God module
  Handle the command line parsing and the dispatch to the various functions that end up generating a table of the last _n_ issues in a github project
  """
  require Logger

  @doc """
  `argv` can be -h or --help, which returns :help.
  Otherwise it is a github user name, project name, and (optionally)
  the number of entries to format.
  Return a tuple of `{ user, project, count }`, or `:help` if help was given.
  """
  def main(argv) do
    command = parse_args(argv)
    process(command)
  end

  def parse_args(argv) do
    parse = OptionParser.parse(argv, switches: [help: :boolean], aliases: [h: :help])

    case parse do
      {[help: true], _, _} ->
        :help

      {_, [user, project, count], _} ->
        {user, project, String.to_integer(count)}

      {_, [user, project], _} ->
        {user, project, 4}

      _ ->
        :help
    end
  end

  def process(:help) do
    IO.puts("""
    usage: issues <user> <project> [ count | 4 ]
    """)

    System.halt(0)
  end

  def process({user, project, count}) do
    print_table_for_columns(
      last(sort_into_descending_order(decode_response(fetch(user, project))), count),
      ["number", "created_at", "title"]
    )
  end

  def decode_response({:ok, body}), do: body

  def decode_response({:error, error}) do
    Logger.error("Error fetching from Github: #{error["message"]}")
    System.halt(2)
  end

  def sort_into_descending_order(list_of_issues) do
    list_of_issues
    |> Enum.sort(fn i1, i2 ->
      i1["created_at"] >= i2["created_at"]
    end)
  end

  # ----------------- Make Request -----------------------
  def fetch(user, project) do
    headers = [{"User-agent", "Elixir dave@pragprog.com"}]

    "https://api.github.com/repos/#{user}/#{project}/issues"
    |> HTTPoison.get(headers)
    |> handle_response
  end

  def handle_response({:ok, %{status_code: 200, body: body}}) do
    {:ok, Poison.Parser.parse!(body)}
  end

  def handle_response({_, %{status_code: _, body: body}}) do
    {:error, Poison.Parser.parse!(body)}
  end

  # --------------- Printing data ------------------
  def print_table_for_columns(rows, headers) do
    with data_by_columns = split_into_columns(rows, headers),
         column_widths = widths_of(data_by_columns),
         format = format_for(column_widths) do
      puts_one_line_in_columns(headers, format)
      IO.puts(separator(column_widths))
      puts_in_columns(data_by_columns, format)
    end
  end

  def split_into_columns(rows, headers) do
    for header <- headers do
      for row <- rows, do: printable(row[header])
    end
  end

  def printable(str) when is_binary(str), do: str
  def printable(str), do: to_string(str)

  def widths_of(columns) do
    for column <- columns, do: column |> Enum.map(&String.length/1) |> Enum.max()
  end

  def format_for(column_widths) do
    Enum.map_join(column_widths, " | ", fn width -> "~-#{width}s" end) <> "~n"
  end

  def separator(column_widths) do
    Enum.map_join(column_widths, "-+-", fn width -> List.duplicate("-", width) end)
  end

  def puts_in_columns(data_by_columns, format) do
    data_by_columns
    |> List.zip()
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.each(&puts_one_line_in_columns(&1, format))
  end

  def puts_one_line_in_columns(fields, format) do
    :io.format(format, fields)
  end

  def last(list, count) do
    list |> Enum.take(count) |> Enum.reverse()
  end
end
