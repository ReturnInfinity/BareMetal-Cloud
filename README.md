# BareMetal-Cloud

> [!IMPORTANT]
> This has only been tested with Digital Ocean and Proxmox. Support for other hypervisor/cloud providers (AWS, Azure, and Google Cloud) is coming soon.

BareMetal Cloud is a minimal version of the [BareMetal](https://github.com/ReturnInfinity/BareMetal) exokernel specifically geared for running in public/private cloud instances. This minimal version of BareMetal that contains only the relevant drivers is 10,240 bytes in size and uses 4 MiB of memory. All other memory is allocated to the payload.

An instance of BareMetal is running in Digital Ocean at http://baremetal.returninfinity.com and will respond to HTTP and ICMP.

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

Create a VMDK disk image

	./baremetal.sh vmdk

The resulting `BareMetal_Cloud.vmdk` in `sys/` will be required.

## Digital Ocean

In Digital Ocean click on `Backups & Snapshots` and then `Custom Images`. Click on the `Upload Image` button and select the .vmdk file on your filesystem. Once the file is uploaded you can start a droplet of it by clicking on the `More` dropdown and selecting `Start a droplet`.

On the `Create Droplets` page you can select the Droplet Type and CPU Options. Give the droplet a name and click on `Create Droplet`.

## Proxmox

### 1) Create a new VM

In Proxmox click on the "Create VM" button. Configure the following settings:

- General - Give the VM a name
- OS - "Do not use any media"
- System - Machine: q35
- Disks - Remove the existing disk
- CPU - Provision as needed
- Memory - Provision as needed
- Network - Model: VirtIO
- Confirm - Click "Finish"

### 2) Copy the .vmdk file

Use a utility like `scp` to copy the .vmdk file to the filesystem of the Proxmox server.

### 3) Import the disk

`qm importdisk <VMID> <vmdk_filename> <storage_location>`

Example - `qm importdisk 101 /root/BareMetal_Cloud.vmdk local-lvm --format raw`

### 4) Attach the new disk

In the Proxmox web interface select the new VM. In the Hardware section, find the new unused disk, and attach it to the VM.

Verify the "Boot Order" in the VM "Options".

### 5) Start the VM

Click "Start" on the VM.


//EOF
