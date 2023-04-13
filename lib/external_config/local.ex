defmodule ExternalConfig.Local do
  @behaviour ExternalConfig.Interface

  @impl ExternalConfig.Interface
  def get(current_version) do
    file =
      with path when not is_nil(path) <- Application.get_env(:realtime_signs, :sign_config_file),
           {:ok, file} <- File.read(path) do
        file
      else
        _ -> "{}"
      end

    etag =
      file
      |> :erlang.phash2()
      |> Kernel.inspect()

    if etag == current_version do
      :unchanged
    else
      {etag, Jason.decode!(file)}
    end
  end

  def get_active_headend_ip() do
    {:ok, nil}
  end

  def put_active_headend_ip(_ip) do
    {:ok, nil}
  end
end
