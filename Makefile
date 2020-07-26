
all: BootLoader Disk.img

BootLoader:
	@echo
	@echo ============ Build Boot Loader ======================
	@echo

	make -C 00.BootLoader

	@echo
	@echo ============ Build Complete ======================
	@echo

Kernel32:
	@echo
	@echo ============ Build 32bit Kernel Loader ======================
	@echo

	make -C 01.Kernel32/Source

	@echo
	@echo ============ Build Complete ======================
	@echo

Disk.img: BootLoader Kernel32
	@echo
	@echo ============ Image Build Start ======================
	@echo

	cat 00.BootLoader/BootLoader.bin 01.Kernel32/Source/VirtualOS.bin > Disk.img

	@echo
	@echo ============ Image Build Complete ======================
	@echo

clean:
	make -C 00.BootLoader clean
	make -C 01.Kernel32/Source clean
	rm -f Disk.img
