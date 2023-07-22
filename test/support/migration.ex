defmodule EctoFirebird.Integration.Migration do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:accounts) do
      add(:name, :string)
      add(:email, :string, collate: :nocase)
      timestamps()
    end

    create table(:users) do
      add(:name, :string)
      add(:custom_id, :uuid)
      timestamps()
    end

    create table(:account_users) do
      add(:account_id, references(:accounts))
      add(:user_id, references(:users))
      add(:role, :string)
      timestamps()
    end

    create table(:products) do
      add(:account_id, references(:accounts))
      add(:name, :string)
      add(:description, :string)
      add(:external_id, :uuid)
      add(:tags, {:array, :string})
      add(:approved_at, :naive_datetime)
      add(:price, :decimal, precision: 5, scale: 3)
      timestamps()
    end

    #    create table(:vec3f) do
    #      add(:x, :float)
    #      add(:y, :float)
    #      add(:z, :float)
    #    end

    create table(:settings) do
      add(:properties, :map)
    end
  end
end
