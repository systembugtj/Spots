import UIKit

extension Component {
  func setupTableView(_ tableView: TableView, with size: CGSize) {
    tableView.dataSource = componentDataSource
    tableView.delegate = componentDelegate
    tableView.rowHeight = UITableView.automaticDimension
    tableView.layer.masksToBounds = false
    tableView.frame.size = size
    tableView.frame.size.width = round(size.width - (tableView.contentInset.left))
    tableView.frame.origin.x = round(size.width / 2 - tableView.frame.width / 2)

    #if os(tvOS)
      tableView.remembersLastFocusedIndexPath = true
      tableView.layoutMargins = .zero
    #endif

    prepareItems()

    var height: CGFloat = 0.0

    for item in model.items {
      height += item.size.height
    }

    height += headerHeight
    height += footerHeight

    tableView.contentSize = CGSize(
      width: tableView.frame.size.width,
      height: height - tableView.contentInset.top - tableView.contentInset.bottom)

    /// On iOS 8 and prior, the second cell always receives the same height as the first cell. Setting estimatedRowHeight magically fixes this issue. The value being set is not relevant.
    if #available(iOS 9, *) {
      // Set `estimatedRowHeight` to `0` to opt-out of using self-sizing cells based on autolayout.
      tableView.estimatedRowHeight = 0
      return
    } else {
      tableView.estimatedRowHeight = 10
    }
  }

  func layoutTableView(_ tableView: TableView, with size: CGSize) {
    tableView.frame.size.width = round(size.width - CGFloat(model.layout.inset.left + model.layout.inset.right))
    tableView.frame.origin.x = CGFloat(model.layout.inset.left)
  }
}
