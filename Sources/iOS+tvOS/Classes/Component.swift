// swiftlint:disable weak_delegate

import UIKit

public class Component: NSObject, ComponentHorizontallyScrollable {
  /// A configuration closure that can be used to pinpoint configuration of
  /// views used inside of the component.
    public static var configure: ((Component) -> Void)?
  /// A focus delegate that returns which component is focused.
  weak public var focusDelegate: ComponentFocusDelegate?
  #if os(tvOS)
  /// A focus guide for the component
  public lazy var focusGuide: UIFocusGuide = .init()
  #endif
  /// A component delegate, used for interaction and to pick up on mutation made to
  /// `self.components`. See `ComponentDelegate` for more information.
  weak public var delegate: ComponentDelegate?
  /// A reference to the header view that should be used for the component.
  var headerView: View?
  /// A reference to the footer view that should be used for the component.
  var footerView: View?
  /// A horizontal scroll view delegate that will invoke methods when a user scrolls
  /// a collection view with horizontal scrolling.
  weak public var carouselScrollDelegate: CarouselScrollDelegate?
  /// The component model, it contains all the information for configuring `Component`
  /// interaction, behaviour and look-and-feel. See `ComponentModel` for more information.
  public var model: ComponentModel
  /// An engine that handles mutation of the component model data source.
  public var manager: ComponentManager
  /// A configuration closure that will be invoked when views are added to the component.
  public var configure: ((ItemConfigurable) -> Void)? {
    didSet {
      configureClosureDidChange()
    }
  }
  /// The delegate for the user interface that the component uses to render itself.
  /// Similar to a normal table or collection view delegate.
  public var componentDelegate: Delegate?
  /// The data source for the user interface that the component uses to render itself.
  /// Similar to a normal table or collection view data source.
  public var componentDataSource: DataSource?
  /// A state cache that can be used to keep state across sessions.
  public var stateCache: StateCache?
  /// A computed value that returns the current view as a UserInterface.
  /// UserInterface supports `UITableView` and `UICollectionView`.
  public var userInterface: UserInterface? {
    return self.view as? UserInterface
  }
  /// A regular UIPageControl that is used inside horizontal collection views.
  /// It is enabled by setting `pageIndicatorPlacement` on `Layout`.
  open lazy var pageControl = UIPageControl()
  /// A background view that gets added to `UICollectionView`.
  open lazy var backgroundView = UIView()
  /// This returns the current user interface as a UIScrollView.
  /// It would either be UICollectionView or UITableView.
  /// If you need to target one specific view it is preferred to use `.tableView` and `.collectionView`.
  /// The height of the header view.
  var headerHeight: CGFloat {
    guard let headerView = headerView else {
      return 0.0
    }

    if model.header?.model != nil {
      return model.header?.size.height ?? 0
    }

    return headerView.frame.size.height
  }
  /// The height of the footer view.
  var footerHeight: CGFloat {
    guard let footerView = footerView else {
      return 0.0
    }

    if model.footer?.model != nil {
      return model.footer?.size.height ?? 0
    }

    return footerView.frame.size.height
  }

  /// The underlying view for this component, usually UITableView or UICollectionView
  public var view: ScrollView {
    didSet {
      if let userInterface = view as? UserInterface {
        userInterface.register(with: configuration)
      }
    }
  }

  /// A computed variable that casts the current `userInterface` into a `UITableView`.
  /// It will return `nil` if the model kind is not `.list`.
  public var tableView: TableView? {
    return userInterface as? TableView
  }
  /// A computed variable that casts the current `userInterface` into a `UICollectionView`.
  /// It will return `nil` if the model kind is `.list`.
  public var collectionView: CollectionView? {
    return userInterface as? CollectionView
  }

  public let configuration: Configuration

  public var isVisible: Bool {
    guard let scrollView = controller?.scrollView else {
      return false
    }

    let isVisible = view.frame.intersects(.init(origin: scrollView.contentOffset,
                                                size: scrollView.frame.size))
    return isVisible
  }

  public var controller: SpotsController? {
    return (focusDelegate as? SpotsController)
  }

