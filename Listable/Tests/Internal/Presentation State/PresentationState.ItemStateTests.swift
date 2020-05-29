//
//  PresentationState.ItemStateTests.swift
//  Listable-Unit-Tests
//
//  Created by Kyle Van Essen on 5/22/20.
//

import XCTest
@testable import Listable


class PresentationState_ItemStateTests : XCTestCase
{
    func test_init()
    {
        let coordinatorDelegate = ItemContentCoordinatorDelegateMock()
        
        let dependencies = ItemStateDependencies(
            reorderingDelegate: ReorderingActionsDelegateMock(),
            coordinatorDelegate: coordinatorDelegate
        )
        
        let initial = Item(TestContent(value: "initial"))
        
        let state = PresentationState.ItemState(with: initial, dependencies: dependencies)
        
        // Updates within init of the coordinator should not trigger callbacks.
        
        XCTAssertEqual(coordinatorDelegate.coordinatorUpdated_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.wasCreated_calls.count, 1)
        
        XCTAssertEqual(state.model.content.updates, [
            "update within coordinator init"
        ])
        
        // Updates outside of init should trigger coordinator updates.
        
        state.coordination.coordinator.triggerUpdate(with: "first update")
        
        XCTAssertEqual(coordinatorDelegate.coordinatorUpdated_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.wasCreated_calls.count, 1)
        
        XCTAssertEqual(state.model.content.updates, [
            "update within coordinator init",
            "first update"
        ])
                
        state.coordination.coordinator.triggerUpdate(with: "second update")
        
        XCTAssertEqual(coordinatorDelegate.coordinatorUpdated_calls.count, 2)
        XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.wasCreated_calls.count, 1)
        
