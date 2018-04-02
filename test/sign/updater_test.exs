defmodule Sign.UpdaterTest do
  use ExUnit.Case, async: true
  import Sign.Updater
  import ExUnit.CaptureLog
  alias Sign.{Message, Content}

  @time ~N[2016-08-19 05:36:23]

  test "makes a request with the right params" do
    message = Message.new |> Message.message("Park St  4 min")
    update = Content.new
    |> Content.station("GPRK")
    |> Content.messages([message])

    log = capture_log [level: :warn], fn ->
      refute send_request(update, @time, 9)
    end

    assert log == ""
  end

  test "Logs error when unsucessful status code is found in response" do
    message = Message.new |> Message.message("Park St  4 min")
    update = Content.new
    |> Content.station("GPRK")
    |> Content.messages([message])

    log = capture_log [level: :warn], fn ->
      send_request(update, @time, 10)
    end

    assert log =~ "head_end_post_error: response had status code: 500"
  end

  test "Logs error when head-end server times out" do
    message = Message.new |> Message.message("Park St  4 min")
    update = Content.new
    |> Content.station("GPRK")
    |> Content.messages([message])

    log = capture_log [level: :warn], fn ->
      send_request(update, @time, 11)
    end

    assert log =~ "head_end_post_error: :timeout"
  end
end
