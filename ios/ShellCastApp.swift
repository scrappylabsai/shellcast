import SwiftUI
import AVFoundation

@main
struct ShellCastApp: App {
    @State private var client = ShellCastClient()

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(client: client)
                .preferredColorScheme(.dark)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            try session.setActive(true)
        } catch {
            print("[ShellCast] Audio session error: \(error)")
        }
    }
}
