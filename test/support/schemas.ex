defmodule EctoFirebird.Integration.Account do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias EctoFirebird.Integration.Product
  alias EctoFirebird.Integration.User

  schema "accounts" do
    field(:name, :string)
    field(:email, :string)

    timestamps()

    many_to_many(:users, User, join_through: "account_users")
    has_many(:products, Product)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end

defmodule EctoFirebird.Integration.User do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias EctoFirebird.Integration.Account

  schema "users" do
    field(:name, :string)

    timestamps()

    many_to_many(:accounts, Account, join_through: "account_users")
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end

defmodule EctoFirebird.Integration.AccountUser do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias EctoFirebird.Integration.Account
  alias EctoFirebird.Integration.User

  schema "account_users" do
    timestamps()

    belongs_to(:account, Account)
    belongs_to(:user, User)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:account_id, :user_id])
    |> validate_required([:account_id, :user_id])
  end
end

defmodule EctoFirebird.Integration.Product do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias EctoFirebird.Integration.Account

  schema "products" do
    field(:name, :string)
    field(:description, :string)
    field(:external_id, :string)
    field(:tags, {:array, :string}, default: [])
    field(:approved_at, :naive_datetime)
    field(:price, :decimal)

    belongs_to(:account, Account)

    timestamps()
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name, :description, :tags, :account_id, :approved_at])
    |> validate_required([:name])
    |> maybe_generate_external_id()
  end

  defp maybe_generate_external_id(changeset) do
    if get_field(changeset, :external_id) do
      changeset
    else
      put_change(changeset, :external_id, Ecto.UUID.generate())
    end
  end
end

defmodule EctoFirebird.Integration.Setting do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  schema "settings" do
    field(:properties, :map)
  end

  def changeset(struct, attrs) do
    cast(struct, attrs, [:properties])
  end
end
