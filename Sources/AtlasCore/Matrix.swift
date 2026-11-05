import Foundation

// MARK: - Matrix

/// A dense matrix of `Double` values stored in row-major order.
///
/// This is the linear-algebra half of the roadmap's “Matrix Operations” entry:
/// basic arithmetic, an inverse, an LU-free Gaussian solve with partial pivoting,
/// reduced row echelon form, a determinant and a numeric eigen-decomposition.
///
/// The type is intentionally small and dependency-free. Matrices are immutable;
/// every operation returns a fresh value.
public struct Matrix: Equatable, Sendable {
    public let rows: Int
    public let columns: Int
    private var values: [Double]

    public init(rows: Int, columns: Int, values: [Double]) throws {
        guard rows > 0, columns > 0 else {
            throw MathError.domainError("A matrix needs at least one row and one column.")
        }
        guard values.count == rows * columns else {
            throw MathError.domainError(
                "A \(rows)×\(columns) matrix needs \(rows * columns) values, got \(values.count)."
            )
        }
        self.rows = rows
        self.columns = columns
        self.values = values
    }

    public init(_ grid: [[Double]]) throws {
        guard let first = grid.first, !first.isEmpty else {
            throw MathError.domainError("A matrix needs at least one row and one column.")
        }
        guard grid.allSatisfy({ $0.count == first.count }) else {
            let widths = Set(grid.map(\.count)).sorted().map(String.init).joined(separator: ", ")
            throw MathError.domainError("Every row must have the same number of entries (found \(widths)).")
        }
        self.rows = grid.count
        self.columns = first.count
        self.values = grid.flatMap { $0 }
    }

    public static func identity(_ size: Int) throws -> Matrix {
        guard size > 0 else { throw MathError.domainError("Identity size must be positive.") }
        var grid = Array(repeating: Array(repeating: 0.0, count: size), count: size)
        for index in 0..<size { grid[index][index] = 1 }
        return try Matrix(grid)
    }

    public subscript(row: Int, column: Int) -> Double {
        get { values[row * columns + column] }
        set { values[row * columns + column] = newValue }
    }

    public func row(_ index: Int) -> [Double] {
        Array(values[(index * columns)..<((index + 1) * columns)])
    }

    public var grid: [[Double]] {
        (0..<rows).map { row($0) }
    }

    public var isSquare: Bool { rows == columns }

    // MARK: Shape checks

    private func requireSameShape(_ other: Matrix) throws {
        guard rows == other.rows, columns == other.columns else {
            throw MathError.domainError(
                "Cannot combine a \(rows)×\(columns) matrix with a \(other.rows)×\(other.columns) matrix."
            )
        }
    }

    private func requireSquare() throws {
        guard isSquare else {
            throw MathError.domainError("This operation needs a square matrix, got \(rows)×\(columns).")
        }
    }

    // MARK: Arithmetic

    public static func + (_ lhs: Matrix, _ rhs: Matrix) throws -> Matrix {
        try lhs.requireSameShape(rhs)
        return try Matrix(rows: lhs.rows, columns: lhs.columns, values: zip(lhs.values, rhs.values).map(+))
    }

    public static func - (_ lhs: Matrix, _ rhs: Matrix) throws -> Matrix {
        try lhs.requireSameShape(rhs)
        return try Matrix(rows: lhs.rows, columns: lhs.columns, values: zip(lhs.values, rhs.values).map(-))
    }

    public func scaled(by factor: Double) throws -> Matrix {
        try Matrix(rows: rows, columns: columns, values: values.map { $0 * factor })
    }

    /// `(m×n) · (n×p) → (m×p)`. The inner dimensions must agree.
    public static func * (_ lhs: Matrix, _ rhs: Matrix) throws -> Matrix {
        guard lhs.columns == rhs.rows else {
            throw MathError.domainError(
                "Cannot multiply a \(lhs.rows)×\(lhs.columns) matrix by a \(rhs.rows)×\(rhs.columns) matrix."
            )
        }
        var out = Array(repeating: 0.0, count: lhs.rows * rhs.columns)
        for rowIndex in 0..<lhs.rows {
            for inner in 0..<lhs.columns {
                let leftValue = lhs[rowIndex, inner]
                guard leftValue != 0 else { continue }
                for columnIndex in 0..<rhs.columns {
                    out[rowIndex * rhs.columns + columnIndex] += leftValue * rhs[inner, columnIndex]
                }
            }
        }
        return try Matrix(rows: lhs.rows, columns: rhs.columns, values: out)
    }

