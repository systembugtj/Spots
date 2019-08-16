import Foundation
import Cache

public class ComponentCache : Codable {
    var item: [String: [ComponentModel]]
    
    init()
    {
        item = [String: [ComponentModel]]();
    }
}

/// A StateCache class used for Controller and Component object caching
public final class StateCache {
    static func makeStorage() -> Storage<ComponentCache>? {
    let cacheName = String(describing: StateCache.self)
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "Spots.bundle.identifier"
    return try? Storage(
      diskConfig: DiskConfig(name: "\(cacheName)/\(bundleIdentifier)"),
      memoryConfig: MemoryConfig(expiry: .never, countLimit: 10, totalCostLimit: 10),
      transformer: TransformerFactory.forCodable(ofType: ComponentCache.self)
    )
  }

  static let storage = StateCache.makeStorage()
  /// Remove state cache for all controllers and components.
  public static func removeAll() {
    try? storage?.removeAll()
  }

  /// A unique identifer string for the StateCache
  public let key: String

  /// A JSON Cache object
    let storage: Storage<ComponentCache>?

  // MARK: - Initialization

  /// Initialize a StateCache with a unique cache key
  ///
  /// - parameter key: A string that is used as an identifier for the StateCache
  ///
  /// - returns: A StateCache object
  public init(key: String) {
    self.storage =  StateCache.makeStorage()
    self.key = key
  }

  // MARK: - Cache

  /// Save JSON to the StateCache
  ///
  /// - parameter json: A JSON object
  public func save(_ object: ComponentCache) {
    let expiry = Expiry.date(Date().addingTimeInterval(60 * 60 * 24 * 3))
    try? storage?.setObject(object, forKey: key, expiry: expiry)
  }

  /// Load JSON from cache
  ///
  /// - returns: A Swift dictionary
  public func load() -> ComponentCache? {
    guard let object = try? storage?.object(forKey: key) else {
      return nil
    }
    return object
  }

  /// Clear the current StateCache
  public func clear(completion: (() -> Void)? = nil) {
    try? storage?.removeAll()
    completion?()
  }

  /// The StateCache file name
  ///
  /// - returns: An md5 representation of the StateCache's file name, computed from the StateCache key
  func fileName() -> String {
    return MD5(key)
  }
}
