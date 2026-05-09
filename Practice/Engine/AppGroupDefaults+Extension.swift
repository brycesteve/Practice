//
//  AppGroupDefaults+Extension.swift
//  Practice
//
//  Created by Steve Bryce on 09/05/2026.
//

extension AppGroupDefaults {
    func updateRecoveryData(_ data: RecoveryDataDTO) {
        var context = loadAppContext()
        context.recoveryData = data
        saveAppContext(context)
    }
}
