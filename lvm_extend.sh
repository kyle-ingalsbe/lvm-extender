#!/bin/bash
	clear
	echo "LVM extend v1.0 build date 9-23-24"
	
	function test_for_q()
	{
		if [ "$1" = "q" ] || [ "$1" = "Q" ]
		then
			exit 1
	
		fi
		
		
		if [ "$1" = "" ]
		then
			if [ "$2" = "" ]
			then
				echo "$1"
			else
				echo "$2"
			fi
		else
			echo "$1"
		fi
	}
	
	function spacer()
	{
		
		for ((i = 0; i < $1; i++)); do
			echo " "
		done
		
	}
	
	
	function arr_fnd()
	{
		for i in $1
		do
			if [[ $i == $2 ]]
			then
				echo "yes"
			fi
		done
	}

	#=====================================================
	
	echo "Choose from the following Volume Group names:"
	
	
	#lvdisplay | grep "VG Name"

	#aa=$(lvdisplay | grep "VG Name" | awk '{print $3}' | head -1)
	aa=$(lvdisplay | grep "VG Name" | awk '{print $3}' )
	spacer 1
	
	
	def=""
	lst=()
	
	for i in $aa; do
		a=$(arr_fnd $lst $i)
		if [ "$a" != "yes" ]
		then
			echo "$i"
			lst+=("$i")
			if [ "$def" = "" ]
			then
				def=$i
			fi
		fi  
	done
	spacer 1

	read -p "Name? (or Q to quit) [$def]: " vg_name
		
	vg_name=$(test_for_q $vg_name $def)
	
	
	spacer 1
	
	if [ -d "/dev/$vg_name" ]; then
		echo " "
	else
		echo -e "\033[31;47m !!!WARNING!!! \033[0m no such path ( /dev/$vg_name/ ) exists. exiting..."
		exit 1
	fi
	
	
	
	#=====================================================
	
	echo "Next, choose a Logical Volume:"
	
	#lvdisplay | grep "LV Path"
	#aa=$(lvdisplay | grep "LV Path" | awk '{print $3}' | head -1)	
	spacer 1
	
	aa=$(lvdisplay | grep "LV Path" | awk '{print $3}')
	def=""
	for i in $aa; do
	
		#this is for the original
		bb=$(basename $i)
		
		#this "bba" is only for the if statment so i dont have to try every combination of swap, efi, boot, etc
		bba=$(basename $i | awk '{print tolower($0)}')
				
		if [ "$bba" != "efi" ] && [ "$bba" != "boot" ]  && [ "$bba" != "swap" ]
		then
			echo "$bb"
			if [ "$def" = "" ]
			then
				def=$bb
			fi
		fi  
	done
	
	spacer 1

	read -p "Volume? (or Q to quit) [$def]: " lv_path
	
	lv_path=$(test_for_q $lv_path $def)
	
	#=====================================================
	
	#get the file system - so far i will only support xfs and ext4 - havent seen other fs systems
	fs=$(lsblk -f /dev/$vg_name/$lv_path | sed -n 2p | awk '{print $2}')
	
	echo "detected file system of $lv_path is $fs"
	#exit 1
	
	redo=0
	
	while [ $redo -eq 0 ]
	do
	
	
		echo "Choose a drive to extend the LVM to (Make sure it does not have any partitions on it already):"
		
		spacer 1
		
		ls /dev/sd*
		
		spacer 1
		
		fdisk -l | grep "Disk /dev"

		spacer 1
		
		read -p "Which base drive? (example: sdb) (or Q to quit) (exclude /dev/ ): " drv
		test_for_q $drv ""
		
		read -p "Going to wipe drive of all paritions on /dev/$drv. Enter to contine or Q to quit: " aa
		test_for_q $aa ""
		
		sfdisk --delete /dev/$drv
		
		echo "Partitions deleted"
		
		echo "Creating new partitons"
		
		#always use parted instead of fdisk commands because there might be 2tb+ drives
		parted -s /dev/$drv mklabel gpt 

		parted /dev/$drv mkpart P1 $fs 1MiB 100%
		 
		parted /dev/$drv align-check optimal 1
		 
		nn="$drv""1"
		
		pvcreate /dev/$nn
		
		echo "extending lvm to /dev/$nn"
		
		vgextend $vg_name /dev/$nn
		
		lvextend -l +100%FREE /dev/$vg_name/$lv_path
		
		case "$fs" in
		
			ext2|ext3|ext4)
				resize2fs /dev/$vg_name/$lv_path
			;;
			
			xfs)
			
				xfs_growfs -d /dev/$vg_name/$lv_path
			;;
			
			*)
				echo "I am not programmed to expand the $fs file system. Research it and run the commands to finish this. Be sure to expand /dev/$vg_name/$lv_path"
			;;
		esac
		
		read -p "Do you want to add another drive? (or Q to quit) [Y/q]: " mm
		
		test_for_q $mm ""
	
		
	done
	
	
	echo "In theory it should be done. You should not see this. If you do, then there was probably an error."
	
