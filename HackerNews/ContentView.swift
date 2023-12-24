//
//  ContentView.swift
//  HackerNews
//
//  Created by Mario Uher on 22.12.23.
//

import Foundation
import SwiftUI

struct API {
  static let shared = API()

  enum Endpoint {
    case topStories
    case item(id: Story.ID)

    var path: String {
      switch self {
      case .topStories:
        return "topstories"
      case let .item(id: id):
        return "item/" + String(id)
      }
    }
  }

  private let jsonDecoder: JSONDecoder

  public init() {
    jsonDecoder = JSONDecoder()
    jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
  }

  public func fetch<Type: Decodable>(endpoint: Endpoint) async -> Result<Type, Error> {
    await Task {
      let url = URL(string: "https://hacker-news.firebaseio.com/v0/" + endpoint.path + ".json")!

      let (data, _) = try await URLSession.shared.data(from: url)
      let decodedData = try jsonDecoder.decode(Type.self, from: data)

      return decodedData
    }.result
  }
}

struct Story: Decodable, Hashable, Identifiable {
  typealias ID = Int

  var id: ID
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
      let storyIDs = await fetchStoryIDs().prefix(10)
      async let stories = fetchStories(ids: storyIDs)

      self.state = await .success(stories: stories)
    }
  }

  private func fetchStoryIDs() async -> [Story.ID] {
    switch await API.shared.fetch(endpoint: .topStories) as Result<[Int], Error> {
    case let .success(storyIDs):
      return storyIDs
    default:
      return []
    }
  }

  private func fetchStories<IDs: Sequence>(ids: IDs) async -> [Story]
  where IDs.Element == Story.ID {
    return await withTaskGroup(of: Result<Story, Error>.self) { group -> [Story] in
      var stories: [Story] = []

      for id in ids {
        group.addTask {
          await API.shared.fetch(endpoint: .item(id: id))
        }
      }

      for await result in group {
        if case let .success(story) = result {
          stories.append(story)
        }
      }

      return stories
    }
  }
}

#Preview{
  ContentView()
}
