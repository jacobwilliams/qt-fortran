!> Item views beyond text: icons, check boxes, tool tips, colors, alignment
!> and font style from Fortran models; QtfListModel with QListView; and
!> custom-painted cells (QtfItemDelegate%paintCell). Run headless with
!> QT_QPA_PLATFORM=offscreen.
module test_item_roles_data

    use qt
    use iso_c_binding, only: c_double
    implicit none

    !> Data behind the models, and what the slots saw.
    type :: data_t
        logical :: done(3) = [.true., .false., .true.]
        logical :: leaf_done(3) = .false.
        real(c_double) :: level(3) = [0.25_c_double, 0.5_c_double, 1.0_c_double]
        type(QIcon) :: icon
        integer :: requests = 0, display_requests = 0, checks = 0
        integer :: painted = 0, painted_rows = 0, cell_height = -1, node_seen = 0
        logical :: color_ok = .true.
        character(len=:), allocatable :: text_seen
    end type data_t

contains

    !> Table cells: column 0 a task (icon, check box), column 1 its level
    !> (right-aligned, colored, bold, with a tool tip).
    subroutine on_cell(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        character(len=8) :: text
        select type (data)
        type is (data_t)
            data%requests = data%requests + 1
            if (request%role() == Qt_DisplayRole) data%display_requests = data%display_requests + 1
            if (column == 0) then
                write(text, '(a, i0)') 'task ', row + 1
                call request%setText(trim(text))
                call request%setIcon(data%icon)
                call request%setChecked(data%done(row + 1))
                call request%setStatusTip('a task')
            else
                call request%setNumber(data%level(row + 1))
                call request%setAlignment(ior(Qt_AlignRight, Qt_AlignVCenter))
                write(text, '(a, i0)') 'tip ', row
                call request%setToolTip(trim(text))
                call request%setForeground(Qt_blue)
                call request%setBackground(QColor(255, 255, 200))
                call request%setBold()
                call request%setItalic(.false.)
                if (row == 0) call request%setIconColor(Qt_red)
            end if
        end select
    end subroutine on_cell

    !> Store a check-box click.
    subroutine on_check(row, column, checked, data)
        integer, intent(in) :: row, column, checked
        class(*), intent(inout), optional :: data
        select type (data)
        type is (data_t)
            data%checks = data%checks + 1
            if (column == 0) data%done(row + 1) = checked == 1
        end select
    end subroutine on_check

    !> Tree cells: node 1 is a folder, nodes 2..4 are leaves with check boxes.
    subroutine on_tree_cell(node, column, request, data)
        integer, intent(in) :: node, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        select type (data)
        type is (data_t)
            if (node == 1) then
                call request%setText('folder')
            else
                call request%setText('leaf')
                call request%setChecked(data%leaf_done(node - 1))
            end if
        end select
    end subroutine on_tree_cell

    !> Store a tree check-box click.
    subroutine on_tree_check(node, column, checked, data)
        integer, intent(in) :: node, column, checked
        class(*), intent(inout), optional :: data
        select type (data)
        type is (data_t)
            data%leaf_done(node - 1) = checked == 1
        end select
    end subroutine on_tree_check

    !> List rows.
    subroutine on_list_item(row, column, request, data)
        integer, intent(in) :: row, column
        type(QtfModelRequest), intent(inout) :: request
        class(*), intent(inout), optional :: data
        character(len=8) :: text
        write(text, '(a, i0)') 'item ', row
        call request%setText(trim(text))
    end subroutine on_list_item

    !> Paint column 1 as a bar: green, as wide as the level. Column 0 is drawn
    !> by Qt (drawDefault).
    subroutine on_paint(cell, data)
        type(QtfPaintCell), intent(in) :: cell
        class(*), intent(inout), optional :: data
        type(QPainter) :: p
        type(QColor) :: c
        integer :: w
        select type (data)
        type is (data_t)
            data%painted = data%painted + 1
            data%node_seen = cell%node()
            data%cell_height = cell%height()
            if (cell%column() == 0) then
                call cell%drawDefault()
                return
            end if
            data%painted_rows = ior(data%painted_rows, 2**cell%row())
            data%text_seen = cell%text()
            c = cell%textColor()
            data%color_ok = data%color_ok .and. c%isValid()
            data%color_ok = data%color_ok .and. cell%isEnabled() .and. .not. cell%isHovered()
            if (cell%isSelected() .or. cell%hasFocus()) data%color_ok = data%color_ok .and. cell%viewRow() >= 0
            call cell%drawBackground()
            p = cell%painter()
            w = nint(data%level(cell%row() + 1) * (cell%width() - 4))
            call p%fillRect(cell%x() + 2, cell%y() + 2, w, cell%height() - 4, Qt_green)
        end select
    end subroutine on_paint

end module test_item_roles_data

!> Tests roles, check states, list views and painted cells.
program test_item_roles

    use qt
    use testing
    use test_item_roles_data
    implicit none

    type(QApplication) :: app
    type(QObject) :: owner
    type(QtfTableModel) :: table
    type(QtfTreeModel) :: tree
    type(QtfListModel) :: list
    type(QTableView) :: view
    type(QListView) :: list_view
    type(QtfItemDelegate) :: delegate
    type(QImage) :: img, shot
    type(QPixmap) :: pix
    type(data_t), target :: d
    integer :: x, y, green, before
    logical :: ok

    app = QApplication()
    owner = QObject()
    img = QImage(16, 16)
    call img%fill(Qt_darkGreen)
    pix = QPixmap_fromImage(img)
    d%icon = QIcon(pix)

    ! --- roles from a table model
    table = QtfTableModel(3, 2, owner)
    call table%dataRequested%connect(on_cell, d)
    call table%checkChanged%connect(on_check, d)
    call check(table%isCheckable(0, 0) .and. .not. table%isCheckable(0, 1), &
               'a cell with setChecked has a check box (learned on first use)')
    call check(table%isChecked(0, 0) .and. .not. table%isChecked(1, 0) .and. table%isChecked(2, 0), 'isChecked')
    call check(table%toolTip(1, 1) == 'tip 1' .and. table%toolTip(1, 0) == '', 'toolTip')
    call check(table%dataText(2, 0) == 'task 3', 'text with the other roles')
    call check(table%setChecked(1, 0, .true.) .and. d%done(2) .and. d%checks == 1, 'checkChanged')
    call check(table%isChecked(1, 0), 'check state from the Fortran data')
    ok = table%setChecked(0, 0, .false.)
    call check(.not. d%done(1), 'uncheck')

    ! a model that only shows text asks once per cell
    before = d%requests
    call check(table%dataText(0, 1) == '0.25', 'number text')
    call check(d%requests == before + 1, 'one request per displayed cell')

    ! --- roles from a tree model
    tree = QtfTreeModel(1, owner)
    call tree%dataRequested%connect(on_tree_cell, d)
    call tree%checkChanged%connect(on_tree_check, d)
    call tree%setParents([0, 1, 1, 1])
    call check(tree%dataText(1, 0) == 'folder' .and. tree%dataText(3, 0) == 'leaf', 'tree text')
    view = QTableView()       ! (any view: only for show/paint below)

    ! --- QtfListModel and QListView
    list = QtfListModel(4, owner)
    call list%dataRequested%connect(on_list_item, d)
    call check(list%rowCount() == 4 .and. list%columnCount() == 1, 'QtfListModel: one column')
    call check(list%dataText(2, 0) == 'item 2', 'list items from Fortran')
    list_view = QListView()
    call list_view%setModel(list)
    call list_view%setUniformItemSizes(.true.)
    call list_view%setSpacing(2)
    call list_view%setWordWrap(.true.)
    call list_view%setResizeMode(QListView_Adjust)
    call list_view%setMovement(QListView_Static)
    call list_view%setIconSize(24, 24)
    call list_view%setCurrentRow(2)
    call check(list_view%currentRow() == 2, 'QListView setCurrentRow / currentRow')
    call list_view%setRowHidden(1, .true.)
    call list_view%scrollToRow(3)
    call list_view%setViewMode(QListView_IconMode)
    call list_view%setFlow(QListView_LeftToRight)
    call list_view%setWrapping(.true.)
    call list_view%setGridSize(64, 64)
    call list_view%setModelColumn(0)
    call list_view%resize(200, 150)
    call list_view%show()
    shot_list: block
        type(QPixmap) :: lp
        lp = list_view%grab()
        call check(lp%width() == 200, 'QListView renders')
        call lp%delete()
    end block shot_list
    call list%setRowCount(6)
    call check(list%rowCount() == 6 .and. list%columnCount() == 1, 'QtfListModel%setRowCount')

    ! --- custom-painted cells
    call view%setModel(table)
    delegate = QtfItemDelegate(view)
    call delegate%paintCell%connect(on_paint, d)
    call delegate%setSizeHint(height=30)
    call view%setItemDelegate(delegate)
    call view%resizeRowsToContents()
    call view%setColumnWidth(1, 100)
    call view%resize(320, 200)
    call view%show()
    call view%setCurrentCell(0, 1)
    pix = view%grab()
    call check(d%painted >= 6 .and. d%painted_rows == 7, 'paintCell called for every cell')
    call check(d%cell_height == 30, 'setSizeHint (with resizeRowsToContents)')
    call check(d%node_seen == -1 .and. len(d%text_seen) > 0, 'cell row, column, node, text')
    call check(d%color_ok, 'cell state and text color')
    shot = pix%toImage()
    green = 0
    do y = 0, shot%height() - 1
        do x = 0, shot%width() - 1
            if (shot%pixelColor(x, y) == Qt_green) green = green + 1
        end do
    end do
    call check(green > 200, 'the bars were painted')
    call shot%delete()
    call pix%delete()

    ! disconnected: Qt paints the cells again
    call delegate%paintCell%disconnect()
    before = d%painted
    pix = view%grab()
    call check(d%painted == before, 'default painting after disconnect')
    call pix%delete()

    ! tree check boxes, in a view
    call view%setModel(tree)
    call check(tree%rowCount() == 1, 'tree model in a view')
    tree_view: block
        type(QTreeView) :: tv
        tv = QTreeView()
        call tv%setModel(tree)
        call tv%expandAll()
        call tv%show()
        pix = tv%grab()
        call pix%delete()
        call tv%delete()
    end block tree_view
    call check(.not. d%leaf_done(2), 'tree leaf unchecked')

    call d%icon%delete()
    call img%delete()
    call view%delete()
    call list_view%delete()
    write(*,'(A)') 'test_item_roles: all checks passed'

end program test_item_roles
