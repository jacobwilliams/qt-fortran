!> Item views: QTableWidget, QListWidget, QTreeWidget, and QTableView with a
!> Fortran-backed QtfTableModel. Run headless with QT_QPA_PLATFORM=offscreen.
module test_views_slots

    use qt
    use iso_c_binding, only: c_double
    implicit none

    !> Records signal arguments.
    type :: view_log
        integer :: calls = 0
        integer :: a = -9, b = -9, c = -9, d = -9
        character(len=:), allocatable :: text
    end type view_log

    !> The data behind a QtfTableModel: a Fortran array.
    type :: table_data
        real(c_double) :: values(1000, 3)
        integer :: requests = 0
        integer :: edits = 0
    end type table_data

contains

    !> Record two integers.
    subroutine on_int2(a, b, data)
        integer, intent(in) :: a, b
        class(*), intent(inout), optional :: data
        select type (data)
        type is (view_log)
            data%calls = data%calls + 1
            data%a = a
            data%b = b
        end select
    end subroutine on_int2

    !> Record four integers.
    subroutine on_int4(a, b, c, d, data)
        integer, intent(in) :: a, b, c, d
        class(*), intent(inout), optional :: data
        select type (data)
        type is (view_log)
            data%calls = data%calls + 1
            data%a = a
            data%b = b
            data%c = c
            data%d = d
        end select
    end subroutine on_int4

    !> Record one integer.
    subroutine on_int(value, data)
        integer, intent(in) :: value
        class(*), intent(inout), optional :: data
        select type (data)
        type is (view_log)
            data%calls = data%calls + 1
            data%a = value
        end select
    end subroutine on_int

    !> Record a tree item's first-column text and the column.
    subroutine on_tree_item_int(item, column, data)
        type(QTreeWidgetItem), intent(in) :: item
        integer, intent(in) :: column
        class(*), intent(inout), optional :: data
        select type (data)
        type is (view_log)
            data%calls = data%calls + 1
            data%a = column
            data%text = item%text(0)
        end select
    end subroutine on_tree_item_int

    !> Record the current tree item's text.
    subroutine on_tree_item(item, data)
        type(QTreeWidgetItem), intent(in) :: item
        class(*), intent(inout), optional :: data
        select type (data)
        type is (view_log)
            data%calls = data%calls + 1
            data%text = ''
            if (.not. item%isNull()) data%text = item%text(0)
        end select
    end subroutine on_tree_item

    !> Provide a cell of the model from the Fortran array.
    subroutine on_data(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        select type (data)
        type is (table_data)
            data%requests = data%requests + 1
            if (column == 0) then
                call request%setInt(row + 1)
            else
                call request%setNumber(data%values(row + 1, column + 1))
            end if
        end select
    end subroutine on_data

    !> Store an edited cell into the Fortran array.
    subroutine on_edit(row, column, text, data)
        integer, intent(in) :: row, column
        character(len=*), intent(in) :: text
        class(*), intent(inout), optional :: data
        integer :: ios
        real(c_double) :: v
        select type (data)
        type is (table_data)
            read(text, *, iostat=ios) v
            if (ios == 0) then
                data%values(row + 1, column + 1) = v
                data%edits = data%edits + 1
            end if
        end select
    end subroutine on_edit

end module test_views_slots

!> Tests the item views.
program test_views

    use qt
    use testing
    use test_views_slots
    use iso_c_binding, only: c_double
    implicit none

    type(QApplication) :: app
    type(QTableWidget) :: table
    type(QTableWidgetItem) :: item
    type(QListWidget) :: list
    type(QTreeWidget) :: tree
    type(QTreeWidgetItem) :: root, child, other
    type(QTableView) :: view
    type(QtfTableModel) :: model
    type(view_log), target :: changed, current, clicked, row_log, tree_changed, tree_current
    type(table_data), target :: tdata
    integer :: i

    app = QApplication()

    ! --- QTableWidget
    table = QTableWidget(3, 2)
    call check(table%rowCount() == 3 .and. table%columnCount() == 2, 'QTableWidget shape')
    call table%setHorizontalHeaderLabels(['Name ', 'Value'])
    call table%cellChanged%connect(on_int2, changed)
    do i = 0, 2
        call table%setItem(i, 0, QTableWidgetItem('row'))
    end do
    item = table%item(1, 0)
    call check(.not. item%isNull() .and. item%text() == 'row', 'setItem / item')
    call check(item%row() == 1 .and. item%column() == 0, 'item row/column')
    item = table%item(2, 1)
    call check(item%isNull(), 'empty cell has no item')
    call table%setItem(2, 1, QTableWidgetItem('x'))
    item = table%item(2, 1)
    call item%setText('changed')
    call check(changed%calls >= 1 .and. changed%a == 2 .and. changed%b == 1, 'cellChanged(row, column)')
    call table%currentCellChanged%connect(on_int4, current)
    call table%setCurrentCell(2, 1)
    call check(current%a == 2 .and. current%b == 1 .and. table%currentRow() == 2, 'currentCellChanged (4 ints)')
    call table%insertRow(0)
    call check(table%rowCount() == 4, 'insertRow')
    call table%setItem(0, 1, QTableWidgetItem('b'))
    call table%setItem(1, 1, QTableWidgetItem('a'))
    call table%sortItems(1)
    item = table%item(0, 1)
    call check(item%text() == 'a', 'sortItems')
    call item%setFlags(Qt_ItemIsEnabled)
    call check(item%flags() == Qt_ItemIsEnabled, 'item flags')

    ! --- QListWidget
    list = QListWidget()
    call list%addItems(['alpha  ', 'beta   ', 'gamma  '])
    call list%addItem('delta')
    call check(list%count() == 4 .and. list%itemText(0) == 'alpha', 'addItems (trimmed) / itemText')
    call list%currentRowChanged%connect(on_int, row_log)
    call list%setCurrentRow(2)
    call check(row_log%a == 2 .and. list%currentRow() == 2, 'currentRowChanged')
    call list%setItemText(1, 'BETA')
    call check(list%itemText(1) == 'BETA', 'setItemText')
    call list%takeItem(0)
    call check(list%count() == 3 .and. list%itemText(0) == 'BETA', 'takeItem')
    call check(list%itemText(99) == '', 'itemText out of range')

    ! --- QTreeWidget
    tree = QTreeWidget()
    call tree%setColumnCount(2)
    call tree%setHeaderLabels(['Name', 'Size'])
    root = QTreeWidgetItem(tree, ['src ', '    '])
    child = QTreeWidgetItem(root, ['main.f90', '12 kB   '])
    other = QTreeWidgetItem(['README'])
    call tree%addTopLevelItem(other)
    call check(tree%topLevelItemCount() == 2, 'top-level items')
    call check(root%childCount() == 1 .and. child%text(1) == '12 kB', 'child item and column text')
    child = root%child(0)
    other = child%parent()
    call check(other%text(0) == 'src', 'item parent')
    other = root%parent()
    call check(other%isNull(), 'top-level item has no parent')
    call tree%itemChanged%connect(on_tree_item_int, tree_changed)
    call child%setText(1, '13 kB')
    call check(tree_changed%calls == 1 .and. tree_changed%a == 1 .and. tree_changed%text == 'main.f90', &
               'itemChanged(item, column)')
    call tree%currentItemChanged%connect(on_tree_item, tree_current)
    call tree%setCurrentItem(child)
    call check(tree_current%text == 'main.f90', 'currentItemChanged(item)')
    other = tree%currentItem()
    call check(other%text(0) == 'main.f90', 'currentItem')
    call tree%expandAll()
    call check(root%isExpanded(), 'expandAll')

    ! --- QTableView + QtfTableModel: cells come from a Fortran array on demand
    do i = 1, 1000
        tdata%values(i, :) = [real(i, c_double), 0.5_c_double * i, real(i, c_double)**2]
    end do
    model = QtfTableModel(1000, 3)
    call model%setHorizontalHeaderLabels(['#      ', 'half   ', 'square '])
    call model%dataRequested%connect(on_data, tdata)
    call model%dataEdited%connect(on_edit, tdata)
    call model%setEditable(.true.)
    call check(model%rowCount() == 1000 .and. model%columnCount() == 3, 'model shape')
    call check(model%dataText(9, 0) == '10', 'model cell from a Fortran slot (integer)')
    call check(model%dataText(9, 2) == '100', 'model cell from a Fortran slot (real)')
    call check(tdata%requests >= 2, 'data slot called')
    call check(model%setDataText(4, 1, '42.5'), 'edit accepted')
    call check(tdata%edits == 1 .and. tdata%values(5, 2) == 42.5_c_double, 'edit stored in the Fortran array')
    call check(model%dataText(4, 1) == '42.5', 'edited value shown')

    view = QTableView()
    call view%setModel(model)
    call view%setAlternatingRowColors(.true.)
    call view%setSelectionBehavior(QAbstractItemView_SelectRows)
    call view%clicked%connect(on_int2, clicked)
    call view%setCurrentCell(3, 2)
    call check(view%currentRow() == 3 .and. view%currentColumn() == 2, 'view current cell')
    call view%resize(400, 300)
    call view%show()
    call QApplication_processEvents()
    call check(tdata%requests > 2, 'the view requests visible cells')
    call model%setRowCount(10)
    call check(model%rowCount() == 10, 'setRowCount')

    call table%delete()
    call list%delete()
    call tree%delete()
    call view%delete()
    call model%delete()

    write(*,'(A)') 'test_views: all checks passed'

end program test_views
