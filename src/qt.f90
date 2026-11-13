!> Modern Fortran interface to Qt: `use qt` for the whole public API.
module qt

    use qt_c_util, only: qt_string
    use qt_core
    use qt_core_classes
    use qt_geometry
    use qt_gui_types
    use qt_gui
    use qt_vectors
    use qt_widgets
    use qt_matrix
    use qt_opengl
    implicit none
    public

end module qt
