import UIKit
import Tailor
import Sugar

public protocol Listable { }


public struct ListItem: Mappable, Listable {
  public var index = 0
  public var title = ""
  public var subtitle = ""
  public var image = ""
  public var kind = ""
  public var action: String?
  public var size = CGSize(width: 0, height: 0)
  public var meta = [String : AnyObject]()

  public init(_ map: JSONDictionary) {
    title    <- map.property("title")
    subtitle <- map.property("subtitle")
    image    <- map.property("image")
    kind     <- map.property("type")
    action   <- map.property("action")
    size     <- map.property("size")
    meta     <- map.property("meta")
  }

  public init(title: String, subtitle: String = "", image: String = "", kind: String = "", action: String? = "", size: CGSize = CGSize(width: 0, height: 0), meta: [String : AnyObject] = [:]) {
    self.title = title
    self.subtitle = subtitle
    self.image = image
    self.kind = kind
    self.action = action
    self.size = size
    self.meta = meta
  }
}
