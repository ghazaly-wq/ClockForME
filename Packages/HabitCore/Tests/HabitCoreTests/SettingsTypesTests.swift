import XCTest
@testable import HabitCore

final class NumberFormattingTests: XCTestCase {
    func testWesternToArabicIndic() {
        XCTAssertEqual(NumberFormatting.convertDigits(in: "12:30", to: .arabicIndic), "١٢:٣٠")
        XCTAssertEqual(NumberFormatting.convertDigits(in: "0123456789", to: .arabicIndic), "٠١٢٣٤٥٦٧٨٩")
    }

    func testArabicIndicToWestern() {
        XCTAssertEqual(
            NumberFormatting.convertDigits(in: "١٤ نوفمبر ٢٠٢٦", to: .western),
            "14 نوفمبر 2026")
    }

    func testMixedInputIsNormalised() {
        XCTAssertEqual(NumberFormatting.convertDigits(in: "1٢3", to: .western), "123")
        XCTAssertEqual(NumberFormatting.convertDigits(in: "1٢3", to: .arabicIndic), "١٢٣")
    }

    func testNonDigitsAreUntouched() {
        XCTAssertEqual(NumberFormatting.convertDigits(in: "مهمة - ok!", to: .arabicIndic), "مهمة - ok!")
        XCTAssertEqual(NumberFormatting.convertDigits(in: "", to: .western), "")
    }

    func testStringFromInt() {
        XCTAssertEqual(NumberFormatting.string(2026, style: .western), "2026")
        XCTAssertEqual(NumberFormatting.string(2026, style: .arabicIndic), "٢٠٢٦")
        XCTAssertEqual(NumberFormatting.string(-5, style: .arabicIndic), "-٥")
        XCTAssertEqual(NumberFormatting.string(0, style: .arabicIndic), "٠")
    }

    func testDigitStyleStoredValueFallsBackToWestern() {
        XCTAssertEqual(DigitStyle(storedValue: "arabicIndic"), .arabicIndic)
        XCTAssertEqual(DigitStyle(storedValue: "western"), .western)
        XCTAssertEqual(DigitStyle(storedValue: "garbage"), .western)
        XCTAssertEqual(DigitStyle(storedValue: ""), .western)
    }
}

final class AppearanceModeTests: XCTestCase {
    func testStoredValueRoundTrip() {
        for mode in AppearanceMode.allCases {
            XCTAssertEqual(AppearanceMode(storedValue: mode.rawValue), mode)
        }
    }

    func testUnknownStoredValueFallsBackToSystem() {
        XCTAssertEqual(AppearanceMode(storedValue: "sepia"), .system)
        XCTAssertEqual(AppearanceMode(storedValue: ""), .system)
    }

    func testDefaultOrder() {
        XCTAssertEqual(AppearanceMode.allCases, [.system, .light, .dark])
    }
}
