//
//  AudioManager.swift
//  Practice
//
//  Created by Steve Bryce on 31/05/2025.
//


import Foundation
import AVFAudio

final class AudioManager {
    var audioPlayer: AVAudioPlayer?
    static let shared = AudioManager()
}


extension AudioManager {
    
    func play() {
        audioPlayer?.play()
    }

    func prepareCountdown() {
        prepareToPlay("countdown")
    }

    fileprivate func prepareToPlay(_ filename: String) {
        guard let soundURL = Bundle.main.url(forResource: filename, withExtension: "caf") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Error al inicializar el reproductor de audio: \(error.localizedDescription)")
        }
    }
}