    public func transposed() throws -> Matrix {
        var out = Array(repeating: 0.0, count: rows * columns)
        for rowIndex in 0..<rows {
            for columnIndex in 0..<columns {
                out[columnIndex * rows + rowIndex] = self[rowIndex, columnIndex]
            }
        }
        return try Matrix(rows: columns, columns: rows, values: out)
    }

    public var trace: Double {
        get throws {
            try requireSquare()
            return (0..<rows).reduce(0) { $0 + self[$1, $1] }
        }
    }

    // MARK: Determinant & inverse

    /// Determinant by Gaussian elimination with partial pivoting, `O(n³)`.
    ///
    /// An earlier version of the roadmap suggested cofactor expansion; elimination is
    /// used instead because cofactor expansion is `O(n!)` and unusable past `n ≈ 9`.
    public var determinant: Double {
        get throws {
            try requireSquare()
            var matrix = grid
            var result = 1.0
            for pivotColumn in 0..<columns {
                // Partial pivoting: swap in the largest magnitude candidate for stability.
                var pivotRow = pivotColumn
                var pivotMagnitude = abs(matrix[pivotColumn][pivotColumn])
                for candidate in (pivotColumn + 1)..<rows where abs(matrix[candidate][pivotColumn]) > pivotMagnitude {
                    pivotRow = candidate
                    pivotMagnitude = abs(matrix[candidate][pivotColumn])
                }
                if pivotMagnitude == 0 { return 0 }
                if pivotRow != pivotColumn {
                    matrix.swapAt(pivotRow, pivotColumn)
                    result = -result
                }
                result *= matrix[pivotColumn][pivotColumn]
                let pivot = matrix[pivotColumn][pivotColumn]
                for lowerRow in (pivotColumn + 1)..<rows {
                    let factor = matrix[lowerRow][pivotColumn] / pivot
                    if factor == 0 { continue }
                    for columnIndex in pivotColumn..<columns {
                        matrix[lowerRow][columnIndex] -= factor * matrix[pivotColumn][columnIndex]
                    }
                }
            }
            return result
        }
    }

    public var inverse: Matrix {
        get throws {
            try requireSquare()
            let size = rows
            // Augment with the identity and row-reduce: [A | I] → [I | A⁻¹].
            var augmented = grid
            var identity = try Matrix.identity(size).grid
            for pivotColumn in 0..<size {
                var pivotRow = pivotColumn
                var pivotMagnitude = abs(augmented[pivotColumn][pivotColumn])
                for candidate in (pivotColumn + 1)..<size where abs(augmented[candidate][pivotColumn]) > pivotMagnitude {
                    pivotRow = candidate
                    pivotMagnitude = abs(augmented[candidate][pivotColumn])
                }
                guard pivotMagnitude > 0 else {
                    throw MathError.domainError("Matrix is singular — it has no inverse.")
                }
                if pivotRow != pivotColumn {
                    augmented.swapAt(pivotRow, pivotColumn)
                    identity.swapAt(pivotRow, pivotColumn)
                }
                let pivot = augmented[pivotColumn][pivotColumn]
                for columnIndex in 0..<size {
                    augmented[pivotColumn][columnIndex] /= pivot
                    identity[pivotColumn][columnIndex] /= pivot
                }
                for rowIndex in 0..<size where rowIndex != pivotColumn {
                    let factor = augmented[rowIndex][pivotColumn]
                    if factor == 0 { continue }
                    for columnIndex in 0..<size {
                        augmented[rowIndex][columnIndex] -= factor * augmented[pivotColumn][columnIndex]
                        identity[rowIndex][columnIndex] -= factor * identity[pivotColumn][columnIndex]
                    }
                }
            }
            return try Matrix(identity)
        }
    }

    // MARK: Linear systems & RREF

    /// Reduced row echelon form, plus the column indices of the pivots.
    public func reducedRowEchelonForm() throws -> (matrix: Matrix, pivotColumns: [Int]) {
        var work = grid
        var pivotColumns: [Int] = []
        var pivotRow = 0
        for pivotColumn in 0..<columns where pivotRow < rows {
            var candidate = pivotRow
            var magnitude = abs(work[pivotRow][pivotColumn])
            for index in (pivotRow + 1)..<rows where abs(work[index][pivotColumn]) > magnitude {
                candidate = index
                magnitude = abs(work[index][pivotColumn])
            }
            guard magnitude > 1e-12 else { continue }
            work.swapAt(candidate, pivotRow)
            let pivot = work[pivotRow][pivotColumn]
            for columnIndex in 0..<columns { work[pivotRow][columnIndex] /= pivot }
            for rowIndex in 0..<rows where rowIndex != pivotRow {
                let factor = work[rowIndex][pivotColumn]
                if factor == 0 { continue }
                for columnIndex in 0..<columns {
                    work[rowIndex][columnIndex] -= factor * work[pivotRow][columnIndex]
                }
            }
            pivotColumns.append(pivotColumn)
            pivotRow += 1
        }
        return (try Matrix(work), pivotColumns)
    }

