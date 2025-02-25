defmodule Content.Message do
  @type value :: String.t() | [{String.t(), non_neg_integer()}]
  @type pages :: [{top :: String.t(), bottom :: String.t(), duration :: integer()}]
end
