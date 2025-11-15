#!/usr/bin/env bash

set +e
export EXEC_DIR="$PWD"
export OUTPUT_DIR="$EXEC_DIR/sys"
DISK_SIZE=128

cmd=( qemu-system-x86_64
	-machine q35 #,hpet=off

# CPU (only 1 cpu type should be uncommented)
	-smp sockets=1,cpus=4
	-cpu Westmere
#	-cpu Westmere,x2apic,pdpe1gb
#	-cpu host -enable-kvm

# RAM
	-m 256 # Value is in Megabytes

# Network configuration.
	-netdev socket,id=testnet1,listen=:1234
	-device virtio-net-pci,netdev=testnet1,mac=10:11:12:00:1A:F4 #,disable-legacy=on,disable-modern=false

# Disk configuration. Use one controller.
	-drive id=disk0,file="sys/baremetal_cloud.img",if=none,format=raw
# NVMe
	-device nvme,serial=12345678,drive=disk0
# VIRTIO-Block
#	-device virtio-blk,drive=disk0 #,disable-legacy=on,disable-modern=false
# VIRTIO-SCSI
#	-device virtio-scsi-pci #,disable-legacy=on,disable-modern=false
#	-device scsi-hd,drive=disk0

# Serial configuration
# Output serial to console and log file
	-chardev stdio,id=char0,logfile="sys/serial.log",signal=off
	-serial chardev:char0

# Debugging
# Enable monitor mode
	-monitor telnet:localhost:8086,server,nowait
# Enable GDB debugging
#	-s
# Wait for GDB before starting execution
#	-S
# Output network traffic to file
#	-object filter-dump,id=testnet,netdev=testnet,file=net.pcap
# Trace options
#	-trace "virt*"
#	-trace "apic*"
#	-trace "msi*"
#	-d trace:memory_region_ops_* # Or read/write
#	-d int # Display interrupts
# Prevent QEMU for resetting (triple fault)
#	-no-shutdown -no-reboot
)

function baremetal_clean {
	rm -rf src
	rm -rf sys
	rm -f payload/libBareMetal.*
}

function baremetal_setup {
	echo -e "BareMetal Cloud Setup\n==================="
	baremetal_clean

	mkdir src
	mkdir sys

	cd payload
	if [ -x "$(command -v curl)" ]; then
		curl -s -o libBareMetal.asm https://raw.githubusercontent.com/ReturnInfinity/BareMetal/master/api/libBareMetal.asm
	else
		wget -q https://raw.githubusercontent.com/ReturnInfinity/BareMetal/master/api/libBareMetal.asm
	fi
	nasm payload-test.asm -o ../sys/payload-test.bin
	nasm exec.asm -o ../sys/exec.bin
	cp http.app ../sys/
	cd ..

	echo -n "Pulling code from GitHub"

	if [ "$1" = "dev" ]; then
		echo -n " (Dev Env)... "
		setup_args=" -q"
	else
		echo -n "... "
		setup_args=" -q --depth 1"
	fi

	cd src
	git clone https://github.com/ReturnInfinity/Pure64.git $setup_args
	git clone https://github.com/ReturnInfinity/BareMetal.git $setup_args
	cd ..
	echo "OK"

	cd src/BareMetal
	if [[ "$(uname)" == "Darwin" ]]; then
		sed -i '' 's/^BUILDFLAGS=.*/BUILDFLAGS="-dNO_LFB -dNO_XHCI -dNO_I8259X -dNO_I8257X -dNO_I8254X -dNO_NVME -dNO_AHCI"/' build.sh
		sed -i '' 's/^KERNELSIZE.*/KERNELSIZE equ 10 * 1024/' src/kernel.asm
	else
		sed -i 's/^BUILDFLAGS=.*/BUILDFLAGS="-dNO_LFB -dNO_XHCI -dNO_I8259X -dNO_I8257X -dNO_I8254X -dNO_NVME -dNO_AHCI"/' build.sh
		sed -i 's/^KERNELSIZE.*/KERNELSIZE equ 10 * 1024/' src/kernel.asm
	fi
	cd ../..

	init_imgs $DISK_SIZE

	baremetal_build

	echo -n "Copying software to disk image... "
	baremetal_install
	echo "OK"

	echo -e "\nSetup Complete. Use './baremetal.sh run' to start."
}

