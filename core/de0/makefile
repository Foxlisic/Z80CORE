all: mif pgm
syn:
	date
	quartus_map --read_settings_files=on  --write_settings_files=off de0 -c de0
	quartus_fit --read_settings_files=off --write_settings_files=off de0 -c de0
	make mif
	make pgm
	date
mif:
	quartus_cdb de0 -c de0 --update_mif
	quartus_asm --read_settings_files=on --write_settings_files=off de0 -c de0
pgm:
	quartus_pgm -m jtag -o "p;output_files/de0.sof"

clean:
	rm -rf db incremental_db simulation timing greybox_tmp *.jdi *.pof *.sld *.rpt *.summary *.sof *.done *.pin *.qws *.bak *.smsg *.qws *.vcd *.qqq *.jic *.map .qsys_edit undo_redo.txt PLLJ_PLLSPE_INFO.txt c5_pin_model_dump.txt *.qdf output_files

