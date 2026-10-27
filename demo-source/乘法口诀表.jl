for row in 1:9
    for column in 1:row
        print("$(column)×$(row)=$(lpad(column * row, 2))\t")
    end
    println()
end
