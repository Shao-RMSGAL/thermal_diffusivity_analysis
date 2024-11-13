
function print_aux_data(aux_data, frame_data)
    # Print auxiliary data
    for (key, value) in aux_data
        println("$key: $value")
    end
    # Print information about frame data
    println("\nNumber of frames: $(length(frame_data))")
    println("Dimensions of first frame: $(size(frame_data[1]))\n")

end
