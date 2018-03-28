//
//  TextureDemoTableViewCell.swift
//  EditTableViewCell
//
//  Created by ancheng on 2018/3/27.
//  Copyright © 2018年 ancheng. All rights reserved.
//

import UIKit
import AsyncDisplayKit

class TextureDemoTableViewCell: ASCellNode {

    let textNode = ASTextNode()

    private var originalX: CGFloat = 0
    weak var tableNode: ASTableNode?
    private var originalLayoutMargins: UIEdgeInsets = .zero
    private var actionsView: ActionsView?

    private(set) var isActionShowing = false
    private var isHideSwiping = false
    private var isPanning = false

    lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(didPan))
        gesture.delegate = self
        return gesture
    }()

    lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        gesture.delegate = self
        return gesture
    }()

    init(tableNode: ASTableNode) {
        self.tableNode = tableNode
        super.init()

        clipsToBounds = false

        view.backgroundColor = UIColor.green

        addSubnode(textNode)
        textNode.attributedText = NSAttributedString(string: "哈哈哈哈哈哈哈哈哈哈", attributes: [.foregroundColor: UIColor.black])
        view.addGestureRecognizer(panGestureRecognizer)
        view.addGestureRecognizer(tapGestureRecognizer)

        tableNode.view.panGestureRecognizer.removeTarget(self, action: nil)
        tableNode.view.panGestureRecognizer.addTarget(self, action: #selector(tableViewDidPan))
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        textNode.style.preferredSize = CGSize(width: 100, height: 100)
        return ASStackLayoutSpec(direction: .horizontal, spacing: 0, justifyContent: .center, alignItems: .center, children: [textNode])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

//    override open func didMoveToSuperview() {
//        super.didMoveToSuperview()
//
//        var view: UIView = self
//        while let superview = view.superview {
//            view = superview
//
//            if let tableView = view as? UITableView {
//                self.tableView = tableView
//
//                tableView.panGestureRecognizer.removeTarget(self, action: nil)
//                tableView.panGestureRecognizer.addTarget(self, action: #selector(tableViewDidPan))
//                return
//            }
//        }
//    }

    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
//        guard let superview = supernode else { return false }

//        let point = convert(point, to: superview)

        return contains(point: point)
    }

    func contains(point: CGPoint) -> Bool {
        return point.y > frame.minY && point.y < frame.maxY
    }

    deinit {
        tableNode?.view.panGestureRecognizer.removeTarget(self, action: nil)
    }

    @objc private func didPan(gesture: UIPanGestureRecognizer) {

        guard let target = gesture.view else { return }

        switch gesture.state {
        case .began:
            isPanning = true
            stopAnimatorIfNeeded()

            originalX = frame.origin.x

            if !isActionShowing {
                if gesture.velocity(in: target).x > 0 { return }
                isActionShowing = true
                showActionsView()
            }
        case .changed:

            guard let actionsView = actionsView else { return }

            let translationX = gesture.translation(in: target).x
            let offsetX = originalX + translationX
            if offsetX > 0 {
                target.frame.origin.x = 0
            } else {
                target.frame.origin.x = offsetX
                let progress = abs(offsetX) / actionsView.preferredWidth

                if !actionsView.isConfirming {
                    actionsView.setProgress(progress)
                }
            }

        case .ended:

            isPanning = false
            guard let actionsView = actionsView else {
                reset()
                return
            }
            let translationX = gesture.translation(in: target).x
            if originalX + translationX >= 0 {
                reset()
                return
            }

            let offSetX = translationX < 0 ? -actionsView.preferredWidth : 0
            let velocity = gesture.velocity(in: target)

            let distance = -frame.origin.x
            let normalizedVelocity = velocity.x / distance

            animate(toOffset: offSetX, withInitialVelocity: normalizedVelocity * 0.4, isConfirming: actionsView.isConfirming) { [weak self] _ in
                guard let strongSelf = self else { return }
                if strongSelf.isActionShowing && translationX >= 0  {
                    strongSelf.reset()
                }
            }
        default:
            break
        }
    }

    @objc private func didTap(gesture: UITapGestureRecognizer) {
        hideSwipe(animated: true)
    }

    @objc private func tableViewDidPan(gesture: UIPanGestureRecognizer) {
        hideSwipe(animated: true)
    }

    private func hideSwipe(animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard !isPanning else { return }
        guard isActionShowing else { return }
        guard !isHideSwiping else { return }
        isHideSwiping = true
        isActionShowing = false
        if animated {
            animate(toOffset: 0, isConfirming: actionsView?.isConfirming == true, fromHideAction: true) { [weak self] complete in
                completion?(complete)
                self?.reset()
            }

        } else {
            view.center = CGPoint(x: 0, y: view.center.y)
            reset()
        }
    }

    func reset() {
        isActionShowing = false
        clipsToBounds = false
        isHideSwiping = false
        actionsView?.removeFromSuperview()
        actionsView = nil
    }

    @discardableResult
    func showActionsView() -> Bool {

//        guard let tableView = tableView else { return false }

//        originalLayoutMargins = super.layoutMargins

//        super.setHighlighted(false, animated: false)

//        let selectedIndexPaths = tableView.indexPathsForSelectedRows
//        selectedIndexPaths?.forEach { tableView.deselectRow(at: $0, animated: false) }

        self.actionsView?.removeFromSuperview()
        self.actionsView = nil


//        guard let indexPath = tableView.indexPath(for: self),
//            let source = tableView as? SwipeTableViewCellDelegate,
//            source.swipe_tableView(tableView, canEditRowAt: indexPath) else { return false }

//        let actions = source.swipe_tableView(tableView, editActionsOptionsForRowAt: indexPath)
        let deleteAction = SwipedAction(title: "删除") { (_) in

        }
        deleteAction.needConfirm = .custom(title: "确认删除")
        let unreadAction = SwipedAction(title: "标记未读") { (_) in

        }
        unreadAction.needConfirm = .custom(title: "确认删除")
        unreadAction.backgroundColor = .gray

        let actions = [unreadAction, deleteAction]
        let actionsView = ActionsView(actions: actions)
        actionsView.leftMoveWhenConfirm = { [weak self] in

            UIView.animate(withDuration: 0.15, animations: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.frame.origin.x = -actionsView.preferredWidth
            })
        }

        view.addSubview(actionsView)

        actionsView.translatesAutoresizingMaskIntoConstraints = false
        actionsView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        actionsView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        actionsView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true

        actionsView.leftAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        actionsView.setNeedsUpdateConstraints()

        self.actionsView = actionsView

        return true
    }

    var animator: SwipeAnimator?

    func animate(duration: Double = 0.7, toOffset offset: CGFloat, withInitialVelocity velocity: CGFloat = 0, isConfirming: Bool = false, fromHideAction: Bool = false, completion: ((Bool) -> Void)? = nil) {

        stopAnimatorIfNeeded()

        if isHideSwiping && !fromHideAction {
            isHideSwiping = false
        }
        layoutIfNeeded()

        let animator: SwipeAnimator = {
            if velocity > 0 {

                return UIViewSpringAnimator(duration: duration, damping: 1.0, initialVelocity: velocity)

            } else {

                return UIViewSpringAnimator(duration: duration, damping: 1.0)

            }
        }()

        animator.addAnimations({

            self.frame.origin = CGPoint(x: offset, y: self.frame.origin.y)

            if !isConfirming {
                self.actionsView?.setProgress(offset <= 0 ? 1 : 0)
            }

            self.layoutIfNeeded()
        })

        if let completion = completion {
            animator.addCompletion(completion: completion)
        }

        self.animator = animator

        animator.startAnimation()
    }

    func stopAnimatorIfNeeded() {
        if animator?.isRunning == true {
            animator?.stopAnimation(true)
        }
    }

}

extension TextureDemoTableViewCell: UIGestureRecognizerDelegate {

    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        let swipeCells = tableNode?.visibleNodes.flatMap({ $0 as? TextureDemoTableViewCell }).filter({ $0.isActionShowing || $0.isHideSwiping })

        if gestureRecognizer == panGestureRecognizer,
            let view = gestureRecognizer.view,
            let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer
        {
            if !isActionShowing {
                swipeCells?.forEach({ $0.hideSwipe(animated: true) })
            }
            let translation = gestureRecognizer.translation(in: view)
            return abs(translation.y) <= abs(translation.x)
        }

        if gestureRecognizer == tapGestureRecognizer {
            if isActionShowing {
                return true
            }
            if swipeCells?.count != 0 {
                swipeCells?.forEach({ $0.hideSwipe(animated: true) })
                return true
            }
            return false
        }

        return true
    }
}


