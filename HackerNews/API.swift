//
//  API.swift
//  HackerNews
//
//  Created by Mario Uher on 25.12.23.
//

import Foundation

struct Story: Decodable, Hashable, Identifiable {
  typealias ID = Int

  var id: ID
  var title: String?
}

@Observable
class API {
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
