defmodule ExXml do
  @moduledoc """
  ExXml allows you to use XML in your library to construct code.
  This can be helpful if you need to deal more descriptive type of
  programming like the ones that are already using a SGML or XML languages
  like HTML and ODF. It also allows you to compose components out of Pascal
  case XML elements. You can also have a list of elements which are wrapped
  with a fragment.

  Out of the box ExXml sigil `~x()` constructs the `Element` and `Fragment`
  structs that you can convert to quoted version of Elixir to create code out
  of this XML like data. It's as close to JSX as can be done in Elixir.

  ## Examples

  Simple syntax with some nesting and a self closing element

      ~x(
        <foo something=#{"b"}>
          <bar2 something="a"/>
          <a>
            2
          </a>
        </foo>
      )


  Now with a fragment

      ~x(
        <>
          <foo>
            <bar2 something="a"/>
            <a>
              2
            </a>
          </foo>
        </>
      )

  This allows you to use a module if you want

      ~x(
        <Foo>
          <bar2 something="a"/>
          <a>2</a>
        </Foo>
      )

  ## How do you implement your library with ExXml

  You have to include `use ExXml` in your module then
  implement either `parse_ex_xml` function in our library
  if you want to expose the sigil x syntax or `@parse_ex_xml`
  attribute if you want to use the syntax only within your library.
  You have to return a quoted from of you data. You can look at Elixir
  Macro documentation for that. Because the sigil syntax is a macro and
  you are probably using this library to construct something else than
  just the output of this library.
  """
  import NimbleParsec

  alias __MODULE__.{Element, Fragment}

  defmacro __using__(opts) do
    sigil_name = Keyword.get(opts, :name, :x)
    sigil = :"sigil_#{sigil_name}"

    quote do
      import ExXml

      defmacro unquote(sigil)(params, options) do
        caller = __CALLER__
        module = __MODULE__
        do_sigil_x(params, options, caller, module)
      end
    end
  end

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
    |> utf8_string([not: ?<, not: ?\n], min: 1)
    |> reduce({:trim, []})
    |> post_traverse({:sub_context_in_text, []})
    |> label("text")

  sub =
    string("$")
    |> concat(ascii_string([?0..?9], min: 1))
    |> post_traverse({:sub_context, []})
    |> label("sub")

  quote_string =
    ascii_char([?"])
    |> label("quote_string")

  quoted_attribute_text =
    ignore(whitespace)
    |> ignore(quote_string)
    |> repeat(
      lookahead_not(ascii_char([?"]))
      |> choice([
        ~s(\") |> string() |> replace(?'),
        utf8_char([])
      ])
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
    |> repeat(
      lookahead_not(choice([ascii_char([?>]), string("/>")]))
      |> choice([attribute, ascii_char([?>]), string("/>")])
    )
    |> ignore(optional(string(">")))
    |> ignore(whitespace)
    |> label("opening_tag")
    |> tag(:element)

  fragment_tag =
    ignore(whitespace)
    |> ignore(string("<"))
    |> repeat(
      lookahead_not(choice([ascii_char([?>]), string("/>")]))
      |> choice([attribute, ascii_char([?>]), string("/>")])
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
    |> repeat(
      lookahead_not(choice([string("</"), string("/>")]))
      |> choice([parsec(:xml), sub, text])
    )
    |> choice([closing_fragment, closing_tag, self_closing])
    |> reduce({:fix_element, []})
  )

  @spec parse_ex_xml([...]) :: {:ok, [%Element{} | %Fragment{}]} | {:error, String.t()}
  def parse_ex_xml(ex_xml) do
    {bin, context} = list_to_context(ex_xml)

    with {:ok, results, _, _, _, _} <- parse_xml(String.trim(bin), context: context) do
      {:ok, results}
    end
  end

  @spec list_to_context([...]) :: {binary, map}
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

  def do_sigil_x({:<<>>, _meta, pieces}, ~c"raw", _, _) do
    pieces
    |> Enum.map(&clean_litteral/1)
  end

  def do_sigil_x({:<<>>, _meta, pieces}, ~c"parse", _, _) do
    pieces
    |> Enum.map(&clean_litteral/1)
    |> parse_ex_xml()

    nil
  end

  def do_sigil_x({:<<>>, _meta, pieces}, ~c"debug", caller, module) do
    {:ok, ex_xml} =
      pieces
      |> Enum.map(&clean_litteral/1)
      |> parse_ex_xml()

    ast =
      if Kernel.function_exported?(module, :process_ex_xml, 2) do
        module.process_ex_xml(ex_xml, caller)
      else
        case Module.get_attribute(caller.module, :process_ex_xml) do
          nil ->
            {:ok, escape_ex_xml(ex_xml)}

          process_ex_xml ->
            process_ex_xml.(ex_xml, caller)
        end
      end

    ast |> Macro.to_string() |> Code.format_string!() |> IO.puts()
    ast
  end

  def do_sigil_x({:<<>>, _meta, pieces}, ~c"", caller, module) do
    with {:ok, ex_xml} <-
           pieces
           |> Enum.map(&clean_litteral/1)
           |> parse_ex_xml() do
      if Kernel.function_exported?(module, :process_ex_xml, 2) do
        module.process_ex_xml(ex_xml, caller)
      else
        case Module.get_attribute(caller.module, :process_ex_xml) do
          nil ->
            {:ok, escape_ex_xml(ex_xml)}

          process_ex_xml ->
            process_ex_xml.(ex_xml, caller)
        end
      end
    else
      {:error, message, _rest, _context, _line, _column} ->
        {:error, message}
    end
  end

  @spec escape_ex_xml([...]) :: Macro.t()
  def escape_ex_xml(list) when is_list(list) do
    do_escape_ex_xml(list)
  end

  defp do_escape_ex_xml(list) when is_list(list) do
    Enum.map(list, &do_escape_ex_xml/1)
  end

  defp do_escape_ex_xml(%{__struct__: module} = struct) do
    keyword_list =
      struct
      |> Map.from_struct()
      |> Enum.map(&do_escape_ex_xml/1)

    {:%, [], [{:__aliases__, [alias: false], [module]}, {:%{}, [], keyword_list}]}
  end

  defp do_escape_ex_xml(%{} = map) do
    keyword_list =
      map
      |> Enum.map(&do_escape_ex_xml/1)

    {:%{}, [], keyword_list}
  end

  defp do_escape_ex_xml({key, value}) do
    {key, do_escape_ex_xml(value)}
  end

  defp do_escape_ex_xml(other) do
    other
  end

  @spec fix_element_based_on_type(atom, [...], [...]) ::
          {:ok, %Element{} | %Fragment{}} | {:error, String.t()}
  defp fix_element_based_on_type(:fragment, content, nested) do
    meta = Enum.reduce(content, %{}, &get_meta_content/2)
    {closing_fragment, new_nested} = List.pop_at(nested, -1)

    if {:closing_fragment, []} !== closing_fragment do
      {:error, "Fragment isn't closed"}
    else
      {:ok, struct(Fragment, Map.put(meta, :children, List.flatten(new_nested)))}
    end
  end

  defp fix_element_based_on_type(:element, content, nested) do
    meta = Enum.reduce(content, %{}, &get_meta_content/2)
    tag = List.first(content)
    {closing_tag, new_nested} = List.pop_at(nested, -1)

    if not (is_nil(closing_tag) or {:closing_tag, List.wrap(tag)} === closing_tag) do
      with {:closing_tag, cl_tag} <- closing_tag do
        {:error,
         "Closing tag doesn't match opening tag open_tag: #{inspect(tag)} closing_tag: #{inspect(cl_tag)}"}
      else
        _ ->
          {:error,
           "Closing tag doesn't match opening tag open_tag: #{inspect(tag)} closing_tag: #{inspect(closing_tag)}"}
      end
    else
      {:ok, struct(Element, Map.put(meta, :children, List.flatten(new_nested)))}
    end
  end

  @spec fix_element([{atom, [...]}, ...]) :: %Element{} | %Fragment{} | {:error, String.t()}
  defp fix_element([{type, content} | nested]) do
    with {:ok, result} <- fix_element_based_on_type(type, content, nested) do
      result
    end
  end

  @spec trim([binary]) :: binary
  defp trim([string]) when is_binary(string) do
    string
    |> String.trim()
  end

  @spec get_meta_content({atom, [...]}, map) :: map
  def get_meta_content({:attribute, [{:tag, [key]}, value]}, acc) do
    Map.update(acc, :attributes, %{key => value}, &Map.put(&1, key, value))
  end

  def get_meta_content({:element_name, [{type, [name]}]}, acc) do
    acc
    |> Map.put(:name, name)
    |> Map.put(:type, type)
  end

  @spec clean_litteral(Macro.t() | binary) :: Macro.t() | binary
  defp clean_litteral(
         {:"::", _, [{{:., _, [Kernel, :to_string]}, _, [litteral]}, {:binary, _, nil}]}
       ) do
    {:ok, litteral}
  end

  defp clean_litteral(other) do
    other
  end

  @spec sub_context(binary, [binary], map, {integer, integer}, integer) :: {[...], map}
  defp sub_context(rest, args, context, _line, _offset) do
    ref = args |> Enum.reverse() |> Enum.join()
    {:ok, value} = context |> Map.get(ref)
    {rest, [value], context}
  end

  @spec sub_context_in_text(binary, [binary], map, {integer, integer}, integer) :: {[...], map}
  defp sub_context_in_text(rest, [text], context, _line, _offset) do
    new_text =
      Regex.split(~r/\$\d+/, text, include_captures: true)
      |> Enum.map(fn text_fragment ->
        case Map.get(context, text_fragment) do
          {:ok, value} -> value
          _ -> text_fragment
        end
      end)
      |> Enum.reject(&match?("", &1))
      |> :lists.reverse()

    {rest, new_text, context}
  end
end
