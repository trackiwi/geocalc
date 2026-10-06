# Run with:
#
#     MIX_ENV=bench mix run bench/geocalc_bench.exs

berlin = %{lat: 52.5075419, lon: 13.4251364}
london = %{lat: 51.5286416, lng: -0.1015987}
paris = %{lat: 48.8588589, lng: 2.3475569}
bearing = Geocalc.bearing(berlin, paris)

poly =
  Enum.map([berlin, london, paris], fn point ->
    [Geocalc.Point.latitude(point), Geocalc.Point.longitude(point)]
  end)

Benchee.run(
  %{
    "degrees to radians" => fn -> Geocalc.degrees_to_radians(555) end,
    "radians to degrees" => fn -> Geocalc.radians_to_degrees(-5.12) end,
    "distance between" => fn -> Geocalc.distance_between(berlin, london) end,
    "within?/2" => fn -> Geocalc.within?(poly, [51.89, 10.23]) end,
    "within?/3" => fn -> Geocalc.within?(100_000, berlin, london) end,
    "bearing" => fn -> Geocalc.bearing(berlin, paris) end,
    "destination point" => fn -> Geocalc.destination_point(berlin, bearing, 1_000_000) end,
    "intersection point" => fn -> Geocalc.intersection_point(berlin, bearing, london, 1.502) end,
    "bounding box" => fn -> Geocalc.bounding_box(london, 1_000_000) end,
    "bounding box for points" => fn -> Geocalc.bounding_box_for_points(poly) end,
    "geographic center" => fn -> Geocalc.geographic_center([london, berlin, paris]) end
  },
  warmup: 1,
  time: 3
)
