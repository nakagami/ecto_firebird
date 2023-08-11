Logger.configure(level: :info)

Application.put_env(:ecto, :primary_key_type, :id)
Application.put_env(:ecto, :async_integration_tests, false)

ecto = Mix.Project.deps_paths()[:ecto]
Code.require_file("#{ecto}/integration_test/support/schemas.exs", __DIR__)

alias Ecto.Integration.TestRepo

Application.put_env(:ecto_firebird, TestRepo,
  adapter: Ecto.Adapters.Firebird,
  hostname: "localhost",
  username: System.get_env("ISC_USER", "sysdba"),
  password: System.get_env("ISC_PASSWORD", "masterkey"),
  database: "/tmp/ecto_firebird_test.fdb",
  pool: Ecto.Adapters.SQL.Sandbox,
  show_sensitive_data_on_connection_error: true
)

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  setup do
    :ok = Sandbox.checkout(TestRepo)
    # on_exit(fn -> Ecto.Adapters.SQL.Sandbox.checkin(TestRepo) end)
  end
end

{:ok, _} = Ecto.Adapters.Firebird.ensure_all_started(TestRepo.config(), :temporary)

# Load up the repository, start it, and run migrations
_ = Ecto.Adapters.Firebird.storage_down(TestRepo.config())
:ok = Ecto.Adapters.Firebird.storage_up(TestRepo.config())

{:ok, _} = TestRepo.start_link()

:ok = Ecto.Migrator.up(TestRepo, 0, EctoFirebird.Integration.Migration, log: false)
Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
Process.flag(:trap_exit, true)

ExUnit.start()