  /// Default initializer for creating a component.
  ///
  /// - Parameters:
  ///   - model: A `ComponentModel` that is used to configure the interaction, behavior and look-and-feel of the component.
  ///   - view: A scroll view, should either be a `UITableView` or `UICollectionView`.
  ///   - kind: The `kind` defines which user interface the component should render (either UICollectionView or UITableView).
  public required init(model: ComponentModel, view: ScrollView, configuration: Configuration = .shared) {
    self.model = model
    self.view = view
    self.configuration = configuration
    self.manager = ComponentManager(configuration: configuration)
    super.init()
    registerDefaultIfNeeded(view: DefaultItemView.self)
    userInterface?.register(with: configuration)

    if let collectionViewLayout = collectionView?.flowLayout {
      model.layout.configure(collectionViewLayout: collectionViewLayout)
    }

    let dataSource = DataSource(component: self, with: configuration)
    let delegate = Delegate(component: self, with: configuration)

    self.componentDataSource = dataSource
    self.componentDelegate = delegate

    #if os(tvOS)
      view.addLayoutGuide(focusGuide)
      focusGuide.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
      focusGuide.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
      focusGuide.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
      focusGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
      focusGuide.isEnabled = false
    #endif

    #if DEBUG
      NotificationCenter.default.addObserver(self,
                                             selector: #selector(didInject),
                                             name: NSNotification.Name(rawValue: "INJECTION_BUNDLE_NOTIFICATION"),
                                             object: nil)
    #endif
  }

  /// A convenience init for creating a component with a `ComponentModel`.
  ///
  /// - Parameter model: A component model that is used for constructing and configurating the component.
  public required convenience init(model: ComponentModel, configuration: Configuration = .shared) {
    let view = model.kind == .list
      ? ComponentTableView()
      : ComponentCollectionView(frame: .zero, collectionViewLayout: CollectionLayout())

    self.init(model: model, view: view, configuration: configuration)

    (tableView as? ComponentTableView)?.component = self
    (collectionView as? ComponentCollectionView)?.component = self
  }

  /// A convenience init for creating a component with view state functionality.
  ///
  /// - Parameter cacheKey: The unique cache key that should be used for storing and restoring the component.
  public convenience init(cacheKey: String, configuration: Configuration = .shared) {
    let stateCache = StateCache(key: cacheKey)
    let component = stateCache.load()?.item["component"]
    self.init(model: component?[0] ?? .init(), configuration: configuration)
    self.stateCache = stateCache
  }

  deinit {
    componentDataSource = nil
    componentDelegate = nil
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func didInject() {
    userInterface?.register(with: configuration)
    userInterface?.reloadVisibleViews(with: .none, completion: nil)
  }

  /// Setup up the component with a given size, this is usually the parent size when used in a controller context.
  ///
  /// - Parameter size: A `CGSize` that is used to set the frame of the user interface.
  public func setup(with size: CGSize, needsLayout: Bool = true) {
    view.frame.size = size

    setupFooter(with: configuration)
    setupHeader(with: configuration)

    if let tableView = self.tableView {
      setupTableView(tableView, with: size)
    } else if let collectionView = self.collectionView {
      setupCollectionView(collectionView, with: size)
    }

    layout(with: size, needsLayout: needsLayout)
    configurePageControl()
    Component.configure?(self)
    configuration.configureComponent?(self)

    if model.layout.infiniteScrolling {
      setupInfiniteScrolling()
    }
  }

  /// Configure the view frame with a given size.
  ///
  /// - Parameter size: A `CGSize` used to set a new size to the user interface.
  public func layout(with size: CGSize, needsLayout: Bool = true) {
    if let tableView = self.tableView {
      layoutTableView(tableView, with: size)
    } else if let collectionView = self.collectionView {
      layoutCollectionView(collectionView, with: size)
    }

    layoutHeaderFooterViews(size)

    guard needsLayout else {
      return
    }

    view.setNeedsLayout()

    // Only call `layoutIfNeeded` if the `Component` is not a part of a `SpotsController`.
    if controller != nil {
      if isVisible {
        view.layoutIfNeeded()
      }
    } else {
      view.layoutIfNeeded()
    }
  }

  /// This method is invoked by `ComponentCollectionView.layoutSubviews()`.
  /// It is used to invoke `handleInfiniteScrolling` when the users scrolls a horizontal
  /// `Component` with `infiniteScrolling` enabled.
  func layoutSubviews() {
    #if os(iOS)
      guard model.kind == .carousel,
        model.layout.infiniteScrolling == true,
        model.interaction.paginate != .page
        else {
          return
      }

      handleInfiniteScrolling()
    #endif
  }

  /// Manipulates the x content offset when `infiniteScrolling` is enabled on the `Component`.
  /// The `.x` offset is changed when the user reaches the beginning or the end of a `Component`.
  func handleInfiniteScrolling() {
    guard let collectionView = collectionView,
      let componentDataSource = componentDataSource,
      model.items.count >= componentDataSource.buffer else {
        return
    }

    let offset = collectionView.numberOfItems(inSection: 0) - model.items.count

    guard let firstAttributes = collectionView.layoutAttributesForItem(at: IndexPath(item: componentDataSource.buffer - 1, section: 0)),
      let lastAttributes = collectionView.layoutAttributesForItem(at: IndexPath(item: collectionView.numberOfItems(inSection: 0) - offset, section: 0)) else {
        return
    }

    let max = model.interaction.paginate == .page
      ? lastAttributes.frame.maxX - CGFloat(model.layout.itemSpacing)
      : lastAttributes.frame.maxX + CGFloat(model.layout.inset.left)

    if view.contentOffset.x < CGFloat(model.layout.inset.left) {
      view.contentOffset.x = lastAttributes.frame.origin.x - CGFloat(model.layout.inset.left)
    } else if view.contentOffset.x >= max {
      view.contentOffset.x = firstAttributes.frame.origin.x - CGFloat(model.layout.inset.left)
    }
  }

  /// Setup a collection view with a specific size.
  ///
  /// - Parameters:
  ///   - collectionView: The collection view that should be configured.
  ///   - size: The size that should be used for setting up the collection view.
  fileprivate func setupCollectionView(_ collectionView: CollectionView, with size: CGSize) {
    collectionView.frame.size = size
    collectionView.dataSource = componentDataSource
    collectionView.delegate = componentDelegate
    collectionView.backgroundView = backgroundView
    collectionView.showsHorizontalScrollIndicator = false
    collectionView.showsVerticalScrollIndicator = false
    collectionView.layer.masksToBounds = false

    if #available(iOS 9.0, *) {
      collectionView.remembersLastFocusedIndexPath = !model.layout.infiniteScrolling
    }

    guard model.kind == .carousel else {
      return
    }

    self.model.interaction.scrollDirection = .horizontal
    setupHorizontalCollectionView(collectionView, with: size)
  }

