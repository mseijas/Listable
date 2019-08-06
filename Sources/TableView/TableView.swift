//
//  TableView.swift
//  CheckoutApplet
//
//  Created by Kyle Van Essen on 6/16/19.
//

import Foundation


public final class TableView : UIView
{
    //
    // MARK: Public Properties
    //
    
    public var configuration : Configuration {
        didSet {
            guard oldValue != self.configuration else {
                return
            }
            
            self.configuration.apply(to: self.tableView)
            self.tableView.reloadData()
        }
    }
    
    //
    // MARK: Setting Content
    //
    
    public var content : Content {
        get { return self.storage.content }
        set { self.set(content: newValue, animated: false) }
    }
    
    public func setContent(animated : Bool = false, _ block : ContentBuilder.Build)
    {
        self.set(content: ContentBuilder.build(with: block), animated: animated)
    }
    
    public func set(content new : Content, animated : Bool = false)
    {
        self.setSource(
            initial: StaticSource.State(),
            source: StaticSource(with: new),
            animated: animated
        )
    }
    
    @discardableResult
    public func setSource<Source:TableViewSource>(initial : Source.State, source : Source, animated : Bool = false) -> StateAccessor<Source.State>
    {
        self.sourcePresenter.discard()
        
        let sourcePresenter = TableView.SourcePresenter(initial: initial, source: source) { [weak self] in
            self?.reloadContent(animated: animated)
        }
        
        self.sourcePresenter = sourcePresenter
        
        self.reloadContent(animated: animated)
        
        return StateAccessor(get: {
            sourcePresenter.state
        }, set: {
            sourcePresenter.state = $0
        })
    }
    
    public func reloadContent(animated : Bool = false)
    {
        self.storage.content = self.sourcePresenter.reloadContent()
        
        self.updatePresentationState(for: .contentChanged(animated: animated))
    }
    
    //
    // MARK: Private Properties
    //
    
    private let storage : Storage
    private var sourcePresenter : TableViewSourcePresenter
    
    private let dataSource : DataSource
    private let delegate : Delegate
    
    private let tableView : UITableView
    
    private let cellMeasurementCache : ReusableViewCache
    private let headerMeasurementCache : ReusableViewCache
    private let footerMeasurementCache : ReusableViewCache
    
    // MARK: Initialization
    
    override public convenience init(frame: CGRect)
    {
        self.init(frame: frame, style: .plain)
    }
    
    public convenience init<Source:TableViewSource>(
        frame: CGRect = .zero,
        style : UITableView.Style = .plain,
        state : Source.State,
        source : Source
        )
    {
        self.init(frame: frame, style: style)
        
        self.setSource(initial: state, source: source)
    }
    
    public convenience init<State:Equatable>(
        frame: CGRect = .zero,
        style : UITableView.Style = .plain,
        state : State,
        _ builder : @escaping (SourceState<State>, inout TableView.ContentBuilder) -> ()
        )
    {
        self.init(frame: frame, style: style)
        
        self.setSource(initial: state, source: TableView.DynamicSource(with: builder))
    }
    
    public convenience init(
        frame: CGRect = .zero,
        style : UITableView.Style = .plain,
        _ builder : @escaping (inout TableView.ContentBuilder) -> ()
        )
    {
        self.init(frame: frame, style: style)
        
        self.setSource(initial: TableView.StaticSource.State(), source: TableView.StaticSource(with: builder))
    }
    
