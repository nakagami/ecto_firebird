defmodule Ecto.Integration.TestRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :ecto_firebird, adapter: Ecto.Adapters.Firebird

  def create_prefix(_) do
    raise "Firebird does not support CREATE DATABASE"
  end

  def drop_prefix(_) do
    raise "Firebird does not support DROP DATABASE"
  end

  def uuid do
    Ecto.UUID
  end
end
