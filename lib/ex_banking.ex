defmodule ExBanking do

  use GenServer


  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

#-------------------------  Client ---------------------------------
#-------------------------         ----------------------------------

  defguard string_valid(value) when is_binary(value) and byte_size(String.trim(value)) > 0


  def create_user(user) when string_valid(user) do
    GenServer.call(__MODULE__, {:create_user, user})
  end

  def create_user(_), do: {:error, :wrong_arguments}


  def deposit(user, amount, currency) when string_valid(user) and is_number(amount) and amount > 0 and string_valid(currency) do
    GenServer.call(__MODULE__, {:deposit, %{user: user, amount: amount, currency: currency}})
  end

  def deposit(_,_,_), do: {:error, :wrong_arguments}

  def withdraw(user, amount, currency) when string_valid(user) and is_number(amount) and amount > 0 and string_valid(currency) do
    GenServer.call(__MODULE__, {:withdraw, %{user: user, amount: amount, currency: currency}})
  end

  def withdraw(_,_,_), do: {:error, :wrong_arguments}

  def get_balance(user, currency) when string_valid(user) and string_valid(currency) do
    GenServer.call(__MODULE__, {:get_balance, %{user: user,  currency: currency}})
  end

  def get_balance(_,_), do: {:error, :wrong_arguments}

  def send(from_user, to_user, amount, currency) when string_valid(from_user) and string_valid(to_user) and is_number(amount) and amount > 0 and string_valid(currency)do
    GenServer.call(__MODULE__, {:send, %{from_user: from_user, to_user: to_user, amount: amount, currency: currency}})
  end

  def send(_,_,_,_), do: {:error, :wrong_arguments}

  # ------------------- Server (Callbacks) ----------------------------------
  #--------------------                 ----------------------------------


  def handle_call({:create_user, user}, _from, state) do
    if user_exist?(state, user) do
      {:reply, {:error, :user_already_exists} , state}
    else
      {:reply, :ok, Map.put(state, user , %{})}
    end
  end

  def handle_call({:deposit, transaction }, _from, state) do

    IO.puts " user depositing........"
    IO.inspect transaction
    IO.puts "current state of the user(depositing)..........."
    IO.inspect state
    %{user: user, amount: amount, currency: currency} = transaction

    if user_exist?(state, user) do

      cond do
        user_has_currency?(user_currencies(state, user), currency) ->
          new_amount =  state[user][currency] + amount
          {:reply, :ok ,update_user_balance(state, user ,currency, new_amount)}

         true ->
          {:reply, :ok , update_user_balance(state, user, currency, amount)}
      end
    else
      {:reply, {:error, :user_does_not_exist}, state}
    end

  end


  def handle_call({:withdraw, transaction}, _from, state) do
    IO.puts " user withdrawing........"
    IO.inspect transaction
    IO.puts "current state of the user(withdrawing)..........."
    IO.inspect state

    %{user: user, amount: amount, currency: currency} = transaction

    if user_exist?(state, user) do
      cond do
        user_has_currency?(user_currencies(state, user), currency) &&  state[user][currency] > amount ->

          new_balance = state[user][currency] - amount
          {:reply, {:ok, new_balance } ,update_user_balance(state, user ,currency, new_balance)}

        user_has_currency?(user_currencies(state, user), currency) &&  state[user][currency] < amount ->
          {:reply, {:error, :not_enough_money  } , state}

        true ->
          {:reply, {:error, :not_enough_money  } , state}
      end
    else
      {:reply, {:error, :user_does_not_exist}, state}
    end
  end



  def handle_call({:get_balance, transaction}, _from, state) do
    IO.puts " user balance........"
    IO.inspect transaction
    IO.puts "current state of the user (balance)..........."
    IO.inspect state
    %{user: user,  currency: currency} = transaction

    if user_exist?(state, user) do
      cond do
        user_has_currency?(user_currencies(state, user), currency) ->

          {:reply, {:ok, user_balance(user_currencies(state, user), currency)} , state}

         true ->
          {:reply, {:ok, 0} , state}
      end
    else
      {:reply, {:error, :user_does_not_exist}, state}
    end
  end


  def handle_call({:send, transaction}, _from, state) do
    IO.puts " user sending........"
    IO.inspect transaction
    IO.puts "current state of the user(withdrawing)..........."
    IO.inspect state

    %{from_user: from_user, to_user: to_user, amount: amount, currency: currency} = transaction

    with :ok <- user_exist?(state, from_user, to_user),
         true <- user_has_currency?(user_currencies(state, from_user), currency) &&  state[from_user][currency] > amount do

      sender_new_balance = state[from_user][currency] - amount
      receiver_new_balance =
        if user_has_currency?(user_currencies(state, to_user), currency), do:  state[to_user][currency] + amount, else: amount


      {:reply, {:ok, sender_new_balance, receiver_new_balance } , update_user_balance(state, from_user, sender_new_balance, to_user, receiver_new_balance ,currency)}

    else
      {:error, :from_user_does_not_exist} ->
            {:reply, {:error, :sender_does_not_exist }, state}

      {:error, :to_user_does_not_exist} ->
            {:reply, {:error, :receiver_does_not_exist  }, state}
      _ ->
        {:reply, {:error, :not_enough_money } , state}

    end
  end





  #--------------------- Private Utility/Helper functions ----------------------------------
  #--------------------                                   ----------------------------------


  defp user_exist?(state, user), do: Map.has_key?(state, user)

  defp user_exist?(state, from_user, to_user) do
    cond do
     !user_exist?(state, from_user) ->
        {:error, :from_user_does_not_exist}
     !user_exist?(state, to_user) ->
        {:error, :to_user_does_not_exist}
     true ->
        :ok
     end
  end

  defp user_has_currency?(user_currencies, currency), do: Map.has_key?(user_currencies, currency)

  defp user_balance(user_currencies, currency), do:  Map.get(user_currencies, currency)

  defp user_currencies(state, user), do: Map.get(state, user)

  defp update_user_balance(state, user, currency, amount) do
    updated_user_data =  Map.put(state[user], currency, amount)
    %{state | user => updated_user_data}
  end

  defp update_user_balance(state, sender, sender_balance, receiver, receiver_balance, currency) do
    update_user_balance(state, sender, currency, sender_balance)
    |> update_user_balance(receiver, currency, receiver_balance)
  end

end

# Datastructure
#  %{"chinedu" => %{"NGN" => 0.0, "USD" => 0.0}}
#  %{user => %{currency => balance, currency => balance}}
