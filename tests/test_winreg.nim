import
  std/[options, os],
  unittest2,
  ../confutils/winreg/winreg_serialization,
  ../confutils/winreg/utils

type
  Fruit = enum
    Apple

const
  commonPath = "SOFTWARE\\nimbus"

template readWrite(key: string, val: typed) =
  test key:
    var ok = setValue(HKCU, commonPath, key, val)
    check ok == true
    var outVal: type val
    ok = getValue(HKCU, commonPath, key, outVal)
    check ok == true
    check outVal == val

suite "winreg utils test suite":
  readWrite("some number", 123'u32)
  readWrite("some number 64", 123'u64)
  readWrite("some bytes", @[1.byte, 2.byte])
  readWrite("some int list", @[4,5,6])
  readWrite("some array", [1.byte, 2.byte, 4.byte])
  readWrite("some string", "hello world")
  readWrite("some enum", Apple)
  readWrite("some boolean", true)
  readWrite("some float32", 1.234'f32)
  readWrite("some float64", 1.234'f64)

  test "parse winregpath":
    let (hKey, path) = parseWinregPath("HKEY_CLASSES_ROOT\\" & commonPath)
    check hKey == HKCR
    check path == commonPath

type
  ValidIpAddress {.requiresInit.} = object
    value: string

  TestObject = object
    address: Option[ValidIpAddress]

proc readValue(r: var WinregReader, value: var ValidIpAddress) =
  r.readValue(value.value)

proc writeValue(w: var WinregWriter, value: ValidIpAddress) =
  w.writeValue(value.value)

suite "optional fields test suite":
  test "optional field with requiresInit pragma":

    var z = TestObject(address: some(ValidIpAddress(value: "1.2.3.4")))
    Winreg.saveFile("HKCU" / commonPath, z)
    var x = Winreg.loadFile("HKCU" / commonPath, TestObject)
    check x.address.isSome
    check x.address.get().value == "1.2.3.4"

type
  Class = enum
    Truck
    MPV
    SUV

  Fuel = enum
    Gasoline
    Diesel

  Engine = object
    cylinder: int
    valve: int16
    fuel: Fuel

  Suspension = object
    dist: int
    length: int

  Vehicle = object
    name: string
    color: int
    class: Class
    engine: Engine
    wheel: int
    suspension: array[3, Suspension]
    door: array[4, int]
    antennae: Option[int]
    bumper: Option[string]

suite "winreg encoder test suite":
  test "basic encoder and decoder":
    let v = Vehicle(
      name: "buggy",
      color: 213,
      class: MPV,
      engine: Engine(
        cylinder: 3,
        valve: 2,
        fuel: Diesel
      ),
      wheel: 6,
      door: [1,2,3,4],
      suspension: [
        Suspension(dist: 1, length: 5),
        Suspension(dist: 2, length: 6),
        Suspension(dist: 3, length: 7)
      ],
      bumper: some("Chromium")
    )

    Winreg.encode(HKCU, commonPath, v)
    let x = Winreg.decode(HKCU, commonPath, Vehicle)
    check x == v
    check x.antennae.isNone
    check x.bumper.get() == "Chromium"
