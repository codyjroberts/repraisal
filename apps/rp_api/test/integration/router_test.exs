defmodule RpAPI.RouterIntegrationTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias RpAPI.Router

  @opts Router.init([])

  test "/unknown 404" do
    conn = conn(:get, "/somepath")
    conn = Router.call(conn, @opts)
    assert conn.status == 404
  end
end
