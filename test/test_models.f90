!> Models and views: QtfTreeModel with QTreeView (nodes), sorting
!> (QtfTableModel%sortRequested, QSortFilterProxyModel), filtering,
!> QFileSystemModel, and QtfItemDelegate. Run headless with QT_QPA_PLATFORM=offscreen.
module test_models_data

    use qt
    use iso_c_binding, only: c_double
    implicit none

    !> Data behind the models, and what the slots saw.
    type :: data_t
        character(len=8) :: names(6) = [character(len=8) :: 'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta']
        real(c_double) :: values(5) = [5.0_c_double, 3.0_c_double, 9.0_c_double, 1.0_c_double, 7.0_c_double]
        integer :: current = -2, sort_column = -1, sort_order = -1
        character(len=:), allocatable :: current_file, loaded
    end type data_t

contains

    !> Tree cells: column 0 the name, column 1 the node number.
    subroutine on_tree_cell(node, column, request, data)
        integer, intent(in) :: node, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        select type (data)
        type is (data_t)
            if (column == 0) then
                call request%setText(trim(data%names(node)))
            else
                call request%setInt(node)
            end if
        end select
    end subroutine on_tree_cell

    !> Table cells: column 0 the value (a number), column 1 its row as text.
    subroutine on_table_cell(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        select type (data)
        type is (data_t)
            if (column == 0) then
                call request%setNumber(data%values(row + 1))
            else
                call request%setText('row ' // achar(iachar('0') + row))
            end if
        end select
    end subroutine on_table_cell

    !> Record a sort request.
    subroutine on_sort(column, order, data)
        integer, intent(in) :: column, order
        class(*), intent(inout), optional :: data
        select type (data)
        type is (data_t)
            data%sort_column = column
            data%sort_order = order
        end select
    end subroutine on_sort

    !> Record the current node.
    subroutine on_current_node(node, data)
        integer, intent(in) :: node
        class(*), intent(inout), optional :: data
        select type (data)
        type is (data_t)
            data%current = node
        end select
    end subroutine on_current_node

    !> Record the current file.
    subroutine on_current_file(path, data)
        character(len=*), intent(in) :: path
        class(*), intent(inout), optional :: data
        select type (data)
        type is (data_t)
            data%current_file = path
        end select
    end subroutine on_current_file

    !> A directory was loaded: leave the event loop.
    subroutine on_loaded(path, data)
        character(len=*), intent(in) :: path
        class(*), intent(inout), optional :: data
        select type (data)
        type is (data_t)
            data%loaded = path
        end select
        call QApplication_quit()
    end subroutine on_loaded

    !> Leave the event loop (a time limit).
    subroutine on_timeout(data)
        class(*), intent(inout), optional :: data
        call QApplication_quit()
    end subroutine on_timeout

end module test_models_data

!> Tests the models and views.
program test_models

    use qt
    use testing
    use test_models_data
    implicit none

    character(len=*), parameter :: dir = 'build/test_models_dir'
    type(QApplication) :: app
    type(QObject) :: owner
    type(QtfTreeModel) :: tree
    type(QtfTableModel) :: table
    type(QSortFilterProxyModel) :: proxy, tree_proxy
    type(QFileSystemModel) :: files
    type(QTreeView) :: view, file_view
    type(QTableView) :: table_view
    type(QtfItemDelegate) :: delegate
    type(data_t), target :: d
    integer :: u, ierr, n

    app = QApplication()
    owner = QObject()

    ! --- QtfTreeModel: alpha(1) > gamma(3), delta(4); beta(2) > epsilon(5)
    tree = QtfTreeModel(2, owner)
    call tree%setHeaderLabels(['Name', 'Node'])
    call tree%dataRequested%connect(on_tree_cell, d)
    call tree%setParents([0, 0, 1, 1, 2])
    call check(tree%nodeCount() == 5 .and. tree%rowCount() == 2 .and. tree%columnCount() == 2, 'tree shape')
    call check(tree%childCount(1) == 2 .and. tree%childCount(0) == 2 .and. tree%parentNode(5) == 2, 'tree structure')
    call check(tree%dataText(4, 0) == 'delta' .and. tree%dataText(5, 1) == '5', 'tree cells from Fortran')
    n = tree%appendNode(3)      ! (separate statement: Fortran does not order evaluation within an expression)
    call check(n == 6 .and. tree%childCount(3) == 1 .and. tree%dataText(6, 0) == 'zeta', 'appendNode')

    view = QTreeView()
    call view%setModel(tree)
    call view%currentNodeChanged%connect(on_current_node, d)
    call view%show()
    call view%setCurrentNode(4)
    call check(view%currentNode() == 4 .and. d%current == 4, 'setCurrentNode, currentNodeChanged')
    call view%expandNode(2)
    call check(view%isNodeExpanded(2), 'expandNode')
    call view%collapseNode(2)
    call check(.not. view%isNodeExpanded(2), 'collapseNode')
    call view%expandAll()
    call check(view%isNodeExpanded(3), 'expandAll')
    call tree%refresh()
    call tree%refreshNode(2)
    call check(view%currentNode() == 4, 'refresh keeps the current node')

    ! --- a proxy between the tree and the view: nodes still come through
    tree_proxy = QSortFilterProxyModel(owner)
    call tree_proxy%setSourceModel(tree)
    call tree_proxy%setRecursiveFilteringEnabled(.true.)
    call tree_proxy%setFilterKeyColumn(0)
    call tree_proxy%setFilterFixedString('epsilon')
    call view%setModel(tree_proxy)
    call check(tree_proxy%rowCount() == 1, 'recursive filter keeps the parent')
    call view%setCurrentNode(5)
    call check(view%currentNode() == 5, 'node through a proxy')
    call tree_proxy%setFilterFixedString('')
    call check(tree_proxy%rowCount() == 2, 'filter cleared')

    ! --- table: Fortran sorting through sortRequested
    table = QtfTableModel(5, 2, owner)
    call table%dataRequested%connect(on_table_cell, d)
    call table%sortRequested%connect(on_sort, d)
    table_view = QTableView()
    call table_view%setModel(table)
    call table_view%setSortingEnabled(.true.)
    call table_view%sortByColumn(0, Qt_DescendingOrder)
    call check(d%sort_column == 0 .and. d%sort_order == Qt_DescendingOrder, 'sortRequested')

    ! --- table: QSortFilterProxyModel sorts numbers numerically, filters text
    proxy = QSortFilterProxyModel(owner)
    call proxy%setSourceModel(table)
    call proxy%sort(0)
    call check(proxy%mapToSourceRow(0) == 3 .and. proxy%mapToSourceRow(4) == 2, 'proxy sorts numerically')
    call check(proxy%mapFromSourceRow(3) == 0, 'mapFromSourceRow')
    call proxy%sort(0, Qt_DescendingOrder)
    call check(proxy%mapToSourceRow(0) == 2, 'descending')
    call proxy%setFilterKeyColumn(1)
    call proxy%setFilterFixedString('row 4')
    call check(proxy%rowCount() == 1 .and. proxy%mapToSourceRow(0) == 4, 'filter')
    call proxy%setFilterRegularExpression('row [12]')
    call check(proxy%rowCount() == 2, 'regular expression filter')
    call proxy%setFilterWildcard('*3')
    call check(proxy%rowCount() == 1 .and. proxy%mapToSourceRow(0) == 3, 'wildcard filter')
    call table_view%setModel(proxy)
    call check(table_view%currentRow() == -1, 'view on the proxy')

    ! --- delegate: a combo box / spin box editor for a column
    delegate = QtfItemDelegate(table_view)
    call delegate%setChoices(['low ', 'mid ', 'high'])
    call table_view%setItemDelegateForColumn(1, delegate)
    call delegate%setRange(0.0_c_double, 10.0_c_double, 1)
    call delegate%clear()
    call table_view%setItemDelegate(delegate)
    call table%setEditable(.true.)
    call table_view%show()
    call table_view%edit(0, 0)
    call check(.true., 'delegates set')

    ! --- QFileSystemModel
    call execute_command_line('mkdir -p ' // dir, exitstat=ierr)
    open(newunit=u, file=dir // '/a.dat', status='replace')
    close(u)
    open(newunit=u, file=dir // '/b.csv', status='replace')
    close(u)
    files = QFileSystemModel(owner)
    call files%directoryLoaded%connect(on_loaded, d)
    call files%setNameFilters(['*.dat'])
    call files%setNameFilterDisables(.false.)
    call files%setRootPath(dir)
    file_view = QTreeView()
    call file_view%setModel(files)
    call file_view%setRootPath(dir)
    call file_view%currentFileChanged%connect(on_current_file, d)
    call QTimer_singleShot(5000, on_timeout)
    ierr = QApplication_exec()
    call check(allocated(d%loaded), 'directoryLoaded')
    call check(files%childCount(files%rootPath()) == 1, 'name filter hides b.csv')
    call file_view%setCurrentFile(files%rootPath() // '/a.dat')
    call check(index(file_view%currentFilePath(), 'a.dat') > 0, 'currentFilePath')
    call check(allocated(d%current_file), 'currentFileChanged')
    if (allocated(d%current_file)) call check(index(d%current_file, 'a.dat') > 0, 'currentFileChanged path')

    call view%delete()
    call table_view%delete()
    call file_view%delete()
    call owner%delete()

    write(*,'(A)') 'test_models: all checks passed'

end program test_models
