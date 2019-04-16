defmodule IssuesTest do
  use ExUnit.Case
  # Allow us to capture stuff sent to stdout
  import ExUnit.CaptureIO
  doctest Issues

  @simple_test_data [
    [c1: "r1 c1", c2: "r1 c2", c3: "r1 c3", c4: "r1+++c4"],
    [c1: "r2 c1", c2: "r2 c2", c3: "r2 c3", c4: "r2 c4"],
    [c1: "r3 c1", c2: "r3 c2", c3: "r3 c3", c4: "r3 c4"],
    [c1: "r4 c1", c2: "r4++c2", c3: "r4 c3", c4: "r4 c4"]
  ]
  @headers [:c1, :c2, :c4]

  test ":help returned by option parsing with -h and --help options" do
    assert Issues.parse_args(["-h", "anything"]) == :help
    assert Issues.parse_args(["--help", "anything"]) == :help
  end

  test "three values returned if three given" do
    assert Issues.parse_args(["user", "project", "99"]) == {"user", "project", 99}
  end

  test "count is defaulted if two values given" do
    assert Issues.parse_args(["user", "project"]) == {"user", "project", 4}
  end

  test "sort descending orders the correct way" do
    result = Issues.sort_into_descending_order(fake_created_at_list(["c", "a", "b"]))
    issues = for issue <- result, do: Map.get(issue, "created_at")
    assert issues == ~w{ c b a }
  end

  defp fake_created_at_list(values) do
    for value <- values,
        do: %{"created_at" => value, "other_data" => "xxx"}
  end

  def split_with_three_columns do
    Issues.split_into_columns(@simple_test_data, @headers)
  end

  test "split_into_columns" do
    columns = split_with_three_columns()
    assert length(columns) == length(@headers)
    assert List.first(columns) == ["r1 c1", "r2 c1", "r3 c1", "r4 c1"]
    assert List.last(columns) == ["r1+++c4", "r2 c4", "r3 c4", "r4 c4"]
  end

  test "column_widths" do
    widths = Issues.widths_of(split_with_three_columns())
    assert widths == [5, 6, 7]
  end

  test "correct format string returned" do
    assert Issues.format_for([9, 10, 11]) == "~-9s | ~-10s | ~-11s~n"
  end

  test "Output is correct" do
    result =
      capture_io(fn ->
        Issues.print_table_for_columns(@simple_test_data, @headers)
      end)

    assert result ==
             "c1    | c2     | c4     \n------+--------+--------\nr1 c1 | r1 c2  | r1+++c4\nr2 c1 | r2 c2  | r2 c4  \nr3 c1 | r3 c2  | r3 c4  \nr4 c1 | r4++c2 | r4 c4  \n"
  end
end
