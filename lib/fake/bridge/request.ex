defmodule Fake.Bridge.Request do
  def get_status("down") do
    {"Lowered", nil}
  end
  def get_status("error") do
    nil
  end
  def get_status(id) do
    {"Raised", 4}
  end
end
