for (let row = 1; row <= 9; row += 1) {
  const cells = [];
  for (let column = 1; column <= row; column += 1) {
    cells.push(`${column}×${row}=${String(column * row).padStart(2, " ")}`);
  }
  console.log(cells.join("\t"));
}
