defmodule RealtimeSignsWeb do
  def controller do
    quote do
      use Phoenix.Controller, namespace: RealtimeSignsWeb
      import Plug.Conn
      import RealtimeSignsWeb.Router.Helpers
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/realtime_signs_web/templates",
        namespace: RealtimeSignsWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      use Phoenix.HTML

      import RealtimeSignsWeb.Router.Helpers
      import RealtimeSignsWeb.ErrorHelpers

      # Include shared imports and aliases for views
      # unquote(view_helpers())
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
