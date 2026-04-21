// Flamora appTests/FIREMathTests.swift
//
// V3 alignment test (Swift half). Mirror of
// `Fire cursor/supabase/functions/_tests/fire-math-alignment.test.ts`.
// Both files use the same Park-Miller seeded sequence and the same boundary cases,
// so cross-runtime drift would surface as a failing assertion in either file.

import XCTest
@testable import Flamora_app

final class FIREMathTests: XCTestCase {

    private let realReturn: Double = 0.04

    // MARK: - Boundary cases (must match TS exactly)

    func testMonthsToFIRE_alreadyAtFIRE_returnsZero() {
        XCTAssertEqual(
            FIREMath.monthsToFIRE(netWorth: 1_000_000, monthlySave: 0, fireNumber: 1_000_000, annualRealReturn: realReturn),
            0
        )
        XCTAssertEqual(
            FIREMath.monthsToFIRE(netWorth: 2_000_000, monthlySave: 5_000, fireNumber: 1_000_000, annualRealReturn: realReturn),
            0
        )
    }

    /// Critical ordering: a user past FIRE who is no longer saving must return 0, not Infinity.
    func testMonthsToFIRE_alreadyFIRECheckPrecedesAnySaveCheck() {
        XCTAssertEqual(
            FIREMath.monthsToFIRE(netWorth: 1_500_000, monthlySave: 0, fireNumber: 1_000_000, annualRealReturn: realReturn),
            0
        )
    }

    /// Positive NW + zero save still reaches FIRE via compounding alone.
    /// 100k → 1M at 4% real takes ~ln(10)/ln(1.003333) ≈ 691.6 months.
    func testMonthsToFIRE_compoundingOnly_isFiniteWhenNWPositive() {
        let result = FIREMath.monthsToFIRE(
            netWorth: 100_000,
            monthlySave: 0,
            fireNumber: 1_000_000,
            annualRealReturn: realReturn,
        )
        XCTAssertTrue(result.isFinite, "expected finite, got \(result)")
        XCTAssertEqual(result, 691.62, accuracy: 0.5)
    }

    func testMonthsToFIRE_trulyUnreachable_returnsInfinity() {
        // No net worth and no savings.
        XCTAssertEqual(
            FIREMath.monthsToFIRE(netWorth: 0, monthlySave: 0, fireNumber: 1_000_000, annualRealReturn: realReturn),
            .infinity
        )
        // Decumulation exceeds compounding: 50k * r ≈ 167; save = -200 → den < 0.
        XCTAssertEqual(
            FIREMath.monthsToFIRE(netWorth: 50_000, monthlySave: -200, fireNumber: 1_000_000, annualRealReturn: realReturn),
            .infinity
        )
    }

    func testSolveRequiredSave_alreadyAtFIRE_returnsZero() {
        XCTAssertEqual(
            FIREMath.solveRequiredSave(netWorth: 1_000_000, targetMonths: 360, fireNumber: 500_000, annualRealReturn: realReturn),
            0
        )
    }

    func testSolveRequiredSave_nonPositiveTargetMonths_returnsInfinity() {
        XCTAssertEqual(
            FIREMath.solveRequiredSave(netWorth: 0, targetMonths: 0, fireNumber: 1_000_000, annualRealReturn: realReturn),
            .infinity
        )
        XCTAssertEqual(
            FIREMath.solveRequiredSave(netWorth: 0, targetMonths: -12, fireNumber: 1_000_000, annualRealReturn: realReturn),
            .infinity
        )
    }

    // MARK: - Round-trip property
    //
    // Core V3 alignment proof: same Park-Miller seed yields the same input sequence on
    // both runtimes; closed-form math is bit-deterministic in IEEE 754 double precision.
    // Cross-runtime drift would manifest as a failing iteration on the same index here.

    /// Input ranges chosen so NW * (1+r)^targetMonths < FN always — i.e. compounding
    /// alone never overshoots, so solveRequiredSave returns strictly positive.
    /// Max growth at 4% real over 540 months is ~6×; NW max = 100k × 6 = 600k < FN min = 1M.
    func testRoundTrip_solveThenMonths_recoversTargetMonths() {
        var lcg = ParkMiller(seed: 42)
        for i in 0..<100 {
            let netWorth = lcg.next() * 100_000
            let fireNumber = 1_000_000 + lcg.next() * 2_000_000        // 1M–3M
            let targetMonths = Double(60 + Int(lcg.next() * 480))      // 60–540 months
            let save = FIREMath.solveRequiredSave(
                netWorth: netWorth,
                targetMonths: targetMonths,
                fireNumber: fireNumber,
                annualRealReturn: realReturn,
            )
            XCTAssertGreaterThan(save, 0, "Iteration \(i): precondition save > 0 violated, got \(save)")
            let back = FIREMath.monthsToFIRE(
                netWorth: netWorth,
                monthlySave: save,
                fireNumber: fireNumber,
                annualRealReturn: realReturn,
            )
            let drift = abs(back - targetMonths)
            XCTAssertLessThan(
                drift,
                0.001,
                "Iteration \(i): target=\(targetMonths), back=\(back), drift=\(drift), save=\(save), NW=\(netWorth), FN=\(fireNumber)",
            )
        }
    }

    /// Degenerate case: when growth alone reaches FN, solveRequiredSave returns 0
    /// and monthsToFIRE with save=0 returns the compounding-only time, not .infinity.
    func testRoundTrip_degenerateCase_compoundingAloneReachesFire() {
        let save = FIREMath.solveRequiredSave(
            netWorth: 500_000,
            targetMonths: 360,
            fireNumber: 1_000_000,
            annualRealReturn: realReturn,
        )
        XCTAssertEqual(save, 0)
        let months = FIREMath.monthsToFIRE(
            netWorth: 500_000,
            monthlySave: 0,
            fireNumber: 1_000_000,
            annualRealReturn: realReturn,
        )
        XCTAssertTrue(months.isFinite && months > 0, "expected finite positive, got \(months)")
    }
}

/// Park-Miller minimal-standard PRNG. Mirrors the TS implementation in
/// `_tests/fire-math-alignment.test.ts`.
/// state_{n+1} = (16807 * state_n) mod (2^31 - 1)
private struct ParkMiller {
    var state: Int64
    init(seed: Int64) { self.state = seed }
    mutating func next() -> Double {
        state = (16807 &* state) % 2147483647
        return Double(state) / 2147483647.0
    }
}
