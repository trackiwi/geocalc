defprotocol Geocalc.Point do
  @moduledoc """
  The `Geocalc.Point` protocol is responsible for receiving latitude and
  longitude from any Elixir data structure.

  At this time it has implementations for Map, Tuple and List, and the shapes
  defined inside this project.

  Point values can be numbers in decimal degrees, `Geocalc.DMS` structs
  (degrees, minutes, seconds), or `Decimal` structs when the optional `:decimal`
  dependency is available.
  """

  @typedoc """
  A latitude or longitude value: decimal degrees as a number, a `Geocalc.DMS`
  struct, or a `Decimal` struct (only with the optional `:decimal` dependency).
  """
  @type coordinate ::
          number()
          | Geocalc.DMS.t()
          | %{required(:__struct__) => Decimal, optional(atom()) => any()}

  @doc """
  Returns point latitude.
  """
  def latitude(point)

  @doc """
  Returns point longitude.
  """
  def longitude(point)
end

defmodule Geocalc.Point.Coordinate do
  @moduledoc false

  # Decimal is an optional dependency: match its struct by name so this compiles
  # without it. Decimal is only called when a Decimal value was passed in, in
  # which case the module is necessarily loaded.
  @compile {:no_warn_undefined, Decimal}

  def to_degrees(degrees) when is_number(degrees), do: degrees
  def to_degrees(%Geocalc.DMS{} = dms), do: Geocalc.DMS.to_degrees(dms)
  def to_degrees(%{__struct__: Decimal} = decimal), do: Decimal.to_float(decimal)
end

defimpl Geocalc.Point, for: List do
  alias Geocalc.Point.Coordinate

  def latitude([lat, _lng]), do: Coordinate.to_degrees(lat)
  def longitude([_lat, lng]), do: Coordinate.to_degrees(lng)
end

defimpl Geocalc.Point, for: Map do
  alias Geocalc.Point.Coordinate

  def latitude(%{lat: lat}), do: Coordinate.to_degrees(lat)
  def latitude(%{latitude: lat}), do: Coordinate.to_degrees(lat)

  def longitude(%{lon: lng}), do: Coordinate.to_degrees(lng)
  def longitude(%{lng: lng}), do: Coordinate.to_degrees(lng)
  def longitude(%{longitude: lng}), do: Coordinate.to_degrees(lng)
end

defimpl Geocalc.Point, for: Tuple do
  alias Geocalc.Point.Coordinate

  def latitude({lat, _lng}), do: Coordinate.to_degrees(lat)
  def latitude({:ok, lat, _lng}), do: Coordinate.to_degrees(lat)

  def longitude({_lat, lng}), do: Coordinate.to_degrees(lng)
  def longitude({:ok, _lat, lng}), do: Coordinate.to_degrees(lng)
end

defimpl Geocalc.Point, for: [Geocalc.Shape.Circle, Geocalc.Shape.Rectangle, Geocalc.Shape.Ellipse] do
  alias Geocalc.Point.Coordinate

  def latitude(%{latitude: lat}), do: Coordinate.to_degrees(lat)
  def longitude(%{longitude: lng}), do: Coordinate.to_degrees(lng)
end
