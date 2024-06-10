#!/usr/bin/env -S ERL_FLAGS=+B elixir
Logger.configure(level: :info)

Mix.install([{:phoenix_html, "~> 4.1"}])

defmodule CreateTake do
  @moduledoc """
  Creates a Text-to-Speech audio files using AWS Polly for TTS and Sox for
  audio conversion and resampling.

  NOTE: Requires the AWS CLI and Sox to be installed and configured.

  Output WAV files are written to `priv/output`.

  Polly generated MP3s are kept in `priv/tmp`. These files are only used to
  prevent duplicate calls to the Polly API. You can safely delete these files.

  ## Usage

  1. Generate an audio file:

      $ ./scripts/create-take.exs --text "Hello, World!" --name hello-world

  2. Force regeneration of audio using Polly:

      $ ./scripts/create-take.exs --text "Hello, World!" --name hello-world --force

  3. Output this message:

      $ ./scripts/create-take.exs --help

  """
  require Logger

  @args [help: :boolean, text: :string, name: :string, force: :boolean]
  def main(args) do
    {parsed, []} = OptionParser.parse!(args, strict: @args)

    parsed = Map.new(parsed)

    cmd(parsed)
  end

  defp cmd(%{help: true}), do: usage()

  @default_polly_args ~w[
    --engine          neural
    --language-code   en-US
    --voice-id        Matthew
    --lexicon-names   mbtalexicon
    --text-type       ssml
    --output-format   mp3
    --sample-rate     22050
    --region          us-east-1
  ]

  defp cmd(%{text: text, name: name} = opts) when is_binary(text) and is_binary(name) do
    Logger.info("Converting text to speech...")

    File.mkdir_p!("priv/tmp")
    File.mkdir_p!("priv/output")

    text_hash =
      :crypto.hash(:sha256, text)
      |> Base.encode16(case: :lower)

    polly_output = Path.join(File.cwd!(), "priv/tmp/#{text_hash}.mp3")

    force? = Map.get(opts, :force, false)

    if File.exists?(polly_output) and not force? do
      Logger.info("Polly generated file exists, reusing. Use '--force' to force regenration.")
    else
      Logger.info("Generating audio file using Polly.")

      {_, 0} =
        System.cmd(
          "aws",
          ["polly", "synthesize-speech" | @default_polly_args] ++
            ["--text", to_ssml(text), polly_output]
        )
    end

    Logger.info("Converting Polly MP3 file to 8-bit WAV")

    wav_output =
      Path.join([
        File.cwd!(),
        "priv/output",
        name
      ])

    wav_output = if Path.extname(wav_output) == ".wav", do: wav_output, else: wav_output <> ".wav"

    {_, 0} = System.cmd("sox", [polly_output, "-r", "11025", "-b", "8", wav_output])

    Logger.info("8-bit WAV file: #{wav_output}")

    Logger.info("Done.")
  end

  defp cmd(args) do
    Logger.error("Unrecognized options: #{inspect(args)}")

    usage()
  end

  defp usage, do: IO.puts(@moduledoc)

  defp to_ssml(text) do
    {:safe, text} = Phoenix.HTML.html_escape(text)

    ~s|<speak><amazon:effect name="drc"><prosody volume="x-loud">#{text}</prosody></amazon:effect></speak>|
  end
end

System.argv()
|> CreateTake.main()
