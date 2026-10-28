import Foundation

// MARK: - Complex Numbers

/// Represents a complex number.
public struct ComplexNumber {
    public var real: Double
    public var imaginary: Double
    
    init(real: Double = 0, imaginary: Double = 0) {
        self.real = real
        self.imaginary = imaginary
    }
    
    /// Create from rectangular form "a + bi" or polar form "r∠θ".
    public static func parse(_ text: String) -> ComplexNumber? {
        // Normalize whitespace and handle common aliases for i/j
        let normalized = text.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Check for explicit imaginary unit notation (e.g., "3i", "2+4j")
        if normalized.contains("i") || normalized.contains("j") {
            return parseComplexWithImaginary(normalized)
        }
        
        // Try polar form: r∠θ or r<θ
        if let polar = try? ComplexNumber.parsePolar(normalized) {
            return polar
        }
        
        // Fallback to rectangular parsing (pure real numbers)
        guard let doubleValue = Double(normalized) else {
            return nil
        }
        return ComplexNumber(real: doubleValue, imaginary: 0)
    }
    
    private static func parseComplexWithImaginary(_ text: String) -> ComplexNumber? {
        // Remove the 'i' or 'j' suffix and parse as real part
        let withoutI = text.replacingOccurrences(of: "i", with: "")
            .replacingOccurrences(of: "j", with: "")
        
        guard let realPart = Double(withoutI) else { return nil }
        
        // Extract imaginary coefficient (handle implicit multiplication like "3i")
        var imagText = text.replacingOccurrences(of: withoutI, with: "", options: .regularExpression)
        imagText = imagText.trimmingCharacters(in: .whitespaces)
        
        if imagText.isEmpty {
            return ComplexNumber(real: realPart, imaginary: 0)
        }
        
        // Check for explicit coefficient (e.g., "3i" -> imag=3)
        let withoutSuffix = imagText.replacingOccurrences(of: "i", with: "")
            .replacingOccurrences(of: "j", with: "")
        if Double(withoutSuffix) != nil {
            guard let coeff = Double(withoutSuffix) else { return nil }
            // Handle sign separately (e.g., "-3i")
            let sign = String(withoutSuffix.prefix(1)) == "-" ? -1.0 : 1.0
            return ComplexNumber(real: realPart, imaginary: sign * coeff)
        }
        
        // Implicit coefficient of 1 (e.g., "5i" -> imag=5)
        guard let imag = Double(imagText) else { return nil }
        return ComplexNumber(real: realPart, imaginary: imag)
    }
    
    private static func parsePolar(_ text: String) throws -> ComplexNumber {
        // Look for angle symbol ∠ or <
        if let parts = text.split(separator: "∠").first {
            guard let r = Double(parts.trimmingCharacters(in: .whitespaces)) else { return ComplexNumber() }
            
            // Extract angle part (after ∠) — use Int count, not String
            let angleText = String(text.dropFirst(Int(parts.count)))
                .trimmingCharacters(in: .whitespaces)
            
            var angleValue: Double
            if angleText.contains("°") {
                guard let deg = Double(angleText.replacingOccurrences(of: "°", with: "")) else { return ComplexNumber() }
                angleValue = deg * .pi / 180.0
            } else if angleText.contains("rad") {
                guard let rad = Double(angleText.replacingOccurrences(of: "rad", with: "")) else { return ComplexNumber() }
                angleValue = rad
            } else {
                // Assume radians
                angleValue = Double(angleText) ?? 0.0
            }
            
            return ComplexNumber(
                real: r * cos(angleValue),
                imaginary: r * sin(angleValue)
            )
        }
        
        if let parts = text.split(separator: "<").first {
            guard let r = Double(parts.trimmingCharacters(in: .whitespaces)) else { return ComplexNumber() }
            
            // Extract angle part (after <) — use Int count, not String
            let angleText = String(text.dropFirst(Int(parts.count)))
                .trimmingCharacters(in: .whitespaces)
            
            var angleValue: Double
            if angleText.contains("°") {
                guard let deg = Double(angleText.replacingOccurrences(of: "°", with: "")) else { return ComplexNumber() }
                angleValue = deg * .pi / 180.0
            } else if angleText.contains("rad") {
                guard let rad = Double(angleText.replacingOccurrences(of: "rad", with: "")) else { return ComplexNumber() }
                angleValue = rad
            } else {
                // Assume radians
                angleValue = Double(angleText) ?? 0.0
            }
            
            return ComplexNumber(
                real: r * cos(angleValue),
                imaginary: r * sin(angleValue)
            )
        }
        
        return ComplexNumber()
    }
    
