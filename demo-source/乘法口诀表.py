for row in range(1, 10):
    for column in range(1, row + 1):
        print(f"{column}×{row}={column * row:2}", end="\t")
    print()
