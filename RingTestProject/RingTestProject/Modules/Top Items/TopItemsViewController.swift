//
//  TopItemsViewController.swift
//  RingTestProject
//
//  Created Yaroslav Nosik on 28.01.2020.
//  Copyright © 2020 Yaroslav Nosik. All rights reserved.

import UIKit

final class TopItemsViewController: BaseViewController, TopItemsViewProtocol, StoryboardInstantiable {
    // MARK: - Props
    var props: TopItemsProps = .initial {
        didSet {
            self.view.setNeedsLayout()
        }
    }

    // MARK: - Default
    enum Default: String {
        case title = "Top Items"
        case lastWatchedItem = "LastWatchedItem"
    }

    // MARK: - Dependencies
    @IBOutlet weak var tableView: UITableView!
    private let refreshControl = UIRefreshControl()
    var lastSeenItemId: String?
    var onRefresh: ((String?) -> Void)?
    var onSelection: ((PostViewModel) -> Void)?
    
    // MARK: View Controller lifecycle
	override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = Default.title.rawValue
        self.tableView.register(cellClass: PostTableViewCell.self)
        self.addRefreshControl()
        self.userActivity = NSUserActivity(activityType: ActivityType.topItems.rawValue)
        self.onRefresh?(lastSeenItemId)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.setupState()
    }

    // MARK: TopItemsViewProtocol
    func showError(with text: String) {
        self.showAlert(text: text,
                       alertTitle: "Error",
                       actionText: "Ok")
    }

    func showFooterActivityView() {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        spinner.frame = CGRect(x: CGFloat.zero, y: CGFloat.zero, width: tableView.bounds.width, height: CGFloat(44.0))

        self.tableView.tableFooterView = spinner
        self.tableView.tableFooterView?.isHidden = false
    }

    func hideFooterActivityView() {
        self.tableView.tableFooterView = nil
        self.tableView.tableFooterView?.isHidden = true
    }

    // MARK: - Actions
    @objc private func onRefreshing() {
        if !self.tableView.isDragging {
            self.onRefresh?(nil)
        }
    }

    // MARK: - Private functions
    private func addRefreshControl() {
        self.tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(onRefreshing), for: .valueChanged)
    }

    private func setupState() {
        switch props.state {
        case .loading:
            if props.posts.isEmpty {
                self.showActivityView()
            } else {
                self.showFooterActivityView()
            }
            
        case .idle, .partial:
            self.tableView.reloadData()
            self.refreshControl.endRefreshing()
            self.hideFooterActivityView()
            self.hideActivityView()
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension TopItemsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return props.posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let element = props.posts[safe: indexPath.row] {
            let cell: PostTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.setup(with: element)
            cell.onSelection = onSelection
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let model = props.posts[safe: indexPath.row]?.model else { return }
        model.photo.cancelDownloading()
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let element = props.posts[safe: indexPath.row] {
            self.lastSeenItemId = element.elementId
        }

        if let next = self.props.onNextPage, indexPath.row == props.posts.count - 2 {
            next.perform()
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if refreshControl.isRefreshing {
            self.onRefresh?(nil)
        }
    }
}

// MARK: State Restoration
extension TopItemsViewController {
    override func updateUserActivityState(_ activity: NSUserActivity) {
        super.updateUserActivityState(activity)
        guard let lastSeenItemId = lastSeenItemId else { return }
        let userInfo: [AnyHashable: Any] = [Default.lastWatchedItem.rawValue: lastSeenItemId]
        self.userActivity?.userInfo = userInfo
    }
}
