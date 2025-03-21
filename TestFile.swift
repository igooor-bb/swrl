import AVFoundation
import Foundation
import SwiftUI
import Combine
import CustomAnalytics

typealias MediaCollection = [Int64: Int32]
typealias CompletionHandler = (Result<AVFoundation.AVAsset, Error>) -> Void
typealias Completion<T> = (T) throws -> Void

enum MediaState {
    case idle
    case loading(progress: Double)
    case loaded(AVAsset)
    case failed(Error)
}

protocol Loadable {
    associatedtype Item
    func load(completion: @escaping (Item) -> Void)
}

protocol Reportable: AnyObject {
    func reportEvent(_ name: String, metadata: [String: Any])
}

protocol CancellableTask {
    func cancel()
}

struct PaginatedResponse<T> {
    let items: [T]
    let nextPageToken: String?
}

class MediaLoader: Loadable, Reportable {
    typealias Item = AVAsset
    
    private var cancellables = Set<AnyCancellable>()
    private let analytics: AnalyticsTracker = DefaultAnalyticsTracker()
    var onLoad: ((@escaping (AVAsset) -> Void) -> Void)?

    func load(completion: @escaping (AVAsset) -> Void) {
        let publisher = Just(URL(string: "https://example.com/video.mp4")!)
            .compactMap { AVAsset(url: $0) }
            .eraseToAnyPublisher()
        
        publisher
            .sink(receiveValue: { asset in
                completion(asset)
            })
            .store(in: &cancellables)
    }

    struct SwiftUI {
        struct MyStruct {}
    }

    func reportEvent(_ name: String, metadata: [String: Any]) {
        let s = SwiftUI.MyStruct()
        analytics.track(name: name, metadata: metadata)
    }

    func fetchPaginatedData<T: Decodable & Identifiable>(
        endpoint: String,
        page: Int,
        decode: @escaping (Data) throws -> PaginatedResponse<T>
    ) async throws -> PaginatedResponse<T> {
        let dummyData = Data()
        return try decode(dummyData)
    }

    func withGenericHandler<T, E: Error>(
        input: T,
        handler: (Result<T, E>) async -> Void
    ) async {
        await handler(.success(input))
    }
}

@propertyWrapper
struct Injected<T> {
    var wrappedValue: T
}

struct MediaPlayerView: View {
    @State private var isMuted: Bool = false
    @Injected private var loader: MediaLoader
    let onComplete: ((Result<AVAsset?, Never>) -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            if let asset = try? AVAsset(url: URL(string: "https://video.mp4")!) {
                CustomVideoPlayer(asset: asset, isMuted: isMuted)
            } else {
                Text("Loading failed")
            }
            Toggle("Mute", isOn: $isMuted)
        }
        .onAppear {
            loader.load { asset in
                print("Loaded: \(asset)")
            }
        }
    }

    func generateHandler() -> (String, @escaping (Bool) -> Void) -> Void {
        return { message, callback in
            print("Message: \(message)")
            callback(true)
        }
    }

    func performTransformation<T, R>(
        input: T,
        transform: (T) -> R
    ) -> R where R: Equatable, T: CustomStringConvertible {
        return transform(input)
    }
}

struct MediaPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MediaPlayerView(onComplete: nil)
            MediaPlayerView(onComplete: nil)
                .preferredColorScheme(.dark)
        }
    }
}
