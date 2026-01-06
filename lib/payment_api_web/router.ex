defmodule PaymentApiWeb.Router do
  use PaymentApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug PaymentApiWeb.Plugs.RateLimiter, limit: 100, window: 60_000
  end

  pipeline :strict_rate_limit do
    plug PaymentApiWeb.Plugs.RateLimiter, limit: 10, window: 60_000
  end

  scope "/api", PaymentApiWeb do
    pipe_through :api

    get "/transactions/:id", TransactionController, :show

    pipe_through :strict_rate_limit
    post "/transactions", TransactionController, :create
    post "/transactions/:id/refund", TransactionController, :refund
  end
end
