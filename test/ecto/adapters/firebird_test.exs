defmodule EctoFirebirdTest do
  use ExUnit.Case
  doctest Ecto.Adapters.Firebird

  test "greets the world" do
    assert Ecto.Adapters.Firebird.hello() == :world
  end
end
