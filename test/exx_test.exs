defmodule ExxTest do
  use ExUnit.Case
  require Exx
  import Exx

  doctest Exx

  test "test simple exx" do
    assert {:ok, _} =
             ~x(<foo something=#{{1, 1}}><bar2 something="a"/><a>2</a></foo>)raw
             |> parse_exx()
             |> IO.inspect()
  end

  test "test simple exx with fragment" do
    assert {:ok, _} =
      ~x(
        <>
          <foo something=#{{1, 1}}>
            <bar2 something="a"/>
            <a>2</a>
          </foo>
        </>
      )raw
    |> parse_exx()
    |> IO.inspect()
  end

  test "test simple exx with module name" do
    assert {:ok, _} =
      ~x(
        <>
          <Foo something=#{{1, 1}}>
            <bar2 something="a"/>
            <a>2</a>
          </Foo>
        </>
      )raw
      |> parse_exx()
      |> IO.inspect()
  end
end
