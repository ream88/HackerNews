//
//  ContentView.swift
//  HackerNews
//
//  Created by Mario Uher on 22.12.23.
//

import Foundation
import SwiftUI

@MainActor
struct ContentView: View {
  @Environment(API.self) private var api

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
    switch await api.fetch(endpoint: .topStories) as Result<[Int], Error> {
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
          await api.fetch(endpoint: .item(id: id))
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
