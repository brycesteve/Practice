//
//  Measurement+Extension.swift
//  Practice
//
//  Created by Steve Bryce on 19/07/2025.
//

import Foundation

extension UnitMass {
    static let kilotonnes = UnitMass(symbol: "kt", converter: UnitConverterLinear(coefficient: 1_000_000))
    static let megatonnes = UnitMass(symbol: "Mt", converter: UnitConverterLinear(coefficient: 1_000_000_000))

    static func name(for unit: UnitMass) -> String {
        switch unit {
        case .kilograms: return "kilograms"
        case .metricTons: return "tonnes"
        case .kilotonnes: return "kilotonnes"
        case .megatonnes: return "megatonnes"
        default: return unit.symbol
        }
    }

    static func abbreviation(for unit: UnitMass) -> String {
        return unit.symbol // or use switch if you want to override
    }
}
