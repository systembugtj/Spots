import UIKit

// MARK: - An extension on Composable views
public extension Composable where Self : View {

  /// A configuration method to configure the Composable view with a collection of Spotable objects
  ///
  ///  - parameter item:  The item that is currently being configured in the list
  ///  - parameter spots: A collection of Spotable objects created from the children of the item
  func configure(_ item: inout Item, compositeComponents: [CompositeComponent]?) {
    guard let compositeComponents = compositeComponents else {
      return
    }

    var size = contentView.frame.size
    let width = contentView.frame.width
    var height: CGFloat = 0.0

    #if os(tvOS)
      if let tableView = superview?.superview as? UITableView {
        size.width = tableView.frame.size.width
      }
    #endif

    compositeComponents.enumerated().forEach { _, compositeSpot in
      compositeSpot.spot.setup(size)
      compositeSpot.spot.model.size = CGSize(
        width: width,
        height: ceil(compositeSpot.spot.view.frame.size.height))
      compositeSpot.spot.layout(size)
      compositeSpot.spot.view.layoutIfNeeded()

      compositeSpot.spot.view.frame.origin.y = height
      /// Disable scrolling for listable objects
      compositeSpot.spot.view.isScrollEnabled = !(compositeSpot.spot is Listable)
      compositeSpot.spot.view.frame.size.height = compositeSpot.spot.view.contentSize.height

      height += compositeSpot.spot.view.contentSize.height

      contentView.addSubview(compositeSpot.spot.view)
    }

    item.size.height = height
  }
}