    /// Solves `A·x = b` by Gaussian elimination with partial pivoting.
    ///
    /// Throws ``MathError/domainError`` for a non-square `A`, a mismatched `b` and a
    /// singular system — a singular system genuinely has no unique answer, so silently
    /// returning a pseudo-solution would be worse than failing.
    public func solve(_ rightHandSide: [Double]) throws -> [Double] {
        try requireSquare()
        guard rightHandSide.count == rows else {
            throw MathError.domainError(
                "Right-hand side must have \(rows) entries, got \(rightHandSide.count)."
            )
        }
        let size = rows
        var augmented = grid
        var solution = rightHandSide
        for pivotColumn in 0..<size {
            var pivotRow = pivotColumn
            var magnitude = abs(augmented[pivotColumn][pivotColumn])
            for candidate in (pivotColumn + 1)..<size where abs(augmented[candidate][pivotColumn]) > magnitude {
                pivotRow = candidate
                magnitude = abs(augmented[candidate][pivotColumn])
            }
            guard magnitude > 1e-12 else {
                throw MathError.domainError("System is singular — it has no unique solution.")
            }
            if pivotRow != pivotColumn {
                augmented.swapAt(pivotRow, pivotColumn)
                solution.swapAt(pivotRow, pivotColumn)
            }
            let pivot = augmented[pivotColumn][pivotColumn]
            for lowerRow in (pivotColumn + 1)..<size {
                let factor = augmented[lowerRow][pivotColumn] / pivot
                if factor == 0 { continue }
                for columnIndex in pivotColumn..<size {
                    augmented[lowerRow][columnIndex] -= factor * augmented[pivotColumn][columnIndex]
                }
                solution[lowerRow] -= factor * solution[pivotColumn]
            }
        }
        // Back substitution.
        for rowIndex in stride(from: size - 1, through: 0, by: -1) {
            var total = solution[rowIndex]
            for columnIndex in (rowIndex + 1)..<size {
                total -= augmented[rowIndex][columnIndex] * solution[columnIndex]
            }
            solution[rowIndex] = total / augmented[rowIndex][rowIndex]
        }
        return solution
    }

    // MARK: Eigenvalues

    public struct Eigenpair: Equatable, Sendable {
        public let eigenvalue: Double
        public let eigenvector: [Double]
    }

    /// Numeric eigenvalues and eigenvectors.
    ///
    /// Symmetric matrices go through Jacobi rotations, which is both simpler and far more
    /// accurate than QR iteration and yields orthonormal eigenvectors for free. Everything
    /// else falls back to unshifted QR iteration followed by inverse iteration.
    ///
    /// The roadmap allows a numerical method here (“exact symbolic roots are not required”).
    /// A complex spectrum is not representable by this real-valued API, so the caller
    /// receives whatever real approximation QR converged to; use `isSymmetric` to know
    /// whether the result can be trusted.
    public var eigenpairs: [Eigenpair] {
        get throws {
            try requireSquare()
            let n = rows
            if n == 1 {
                return [Eigenpair(eigenvalue: self[0, 0], eigenvector: [1])]
            }
            guard n <= 60 else {
                throw MathError.domainError("Numeric eigen-decomposition supports matrices up to 60×60.")
            }
            if isSymmetric {
                let (values, vectors) = jacobiEigen()
                return zip(values, vectors)
                    .map { Eigenpair(eigenvalue: $0.0, eigenvector: $0.1) }
                    .sorted { $0.eigenvalue < $1.eigenvalue }
            }
            let values = try qrEigenvalues()
            var pairs: [Eigenpair] = []
            for value in values {
                guard let vector = try inverseIteration(for: value) else { continue }
                pairs.append(Eigenpair(eigenvalue: value, eigenvector: vector))
            }
            return pairs.sorted { $0.eigenvalue < $1.eigenvalue }
        }
    }

    /// `aᵢⱼ == aⱼᵢ` within rounding.
    public var isSymmetric: Bool {
        guard isSquare else { return false }
        let scale = max(1, grid.flatMap { $0.map(abs) }.max() ?? 1)
        for i in 0..<rows {
            for j in 0..<i where abs(self[i, j] - self[j, i]) > 1e-12 * scale {
                return false
            }
        }
        return true
    }

