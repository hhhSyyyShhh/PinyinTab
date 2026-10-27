fn main() {
    for row in 1..=9 {
        for column in 1..=row {
            print!("{column}×{row}={:2}\t", column * row);
        }
        println!();
    }
}
