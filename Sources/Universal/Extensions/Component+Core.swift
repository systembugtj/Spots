#if os(OSX)
  import Foundation
#else
  import UIKit
#endif

// MARK: - Component extension
public extension Component {
  /// A computed CGFloat of the total height of all items inside of a component
  public var computedHeight: CGFloat {
    guard model.layout.dynamicHeight == true else {
      return self.view.frame.height
    }

    var height: CGFloat = 0

    switch model.kind {
    case .list:
      #if !os(OSX)
        let superViewHeight = UIScreen.main.bounds.height
      #endif

      for item in model.items {
        height += item.size.height

        #if !os(OSX)
          /// tvOS adds spacing between cells (it seems to be locked to 14 pixels in height).
          #if os(tvOS)
            if model.kind == .list {
              height += 14
            }
          #endif

          if height > superViewHeight {
            height = superViewHeight
            break
          }
        #endif
      }

      /// Add extra height to make room for focus shadow
      #if os(tvOS)
        if model.kind == .list {
          height += 28
        }
      #endif
    case .grid:
      height = model.size.height
    case .carousel:
        height = model.size.height
        if let firstItem = item(at: 0), firstItem.size.height > height {
          height = firstItem.size.height
          height += CGFloat(model.layout.inset.top)
          height += CGFloat(model.layout.inset.bottom)
      }
    }

    return height
  }

  func configureClosureDidChange() {
    guard let configure = configure else {
      return
    }

    userInterface?.visibleViews.forEach { view in
      switch view {
      case let view as ItemConfigurable:
        configure(view)
      case let view as Wrappable:
        if let wrappedView = view.wrappedView as? ItemConfigurable {
          configure(wrappedView)
        }
      default:
        break
      }
    }
  }

  public func prepareItems(purgeCachedViews: Bool = false) {
    manager.itemManager.prepareItems(component: self, purgeCachedViews: purgeCachedViews)
  }

  /// Resolve a UI component at index with inferred type
  ///
  /// - parameter index: The index of the UI component
  ///
  /// - returns: An optional view of inferred type
  public func ui<T: View>(at index: Int) -> T? {
    return userInterface?.view(at: index)
  }

  public func itemModel<T>(at index: Int) -> T? {
    return item(at: index)?.model as? T
  }

  /// Resolve item at index.
  ///
  /// - parameter index: The index of the item that should be resolved.
  ///
  /// - returns: An optional Item that corresponds to the index.
  public func item(at index: Int) -> Item? {
    guard index < model.items.count && index > -1 else {
      return nil
    }

    return model.items[index]
  }

  /// Resolve item at index path.
  ///
  /// - parameter indexPath: The index path of the item that should be resolved.
  ///
  /// - returns: An optional Item that corresponds to the index path.
  public func item(at indexPath: IndexPath) -> Item? {
    #if os(OSX)
      return item(at: indexPath.item)
    #else
      return item(at: indexPath.row)
    #endif
  }

  /// Update the height of the UI ComponentModel
  ///
  /// - parameter completion: A completion closure that will be run in the main queue when the size has been updated.
  public func updateHeight(_ completion: Completion = nil) {
    Dispatch.interactive { [weak self] in
      guard let `self` = self else {
        completion?()
        return
      }

      let componentHeight = self.computedHeight
      Dispatch.main {
        #if os(macOS)
          if let enclosingScrollView = self.view.enclosingScrollView {
            let maxHeight = enclosingScrollView.frame.size.height - enclosingScrollView.contentInsets.top
            let newHeight: CGFloat = min(maxHeight, componentHeight)

            if self.view.frame.size.height != newHeight {
              self.view.frame.size.height = newHeight
            }
          }
        #else
          if let spotsContentView = self.view.superview {
            let maxHeight = spotsContentView.frame.size.height
            let newHeight: CGFloat = min(maxHeight, componentHeight)
            if self.view.frame.size.height != newHeight {
              self.view.frame.size.height = newHeight
            }
          } else {
            self.view.frame.size.height = componentHeight
          }

        #endif

        completion?()
      }
    }
  }

  /// Refresh indexes for all items to ensure that the indexes are unique and in ascending order.
  public func refreshIndexes(completion: Completion = nil) {
    Dispatch.interactive { [weak self] in
      guard let `self` = self else {
        return
      }

      var updatedItems = self.model.items

      updatedItems.enumerated().forEach {
        updatedItems[$0.offset].index = $0.offset
      }

      self.model.items = updatedItems

      Dispatch.main {
        completion?()
      }
    }
  }

  /// Caches the current state of the component
  public func cache() {
    var cache = ComponentCache()
    cache.item["component"] = [model];
    stateCache?.save(cache)
  }

  /// Get identifier for item at index path
  ///
  /// - parameter indexPath: The index path for the item
  ///
  /// - returns: The identifier string of the item at index path
  func identifier(for indexPath: IndexPath) -> String {
    #if os(OSX)
      return identifier(at: indexPath.item)
    #else
      return identifier(at: indexPath.row)
    #endif
  }

  /// Lookup identifier at index.
  ///
  /// - parameter index: The index of the item that needs resolving.
  ///
  /// - returns: A string identifier for the view, defaults to the `defaultIdentifier` on the component.
  public func identifier(at index: Int) -> String {
    if let item = item(at: index), configuration.views.storage[item.kind] != nil {
      return item.kind
    } else {
      return configuration.views.defaultIdentifier
    }
  }

  /// Get offset of item
  ///
  /// - Parameter includeElement: A predicate closure to determine the offset of the item.
  /// - Returns: The offset based of the model data.
  public func itemOffset(_ includeElement: (Item) -> Bool) -> CGFloat {
    guard let item = model.items.filter(includeElement).first else {
      return 0.0
    }

    let offset: CGFloat
    if model.interaction.scrollDirection == .horizontal {
      offset = model.items[0..<item.index].reduce(0, { $0 + $1.size.width })
    } else {
      offset = model.items[0..<item.index].reduce(0, { $0 + $1.size.height })
    }

    return offset
  }

  /// Update height and refresh indexes for the component.
  ///
  /// - parameter completion: A completion closure that will be run when the computations are complete.
  public func updateHeightAndIndexes(completion: Completion = nil) {
    updateHeight { [weak self] in
      guard let `self` = self else {
        return
      }

      self.refreshIndexes(completion: completion)
    }
  }

  /// Get the size of the item at index path.
  ///
  /// - Parameter indexPath: The index path of the item that should be resolved.
  /// - Returns: A `CGSize` based of the `Item`'s width and height.
  public func sizeForItem(at indexPath: IndexPath) -> CGSize {
    return manager.itemManager.sizeForItem(at: indexPath, in: self)
  }
}
