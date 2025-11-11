# BareMetal-Cloud

> [!IMPORTANT]
> This has only been tested against Digital Ocean. AWS and Google Cloud support is coming soon.

BareMetal Cloud is a minimal version of the [BareMetal](https://github.com/ReturnInfinity/BareMetal) exokernel specifically geared for running in cloud instances.

# Getting Started

## Initial configuration

	git clone https://github.com/ReturnInfinity/BareMetal-Cloud.git
	cd BareMetal-Cloud
	./baremetal.sh setup

`baremetal.sh setup` automatically runs the build and install functions. Once the setup is complete you can execute `baremetal.sh run` to verify that everything installed correctly.

## Building

	./baremetal.sh build

This command builds the boot sector, loader (Pure64), and kernel

## Installing

	./baremetal.sh install

This command installs the software to the disk image.

## Running

	./baremetal.sh run

This command will run BareMetal-Cloud in a QEMU VM. Output to the serial port will be displayed to the console.

# Running in the Cloud

## Digital Ocean

Create a VMDK disk image

	./baremetal.sh vmdk

In Digital Ocean click on `Backups & Snapshots` and then `Custom Images`. Click on the `Upload Image` button and select the .vmdk file on your filesystem. Once the file is uploaded you can start a droplet of it by clicking on the `More` dropdown and selecting `Start a droplet`.

On the `Create Droplets` page you can select the Droplet Type and CPU Options. Give the droplet a name and click on `Create Droplet`.


//EOF