    /// Cyclic Jacobi eigenvalue algorithm for symmetric matrices.
    ///
    /// Returns the eigenvalues and the corresponding orthonormal eigenvectors (each
    /// eigenvector is one element of the returned array).
    private func jacobiEigen() -> ([Double], [[Double]]) {
        let n = rows
        var a = grid
        // V accumulates the rotations; its columns become the eigenvectors.
        var v: [[Double]] = (0..<n).map { i in
            (0..<n).map { j in i == j ? 1 : 0 }
        }

        for _ in 0..<(60 * n * n) {
            // Largest off-diagonal magnitude.
            var offDiagonal = 0.0
            var p = 0
            var q = 1
            for i in 0..<n {
                for j in (i + 1)..<n where abs(a[i][j]) > offDiagonal {
                    offDiagonal = abs(a[i][j])
                    p = i
                    q = j
                }
            }
            guard offDiagonal > 1e-14 else { break }

            // Rotation annihilating a[p][q].
            let theta = (a[q][q] - a[p][p]) / (2 * a[p][q])
            let t = (theta >= 0 ? 1.0 : -1.0) / (abs(theta) + sqrt(theta * theta + 1))
            let c = 1 / sqrt(t * t + 1)
            let s = t * c

            for k in 0..<n {
                let aip = a[k][p]
                let aiq = a[k][q]
                a[k][p] = c * aip - s * aiq
                a[k][q] = s * aip + c * aiq
            }
            for k in 0..<n {
                let api = a[p][k]
                let aqi = a[q][k]
                a[p][k] = c * api - s * aqi
                a[q][k] = s * api + c * aqi
            }
            for k in 0..<n {
                let vip = v[k][p]
                let viq = v[k][q]
                v[k][p] = c * vip - s * viq
                v[k][q] = s * vip + c * viq
            }
            a[p][q] = 0
            a[q][p] = 0
        }

        let values = (0..<n).map { a[$0][$0] }
        let vectors = (0..<n).map { columnIndex in
            (0..<n).map { rowIndex in v[rowIndex][columnIndex] }
        }
        return (values, vectors)
    }

    /// Unshifted QR iteration; returns the diagonal once the subdiagonal vanishes.
    private func qrEigenvalues() throws -> [Double] {
        let n = rows
        var a = grid
        let scale = max(1, a.flatMap { $0.map(abs) }.max() ?? 1)
        for _ in 0..<2000 {
            let shifted = try Matrix(a).qrDecomposition()
            // The iteration step is A' = R·Q = QᵀAQ, a similarity transform, so the
            // eigenvalues are preserved. `shifted.q` holds Q's columns, so it must be
            // transposed before the product — multiplying by it directly computes R·Qᵀ,
            // which is not similar to A and drifts away from the true spectrum.
            let qRows = (0..<n).map { row in
                (0..<n).map { column in shifted.q[column][row] }
            }
            a = gridFromProduct(shifted.r, qRows)
            var belowDiagonal = 0.0
            for i in 1..<n {
                for j in 0..<i { belowDiagonal += abs(a[i][j]) }
            }
            if belowDiagonal < 1e-13 * scale { break }
        }
        return (0..<n).map { a[$0][$0] }
    }

    /// Solves `(A − λI)v = 0` by inverse iteration: repeatedly divide by a
    /// nearly-singular matrix so the solution collapses onto the eigenvector.
    private func inverseIteration(for eigenvalue: Double) throws -> [Double]? {
        let n = rows
        let scale = max(1, grid.flatMap { $0.map(abs) }.max() ?? 1)
        var shifted = grid
        for index in 0..<n {
            shifted[index][index] -= eigenvalue + 1e-10 * scale
        }
        var vector = (0..<n).map { $0 == 0 ? 1.0 : 1.0 }
        for _ in 0..<12 {
            let solved = try? Matrix(shifted).solveHorner(vector)
            guard let next = solved else { return vector }
            let norm = sqrt(next.map { $0 * $0 }.reduce(0, +))
            guard norm > 1e-12 else { break }
            vector = next.map { $0 / norm }
        }
        let norm = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        guard norm > 1e-12 else { return nil }
        return vector.map { $0 / norm }
    }

    /// Solves without throwing for a (near) singular system: no pivoting failure is fatal here.
    private func solveHorner(_ rightHandSide: [Double]) throws -> [Double] {
        try Matrix(rows: rows, columns: columns, values: values).solve(rightHandSide)
    }

