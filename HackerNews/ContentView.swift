//
//  ContentView.swift
//  HackerNews
//
//  Created by Mario Uher on 22.12.23.
//

import Foundation
import SwiftUI

enum RemoteData<Value> {
  case notAsked
  case loading
  case success(Value)
  case failure(Error)

  var value: Value? {
    switch self {
    case let .success(value):
      return value

    default:
      return nil
    }
  }

  @discardableResult func map<T>(_ transform: (Value) -> T) -> RemoteData<T> {
    switch self {
    case .notAsked:
      return .notAsked

    case .loading:
      return .loading

    case let .success(value):
      return .success(transform(value))

    case let .failure(error):
      return .failure(error)
    }
  }

  func withDefault<T: Equatable>(_ defaultValue: T) -> T {
    switch self {
    case let .success(value):
      return value as! T

    default:
      return defaultValue
    }
  }
}

extension RemoteData: Equatable where Value: Equatable {
  static func == (lhs: RemoteData<Value>, rhs: RemoteData<Value>) -> Bool {
    lhs.value == rhs.value
  }
}

struct API {
  enum Endpoint {
    case topStories
    case item(id: Int)

    var path: String {
      switch self {
      case .topStories:
        return "topstories"
      case let .item(id: id):
        return "item/" + String(id)
      }
    }
  }

  static let shared = API()

  private let jsonDecoder = JSONDecoder()

  public init() {
    jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
  }

  public func fetch<Type: Decodable>(endpoint: Endpoint) async throws -> RemoteData<Type> {
    let url = URL(string: "https://hacker-news.firebaseio.com/v0/" + endpoint.path + ".json")!

    let (data, _) = try await URLSession.shared.data(from: url)
    let decodedData = try jsonDecoder.decode(Type.self, from: data)

    return .success(decodedData)
  }
}

struct Story: Decodable, Hashable, Identifiable {
  var id: Int
  var title: String?
}

@MainActor
struct ContentView: View {
  enum ViewState {
    case loading
    case error(error: Error)
    case success(stories: [Story])
  }

  @State var state: ViewState = .loading

  var body: some View {
    NavigationStack {
      List {
        switch state {
        case .loading:
          ProgressView()
        case .error(let error):
          Text(error.localizedDescription)
        case .success(let stories):
          ForEach(stories) { story in
            NavigationLink(value: story) {
              Text(story.title ?? "")
            }
          }
        }
      }
      .navigationDestination(for: Story.self) { story in
        ScrollView {
          Text(story.title ?? "").font(.title)
        }
        .padding()
      }
    }
    .task {
      await fetch()
    }
  }

  private func fetch() async {
    let storyIDs = await fetchStoryIDs().prefix(10)
    async let stories = fetchStories(ids: storyIDs)

    self.state = await .success(stories: stories)
  }

  private func fetchStoryIDs() async -> [Int] {
    do {
      return try await API.shared.fetch(endpoint: .topStories).value ?? []
    } catch {
      return []
    }
  }

  private func fetchStories<IDs: Sequence>(ids: IDs) async -> [Story] where IDs.Element == Int {
    do {
      return try await withThrowingTaskGroup(of: Story.self) { group -> [Story] in
        var stories: [Story] = []

        for id in ids {
          group.addTask {
            return try await API.shared.fetch(endpoint: .item(id: id)).value!
          }
        }

        for try await story in group {
          stories.append(story)
        }

        return stories
      }
    } catch {
      return []
    }
  }
}

#Preview{
  ContentView()
}
