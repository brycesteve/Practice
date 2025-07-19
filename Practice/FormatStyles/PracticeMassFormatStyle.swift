//
//  LargeMassFormatStyle.swift
//  Practice
//
//  Created by Steve Bryce on 19/07/2025.
//

import Foundation

struct PracticeMassFormatStyle: FormatStyle {
    var locale: Locale = .current
    var precision: Int = 2
    var width: Measurement<UnitMass>.FormatStyle.UnitWidth = .abbreviated

    func format(_ value: Measurement<UnitMass>) -> String {
        let baseValue = value.converted(to: .kilograms).value
        let (scaledValue, unit): (Double, UnitMass) = {
            switch baseValue {
            case 1_000_000_000...:
                return (baseValue / 1_000_000_000, .megatonnes)
            case 1_000_000...:
                return (baseValue / 1_000_000, .kilotonnes)
            case 1_000...:
                return (baseValue / 1_000, .metricTons)
            default:
                return (baseValue, .kilograms)
            }
        }()

        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        numberFormatter.minimumFractionDigits = precision
        numberFormatter.maximumFractionDigits = precision

        let number = numberFormatter.string(from: NSNumber(value: scaledValue)) ?? "\(scaledValue)"
        let label = {
            switch width {
            case .wide:
                return UnitMass.name(for: unit)
            default:
                return UnitMass.abbreviation(for: unit)
            }
        }()
        return "\(number) \(label)"
    }
}

extension FormatStyle where Self == PracticeMassFormatStyle {
    static var practiceMass: PracticeMassFormatStyle {
        PracticeMassFormatStyle()
    }

    static func practiceMass(locale: Locale = .current, precision: Int = 2, width: Measurement<UnitMass>.FormatStyle.UnitWidth = .abbreviated) -> PracticeMassFormatStyle {
        PracticeMassFormatStyle(locale: locale, precision: precision, width: width)
    }
}
