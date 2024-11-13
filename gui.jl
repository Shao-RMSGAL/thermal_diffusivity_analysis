using Gtk4

function create_file_selector_window()
    # Create the main window
    win = GtkWindow("File Selector")
    set_default_size(win, 800, 500)

    # Create a vertical box to organize widgets
    vbox = GtkBox(:v)
    push!(win, vbox)

    # Create a button to open the file chooser dialog
    choose_button = GtkButton("Choose File")
    push!(vbox, choose_button)

    # Create a label to display the selected file path
    file_label = GtkLabel("No file selected")
    push!(vbox, file_label)

    # Create the "Run Analysis" button
    run_button = GtkButton("Run Analysis")
    # Gtk4.set_sensitive(run_button, false)  # Disable initially
    push!(vbox, run_button)

    # Function to handle file selection
    function on_file_chosen(path)
        Gtk4.text(file_label, path)
        # set_sensitive(run_button, true)  # Enable the Run Analysis button
    end

    # Set up the file chooser dialog
    function open_file_chooser(widget)
        dialog = GtkFileChooserDialog(
            "Choose a file",
            widget,
            Gtk4.FileChooserAction_OPEN,
            ("_Cancel", Gtk4.ResponseType_CANCEL, "_Open", Gtk4.ResponseType_ACCEPT),
        )
        response = run(dialog)
        if response == Gtk4.ResponseType_ACCEPT
            #  file_path = get_filename(dialog)
            on_file_chosen(file_path)
        end
        destroy(dialog)
    end

    # Connect the Choose File button to the file chooser function
    signal_connect(open_file_chooser, choose_button, "clicked")

    # Connect the Run Analysis button to the analysis function
    signal_connect(run_button, "clicked") do widget
        file_path = get_text(file_label)
        run_analysis(file_path)
    end

    # Show all widgets
    show(win)
end
