defmodule Signs.Utilities.SignText do
  @moduledoc """
  Functions for handling Sign Text Length information
  """

  @short_sign_scu_ids ["SCOUSCU001"]
  @width 24
  @short_width 18

  def sign_length(scu_id) when scu_id in @short_sign_scu_ids, do: :short
  def sign_length(_), do: :long

  def max_text_length(scu_id) when scu_id in @short_sign_scu_ids, do: @short_width
  def max_text_length(_), do: @width
end