    public init(frame: CGRect = .zero, style : UITableView.Style = .plain)
    {
        self.storage = Storage()
        self.sourcePresenter = SourcePresenter(initial: StaticSource.State(), source: StaticSource())
        
        self.cellMeasurementCache = ReusableViewCache()
        self.headerMeasurementCache = ReusableViewCache()
        self.footerMeasurementCache = ReusableViewCache()
                
        self.configuration = Configuration()
        
        self.dataSource = DataSource()
        self.delegate = Delegate()
        
        self.tableView = UITableView(frame: frame, style: style)
        self.configuration.apply(to: self.tableView)
        
        self.tableView.dataSource = self.dataSource
        self.tableView.delegate = self.delegate
        
        super.init(frame: frame)
        
        self.storage.presentationState.tableView = self.tableView
        
        self.dataSource.tableView = self
        self.delegate.tableView = self
        
        self.tableView.frame = self.bounds
        self.addSubview(self.tableView)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: Public Methods
    
   public struct VisibleRow
    {
        public let indexPath : IndexPath
        public let row : TableViewRow
    }
    
    var visibleRows : [VisibleRow] {
        return self.visibleIndexPaths.map {
            VisibleRow(
                indexPath: $0,
                row: self.storage.presentationState.row(at: $0).anyModel
            )
        }
    }
    
    public struct VisibleSection
    {
        public let index : Int
        public let section : TableView.Section
    }
    
    public var visibleSections : [VisibleSection] {
        let sectionIndexes : [Int] = self.visibleRows.reduce(into: Set<Int>(), {
            $0.insert($1.indexPath.section)
        }).sorted(by: { $0 < $1 })
        
        return sectionIndexes.map {
            VisibleSection(
                index: $0,
                section: self.storage.presentationState.sections[$0].model
            )
        }
    }
    
    private var visibleIndexPaths : [IndexPath] {
        if let indexPaths = self.tableView.indexPathsForVisibleRows {
            return indexPaths
        } else {
            return []
        }
    }
    
    // MARK: UIView
    
    override public func layoutSubviews()
    {
        super.layoutSubviews()
        
        self.tableView.frame = self.bounds
    }
    
    //
    // MARK: Updating Content
    //
    
    private func updatePresentationState(for reason : Content.Slice.UpdateReason)
    {
        let indexPath = self.visibleIndexPaths.first
        
        switch reason {
        case .scrolledDown:
            let needsUpdate = self.tableView.isScrolledNearBottom() && self.storage.presentationState.containsAllRows == false
            
            if needsUpdate {
                self.updatePresentationStateWith(firstVisibleIndexPath: indexPath, for: reason)
            }
        case .contentChanged:
            self.updatePresentationStateWith(firstVisibleIndexPath: indexPath, for: reason)
            
        case .didEndDecelerating:
            self.updatePresentationStateWith(firstVisibleIndexPath: indexPath, for: reason)
            
        case .scrolledToTop:
            self.updatePresentationStateWith(firstVisibleIndexPath: .zero, for: reason)
        }
    }
    
    private func updatePresentationStateWith(firstVisibleIndexPath indexPath: IndexPath?, for reason : Content.Slice.UpdateReason)
    {
        let indexPath = indexPath ?? .zero
        
        let new = self.content.sliceTo(indexPath: indexPath, plus: Content.Slice.defaultSize)
        
        let diff = TableView.diffWith(old: self.storage.presentationState.sectionModels, new: new.content.sections)
        
        let updateData = {
            self.storage.presentationState.update(with: diff, slice: new)
        }
        
        if reason.diffsChanges {
            self.tableView.update(with: diff, animated: reason.animated, onBeginUpdates: updateData)
        } else {
            updateData()
            self.tableView.reloadData()
        }
    }
    
    private static func diffWith(old : [Section], new : [Section]) -> SectionedDiff<Section, TableViewRow>
    {
        return SectionedDiff(
            old: old,
            new: new,
            configuration: SectionedDiff.Configuration(
                section: .init(
                    identifier: { $0.identifier },
                    rows: { $0.rows },
                    updated: { $0.updatedComparedTo(old: $1) },
                    movedHint: { $0.movedComparedTo(old: $1) }
                ),
                row: .init(
                    identifier: { $0.identifier },
                    updated: { $0.updatedComparedTo(old: $1) },
                    movedHint: { $0.movedComparedTo(old: $1) }
                )
            )
        )
    }
}

public protocol TableViewPresentationStateRow : TableViewPresentationStateRow_Internal
{
}

public protocol TableViewPresentationStateRow_Internal : AnyObject
{
    var anyIdentifier : AnyIdentifier { get }
    var anyModel : TableViewRow { get }
    
    func update(with old : TableViewRow, new : TableViewRow)
    
