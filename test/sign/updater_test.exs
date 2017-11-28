defmodule Sign.UpdaterTest do
  use ExUnit.Case, async: true
  alias Sign.Message, as: M
  alias Sign.Content, as: SC
  alias Sign.Updater, as: R

  test "makes a request with the right params" do
    test_time = ~N[2016-08-19 05:36:23]
    message = M.new |> M.message("Park St  4 min")
    update = SC.new
    |> SC.station("GPRK")
    |> SC.messages([message])

    {url, body, headers} = R.send_request(update, test_time, 10)
    assert url == "http://127.0.0.1/mbta/cgi-bin/RemoteMsgsCgi.exe"
    assert body == "MsgType=SignContent&uid=11&sta=GPRK&c=-%22Park+St++4+min%22"
    assert headers == [{"Content-type", "application/x-www-form-urlencoded"}]
  end
end
