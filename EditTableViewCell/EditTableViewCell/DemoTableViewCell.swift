//
//  DemoTableViewCell.swift
//  EditTableViewCell
//
//  Created by ancheng on 2018/3/26.
//  Copyright © 2018年 ancheng. All rights reserved.
//

import UIKit

class DemoTableViewCell: UITableViewCell {

    private var originalX: CGFloat = 0
    private weak var tableView: UITableView?
    private var originalLayoutMargins: UIEdgeInsets = .zero
    private var actionsView: ActionsView?

    private(set) var isActionShowing = false

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

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        clipsToBounds = false

        addGestureRecognizer(panGestureRecognizer)
        addGestureRecognizer(tapGestureRecognizer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func didMoveToSuperview() {
        super.didMoveToSuperview()

        var view: UIView = self
        while let superview = view.superview {
            view = superview

            if let tableView = view as? UITableView {
                self.tableView = tableView

                tableView.panGestureRecognizer.removeTarget(self, action: nil)
                tableView.panGestureRecognizer.addTarget(self, action: #selector(tableViewDidPan))
                return
            }
        }
    }

    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let superview = superview else { return false }

        let point = convert(point, to: superview)

        return contains(point: point)
    }

    func contains(point: CGPoint) -> Bool {
        return point.y > frame.minY && point.y < frame.maxY
    }

    deinit {
        tableView?.panGestureRecognizer.removeTarget(self, action: nil)
    }

    @objc private func didPan(gesture: UIPanGestureRecognizer) {

        guard let target = gesture.view else { return }

        switch gesture.state {
        case .began:
            stopAnimatorIfNeeded()

            originalX = frame.origin.x

            if !isActionShowing {
                if gesture.velocity(in: target).x > 0 { return }
                showActionsView()
                isActionShowing = true
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

    @objc private func tableViewDidPan(gesture: UIPanGestureRecognizer) {}

    private func hideSwipe(animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard isActionShowing else { return }

        if animated {
            animate(toOffset: 0, isConfirming: actionsView?.isConfirming == true) { [weak self] complete in
                completion?(complete)
                self?.reset()
            }
        } else {
            center = CGPoint(x: 0, y: self.center.y)
            reset()
        }
    }

    func reset() {
        isActionShowing = false
        clipsToBounds = false
        actionsView?.removeFromSuperview()
        actionsView = nil
    }

    @discardableResult
    func showActionsView() -> Bool {

        guard let tableView = tableView else { return false }

        originalLayoutMargins = super.layoutMargins

        super.setHighlighted(false, animated: false)

        let selectedIndexPaths = tableView.indexPathsForSelectedRows
        selectedIndexPaths?.forEach { tableView.deselectRow(at: $0, animated: false) }

        self.actionsView?.removeFromSuperview()
        self.actionsView = nil


        guard let indexPath = tableView.indexPath(for: self),
            let source = tableView as? SwipeTableViewCellDelegate,
            source.swipe_tableView(tableView, canEditRowAt: indexPath) else { return false }

        let actions = source.swipe_tableView(tableView, editActionsOptionsForRowAt: indexPath)
        let actionsView = ActionsView(actions: actions)
        actionsView.leftMoveWhenConfirm = { [weak self] in

            UIView.animate(withDuration: 0.15, animations: { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.frame.origin.x = -actionsView.preferredWidth
            })
        }

        addSubview(actionsView)

        actionsView.translatesAutoresizingMaskIntoConstraints = false
        actionsView.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        actionsView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        actionsView.topAnchor.constraint(equalTo: topAnchor).isActive = true

        actionsView.leftAnchor.constraint(equalTo: rightAnchor).isActive = true

        actionsView.setNeedsUpdateConstraints()

        self.actionsView = actionsView

        return true
    }

    var animator: SwipeAnimator?

    func animate(duration: Double = 0.7, toOffset offset: CGFloat, withInitialVelocity velocity: CGFloat = 0, isConfirming: Bool = false, completion: ((Bool) -> Void)? = nil) {
        stopAnimatorIfNeeded()

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

class ActionsView: UIView {

    private var actionViews: [ActionView] = []

    var preferredWidth: CGFloat = 0
    var isConfirming = false

    var leftMoveWhenConfirm: (() -> Void)?

    init(actions: [SwipedAction]) {

        super.init(frame: .zero)

        clipsToBounds = true

        for action in actions {
            let actionView = ActionView(action: action)

            addSubview(actionView)

            actionViews.append(actionView)
            actionView.toX = preferredWidth
            preferredWidth += actionView.widthConst
        }
    }

    func setProgress(_ progress: CGFloat) {
        for actionView in actionViews {
            actionView.frame.origin.x = actionView.toX * progress
            actionView.frame.size = bounds.size
            actionView.beConfirm = { [weak self] in
                self?.isConfirming = true
            }
            actionView.leftMoveWhenConfirm = leftMoveWhenConfirm
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
}

class ActionView: UIView {

    let margin: CGFloat = 10

    var beConfirm: (() -> Void)?
    var leftMoveWhenConfirm: (() -> Void)?

    var widthConst: CGFloat {
        return action.preferredWidth ?? (action.title.getWidth(withFont: action.titleFont) + 2 * margin)
    }

    var toX: CGFloat = 0

    private var titleLabel = UILabel()
    private let action: SwipedAction
    private var widthConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?

    init(action: SwipedAction) {
        self.action = action
        super.init(frame: CGRect.zero)

        backgroundColor = action.backgroundColor

        titleLabel.textColor = action.titleColor
        titleLabel.textAlignment = .center
        titleLabel.text = action.title
        titleLabel.numberOfLines = 0
        titleLabel.font = action.titleFont

        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        leadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin)
        leadingConstraint?.isActive = true
        titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        widthConstraint = titleLabel.widthAnchor.constraint(equalToConstant: widthConst - 2 * margin)
        widthConstraint?.isActive = true

        titleLabel.isUserInteractionEnabled = false

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func didTap() {
        if case .custom(let title) = action.needConfirm {

            beConfirm?()
            titleLabel.text = title
            superview?.bringSubview(toFront: self)

            UIView.animate(withDuration: 0.15, animations: { [weak self] in
                guard let strongSelf = self else { return }
                self?.frame.origin.x = 0
                self?.widthConstraint?.constant = title.getWidth(withFont: strongSelf.action.titleFont)
                if let superView = strongSelf.superview as? ActionsView {
                    let deleteWidth = title.getWidth(withFont: strongSelf.action.titleFont) + 2 * strongSelf.margin
                    if superView.preferredWidth < deleteWidth {
                        superView.preferredWidth = deleteWidth
                        strongSelf.leftMoveWhenConfirm?()
                    } else {
                        strongSelf.leadingConstraint?.constant = (superView.preferredWidth - title.getWidth(withFont: strongSelf.action.titleFont)) / 2
                    }
                }
                strongSelf.layoutIfNeeded()
            })
        }
    }

}

extension DemoTableViewCell {

    override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        let swipeCells = tableView?.visibleCells.flatMap({ ($0 as? DemoTableViewCell) }).filter({ $0.isActionShowing })

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

