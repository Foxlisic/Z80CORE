#include <stdlib.h>
#include "obj_dir/Vz80.h"
#include "obj_dir/Vula.h"
#include "obj_dir/Vmmap.h"
#include "obj_dir/Vps2.h"
#include "obj_dir/Vkbd.h"

#include "zx.h"

// Главный цикл работы программы
int main(int argc, char **argv) {

    // -------------------------------------
    Verilated::commandArgs(argc, argv);
    ZXSpectrum* zx = new ZXSpectrum(640, 400);
    // -------------------------------------

    // PentaGon128k!
    while (zx->main()) {
        for (int i = 0; i < 71000; i++) {
            zx->tick(i);
        }
    }

    return zx->destroy();
}
