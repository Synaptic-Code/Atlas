# Atlas

A macOS calculator that goes from `1 + 1` to calculus, built with SwiftUI and the
Liquid Glass design language on macOS 27.

## Requirements

- macOS 27 “Golden Gate” (Liquid Glass APIs)
- Xcode 27 / Swift 6.4 toolchain

## Run it

Open `Atlas.xcodeproj` in Xcode and press ⌘R, or build from the command line:

```sh
# Build the app with Xcode's toolchain
xcodebuild -project Atlas.xcodeproj -scheme Atlas -configuration Debug build

# Build and launch as a real .app bundle (no Xcode required)
./Scripts/build-app.sh
open .build/Atlas.app

# Or run straight from SwiftPM
swift run Atlas
```

Run the engine test suite with ⌘U in Xcode, or:

```sh
xcodebuild -project Atlas.xcodeproj -scheme Atlas test
# or
swift test
```

The Xcode project mirrors the package layout: the `Atlas` app target links and
embeds the `AtlasCore` framework built from `Sources/AtlasCore`, and
`AtlasCoreTests` runs the same tests as `swift test`. The app icon and accent
colour live in `Assets.xcassets`; `Resources/AppIcon.icns` is the source artwork
used by `Scripts/build-app.sh` for the SwiftPM-built bundle.

## What it can do

**Everything numeric** — arithmetic with full precedence, powers, factorials,
percentages, implicit multiplication (`3x`, `2π`, `2(3+4)`), absolute-value bars,
and Unicode input (`×`, `÷`, `−`, `√`, `π`).

**Functions** — trigonometry (degrees or radians), inverse and hyperbolic
functions, logarithms in any base, roots, rounding, combinatorics (`ncr`, `npr`),
number theory (`gcd`, `lcm`, `mod`), statistics (`mean`, `median`, `stdev`), and
aggregates over any number of arguments.

**Variables and answers** — type `x = 5` to define a variable, then use `x`
anywhere. `ans` always holds the previous result. History and variables persist
between launches.

**Calculus** (its own tab, with a live plot):

| Operation | Method |
| --- | --- |
| Derivative, orders 1–4 | Ridders' extrapolation / repeated central differences |
| Definite integral | Adaptive Simpson, including infinite bounds |
| Limit | Extrapolated one- and two-sided limits, including at ±∞ |
| Roots | Range scan + bisection, with touching roots |
| Sum / Product | Kahan-summed Σ and Π over integer ranges |

The plot shades integral regions, draws tangent lines for derivatives, marks
limits, roots and integer sample points.

## Quick syntax

```
2 + 3 × 4              precedence          → 14
2^3^2                  right-associative   → 512
5!                     factorial           → 120
200 + 10%              contextual percent  → 220
2π                     implicit ×          → 6.28318530718
sqrt(2) · cbrt(27)     roots               → 1.414… / 3
log(8, 2) · ln(e)      logarithms          → 3 / 1
ncr(5, 2) · gcd(48,18) combinatorics       → 10 / 6
x = 5                  variable definition
```

The in-app **Reference** sheet (⌘/) lists every function with an example.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Return | Evaluate the expression |
| ⌘↩ | Calculate (also in the Calculus tab) |
| ⇧⌘C | Copy the current result |
| ⇧⌘⌫ | Clear |
| ⇧⌘D | Toggle degrees / radians |
| ⌘1 / ⌘2 / ⌘3 | Basic / Scientific / Calculus |
| ⇧⌘H | Toggle the history sidebar |
| ⌘/ | Function reference |

## Layout

```
Sources/AtlasCore/     Dependency-free math engine
  Lexer · Parser        tokenizer + recursive-descent parser
  Evaluator             AST interpreter, variables, angle modes
  MathFunctions         function library
  Calculus              numerical differentiation/integration/limits/roots/series
  NumberText            display formatting + fraction approximation
  CalculatorEngine      stateful front door (variables, ans)
Sources/Atlas/         SwiftUI app
  Model/                observable calculator and calculus state
  Views/                display, keypads, calculus workspace, plot, sidebar, reference
  Support/Theme.swift   Golden Gate aurora + glass helpers
Tests/                 engine tests
Assets.xcassets/       app icon (all macOS sizes) and accent colour
Preview Content/       preview-only assets, excluded from archives
Config/                Info.plist for the Xcode app target
Atlas.xcodeproj/       Xcode app + framework + test targets
```

## Notes

- Values are IEEE-754 doubles, rendered to 12 significant digits with a fraction
  approximation where one is close.
- Numerical calculus is accurate to roughly 10–12 significant digits for smooth
  functions; results are evaluated in the current angle mode.
- The app is intentionally dependency-free: no third-party packages, and the
  plot is drawn with `Canvas`.
