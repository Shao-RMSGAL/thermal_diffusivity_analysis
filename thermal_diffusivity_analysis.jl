using Plots
using DataFrames
using Unitful
using CSV
using Gtk4, GtkObservables

function analyze_data(df)

end

function extract_header_data(df)
    header_data = Dict{String, Any}()
    for i in 2:14
        header_data[df[i, 2]] = df[i ,3]
    end
    return header_data
end

function extract_temperature_data(df)

    

    #  temperature_data =Matrix{Float64}[]
    #  frame_num = 1
    #  while true
    #      frame_start = 15 + (frame_num - 1) * 21
    #      if frame_start > size(df, 1)
    #          break
    #      end
    #      temp_data = Matrix{Float64}(undef, 20, 17)
    #      for i in 1:20
    #          for j in 1:17
    #              temp_data[i, j] = parse(Float64, df[frame_start + i, 'B' + j - 1])
    #          end
    #      end
    #      push!(temperature_data, temp_data)
    #      frame_num += 1
    #  end
    #  return temperature_data
end

function read_file(filename) 
    #header_df = DataFrame(CSV.File(filename, skipto=1, limit=13))
    #println("Header:\n", header_df)
    df = CSV.read(filename, DataFrame, skipto=15) # DataFrame(CSV.File(filename, skipto=15))
    println("Rest of it:\n", df[1:20, 1:end])
    # header_data = extract_header_data(df)
    temperature_data = extract_temperature_data(df)

    # println("Header Data:")
    # for (k, v) in header_data
    #    println("$k, $v")
    # end

    #  println("\nTemperature Data (Vector of Matrrices):")
    #  for (i, matrix) in enumerate(temperature_data)
    #      println("Frame $i: ")
    #      println(matrix)
    #  end
end

function on_button_clicked(window)
    println("Window: $window")
    file_path = open_file_dialog(window)
    if file_path !== nothing
        df = DataFrame(CSV.File(file_path))

        println(df)
    end
end

function create_window()
    win = GtkWindow("Thermal Diffusivity Analysis")
    hbox = GtkBox(:h)
    push!(win, hbox)
    vbox = GtkBox(:v)
    push!(win, vbox)

    file_search = GtkButton("Select a file to analyze")
    file_search.hexpand = true

    id = signal_connect(file_search, "clicked") do widget
        open_dialog("Pick a sample file to analyze", win, start_folder = ".") do filename
            read_file(filename)
        end
    end

    push!(vbox, file_search)
    show(win)
end

# create_window()
read_file("./Sample2_Extracted Data/Sample2 100 M1.csv")
