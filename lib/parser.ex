defmodule Parser do
  def load_csv(file) do
    File.read!(file)
  end

  def get_keys(line, opt) do
    String.split(line, opt)
  end

  def is_my_boolean(value) do
    String.downcase(value) == "true"
  end

  def parse_field(value, function) when is_function(function) do
    try do
      {:ok, function.(value)}
    catch
      _ ->
        {:error, :conversion_error, value}
    end
  end

  def parse_field(value, :integer), do: parse_field(value, &String.to_integer/1)
  def parse_field(value, :float), do: parse_field(value, &String.to_float/1)
  def parse_field(value, :boolean), do: parse_field(value, &is_my_boolean/1)
  def parse_field(value, :string), do: {:ok, value}

  def parse_field(keys, key, data_type) do
    if Map.has_key?(keys, key) do
      parse_field(keys[key], data_type)
    else
      {:error, :field_not_found}
    end
  end

  def parse_line(raw_keys, {index, line}, map, opt) do
    raw_values = get_keys(line, opt[:sep])
    keys = raw_keys |> Enum.zip(raw_values) |> Map.new()

    list =
      Enum.map(map, fn {key, data_type} ->
        case parse_field(keys, key, data_type) do
          {:ok, value} ->
            {:ok, Map.new([{key, value}])}

          {:error, :conversion_error, value} ->
            {:error,
             %{line: index, field: key, value: value, note: "can't apply the #{data_type} type"}}

          {:error, :field_not_found} ->
            {:error, %{line: index, field: key, note: "can't find the #{key} field"}}
        end
      end)
      |> Enum.group_by(fn {key, _} -> key end, fn {_, value} -> value end)

    if Map.has_key?(list, :ok) do
      Map.put(list, :ok, Enum.reduce(list[:ok], %{}, fn map, acc -> Map.merge(map, acc) end))
    end
  end

  def parse_data(data, map, opt) do
    {_, [raw_values | raw_lines]} = data |> String.split("\r\n") |> List.pop_at(-1)
    keys = get_keys(raw_values, opt[:sep])
    lines = Enum.zip(1..Enum.count(raw_lines), raw_lines)

    parsed_file = Enum.map(lines, &parse_line(keys, &1, map, opt))

    errors =
      Enum.reduce(parsed_file, [], fn map, acc ->
        if Map.has_key?(map, :error) do
          acc ++ map[:error]
        else
          acc ++ []
        end
      end)

    data =
      Enum.reduce(parsed_file, [], fn map, acc ->
        if Map.has_key?(map, :ok) do
          acc ++ [map[:ok]]
        end
      end)

    if Enum.count(errors) > 0 do
      {:error, errors}
    else
      {:ok, data}
    end
  end

  def main() do
    file_name = "C2ImportSchoolSample.csv"

    data = load_csv(file_name)

    map = %{
      "Active" => :boolean,
      "Image" => :string,
      "System ID" => :string
    }

    opt = %{
      sep: ","
    }

    parse_data(data, map, opt)
  end
end
