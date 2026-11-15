import Foundation

struct StableRandom: RandomNumberGenerator {
    private var state: UInt64

    init(_ id: UUID, salt: UInt64 = 0) {
        let bytes = id.uuid
        let high = [bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7]
            .reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        let low = [bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15]
            .reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        state = high ^ (low &* 0x9E37_79B9_7F4A_7C15) ^ salt
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func value(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &self)
    }
}