        XCTAssertEqual(state.model.content.updates, [
            "update within coordinator init",
            "first update",
            "second update"
        ])
    }
    
    func test_setNew()
    {
        self.testcase("Only update isSelected if the selectionStyle changes") {
            let dependencies = ItemStateDependencies(
                reorderingDelegate: ReorderingActionsDelegateMock(),
                coordinatorDelegate: ItemContentCoordinatorDelegateMock()
            )
                
            let initial = Item(
                TestContent(value: "initial"),
                selectionStyle: .selectable(isSelected: false)
            )
            
            let state = PresentationState.ItemState(with: initial, dependencies: dependencies)
            
            // Should use the initial isSelected value off of the item.
            
            XCTAssertEqual(state.storage.state.isSelected, false)
            
            // Should not override the live isSelected state if updating with the same selectionStyle.
            
            state.storage.state.isSelected = true
            
            state.setNew(item: initial, reason: .updateFromList)
            
            XCTAssertEqual(state.storage.state.isSelected, true)
            
            // Should update isSelected if the selectionStyle changed.
            
            state.storage.state.isSelected = false
            
            let updated = Item(
                TestContent(value: "updated"),
                selectionStyle: .selectable(isSelected: true)
            )
                        
            state.setNew(item: updated, reason: .updateFromList)
            
            XCTAssertEqual(state.storage.state.isSelected, true)
        }
        
        self.testcase("Testing Different ItemUpdateReasons") {
            let dependencies = ItemStateDependencies(
                reorderingDelegate: ReorderingActionsDelegateMock(),
                coordinatorDelegate: ItemContentCoordinatorDelegateMock()
            )
                
            let initial = Item(
                TestContent(value: "initial"),
                selectionStyle: .selectable(isSelected: false)
            )
            
            let updated = Item(
                TestContent(value: "updated"),
                selectionStyle: .selectable(isSelected: true)
            )
        
            for reason in PresentationState.ItemUpdateReason.allCases {
                switch reason {
                case .move:
                    let state = PresentationState.ItemState(with: initial, dependencies: dependencies)
                    
                    XCTAssertEqual(state.model.content.value, "initial")
                    XCTAssertEqual(state.coordination.info.original.content.value, "initial")
                    XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 0)
                    XCTAssertEqual(state.storage.state.isSelected, false)
                    XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 0)

                    state.setNew(item: updated, reason: .move)
                    
                    XCTAssertEqual(state.model.content.value, "updated")
                    XCTAssertEqual(state.coordination.info.original.content.value, "updated")
                    XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 1)
                    XCTAssertEqual(state.storage.state.isSelected, true)
                    XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 1)
                    
                case .updateFromList:
                    let state = PresentationState.ItemState(with: initial, dependencies: dependencies)
                    
                    XCTAssertEqual(state.model.content.value, "initial")
                    XCTAssertEqual(state.coordination.info.original.content.value, "initial")
                    XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 0)
                    XCTAssertEqual(state.storage.state.isSelected, false)
                    XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 0)

                    state.setNew(item: updated, reason: .updateFromList)
                    
                    XCTAssertEqual(state.model.content.value, "updated")
                    XCTAssertEqual(state.coordination.info.original.content.value, "updated")
                    XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 1)
                    XCTAssertEqual(state.storage.state.isSelected, true)
                    XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 1)
                    
                case .updateFromItemCoordinator:
                    let state = PresentationState.ItemState(with: initial, dependencies: dependencies)
                    
                    XCTAssertEqual(state.model.content.value, "initial")
                    XCTAssertEqual(state.coordination.info.original.content.value, "initial")
                    XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 0)
                    XCTAssertEqual(state.storage.state.isSelected, false)
                    XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 0)

                    state.setNew(item: updated, reason: .updateFromItemCoordinator)
                    
                    XCTAssertEqual(state.model.content.value, "updated")
                    XCTAssertEqual(state.coordination.info.original.content.value, "initial")
                    XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 0)
                    XCTAssertEqual(state.storage.state.isSelected, true)
                    XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 1)
                    
                case .noChange:
                    let state = PresentationState.ItemState(with: initial, dependencies: dependencies)
                    
                    XCTAssertEqual(state.model.content.value, "initial")
                    XCTAssertEqual(state.coordination.info.original.content.value, "initial")
                    XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 0)
                    XCTAssertEqual(state.storage.state.isSelected, false)
                    XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 0)

                    state.setNew(item: updated, reason: .noChange)
                    
                    XCTAssertEqual(state.model.content.value, "updated")
                    XCTAssertEqual(state.coordination.info.original.content.value, "initial")
                    XCTAssertEqual(state.coordination.coordinator.wasUpdated_calls.count, 0)
                    XCTAssertEqual(state.storage.state.isSelected, true)
                    XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 1)
                }
            }
        }
    }
    
    func test_updateCoordinatorWithStateChange()
    {
        let dependencies = ItemStateDependencies(
            reorderingDelegate: ReorderingActionsDelegateMock(),
            coordinatorDelegate: ItemContentCoordinatorDelegateMock()
        )
        
        let item = Item(TestContent(value: "initial"))
        
        let state = PresentationState.ItemState(with: item, dependencies: dependencies)
        
        // Was Selected / Deselected
        
        XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.wasDeselected_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.willDisplay_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.didEndDisplay_calls.count, 0)
        
        state.updateCoordinatorWithStateChange(
            old: .init(
                isSelected: false,
                visibleCell: nil
            ), new: .init(
                isSelected: true,
                visibleCell: nil
            )
        )
        
        XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.wasDeselected_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.willDisplay_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.didEndDisplay_calls.count, 0)
        
        state.updateCoordinatorWithStateChange(
            old: .init(
                isSelected: true,
                visibleCell: nil
            ), new: .init(
                isSelected: false,
                visibleCell: nil
            )
        )
        
        XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.wasDeselected_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.willDisplay_calls.count, 0)
        XCTAssertEqual(state.coordination.coordinator.didEndDisplay_calls.count, 0)
        
        // Visible Cells
        
        state.updateCoordinatorWithStateChange(
            old: .init(
                isSelected: false,
                visibleCell: nil
            ), new: .init(
                isSelected: false,
                visibleCell: ItemCell()
            )
        )
        
        XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.wasDeselected_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.willDisplay_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.didEndDisplay_calls.count, 0)
        
        state.updateCoordinatorWithStateChange(
            old: .init(
                isSelected: false,
                visibleCell: ItemCell()
            ), new: .init(
                isSelected: false,
                visibleCell: nil
            )
        )
        
        XCTAssertEqual(state.coordination.coordinator.wasSelected_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.wasDeselected_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.willDisplay_calls.count, 1)
        XCTAssertEqual(state.coordination.coordinator.didEndDisplay_calls.count, 1)
    }
}


