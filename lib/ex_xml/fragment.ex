defmodule ExXml.Fragment do
  @moduledoc false
  defstruct attributes: %{}, children: []

  @type t :: %__MODULE__{
          attributes: map,
          children: list
        }
end
