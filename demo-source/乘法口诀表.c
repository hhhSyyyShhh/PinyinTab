#include <stdio.h>

int main(void) {
    for (int row = 1; row <= 9; row++) {
        for (int column = 1; column <= row; column++) {
            printf("%d×%d=%2d\t", column, row, column * row);
        }
        putchar('\n');
    }
    return 0;
}
