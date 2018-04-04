defmodule Sign.Static.Parser.StaticTextTest do
  use ExUnit.Case
  import Sign.Static.Parser.StaticText
  import ExUnit.CaptureLog

  @file_path "test/data/static_test.json"

  setup do
    on_exit fn ->
      File.rm(@file_path)
    end
  end

  describe "parse/1" do
    test "Correctly reads valid json file" do
      static_text_map = %{"70262" => %{"direction" =>  0, "top_text" => "top text", "bottom_text" => "bottom text"}}
      File.write!(@file_path, Poison.encode!(static_text_map))
      expected = [%Sign.Static.Message{
        station_id: "70262",
        sign_id: "RASH",
        direction: 0,
        top_text: "top text",
        bottom_text: "bottom text"
      }]
      assert parse(@file_path) == expected
    end

    test "warns if file cannot be read" do
      bogus_file = "made_up_dir/made_up_name"
      log = capture_log [level: :warn], fn ->
        assert parse(bogus_file) == []
      end

      assert log =~ "Could not read \"#{bogus_file}\""
    end

    test "warns if file cannot be parsed" do
      File.write!(@file_path, :erlang.term_to_binary(5))
      log = capture_log [level: :warn], fn ->
        assert parse(@file_path) == []
      end

      assert log =~ "Could not parse static text file:"
    end
  end
end
