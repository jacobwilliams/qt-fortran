!> Drag and drop on windows (QtfEventFilter) and item views with
!> Fortran-backed models, through synthetic events. Run headless with
!> QT_QPA_PLATFORM=offscreen.
module test_drag_drop_slots

    use qt
    implicit none

    !> What the slots saw.
    type :: seen_t
        integer :: enters = 0, moves = 0, leaves = 0, drops = 0, drags = 0
        logical :: accept = .true.
        logical :: refuse_drop = .false.
        character(len=:), allocatable :: text
        integer, allocatable :: items(:)
        integer :: row = -9, column = -9, parent_node = -9, node = -9, action = -9
        logical :: on_item = .false., internal = .false., has_items = .false.
    end type seen_t

contains

    !> Count drag enters; accept them if `accept` is set.
    subroutine on_enter(event, data)
        type(QDropEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (seen_t)
            data%enters = data%enters + 1
            if (data%accept) call event%acceptProposedAction()
        end select
    end subroutine on_enter

    !> Count drag moves (accepted).
    subroutine on_move(event, data)
        type(QDropEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (seen_t)
            data%moves = data%moves + 1
            call event%acceptProposedAction()
        end select
    end subroutine on_move

    !> Count drag leaves.
    subroutine on_leave(data)
        class(*), intent(inout), optional :: data
        select type (data)
        type is (seen_t)
            data%leaves = data%leaves + 1
        end select
    end subroutine on_leave

    !> Record a drop on the window.
    subroutine on_window_drop(event, data)
        type(QDropEvent), intent(in) :: event
        class(*), intent(inout), optional :: data
        select type (data)
        type is (seen_t)
            data%drops = data%drops + 1
            data%text = event%text()
            data%has_items = event%hasItems()
            data%items = event%items()
            call event%acceptProposedAction()
        end select
    end subroutine on_window_drop

    !> A model's drag: add a format of our own.
    subroutine on_drag_started(mime, data)
        type(QMimeData), intent(in) :: mime
        class(*), intent(inout), optional :: data
        select type (data)
        type is (seen_t)
            data%drags = data%drags + 1
            call mime%setData('application/x-qtf-test', 'extra')
        end select
    end subroutine on_drag_started

    !> A model's drop: record where it went.
    subroutine on_model_drop(drop, data)
        type(QtfModelDrop), intent(in) :: drop
        class(*), intent(inout), optional :: data
        select type (data)
        type is (seen_t)
            data%drops = data%drops + 1
            data%text = drop%text()
            data%items = drop%items()
            data%has_items = drop%hasItems()
            data%internal = drop%isInternal()
            data%row = drop%row()
            data%column = drop%column()
            data%parent_node = drop%parentNode()
            data%node = drop%node()
            data%on_item = drop%onItem()
            data%action = drop%action()
            if (data%refuse_drop) call drop%ignore()
        end select
    end subroutine on_model_drop

    !> List cells: 'a', 'b', ...
    subroutine on_list_data(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        call request%setText(achar(iachar('a') + row))
    end subroutine on_list_data

    !> Tree and table cells: 'n<key>c<column>'.
    subroutine on_cell_data(key, column, request, data)
        integer, intent(in) :: key, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        character(len=16) :: s
        write(s, '(A,I0,A,I0)') 'n', key, 'c', column
        call request%setText(trim(s))
    end subroutine on_cell_data

end module test_drag_drop_slots

!> Tests drag and drop on windows and item views.
program test_drag_drop

    use qt
    use testing
    use test_drag_drop_slots
    use iso_c_binding, only: c_double
    implicit none

    type(QApplication) :: app
    type(QWindow) :: win
    type(QtfEventFilter) :: filter
    type(QMimeData) :: mime, mime2
    type(QDropEvent) :: ev
    type(QEvent) :: leave
    type(QtfListModel) :: list
    type(QtfListModel) :: other
    type(QtfTreeModel) :: tree
    type(QtfTableModel) :: table
    type(QListView) :: list_view
    type(QTreeView) :: tree_view
    type(QTableView) :: table_view
    type(QSortFilterProxyModel) :: proxy
    type(seen_t), target :: w, m
    logical :: sent
    integer, allocatable :: items(:)

    app = QApplication()

    ! --- a QWindow through a QtfEventFilter (e.g. a window an external engine renders into)
    win = QWindow()
    filter = QtfEventFilter(win)
    call filter%dragEnterEvent%connect(on_enter, w)
    call filter%dragMoveEvent%connect(on_move, w)
    call filter%dragLeaveEvent%connect(on_leave, w)
    call filter%dropEvent%connect(on_window_drop, w)
    mime = QMimeData()
    call mime%setText('to the window')
    ev = QDropEvent(QEvent_DragEnter, 4.0_c_double, 4.0_c_double, mime)
    sent = QCoreApplication_sendEvent(win, ev)
    call check(w%enters == 1 .and. ev%isAccepted(), 'QtfEventFilter%dragEnterEvent accepted')
    call ev%delete()
    ev = QDropEvent(QEvent_DragMove, 5.0_c_double, 5.0_c_double, mime)
    sent = QCoreApplication_sendEvent(win, ev)
    call check(w%moves == 1 .and. ev%isAccepted(), 'QtfEventFilter%dragMoveEvent')
    call ev%delete()
    ev = QDropEvent(QEvent_Drop, 5.0_c_double, 5.0_c_double, mime)
    sent = QCoreApplication_sendEvent(win, ev)
    call check(w%drops == 1 .and. w%text == 'to the window' .and. ev%isAccepted(), 'QtfEventFilter%dropEvent')
    call check(.not. w%has_items .and. size(w%items) == 0, 'no items in plain text')
    call ev%delete()
    leave = QEvent(QEvent_DragLeave)
    sent = QCoreApplication_sendEvent(win, leave)
    call check(w%leaves == 1, 'QtfEventFilter%dragLeaveEvent')
    call leave%delete()
    w%accept = .false.
    ev = QDropEvent(QEvent_DragEnter, 4.0_c_double, 4.0_c_double, mime)
    sent = QCoreApplication_sendEvent(win, ev)
    call check(w%enters == 2 .and. .not. ev%isAccepted(), 'drag not accepted by the slot: refused')
    call ev%delete()
    w%accept = .true.

    ! --- dragging rows out of a list model
    list = QtfListModel(4)
    call list%dataRequested%connect(on_list_data)
    call list%dragStarted%connect(on_drag_started, m)
    call list%setDragEnabled(.true.)
    mime2 = list%mimeData([3, 1])
    call check(m%drags == 1, 'dragStarted')
    call check(mime2%text() == 'd' // new_line('a') // 'b', 'drag data: cells as text, in the order given')
    items = mime2%items()
    call check(mime2%hasItems() .and. size(items) == 2, 'drag data: items')
    call check(items(1) == 3 .and. items(2) == 1, 'drag data: the rows')
    call check(mime2%data('application/x-qtf-test') == 'extra', 'dragStarted adds a format')
    call check(list%isDragSource(mime2), 'isDragSource')
    other = QtfListModel(2)
    call check(.not. other%isDragSource(mime2) .and. .not. list%isDragSource(mime), 'isDragSource: other data')

    ! the items dropped on a window
    ev = QDropEvent(QEvent_DragEnter, 4.0_c_double, 4.0_c_double, mime2)
    sent = QCoreApplication_sendEvent(win, ev)
    call ev%delete()
    ev = QDropEvent(QEvent_Drop, 4.0_c_double, 4.0_c_double, mime2)
    sent = QCoreApplication_sendEvent(win, ev)
    call check(w%has_items .and. size(w%items) == 2, 'items dropped on a window')
    call check(w%items(1) == 3, 'event%items')
    call ev%delete()

    ! --- view settings
    list_view = QListView()
    call list_view%setModel(list)
    call check(.not. list_view%dragEnabled(), 'not draggable by default')
    call list_view%setDragDropMode(QAbstractItemView_DragDrop)
    call check(list_view%dragDropMode() == QAbstractItemView_DragDrop, 'setDragDropMode')
    call check(list_view%dragEnabled() .and. list_view%acceptDrops(), 'DragDrop: drags and drops')
    call list_view%setDefaultDropAction(Qt_MoveAction)
    call check(list_view%defaultDropAction() == Qt_MoveAction, 'setDefaultDropAction')
    call list_view%setDropIndicatorShown(.false.)
    call check(.not. list_view%showDropIndicator(), 'setDropIndicatorShown')
    call list_view%setDropIndicatorShown(.true.)
    call list_view%setDragDropOverwriteMode(.false.)
    call check(.not. list_view%dragDropOverwriteMode(), 'setDragDropOverwriteMode')
    call list_view%setDragEnabled(.false.)
    call check(.not. list_view%dragEnabled(), 'setDragEnabled')
    call list_view%setDragDropMode(QAbstractItemView_DragDrop)

    ! --- drops on a list view: refused until the model takes drops
    call list_view%resize(200, 300)
    call list_view%show()
    call list%dropped%connect(on_model_drop, m)
    call check(.not. drop_on(list_view%viewport(), mime2, 50, 280), 'model without setDropEnabled refuses')
    call check(m%drops == 0, 'no dropped slot called')
    call list%setDropEnabled(.true.)
    ! on the empty space below the rows: appended
    call check(drop_on(list_view%viewport(), mime2, 50, 280), 'drop on a list view accepted')
    call check(m%drops == 1 .and. m%row == 4 .and. .not. m%on_item, 'dropped at the end')
    call check(m%internal .and. m%has_items .and. size(m%items) == 2, 'dropped items from this model')
    call check(m%action == Qt_CopyAction .and. m%text(1:1) == 'd', 'drop action and text')
    ! at the top edge of the first row: inserted before it
    call check(drop_on(list_view%viewport(), mime, 50, 1), 'drop of text before row 0')
    call check(m%drops == 2 .and. m%row == 0 .and. .not. m%internal .and. .not. m%has_items, &
               'dropped before row 0, from outside')
    call check(m%text == 'to the window', 'dropped text')
    ! a slot refusing the drop
    m%refuse_drop = .true.
    call check(.not. drop_on(list_view%viewport(), mime, 50, 280), 'drop refused by the slot')
    m%refuse_drop = .false.
    ! formats the model does not take
    call list%setDropFormats(['application/x-other'])
    call check(.not. drop_on(list_view%viewport(), mime, 50, 280), 'setDropFormats: text refused')
    call list%setDropFormats([character(len=23) :: 'application/x-qtf-items', 'text/plain'])
    call check(drop_on(list_view%viewport(), mime, 50, 280), 'setDropFormats: text taken again')

    ! --- a tree view: onto a node, or at the top level
    tree = QtfTreeModel(2)
    call tree%dataRequested%connect(on_cell_data)
    call tree%setParents([0, 1, 0])
    call tree%setDragEnabled(.true.)
    call tree%setDropEnabled(.true.)
    call tree%dropped%connect(on_model_drop, m)
    mime2 = tree%mimeData([2])
    items = mime2%items()
    call check(size(items) == 1 .and. items(1) == 2, 'tree drag data: the nodes')
    call check(mime2%text() == 'n2c0' // achar(9) // 'n2c1', 'tree drag data: cells separated by tabs')
    tree_view = QTreeView()
    call tree_view%setModel(tree)
    call tree_view%setDragDropMode(QAbstractItemView_DragDrop)
    call tree_view%resize(300, 300)
    call tree_view%show()
    m%drops = 0
    call check(drop_on(tree_view%viewport(), mime2, 60, 9), 'drop onto a tree node')
    call check(m%drops == 1 .and. m%on_item .and. m%node == 1, 'dropped onto node 1')
    call check(m%parent_node == 1 .and. m%row == 1, 'as the last child of node 1')
    call check(m%internal .and. m%items(1) == 2, 'tree drop: internal items')
    call check(drop_on(tree_view%viewport(), mime2, 60, 280), 'drop on empty tree space')
    call check(m%drops == 2 .and. .not. m%on_item .and. m%parent_node == 0 .and. m%row == 2 .and. m%node == 0, &
               'dropped at the end of the top level')

    ! --- a table view, through a proxy: onto a cell
    table = QtfTableModel(3, 2)
    call table%dataRequested%connect(on_cell_data)
    call table%setDragEnabled(.true.)
    call table%setDropEnabled(.true., onItems=.true.)
    call table%dropped%connect(on_model_drop, m)
    proxy = QSortFilterProxyModel()
    call proxy%setSourceModel(table)
    call check(table%isDragSource(table%mimeData([0])), 'table drag data')
    call check(.not. proxy%isDragSource(table%mimeData([0])), 'the source model is the drag source')
    table_view = QTableView()
    call table_view%setModel(proxy)
    call table_view%setDragDropMode(QAbstractItemView_DragDrop)
    call table_view%resize(400, 300)
    call table_view%show()
    m%drops = 0
    call check(drop_on(table_view%viewport(), mime, table_view%columnWidth(0) + 10, &
                       table_view%rowHeight(0) + table_view%rowHeight(1) / 2), 'drop onto a table cell')
    call check(m%drops == 1 .and. m%on_item .and. m%row == 1 .and. m%column == 1, 'dropped onto cell (1, 1)')

    call table_view%delete()
    call tree_view%delete()
    call list_view%delete()
    call proxy%delete()
    call table%delete()
    call tree%delete()
    call list%delete()
    call other%delete()
    call mime%delete()
    call mime2%delete()
    call win%delete()
    write(*,'(A)') 'test_drag_drop: all checks passed'

contains

    !> Drag `data` onto `target` at (x, y) and drop it; true if the drop was accepted.
    logical function drop_on(target, data, x, y)
        type(QWidget), intent(in) :: target
        type(QMimeData), intent(in) :: data
        integer, intent(in) :: x, y
        type(QDropEvent) :: e
        logical :: s
        drop_on = .false.
        e = QDropEvent(QEvent_DragEnter, real(x, c_double), real(y, c_double), data)
        s = QCoreApplication_sendEvent(target, e)
        if (.not. e%isAccepted()) then
            call e%delete()
            return
        end if
        call e%delete()
        e = QDropEvent(QEvent_DragMove, real(x, c_double), real(y, c_double), data)
        s = QCoreApplication_sendEvent(target, e)
        call e%delete()
        e = QDropEvent(QEvent_Drop, real(x, c_double), real(y, c_double), data)
        s = QCoreApplication_sendEvent(target, e)
        drop_on = e%isAccepted()
        call e%delete()
    end function drop_on

end program test_drag_drop
