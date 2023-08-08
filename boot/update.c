#include <stdlib.h>
#include <stdio.h>

// Очистка первых 256К образа диска
void cleanup() {

    char buf[512];
    for (int i = 0; i < 512; i++) buf[i] = 0;

    FILE* fp = fopen("c.img", "rb+");
    if (fp) {

        fseek(fp, 0, SEEK_SET);
        fwrite(buf, 1, 446, fp);
        fseek(fp, 512, SEEK_SET);
        for (int i = 0; i < 512; i++)
            fwrite(buf, 1, 512, fp);

        fclose(fp);
    }
}

void copyfile(const char* file, int sector_n) {

    char buf[512];

    int size;

    FILE* fp   = fopen(file, "rb");
    FILE* fimg = fopen("c.img", "rb+");

    if (fp && fimg) {

        fseek(fp,   0, SEEK_SET);
        fseek(fimg, 512*sector_n, SEEK_SET);

        do {

            for (int i = 0; i < 512; i++) buf[i] = 0;
            size = fread(buf, 1, 512, fp);
            fwrite(buf, 1, 512, fimg);

        } while (size == 512);

        fclose(fp);
        fclose(fimg);

    } else {
        printf("CAN'T COPY %s\n", file);
    }
}

void update_magic() {

    FILE* fp = fopen("c.img", "rb+");

    if (fp) {

        char buf[2];

        buf[0] = 0x55;
        buf[1] = 0xAA;

        fseek(fp, 510, SEEK_SET);
        fwrite(buf, 1, 2, fp);

        fclose(fp);

    } else {
        printf("CAN'T UPDATE MAGIC\n");
    }
}

void makeimage() {

    char buf[512];

    FILE* fi = fopen("c.img", "rb+");
    FILE* fo = fopen("dist/program.img", "wb");

    if (fi && fo) {

        fseek(fi, 512, SEEK_SET);

        for (int i = 0; i < 128*1024/512; i++) {

            fread(buf, 1, 512, fi);
            fwrite(buf, 1, 512, fo);
        }

        fclose(fi);
        fclose(fo);
    }
}

/*
 * Микропрограмма для обновления MBR в образе диска
 */

int main(int argc, char* argv[]) {

    cleanup();

    copyfile("dist/boot.bin",   0);             // Boot
    copyfile("dist/speccy.bin", 1);             // 64K эмулятор

    copyfile("rom/128k.rom",    128+1+0);       // 16K 128K ROM
    copyfile("rom/48k.rom",     128+1+32);      // 16K 48K  ROM
    copyfile("rom/trdos.rom",   128+1+64);      // 16K TRDOS
    copyfile("rom/other.rom",   128+1+96);      // 16K ?

    makeimage();

    update_magic();

    return 0;
}
