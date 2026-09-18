import Base

def Ship.less(+a: U32, +b: U32) -> Bool:
  U32.is_lt(a, b)

def Ship.escaped(+x: F32, +y: F32) -> Bool:
  F32.is_gt((x * x + y * y : F32), 4.0)

def Ship.is_zero(+n: U32) -> Bool:
  U32.is_eq(n, 0)

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

def Ship.min.go(+a: U32, +b: U32, lt: Bool) -> U32:
  match lt:
    case True{}:
      a
    case False{}:
      b

def Ship.min(+a: U32, +b: U32) -> U32:
  Ship.min.go(a, b, Ship.less(a, b))

def Ship.escape.go(
  i: Nat,
  +step: U32,
  +cx: F32,
  +cy: F32,
  +zx: F32,
  +zy: F32,
  escaped: Bool
) -> U32:
  match i:
    case 0n:
      match escaped:
        case True{}:
          U32.sub(step, 1)
        case False{}:
          0

    case 1n+k:
      match escaped:
        case True{}:
          U32.sub(step, 1)

        case False{}:
          +ax = F32.abs(zx)
          +ay = F32.abs(zy)
          +nx = (ax * ax - ay * ay + cx : F32)
          +ny = (2.0 * ax * ay + cy : F32)

          Ship.escape.go(
            k,
            (step + 1 : U32),
            cx,
            cy,
            nx,
            ny,
            Ship.escaped(nx, ny)
          )

def Ship.escape(
  i: Nat,
  +step: U32,
  +cx: F32,
  +cy: F32,
  +zx: F32,
  +zy: F32
) -> U32:
  Ship.escape.go(i, step, cx, cy, zx, zy, False{})

def Ship.cx(+x: U32) -> F32:
  +u = (U32.to_f32(x) / 511.0 : F32)

  # approximately -1.805 .. -1.740
  (F32.neg(1.7725) + (u - 0.5) * 0.065 : F32)

def Ship.cy(+y: U32) -> F32:
  +v = (U32.to_f32(y) / 511.0 : F32)

  # approximately -0.090 .. -0.025
  (F32.neg(0.0575) + (v - 0.5) * 0.065 : F32)

def Ship.pack(+r: U32, +g: U32, +b: U32) -> U32:
  (r << 16n .|. g << 8n .|. b : U32)

def Ship.color.go(+n: U32, is_zero: Bool) -> U32:
  match is_zero:
    case True{}:
      # dark brick red: #913423
      9516067

    case False{}:
      +heat = Ship.min(255, (n * 4 : U32))

      +r = Ship.min(255, (145 + heat : U32))
      +g = Ship.min(245, (52 + heat * 3 / 4 : U32))
      +b = Ship.min(210, (35 + heat * 2 / 3 : U32))

      Ship.pack(r, g, b)

def Ship.color(+x: U32, +y: U32, +iterations: U32) -> U32:
  +cx = Ship.cx(x)
  +cy = Ship.cy(y)

  +n = Ship.escape(
    U32.to_nat(iterations),
    1,
    cx,
    cy,
    0.0,
    0.0
  )

  Ship.color.go(n, Ship.is_zero(n))

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