    private struct QR {
        let q: [[Double]]
        let r: [[Double]]
    }

    private func qrDecomposition() throws -> QR {
        let n = rows
        var columns: [[Double]] = []
        for columnIndex in 0..<n {
            var v = (0..<n).map { self[$0, columnIndex] }
            for _ in 0..<2 {
                for q in columns {
                    let projection = zip(v, q).map(*).reduce(0, +)
                    for index in 0..<n { v[index] -= projection * q[index] }
                }
            }
            let norm = sqrt(v.map { $0 * $0 }.reduce(0, +))
            if norm < 1e-14 {
                var fallback = Array(repeating: 0.0, count: n)
                fallback[columnIndex] = 1
                for q in columns {
                    let projection = zip(fallback, q).map(*).reduce(0, +)
                    for index in 0..<n { fallback[index] -= projection * q[index] }
                }
                let fallbackNorm = sqrt(fallback.map { $0 * $0 }.reduce(0, +))
                columns.append(fallbackNorm > 0 ? fallback.map { $0 / fallbackNorm } : fallback)
            } else {
                columns.append(v.map { $0 / norm })
            }
        }
        // R = QᵀA: r[i][j] is the dot product of Q's i-th column with A's j-th column.
        // (Using columns[$1][i] here instead would compute Q·A, which is neither
        // upper-triangular nor a factor of A.)
        var r = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n {
            for j in 0..<n {
                r[i][j] = (0..<n).reduce(0) { $0 + columns[i][$1] * self[$1, j] }
            }
        }
        return QR(q: columns, r: r)
    }

    private func gridFromProduct(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        let n = a.count
        var out = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for i in 0..<n {
            for k in 0..<n {
                let aik = a[i][k]
                if aik == 0 { continue }
                for j in 0..<n { out[i][j] += aik * b[k][j] }
            }
        }
        return out
    }

    // MARK: Display

    /// Renders as `[1, 2; 3, 4]` — rows separated by `;`, entries by `,`.
    public var description: String {
        let rowsText = (0..<rows).map { rowIndex in
            row(rowIndex).map { NumberText.string(for: $0) }.joined(separator: ", ")
        }
        return "[" + rowsText.joined(separator: "; ") + "]"
    }
}

extension Matrix: CustomStringConvertible {}

// MARK: - Least squares

extension Matrix {
    /// Solves a (possibly over-determined) system by normal equations with pivoting.
    ///
    /// Used internally to recover eigenvector components; exposed because it is a
    /// legitimate operation for a non-square matrix.
    public func leastSquaresSolve(_ rightHandSide: [Double]) throws -> [Double] {
        guard rows == rightHandSide.count else {
            throw MathError.domainError("Right-hand side must have \(rows) entries.")
        }
        return try transposed().multiplied(by: self).solve(transposed().multiplied(byVector: rightHandSide))
    }

    public func multiplied(by other: Matrix) throws -> Matrix {
        try self * other
    }

    public func multiplied(byVector vector: [Double]) throws -> [Double] {
        guard columns == vector.count else {
            throw MathError.domainError("Vector must have \(columns) entries, got \(vector.count).")
        }
        return (0..<rows).map { rowIndex in
            (0..<columns).reduce(0.0) { total, columnIndex in
                total + self[rowIndex, columnIndex] * vector[columnIndex]
            }
        }
    }
}

// MARK: - Parsing

extension Matrix {
    /// Parses `[1, 2; 3, 4]`, `|1 2; 3 4|`, or rows separated by newlines.
    ///
    /// Semicolons (or line breaks) separate rows; commas and whitespace separate
    /// entries. The leading `[` and trailing `]` are optional so users can paste raw rows.
    public static func parse(_ text: String) throws -> Matrix {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("[") && body.hasSuffix("]") {
            body = String(body.dropFirst().dropLast())
        } else if body.hasPrefix("|") && body.hasSuffix("|") {
            body = String(body.dropFirst().dropLast())
        }

        let rowTexts = body
            .split(whereSeparator: { $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !rowTexts.isEmpty else {
            throw MathError.domainError("Matrix input is empty.")
        }

        let grid: [[Double]] = try rowTexts.map { rowText in
            let fields = rowText.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\t" })
            guard !fields.isEmpty else {
                throw MathError.domainError("A matrix row was empty.")
            }
            return try fields.map { field in
                let trimmed = field.trimmingCharacters(in: .whitespaces)
                guard let value = Double(trimmed) else {
                    throw MathError.domainError("“\(trimmed)” is not a number.")
                }
                return value
            }
        }
        return try Matrix(grid)
    }
}
