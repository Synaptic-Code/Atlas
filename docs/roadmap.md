# Atlas Roadmap: Future Enhancements

This document outlines the planned future enhancements for Atlas, organized by feature area. Each item includes a brief description and suggested implementation approach.

---

## Complex Numbers

### Overview
Add full complex number support to the calculator engine, enabling users to work with imaginary numbers in all numeric contexts (arithmetic, functions, calculus).

### Sub-features

#### 1. Literal Syntax
- **Imaginary unit**: `i` and `j` as aliases for √−1
- **Explicit form**: `(a + bi)` or `a + b*i`
- **Polar form**: `r∠θ` (e.g., `3∠45°`)

#### 2. Arithmetic Operations
Implement all standard operations:
- Addition, subtraction, multiplication, division
- Powers and roots (`z^w`, `√z`)
- Conjugate (`conj(z)`) and modulus (`abs(z)`)

#### 3. Functions
Extend the function library to accept complex arguments:
- Trigonometric: `sin`, `cos`, `tan` (and inverses)
- Exponential, logarithmic, hyperbolic functions
- Absolute value, argument/phase

#### 4. Display & Formatting
- Show results in rectangular form by default (`a + bi`)
- Offer polar representation on demand
- Handle edge cases: zero, pure imaginary, infinity

### Implementation Notes
- The core math engine is dependency-free; complex arithmetic can be built using Swift's `Complex` type (stdlib since 5.9) or a minimal custom struct if stricter control is desired.
- Ensure angle mode (degrees/radians) applies to polar input and trigonometric functions.

---

## Matrix Operations

### Overview
Provide matrix algebra capabilities, including basic operations, linear system solving, and determinant/eigenvalue computation for square matrices.

### Sub-features

#### 1. Basic Operations
- Addition, subtraction, scalar multiplication
- Matrix multiplication (with dimension checking)
- Transpose, inverse (for square, non-singular matrices)

#### 2. Linear Algebra
- Solve systems of linear equations `Ax = b` using Gaussian elimination with partial pivoting
- Row reduction to reduced row echelon form (RREF) for inspection

#### 3. Determinant & Eigenvalues
- Compute determinant via cofactor expansion or LU decomposition
- For square matrices, find eigenvalues and eigenvectors (numerical methods acceptable; exact symbolic roots are not required here).

### Implementation Notes
- Matrices will be represented as nested arrays or a dedicated `Matrix` type.
- Keep the implementation within `Sources/AtlasCore`; no external dependencies needed.
- Consider adding matrix input via text (e.g., comma-separated rows) and display formatting with clear delimiters.

---

## UI / UX Considerations

### Display Mode
When complex or matrix results are produced, the calculator should:
- Show a concise summary in the main result area (e.g., `3 + 4i` for a complex number).
- Offer an expandable detail view with additional information (polar form, step-by-step computation, etc.).

### Input Handling
- Allow users to toggle between real-only and complex mode.
- For matrices, provide a clear way to specify dimensions before entering values.

---

## Testing Strategy

Add unit tests for each new feature:
- Complex arithmetic correctness against known identities.
- Matrix operations verified with small hand-crafted examples.
- Edge cases (division by zero, singular matrices) should produce appropriate errors or warnings.

These tests will live alongside the existing `AtlasCoreTests` suite.

---

*This roadmap is a living document; items may be reordered or refined as implementation progresses.*
