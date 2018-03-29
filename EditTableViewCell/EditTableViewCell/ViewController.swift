//
//  ViewController.swift
//  EditTableViewCell
//
//  Created by ancheng on 2018/3/26.
//  Copyright © 2018年 ancheng. All rights reserved.
//

import UIKit
import AsyncDisplayKit

class ViewController: UIViewController {

    private lazy var tableNode = ASTableNode()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubnode(tableNode)
        tableNode.dataSource = self
        tableNode.circle_swipeDelegate = self

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        tableNode.frame = view.bounds
    }
}

extension ViewController: ASTableDataSource {

    func numberOfSections(in tableNode: ASTableNode) -> Int {
        return 1
    }

    func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
        return 20
    }

    func tableNode(_ tableNode: ASTableNode, nodeForRowAt indexPath: IndexPath) -> ASCellNode {
        let cell = TextureDemoCellNode(tableNode: tableNode)
        return cell
    }
}

extension ViewController: ASTableNodeSwipableDelegate {
    public func swipe_tableNode(_ tableNode: ASTableNode, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    public func swipe_tableNode(_ tableNode: ASTableNode, editActionsOptionsForRowAt indexPath: IndexPath) -> [SwipedAction] {

        guard let cell = tableNode.nodeForRow(at: indexPath) as? TextureDemoCellNode else { return [] }
        let deleteAction = SwipedAction(title: "删除", backgroundColor: #colorLiteral(red: 1, green: 0.01568627451, blue: 0.3450980392, alpha: 1), titleColor: UIColor.white, titleFont: UIFont.systemFont(ofSize: 17, weight: .medium), preferredWidth: nil, handler: { [weak self] (_) in
//            guard let strongSelf = self else { return }
//            if indexPath.row >= strongSelf.conversations.count { return }
//            strongSelf.conversations.remove(at: indexPath.row)
//            strongSelf.tableNode.deleteRows(at: [indexPath], with: .automatic)
//            Config.deleteConversationAction?(conversation)
            cell.hideSwipe(animated: true)
        })
        deleteAction.needConfirm = .custom(title: "确认删除")

        let markAction: SwipedAction

        let markAsRead = SwipedAction(title: "标记未读", handler: { (_) in
//            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: {
//                ConversationMarkUnreadCache.markUnread(conversationID: conversation.id, on: false)
//                Config.markAllMessagesInConversationReadAction?(conversation)
//            })
            cell.hideSwipe(animated: true)
        })
        markAction = markAsRead

        markAction.backgroundColor = #colorLiteral(red: 0.8117647059, green: 0.8117647059, blue: 0.8117647059, alpha: 1)
        markAction.titleFont = UIFont.systemFont(ofSize: 17, weight: .medium)
        markAction.horizontalMargin = 24
        deleteAction.horizontalMargin = 24

        return [markAction, deleteAction]
    }

}

//    private lazy var tableView = DemoTableView()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.addSubview(tableView)
//        tableView.translatesAutoresizingMaskIntoConstraints = false
//        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
//        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
//        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
//        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
//
//        tableView.dataSource = self
//        tableView.delegate = self
//        tableView.register(DemoTableViewCell.self, forCellReuseIdentifier: "DemoTableViewCell")
//    }
//
//}
//
//extension ViewController: UITableViewDataSource {
//
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return 20
//    }
//
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: "DemoTableViewCell", for: indexPath)
//        cell.textLabel?.text = "哈哈哈哈哈哈哈哈哈哈"
//        return cell
//    }
//}
//
//extension ViewController: UITableViewDelegate {
//
//    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
//        return false
//    }
//}
//
//class DemoTableView: UITableView, SwipeTableViewCellDelegate {
//
//    func swipe_tableView(_ tableView: UITableView, editActionsOptionsForRowAt indexPath: IndexPath) -> [SwipedAction] {
//        let deleteAction = SwipedAction(title: "删除") { (_) in
//            tableView.deleteRows(at: [indexPath], with: .automatic)
//        }
//        deleteAction.needConfirm = .custom(title: "确认删除")
//        let unreadAction = SwipedAction(title: "标记未读") { (_) in
//
//        }
//        unreadAction.needConfirm = .custom(title: "确认删除")
//        unreadAction.backgroundColor = .gray
//
//        if indexPath.row % 3 == 0 {
//            deleteAction.preferredWidth = 100
//        }
//
//        if indexPath.row % 2 == 1 {
//            return [unreadAction, deleteAction]
//        } else {
//            return [deleteAction]
//        }
//    }
//
//    func swipe_tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
//        return true
//    }
//}

