defmodule Mustache.Compiler do

  def compile(source, bindings, options) do
    line = options[:line] || 1
    tokens = Mustache.Tokenizer.tokenize(source, line)

    partials = options[:partials] || []
    partials = Enum.map partials, fn({ k,partial}) -> { k, Mustache.Tokenizer.tokenize(partial, line) } end

    build(tokens, bindings) |> List.flatten |> Enum.join
  end


  def escape(value) do
    Mustache.Utils.escape_html(Mustache.Utils.to_binary(value))
  end

  def get_value(nil, _) do
    nil
  end

  def get_value(bindings, name) when is_map(bindings) and is_atom(name) do
    ret = bindings[name]
    if ret==nil do
      ret = bindings[Atom.to_string(name)]
    end
    ret || ""
  end

  def get_value(bindings, name) when is_map(bindings) and is_list(name) do
    Enum.reduce(name, bindings, fn(name, acc) ->
                  get_value(acc, name)
                end)
  end

  def build([{:text,_,val}|rest], bindings) do
    [val] ++ build(rest, bindings)
  end

  def build([{:variable,_,name}|rest], bindings) do
    [get_value(bindings, name) |> escape] ++ build(rest, bindings)
  end

  def build([{:dotted_name,_,name}|rest], bindings) do
    [get_value(bindings, name) |> escape] ++ build(rest, bindings)
  end

  def build([{:unescaped_variable,_,name}|rest], bindings) do
    [get_value(bindings, name)] ++ build(rest, bindings)
  end
  def build([{:unescaped_dotted_name,_,name}|rest], bindings) do
    [get_value(bindings, name)] ++ build(rest, bindings)
  end

  def build([{:dotted_name_section, line,name}| rest], bindings) do
    build([{:section, line, name}] ++ rest, bindings)
  end

  def build([{:section,_,name}|rest], bindings) do
    bind = get_value(bindings, name)
    idx = Enum.find_index(rest, fn(e) -> {:end_section,1,name} == e end)
    elements = Enum.take(rest, idx)
    if is_list(bind) do
      ret = Enum.map(bind, fn(b) -> 
                       build(elements, b)
                     end)
    else
      ret = build(elements, bind)
    end
    rest = Enum.drop(rest, idx+1)
    [ret] ++ build(rest, bindings)
  end

  def build([{:dotted_name_inverted_section, line,name}| rest], bindings) do
    build([{:inverted_section, line, name}] ++ rest, bindings)
  end

  def build([{:inverted_section,_, name}|rest], bindings) do
    bind = get_value(bindings, name)
    idx = Enum.find_index(rest, fn(e) -> {:end_section,1,name} == e end)
    elements = Enum.take(rest, idx)
    if bind == nil or bind == [] do
      ret = build(elements, bind)
    end
    rest = Enum.drop(rest, idx+1)
    [ret] ++ build(rest, bindings)
  end

  def build([{:partial,_,_name}|rest], bindings) do
    [""] ++ build(rest, bindings)
  end

  def build([token|rest], bindings) do
    [inspect(token)] ++ build(rest, bindings)
  end

  def build([], _bindings) do
    []
  end
end



