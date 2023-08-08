all:
	sjasm demo.asm program.bin
	php bin2mif.php 64 program.bin ../de0/demo.mif
	cd .. && make icarus
	rm program.lst
	./../tb program.bin
mpg:
	ffmpeg -framerate 60 -r 60 -i out/record.ppm -vf "scale=w=1280:h=800,pad=width=1920:height=1080:x=320:y=140:color=black" -sws_flags neighbor -sws_dither none -f mp4 -q:v 0 -vcodec mpeg4 -y record.mp4
