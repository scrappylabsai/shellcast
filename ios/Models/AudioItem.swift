import Foundation

struct AudioItem: Identifiable {
    let id: String
    let voice: String
    let text: String
    let audioData: Data
    let receivedAt: Date
    var isPlaying: Bool = false
}