    func willDisplay(with cell : UITableViewCell)
    func didEndDisplay()
}


fileprivate extension TableView
{
    final class Storage {
        let presentationState : PresentationState = PresentationState()
        
        var content : Content = Content()
        
        func remove(row rowToRemove : TableViewPresentationStateRow) -> IndexPath?
        {
            if let indexPath = self.presentationState.remove(row: rowToRemove) {
                self.content.remove(at: indexPath)
                return indexPath
            } else {
                return nil
            }
        }
    }
    
    final class DataSource : NSObject, UITableViewDataSource
    {
        unowned var tableView : TableView!
        
        var presentationState : TableView.PresentationState {
            return self.tableView.storage.presentationState
        }
        
        func numberOfSections(in tableView: UITableView) -> Int
        {
            return self.presentationState.sections.count
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
        {
            let section = self.presentationState.sections[section]
            
            return section.rows.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
        {
            let row = self.presentationState.row(at: indexPath)
            
            return row.anyModel.dequeueCell(in: tableView)
        }
        
        // MARK: Moving
        
        func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool
        {
            // TODO
            
            return false
        }
        
        func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath)
        {
            // TODO
            
            fatalError()
        }
    }
    
    final class Delegate : NSObject, UITableViewDelegate
    {
        unowned var tableView : TableView!
        
        var presentationState : TableView.PresentationState {
            return self.tableView.storage.presentationState
        }
        
        // MARK: Views & Sizing
        
        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
        {
            let section = self.presentationState.sections[section]

            guard let header = section.model.header else {
                return nil
            }
            
            return header.dequeueView(in: tableView)
        }
        
        func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
        {
            let section = self.presentationState.sections[section]

            guard let footer = section.model.footer else {
                return nil
            }
            
            return footer.dequeueView(in: tableView)
        }
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
        {
            let row = self.presentationState.row(at: indexPath)
            
            return row.anyModel.heightWith(
                width: tableView.bounds.size.width,
                default: tableView.rowHeight,
                measurementCache: self.tableView.cellMeasurementCache
            )
        }
        
        func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
        {
            let section = self.presentationState.sections[section]

            guard let header = section.model.header else {
                return 0.0
            }
            
            return header.heightWith(
                width: tableView.bounds.size.width,
                default: tableView.sectionHeaderHeight,
                measurementCache: self.tableView.headerMeasurementCache
            )
        }
        
        func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
        {
            let section = self.presentationState.sections[section]

            guard let footer = section.model.footer else {
                return 0.0
            }
            
            return footer.heightWith(
                width: tableView.bounds.size.width,
                default: tableView.sectionFooterHeight,
                measurementCache: self.tableView.footerMeasurementCache
            )
        }
        
        // MARK: Selection
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
        {
            let row = self.presentationState.row(at: indexPath)
            
            row.anyModel.performOnTap()
            
            self.tableView.tableView.deselectRow(at: indexPath, animated: true)
        }
        
        // MARK: Display
        
        var displayedRows : [ObjectIdentifier:TableViewPresentationStateRow] = [:]
        
        func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
        {
            let row = self.presentationState.row(at: indexPath)
            
            self.displayedRows[ObjectIdentifier(cell)] = row
            
            row.willDisplay(with: cell)
        }
        
        func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath)
        {
            guard let row = self.displayedRows.removeValue(forKey: ObjectIdentifier(cell)) else {
                return
            }
            
            row.didEndDisplay()
        }
        
        // MARK: Moving
        
        func tableView(
            _ tableView: UITableView,
            targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
            toProposedIndexPath proposedDestinationIndexPath: IndexPath
            ) -> IndexPath
        {
            // TODO
            
            return proposedDestinationIndexPath
        }
        
        func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle
        {
            return .none
        }
        
        // MARK: Row Actions
        
        func performedActionFor(row : TableViewPresentationStateRow, style : TableView.SwipeAction.Style)
        {
            if style.deletesRow {
                if let indexPath = self.tableView.storage.remove(row: row) {
                    UIView.performWithoutAnimation {
                        self.tableView.tableView.deleteRows(at: [indexPath], with: .none)
                    }
                }
            }
        }
        
        func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
        {
            // Note: Only used before iOS 11.
            // We must also manually animate out the removal.
            
            let row = self.presentationState.row(at: indexPath)
            
            return row.anyModel.trailingTableViewRowActions { [weak self] style in
                self?.performedActionFor(row: row, style: style)
            }
        }
        
        @available(iOS 11.0, *)
        func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
        {
            let row = self.presentationState.row(at: indexPath)

            return row.anyModel.leadingSwipeActionsConfiguration { [weak self] style in
                self?.performedActionFor(row: row, style: style)
            }
        }
        
        @available(iOS 11.0, *)
        func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
        {
            let row = self.presentationState.row(at: indexPath)
            
            return row.anyModel.trailingSwipeActionsConfiguration { [weak self] style in
                self?.performedActionFor(row: row, style: style)
            }
        }
        
        // MARK: UIScrollViewDelegate
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
        {
            self.tableView.updatePresentationState(for: .didEndDecelerating)
        }
        
        func scrollViewDidScrollToTop(_ scrollView: UIScrollView)
        {
            self.tableView.updatePresentationState(for: .scrolledToTop)
        }
        
        var lastPosition : CGFloat = 0.0
        
        func scrollViewDidScroll(_ scrollView: UIScrollView)
        {
            guard scrollView.bounds.size.height > 0 else { return }
            
            let scrollingDown = self.lastPosition < scrollView.contentOffset.y
            
            self.lastPosition = scrollView.contentOffset.y
            
            if scrollingDown {
                self.tableView.updatePresentationState(for: .scrolledDown)
            }
        }
    }
}


fileprivate extension IndexPath
{
    static var zero : IndexPath {
        return IndexPath(row: 0, section: 0)
    }
}


fileprivate extension UITableView
{
    func isScrolledNearBottom() -> Bool
    {
        let viewHeight = self.bounds.size.height
        
        // We are within one half view height from the bottom of the content.
        return self.contentOffset.y + (viewHeight * 1.5) > self.contentSize.height
    }
    
    func update(with diff : SectionedDiff<TableView.Section,TableViewRow>, animated: Bool, onBeginUpdates : () -> ())
    {
        self.beginUpdates()
        onBeginUpdates()
        
        let animation : UITableView.RowAnimation = animated ? .fade : .none
        
        // Inserted & Removed Sections
        
        let removedSectionIndexes = IndexSet(diff.changes.removed.map { $0.oldIndex })
        let addedSectionIndexes = IndexSet(diff.changes.added.map { $0.newIndex })
        
        self.deleteSections(removedSectionIndexes, with: animation)
        self.insertSections(addedSectionIndexes, with: animation)
        
        // Updated Sections
        
        for section in diff.changes.updated {
            if let view = self.headerView(forSection: section.oldIndex) {
                view.performTransition(animated: animated) {
                    section.newValue.header?.applyTo(headerFooterView: view, reason: .wasUpdated)
                }
            }
            
            if let view = self.footerView(forSection: section.oldIndex) {
                view.performTransition(animated: animated) {
                    section.newValue.footer?.applyTo(headerFooterView: view, reason: .wasUpdated)
                }
            }
        }
        
        // Moved Sections
        
        // TODO: Do I need to also handle removes and deletions inside the moved sections?
        
        diff.changes.moved.forEach {
            self.moveSection($0.oldIndex, toSection: $0.newIndex)
        }
        
        // Updated Rows
        
        // TODO: Need to maintain bindings across updated rows
        
        for section in diff.changes.updated {
            
            let indexPaths = section.rowChanges.updated.map { IndexPath(row: $0.oldIndex, section: section.oldIndex) }
            self.reloadRows(at: indexPaths, with: animation)
            
            // Reloaded Rows
            
            // TODO
            
            // Reapplied Rows
            
            // TODO
        }
        
        for section in diff.changes.noChange {
            let indexPaths = section.rowChanges.updated.map { IndexPath(row: $0.oldIndex, section: section.oldIndex) }
            self.reloadRows(at: indexPaths, with: animation)
        }
        
        // Deleted Rows
        
        for section in diff.changes.updated {
            let indexPaths = section.rowChanges.removed.map { IndexPath(row: $0.oldIndex, section: section.oldIndex) }
            self.deleteRows(at: indexPaths, with: animation)
        }
        
        for section in diff.changes.noChange {
            let indexPaths = section.rowChanges.removed.map { IndexPath(row: $0.oldIndex, section: section.oldIndex) }
            self.deleteRows(at: indexPaths, with: animation)
        }
        
        // Inserted Rows
        
        for section in diff.changes.updated {
            let indexPaths = section.rowChanges.added.map { IndexPath(row: $0.newIndex, section: section.newIndex) }
            self.insertRows(at: indexPaths, with: animation)
        }
        
        for section in diff.changes.noChange {
            let indexPaths = section.rowChanges.added.map { IndexPath(row: $0.newIndex, section: section.newIndex) }
            self.insertRows(at: indexPaths, with: animation)
        }
        
        // Moved Rows
        
        for section in diff.changes.updated {
            section.rowChanges.moved.forEach {
                self.moveRow(
                    at: IndexPath(row: $0.oldIndex, section: section.oldIndex),
                    to: IndexPath(row: $0.newIndex, section: section.newIndex)
                )
            }
        }
        
        for section in diff.changes.noChange {
            section.rowChanges.moved.forEach {
                self.moveRow(
                    at: IndexPath(row: $0.oldIndex, section: section.oldIndex),
                    to: IndexPath(row: $0.newIndex, section: section.newIndex)
                )
            }
        }
        
        self.endUpdates()
    }
}

fileprivate extension UIView
{
    func performTransition(animated : Bool, _ changes : @escaping () -> ())
    {
        if animated {
            UIView.transition(with: self, duration: 0.2, options: [.transitionCrossDissolve], animations: changes, completion: nil)
        } else {
            changes()
        }
    }
}
