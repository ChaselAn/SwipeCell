//
//  PlusSwipableCellNode.swift
//  EditTableViewCell
//
//  Created by ancheng on 2018/3/30.
//  Copyright © 2018年 ancheng. All rights reserved.
//

import UIKit
import AsyncDisplayKit

open class PlusSwipableCellNode: ASCellNode {

    enum State {
        case showed
        case hid
        case hiding
        case showing
        case moving
    }

    enum Transition {
//        case panning
        case willPan
        case panned
        case tap
        case animate
        case hideToEdge
    }

    lazy var stateMachine: StateMachine<State, Transition> = {
        let stateMachine = StateMachine<State, Transition>()

//        stateMachine.add(state: .showed, entryOperation: {
//
//        })
        stateMachine.add(state: .hid, entryOperation: { [weak self] in
            self?.reset()
        })
//        stateMachine.add(state: .hiding, entryOperation: { [weak self] in
//
//        })

        stateMachine.add(transition: .willPan, fromState: .hid, toState: .moving)
        stateMachine.add(transition: .hideToEdge, fromState: .moving, toState: .hid)
        stateMachine.add(transition: .panned, fromState: .moving, toState: .hiding)
        stateMachine.add(transition: .panned, fromState: .moving, toState: .showing)
        stateMachine.add(transition: .animate, fromState: .hiding, toState: .hid)
        stateMachine.add(transition: .animate, fromState: .showing, toState: .showed)
        stateMachine.add(transition: .willPan, fromState: .showed, toState: .moving)
        stateMachine.add(transition: .tap, fromState: .showed, toState: .hiding)

//        stateMachine.add(state: .off) { [weak self] in
//            self?.statusBarStyle = .lightContent
//            self?.view.backgroundColor = .black
//            self?.promptLabel.textColor = .white
//            self?.promptLabel.text = "Tap to turn lights on"
//        }

        stateMachine.initialState = .hid
        return stateMachine
    }()

    public var scale: CGFloat = 0.75

    private var originalX: CGFloat = 0
    private weak var tableNode: ASTableNode?
    private var actionsView: ActionsView?

    private var isActionShowing = false
    private var isHideSwiping = false
    private var isPanning = false
    private var animator: SwipeAnimator?

    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(didPan))
        gesture.delegate = self
        return gesture
    }()

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        gesture.delegate = self
        return gesture
    }()

    public init(tableNode: ASTableNode) {
        self.tableNode = tableNode
        super.init()

        clipsToBounds = false

        view.backgroundColor = UIColor.green

        view.addGestureRecognizer(panGestureRecognizer)
        view.addGestureRecognizer(tapGestureRecognizer)

        tableNode.view.panGestureRecognizer.removeTarget(self, action: nil)
        tableNode.view.panGestureRecognizer.addTarget(self, action: #selector(tableViewDidPan))
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {

        return contains(point: point)
    }

    private func contains(point: CGPoint) -> Bool {
        return point.y > frame.minY && point.y < frame.maxY
    }

    deinit {
        tableNode?.view.panGestureRecognizer.removeTarget(self, action: nil)
    }

    @objc private func didPan(gesture: UIPanGestureRecognizer) {

        guard let target = gesture.view else { return }

        switch gesture.state {
        case .began:

//            isPanning = true
            stopAnimatorIfNeeded()

            originalX = frame.origin.x

            if stateMachine.currentState == .hid {
                if gesture.velocity(in: target).x > 0 { return }
//                isActionShowing = true
                showActionsView()
            }
            stateMachine.fire(transition: .willPan)

        case .changed:

            guard let actionsView = actionsView, let tableNode = tableNode else { return }

            let translationX = gesture.translation(in: target).x * scale
            var offsetX = originalX + translationX
            if offsetX > 0 {
                target.frame.origin.x = 0
            } else {
                if offsetX < -tableNode.bounds.width * 3 {
                    offsetX = -tableNode.bounds.width * 3
                }
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
            let translationX = gesture.translation(in: target).x * scale
            if originalX + translationX >= 0 {
                if stateMachine.currentState == .hiding {
                    stateMachine.fire(transition: .animate)
                }
                return
            }

            let offSetX = translationX < 0 ? -actionsView.preferredWidth : 0
            let velocity = gesture.velocity(in: target)

            let distance = -frame.origin.x
            let normalizedVelocity = velocity.x / distance

            animate(duration: 0.4, toOffset: offSetX, withInitialVelocity: normalizedVelocity * 0.4, isConfirming: actionsView.isConfirming) { [weak self] _ in
                guard let strongSelf = self else { return }
//                if strongSelf.isActionShowing && translationX >= 0 {
//                    strongSelf.reset()
//                }
                if strongSelf.stateMachine.currentState == .hiding, translationX >= 0 {
                    strongSelf.stateMachine.fire(transition: .animate)
                }

            }
        case .cancelled:
            isPanning = false
            hideSwipe(animated: false)
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

    public func hideSwipe(animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard !isPanning else { return }
        guard isActionShowing else { return }
        guard !isHideSwiping else { return }
        isHideSwiping = true
        isActionShowing = false
        if animated {
            animate(duration: 0.5, toOffset: 0, isConfirming: actionsView?.isConfirming == true, fromHideAction: true) { [weak self] complete in
                completion?(complete)
                self?.reset()
            }
        } else {
            self.frame.origin = CGPoint(x: 0, y: self.frame.origin.y)

            self.layoutIfNeeded()
            reset()
        }
    }

    private func reset() {
        isActionShowing = false
        clipsToBounds = false
        isHideSwiping = false
        actionsView?.removeFromSuperview()
        actionsView = nil
    }

    @discardableResult
    private func showActionsView() -> Bool {

        guard let tableNode = tableNode else { return false }

        super.isHighlighted = false

        let selectedIndexPaths = tableNode.indexPathsForSelectedRows
        selectedIndexPaths?.forEach { tableNode.deselectRow(at: $0, animated: false) }

        self.actionsView?.removeFromSuperview()
        self.actionsView = nil

        guard let indexPath = tableNode.indexPath(for: self),
            let source = tableNode.circle_swipeDelegate,
            source.swipe_tableNode(tableNode, canEditRowAt: indexPath) else { return false }

        let actions = source.swipe_tableNode(tableNode, editActionsOptionsForRowAt: indexPath)
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
        actionsView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 3).isActive = true
        actionsView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true

        actionsView.leftAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        actionsView.setNeedsUpdateConstraints()

        self.actionsView = actionsView

        return true
    }

    private func animate(duration: Double = 0.7, toOffset offset: CGFloat, withInitialVelocity velocity: CGFloat = 0, isConfirming: Bool = false, fromHideAction: Bool = false, completion: ((Bool) -> Void)? = nil) {

        stopAnimatorIfNeeded()

        if isHideSwiping && !fromHideAction {
            isHideSwiping = false
        }
        layoutIfNeeded()

        if offset == 0, frame.origin.x >= -30 {
            frame.origin.x = 0
            if !isConfirming {
                self.actionsView?.setProgress(offset <= 0 ? 1 : 0)
            }
            completion?(true)
            return
        }

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

    private func stopAnimatorIfNeeded() {
        if animator?.isRunning == true {
            animator?.stopAnimation(true)
        }
    }

}

extension PlusSwipableCellNode: UIGestureRecognizerDelegate {

    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        let swipeCells = tableNode?.visibleNodes.flatMap({ $0 as? SwipableCellNode }).filter({ $0.isActionShowing || $0.isHideSwiping })
        if gestureRecognizer == panGestureRecognizer,
            let view = gestureRecognizer.view,
            let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
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
