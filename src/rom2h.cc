#include <stdlib.h>
#include <stdio.h>

/**
 * Требуется для перевода ROM в H файлы
 * ./rom2h <rom_name> <file_in.rom> <file_out.h>
 */

int main(int argc, char* argv[]) {

    unsigned char rom[16384];

    if (argc > 3) {

        FILE* fp = fopen(argv[2], "rb");
        FILE* fo = fopen(argv[3], "w");

        if (fp && fo) {

            fread(rom, 1, 16384, fp);
            fprintf(fo, "unsigned char %s[16384] = {\n", argv[1]);
            for (int s = 0; s < 16384; s += 32) {

                fprintf(fo, "    ");
                for (int i = 0; i < 32; i++) {
                    fprintf(fo, "0x%02X%s", rom[s + i], i < 31 ? "," : ",\n");
                }
            }
            fprintf(fo, "};\n");

            fclose(fp);
            fclose(fo);
        }
    }
}
