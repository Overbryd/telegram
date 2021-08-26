defmodule Test.Telegram.Bot.Poller do
  use ExUnit.Case, async: false
  import Test.Utils.{Const, Mock}

  setup_all do
    Test.Utils.Mock.tesla_mock_global_async()
    :ok
  end

  describe "getUpdates" do
    setup _context do
      setup_poller(false)
    end

    test "basic flow" do
      url_get_updates = tg_url(tg_token(), "getUpdates")

      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url_get_updates},
                 fn %{body: body} ->
                   body = Jason.decode!(body)
                   assert body["offset"] == nil

                   response = %{"ok" => true, "result" => []}
                   Tesla.Mock.json(response, status: 200)
                 end
               )

      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url_get_updates},
                 fn %{body: body} ->
                   body = Jason.decode!(body)
                   assert body["offset"] == nil

                   result = [
                     %{
                       "update_id" => 1,
                       "message" => %{"text" => "/test"}
                     }
                   ]

                   response = %{"ok" => true, "result" => result}
                   Tesla.Mock.json(response, status: 200)
                 end
               )

      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url_get_updates},
                 fn %{body: body} ->
                   body = Jason.decode!(body)
                   assert body["offset"] == 2

                   response = %{"ok" => true, "result" => []}
                   Tesla.Mock.json(response, status: 200)
                 end
               )
    end

    test "response error" do
      url = tg_url(tg_token(), "getUpdates")

      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url},
                 fn %{body: body} ->
                   body = Jason.decode!(body)
                   assert body["offset"] == nil

                   response = %{"ok" => false, "description" => "AZZ"}
                   Tesla.Mock.json(response, status: 200)
                 end
               )

      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url},
                 fn %{body: body} ->
                   body = Jason.decode!(body)
                   assert body["offset"] == nil

                   response = %{"ok" => true, "result" => []}
                   Tesla.Mock.json(response, status: 200)
                 end
               )
    end
  end

  describe "purge old updates" do
    setup _context do
      setup_poller(true)
    end

    test "nothing to purge, first message without sent date" do
      url_get_updates = tg_url(tg_token(), "getUpdates")

      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url_get_updates},
                 fn %{body: body} ->
                   body = Jason.decode!(body)
                   assert body["offset"] == nil

                   result = [
                     %{
                       "update_id" => 1,
                       "message" => %{"text" => "/test"}
                     }
                   ]

                   response = %{"ok" => true, "result" => result}
                   Tesla.Mock.json(response, status: 200)
                 end
               )

      # first non purged update
      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url_get_updates},
                 fn %{body: body} ->
                   body = Jason.decode!(body)
                   assert body["offset"] == 1

                   response = %{"ok" => true, "result" => []}
                   Tesla.Mock.json(response, status: 200)
                 end
               )
    end

    test "Telegram.Bot purge old messages" do
      url = tg_url(tg_token(), "getUpdates")

      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url},
                 fn %{body: body} ->
                   now = DateTime.utc_now() |> DateTime.to_unix(:second)
                   old = now - 1_000

                   body = Jason.decode!(body)
                   assert body["offset"] == nil

                   result = [
                     %{
                       "update_id" => 1,
                       "message" => %{
                         "text" => "OLD",
                         "date" => old
                       }
                     },
                     %{
                       "update_id" => 2,
                       "message" => %{
                         "text" => "OLD",
                         "date" => old
                       }
                     },
                     %{
                       "update_id" => 3,
                       "message" => %{
                         "text" => "OLD",
                         # << not too old
                         "date" => now + 1_000
                       }
                     }
                   ]

                   response = %{"ok" => true, "result" => result}
                   Tesla.Mock.json(response, status: 200)
                 end
               )

      # first non purged update
      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url},
                 fn %{body: body} ->
                   body = Jason.decode!(body)
                   assert body["offset"] == 3

                   response = %{"ok" => true, "result" => []}
                   Tesla.Mock.json(response, status: 200)
                 end
               )
    end

    test "Telegram.Bot purge old messages 2" do
      url = tg_url(tg_token(), "getUpdates")

      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url},
                 fn %{body: body} ->
                   now = DateTime.utc_now() |> DateTime.to_unix(:second)
                   old = now - 1_000

                   body = Jason.decode!(body)
                   assert body["offset"] == nil

                   result = [
                     %{
                       "update_id" => 1,
                       "message" => %{
                         "text" => "OLD",
                         "date" => old
                       }
                     },
                     %{
                       "update_id" => 2,
                       "message" => %{
                         "text" => "OLD",
                         "date" => old
                       }
                     }
                   ]

                   response = %{"ok" => true, "result" => result}
                   Tesla.Mock.json(response, status: 200)
                 end
               )

      # first non purged update
      assert :ok ==
               tesla_mock_expect_request(
                 %{method: :post, url: ^url},
                 fn %{body: body} ->
                   body = Jason.decode!(body)
                   assert body["offset"] == 3

                   response = %{"ok" => true, "result" => []}
                   Tesla.Mock.json(response, status: 200)
                 end
               )
    end
  end

  defp setup_poller(purge) do
    t_token = tg_token()
    options = [purge: purge]

    handle_update = fn update, token ->
      assert token == t_token
      assert %{"message" => %{"text" => "/test"}} = update
    end

    start_supervised!({Telegram.Bot.Poller, {handle_update, t_token, options}})

    :ok
  end
end
