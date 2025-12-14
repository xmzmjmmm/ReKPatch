#!/system/bin/sh

MODDIR="${0%/*}"
key="xmzmj520"

Basic_Check() {
	if [ "$(whoami)" != "root" ]; then
		echo "请使用 Root 权限运行此脚本"
		exit 1
	fi
    
	if [ ! -f "boot.img" ]; then
		echo "[x] 当前目录下未找到 boot.img"
		echo "[x] 脚本已退出，请将 boot.img 文件放在当前目录"
		exit 1
	fi

	if echo "$MODDIR" | grep -qE "sdcard|storage/emulated"; then
		echo "[!] 请勿在 sdcard 以及它的子目录下执行该脚本"
		echo "[x] 脚本已退出"
		exit 1
	elif [ ! -x . ]; then
		echo "[x] 当前目录没有可执行权限，请使用其他目录"
		echo "[x] 脚本已退出"
		exit 1
	else
		echo "[✓] 当前处于拥有可执行权限目录下"
	fi

	if test -x "$MODDIR/kpm/kptools-android"; then
		echo "[✓] kptools 可执行"
	else
		echo "[x] kptools 不可执行"
		echo "[-] 正在尝试获取可执行权限..."
		chmod +x "$MODDIR/kpm/kptools-android"
		
		if test -x "$MODDIR/kpm/kptools-android"; then
			echo "[✓] kptools 已获得可执行权限"
		else
			echo "[x] kptools 获取可执行权限失败，脚本已退出"
			exit 1
		fi
	fi

	required_files=("kpm/kpimg-linux" "kpm/Re-Kernel.kpm" "kpm/Re-Kernel_network.kpm" "libmagiskboot.so")
	for file in "${required_files[@]}"; do
		if [ ! -f "$file" ]; then
			echo "[x] 缺少必要文件: $file"
			echo "[x] 脚本已退出"
			exit 1
		fi
	done

	if [[ -e "kernel" && -e "new-boot.img" ]]; then
		echo "[?] 当前目录不干净，可能会影响嵌入效果"
		echo "[-] 正在清理目录"
		rm -f kernel ramdisk.cpio new-boot.img kpm/kernel kpm/patched_kernel 2>/dev/null
		echo "[✓] 已清理完成"
	fi
}

boot_unpack() {
	echo "[-] 正在解包 boot 获取 kernel"
	./libmagiskboot.so unpack boot.img >/dev/null 2>&1
	[ -e "kernel" ] && echo "[✓] 已成功获取 kernel"
	cp kernel kpm/
	cd kpm
}

Kernel_patching() {
	echo "[-] 正在对 kernel 执行修补"
	./kptools-android -p -i kernel -k kpimg-linux -M $1.kpm -V pre-kernel-init -T kpm -s $key -o patched_kernel
	is_rekernel=$(./kptools-android -l -i patched_kernel)
	[ -e "patched_kernel" ] && echo "[✓] Kernel 修补已完成"
	if echo "$is_rekernel" | grep -qE "re_kernel"; then
		echo "[✓] $kpm 已成功修补进你的内核！"
	else
		echo "[x] $kpm 修补失败，脚本已退出"
		cd ..
		rm -f kernel ramdisk.cpio kpm/kernel kpm/patched_kernel
		echo "[x] 已清理修补产生的文件"
		exit 1
	fi

	cp -f patched_kernel ../kernel
	cd ..
}

boot_repack() {
	echo "[-] 正在打包 boot"
	./libmagiskboot.so repack boot.img >/dev/null 2>&1
	[ -e "new-boot.img" ] && echo "[✓] boot 已打包成功"
	echo "[✓] 脚本已执行完毕，请确认当前目录下是否存在 new-boot.img"
	echo "[✓] 最后刷入 new-boot.img，即可获得 Rekernel"
}

main() {
	Basic_Check
	echo "---------------------------"
	echo "[?] 请输入序号选择修补版本"
	echo "[1] ReKernel (无网络解冻)"
	echo "[2] ReKernel_network (带网络解冻)"
	echo "[0] 退出"
	echo -n "[?] 请输入序号："
	read -r UserChose
	if [ "$UserChose" -eq 1 ]; then
		echo "[-] 你选择了 ReKernel (无网络解冻)"
		echo "[-] 开始修补..."
		kpm="Re-Kernel"
	elif [ "$UserChose" -eq 2 ]; then
		echo "[-] 你选择了 ReKernel_network (带网络解冻)"
		echo "[-] 开始修补..."
		kpm="Re-Kernel_network"
        elif [ "$UserChose" -eq 0 ]; then
                echo "[x] 脚本已退出"
		exit 1
	else
		echo "[x] 错误的输入，脚本已退出"
		exit 1
	fi
	boot_unpack
	Kernel_patching $kpm
	boot_repack
	exit 0
}

main
