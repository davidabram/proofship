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

type Ship.State is Data:
  State{
    cx: F32,
    cy: F32,
    span: F32,
    iterations: U32
  }

def Ship.init(+iterations: U32) -> Ship.State:
  State{
    F32.neg(1.7725),
    F32.neg(0.0520),
    0.032,
    iterations
  }

type Ship.Escape is Data:
  Escape{n: U32, r2: F32}

def Ship.escape.go(
  i: Nat,
  +step: U32,
  +cx: F32,
  +cy: F32,
  +zx: F32,
  +zy: F32,
  +r2: F32,
  escaped: Bool
) -> Ship.Escape:
  match i:
    case 0n:
      match escaped:
        case True{}:
          Escape{U32.sub(step, 1), r2}

        case False{}:
          Escape{0, 0.0}

    case 1n+k:
      match escaped:
        case True{}:
          Escape{U32.sub(step, 1), r2}

        case False{}:
          +ax = F32.abs(zx)
          +ay = F32.abs(zy)
          +nx = (ax * ax - ay * ay + cx : F32)
          +ny = (2.0 * ax * ay + cy : F32)
          +next_r2 = (nx * nx + ny * ny : F32)

          Ship.escape.go(
            k,
            (step + 1 : U32),
            cx,
            cy,
            nx,
            ny,
            next_r2,
            Ship.escaped(nx, ny)
          )

def Ship.escape(
  i: Nat,
  +cx: F32,
  +cy: F32
) -> Ship.Escape:
  Ship.escape.go(i, 1, cx, cy, 0.0, 0.0, 0.0, False{})

def Ship.cx(+x: U32, +s: Ship.State) -> F32:
  State{cx, cy, span, iterations} = s
  +u = (U32.to_f32(x) / 511.0 : F32)

  (cx + (u - 0.5) * span : F32)

def Ship.cy(+y: U32, +s: Ship.State) -> F32:
  State{cx, cy, span, iterations} = s
  +v = (U32.to_f32(y) / 511.0 : F32)

  (cy - (v - 0.5) * span : F32)

def Ship.zoom(
  +s: Ship.State,
  +x: U32,
  +y: U32,
  +factor: F32
) -> Ship.State:
  State{cx, cy, span, iterations} = s

  +u = (U32.to_f32(x) / 511.0 : F32)
  +v = (U32.to_f32(y) / 511.0 : F32)

  +dx = (u - 0.5 : F32)
  +dy = (v - 0.5 : F32)

  +next_span = (span * factor : F32)
  +delta = (span - next_span : F32)

  State{
    (cx + dx * delta : F32),
    (cy - dy * delta : F32),
    next_span,
    iterations
  }

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
        - F32.exp(F32.neg((mu * 0.060 : F32)))
        : F32
      )

      +t2 = (t * t : F32)
      +t3 = (t2 * t : F32)

      +r = F32.to_u32((145.0 + 110.0 * t : F32))
      +g = F32.to_u32((42.0 + 205.0 * t2 : F32))
      +b = F32.to_u32((26.0 + 190.0 * t3 : F32))

      Ship.pack(r, g, b)

def Ship.color(+x: U32, +y: U32, +s: Ship.State) -> U32:
  State{cx, cy, span, iterations} = s
  Ship.color_escape(
    Ship.escape(
      U32.to_nat(iterations),
      Ship.cx(x, s),
      Ship.cy(y, s)
    )
  )

def Ship.scene(+d: Nat, +x: U32, +y: U32, +s: Ship.State) -> Image:
  match d:
    case 0n:
      Pix{Ship.color(x, y, s)}

    case 1n+e:
      +h = U32.shln(1, e)
      +x1 = (x + h : U32)
      +y1 = (y + h : U32)

      tl tr bl br =
        Ship.scene(e, x,  y,  s)
        Ship.scene(e, x1, y,  s)
        Ship.scene(e, x,  y1, s)
        Ship.scene(e, x1, y1, s)

      Qua{tl, tr, bl, br}

def Ship.view(s: Ship.State) -> Ship.State & Image:
  +s2 = s
  (s2, Ship.scene(9n, 0, 0, s2))

def Ship.event(e: Event, s: Ship.State) -> Maybe<Ship.State>:
  match e:
    case Key{27, True{}}:
      None{}

    case Mouse{x, y, 0, True{}}:
      Some{Ship.zoom(s, x, y, 0.5)}

    case Mouse{x, y, 1, True{}}:
      Some{Ship.zoom(s, x, y, 2.0)}

    case Close{}:
      None{}

    case _:
      Some{s}

def Ship.events(events: List<Event>, s: Ship.State) -> Maybe<Ship.State>:
  match events:
    case []:
      Some{s}

    case e <> rest:
      Maybe.bind(
        &1,
        Ship.State,
        Ship.State,
        Ship.event(e, s),
        next => Ship.events(rest, next)
      )

def Ship.tick(
  events: List<Event>,
  s: Ship.State
) -> IO(Maybe<Ship.State>):
  IO.pure(
    Maybe<Ship.State>,
    Ship.events(events, s)
  )

def main() -> IO(Unit):
  do IO<Unit>:
    settings : Result<&1, &1, U32 & String, String> <-
      IO.get_env("PROOFSHIP_ITERATIONS")
    App.run(
      ~Ship.State,
      ~App{Ship.view, Ship.tick},
      "Proofship",
      512,
      512,
      Ship.init(Ship.env_iterations(settings))
    )
