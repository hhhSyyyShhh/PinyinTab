(1..9).each do |row|
  cells = (1..row).map do |column|
    format("%d×%d=%2d", column, row, column * row)
  end
  puts cells.join("\t")
end
