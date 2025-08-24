uac() {
clear
uacpass=0
if [ $uacpass -eq 0 ]
then

echo -e "\033[31m***************************************************\033[0m"
echo -e "\033[31mВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! \033[0m"
echo ""
echo "Выполнение критической операции! Для отмены: CTRL + C или N"
echo "Для подтверждения нажмите ЛЮБУЮ клавишу!"
echo ""
echo -e "\033[31mВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! \033[0m"
echo -e "\033[31m***************************************************\033[0m"
	read -p "Подтвердите выполнение операции: [*/n]: " item
        case "$item" in
	n) exit
	;;

	N) exit
	;;

	*) clear
           echo "!!!!Подтверждение получено!!!!"
	   echo ""
	   uacpass=1
	;;
esac
fi
}


send() {
echo "Отправка парольной фразы..."
echo ""
python3 unlock.py -c $1
echo ""
echo "Парольная фраза отправлена!"
echo ""
}


selfdestruct() {
partition="/dev/nvme0n1p3"

#cryptsetup --batch-mode erase $partition
echo -e "\033[31m***************************************************\033[0m"
echo -e "\033[31mВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! \033[0m"
echo ""
echo "Cервер КОМАНДНОГО центра стал незагружаемым!"
echo ""
echo -e "\033[31mВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! ВНИМАНИЕ! \033[0m"
echo -e "\033[31m***************************************************\033[0m"
sleep 5
echo o > /proc/sysrq-trigger 
}

delayreboot() {
nohup sleep 60 && echo o > /proc/sysrq-trigger &
nohup sleep 61 && shutdown -h now &
nohup sleep 62 && poweroff --force --no-sync &
}


# re-run as root
if [[ $EUID -ne 0 ]]; then
    exec sudo /bin/bash "$0" "$@"
fi
        clear
        echo ""
        echo "Выберите действие:"
        echo "   1) Разблокировать сервер sandbox"
	echo "   ------------------------------"
	echo "   a) Затереть сервер sandbox"
	echo "   b) Восстановить сервер sandbox"
	echo "   c) Затереть командный центр"
	echo "   -----------------------------"
	echo "   X) Протокол ТРЕВОГА"
        echo "   *) Выйти"
        read -p "Выбор: " techoption
        case "$techoption" in
                1)
		send sandbox.ini
                exit
                ;;

                a)
		uac
		send sandbox.destroy.ini
                exit
                ;;

                b)
                ssh -o "IdentitiesOnly=yes" -i key root@IP-address -p2222 "cryptsetup luksHeaderRestore /dev/vda5 --header-backup-file /scripts/backup-header-file"
                ssh -o "IdentitiesOnly=yes" -i key root@IP-address -p2222 "reboot -f"
                exit
                ;;

		c)
		uac
		delayreboot
		selfdestruct
		;;

		X|x)
		uac
		delayreboot
		send sandbox.destroy.ini
		selfdestruct
		;;

                *)
                exit
                ;;
esac

