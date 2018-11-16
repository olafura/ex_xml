defmodule Exx do
  @moduledoc """
  Documentation for Exx.
  """
  import NimbleParsec

  alias __MODULE__.{Element, Fragment}

  whitespace =
    ascii_string([?\s, ?\n, ?\t], max: 100)
    |> label("whitespace")

  tag =
    ascii_char([?a..?z])
    |> reduce({Kernel, :to_string, []})
    |> concat(optional(ascii_string([?a..?z, ?_, ?0..?9, not: ?=], min: 1)))
    |> ignore(whitespace)
    |> reduce({Enum, :join, [""]})
    |> label("tag")
    |> tag(:tag)

  module =
    ascii_char([?A..?Z])
    |> reduce({Kernel, :to_string, []})
    |> concat(optional(ascii_string([?a..?z, ?0..?9, ?A..?Z, ?., not: ?=], min: 1)))
    |> ignore(whitespace)
    |> reduce({Enum, :join, [""]})
    |> label("module")
    |> tag(:module)

  element_name =
    choice([tag, module])
    |> label("element_name")
    |> tag(:element_name)

  text =
    ignore(whitespace)
    |> utf8_string([not: ?<], min: 1)
    |> label("text")

  sub =
    string("$")
    |> concat(ascii_string([?0..?9], min: 1))
    |> traverse({:sub_context, []})
    |> label("sub")

  quote_string =
    ascii_char([?"])
    |> label("quote_string")

  quoted_attribute_text =
    ignore(whitespace)
    |> ignore(quote_string)
    |> repeat_until(
      choice([
        ~s(\") |> string() |> replace(?'),
        utf8_char([])
      ]),
      [ascii_char([?"])]
    )
    |> ignore(quote_string)
    |> reduce({List, :to_string, []})
    |> label("quoted_attribute_text")

  attribute =
    ignore(whitespace)
    |> concat(tag)
    |> ignore(string("="))
    |> choice([sub, quoted_attribute_text])
    |> label("attribute")
    |> tag(:attribute)

  opening_tag =
    ignore(whitespace)
    |> ignore(string("<"))
    |> concat(element_name)
    |> repeat_until(
      choice([attribute, ascii_char([?>]), string("/>")]),
      [ascii_char([?>]), string("/>")]
    )
    |> ignore(optional(string(">")))
    |> ignore(whitespace)
    |> label("opening_tag")
    |> tag(:element)

  fragment_tag =
    ignore(whitespace)
    |> ignore(string("<"))
    |> repeat_until(
      choice([attribute, ascii_char([?>]), string("/>")]),
      [ascii_char([?>]), string("/>")]
    )
    |> ignore(string(">"))
    |> ignore(whitespace)
    |> label("fragment_tag")
    |> tag(:fragment)

  closing_tag =
    ignore(whitespace)
    |> ignore(string("</"))
    |> concat(element_name)
    |> ignore(string(">"))
    |> ignore(whitespace)
    |> label("closing_tag")
    |> tag(:closing_tag)

  closing_fragment =
    ignore(whitespace)
    |> ignore(string("</>"))
    |> ignore(whitespace)
    |> label("closing_fragment")
    |> tag(:closing_fragment)


  self_closing =
    ignore(whitespace)
    |> ignore(string("/>"))
    |> ignore(whitespace)
    |> label("self_closing")

  defparsec(
    :parse_xml,
    parsec(:xml)
  )

  defcombinatorp(
    :xml,
    choice([fragment_tag, opening_tag])
    |> repeat_until(choice([parsec(:xml), sub, text]), [string("</"), string("/>")])
    |> choice([closing_fragment, closing_tag, self_closing])
    |> reduce({:fix_element, []})
  )

  def parse_exx(exx) do
    {bin, context} = list_to_context(exx)

    with {:ok, results, _, _, _, _} <- parse_xml(String.trim(bin), context: context) do
      {:ok, results}
    end
  end

  def list_to_context(list) when is_list(list) do
    {_, context, acc_list} =
      list
      |> Enum.reduce({1, [], []}, fn
        bin, {index, context, acc_list} when is_binary(bin) ->
          {index, context, [bin | acc_list]}

        other, {index, context, acc_list} ->
          ref = "$#{index}"
          {index + 1, [{ref, other} | context], [ref | acc_list]}
      end)

    {acc_list |> Enum.reverse() |> Enum.join(), Enum.into(context, %{})}
  end

  def list_to_context(bin) when is_binary(bin) do
    {bin, %{}}
  end

  defmacro sigil_x({:<<>>, _meta, pieces}, 'raw') do
    pieces
    |> Enum.map(&clean_litteral/1)
  end

  defmacro sigil_x({:<<>>, _meta, pieces}, 'parse') do
    pieces
    |> Enum.map(&clean_litteral/1)
    |> parse_exx()

    nil
  end

  defmacro sigil_x({:<<>>, _meta, pieces}, '') do
    {:ok, exx} =
      pieces
      |> Enum.map(&clean_litteral/1)
      |> parse_exx()

    exx
  end

  defp fix_element_based_on_type(:fragment, content, nested) do
    meta = Enum.reduce(content, %{}, &get_meta_content/2)
    {closing_fragment, new_nested} = List.pop_at(nested, -1)

    if {:closing_fragment, []} !== closing_fragment do
      raise "Fragment isn't closed"
    end

    struct(Fragment, Map.put(meta, :children, List.flatten(new_nested)))
  end

  defp fix_element_based_on_type(:element, content, nested) do
    meta = Enum.reduce(content, %{}, &get_meta_content/2)
    tag = List.first(content)
    {closing_tag, new_nested} = List.pop_at(nested, -1)

    if not (is_nil(closing_tag) or {:closing_tag, List.wrap(tag)} === closing_tag) do
      with {:closing_tag, cl_tag} <- closing_tag do
        raise "Closing tag doesn't match opening tag open_tag: #{inspect(tag)} closing_tag: #{inspect(cl_tag)}"
      else
        _ ->
          raise "Closing tag doesn't match opening tag open_tag: #{inspect(tag)} closing_tag: #{inspect(closing_tag)}"
      end
    end

    struct(Element, Map.put(meta, :children, List.flatten(new_nested)))
  end

  defp fix_element([{type, content} | nested]) do
    fix_element_based_on_type(type, content, nested)
  end

  defp fix_element(other) do
    other
  end

  def get_meta_content({:attribute, [{:tag, [key]}, value]}, acc) do
    Map.update(acc, :attributes, %{key => value}, &Map.put(&1, key, value))
  end

  def get_meta_content({:element_name, [{type, [name]}]}, acc) do
    acc
    |> Map.put(:name, name)
    |> Map.put(:type, type)
  end

  defp clean_litteral(
         {:::, _, [{{:., _, [Kernel, :to_string]}, _, [litteral]}, {:binary, _, nil}]}
       ) do
    {:ok, litteral}
  end

  defp clean_litteral(other) do
    other
  end

  defp sub_context(_rest, args, context, _line, _offset) do
    ref = args |> Enum.reverse() |> Enum.join()
    {:ok, value} = context |> Map.get(ref)
    {[value], context}
  end
end
