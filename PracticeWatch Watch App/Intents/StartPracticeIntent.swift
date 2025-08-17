//
//  StartPracticeIntent.swift
//  Practice
//
//  Created by Steve Bryce on 26/07/2025.
//


import AppIntents

struct StartPracticeIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Practice"
    static var description = IntentDescription("Starts a practice by name in the app.")
    #if os(watchOS)
    static var supportedModes: IntentModes = [.foreground(.immediate)]
    #else
    static var supportedModes: IntentModes = .background
    #endif
    
    @Parameter(
        title: "Practice",
        requestValueDialog: IntentDialog("Which practice do you want to start?")
    )
    var practice: PracticeEntity
    
    var defaultValue: PracticeEntity {
        PracticeEntity(name: Practice.SimpleAndSinister.rawValue)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$practice)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        #if os(iOS)
        WatchSessionManager.shared.sendStartPractice(practice.name)
        #else
        //NotificationCenter.default.post(name: .startPractice, object: practice.name)
        PracticeManager.shared.selectedPractice = Practice(rawValue: practice.name)
        #endif
        return .result()
    }
}


extension Notification.Name {
    static let startPractice = Notification.Name("StartPractice")
}
