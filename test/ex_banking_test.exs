defmodule ExBankingTest do
  use ExUnit.Case, async: true
  import Mox

  alias ExBanking

  setup :verify_on_exit!

  setup context do
    if context[:use_mock] do
      Application.put_env(:ex_banking, :request_limiter, ExBanking.RequestLimiterMock)
    else
      Application.put_env(:ex_banking, :request_limiter, ExBanking.RequestLimiter)
    end

    :ok
  end

  test "create_user/1 creates a new user" do
    assert :ok == ExBanking.create_user("Alice")
    assert {:error, :user_already_exists} == ExBanking.create_user("Alice")
  end

  test "create_user/1 with invalid argument" do
    assert {:error, :wrong_arguments} == ExBanking.create_user(123)
  end

  test "deposit/3 deposits money to user's account" do
    ExBanking.create_user("Bob")
    assert {:ok, 100.0} == ExBanking.deposit("Bob", 100.0, "USD")
    assert {:ok, 200.0} == ExBanking.deposit("Bob", 100.0, "USD")
  end

  test "deposit/3 with invalid arguments" do
    ExBanking.create_user("Bob")
    assert {:error, :wrong_arguments} == ExBanking.deposit("Bob", -100.0, "USD")
    assert {:error, :wrong_arguments} == ExBanking.deposit("Bob", 100.0, 123)
    assert {:error, :user_does_not_exist} == ExBanking.deposit(123, 100.0, "USD")
  end

  test "withdraw/3 withdraws money from user's account" do
    ExBanking.create_user("Charlie")
    ExBanking.deposit("Charlie", 100.0, "USD")
    assert {:ok, 50.0} == ExBanking.withdraw("Charlie", 50.0, "USD")
    assert {:ok, 0.0} == ExBanking.withdraw("Charlie", 50.0, "USD")
  end

  test "withdraw/3 with insufficient funds" do
    ExBanking.create_user("Dave")
    ExBanking.deposit("Dave", 50.0, "USD")
    assert {:error, :not_enough_money} == ExBanking.withdraw("Dave", 100.0, "USD")
  end

  test "withdraw/3 with invalid arguments" do
    assert {:error, :wrong_arguments} == ExBanking.withdraw("Dave", -50.0, "USD")
    assert {:error, :wrong_arguments} == ExBanking.withdraw("Dave", 50.0, 123)
    assert {:error, :user_does_not_exist} == ExBanking.withdraw(123, 50.0, "USD")
  end

  test "get_balance/2 returns user's balance" do
    ExBanking.create_user("Eve")
    ExBanking.deposit("Eve", 100.0, "USD")
    assert {:ok, 100.0} == ExBanking.get_balance("Eve", "USD")
  end

  test "get_balance/2 with invalid arguments" do
    assert {:error, :wrong_arguments} == ExBanking.get_balance("Eve", 123)
    assert {:error, :user_does_not_exist} == ExBanking.get_balance(123, "USD")
  end

  test "send/4 transfers money between users" do
    ExBanking.create_user("Frank")
    ExBanking.create_user("Grace")
    ExBanking.deposit("Frank", 100.0, "USD")
    assert {:ok, 50.0, 50.0} == ExBanking.send("Frank", "Grace", 50.0, "USD")
    assert {:ok, 0.0, 100.0} == ExBanking.send("Frank", "Grace", 50.0, "USD")
  end

  test "send/4 with insufficient funds" do
    ExBanking.create_user("Hank")
    ExBanking.create_user("Ivy")
    ExBanking.deposit("Hank", 50.0, "USD")
    assert {:error, :not_enough_money} == ExBanking.send("Hank", "Ivy", 100.0, "USD")
  end

  test "send/4 with invalid arguments" do
    assert {:error, :wrong_arguments} == ExBanking.send("Hank", "Ivy", -50.0, "USD")
    assert {:error, :wrong_arguments} == ExBanking.send("Hank", "Ivy", 50.0, 123)
    assert {:error, :user_does_not_exist} == ExBanking.send("Hank", 123, 50.0, "USD")
    assert {:error, :user_does_not_exist} == ExBanking.send(123, "Ivy", 50.0, "USD")
  end

  @tag :use_mock
  test "handles too many requests" do
    ExBanking.create_user("Jack")

    ExBanking.RequestLimiterMock
    |> expect(:increment, fn "Jack" ->
      {:error, :too_many_requests_to_user}
    end)

    ExBanking.RequestLimiterMock
    |> expect(:decrement, fn "Jack" ->
      :ok
    end)

    assert {:error, :too_many_requests_to_user} == ExBanking.deposit("Jack", 10, "USD")

    ExBanking.RequestLimiterMock
    |> expect(:increment, fn "Jack" ->
      :ok
    end)

    assert {:ok, _} = ExBanking.deposit("Jack", 10, "USD")
  end
end