    /// Convert to rectangular form (a + bi).
    public var asRectangular: String {
        let imagSign = self.imaginary >= 0 ? "+" : "-"
        let realPart = abs(self.real)
        let imagPart = abs(self.imaginary)
        
        if realPart == 0 && imagPart == 0 {
            return "0"
        } else if realPart == 0 {
            return "\(imagPart)i"
        } else if imagPart == 0 {
            return String(realPart)
        } else {
            // Format with reasonable precision, avoiding trailing zeros
            let formattedReal = NumberText.string(for: self.real)
            let formattedImag = NumberText.string(for: self.imaginary)
            return "\(formattedReal) \(imagSign) \(formattedImag)i"
        }
    }
    
    /// Convert to polar form (r∠θ).
    public var asPolar: String {
        let r = hypot(real, imaginary)
        let theta = atan2(imaginary, real)
        
        // Return radians by default; could add a flag for degrees if needed
        return "\(NumberText.string(for: r))∠\(theta)"
    }
    
    /// Add another complex number.
    public static func +(lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(real: lhs.real + rhs.real, imaginary: lhs.imaginary + rhs.imaginary)
    }
    
    /// Subtract.
    public static func -(lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        ComplexNumber(real: lhs.real - rhs.real, imaginary: lhs.imaginary - rhs.imaginary)
    }
    
    /// Multiply using (a+bi)(c+di) = (ac−bd) + (ad+bc)i.
    public static func *(lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber {
        let real = lhs.real * rhs.real - lhs.imaginary * rhs.imaginary
        let imag = lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        return ComplexNumber(real: real, imaginary: imag)
    }
    
    /// Divide.
    public static func /(lhs: ComplexNumber, rhs: ComplexNumber) throws -> ComplexNumber {
        guard rhs.magnitude > 0 else { throw MathError.divisionByZero }
        
        let denominator = rhs.real * rhs.real + rhs.imaginary * rhs.imaginary
        return ComplexNumber(
            real: (lhs.real * rhs.real + lhs.imaginary * rhs.imaginary) / denominator,
            imaginary: (lhs.imaginary * rhs.real - lhs.real * rhs.imaginary) / denominator
        )
    }
    
    /// Power: z^w where both are complex. Uses polar form for generality.
    public static func ^ (base: ComplexNumber, exponent: ComplexNumber) -> ComplexNumber {
        // Convert to polar and use the formula e^(w log(z))
        let r = hypot(base.real, base.imaginary)
        let theta = atan2(base.imaginary, base.real)
        
        // log(z) = ln|z| + i arg(z)
        let logZ = ComplexNumber(real: log(r), imaginary: theta)
        
        // w * log(z)
        let product = exponent * logZ
        
        return ComplexNumber(
            real: exp(product.real) * cos(product.imaginary),
            imaginary: exp(product.real) * sin(product.imaginary)
        )
    }
    
    /// Conjugate.
    public var conjugate: ComplexNumber {
        ComplexNumber(real: self.real, imaginary: -self.imaginary)
    }
    
    /// Modulus (absolute value).
    public var magnitude: Double {
        hypot(real, imaginary)
    }
}