# Initialize disk images
function init_imgs { # arg 1 is disk size in MiB
	echo -n "Creating disk image file... "
	cd sys
	dd if=/dev/zero of=baremetal_cloud.img count=$1 bs=1048576 > /dev/null 2>&1
	cd ..
	echo "OK"
}

function update_dir {
	echo "Updating $1..."
	cd "$1"
	git pull -q
	cd "$EXEC_DIR"
}

function baremetal_update {
	git pull -q
	baremetal_src_check
	update_dir "src/Pure64"
	update_dir "src/BareMetal"
}

function build_dir {
	cd "$1"
	if [ -e "build.sh" ]; then
		./build.sh
	fi
	if [ -e "install.sh" ]; then
		./install.sh
	fi
	if [ -e "Makefile" ]; then
		make --quiet
	fi
	mv bin/* "${OUTPUT_DIR}"
	cd "$EXEC_DIR"
}

# Build the source code and create the software files
function baremetal_build {
	baremetal_src_check
	echo -n "Assembling source code... "
	build_dir "src/Pure64"
	build_dir "src/BareMetal"
	echo "OK"

	cd "$OUTPUT_DIR"

	# Remove extra files
	rm bios-floppy*
	rm bios-pxe*
	rm uefi*
	rm pure64-uefi*

	cd ..
}

# Install system software (boot sector, Pure64, kernel, payload)
function baremetal_install {
	baremetal_sys_check
	cd "$OUTPUT_DIR"

	cat exec.bin http.app > payload.bin 

	# Inject a program binary into to the kernel (ORG 0x001E0000)
	cat pure64-bios.sys kernel.sys payload.bin > software-bios.sys
	
	softwaresize=$(wc -c <software-bios.sys)
	if [ $softwaresize -gt 32768 ]; then
		echo "Warning - BIOS binary is larger than 32768 bytes!"
	fi

	# Copy first 3 bytes of MBR (jmp and nop)
	dd if=bios-novideo.sys of=baremetal_cloud.img bs=1 count=3 conv=notrunc > /dev/null 2>&1

	# Insert disk parameters
	echo "4D544F4F3430343900020220000200000000F00000000402000000000000000400F8030000000000000200000001000600000000000000000000000000000029F18A86064E4F204E414D45202020204641543332202020" | xxd -r -p | dd of=baremetal_cloud.img bs=1 seek=3 count=87 conv=notrunc > /dev/null 2>&1

	# Copy MBR code starting at offset 90
	dd if=bios-novideo.sys of=baremetal_cloud.img bs=1 skip=90 seek=90 count=356 conv=notrunc > /dev/null 2>&1

	# Insert partition table entry
	echo "800001000C0001000000000000000400" | xxd -r -p | dd of=baremetal_cloud.img bs=1 seek=446 count=16 conv=notrunc > /dev/null 2>&1

	# Copy valid boot sector signature
	dd if=bios-novideo.sys of=baremetal_cloud.img bs=1 skip=510 seek=510 count=2 conv=notrunc > /dev/null 2>&1
	
	# Copy software (Pure64, kernel, etc) to disk
	dd if=software-bios.sys of=baremetal_cloud.img bs=4096 seek=2 conv=notrunc > /dev/null 2>&1

	cd ..
}

function baremetal_run {
	baremetal_sys_check
	echo "Starting QEMU..."

	cmd+=( -name "BareMetal Cloud" )

	"${cmd[@]}" #execute the cmd string
}

function baremetal_vmdk {
	baremetal_sys_check
	echo "Creating VMDK image..."
	qemu-img convert -O vmdk "$OUTPUT_DIR/baremetal_cloud.img" "$OUTPUT_DIR/BareMetal_Cloud.vmdk"
}


function baremetal_bnr {
	baremetal_build
	baremetal_install
	baremetal_run
}

function baremetal_help {
	echo "BareMetal Cloud Script"
	echo "Available commands:"
	echo "clean    - Clean the src and bin folders"
	echo "setup    - Clean and setup"
	echo "update   - Pull in the latest code"
	echo "build    - Build source code"
	echo "install  - Install binary to disk image"
	echo "run      - Run the OS via QEMU"
	echo "vmdk     - Generate cloud VMDK disk image"
	echo "vendor   - Select vendor for disk image"
	echo "bnr      - Build 'n Run"
}

function baremetal_src_check {
	if [ ! -d src ]; then
		echo "Files are missing. Please run './baremetal.sh setup' first."
		exit 1
	fi
}

function baremetal_sys_check {
	if [ ! -d sys ]; then
		echo "Files are missing. Please run './baremetal.sh setup' first."
		exit 1
	fi
}

function baremetal_vendor {
	cd src/BareMetal
	if [ $# -eq 0 ]; then
		echo "Insufficent agruments - Select a cloud vendor with the correct argument:"
#		echo "aws - Amazon Web Services"
		echo "do  - Digital Ocean"
		echo "gcp - Google Cloud"
		exit 1
#	elif [ "$1" == "aws" ]; then
#		if [[ "$(uname)" == "Darwin" ]]; then
#			sed -i '' 's/^BUILDFLAGS=.*/BUILDFLAGS="-dNO_LFB -dNO_VIRTIO -dNO_XHCI -dNO_I8259X -dNO_I8257X -dNO_I8254X -dNO_AHCI"/' build.sh
#			sed -i '' 's/^KERNELSIZE.*/KERNELSIZE equ 10 * 1024/' src/kernel.asm
#		else
#			sed -i 's/^BUILDFLAGS=.*/BUILDFLAGS="-dNO_LFB -dNO_VIRTIO -dNO_XHCI -dNO_I8259X -dNO_I8257X -dNO_I8254X -dNO_AHCI"/' build.sh
#			sed -i 's/^KERNELSIZE.*/KERNELSIZE equ 10 * 1024/' src/kernel.asm
#		fi
	elif [ "$1" == "do" ]; then
		if [[ "$(uname)" == "Darwin" ]]; then
			sed -i '' 's/^BUILDFLAGS=.*/BUILDFLAGS="-dNO_LFB -dNO_XHCI -dNO_I8259X -dNO_I8257X -dNO_I8254X -dNO_NVME -dNO_AHCI"/' build.sh
			sed -i '' 's/^KERNELSIZE.*/KERNELSIZE equ 10 * 1024/' src/kernel.asm
		else
			sed -i 's/^BUILDFLAGS=.*/BUILDFLAGS="-dNO_LFB -dNO_XHCI -dNO_I8259X -dNO_I8257X -dNO_I8254X -dNO_NVME -dNO_AHCI"/' build.sh
			sed -i 's/^KERNELSIZE.*/KERNELSIZE equ 10 * 1024/' src/kernel.asm
		fi
	elif [ "$1" == "gcp" ]; then
		if [[ "$(uname)" == "Darwin" ]]; then
			sed -i '' 's/^BUILDFLAGS=.*/BUILDFLAGS="-dNO_LFB -dNO_VGA -dNO_XHCI -dNO_I8259X -dNO_I8257X -dNO_I8254X -dNO_NVME -dNO_AHCI"/' build.sh
			sed -i '' 's/^KERNELSIZE.*/KERNELSIZE equ 10 * 1024/' src/kernel.asm
		else
			sed -i 's/^BUILDFLAGS=.*/BUILDFLAGS="-dNO_LFB -dNO_VGA -dNO_XHCI -dNO_I8259X -dNO_I8257X -dNO_I8254X -dNO_NVME -dNO_AHCI"/' build.sh
			sed -i 's/^KERNELSIZE.*/KERNELSIZE equ 10 * 1024/' src/kernel.asm
		fi
	fi
	cd ../..
	baremetal_build
	baremetal_install
}

if [ $# -eq 0 ]; then
	baremetal_help
elif [ $# -eq 1 ]; then
	if [ "$1" == "setup" ]; then
		baremetal_setup
	elif [ "$1" == "clean" ]; then
		baremetal_clean
	elif [ "$1" == "build" ]; then
		baremetal_build
	elif [ "$1" == "install" ]; then
		baremetal_install
	elif [ "$1" == "update" ]; then
		baremetal_update
	elif [ "$1" == "help" ]; then
		baremetal_help
	elif [ "$1" == "run" ]; then
		baremetal_run
	elif [ "$1" == "vmdk" ]; then
		baremetal_vmdk
	elif [ "$1" == "bnr" ]; then
		baremetal_bnr
	elif [ "$1" == "vendor" ]; then
		baremetal_vendor
	else
		echo "Invalid argument '$1'"
	fi
elif [ $# -eq 2 ]; then
	if [ "$1" == "build" ]; then
		baremetal_build $2
	elif [ "$1" == "install" ]; then
		baremetal_install $2
	elif [ "$1" == "setup" ]; then
		baremetal_setup $2
	elif [ "$1" == "vendor" ]; then
		baremetal_vendor $2
	fi
fi
