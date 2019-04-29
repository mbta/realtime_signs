defmodule Content.Message.Custom do
  @moduledoc """
  Custom text entered by a PIO to override other predictions or alert messages
  """
  require Logger
  @enforce_keys [:line, :message]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          line: Content.line(),
          message: String.t()
        }
  @spec new(String.t(), :top | :bottom) :: t()
  def new("", _) do
    Content.Message.Empty.new()
  end

  def new(message, line) do
    if is_valid_message?(message, line) do
      %__MODULE__{
        line: line,
        message: message
      }
    else
      Logger.error("Invalid custom message: #{inspect(message)}")

      %__MODULE__{
        line: line,
        message: ""
      }
    end
  end

  @spec is_valid_message?(String.t(), :top | :bottom) :: boolean()
  defp is_valid_message?(message, line) do
    max_length = if line == :top, do: 18, else: 24

    cond do
      String.length(message) > max_length -> false
      Regex.match?(~r/^[a-zA-Z0-9,.!@' ]*$/, message) -> true
      true -> false
    end
  end

  defimpl Content.Message do
    def to_string(message) do
      message.message
    end
  end
end
