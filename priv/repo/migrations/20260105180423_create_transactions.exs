defmodule PaymentApi.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :amount, :decimal, precision: 20, scale: 2, null: false
      add :currency, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :customer_email, :string, null: false
      add :customer_ip, :string
      add :payment_method, :string, null: false
      add :description, :text
      add :fraud_score, :integer, default: 0
      add :fraud_flags, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      add :refunded_amount, :decimal, precision: 20, scale: 2, default: 0
      add :refunded_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:customer_email])
    create index(:transactions, [:status])
    create index(:transactions, [:inserted_at])
  end
end