  /// Set new frame to collection view and invalidate the layout.
  ///
  /// - Parameters:
  ///   - collectionView: The collection view that should be configured.
  ///   - size: The size that should be used for setting the new layout for the collection view.
  fileprivate func layoutCollectionView(_ collectionView: CollectionView, with size: CGSize) {
    prepareItems()

    switch model.interaction.scrollDirection {
    case .horizontal:
      if let pageIndicatorPlacement = model.layout.pageIndicatorPlacement {
        switch pageIndicatorPlacement {
        case .below:
          pageControl.frame.origin.y = collectionView.frame.height - pageControl.frame.height
        case .overlay:
          let verticalAdjustment = CGFloat(2)
          pageControl.frame.origin.y = collectionView.frame.height - pageControl.frame.height - verticalAdjustment
        }
      }

      layoutHorizontalCollectionView(collectionView, with: size)
    case .vertical:
      layoutVerticalCollectionView(collectionView, with: size)
    }
  }

  /// Register a default item as fallback, only if it is not already defined.
  ///
  /// - Parameter view: The view that should be registred as the default view.
  func registerDefaultIfNeeded(view: View.Type) {
    guard configuration.views.defaultItem == nil else {
      return
    }

    configuration.views.defaultItem = Registry.Item.classType(view)
  }

  /// Configure the page control for the component.
  /// Page control is only supported in horizontal collection views.
  func configurePageControl() {
    guard let placement = model.layout.pageIndicatorPlacement else {
      pageControl.removeFromSuperview()
      return
    }

    pageControl.numberOfPages = model.items.count
    pageControl.frame.origin.x = 0
    pageControl.frame.size.height = 22

    switch placement {
    case .below:
      pageControl.frame.size.width = backgroundView.frame.width
      pageControl.pageIndicatorTintColor = .lightGray
      pageControl.currentPageIndicatorTintColor = .gray
      backgroundView.addSubview(pageControl)
    case .overlay:
      pageControl.frame.size.width = view.frame.width
      pageControl.pageIndicatorTintColor = nil
      pageControl.currentPageIndicatorTintColor = nil
      view.addSubview(pageControl)
    }
  }

  /// Scroll to a specific item based on predicate.
  ///
  /// - parameter predicate: A predicate closure to determine which item to scroll to.
  public func scrollTo(item predicate: ((Item) -> Bool), animated: Bool = true) {
    guard let index = model.items.index(where: predicate) else {
      return
    }

    if let collectionView = collectionView {
        let scrollPosition: UICollectionView.ScrollPosition

      if model.interaction.scrollDirection == .horizontal {
        scrollPosition = .centeredHorizontally
      } else {
        scrollPosition = .centeredVertically
      }

      collectionView.scrollToItem(at: .init(item: index, section: 0), at: scrollPosition, animated: animated)
    } else if let tableView = tableView {
      tableView.scrollToRow(at: .init(row: index, section: 0), at: .middle, animated: animated)
    }
  }

  /// This method is invoked after mutations has been performed on a component.
  public func afterUpdate() {
    reloadHeader()
    reloadFooter()
    pageControl.numberOfPages = model.items.count
    view.superview?.layoutIfNeeded()
  }
}
