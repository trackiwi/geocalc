defmodule Geocalc.Calculator do
  @moduledoc false

  alias Geocalc.Point

  @earth_radius 6_371_000
  @pi :math.pi()
  @epsilon 2.220446049250313e-16
  @intersection_not_found "No intersection point found"
  @same_great_circle_tolerance 1.0e-9 # less than 1cm

  def distance_between(point_1, point_2, radius \\ @earth_radius) do
    fo_1 = degrees_to_radians(Point.latitude(point_1))
    fo_2 = degrees_to_radians(Point.latitude(point_2))
    diff_fo = degrees_to_radians(Point.latitude(point_2) - Point.latitude(point_1))
    diff_la = degrees_to_radians(Point.longitude(point_2) - Point.longitude(point_1))

    a =
      :math.sin(diff_fo / 2) * :math.sin(diff_fo / 2) +
        :math.cos(fo_1) * :math.cos(fo_2) * :math.sin(diff_la / 2) * :math.sin(diff_la / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    radius * c
  end

  def bearing(point_1, point_2) do
    fo_1 = degrees_to_radians(Point.latitude(point_1))
    fo_2 = degrees_to_radians(Point.latitude(point_2))
    la_1 = degrees_to_radians(Point.longitude(point_1))
    la_2 = degrees_to_radians(Point.longitude(point_2))
    y = :math.sin(la_2 - la_1) * :math.cos(fo_2)

    x =
      :math.cos(fo_1) * :math.sin(fo_2) -
        :math.sin(fo_1) * :math.cos(fo_2) * :math.cos(la_2 - la_1)

    :math.atan2(y, x)
  end

  def destination_point(point_1, brng, distance) do
    destination_point(point_1, brng, distance, @earth_radius)
  end

  defp destination_point(point_1, brng, distance, radius) when is_number(brng) do
    fo_1 = degrees_to_radians(Point.latitude(point_1))
    la_1 = degrees_to_radians(Point.longitude(point_1))

    rad_lat =
      :math.asin(
        :math.sin(fo_1) * :math.cos(distance / radius) +
          :math.cos(fo_1) * :math.sin(distance / radius) * :math.cos(brng)
      )

    rad_lng =
      la_1 +
        :math.atan2(
          :math.sin(brng) * :math.sin(distance / radius) * :math.cos(fo_1),
          :math.cos(distance / radius) - :math.sin(fo_1) * :math.sin(rad_lat)
        )

    {:ok, [radians_to_degrees(rad_lat), radians_to_degrees(rad_lng)]}
  end

  defp destination_point(point_1, point_2, distance, radius) do
    brng = bearing(point_1, point_2)
    destination_point(point_1, brng, distance, radius)
  end

  def intersection_point(point_1, bearing_1, point_2, bearing_2)
      when is_number(bearing_1) and is_number(bearing_2) do
    fo_1 = degrees_to_radians(Point.latitude(point_1))
    la_1 = degrees_to_radians(Point.longitude(point_1))
    fo_2 = degrees_to_radians(Point.latitude(point_2))
    la_2 = degrees_to_radians(Point.longitude(point_2))
    path_1 = {fo_1, la_1, bearing_1}
    path_2 = {fo_2, la_2, bearing_2}

    # angular distance point_1 - point_2
    be_12 = angular_distance(fo_1, la_1, fo_2, la_2)

    case {abs(be_12) < @epsilon, same_great_circle?(path_1, path_2)} do
      # coincident start points
      {true, _} -> {:ok, [Point.latitude(point_1), Point.longitude(point_1)]}
      # both paths on the same great circle: infinite intersections
      {false, true} -> {:error, @intersection_not_found}
      {false, false} -> intersection_of_paths(path_1, path_2, be_12)
    end
  end

  def intersection_point(point_1, bearing_1, point_3, point_4) when is_number(bearing_1) do
    brng_3 = bearing(point_3, point_4)
    intersection_point(point_1, bearing_1, point_3, brng_3)
  end

  def intersection_point(point_1, point_2, point_3, bearing_2) when is_number(bearing_2) do
    brng_1 = bearing(point_1, point_2)
    intersection_point(point_1, brng_1, point_3, bearing_2)
  end

  def intersection_point(point_1, point_2, point_3, point_4) do
    brng_1 = bearing(point_1, point_2)
    brng_3 = bearing(point_3, point_4)
    intersection_point(point_1, brng_1, point_3, brng_3)
  end

  def degrees_to_radians(degrees) do
    normalize_degrees(degrees) * :math.pi() / 180
  end

  defp normalize_degrees(degrees) when degrees < -180 do
    normalize_degrees(degrees + 2 * 180)
  end

  defp normalize_degrees(degrees) when degrees > 180 do
    normalize_degrees(degrees - 2 * 180)
  end

  defp normalize_degrees(degrees) do
    degrees
  end

  def radians_to_degrees(radians) do
    normalize_radians(radians) * 180 / :math.pi()
  end

  defp normalize_radians(radians) when radians < -@pi do
    normalize_radians(radians + 2 * :math.pi())
  end

  defp normalize_radians(radians) when radians > @pi do
    normalize_radians(radians - 2 * :math.pi())
  end

  defp normalize_radians(radians) do
    radians
  end

  def bounding_box(point, radius_in_m) do
    lat = degrees_to_radians(Point.latitude(point))
    lon = degrees_to_radians(Point.longitude(point))
    # angular radius on the same spherical earth as distance_between/3
    angle = radius_in_m / @earth_radius

    lat_min = lat - angle
    lat_max = lat + angle

    case lat_min > -@pi / 2 and lat_max < @pi / 2 do
      true ->
        diff_lon = :math.asin(clamp(:math.sin(angle) / :math.cos(lat)))
        bounding_box_in_longitude(lat_min, lat_max, lon, diff_lon)

      # the circle contains a pole: cap the latitude and cover all longitudes
      false ->
        box_in_degrees(max(lat_min, -@pi / 2), min(lat_max, @pi / 2), -@pi, @pi)
    end
  end

  def bounding_box_for_points([]) do
    [[0, 0], [0, 0]]
  end

  def bounding_box_for_points(points) do
    latitudes = Enum.map(points, &Point.latitude/1)
    longitudes = Enum.map(points, &Point.longitude/1)

    [
      [Enum.min(latitudes), Enum.min(longitudes)],
      [Enum.max(latitudes), Enum.max(longitudes)]
    ]
  end

  def extend_bounding_box([sw_point_1, ne_point_1], [sw_point_2, ne_point_2]) do
    sw_lat = Kernel.min(Point.latitude(sw_point_2), Point.latitude(sw_point_1))
    sw_lon = Kernel.min(Point.longitude(sw_point_2), Point.longitude(sw_point_1))
    ne_lat = Kernel.max(Point.latitude(ne_point_2), Point.latitude(ne_point_1))
    ne_lon = Kernel.max(Point.longitude(ne_point_2), Point.longitude(ne_point_1))

    [
      [sw_lat, sw_lon],
      [ne_lat, ne_lon]
    ]
  end

  def contains_point?([sw_point, ne_point], point) do
    Point.latitude(point) >= Point.latitude(sw_point) &&
      Point.latitude(point) <= Point.latitude(ne_point) &&
      Point.longitude(point) >= Point.longitude(sw_point) &&
      Point.longitude(point) <= Point.longitude(ne_point)
  end

  def intersects_bounding_box?([sw_point_1, ne_point_1], [sw_point_2, ne_point_2]) do
    Point.latitude(ne_point_2) >= Point.latitude(sw_point_1) &&
      Point.latitude(sw_point_2) <= Point.latitude(ne_point_1) &&
      Point.longitude(ne_point_2) >= Point.longitude(sw_point_1) &&
      Point.longitude(sw_point_2) <= Point.longitude(ne_point_1)
  end

  def overlaps_bounding_box?([sw_point_1, ne_point_1], [sw_point_2, ne_point_2]) do
    Point.latitude(ne_point_2) > Point.latitude(sw_point_1) &&
      Point.latitude(sw_point_2) < Point.latitude(ne_point_1) &&
      Point.longitude(ne_point_2) > Point.longitude(sw_point_1) &&
      Point.longitude(sw_point_2) < Point.longitude(ne_point_1)
  end

  # Semi-axes of WGS-84 geoidal reference
  # Major semiaxis [m]
  @wgsa 6_378_137.0
  # Minor semiaxis [m]
  @wgsb 6_356_752.3

  def earth_radius(lat) do
    # http://en.wikipedia.org/wiki/Earth_radius
    an = @wgsa * @wgsa * :math.cos(lat)
    bn = @wgsb * @wgsb * :math.sin(lat)
    ad = @wgsa * :math.cos(lat)
    bd = @wgsb * :math.sin(lat)
    :math.sqrt((an * an + bn * bn) / (ad * ad + bd * bd))
  end

  def geographic_center(points) do
    len = length(points)

    {xa, ya, za} =
      Enum.reduce(points, {0, 0, 0}, fn point, {x, y, z} ->
        lat = point |> Point.latitude() |> degrees_to_radians()
        lon = point |> Point.longitude() |> degrees_to_radians()

        {
          x + :math.cos(lat) * :math.cos(lon),
          y + :math.cos(lat) * :math.sin(lon),
          z + :math.sin(lat)
        }
      end)

    xa = xa / len
    ya = ya / len
    za = za / len

    lon = :math.atan2(ya, xa)
    hyp = :math.sqrt(xa * xa + ya * ya)
    lat = :math.atan2(za, hyp)

    [radians_to_degrees(lat), radians_to_degrees(lon)]
  end

  def max_latitude(point, bearing) do
    lat = degrees_to_radians(Point.latitude(point))
    max_lat = :math.acos(Kernel.abs(:math.sin(bearing) * :math.cos(lat)))
    radians_to_degrees(max_lat)
  end

  def cross_track_distance_to(point, path_start_point, path_end_point, radius \\ @earth_radius) do
    dist_13 = distance_between(path_start_point, point, radius) / radius
    be_13 = bearing(path_start_point, point)
    be_12 = bearing(path_start_point, path_end_point)
    :math.asin(:math.sin(dist_13) * :math.sin(be_13 - be_12)) * radius
  end

  def along_track_distance_to(point, path_start_point, path_end_point, radius \\ @earth_radius) do
    dist_13 = distance_between(path_start_point, point, radius) / radius
    be_13 = bearing(path_start_point, point)
    be_12 = bearing(path_start_point, path_end_point)

    # Napier's rule for the right spherical triangle start/point/foot:
    # tan(δat) = tan(δ13) · cos(θ13 − θ12). Mathematically equal to movable-type's
    # acos(cos δ13 / cos δxt), but well-conditioned everywhere and signed by itself.
    :math.atan2(:math.sin(dist_13) * :math.cos(be_13 - be_12), :math.cos(dist_13)) * radius
  end

  def crossing_parallels(point_1, point_2, latitude) do
    lat = degrees_to_radians(latitude)

    lat_1 = degrees_to_radians(Point.latitude(point_1))
    lon_1 = degrees_to_radians(Point.longitude(point_1))
    lat_2 = degrees_to_radians(Point.latitude(point_2))
    lon_2 = degrees_to_radians(Point.longitude(point_2))

    diff_lon = lon_2 - lon_1

    x = :math.sin(lat_1) * :math.cos(lat_2) * :math.cos(lat) * :math.sin(diff_lon)

    y =
      :math.sin(lat_1) * :math.cos(lat_2) * :math.cos(lat) * :math.cos(diff_lon) -
        :math.cos(lat_1) * :math.sin(lat_2) * :math.cos(lat)

    z = :math.cos(lat_1) * :math.cos(lat_2) * :math.sin(lat) * :math.sin(diff_lon)

    xy_squared = x * x + y * y

    case xy_squared == 0 or z * z > xy_squared do
      # coincident points, the equator itself at latitude 0,
      # or a great circle that doesn't reach the latitude
      true -> {:error, "Not found"}
      false -> crossing_longitudes(lon_1, x, y, z)
    end
  end

  defp intersection_from_angles(fo_1, la_1, bo_13, be_12, a_1, a_2) do
    cos_a_3 =
      -:math.cos(a_1) * :math.cos(a_2) + :math.sin(a_1) * :math.sin(a_2) * :math.cos(be_12)

    be_13 =
      :math.atan2(
        :math.sin(be_12) * :math.sin(a_1) * :math.sin(a_2),
        :math.cos(a_2) + :math.cos(a_1) * cos_a_3
      )

    fo_3 =
      :math.asin(
        clamp(
          :math.sin(fo_1) * :math.cos(be_13) +
            :math.cos(fo_1) * :math.sin(be_13) * :math.cos(bo_13)
        )
      )

    diff_la_13 =
      :math.atan2(
        :math.sin(bo_13) * :math.sin(be_13) * :math.cos(fo_1),
        :math.cos(be_13) - :math.sin(fo_1) * :math.sin(fo_3)
      )

    [radians_to_degrees(fo_3), radians_to_degrees(la_1 + diff_la_13)]
  end

  defp angular_distance(fo_1, la_1, fo_2, la_2) do
    diff_fo = fo_2 - fo_1
    diff_la = la_2 - la_1

    a =
      :math.sin(diff_fo / 2) * :math.sin(diff_fo / 2) +
        :math.cos(fo_1) * :math.cos(fo_2) * :math.sin(diff_la / 2) * :math.sin(diff_la / 2)

    2 * :math.asin(min(1.0, :math.sqrt(a)))
  end

  defp intersection_of_paths({fo_1, la_1, bo_13}, {fo_2, la_2, bo_23}, be_12) do
    # initial / final bearings between the start points
    cos_bo_a =
      (:math.sin(fo_2) - :math.sin(fo_1) * :math.cos(be_12)) /
        (:math.sin(be_12) * :math.cos(fo_1))

    cos_bo_b =
      (:math.sin(fo_1) - :math.sin(fo_2) * :math.cos(be_12)) /
        (:math.sin(be_12) * :math.cos(fo_2))

    bo_a = :math.acos(clamp(cos_bo_a))
    bo_b = :math.acos(clamp(cos_bo_b))

    {bo_12, bo_21} =
      case :math.sin(la_2 - la_1) > 0 do
        true -> {bo_a, 2 * @pi - bo_b}
        false -> {2 * @pi - bo_a, bo_b}
      end

    # angle 2-1-3 and angle 1-2-3
    a_1 = bo_13 - bo_12
    a_2 = bo_21 - bo_23

    case :math.sin(a_1) * :math.sin(a_2) < 0 do
      # ambiguous intersection (antipodal / 360°)
      true -> {:error, @intersection_not_found}
      false -> {:ok, intersection_from_angles(fo_1, la_1, bo_13, be_12, a_1, a_2)}
    end
  end

  defp crossing_longitudes(lon_1, x, y, z) do
    # longitude at max latitude, and from there to the two crossing points
    lon_max = :math.atan2(-y, x)
    diff_lon_i = :math.acos(clamp(z / :math.sqrt(x * x + y * y)))

    # radians_to_degrees/1 already wraps into -180..180, like Dms.wrap180 in the reference
    {:ok, radians_to_degrees(lon_1 + lon_max - diff_lon_i),
     radians_to_degrees(lon_1 + lon_max + diff_lon_i)}
  end

  # protect acos/asin against rounding errors pushing arguments past ±1
  defp clamp(value), do: value |> max(-1.0) |> min(1.0)

    # The paths lie on the same great circle when the normals of their great circles
  # are parallel. |c1 × c2| is the sine of the angle between the circles; below the
  # tolerance they never separate by more than 1.0e-9 × 6371 km ≈ 6 mm.
  defp same_great_circle?(path_1, path_2) do
    {x_1, y_1, z_1} = great_circle(path_1)
    {x_2, y_2, z_2} = great_circle(path_2)

    cx = y_1 * z_2 - z_1 * y_2
    cy = z_1 * x_2 - x_1 * z_2
    cz = x_1 * y_2 - y_1 * x_2

    :math.sqrt(cx * cx + cy * cy + cz * cz) < @same_great_circle_tolerance
  end

  # normal vector of the great circle through a point on a given bearing,
  # see greatCircle() in movable-type's latlon-nvector-spherical.js
  defp great_circle({fo, la, bo}) do
    {
      :math.sin(la) * :math.cos(bo) - :math.sin(fo) * :math.cos(la) * :math.sin(bo),
      -:math.cos(la) * :math.cos(bo) - :math.sin(fo) * :math.sin(la) * :math.sin(bo),
      :math.cos(fo) * :math.sin(bo)
    }
  end

  defp bounding_box_in_longitude(lat_min, lat_max, lon, diff_lon) do
    case lon - diff_lon < -@pi or lon + diff_lon > @pi do
      # the box would cross the antimeridian: cover all longitudes
      true -> box_in_degrees(lat_min, lat_max, -@pi, @pi)
      false -> box_in_degrees(lat_min, lat_max, lon - diff_lon, lon + diff_lon)
    end
  end

  defp box_in_degrees(lat_min, lat_max, lon_min, lon_max) do
    [
      [radians_to_degrees(lat_min), radians_to_degrees(lon_min)],
      [radians_to_degrees(lat_max), radians_to_degrees(lon_max)]
    ]
  end
end
