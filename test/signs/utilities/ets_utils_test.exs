defmodule EtsUtilsTest do
  use ExUnit.Case
  alias Signs.Utilities.EtsUtils

  # Helper to create a temporary ETS table
  defp create_table do
    :ets.new(:test_table, [:named_table, :set, :public, {:keypos, 1}])
  end

  setup do
    # Create a fresh table before each test
    table = create_table()
    {:ok, table: table}
  end

  ###################################################################
  # write_ets tests
  ###################################################################

  test "write_ets inserts a single key-value pair into the table", %{table: table} do
    # Act
    EtsUtils.write_ets(table, %{:key1 => "value1"}, :none)

    # Assert
    assert {:key1, "value1"} in :ets.tab2list(table)
  end

  test "write_ets inserts multiple entries", %{table: table} do
    # Act
    EtsUtils.write_ets(table, %{:key1 => "value1", :key2 => "value2", :key3 => "value3"}, [])

    # Assert
    assert {:key1, "value1"} in :ets.tab2list(table)
    assert {:key2, "value2"} in :ets.tab2list(table)
    assert {:key3, "value3"} in :ets.tab2list(table)
  end

  test "write_ets replaces existing entries with new ones", %{table: table} do
    # Arrange
    :ets.insert(table, {:key1, "old_value1"})
    :ets.insert(table, {:key2, "old_value2"})

    # Act
    EtsUtils.write_ets(table, %{:key1 => "new_value1", :key3 => "new_value3"}, [])

    # Assert
    assert {:key1, "new_value1"} in :ets.tab2list(table)
    assert {:key3, "new_value3"} in :ets.tab2list(table)
    refute {:key2, "old_value2"} in :ets.tab2list(table)
    assert {:key2, []} in :ets.tab2list(table)
  end

  test "write_ets updates values of keys not in the new entries to the empty_value", %{
    table: table
  } do
    # Arrange
    :ets.insert(table, {:key1, "old_value1"})
    :ets.insert(table, {:key2, "old_value2"})

    # Act
    EtsUtils.write_ets(table, %{:key1 => "new_value1"}, :none)

    # Assert
    assert {:key1, "new_value1"} in :ets.tab2list(table)
    assert {:key2, :none} in :ets.tab2list(table)
  end

  ###################################################################
  # replace_contents tests
  ###################################################################

  test "replace_contents inserts single tuple into an empty table", %{table: table} do
    # Act
    EtsUtils.replace_contents(table, {:key1, "value1"})

    # Assert
    assert {:key1, "value1"} in :ets.tab2list(table)
  end

  test "replace_contents inserts a single entry when new entry is a tuple", %{table: table} do
    # Act
    EtsUtils.replace_contents(table, {:key1, "value1"})

    # Assert
    assert {:key1, "value1"} in :ets.tab2list(table)
  end

  test "inserts multiple entries when new entries is a list of tuples", %{table: table} do
    # Act
    EtsUtils.replace_contents(table, [{:key1, "value1"}, {:key2, "value2"}, {:key3, "value3"}])

    # Assert
    assert {:key1, "value1"} in :ets.tab2list(table)
    assert {:key2, "value2"} in :ets.tab2list(table)
    assert {:key3, "value3"} in :ets.tab2list(table)
  end

  test "replace_contents replaces existing entries with new ones", %{table: table} do
    # Arrange
    :ets.insert(table, {:key1, "old_value1"})
    :ets.insert(table, {:key2, "old_value2"})

    # Act
    EtsUtils.replace_contents(table, [{:key1, "new_value1"}, {:key3, "new_value3"}])

    # Assert
    assert {:key1, "new_value1"} in :ets.tab2list(table)
    assert {:key3, "new_value3"} in :ets.tab2list(table)
    refute {:key2, "old_value2"} in :ets.tab2list(table)
  end

  test "replace_contents removes keys that are not in the new entries", %{table: table} do
    # Arrange
    :ets.insert(table, {:key1, "old_value1"})
    :ets.insert(table, {:key2, "old_value2"})

    # Act
    EtsUtils.replace_contents(table, [{:key1, "new_value1"}])

    # Assert
    assert {:key1, "new_value1"} in :ets.tab2list(table)
    refute {:key2, "old_value2"} in :ets.tab2list(table)
  end
end
