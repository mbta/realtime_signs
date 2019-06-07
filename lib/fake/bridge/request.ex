defmodule Fake.Bridge.Request do
  require Logger

  def get_status("down", _time) do
    {"Lowered", nil}
  end

  def get_status("error", _time) do
    nil
  end

  def get_status(_id, _time) do
    {"Raised", 4}
  end
end
