import Base

def Ship.escaped(+x: F32, +y: F32) -> Bool:
  F32.is_gt((x * x + y * y : F32), 4.0)

def Ship.read_iterations(iterations: Maybe<&2, U32>) -> U32:
  match iterations:
    case None{}:
      500
    case Some{n}:
      n

def Ship.env_iterations(
  result: Result<&1, &1, U32 & String, String>
) -> U32:
  match result:
    case Fail{error}:
      500
    case Done{value}:
      Ship.read_iterations(U32.read(value))

type Ship.Escape is Data:
  Escape{n: U32, r2: F32}

def Ship.escape.select(
  escaped: Bool,
  +step: U32,
  +r2: F32,
  next: Ship.Escape
) -> Ship.Escape:
  match escaped:
    case True{}:
      Escape{step, r2}

    case False{}:
      next

def Ship.escape.go(
  i: Nat,
  +step: U32,
  +cx: F32,
  +cy: F32,
  +zx: F32,
  +zy: F32
) -> Ship.Escape:
  match i:
    case 0n:
      Escape{0, 0.0}

    case 1n+k:
      +ax = F32.abs(zx)
      +ay = F32.abs(zy)
      +nx = (ax * ax - ay * ay + cx : F32)
      +ny = (2.0 * ax * ay + cy : F32)
      +next_r2 = (nx * nx + ny * ny : F32)
      +did_escape = Ship.escaped(nx, ny)

      Ship.escape.select(
        did_escape,
        step,
        next_r2,
        Ship.escape.go(
          k,
          (step + 1 : U32),
          cx,
          cy,
          nx,
          ny
        )
      )

def Ship.escape(
  i: Nat,
  +cx: F32,
  +cy: F32
) -> Ship.Escape:
  Ship.escape.go(i, 1, cx, cy, 0.0, 0.0)

def Ship.cx(+x: U32) -> F32:
  +u = (U32.to_f32(x) / 511.0 : F32)

  # approximately -1.7885 .. -1.7565
  (F32.neg(1.7725) + (u - 0.5) * 0.032 : F32)

def Ship.cy(+y: U32) -> F32:
  +v = (U32.to_f32(y) / 511.0 : F32)

  # approximately -0.0735 .. -0.0415, vertically reflected
  (F32.neg(0.0575) - (v - 0.5) * 0.032 : F32)

def Ship.pack(+r: U32, +g: U32, +b: U32) -> U32:
  (r << 16n .|. g << 8n .|. b : U32)

def Ship.smooth(e: Ship.Escape) -> F32:
  match e:
    case Escape{0, r2}:
      0.0

    case Escape{n, r2}:
      +mag = F32.sqrt(r2)
      (
        U32.to_f32(n)
        + 1.0
        - F32.log(F32.log(mag)) / F32.log(2.0)
        : F32
      )

def Ship.color_escape(e: Ship.Escape) -> U32:
  match e:
    case Escape{0, r2}:
      # deep brick red
      Ship.pack(145, 42, 26)

    case Escape{n, r2}:
      +mu = Ship.smooth(Escape{n, r2})
      +t = (
        1.0
        - F32.exp(F32.neg((mu * 0.030 : F32)))
        : F32
      )

      +t2 = (t * t : F32)
      +t3 = (t2 * t : F32)

      +r = F32.to_u32((145.0 + 110.0 * t : F32))
      +g = F32.to_u32((42.0 + 205.0 * t2 : F32))
      +b = F32.to_u32((26.0 + 190.0 * t3 : F32))

      Ship.pack(r, g, b)

def Ship.color(+x: U32, +y: U32, +iterations: U32) -> U32:
  +cx = Ship.cx(x)
  +cy = Ship.cy(y)

  Ship.color_escape(
    Ship.escape(
      U32.to_nat(iterations),
      cx,
      cy
    )
  )

def Ship.scene(+d: Nat, +x: U32, +y: U32, +iterations: U32) -> Image:
  match d:
    case 0n:
      Pix{Ship.color(x, y, iterations)}

    case 1n+e:
      +h = U32.shln(1, e)
      +x1 = (x + h : U32)
      +y1 = (y + h : U32)

      tl tr bl br =
        Ship.scene(e, x,  y,  iterations)
        Ship.scene(e, x1, y,  iterations)
        Ship.scene(e, x,  y1, iterations)
        Ship.scene(e, x1, y1, iterations)

      Qua{tl, tr, bl, br}

def Ship.view(s: U32) -> U32 & Image:
  +s2 = s
  (s2, Ship.scene(9n, 0, 0, s2))

def Ship.event(e: Event, +s: U32) -> Maybe<U32>:
  match e:
    case Key{27, True{}}:
      None{}

    case Close{}:
      None{}

    case _:
      Some{s}

def Ship.events(events: List<Event>, s: U32) -> Maybe<U32>:
  match events:
    case []:
      Some{s}

    case e <> rest:
      Maybe.bind(
        &1,
        U32,
        U32,
        Ship.event(e, s),
        next => Ship.events(rest, next)
      )

def Ship.tick(events: List<Event>, s: U32) -> IO(Maybe<U32>):
  IO.pure(Maybe<U32>, Ship.events(events, s))

def main() -> IO(Unit):
  do IO<Unit>:
    settings : Result<&1, &1, U32 & String, String> <-
      IO.get_env("PROOFSHIP_ITERATIONS")
    App.run(
      ~U32,
      ~App{Ship.view, Ship.tick},
      "Proofship",
      512,
      512,
      Ship.env_iterations(settings)
    )
