defmodule GeocalcTest do
  use ExUnit.Case
  doctest Geocalc, except: [
    bearing: 2,
    destination_point: 3,
    intersection_point: 4,
    max_latitude: 2,
    cross_track_distance_to: 3,
    along_track_distance_to: 3,
    crossing_parallels: 3,
    distance_between: 2,
    bounding_box: 2,
    geographic_center: 1
  ]

  alias Geocalc.{Point, Shape}

  # :math calls the platform's C libm, which isn't required to be correctly
  # rounded, so computed floats can differ by a few ulps between machines.
  @tolerance 1.0e-12
  @distance_tolerance 1.0e-6

  test "bearing matches the documented Berlin/Paris values" do
    berlin = {52.5075419, 13.4251364}
    paris = {48.8588589, 2.3475569}

    assert_in_delta Geocalc.bearing(berlin, paris), -1.9739245359361473, @tolerance
    assert_in_delta Geocalc.bearing(paris, berlin), 1.0178267866082626, @tolerance
  end

  test "bearing is identical for every supported point format" do
    expected = Geocalc.bearing({52.5075419, 13.4251364}, {48.8588589, 2.3475569})

    assert Geocalc.bearing([52.5075419, 13.4251364], [48.8588589, 2.3475569]) == expected

    assert Geocalc.bearing(
             %{lat: 52.5075419, lon: 13.4251364},
             %{latitude: 48.8588589, longitude: 2.3475569}
           ) == expected

    assert Geocalc.bearing(
             {Decimal.new("52.5075419"), Decimal.new("13.4251364")},
             {48.8588589, 2.3475569}
           ) == expected
  end

  test "bearing returns cardinal directions from the origin" do
    origin = {0.0, 0.0}

    assert_in_delta Geocalc.bearing(origin, {1.0, 0.0}), 0.0, @tolerance
    assert_in_delta Geocalc.bearing(origin, {0.0, 1.0}), :math.pi() / 2, @tolerance
    assert_in_delta Geocalc.bearing(origin, {-1.0, 0.0}), :math.pi(), @tolerance
    assert_in_delta Geocalc.bearing(origin, {0.0, -1.0}), -:math.pi() / 2, @tolerance
  end

  test "calculates distance between two points" do
    point_1 = [50.0663889, -5.7147222]
    point_2 = [58.6438889, -3.07]
    assert_in_delta Geocalc.distance_between(point_1, point_2), 968_853.5, 0.05
  end

  test "calculates distance between two decimal points" do
    point_1 = [Decimal.new("50.0663889"), Decimal.new("-5.7147222")]
    point_2 = [Decimal.new("58.6438889"), Decimal.new("-3.07")]
    assert_in_delta Geocalc.distance_between(point_1, point_2), 968_853.5, 0.05
  end

  test "returns true when point is within a given radius from the circle center" do
    center = [18.2208, 66.5901]
    point = [18.4655, 66.1057]
    assert Geocalc.within?(170_000, center, point)
  end

  test "returns true when radius is 0 and the point equals the center point" do
    center = [18.2208, 66.5901]
    assert Geocalc.within?(0, center, center)
  end

  test "returns false when radius is 0 and point does not equal center point" do
    center = [18.2208, 66.5901]
    point = [18.4655, 66.1057]
    refute Geocalc.within?(0, center, point)
  end

  test "returns false when point is not wihtin a given radius from the circle center" do
    center = [18.2208, 66.5901]
    point = [52.5075419, 13.4251364]
    refute Geocalc.within?(170_000, center, point)
  end

  test "returns false when radius is negative" do
    center = [18.2208, 66.5901]
    point = [52.5075419, 13.4251364]
    refute Geocalc.within?(-170_000, center, point)
  end

  test "calculates distance between Minsk and London" do
    minsk = %{lat: 53.8838884, lon: 27.5949741}
    london = %{lat: Decimal.new("51.5286416"), lon: Decimal.new("-0.1015987")}
    assert_in_delta Geocalc.distance_between(minsk, london), 1_872_028.5, 0.05
  end

  test "distance_between matches the documented values" do
    berlin = [52.5075419, 13.4251364]
    paris = [48.8588589, 2.3475569]
    london = [51.5286416, -0.1015987]

    assert_in_delta Geocalc.distance_between(berlin, paris), 878_327.4291149472, @distance_tolerance
    assert_in_delta Geocalc.distance_between(paris, berlin), 878_327.4291149472, @distance_tolerance
    assert_in_delta Geocalc.distance_between(paris, london), 344_229.88946533133, @distance_tolerance
  end

  test "distance_between is identical for every supported point format" do
    expected = Geocalc.distance_between([52.5075419, 13.4251364], [48.8588589, 2.3475569])

    assert Geocalc.distance_between({52.5075419, 13.4251364}, {48.8588589, 2.3475569}) == expected

    assert Geocalc.distance_between(
             %{lat: 52.5075419, lon: 13.4251364},
             %{latitude: 48.8588589, longitude: 2.3475569}
           ) == expected

    assert Geocalc.distance_between(
             [Decimal.new("52.5075419"), Decimal.new("13.4251364")],
             %{lat: 48.8588589, lng: Decimal.new("2.3475569")}
           ) == expected
  end

  test "distance_between follows the spherical earth model" do
    radius = 6_371_000

    assert_in_delta Geocalc.distance_between([0, 0], [1, 0]), radius * :math.pi() / 180, @distance_tolerance
    assert_in_delta Geocalc.distance_between([0, 0], [0, 90]), radius * :math.pi() / 2, @distance_tolerance
    assert_in_delta Geocalc.distance_between([0, 0], [0, 180]), radius * :math.pi(), @distance_tolerance
  end

  test "calculates bearing between two points" do
    point_1 = [50.0663889, -5.7147222]
    point_2 = [58.6438889, -3.07]
    assert_in_delta Geocalc.bearing(point_1, point_2), 0.159170, 0.000001
  end

  test "calculates bearing between Minsk and London" do
    minsk = %{latitude: 53.8838884, longitude: 27.5949741}
    london = %{latitude: Decimal.new("51.5286416"), longitude: Decimal.new("-0.1015987")}
    assert_in_delta Geocalc.bearing(minsk, london), -1.513836, 0.000001
  end

  test "returns destination point between two points in direction to second point" do
    point_1 = [1.234, 2.345]
    point_2 = [3.654, 4.765]
    distance = 1_000
    brng = Geocalc.bearing(point_1, point_2)
    {:ok, point_3} = Geocalc.destination_point(point_1, brng, distance)

    assert_in_delta Geocalc.distance_between(point_3, [1.2403670648864074, 2.3513527343464733]),
                    0,
                    0.0005

    actual_distance = Geocalc.distance_between(point_3, point_1)
    assert_in_delta actual_distance, distance, 0.0005
  end

  test "returns destination point in pacific ocean near Japan" do
    point_1 = %{lat: 46.118942, lng: 150.402832}
    point_2 = %{lat: 21.913108, lng: -160.193712}
    distance = 1_178_348
    {:ok, point_3} = Geocalc.destination_point(point_1, point_2, distance)

    assert_in_delta Geocalc.distance_between(point_3, [42.64962243973242, 164.43934677825277]),
                    0,
                    0.0005

    actual_distance = Geocalc.distance_between(point_3, point_1)
    assert_in_delta actual_distance, distance, 0.0005
  end

  test "returns destination point in pacific ocean near Hawaii" do
    point_1 = {46.118942, 150.402832}
    point_2 = {Decimal.new("21.913108"), Decimal.new("-160.193712")}
    distance = 4_178_348
    {:ok, point_3} = Geocalc.destination_point(point_1, point_2, distance)

    assert_in_delta Geocalc.distance_between(point_3, [27.939238854720823, -167.5615280845497]),
                    0,
                    0.0005

    actual_distance = Geocalc.distance_between(point_3, point_1)
    assert_in_delta actual_distance, distance, 0.0005
  end

  test "destination_point matches the documented Berlin values" do
    berlin = [52.5075419, 13.4251364]
    paris = [48.8588589, 2.3475569]

    {:ok, [lat, lng]} = Geocalc.destination_point(berlin, Geocalc.bearing(berlin, paris), 400_000)
    assert_in_delta lat, 50.97658022467569, @tolerance
    assert_in_delta lng, 8.165929595956978, @tolerance

    {:ok, [lat, lng]} =
      Geocalc.destination_point(%{lat: 52.5075419, lon: 13.4251364}, -1.9739245359361486, 100_000)

    assert_in_delta lat, 52.147030316318904, @tolerance
    assert_in_delta lng, 12.076990111001148, @tolerance

    {:ok, [lat, lng]} = Geocalc.destination_point(berlin, paris, 250_000)
    assert_in_delta lat, 51.578054644172525, @tolerance
    assert_in_delta lng, 10.096282782248409, @tolerance
  end

  test "destination_point towards a point equals destination_point along its bearing" do
    berlin = [52.5075419, 13.4251364]
    paris = [48.8588589, 2.3475569]

    assert Geocalc.destination_point(berlin, paris, 250_000) ==
             Geocalc.destination_point(berlin, Geocalc.bearing(berlin, paris), 250_000)
  end

  test "destination_point follows the equator and the prime meridian" do
    origin = {0.0, 0.0}
    distance = 1_000_000
    # angular distance on a sphere with the library's 6_371 km earth radius, in degrees
    arc = distance / 6_371_000 * 180 / :math.pi()

    {:ok, [lat, lng]} = Geocalc.destination_point(origin, :math.pi() / 2, distance)
    assert_in_delta lat, 0.0, @tolerance
    assert_in_delta lng, arc, @tolerance

    {:ok, [lat, lng]} = Geocalc.destination_point(origin, 0.0, distance)
    assert_in_delta lat, arc, @tolerance
    assert_in_delta lng, 0.0, @tolerance
  end

  test "returns intersection point" do
    point_1 = [51.8853, 0.2545]
    bearing_1 = Geocalc.degrees_to_radians(108.547)
    point_2 = [49.0034, 2.5735]
    bearing_2 = Geocalc.degrees_to_radians(32.435)
    {:ok, point_3} = Geocalc.intersection_point(point_1, bearing_1, point_2, bearing_2)
    assert_in_delta Point.latitude(point_3), 50.9078, 0.00001
    assert_in_delta Point.longitude(point_3), 4.5084, 0.00001
  end

  test "all roads lead to Rome" do
    milan = {45.4628328, 9.1076929}
    naples = {40.8536668, 14.2079876}
    rome = {41.9102415, 12.3959161}
    {:ok, point_3} = Geocalc.intersection_point(milan, rome, naples, rome)
    assert_in_delta Geocalc.distance_between(point_3, rome), 0, 0.0005
  end

    test "intersection_point matches the documented Berlin/London values" do
    berlin = [52.5075419, 13.4251364]
    london = [51.5286416, -0.1015987]

    {:ok, [lat, lng]} = Geocalc.intersection_point(berlin, -2.102, london, 1.502)
    assert_in_delta lat, 51.49271112601574, @tolerance
    assert_in_delta lng, 10.735322818996854, @tolerance
  end

  test "intersection_point of two paths towards the same point is that point" do
    berlin = {52.5075419, 13.4251364}
    london = {51.5286416, -0.1015987}
    paris = {48.8588589, 2.3475569}

    {:ok, [lat, lng]} = Geocalc.intersection_point(berlin, london, paris, london)
    assert_in_delta lat, 51.5286416, @tolerance
    assert_in_delta lng, -0.1015987, @tolerance
  end

  test "intersection_point returns an error when the paths only meet behind a start point" do
    berlin_1 = %{lat: 52.5075419, lng: 13.4251364}
    berlin_2 = %{lat: 52.5075419, lng: 13.57}
    bearing = Geocalc.degrees_to_radians(90.0)

    assert Geocalc.intersection_point(berlin_1, bearing, berlin_2, bearing) ==
             {:error, "No intersection point found"}
  end

  test "returns point if point 1 and point 2 are the same" do
    minsk = %{lat: 53.8838884, lon: 27.5949741}
    bearing = Geocalc.degrees_to_radians(0)
    {:ok, point} = Geocalc.intersection_point(minsk, bearing, minsk, bearing)
    assert Point.latitude(point) == Point.latitude(minsk)
    assert Point.longitude(point) == Point.longitude(minsk)
  end

  # Point 1 lies exactly on point 2's path, so the result hinges on
  # sin(π) ≈ 1.2e-16 rather than a real margin.
  test "returns error message if intersection point not found" do
    point_1 = %{lat: 0, lon: 30}
    point_2 = %{lat: 0, lon: 60}
    bearing_1 = Geocalc.degrees_to_radians(0)
    bearing_2 = Geocalc.degrees_to_radians(90)
    {:error, msg} = Geocalc.intersection_point(point_1, bearing_1, point_2, bearing_2)
    assert msg == "No intersection point found"
  end

  test "returns equator intersection for two eastbound paths from one meridian" do
    point_1 = %{lat: 30, lon: 0}
    point_2 = %{lat: 60, lon: 0}
    bearing = Geocalc.degrees_to_radians(90)
    {:ok, point} = Geocalc.intersection_point(point_1, bearing, point_2, bearing)
    assert_in_delta Geocalc.distance_between(point, [0, 90]), 0, 0.0005
  end

  test "returns the start point when both paths start at the same point" do
    point = %{lat: 0, lon: 0}
    bearing_1 = Geocalc.degrees_to_radians(0)
    bearing_2 = Geocalc.degrees_to_radians(90)
    {:ok, point} = Geocalc.intersection_point(point, bearing_1, point, bearing_2)
    assert_in_delta Geocalc.distance_between(point, [0, 0]), 0, 0.0005
  end

  test "returns error for two paths along the same meridian" do
    assert Geocalc.intersection_point(%{lat: 10, lng: 0}, 0.0, %{lat: 20, lng: 0}, 0.0) ==
             {:error, "No intersection point found"}
  end

  test "returns error for two paths along the same great circle" do
    berlin = [52.5075419, 13.4251364]
    paris = [48.8588589, 2.3475569]
    {:ok, waypoint} = Geocalc.destination_point(berlin, paris, 100_000)

    # same direction of travel
    assert Geocalc.intersection_point(berlin, paris, waypoint, paris) ==
             {:error, "No intersection point found"}

    # towards each other
    assert Geocalc.intersection_point(berlin, paris, waypoint, berlin) ==
             {:error, "No intersection point found"}
  end

  test "returns a bounding box given a point and a radius in meters" do
    [[sw_lat, sw_lon], [ne_lat, ne_lon]] = Geocalc.bounding_box([52.5075419, 13.4251364], 10_000)

    assert_in_delta sw_lat, 52.41760973940812, @tolerance
    assert_in_delta sw_lon, 13.277381220560693, @tolerance
    assert_in_delta ne_lat, 52.59747406059187, @tolerance
    assert_in_delta ne_lon, 13.572891579439304, @tolerance
  end

  test "bounding box contains every point within the radius" do
    for center <- [[0.0, 20.0], [52.5075419, 13.4251364], [70.0, 0.0], [-45.0, 100.0]],
        radius <- [10_000, 1_000_000] do
      box = Geocalc.bounding_box(center, radius)

      for degrees <- 0..359 do
        bearing = Geocalc.degrees_to_radians(degrees * 1.0)
        # just inside the circle, so rounding on the box edge can't decide the result
        {:ok, point} = Geocalc.destination_point(center, bearing, radius * (1 - 1.0e-9))
        assert Geocalc.contains_point?(box, point), "#{inspect(point)} outside #{inspect(box)}"
      end
    end
  end

  test "bounding box touches the circle due north and due south" do
    center = [52.5075419, 13.4251364]
    [[sw_lat, _], [ne_lat, _]] = Geocalc.bounding_box(center, 10_000)
    {:ok, [north_lat, _]} = Geocalc.destination_point(center, 0.0, 10_000)
    {:ok, [south_lat, _]} = Geocalc.destination_point(center, :math.pi(), 10_000)

    assert_in_delta ne_lat, north_lat, @tolerance
    assert_in_delta sw_lat, south_lat, @tolerance
  end

  test "bounding box spans all longitudes around a pole" do
    assert [[sw_lat, -180.0], [90.0, 180.0]] = Geocalc.bounding_box([90.0, 0.0], 10_000)
    assert_in_delta sw_lat, 89.91006783940813, @tolerance

    assert [[_, -180.0], [90.0, 180.0]] = Geocalc.bounding_box([89.95, 0.0], 10_000)
  end

  test "bounding box spans all longitudes when crossing the antimeridian" do
    box = Geocalc.bounding_box([0.0, 179.99], 10_000)

    assert [[_, -180.0], [_, 180.0]] = box
    assert Geocalc.contains_point?(box, [0.0, -179.995])
  end

  test "returns a bounding box given a list of points" do
    point_1 = %{lat: 46.118942, lng: 150.402832}
    point_2 = %{lat: 21.913108, lng: -160.193712}

    assert Geocalc.bounding_box_for_points([point_1, point_2]) == [
             [21.913108, -160.193712],
             [46.118942, 150.402832]
           ]
  end

  test "returns an extended bounding box" do
    london = [51.5286416, -0.1015987]
    paris = [48.8588589, 2.3475569]

    assert Geocalc.extend_bounding_box([london, london], [paris, paris]) == [
             [48.8588589, -0.1015987],
             [51.5286416, 2.3475569]
           ]
  end

  test "returns true if bounding box contains point" do
    france = [[41.33, -5.22], [51.2, 9.55]]
    paris = [48.8588589, 2.3475569]

    assert Geocalc.contains_point?(france, paris)
  end

  test "returns false if bounding box does not contains point" do
    france = [[41.33, -5.22], [51.2, 9.55]]
    london = [51.5286416, -0.1015987]

    refute Geocalc.contains_point?(france, london)
  end

  test "returns true if bounding box intersects bounding box" do
    france = [[41.33, -5.22], [51.2, 9.55]]
    spain = [[27.43, -18.39], [43.99, 4.59]]

    assert Geocalc.intersects_bounding_box?(france, spain)
  end

  test "returns true if bounding box intersects bounding box with one point in common" do
    france = [[41.33, -5.22], [51.2, 9.55]]
    border = [[51.2, -5.22], [52, -5]]

    assert Geocalc.intersects_bounding_box?(france, border)
  end

  test "returns false if bounding box does not intersects bounding box" do
    france = [[41.33, -5.22], [51.2, 9.55]]
    portugal = [[29.83, -31.56], [42.15, -6.19]]

    refute Geocalc.intersects_bounding_box?(france, portugal)
  end

  test "returns true if bounding box overlaps bounding box" do
    france = [[41.33, -5.22], [51.2, 9.55]]
    spain = [[27.43, -18.39], [43.99, 4.59]]

    assert Geocalc.overlaps_bounding_box?(france, spain)
  end

  test "returns false if bounding box overlaps bounding box with one point in common" do
    france = [[41.33, -5.22], [51.2, 9.55]]
    border = [[51.2, -5.22], [52, -5]]

    refute Geocalc.overlaps_bounding_box?(france, border)
  end

  test "returns false if bounding box does not overlaps bounding box" do
    france = [[41.33, -5.22], [51.2, 9.55]]
    portugal = [[29.83, -31.56], [42.15, -6.19]]

    refute Geocalc.overlaps_bounding_box?(france, portugal)
  end

  test "returns a bounding box given a list with one point" do
    point = [52.5075419, 13.4251364]

    assert Geocalc.bounding_box_for_points([point]) == [
             point,
             point
           ]
  end

  test "returns a bounding box given a list with no points" do
    assert Geocalc.bounding_box_for_points([]) == [[0, 0], [0, 0]]
  end

  test "returns geographic center point" do
    for {points, [lat, lon]} <- [
          {[[0, 0], [0, 1]], [0.0, 0.5]},
          {[[0, 0], [0, 1], [0, 2]], [0.0, 1.0]},
          {[[0, 0], [0, 3]], [0.0, 1.5]},
          {[[10, 20], [-10, 20]], [0.0, 20.0]}
        ] do
      [center_lat, center_lon] = Geocalc.geographic_center(points)
      assert_in_delta center_lat, lat, @tolerance
      assert_in_delta center_lon, lon, @tolerance
    end
  end

  test "returns max latitude" do
    bearing_1 = Geocalc.degrees_to_radians(0)
    bearing_2 = Geocalc.degrees_to_radians(90)
    assert Geocalc.max_latitude([0, 0], bearing_1) == 90.0
    assert Geocalc.max_latitude([0, 0], bearing_2) == 0.0
  end

  test "returns cross track distance to point" do
    point_1 = %{lat: 53.2611, lng: -0.7972}
    point_2 = %{lat: 53.3206, lng: -1.7297}
    point_3 = %{lat: 53.1887, lng: 0.1334}
    assert_in_delta Geocalc.cross_track_distance_to(point_1, point_2, point_3), -307.5, 0.05
  end

  test "returns along track distance to point" do
    point_1 = %{lat: 53.2611, lng: -0.7972}
    point_2 = %{lat: 53.3206, lng: -1.7297}
    point_3 = %{lat: 53.1887, lng: 0.1334}
    assert_in_delta Geocalc.along_track_distance_to(point_1, point_2, point_3), 62_331.49, 0.5
  end

  test "max_latitude matches the documented Berlin/Paris value" do
    berlin = [52.5075419, 13.4251364]
    paris = [48.8588589, 2.3475569]

    assert_in_delta Geocalc.max_latitude(berlin, Geocalc.bearing(berlin, paris)),
                    55.95346742988281,
                    @tolerance
  end

  test "max_latitude of a path heading due east or west is the start latitude" do
    east = Geocalc.degrees_to_radians(90.0)
    west = Geocalc.degrees_to_radians(-90.0)

    assert_in_delta Geocalc.max_latitude([52.5075419, 13.4251364], east), 52.5075419, @tolerance
    assert_in_delta Geocalc.max_latitude([-30.0, 0.0], west), 30.0, @tolerance
  end

  test "track distances match the documented Berlin/London/Paris values" do
    berlin = [52.5075419, 13.4251364]
    london = [51.5286416, -0.1015987]
    paris = [48.8588589, 2.3475569]

    assert_in_delta Geocalc.cross_track_distance_to(berlin, london, paris),
                    -877_680.2992295168,
                    @distance_tolerance

    assert_in_delta Geocalc.along_track_distance_to(berlin, london, paris),
                    310_412.6031976226,
                    @distance_tolerance
  end

  test "track distances to a path along the equator" do
    start = [0.0, 0.0]
    finish = [0.0, 10.0]
    one_degree = 6_371_000 * :math.pi() / 180

    # cross-track: negative left (north) of an eastbound path, positive right of it
    assert_in_delta Geocalc.cross_track_distance_to([1.0, 5.0], start, finish),
                    -one_degree,
                    @distance_tolerance

    assert_in_delta Geocalc.cross_track_distance_to([-1.0, 5.0], start, finish),
                    one_degree,
                    @distance_tolerance

    # along-track: distance to the foot of the perpendicular, negative behind the start
    assert_in_delta Geocalc.along_track_distance_to([1.0, 5.0], start, finish),
                    5 * one_degree,
                    @distance_tolerance

    assert_in_delta Geocalc.along_track_distance_to([1.0, -5.0], start, finish),
                    -5 * one_degree,
                    @distance_tolerance
  end

  test "along_track_distance_to is zero for points perpendicular to the path start" do
    # some of these used to raise ArithmeticError; acos near 1.0 also limits
    # the precision right here to roughly 0.1 m, hence the wider tolerance
    for lat <- [39.3, 50.5, 52.6, 56.8, 62.4] do
      assert_in_delta Geocalc.along_track_distance_to([lat, 0.0], [0.0, 0.0], [0.0, 10.0]),
                      0.0,
                      0.5
    end
  end

  test "returns crossing parallels" do
    point_1 = %{lat: 46.1189424, lng: 150.402832}
    point_2 = %{lat: 21.9131082, lng: -160.1937128}

    {:ok, lon_1, lon_2} = Geocalc.crossing_parallels(point_1, point_2, 45.0)
    assert_in_delta lon_1, 106.52361930066911, @tolerance
    assert_in_delta lon_2, 155.95500236778838, @tolerance
  end

  test "crossing_parallels matches the documented Berlin/Paris values" do
    berlin = [52.5075419, 13.4251364]
    paris = [48.8588589, 2.3475569]

    {:ok, lon_1, lon_2} = Geocalc.crossing_parallels(berlin, paris, 12.3456)
    assert_in_delta lon_1, 123.179463369946, @tolerance
    assert_in_delta lon_2, -39.8114487850859, @tolerance

    # both crossing points lie on the Berlin/Paris great circle
    assert_in_delta Geocalc.cross_track_distance_to([12.3456, lon_1], berlin, paris),
                    0.0,
                    @distance_tolerance

    assert_in_delta Geocalc.cross_track_distance_to([12.3456, lon_2], berlin, paris),
                    0.0,
                    @distance_tolerance
  end

  test "crossing_parallels returns an error instead of crashing for degenerate paths" do
    # identical points and the equator itself used to divide 0.0 by 0.0
    berlin = [52.5075419, 13.4251364]

    assert Geocalc.crossing_parallels(berlin, berlin, 45.0) == {:error, "Not found"}
    assert Geocalc.crossing_parallels([0.0, 10.0], [0.0, 20.0], 0.0) == {:error, "Not found"}
  end

  test "returns error message if no crossing parallels found" do
    point_1 = %{lat: 0, lng: 0}
    point_2 = %{lat: 180, lng: 90}
    latitude = 45.0
    assert Geocalc.crossing_parallels(point_1, point_2, latitude) == {:error, "Not found"}
  end

  test "returns if point is inside circle area" do
    area = %Shape.Circle{latitude: 48.856614, longitude: 2.3522219, radius: 1000}
    point = %{lat: 48.856612, lng: 2.3522217}

    assert Geocalc.in_area?(area, point)
    assert not Geocalc.outside_area?(area, point)
    assert not Geocalc.at_area_border?(area, point)
    assert not Geocalc.at_center_point?(area, point)
  end

  test "returns if point is at center of a circle area" do
    area = %Shape.Circle{latitude: 48.856614, longitude: 2.3522219, radius: 10}
    point = %{lat: 48.856614, lng: 2.3522219}

    assert Geocalc.in_area?(area, point)
    assert Geocalc.at_center_point?(area, point)
  end

  test "returns if point is at border of circle area" do
    area = %Shape.Circle{latitude: 48.856614, longitude: 2.3522219, radius: 1000}
    point = %{lat: 48.856418, lng: 2.365871}

    assert Geocalc.at_area_border?(area, point)
  end

  test "returns if point is inside rectangle area" do
    area = %Shape.Rectangle{
      latitude: 48.856614,
      longitude: 2.3522219,
      long_semi_axis: 500,
      short_semi_axis: 250,
      angle: 0
    }

    point = %{lat: 48.856612, lng: 2.3522217}

    assert Geocalc.in_area?(area, point)
    assert not Geocalc.outside_area?(area, point)
    assert not Geocalc.at_area_border?(area, point)
    assert not Geocalc.at_center_point?(area, point)
  end

  test "returns if point is inside ellipse area" do
    area = %Shape.Ellipse{
      latitude: 48.856614,
      longitude: 2.3522219,
      long_semi_axis: 500,
      short_semi_axis: 250,
      angle: 0
    }

    point = %{lat: 48.856612, lng: 2.3522217}

    assert Geocalc.in_area?(area, point)
    assert not Geocalc.outside_area?(area, point)
    assert not Geocalc.at_area_border?(area, point)
    assert not Geocalc.at_center_point?(area, point)
  end

  test "point in polygon works for polygons given as [lon, lat] beyond 90° longitude" do
    tokyo = [[139.6, 35.6], [139.8, 35.6], [139.8, 35.8], [139.6, 35.8]]

    assert Geocalc.within?(tokyo, [139.7, 35.7])
    refute Geocalc.within?(tokyo, [139.9, 35.7])
  end

  test "circle area uses the local earth radius at the area's latitude" do
    # Area projects with the WGS-84 radius at its center (≈ 6366 km at Paris) while
    # destination_point uses the 6371 km sphere, so 1001 m on the sphere is ≈ 1000.2 m
    # in the area's plane. Passing degrees to earth_radius/1 shrank it to ≈ 998.9 m.
    area = %Shape.Circle{latitude: 48.856614, longitude: 2.3522219, radius: 1000}

    for degrees <- 0..345//15 do
      bearing = Geocalc.degrees_to_radians(degrees * 1.0)
      {:ok, point} = Geocalc.destination_point(area, bearing, 1001)
      assert Geocalc.outside_area?(area, point)
    end
  end
end
