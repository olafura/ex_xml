defmodule ExXml.Element do
  @moduledoc false
  defstruct name: "", type: nil, attributes: %{}, children: []

  @type t :: %__MODULE__{
          name: String.t(),
          type: atom,
          attributes: map,
          children: list
        }
end
