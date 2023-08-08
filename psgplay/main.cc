#include <math.h>

#include <stdio.h>
#include <stdlib.h>
#include "ay.cc"

int main(int argc, char* argv[]) {

    AYChip AY;

    if (argc < 2) { printf("Need .psg file\n"); return 1; }

    AY.loadpsg(argv[1]);
    AY.play();

    return 0;
}