class PresentationState_ItemState_StorageTests : XCTestCase
{
    func test_init()
    {
        let item = Item(TestContent(value: "initial"), selectionStyle: .selectable(isSelected: true))
        
        let storage = PresentationState.ItemState.Storage(item)
        
        XCTAssertEqual(storage.state.isSelected, true)
        XCTAssertEqual(storage.state.visibleCell, nil)
    }
}


fileprivate struct TestContent : ItemContent, Equatable
{
    typealias ContentView = UIView
    
    var value : String
    var updates : [String] = []
    
    var identifier: Identifier<TestContent> = .init("")
    
    func apply(to views: ItemContentViews<TestContent>, for reason: ApplyReason, with info: ApplyItemContentInfo) {}
    
    static func createReusableContentView(frame: CGRect) -> UIView {
        UIView(frame: frame)
    }
    
    func makeCoordinator(actions: CoordinatorActions, info: CoordinatorInfo) -> Coordinator
    {
        Coordinator(actions: actions, info: info)
    }
    
    final class Coordinator : ItemContentCoordinator
    {
        init(actions : TestContent.CoordinatorActions, info : TestContent.CoordinatorInfo)
        {
            self.actions = actions
            self.info = info
            
            self.triggerUpdate(with: "update within coordinator init")
        }
        
        func triggerUpdate(with newContent : String)
        {
            self.actions.update {
                $0.content.updates.append(newContent)
            }
        }
        
        // MARK: ItemElementCoordinator
        
        typealias ItemContentType = TestContent
        
        var actions: CoordinatorActions
        var info: CoordinatorInfo
                
        // MARK: ItemElementCoordinator - Instance Lifecycle
        
        var wasCreated_calls: [Void] = [Void]()
        
        func wasCreated()
        {
            self.wasCreated_calls.append(())
        }
        
        var wasUpdated_calls = [(old : Item<ItemContentType>, new : Item<ItemContentType>)]()
        
        func wasUpdated(old : Item<ItemContentType>, new : Item<ItemContentType>)
        {
            self.wasUpdated_calls.append((old, new))
        }
        
        var wasRemoved_calls: [Void] = [Void]()
        
        func wasRemoved()
        {
            self.wasRemoved_calls.append(())
        }
        
        // MARK: ItemElementCoordinator - Visibility & View Lifecycle
        
        typealias View = ItemContentType.ContentView
        
        var view_didSet_calls = [View?]()
        
        var view : View? {
            didSet {
                self.view_didSet_calls.append(self.view)
            }
        }
        
        var willDisplay_calls = [View]()

        func willDisplay(with view : View)
        {
            self.willDisplay_calls.append(view)
        }
        
        var didEndDisplay_calls = [View]()

        func didEndDisplay(with view : View)
        {
            self.didEndDisplay_calls.append(view)
        }
        
        // MARK: ItemElementCoordinator - Selection & Highlight Lifecycle
        
        var wasSelected_calls: [Void] = [Void]()

        
        func wasSelected()
        {
            self.wasSelected_calls.append(())
        }
        
        var wasDeselected_calls: [Void] = [Void]()
        
        func wasDeselected()
        {
            self.wasDeselected_calls.append(())
        }
    }
}


fileprivate class ItemContentCoordinatorDelegateMock : ItemContentCoordinatorDelegate
{
    var coordinatorUpdated_calls = [AnyItem]()
    
    func coordinatorUpdated(for item: AnyItem, animated : Bool)
    {
        self.coordinatorUpdated_calls.append(item)
    }
}


fileprivate class ReorderingActionsDelegateMock : ReorderingActionsDelegate
{
    func beginInteractiveMovementFor(item: AnyPresentationItemState) -> Bool { true }
    
    func updateInteractiveMovementTargetPosition(with recognizer: UIPanGestureRecognizer) {}
    
    func endInteractiveMovement() {}
    
    func cancelInteractiveMovement() {}
}
